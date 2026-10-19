// CoverageTTests.swift
// 生活費×部屋×やりくり上手／moveRoom の境界／テレビ慣れの境目／applyRest の回数券。Sources は不変。

import XCTest
@testable import GameCore

final class CoverageTTests: XCTestCase {
    let cfg = GameConfig()

    func testLivingCostDueCombinesSkillAndRoom() {
        var s = GameState(config: cfg)
        XCTAssertEqual(GameEngine.livingCostDue(s, config: cfg), 140_000)
        s.room = 1
        XCTAssertEqual(GameEngine.livingCostDue(s, config: cfg), 190_000)
        s.skills = [.やりくり上手]
        XCTAssertEqual(GameEngine.livingCostDue(s, config: cfg), 183_000)   // 133,000 + 50,000（割引は上乗せに掛からない）
        s.room = 2
        XCTAssertEqual(GameEngine.livingCostDue(s, config: cfg), 283_000)
    }

    func testMoveRoomBoundaries() {
        var s = GameState(config: cfg)
        s.money = 49_999
        XCTAssertFalse(GameEngine.moveRoom(to: 1, state: &s, config: cfg))
        XCTAssertNil(s.room)
        s.money = 50_000
        XCTAssertTrue(GameEngine.moveRoom(to: 1, state: &s, config: cfg))
        XCTAssertEqual(s.room, 1)
        XCTAssertEqual(s.money, 50_000)                                      // お金は引かない
        XCTAssertFalse(GameEngine.moveRoom(to: 3, state: &s, config: cfg))   // 範囲外
        XCTAssertFalse(GameEngine.moveRoom(to: -1, state: &s, config: cfg))
        s.money = 0
        XCTAssertTrue(GameEngine.moveRoom(to: 1, state: &s, config: cfg))    // 同じ段は常に可
        XCTAssertTrue(GameEngine.moveRoom(to: 0, state: &s, config: cfg))    // 下げるのも可
        XCTAssertNil(s.room)                                                 // 0 は nil に戻る
    }

    func testOfferFatiguedBoundary() {
        var s = GameState(config: cfg)
        s.offerWeeks = [1, 2, 3, 4]
        XCTAssertTrue(GameEngine.offerFatigued(state: s, atWeek: 6, config: cfg))    // 差が最大5＜6：4回
        XCTAssertFalse(GameEngine.offerFatigued(state: s, atWeek: 7, config: cfg))   // 週1が差6で窓外：3回
        s.offerWeeks = [2, 3, 4]
        XCTAssertFalse(GameEngine.offerFatigued(state: s, atWeek: 5, config: cfg))   // 3回は足りない
        s.offerWeeks = nil
        XCTAssertFalse(GameEngine.offerFatigued(state: s, atWeek: 5, config: cfg))
    }

    func testApplyRestTicketOnlyConsumedWhenUsed() {
        var a = GameState(config: cfg)
        a.sentoTickets = 3
        var b = a
        GameEngine.applyRest(.完全休養, to: &a, config: cfg, useTicket: false)
        XCTAssertEqual(a.sentoTickets, 3)
        GameEngine.applyRest(.完全休養, to: &b, config: cfg)
        XCTAssertEqual(b.sentoTickets, 2)
        var z = GameState(config: cfg)
        GameEngine.applyRest(.完全休養, to: &z, config: cfg)
        XCTAssertNil(z.sentoTickets)                                         // 未購入は nil のまま
    }
}
