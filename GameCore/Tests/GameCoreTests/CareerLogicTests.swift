// CareerLogicTests.swift
// 年間進行の分岐テスト（乱数スタブで敗者復活ルート・王者シード・出場資格を固定的に検証）

import XCTest
@testable import GameCore

struct RestOnlyPolicy: WeekPolicy {
    mutating func action(week: Int, year: Int, state: GameState, offer: OfferSpec?) -> WeekAction {
        .rest(.完全休養)
    }
    mutating func enterTournament(_ spec: TournamentSpec, year: Int, state: GameState) -> Travel? {
        nil
    }
}

final class CareerLogicTests: XCTestCase {

    /// 大会なし・オファー率0の検証用コンフィグ（乱数消費が「自由週1・回戦1」に固定される）
    func bareConfig() -> GameConfig {
        var config = GameConfig()
        config.calendar.tournaments = []
        config.offerRates = [(999, 0.0)]
        return config
    }

    func testRevivalRouteToChampionship() {
        let config = bareConfig()
        var s = GameState(config: config)
        for a in [Ability.センス, .発想, .表現, .華] { s[a] = 78 }   // 実力値78
        s.メンタル = 100                                             // ブレ幅±5
        s.compat = 10                                                // 素点88

        // 乱数計画: 自由週=0.9 / 回戦u=0.5(ブレ0→88で通過) / 準決u=0.0(83<85で敗退→復活へ)
        //           / 敗者復活u=0.9(92≥88通過) / 決勝u=0.95(92.5≥91優勝)
        var vals = Array(repeating: 0.9, count: 29)   // 第1〜29週
        vals += [0.5]                                  // 第30週 1回戦
        vals += Array(repeating: 0.9, count: 8)        // 第31〜38週
        vals += [0.5, 0.9, 0.5, 0.9, 0.5, 0.9, 0.0, 0.9, 0.9, 0.95]
        var rng = SeqRandom(values: vals)
        var policy = RestOnlyPolicy()

        let outcome = GameCareer.runYear(state: &s, year: 1, config: config, policy: &policy, rng: &rng)
        XCTAssertTrue(outcome.champion)
        XCTAssertTrue(outcome.reachedFinal)
        XCTAssertEqual(outcome.roundsPassed, 4)   // 準決勝は落ちている（復活経由）
        // 生活費11回(第4〜44週)と優勝賞金が反映される
        XCTAssertEqual(s.money, 300_000 - 1_100_000 + 5_000_000)
        // 知名度: 3 + 回戦通過3×4 + 復活3 + 優勝20
        XCTAssertEqual(s.fame, 38, accuracy: 1e-9)
    }

    func testSeedFinalAndLineOverride() {
        let config = bareConfig()
        var s = GameState(config: config)
        var rng = FixedRandom(value: 0.9)
        var policy = RestOnlyPolicy()

        // 王者シード: 予選免除で決勝直行。ライン200は絶対に越えられない→防衛失敗
        let outcome = GameCareer.runYear(state: &s, year: 11, config: config, policy: &policy, rng: &rng,
                                         seedFinal: true, finalLineOverride: 200)
        XCTAssertFalse(outcome.champion)
        XCTAssertTrue(outcome.reachedFinal)
        XCTAssertEqual(outcome.roundsPassed, 0)
    }

    func testTournamentEligibility() {
        var s = GameState()
        let young = TournamentSpec(name: "若手限定賞", week: 35, line: 50, prize: 250_000, fame: 5,
                                   osaka: false, eligibility: .careerYearAtMost(5))
        XCTAssertTrue(young.isEligible(year: 5, state: s))
        XCTAssertFalse(young.isEligible(year: 6, state: s))

        let invite = TournamentSpec(name: "推薦制中堅賞", week: 38, line: 60, prize: 500_000, fame: 10,
                                    osaka: false, eligibility: .fameAtLeast(30))
        XCTAssertFalse(invite.isEligible(year: 1, state: s))
        s.fame = 30
        XCTAssertTrue(invite.isEligible(year: 1, state: s))
    }

    func testCannotAffordTravelSkipsTournament() {
        var config = GameConfig()
        config.offerRates = [(999, 0.0)]
        var s = GameState(config: config)
        s.money = 5_000   // バス代1万円が払えない

        struct BusPolicy: WeekPolicy {
            var sawOffer = false
            mutating func action(week: Int, year: Int, state: GameState, offer: OfferSpec?) -> WeekAction {
                .rest(.完全休養)
            }
            mutating func enterTournament(_ spec: TournamentSpec, year: Int, state: GameState) -> Travel? {
                .夜行バス
            }
        }
        var policy = BusPolicy()
        var rng = FixedRandom(value: 0.9)
        // 第12週の大阪大会は交通費不足で不参加→自由週として処理され、体力は満タンのまま週を終える
        _ = GameCareer.runYear(state: &s, year: 1, config: config, policy: &policy, rng: &rng)
        // バス代を引かれた形跡がない（生活費のみ12回）
        XCTAssertEqual(s.money, 5_000 - 1_200_000)
    }
}
