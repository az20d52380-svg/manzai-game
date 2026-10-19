// Coverage1019bTests.swift
// llvm-cov で 0 回だった2か所（WeekRunner.chooseOffer の差し替え・runCareer の優勝年を返す枝）を通す。
// ★式・乱数・golden には触れない（既存の GoldenPolicy／SplitMix64 をそのまま使う）。

import XCTest
@testable import GameCore

final class Coverage1019bTests: XCTestCase {
    private let cfg = GameConfig()

    /// 札が2枚以上並んだ週に chooseOffer(1) を呼ぶと、受けた時の収入が2枚目の札の分になる
    func testChooseOfferSecondCardChangesAcceptedIncome() {
        var found = false
        outer: for seed in UInt64(1)...40 {
            var s = GameState(config: cfg)
            s.fame = 60          // 知名度が高いほど追加の札が並ぶ
            s.money = 5_000_000
            var r = WeekRunner(state: s, year: 1, config: cfg, rng: SplitMix64(seed: seed), inviteSeed: 424243 &+ seed)
            var phase = r.begin()
            for _ in 0..<400 {
                switch phase {
                case .tournamentDecision: phase = r.resolveTournament(travel: nil)
                case .gpRound, .gpRevival, .gpFinal: phase = r.resolveAuto()
                case .weekDone:
                    if r.pendingInvite != nil { r.resolveInvite(accept: false) }
                    phase = r.begin()
                case .yearDone: continue outer
                case .freeAction(let offer):
                    if offer != nil, let c = r.offerChoices, c.count >= 2, c[0].income != c[1].income {
                        var first = r
                        var second = r
                        second.chooseOffer(index: 1)
                        _ = first.resolveAction(.acceptOffer)
                        _ = second.resolveAction(.acceptOffer)
                        XCTAssertEqual(second.state.money - first.state.money, c[1].income - c[0].income,
                                       "2枚目を選ぶと、受けた収入の差がちょうど札の収入の差になる")
                        found = true
                        break outer
                    }
                    phase = r.resolveAction(.rest(.完全休養))
                }
            }
        }
        XCTAssertTrue(found, "札が2枚以上並ぶ週が見つからなかった（知名度・シードを見直す）")
    }

    /// 優勝した年でキャリアが終わり、その年を返す（それ以降の年は回らない）
    func testRunCareerReturnsChampionYear() {
        var s = GameState(config: cfg)
        for a in Ability.allCases { s[a] = 400 }   // 誰にも負けない実力
        s.money = 50_000_000
        var p = GoldenPolicy()
        var r = SplitMix64(seed: 7)
        let champ = GameCareer.runCareer(state: &s, years: 3, config: cfg, policy: &p, rng: &r)
        XCTAssertEqual(champ, 1)

        var s2 = GameState(config: cfg)
        for a in Ability.allCases { s2[a] = 400 }
        s2.money = 50_000_000
        var p2 = GoldenPolicy()
        var r2 = SplitMix64(seed: 7)
        let o = GameCareer.runYear(state: &s2, year: 1, config: cfg, policy: &p2, rng: &r2)
        XCTAssertTrue(o.champion)
        XCTAssertEqual(s.fame, s2.fame, accuracy: 1e-12, "1年目で終わり、2年目は回らない")
        XCTAssertEqual(s.money, s2.money)
    }
}
