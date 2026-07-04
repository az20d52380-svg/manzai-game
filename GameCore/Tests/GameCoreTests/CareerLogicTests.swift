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

    /// 敗者復活→同週決勝→優勝のルート検証【正典v2改訂】。
    /// ラインを極端値に固定して経路だけを検証する（数値の正しさはgoldenが担保。旧版の乱数計画方式は
    /// v2のperform=2draw化・エントリー費で崩れるため、レッドチーム指摘により全面書き直し）
    func testRevivalRouteToChampionship() {
        var config = bareConfig()
        config.calendar.gpRounds = [(30, -999), (39, -999), (41, -999), (43, -999), (45, 999)]  // 準決だけ必ず落ちる
        config.calendar.gpRevivalLine = -999   // 敗者復活は必ず通る
        config.calendar.gpFinalLine = -999     // 決勝は必ず勝つ
        var s = GameState(config: config)
        s.money = 10_000_000                   // エントリー費・生活費で詰まらない潤沢な資金
        var rng = FixedRandom(value: 0.5)      // 0.5 > ハマ率0.10 なのでハマは発生しない・決定的
        var policy = RestOnlyPolicy()

        let outcome = GameCareer.runYear(state: &s, year: 1, config: config, policy: &policy, rng: &rng)
        XCTAssertTrue(outcome.champion)
        XCTAssertTrue(outcome.reachedFinal)
        XCTAssertFalse(outcome.bankrupt)
        XCTAssertEqual(outcome.roundsPassed, 4)   // 準決勝は落ちている（復活経由）
        // 生活費11回(第4〜44週・優勝週の週末処理は走らない)＋エントリー費2,000＋優勝賞金
        XCTAssertEqual(s.money, 10_000_000 - 1_100_000 - 2_000 + 5_000_000)
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
        // 第12週の大阪大会は「エントリー費2,000+バス代1万」が払えず不参加→自由週として処理される。
        // GPも第30週時点で赤字のためエントリー費が払えず今年は不出場【正典v2】
        let outcome = GameCareer.runYear(state: &s, year: 1, config: config, policy: &policy, rng: &rng)
        // 収入ゼロのまま生活費が積もり、第44週の支払いで-100万を割って夜逃げ（第45週以降は走らない）
        XCTAssertTrue(outcome.bankrupt)
        XCTAssertEqual(outcome.roundsPassed, 0)
        XCTAssertEqual(s.money, 5_000 - 1_100_000)   // 生活費11回で夜逃げライン超え・大会費用の形跡なし
    }
}
