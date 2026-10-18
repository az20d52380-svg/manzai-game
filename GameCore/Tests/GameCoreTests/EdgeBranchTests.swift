// EdgeBranchTests.swift
// 端の条件（お金不足・体力0・上限張り付き・借金中）を「今の振る舞いのまま」固定するテスト。Sources は不変。

import XCTest
@testable import GameCore

final class EdgeBranchTests: XCTestCase {
    private let cfg = GameConfig()

    /// 有料稽古は所持金が足りなければ false を返し、状態は一切動かない
    func testPaidTrainingRefusedWhenBrokeLeavesStateUntouched() {
        var s = GameState(config: cfg)
        s.money = 79_999; s.stamina = 50
        XCTAssertFalse(GameEngine.applyTraining(.ネタ見せ会, to: &s, config: cfg))
        XCTAssertEqual(s.money, 79_999)
        XCTAssertEqual(s.stamina, 50, accuracy: 1e-9)
        XCTAssertEqual(s[currency: .間合い], 0, accuracy: 1e-9)
        s.money = 80_000   // ちょうどなら通る
        XCTAssertTrue(GameEngine.applyTraining(.ネタ見せ会, to: &s, config: cfg))
        XCTAssertEqual(s.money, 0)
    }

    /// 借金中（money<0）は通貨の獲得が debtTrainFactor 倍（体力消費は変わらない）
    func testDebtHalvesCurrencyGainButNotStamina() {
        var a = GameState(config: cfg); a.money = 0; a.stamina = 100
        var b = GameState(config: cfg); b.money = -1; b.stamina = 100
        GameEngine.applyTraining(.ネタ作り, to: &a, config: cfg)
        GameEngine.applyTraining(.ネタ作り, to: &b, config: cfg)
        let f = cfg.debtTrainFactor ?? 1
        XCTAssertGreaterThan(a[currency: .閃き], 0)
        XCTAssertEqual(b[currency: .閃き], a[currency: .閃き] * f, accuracy: 1e-9)
        XCTAssertEqual(a.stamina, b.stamina, accuracy: 1e-9)
    }

    /// 決勝進出の知名度：0以下は何もしない／逓減する／100で頭打ち
    func testAddFameBigGuardsAndTapers() {
        var s = GameState(config: cfg)
        s.fame = 40
        GameEngine.addFameBig(0, to: &s); GameEngine.addFameBig(-5, to: &s)
        XCTAssertEqual(s.fame, 40, accuracy: 1e-9)
        GameEngine.addFameBig(10, to: &s)
        XCTAssertEqual(s.fame, 46, accuracy: 1e-9)   // 40 + 10×(1−0.4)
        s.fame = 100
        GameEngine.addFameBig(10, to: &s)
        XCTAssertEqual(s.fame, 100, accuracy: 1e-9)
    }

    /// 優勝の知名度は逓減なし・0..100 にクランプ（負も通す）
    func testAddFameRawClampsBothEnds() {
        var s = GameState(config: cfg)
        s.fame = 95
        GameEngine.addFameRaw(20, to: &s)
        XCTAssertEqual(s.fame, 100, accuracy: 1e-9)
        GameEngine.addFameRaw(-250, to: &s)
        XCTAssertEqual(s.fame, 0, accuracy: 1e-9)
    }

    /// 通貨キーの add() は何もしない（設計上、通貨は creditCurrency だけが積む）
    func testAddCurrencyKeyIsNoOp() {
        var s = GameState(config: cfg)
        GameEngine.add(.currency(.閃き), 50, to: &s, config: cfg)
        XCTAssertEqual(s[currency: .閃き], 0, accuracy: 1e-9)
    }

    /// バイトは収入を足し、体力は0で止まる（マイナスにならない）
    func testJobIncomeAndStaminaFloor() {
        var s = GameState(config: cfg)
        s.money = 1_000; s.stamina = 10
        GameEngine.applyJob(.キツい, to: &s, config: cfg)
        XCTAssertEqual(s.money, 97_000)
        XCTAssertEqual(s.stamina, 0, accuracy: 1e-9)
    }

    /// 休み：useTicket:false なら回数券は減らず回復も上乗せされない
    func testRestWithoutTicketKeepsTicket() {
        var s = GameState(config: cfg)
        s.stamina = 0; s.sentoTickets = 2
        GameEngine.applyRest(.完全休養, to: &s, config: cfg, useTicket: false)
        XCTAssertEqual(s.sentoTickets, 2)
        XCTAssertEqual(s.stamina, 60, accuracy: 1e-9)
        GameEngine.applyRest(.完全休養, to: &s, config: cfg)   // 既定は使う
        XCTAssertEqual(s.sentoTickets, 1)
    }

    /// 有料の休みはお金が足りなければ完全休養にすり替わり、お金は減らない
    func testPaidRestFallsBackToFullRestWhenBroke() {
        var s = GameState(config: cfg)
        s.money = 9_999; s.stamina = 0
        let mental0 = s.メンタル
        GameEngine.applyRest(.サウナ, to: &s, config: cfg)
        XCTAssertEqual(s.money, 9_999)
        XCTAssertEqual(s.stamina, 60, accuracy: 1e-9)   // サウナ80ではなく完全休養60
        XCTAssertGreaterThan(s.メンタル, mental0)
    }

    /// ラインナップ外の品は買えず、足りない所持金のとき状態は不変
    func testBuyFailureIsAtomic() {
        var s = GameState(config: cfg)
        s.money = 0
        let before = s
        XCTAssertFalse(GameEngine.buy(.栄養ドリンク, to: &s, config: cfg))
        XCTAssertEqual(s.money, before.money)
        XCTAssertNil(s.itemCounts)
        s.money = 10_000_000
        XCTAssertFalse(GameEngine.buy(.ボイトレ短期集中, to: &s, config: cfg))   // ラインナップ外
        XCTAssertEqual(s.money, 10_000_000)
    }

    /// ラインナップに入れれば勉強会・ボイトレは通貨を直接足す（供給スケールは掛からない）
    func testStudyAndVoiceItemsCreditCurrencyDirectly() {
        var c = cfg
        c.shopLineup = [.ネタ作家の勉強会, .ボイトレ短期集中]
        var s = GameState(config: c)
        s.money = 10_000_000
        XCTAssertTrue(GameEngine.buy(.ネタ作家の勉強会, to: &s, config: c))
        XCTAssertEqual(s[currency: .閃き], c.itemStudyHirameki, accuracy: 1e-9)
        XCTAssertEqual(s[currency: .語彙], c.itemStudyGoi, accuracy: 1e-9)
        XCTAssertTrue(GameEngine.buy(.ボイトレ短期集中, to: &s, config: c))
        XCTAssertEqual(s[currency: .間合い], c.itemVoiceMaai, accuracy: 1e-9)
        XCTAssertEqual(s[currency: .語彙], c.itemStudyGoi + c.itemVoiceGoi, accuracy: 1e-9)
    }

    /// 稽古場の年契約とICレコーダーは稽古の主効果に生の量を足す（供給スケール後に反映）
    func testStudioAndRecorderBoostTrainingMain() {
        var base = GameState(config: cfg); base.stamina = 100
        var boosted = GameState(config: cfg); boosted.stamina = 100
        boosted.studioActive = true; boosted.hasRecorder = true
        GameEngine.applyTraining(.ネタ作り, to: &base, config: cfg)
        GameEngine.applyTraining(.ネタ作り, to: &boosted, config: cfg)
        let extra = (cfg.itemStudioBonus + cfg.itemRecorderBonus) * cfg.expSupplyScale
        XCTAssertEqual(boosted[currency: .閃き] - base[currency: .閃き], extra, accuracy: 1e-9)
    }
}
