// CoverageRTests.swift
// 経験点通貨の表示名／特技の説明・係数の向き・覚える条件／ShopItem の購入ガード／読み取り専用フラグの初期値。
// Sources・式・乱数・golden は不変（期待値は性質だけ＝向きと一意性）。

import XCTest
@testable import GameCore

final class CoverageRTests: XCTestCase {
    let cfg = GameConfig()

    func testExpCurrencyDisplayNamesDistinctAndNonEmpty() {
        let names = ExpCurrency.allCases.map(\.displayName)
        XCTAssertEqual(names.count, 5)
        XCTAssertEqual(Set(names).count, 5)
        XCTAssertTrue(names.allSatisfy { !$0.isEmpty })
        XCTAssertEqual(ExpCurrency.閃き.displayName, "ネタ種")
    }

    func testExpCurrencyCodableRoundTrip() throws {
        for c in ExpCurrency.allCases {
            let back = try JSONDecoder().decode(ExpCurrency.self, from: JSONEncoder().encode(c))
            XCTAssertEqual(back, c)
        }
    }

    func testSkillMultipliersPointTheRightWay() {
        XCTAssertLessThan(Skill.injuryMult, 1)    // 体調ダウンは減る
        XCTAssertGreaterThan(Skill.fameMult, 1)   // 知名度は伸びやすい
        XCTAssertLessThan(Skill.livingMult, 1)    // 生活費は安い
        XCTAssertLessThan(Skill.riftMult, 1)      // すれ違いは増えにくい
    }

    func testSkillSummariesAndCostsAreDefined() {
        XCTAssertEqual(Set(Skill.allCases.map(\.summary)).count, Skill.allCases.count)
        for k in Skill.allCases {
            XCTAssertFalse(k.cost.isEmpty)
            XCTAssertTrue(k.cost.allSatisfy { $0.amount > 0 })
        }
    }

    func testSkillHasIsFalseWithoutSkills() {
        var s = GameState(config: cfg)
        XCTAssertNil(s.skills)
        XCTAssertTrue(Skill.allCases.allSatisfy { !s.has($0) })
        s.skills = [.愛され芸人]
        XCTAssertTrue(s.has(.愛され芸人))
        XCTAssertFalse(s.has(.体が資本))
    }

    func testLearnSkillFailsWithoutExpAndLeavesStateUntouched() {
        var s = GameState(config: cfg)
        for c in ExpCurrency.allCases { s[currency: c] = 0 }
        let before = s
        XCTAssertFalse(GameEngine.canLearn(.愛され芸人, state: s))
        XCTAssertFalse(GameEngine.learnSkill(.愛され芸人, to: &s))
        XCTAssertEqual(s.money, before.money)
        XCTAssertNil(s.skills)
        for c in ExpCurrency.allCases { XCTAssertEqual(s[currency: c], 0) }
    }

    func testLearnSkillOnlyOnceAndPaysCost() {
        var s = GameState(config: cfg)
        for c in ExpCurrency.allCases { s[currency: c] = 10 }
        XCTAssertTrue(GameEngine.learnSkill(.愛され芸人, to: &s))
        XCTAssertEqual(s[currency: .存在感], 4, accuracy: 1e-9)   // 費用 6 を引く
        XCTAssertFalse(GameEngine.canLearn(.愛され芸人, state: s))   // 覚えたものは再び覚えられない
        XCTAssertFalse(GameEngine.learnSkill(.愛され芸人, to: &s))
        XCTAssertEqual(s.skills, [.愛され芸人])
    }

    func testCanBuyRejectsTooPoorAndUnlisted() {
        var s = GameState(config: cfg)
        s.money = 0
        for item in cfg.shopLineup { XCTAssertFalse(GameEngine.canBuy(item, state: s, config: cfg)) }
        s.money = 10_000_000
        var c2 = cfg; c2.shopLineup = [.栄養ドリンク]
        XCTAssertFalse(GameEngine.canBuy(.回復ドリンク大, state: s, config: c2))   // 品揃えに無い物は買えない
        XCTAssertTrue(GameEngine.canBuy(.栄養ドリンク, state: s, config: c2))
    }

    func testBuyFailureLeavesMoneyAndCountsUntouched() {
        var s = GameState(config: cfg)
        s.money = 1
        let before = s
        XCTAssertFalse(GameEngine.buy(.栄養ドリンク, to: &s, config: cfg))
        XCTAssertEqual(s.money, before.money)
        XCTAssertNil(s.itemCounts)
    }

    func testSentoTicketCannotBeBoughtTwiceWhileHeld() {
        var s = GameState(config: cfg)
        s.money = 10_000_000
        XCTAssertTrue(GameEngine.buy(.銭湯の回数券, to: &s, config: cfg))
        let m = s.money
        XCTAssertFalse(GameEngine.canBuy(.銭湯の回数券, state: s, config: cfg))
        XCTAssertFalse(GameEngine.buy(.銭湯の回数券, to: &s, config: cfg))
        XCTAssertEqual(s.money, m)
    }

    func testFreshRunnerFlagsAtStart() {
        let r = WeekRunner(state: GameState(config: cfg), year: 1, config: cfg, rng: SplitMix64(seed: 3))
        XCTAssertFalse(r.hasRevival)
        XCTAssertFalse(r.isFinalist)
        XCTAssertEqual(r.gpRoundsPassed, 0)
    }
}
