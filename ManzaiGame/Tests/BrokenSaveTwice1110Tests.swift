// セーブ互換の点検 案4（save_compat_audit_1108）：壊れたセーブが2回続いた時の退避の中身を固定する。
// 今の挙動＝退避は1枠（manzai.save.v1.broken）で、2回目は上書き（1回目の中身は残らない）。
// 直す／一言出す／戻すボタンはオーナー判断（キュー154）。挙動を変えたらこのテストを直す。
import XCTest
import GameCore
@testable import ManzaiGame

final class BrokenSaveTwice1110Tests: IsolatedStoreTestCase {
    private let saveKey = "manzai.save.v1"

    func testSecondBrokenSaveOverwritesTheSingleBackupSlot() {
        let junk1 = Data("broken-1".utf8)
        let junk2 = Data("{\"half\":".utf8)
        GameSession.store.set(junk1, forKey: saveKey)
        _ = GameSession.loadedOrNew()
        XCTAssertEqual(GameSession.store.data(forKey: saveKey + ".broken"), junk1)

        GameSession.store.set(junk2, forKey: saveKey)
        let s = GameSession.loadedOrNew()
        XCTAssertNil(GameSession.store.data(forKey: saveKey))
        XCTAssertEqual(GameSession.store.data(forKey: saveKey + ".broken"), junk2)   // 1回目は上書きで消える
        XCTAssertFalse(s.finished)
    }

    func testGoodSaveAfterBrokenOneLeavesBackupUntouched() {
        let junk = Data("broken".utf8)
        GameSession.store.set(junk, forKey: saveKey)
        let fresh = GameSession.loadedOrNew()
        fresh.saveNow()                                   // 新規の周で普通に保存
        XCTAssertNotNil(GameSession.store.data(forKey: saveKey))
        let again = GameSession.loadedOrNew()             // 正常に読めれば退避には触らない
        XCTAssertFalse(again.finished)
        XCTAssertEqual(GameSession.store.data(forKey: saveKey + ".broken"), junk)
    }
}
