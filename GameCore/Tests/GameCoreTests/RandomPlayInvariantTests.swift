// RandomPlayInvariantTests.swift
// ランダムな行動で10年回し、毎週末の状態が範囲を外れない・NaN/無限大にならないことを見る（11/08 自走の点検）。
// 式・乱数消費・golden には触らない（ボットは別の乱数で行動を選ぶ＝本体の乱数列は runYear の中だけ）。
// 体力・知名度 0..100、相性 0..compatCap、能力 0..abilityCap（メンタルは mentalCap）、経験点は非負・有限。

import XCTest
@testable import GameCore

private struct RandomPolicy: WeekPolicy {
    var pick: SplitMix64
    private mutating func roll(_ n: Int) -> Int { min(n - 1, Int(pick.nextUniform() * Double(n))) }
    mutating func action(week: Int, year: Int, state: GameState, offer: OfferSpec?) -> WeekAction {
        switch roll(offer == nil ? 3 : 4) {
        case 0: return .train(Training.allCases[roll(Training.allCases.count)])
        case 1: return .job(Job.allCases[roll(Job.allCases.count)])
        case 2: return .rest(Rest.allCases[roll(Rest.allCases.count)])
        default: return .acceptOffer
        }
    }
    mutating func enterTournament(_ spec: TournamentSpec, year: Int, state: GameState) -> Travel? {
        switch roll(3) { case 0: return nil; case 1: return .夜行バス; default: return .新幹線 }
    }
    mutating func acceptInvite(state: GameState) -> Bool { roll(2) == 0 }
}

final class RandomPlayInvariantTests: XCTestCase {

    private func check(_ s: GameState, _ c: GameConfig, _ where_: String) {
        let eps = 1e-9
        XCTAssert(s.stamina.isFinite && s.stamina >= -eps && s.stamina <= 100 + eps, "体力 \(s.stamina) \(where_)")
        XCTAssert(s.fame.isFinite && s.fame >= -eps && s.fame <= 100 + eps, "知名度 \(s.fame) \(where_)")
        XCTAssert(s.compat.isFinite && s.compat >= -eps && s.compat <= c.compatCap + eps, "相性 \(s.compat) \(where_)")
        for (name, v, cap) in [("センス", s.センス, c.abilityCap), ("発想", s.発想, c.abilityCap), ("表現", s.表現, c.abilityCap),
                               ("華", s.華, c.abilityCap), ("メンタル", s.メンタル, c.mentalCap)] {
            XCTAssert(v.isFinite && v >= -eps && v <= cap + eps, "\(name) \(v) \(where_)")
        }
        XCTAssert(s.exp閃き.isFinite && s.exp閃き >= -eps, "経験点 閃き \(s.exp閃き) \(where_)")
        XCTAssert(s.exp語彙.isFinite && s.exp語彙 >= -eps, "経験点 語彙 \(s.exp語彙) \(where_)")
    }

    func testRandomPlayKeepsStateInRange() { run(female: false, metaPoints: 0) }
    /// 女性コンビ（THE HANA の道）と周回メタの初期加算ありでも同じ
    func testRandomPlayFemaleAndMetaKeepsStateInRange() { run(female: true, metaPoints: 60) }

    private func run(female: Bool, metaPoints: Int) {
        let config = GameConfig()
        for seed in UInt64(1)...40 {
            var s = GameState(config: config, metaPoints: metaPoints, femaleCombo: female)
            var rng = SplitMix64(seed: seed)
            var policy = RandomPolicy(pick: SplitMix64(seed: seed &* 7919 &+ 17))
            for year in 1...10 {
                let o = GameCareer.runYear(state: &s, year: year, config: config, policy: &policy, rng: &rng) { week, st in
                    self.check(st, config, "seed \(seed) \(year)年 第\(week)週")
                }
                check(s, config, "seed \(seed) \(year)年末")
                if o.bankrupt || o.dissolved { break }
            }
        }
    }
}
