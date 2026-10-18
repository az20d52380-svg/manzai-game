// SkillTests.swift
// 特技（キュー106・規律A）。Python: balance_sim.learn_skill / SKILL_*。乱数は引かない（体調ダウンの抽選の確率だけ変わる）。
import XCTest
@testable import GameCore

private struct FixedRNG: RandomSource {
    var value: Double
    mutating func nextUniform() -> Double { value }
}

final class SkillTests: XCTestCase {
    /// 体が資本：体力10＝確率0.2、特技ありは0.14。乱数0.17なら、特技なしだけ体調ダウン
    func testBodyIsCapitalLowersInjuryChance() {
        var config = GameConfig()
        config.initStamina = 10   // 年初の体力＝10
        func run(_ skill: Bool) -> Int {
            var s = GameState(config: config)
            if skill { s.skills = [.体が資本] }
            var r = WeekRunner(state: s, year: 1, config: config, rng: FixedRNG(value: 0.17))
            _ = r.begin()
            _ = r.resolveAction(.job(.キツい))
            return r.state.メンタル < GameState(config: config).メンタル ? 1 : 0
        }
        XCTAssertGreaterThan(run(false), 0)
        XCTAssertEqual(run(true), 0)
    }

    /// 愛され芸人：知名度の伸びが ×1.1（正の増分だけ・負は変えない）
    func testBelovedComedianRaisesFameGain() {
        let config = GameConfig()
        var a = GameState(config: config), b = GameState(config: config)
        b.skills = [.愛され芸人]
        GameEngine.add(.知名度, 10, to: &a, config: config)
        GameEngine.add(.知名度, 10, to: &b, config: config)
        XCTAssertEqual(b.fame - config.initFame, (a.fame - config.initFame) * 1.1, accuracy: 1e-9)
        a.fame = 50; b.fame = 50
        GameEngine.add(.知名度, -5, to: &a, config: config)
        GameEngine.add(.知名度, -5, to: &b, config: config)
        XCTAssertEqual(a.fame, b.fame, accuracy: 1e-9)
    }

    /// やりくり上手：月末の生活費 −5%
    func testThriftyCutsLivingCost() {
        let config = GameConfig()
        var a = GameState(config: config), b = GameState(config: config)
        b.skills = [.やりくり上手]
        GameEngine.applyWeekEnd(week: config.livingInterval, to: &a, config: config)
        GameEngine.applyWeekEnd(week: config.livingInterval, to: &b, config: config)
        XCTAssertEqual(config.initMoney - a.money, config.livingCost)
        XCTAssertEqual(config.initMoney - b.money, Int((Double(config.livingCost) * 0.95).rounded()))
    }

    /// 相方思い：すれ違いの増えが ×0.8（増えた週だけ・相性が上がった週の回復は同じ）
    func testPartnerMindedSlowsRift() {
        let config = GameConfig()
        var a = GameState(config: config), b = GameState(config: config)
        for i in 0..<2 {
            var s = i == 0 ? a : b
            s.compat = 5; s.riftWeekStartCompat = 5
            if i == 1 { s.skills = [.相方思い] }
            _ = GameEngine.applyRiftWeekEnd(year: 2, to: &s, config: config)
            if i == 0 { a = s } else { b = s }
        }
        XCTAssertEqual(b.rift ?? 0, (a.rift ?? 0) * 0.8, accuracy: 1e-9)
    }

    /// 足りない時は覚えられない（費用も引かれない）／足りれば費用を引いて一度きり
    func testCannotLearnWithoutEnoughExp() {
        let config = GameConfig()
        var s = GameState(config: config)
        s.exp存在感 = 5.9
        XCTAssertFalse(GameEngine.learnSkill(.愛され芸人, to: &s))
        XCTAssertEqual(s.exp存在感, 5.9, accuracy: 1e-9)
        XCTAssertFalse(s.has(.愛され芸人))
        s.exp存在感 = 6.5
        XCTAssertTrue(GameEngine.learnSkill(.愛され芸人, to: &s))
        XCTAssertEqual(s.exp存在感, 0.5, accuracy: 1e-9)
        XCTAssertTrue(s.has(.愛され芸人))
        s.exp存在感 = 6.5
        XCTAssertFalse(GameEngine.learnSkill(.愛され芸人, to: &s))   // 一度きり
    }
}
