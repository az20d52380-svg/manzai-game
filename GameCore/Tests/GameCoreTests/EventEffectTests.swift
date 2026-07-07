// EventEffectTests.swift
// 選択肢イベントの確定効果（proposals/0024 ピース1）の単体テスト。
// golden とは別系統: applyEventEffect は RandomSource を呼ばないので3年goldenは不変（golden系テストで担保）。
// ここは「効果が期待通り・clampが効く・弱技能選択が決定的」を検証する。
// ※ WeekRunner.init は stamina/growthBudget を初期化リセットするため、効果ロジックは GameState 直接で検証する。

import XCTest
@testable import GameCore

final class EventEffectTests: XCTestCase {

    private let cfg = GameConfig()

    /// 0018-A: 知名度+3 / 体力-15 / メンタル-1（純加減算）
    func testJustPassedChoiceAflat() {
        var s = GameState(config: cfg)
        s.fame = 10; s.stamina = 80; s.メンタル = 40
        for e in [EventEffect.fame(3), .stamina(-15), .ability(.メンタル, -1)] {
            s.applyEventEffect(e, config: cfg)
        }
        XCTAssertEqual(s.fame, 13, accuracy: 1e-9)
        XCTAssertEqual(s.stamina, 65, accuracy: 1e-9)
        XCTAssertEqual(s.メンタル, 39, accuracy: 1e-9)
    }

    /// 0018-B: センス/発想の低い方に+1（決定的）＋相性+1
    func testWeakerSenseIdeaAndCompat() {
        var s = GameState(config: cfg)
        s.センス = 30; s.発想 = 25; s.compat = 8
        for e in [EventEffect.weakerSenseIdeaPlus(1), .compat(1)] { s.applyEventEffect(e, config: cfg) }
        XCTAssertEqual(s.発想, 26, accuracy: 1e-9)   // 発想の方が低い
        XCTAssertEqual(s.センス, 30, accuracy: 1e-9)
        XCTAssertEqual(s.compat, 9, accuracy: 1e-9)
    }

    /// 0017-A: 4技能(メンタル除外)の最弱に+2。メンタルが全体最小でもメンタルには乗らない（相殺バグ回避）
    func testWeakestSkillExcludesMental() {
        var s = GameState(config: cfg)
        s.センス = 20; s.発想 = 18; s.表現 = 22; s.華 = 25; s.メンタル = 5
        for e in [EventEffect.weakestSkillPlus(2), .ability(.メンタル, -2), .stamina(-10)] {
            s.applyEventEffect(e, config: cfg)
        }
        XCTAssertEqual(s.発想, 20, accuracy: 1e-9)   // 4技能の最弱=発想に+2
        XCTAssertEqual(s.メンタル, 3, accuracy: 1e-9) // メンタルは-2のみ（+2は乗らない）
    }

    /// clamp: 相性は compatCap 上限・能力は0下限
    func testClamps() {
        var s = GameState(config: cfg)
        s.compat = cfg.compatCap; s.表現 = 1
        for e in [EventEffect.compat(1), .ability(.表現, -5)] { s.applyEventEffect(e, config: cfg) }
        XCTAssertEqual(s.compat, cfg.compatCap, accuracy: 1e-9)  // 上限で止まる
        XCTAssertEqual(s.表現, 0, accuracy: 1e-9)                 // 0で止まる
    }

    /// 0017-C: 所持金は負にもなる（クランプ無し）
    func testMoneyNoClamp() {
        var s = GameState(config: cfg)
        s.money = 1000
        s.applyEventEffect(.money(-1500), config: cfg)
        XCTAssertEqual(s.money, -500)
    }

    /// seam: WeekRunner.applyEventEffects が権威stateへ反映する（stamina は init リセット後の値基準）
    func testRunnerSeamAppliesAbility() {
        var s = GameState(config: cfg)
        s.発想 = 40
        var r = WeekRunner(state: s, year: 1, config: cfg, rng: SplitMix64(seed: 1))
        r.applyEventEffects([.ability(.発想, 2)])
        XCTAssertEqual(r.state.発想, 42, accuracy: 1e-9)
    }
}
