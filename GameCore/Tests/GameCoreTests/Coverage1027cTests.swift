// Coverage1027cTests.swift
// 未カバーだった境界を固定（テストのみ・本体/式/乱数/golden は不変）。
import XCTest
@testable import GameCore

final class Coverage1027cTests: XCTestCase {
    let config = GameConfig()

    // blurWidth: メンタル100→5・0→20・50→12.5（線形）
    func testBlurWidthLinearEndpoints() {
        XCTAssertEqual(GameEngine.blurWidth(mental: 100), 5, accuracy: 1e-12)
        XCTAssertEqual(GameEngine.blurWidth(mental: 0), 20, accuracy: 1e-12)
        XCTAssertEqual(GameEngine.blurWidth(mental: 50), 12.5, accuracy: 1e-12)
    }

    // roomRent: 部屋0・範囲外（負・上限超え）は 0、有効段は表の値
    func testRoomRentOutOfRangeIsZero() {
        var s = GameState(config: config)
        s.room = nil
        XCTAssertEqual(GameEngine.roomRent(s, config: config), 0)
        s.room = 0
        XCTAssertEqual(GameEngine.roomRent(s, config: config), 0)
        s.room = 1
        XCTAssertEqual(GameEngine.roomRent(s, config: config), config.roomRents[1])
        s.room = -1
        XCTAssertEqual(GameEngine.roomRent(s, config: config), 0)
        s.room = config.roomRents.count
        XCTAssertEqual(GameEngine.roomRent(s, config: config), 0)
    }

    // canMoveRoom: 範囲外は不可・同じ段/下げるは常に可・上げるは所持金ちょうどで可、1円足りないと不可
    func testCanMoveRoomBounds() {
        var s = GameState(config: config)
        s.room = 1
        s.money = 0
        XCTAssertFalse(GameEngine.canMoveRoom(to: -1, state: s, config: config))
        XCTAssertFalse(GameEngine.canMoveRoom(to: config.roomRents.count, state: s, config: config))
        XCTAssertTrue(GameEngine.canMoveRoom(to: 1, state: s, config: config))
        XCTAssertTrue(GameEngine.canMoveRoom(to: 0, state: s, config: config))
        s.money = config.roomRents[2] - 1
        XCTAssertFalse(GameEngine.canMoveRoom(to: 2, state: s, config: config))
        s.money = config.roomRents[2]
        XCTAssertTrue(GameEngine.canMoveRoom(to: 2, state: s, config: config))
    }

    // rollInvite: 率0→nil・率1なら必ず来る・同じ入力は同じ結果（決定論）
    func testRollInviteRateZeroAndOneAndDeterminism() {
        var c = config
        c.inviteRate = 0
        XCTAssertNil(GameEngine.rollInvite(seed: 42, year: 1, week: 1, config: c))
        c.inviteRate = 1
        for w in 1...5 {
            XCTAssertNotNil(GameEngine.rollInvite(seed: 42, year: 1, week: w, config: c))
        }
        let a = GameEngine.rollInvite(seed: 7, year: 3, week: 9, config: c)
        let b = GameEngine.rollInvite(seed: 7, year: 3, week: 9, config: c)
        XCTAssertEqual(a, b)
    }

    // offerFatigued: 窓内の件数が K 未満→false、K 件→true、窓外は数えない
    func testOfferFatiguedWindowBoundary() {
        var s = GameState(config: config)
        let k = config.offerFatigueK, w = config.offerFatigueWindow
        s.offerWeeks = nil
        XCTAssertFalse(GameEngine.offerFatigued(state: s, atWeek: 50, config: config))
        s.offerWeeks = Array(repeating: 50 - 1, count: k)
        XCTAssertTrue(GameEngine.offerFatigued(state: s, atWeek: 50, config: config))
        s.offerWeeks = Array(repeating: 50 - w, count: k)   // ちょうど窓の外
        XCTAssertFalse(GameEngine.offerFatigued(state: s, atWeek: 50, config: config))
    }
}
