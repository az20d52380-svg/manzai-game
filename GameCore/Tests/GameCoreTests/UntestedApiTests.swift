// UntestedApiTests.swift
// これまでテストで一度も触られていなかった公開関数の境界値・不変条件（今の振る舞いを固定するだけ・Sources は不変）。

import XCTest
@testable import GameCore

final class UntestedApiTests: XCTestCase {
    let cfg = GameConfig()

    // MARK: 乱数

    func testSplitMix64SameSeedSameSequenceAndInRange() {
        var a = SplitMix64(seed: 42), b = SplitMix64(seed: 42), c = SplitMix64(seed: 43)
        var diff = false
        for _ in 0..<200 {
            let x = a.nextUniform(), y = b.nextUniform(), z = c.nextUniform()
            XCTAssertEqual(x, y)
            XCTAssertTrue(x >= 0 && x < 1)
            if x != z { diff = true }
        }
        XCTAssertTrue(diff)
    }

    func testUniformInRangeMapsEndpoints() {
        var lo = FixedRandom(value: 0.0), hi = FixedRandom(value: 0.5)
        XCTAssertEqual(lo.uniform(in: 3...7), 3, accuracy: 1e-12)
        XCTAssertEqual(hi.uniform(in: 3...7), 5, accuracy: 1e-12)
        var r = SplitMix64(seed: 7)
        for _ in 0..<100 { let v = r.uniform(in: -2...2); XCTAssertTrue(v >= -2 && v <= 2) }
    }

    func testSplitMix64CodableResumeKeepsSequence() throws {
        var a = SplitMix64(seed: 9)
        _ = a.nextUniform(); _ = a.nextUniform()
        var b = try JSONDecoder().decode(SplitMix64.self, from: JSONEncoder().encode(a))
        for _ in 0..<20 { XCTAssertEqual(a.nextUniform(), b.nextUniform()) }
    }

    // MARK: 部屋

    func testMoveRoomBoundaries() {
        var s = GameState(config: cfg); s.money = 0
        XCTAssertFalse(GameEngine.moveRoom(to: -1, state: &s, config: cfg))
        XCTAssertFalse(GameEngine.moveRoom(to: cfg.roomRents.count, state: &s, config: cfg))
        XCTAssertFalse(GameEngine.moveRoom(to: 1, state: &s, config: cfg))     // 上乗せ1か月分が払えない
        XCTAssertNil(s.room)
        s.money = cfg.roomRents[1] - 1
        XCTAssertFalse(GameEngine.canMoveRoom(to: 1, state: s, config: cfg))
        s.money = cfg.roomRents[1]                                              // ちょうどは可
        XCTAssertTrue(GameEngine.moveRoom(to: 1, state: &s, config: cfg))
        XCTAssertEqual(s.room, 1)
        XCTAssertEqual(s.money, cfg.roomRents[1])                               // 移る時にお金は引かれない
    }

    func testMoveRoomDownIsFreeAndZeroClearsRoom() {
        var s = GameState(config: cfg); s.money = 0; s.room = 2
        XCTAssertTrue(GameEngine.moveRoom(to: 2, state: &s, config: cfg))       // 同じ段は常に可
        XCTAssertTrue(GameEngine.moveRoom(to: 1, state: &s, config: cfg))
        XCTAssertEqual(s.room, 1)
        XCTAssertTrue(GameEngine.moveRoom(to: 0, state: &s, config: cfg))
        XCTAssertNil(s.room)                                                    // 0 は nil に戻す（旧セーブと同じ形）
        XCTAssertEqual(GameEngine.roomRent(s, config: cfg), 0)
    }

    func testRunnerApplyRoomMoveMatchesEngineAndDoesNotTouchMoney() {
        var r = WeekRunner(state: GameState(config: cfg), year: 1, config: cfg, rng: SplitMix64(seed: 1))
        let before = r.state.money
        XCTAssertTrue(r.applyRoomMove(to: 1))
        XCTAssertEqual(r.state.room, 1)
        XCTAssertEqual(r.state.money, before)
        XCTAssertFalse(r.applyRoomMove(to: 99))
        XCTAssertEqual(r.state.room, 1)
    }

    // MARK: アイテム

    func testBuyFailureLeavesStateUnchanged() throws {
        var s = GameState(config: cfg); s.money = 2_999
        let snap = try JSONEncoder().encode(s)
        XCTAssertFalse(GameEngine.buy(.栄養ドリンク, to: &s, config: cfg))      // 3,000円に1円足りない
        XCTAssertEqual(try JSONEncoder().encode(s), snap)
    }

    func testDrinkStaminaClampsAt100AndStillCostsMoney() {
        var s = GameState(config: cfg); s.money = 10_000; s.stamina = 99
        XCTAssertTrue(GameEngine.buy(.栄養ドリンク, to: &s, config: cfg))
        XCTAssertEqual(s.stamina, 100, accuracy: 1e-9)
        XCTAssertEqual(s.money, 7_000)
    }

    func testShinkansenTicketCannotBeBoughtTwice() {
        var s = GameState(config: cfg); s.money = 3_000_000
        XCTAssertTrue(GameEngine.buy(.新幹線回数券, to: &s, config: cfg))
        let m = s.money
        XCTAssertFalse(GameEngine.buy(.新幹線回数券, to: &s, config: cfg))
        XCTAssertEqual(s.money, m)
        XCTAssertEqual(s.shinkansenActive, true)
    }

    func testRunnerApplyItemPurchaseDelegates() {
        var s = GameState(config: cfg); s.money = 5_000; s.stamina = 10
        var r = WeekRunner(state: s, year: 1, config: cfg, rng: SplitMix64(seed: 1))
        XCTAssertTrue(r.applyItemPurchase(.栄養ドリンク))
        XCTAssertEqual(r.state.stamina, 100, accuracy: 1e-9)                    // 年初に回復済み＝100 を超えない
        XCTAssertEqual(r.state.money, 2_000)
        XCTAssertFalse(r.applyItemPurchase(.中古のICレコーダー))               // 売らない物は買えない
    }

    func testReplayItemPurchasesRestoresStartThenBuysRemaining() {
        var start = GameState(config: cfg); start.money = 100_000; start.stamina = 20
        var r = WeekRunner(state: start, year: 1, config: cfg, rng: SplitMix64(seed: 1))
        _ = r.applyItemPurchase(.栄養ドリンク); _ = r.applyItemPurchase(.回復ドリンク大); _ = r.applyItemPurchase(.銭湯の回数券)
        r.replayItemPurchases(from: start, [.栄養ドリンク])                      // 後ろ2つを「戻す」
        XCTAssertEqual(r.state.money, 100_000 - 3_000)
        XCTAssertNil(r.state.sentoTickets)
        r.replayItemPurchases(from: start, [])
        XCTAssertEqual(r.state.money, 100_000)
    }

    func testReplayIgnoresUnaffordableItemsInsteadOfGoingNegative() {
        var start = GameState(config: cfg); start.money = 3_000
        var r = WeekRunner(state: start, year: 1, config: cfg, rng: SplitMix64(seed: 1))
        r.replayItemPurchases(from: start, [.栄養ドリンク, .栄養ドリンク])
        XCTAssertEqual(r.state.money, 0)                                        // 2本目は買えず無視
        XCTAssertEqual(r.state.itemCounts?[ShopItem.栄養ドリンク.rawValue], 1)
    }

    // MARK: 特技

    func testCanLearnExactCostBoundaryAndNoDoubleLearn() {
        var s = GameState(config: cfg)
        for c in Skill.愛され芸人.cost { s[currency: c.currency] = c.amount - 0.01 }
        XCTAssertFalse(GameEngine.canLearn(.愛され芸人, state: s))
        for c in Skill.愛され芸人.cost { s[currency: c.currency] = c.amount }
        XCTAssertTrue(GameEngine.canLearn(.愛され芸人, state: s))
        XCTAssertTrue(GameEngine.learnSkill(.愛され芸人, to: &s))
        XCTAssertTrue(s.has(.愛され芸人))
        for c in Skill.愛され芸人.cost { s[currency: c.currency] = 100 }
        XCTAssertFalse(GameEngine.canLearn(.愛され芸人, state: s))              // 覚え済みは不可
        XCTAssertFalse(GameEngine.learnSkill(.愛され芸人, to: &s))
        XCTAssertEqual(s.skills?.count, 1)
    }

    func testLearnSkillDeductsExactlyAndFailureChangesNothing() {
        var s = GameState(config: cfg)
        for c in ExpCurrency.allCases { s[currency: c] = 10 }
        XCTAssertTrue(GameEngine.learnSkill(.体が資本, to: &s))
        XCTAssertEqual(s[currency: .胆力], 10 - 4, accuracy: 1e-9)
        XCTAssertEqual(s[currency: .存在感], 10 - 3, accuracy: 1e-9)
        XCTAssertEqual(s[currency: .閃き], 10, accuracy: 1e-9)
        var poor = GameState(config: cfg)
        XCTAssertFalse(GameEngine.learnSkill(.相方思い, to: &poor))
        XCTAssertNil(poor.skills)
        XCTAssertEqual(poor[currency: .存在感], 0, accuracy: 1e-9)
    }

    func testRunnerApplyLearnSkill() {
        var s = GameState(config: cfg); s[currency: .存在感] = 6
        var r = WeekRunner(state: s, year: 1, config: cfg, rng: SplitMix64(seed: 1))
        XCTAssertTrue(r.applyLearnSkill(.愛され芸人))
        XCTAssertEqual(r.state[currency: .存在感], 0, accuracy: 1e-9)
        XCTAssertFalse(r.applyLearnSkill(.愛され芸人))
    }

    // MARK: 旅費・割り振り・オファー・ネタ選択

    func testTravelSpecMapsBothCases() {
        let cal = CalendarConfig()
        XCTAssertEqual(cal.travelSpec(.夜行バス).cost, cal.busTravel.cost)
        XCTAssertEqual(cal.travelSpec(.夜行バス).stamina, cal.busTravel.stamina)
        XCTAssertEqual(cal.travelSpec(.新幹線).cost, 30_000)
        XCTAssertEqual(cal.travelSpec(.新幹線).stamina, 0)
    }

    func testPourableZeroWithoutCurrencyAndNonNegative() {
        let s = GameState(config: cfg)
        for a in Ability.allCases { XCTAssertEqual(s.pourable(a, config: cfg), 0, accuracy: 1e-12) }
        var rich = GameState(config: cfg)
        for c in ExpCurrency.allCases { rich[currency: c] = 5 }
        for a in Ability.allCases { XCTAssertGreaterThanOrEqual(rich.pourable(a, config: cfg), 0) }
    }

    func testChooseOfferOutOfRangeOrNoPendingIsNoOp() {
        var r = WeekRunner(state: GameState(config: cfg), year: 1, config: cfg, rng: SplitMix64(seed: 1))
        let before = r.state
        r.chooseOffer(index: 0)                                                 // 保留が無ければ何も起きない
        r.chooseOffer(index: -1); r.chooseOffer(index: 99)
        XCTAssertNil(r.offerChoices)
        XCTAssertEqual(r.state.money, before.money)
    }

    func testApplyNetaSelect2SetsAndClears() {
        var r = WeekRunner(state: GameState(config: cfg), year: 1, config: cfg, rng: SplitMix64(seed: 1))
        r.applyNetaSelect2(id: 5)
        XCTAssertEqual(r.state.selectedNetaID2, 5)
        r.applyNetaSelect2(id: nil)
        XCTAssertNil(r.state.selectedNetaID2)
    }
}
