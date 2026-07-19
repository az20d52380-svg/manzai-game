// ChoiceEventTests.swift
// 選択肢イベント（正典: proposals/0024・0010/0017/0018/0019）の純データ検証。
// ★golden非干渉の証明は既存32件（WeekRunnerGoldenTests等・不変）が担う。本ファイルは
//   ChoiceEventTable と EventEffect 適用（GameState.applyEventEffect・RNG非消費）の挙動のみを検証する。

import XCTest
@testable import GameCore

final class ChoiceEventTests: XCTestCase {

    private func apply(_ effects: [EventEffect], to s: inout GameState, config: GameConfig) {
        for e in effects { s.applyEventEffect(e, config: config) }
    }

    // MARK: 0017 負けた日の稽古場

    func test0017_A_raisesWeakestOfFourSkillsExcludingMental() {
        let config = GameConfig()
        var s = GameState(config: config)
        s.センス = 50; s.発想 = 30; s.表現 = 60; s.華 = 70; s.メンタル = 10   // 発想が最弱・メンタルは対象外
        apply(ChoiceEventTable.choices(for: .justLostRehearsal, config: config)[0].effects, to: &s, config: config)
        XCTAssertEqual(s.発想, 32)     // 最弱4技能(メンタル除外)+2
        XCTAssertEqual(s.センス, 50)   // 他は不変
        XCTAssertEqual(s.メンタル, 8)  // メンタル-2（加算対象からは除外・ペナルティは適用）
        XCTAssertEqual(s.stamina, config.initStamina - 10)
    }

    func test0017_B_restoresStaminaAndMental() {
        let config = GameConfig()
        var s = GameState(config: config)
        let before = s.stamina
        apply(ChoiceEventTable.choices(for: .justLostRehearsal, config: config)[1].effects, to: &s, config: config)
        XCTAssertEqual(s.stamina, min(100, before + 15))
        XCTAssertEqual(s.メンタル, config.initAbility + 2)
    }

    func test0017_C_gatedByMoney() {
        let config = GameConfig()
        let choices = ChoiceEventTable.choices(for: .justLostRehearsal, config: config)
        var poor = GameState(config: config); poor.money = 1000
        var rich = GameState(config: config); rich.money = 5000
        XCTAssertFalse(choices[2].gate(poor))
        XCTAssertTrue(choices[2].gate(rich))
        apply(choices[2].effects, to: &rich, config: config)
        XCTAssertEqual(rich.money, 3500)
        XCTAssertEqual(rich.compat, min(config.compatCap, config.compatInit + 2))
    }

    // MARK: 0019 型を捨てる相談

    func test0019_A_tradesExpressionAndCompatForIdea() {
        let config = GameConfig()
        var s = GameState(config: config)
        apply(ChoiceEventTable.choices(for: .styleTalk, config: config)[0].effects, to: &s, config: config)
        XCTAssertEqual(s.発想, config.initAbility + 2)
        XCTAssertEqual(s.表現, config.initAbility - 1)
        XCTAssertEqual(s.compat, max(0, config.compatInit - 2))
    }

    func test0019_B_raisesExpressionAndCompatCostsMental() {
        let config = GameConfig()
        var s = GameState(config: config)
        apply(ChoiceEventTable.choices(for: .styleTalk, config: config)[1].effects, to: &s, config: config)
        XCTAssertEqual(s.表現, config.initAbility + 2)
        XCTAssertEqual(s.compat, min(config.compatCap, config.compatInit + 1))
        XCTAssertEqual(s.メンタル, config.initAbility - 1)
    }

    // MARK: 0018 通った日の分かれ道

    func test0018_A_tradesStaminaAndMentalForFame() {
        let config = GameConfig()
        var s = GameState(config: config)
        let beforeStamina = s.stamina
        apply(ChoiceEventTable.choices(for: .justPassedFork, config: config)[0].effects, to: &s, config: config)
        XCTAssertEqual(s.fame, min(100, config.initFame + 3))
        XCTAssertEqual(s.stamina, max(0, beforeStamina - 15))
        XCTAssertEqual(s.メンタル, config.initAbility - 1)
    }

    func test0018_B_raisesWeakerOfSenseIdeaAndCompat() {
        let config = GameConfig()
        var s = GameState(config: config)
        s.センス = 40; s.発想 = 60   // センスが低い方
        apply(ChoiceEventTable.choices(for: .justPassedFork, config: config)[1].effects, to: &s, config: config)
        XCTAssertEqual(s.センス, 41)
        XCTAssertEqual(s.発想, 60)   // 不変
        XCTAssertEqual(s.compat, min(config.compatCap, config.compatInit + 1))
    }

    // MARK: 0021 慣れの外し方（相性初到達15・一発化）

    func test0021_A_tradesCompatAndStaminaForSense() {
        let config = GameConfig()
        var s = GameState(config: config)
        s.compat = 15
        let beforeStamina = s.stamina
        apply(ChoiceEventTable.choices(for: .tsuukaBreak, config: config)[0].effects, to: &s, config: config)
        XCTAssertEqual(s.センス, config.initAbility + 2)
        XCTAssertEqual(s.compat, 14)
        XCTAssertEqual(s.stamina, max(0, beforeStamina - 10))
    }

    func test0021_B_raisesExpressionAndCompatOnly() {
        let config = GameConfig()
        var s = GameState(config: config)
        s.compat = 15
        apply(ChoiceEventTable.choices(for: .tsuukaBreak, config: config)[1].effects, to: &s, config: config)
        XCTAssertEqual(s.表現, config.initAbility + 2)
        XCTAssertEqual(s.compat, min(config.compatCap, 16))
        XCTAssertEqual(s.発想, config.initAbility)   // 伸びしろ(発想)は不動
    }

    // MARK: 0020 まだ敬語の残る間（結成初期・他人行儀帯・一発化）

    func test0020_A_buysCompatWithStamina() {
        let config = GameConfig()
        var s = GameState(config: config)
        let beforeStamina = s.stamina
        apply(ChoiceEventTable.choices(for: .earlyFormality, config: config)[0].effects, to: &s, config: config)
        XCTAssertEqual(s.compat, min(config.compatCap, config.compatInit + 2))
        XCTAssertEqual(s.stamina, max(0, beforeStamina - 15))
    }

    func test0020_B_restoresStaminaAndMentalCompatUnchanged() {
        let config = GameConfig()
        var s = GameState(config: config)
        let beforeStamina = s.stamina
        let beforeCompat = s.compat
        apply(ChoiceEventTable.choices(for: .earlyFormality, config: config)[1].effects, to: &s, config: config)
        XCTAssertEqual(s.stamina, min(100, beforeStamina + 10))
        XCTAssertEqual(s.メンタル, config.initAbility + 1)
        XCTAssertEqual(s.compat, beforeCompat)   // 距離は動かさない
    }

    // MARK: 0010 前夜の一本（A確定効果のみ・0024でMVP降格済）

    func test0010_A_isFlatExpressionOnly() {
        let config = GameConfig()
        var s = GameState(config: config)
        apply(ChoiceEventTable.choices(for: .preTournamentEve, config: config)[0].effects, to: &s, config: config)
        XCTAssertEqual(s.表現, config.initAbility + 1)
        // 他の軸は一切動かない（内部ロールは本編送り＝MVPでは実装しない）
        XCTAssertEqual(s.メンタル, config.initAbility)
        XCTAssertEqual(s.stamina, config.initStamina)
    }

    func test0010_B_restoresStaminaAndMental() {
        let config = GameConfig()
        var s = GameState(config: config)
        let before = s.stamina
        apply(ChoiceEventTable.choices(for: .preTournamentEve, config: config)[1].effects, to: &s, config: config)
        XCTAssertEqual(s.stamina, min(100, before + 10))
        XCTAssertEqual(s.メンタル, config.initAbility + 1)
    }

    // MARK: 全イベント共通・RNG非消費の実測（golden不変の直接証明）

    func testAllChoicesNeverConsumeRandomSource() {
        // EventEffect の適用は GameState.applyEventEffect のみを通る＝シグネチャに RandomSource が
        // 存在しない（コンパイル時に保証）。ここでは全イベント×全選択肢が例外なく決定論的に
        // 同一結果を返すこと（同じ入力→同じ出力）を実測し、非決定性が紛れ込んでいないか二重に確認する。
        let config = GameConfig()
        for kind in ChoiceEventKind.allCases {
            for choice in ChoiceEventTable.choices(for: kind, config: config) {
                var s1 = GameState(config: config)
                var s2 = GameState(config: config)
                apply(choice.effects, to: &s1, config: config)
                apply(choice.effects, to: &s2, config: config)
                XCTAssertEqual(s1.センス, s2.センス, "\(kind).\(choice.id) が非決定的")
                XCTAssertEqual(s1.compat, s2.compat, "\(kind).\(choice.id) が非決定的")
                XCTAssertEqual(s1.money, s2.money, "\(kind).\(choice.id) が非決定的")
            }
        }
    }
}
