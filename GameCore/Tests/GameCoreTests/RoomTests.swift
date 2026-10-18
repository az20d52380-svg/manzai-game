import XCTest
@testable import GameCore

/// キュー90：部屋を選ぶ（§90）。既定（安アパート）は今と完全に同一。
final class RoomTests: XCTestCase {
    let config = GameConfig()

    func testRentAddedToLivingCost() {
        var s = GameState(config: config); s.money = 1_000_000
        GameEngine.applyWeekEnd(week: 4, to: &s, config: config)
        XCTAssertEqual(s.money, 1_000_000 - 140_000)          // 安アパート＝上乗せ0
        s.money = 1_000_000; s.room = 1
        GameEngine.applyWeekEnd(week: 4, to: &s, config: config)
        XCTAssertEqual(s.money, 1_000_000 - 140_000 - 50_000)
        s.money = 1_000_000; s.room = 2
        GameEngine.applyWeekEnd(week: 3, to: &s, config: config)  // 生活費の週でなければ引かれない
        XCTAssertEqual(s.money, 1_000_000)
        GameEngine.applyWeekEnd(week: 8, to: &s, config: config)
        XCTAssertEqual(s.money, 1_000_000 - 140_000 - 150_000)
    }

    func testHomeRestRecoversMore() {
        var base = GameState(config: config); base.stamina = 20; base.メンタル = 50
        var r1 = base; r1.room = 1
        var r2 = base; r2.room = 2
        GameEngine.applyRest(.完全休養, to: &base, config: config, useTicket: false)
        GameEngine.applyRest(.完全休養, to: &r1, config: config, useTicket: false)
        GameEngine.applyRest(.完全休養, to: &r2, config: config, useTicket: false)
        XCTAssertEqual(r1.stamina - base.stamina, 10, accuracy: 0.001)
        XCTAssertEqual(r2.stamina - base.stamina, 20, accuracy: 0.001)
        XCTAssertGreaterThan(r2.メンタル, base.メンタル)   // いい部屋の完全休養はメンタルも上乗せ（add 経由）
        XCTAssertEqual(r1.メンタル, base.メンタル, accuracy: 0.001)
        var t = GameState(config: config); t.stamina = 20; t.room = 2     // 相方と過ごすは家の休みではない
        var u = t; u.room = nil
        GameEngine.applyRest(.相方と過ごす, to: &t, config: config, useTicket: false)
        GameEngine.applyRest(.相方と過ごす, to: &u, config: config, useTicket: false)
        XCTAssertEqual(t.stamina, u.stamina, accuracy: 0.001)
    }

    func testMoveRoomRulesAndOldSave() throws {
        var s = GameState(config: config); s.money = 30_000
        XCTAssertFalse(GameEngine.canMoveRoom(to: 1, state: s, config: config))   // 1か月分の上乗せが無い
        s.money = 50_000
        XCTAssertTrue(GameEngine.moveRoom(to: 1, state: &s, config: config))
        XCTAssertEqual(s.room, 1)
        s.money = -500_000                                                          // 下げるのはお金が無くても可
        XCTAssertTrue(GameEngine.moveRoom(to: 0, state: &s, config: config))
        XCTAssertNil(s.room)
        // 古いセーブ（room キー無し）は安アパート
        let data = try JSONEncoder().encode(GameState(config: config))
        var obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        obj.removeValue(forKey: "room")
        let old = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: obj))
        XCTAssertEqual(GameEngine.roomRent(old, config: config), 0)
    }
}
