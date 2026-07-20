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

    // MARK: 0012 相性凍結（compatFreeze）— 増加だけ止める／減算は通す／週送りで減る／golden経路は恒等no-op

    func test0012_compatFreezeBlocksGrowthNotDecrement() {
        let config = GameConfig()   // compatGrows=true
        var s = GameState(config: config); s.compat = 10
        s.applyEventEffect(.compatFreeze(3), config: config)
        XCTAssertEqual(s.compatFreezeWeeks, 3)
        // 凍結中: 増加（ネタ合わせ相性+1相当）は乗らない
        GameEngine.add(.コンビ相性, 1, to: &s, config: config)
        XCTAssertEqual(s.compat, 10, "凍結中は相性の増加が止まる")
        // 凍結中でも減算（0019A の相性-2 等）は通す
        GameEngine.add(.コンビ相性, -2, to: &s, config: config)
        XCTAssertEqual(s.compat, 8, "凍結中でも減算は効く")
    }

    func test0012_compatFreezeDecrementsAndThaws() {
        let config = GameConfig()
        var r = WeekRunner(state: GameState(config: config), year: 1, config: config, rng: SplitMix64(seed: 1))
        r.applyEventEffects([.compatFreeze(2)])
        XCTAssertEqual(r.state.compatFreezeWeeks, 2)
        r.tickCompatFreeze(); XCTAssertEqual(r.state.compatFreezeWeeks, 1)
        r.tickCompatFreeze(); XCTAssertEqual(r.state.compatFreezeWeeks, 0)
        r.tickCompatFreeze(); XCTAssertEqual(r.state.compatFreezeWeeks, 0)   // 0 で頭打ち
        // 解凍後は相性が再び伸びる
        var s = r.state; s.compat = 10
        GameEngine.add(.コンビ相性, 1, to: &s, config: config)
        XCTAssertEqual(s.compat, 11, "解凍後は相性成長が戻る")
    }

    func test0012_noFreezeIsIdentityOnGoldenPath() {
        // golden 経路＝compatFreezeWeeks が常に0。このときゲートは一切効かず従来と同一（byte一致の根拠）。
        let config = GameConfig()
        var frozen = GameState(config: config); frozen.compat = 10   // freeze=0（既定）
        var plain = frozen
        GameEngine.add(.コンビ相性, 1, to: &frozen, config: config)
        plain.compat = min(config.compatCap, plain.compat + 1)   // ゲートが無い場合の期待挙動
        XCTAssertEqual(frozen.compat, plain.compat)
    }

    // MARK: 0016 ネタ合わせブースト（netaBoost）— revise を乗算／週送りで減る／golden経路は恒等no-op

    func test0016_netaBoostSetByEffect() {
        let config = GameConfig()
        var s = GameState(config: config)
        s.applyEventEffect(.netaBoostNextWeek(config.netaBoostWeeks), config: config)
        XCTAssertEqual(s.netaBoostWeeks, config.netaBoostWeeks)
        // 既にブースト中ならより長い方を残す（compatFreeze と同型）
        s.applyEventEffect(.netaBoostNextWeek(1), config: config)
        XCTAssertEqual(s.netaBoostWeeks, config.netaBoostWeeks, "短い方では上書きしない")
    }

    func test0016_netaBoostMultipliesReviseThenTicks() {
        let config = GameConfig()   // netaReviseGain=8, netaBoostMult=1.6, netaBoostWeeks=2
        var r = WeekRunner(state: GameState(config: config), year: 1, config: config, rng: SplitMix64(seed: 1))
        let id = r.applyNetaCreate(kata: .王道しゃべくり, lengthFit: [.中尺], name: "x")   // polish=30
        r.applyEventEffects([.netaBoostNextWeek(2)])
        XCTAssertEqual(r.state.netaBoostWeeks, 2)
        // ブースト中: 8×1.6=12.8 乗る（30→42.8）
        r.applyNetaRevise(id: id)
        XCTAssertEqual(r.state.netas[0].polish, 30 + config.netaReviseGain * config.netaBoostMult, accuracy: 1e-9)
        r.tickNetaBoost(); XCTAssertEqual(r.state.netaBoostWeeks, 1)
        r.tickNetaBoost(); XCTAssertEqual(r.state.netaBoostWeeks, 0)
        r.tickNetaBoost(); XCTAssertEqual(r.state.netaBoostWeeks, 0)   // 0 で頭打ち
        // 失効後: 素の 8 だけ乗る（42.8→50.8）
        let before = r.state.netas[0].polish
        r.applyNetaRevise(id: id)
        XCTAssertEqual(r.state.netas[0].polish, before + config.netaReviseGain, accuracy: 1e-9)
    }

    func test0016_noBoostIsIdentityOnGoldenPath() {
        // golden 経路＝netaBoostWeeks が常に0。このとき revise 乗算は ×1.0＝従来と同一（byte一致の根拠）。
        let config = GameConfig()
        var r = WeekRunner(state: GameState(config: config), year: 1, config: config, rng: SplitMix64(seed: 1))
        let id = r.applyNetaCreate(kata: .王道しゃべくり, lengthFit: [.中尺], name: "x")   // boost=0（既定）
        r.applyNetaRevise(id: id)
        XCTAssertEqual(r.state.netas[0].polish, 30 + config.netaReviseGain, accuracy: 1e-9, "ブースト0では素の上昇")
    }

    // MARK: Codable — 新規 inert フィールドがセーブ往復で保存される
    func testNetaBoostWeeksSurvivesCodableRoundTrip() throws {
        var s = GameState(config: GameConfig()); s.netaBoostWeeks = 2; s.compatFreezeWeeks = 3
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(back.netaBoostWeeks, 2)
        XCTAssertEqual(back.compatFreezeWeeks, 3)
    }
}
