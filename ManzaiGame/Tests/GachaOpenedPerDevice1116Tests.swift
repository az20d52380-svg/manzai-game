// 購入分の開封数を端末ごとに持つ（iCloud 合流で残りが多く戻らない＝code_review_unreviewed_1115 #1・AUTOPILOT 439）
import XCTest
@testable import ManzaiGame

final class GachaOpenedPerDevice1116Tests: XCTestCase {
    /// 10回分を A で3・B で2 オフラインで回して合流→残り5（前は max で7だった）
    func testTwoDevicesOfflineBothSubtracted() {
        var base = GachaState(); base.freeTickets = 0
        base.credit(txID: "t1", count: 10)
        var a = base; a.openedBy["A"] = 3
        var b = base; b.openedBy["B"] = 2
        XCTAssertEqual(a.merged(with: b).paidPending, 5)
        XCTAssertEqual(b.merged(with: a).paidPending, 5)
    }

    /// 同じ端末の古い版と新しい版の合流は二重に引かない
    func testSameDeviceNotDoubleCounted() {
        var base = GachaState(); base.freeTickets = 0
        base.credit(txID: "t1", count: 10)
        var old = base; old.openedBy["A"] = 2
        var new = base; new.openedBy["A"] = 4
        XCTAssertEqual(old.merged(with: new).paidPending, 6)
        XCTAssertEqual(new.merged(with: new).paidPending, 6)
    }

    /// 回すとこの端末の行が増える
    func testPullIncrementsThisDevice() {
        var s = GachaState(); s.freeTickets = 0
        s.credit(txID: "t1", count: 2)
        var g = SeededGen(s: 1)
        XCTAssertNotNil(s.pullOne(&g))
        XCTAssertEqual(s.openedBy[GachaState.deviceKey], 1)
        XCTAssertEqual(s.paidOpened, 1); XCTAssertEqual(s.paidPending, 1)
    }

    /// 旧形式（開封の合計だけ）は固定の行へ移り、合計も書き出す（前の版のアプリが読んでも合う）
    func testLegacyDecodeAndSumEncoded() throws {
        let json = #"{"ledger":{"t1":5},"paidOpened":3,"freeTickets":0}"#.data(using: .utf8)!
        let s = try JSONDecoder().decode(GachaState.self, from: json)
        XCTAssertEqual(s.openedBy, [GachaState.legacyOpenedKey: 3])
        XCTAssertEqual(s.paidPending, 2)
        let out = try JSONSerialization.jsonObject(with: JSONEncoder().encode(s)) as? [String: Any]
        XCTAssertEqual(out?["paidOpened"] as? Int, 3)
        let back = try JSONDecoder().decode(GachaState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back, s)
    }
}
