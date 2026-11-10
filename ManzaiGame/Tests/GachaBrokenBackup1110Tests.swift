// 候補 gacha-broken-backup：端末のガチャの保存が読めない時、上書きの前に元データを別キーへ退避する
import XCTest
@testable import ManzaiGame

final class GachaBrokenBackup1110Tests: XCTestCase {
    private func suite() -> UserDefaults { UserDefaults(suiteName: "gbb1110-\(UUID().uuidString)")! }

    @MainActor func testUnreadableDataIsKeptAsideBeforeOverwrite() {
        let d = suite()
        let junk = Data("{壊れ".utf8)
        d.set(junk, forKey: GachaStore.key)
        let s = GachaStore(defaults: d, useCloud: false)
        XCTAssertEqual(s.state, GachaState())
        s.mutate { $0.totalPulls += 1 }                       // 次の保存で本キーは上書きされる
        XCTAssertEqual(d.data(forKey: GachaStore.brokenKey), junk)
    }

    @MainActor func testFirstBackupIsNotOverwrittenBySecondFailure() {
        let d = suite()
        let first = Data("first".utf8)
        d.set(first, forKey: GachaStore.key)
        _ = GachaStore(defaults: d, useCloud: false)
        d.set(Data("second".utf8), forKey: GachaStore.key)
        _ = GachaStore(defaults: d, useCloud: false)
        XCTAssertEqual(d.data(forKey: GachaStore.brokenKey), first)   // 先に壊れた方（購入の台帳が残っている見込みが高い）を残す
    }

    @MainActor func testReadableDataMakesNoBackup() throws {
        let d = suite()
        var g = GachaState(); g.totalPulls = 4
        d.set(try JSONEncoder().encode(g), forKey: GachaStore.key)
        _ = GachaStore(defaults: d, useCloud: false)
        XCTAssertNil(d.data(forKey: GachaStore.brokenKey))
    }
}
