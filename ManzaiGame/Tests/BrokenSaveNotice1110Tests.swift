// 候補 broken-save-notice（キュー154 推奨形）：退避を2枠にし、読めなかった起動を印で知らせる
import XCTest
import GameCore
@testable import ManzaiGame

final class BrokenSaveNotice1110Tests: IsolatedStoreTestCase {
    private let saveKey = "manzai.save.v1"

    func testTwoFailuresKeepBothBackups() {
        let a = Data("broken-a".utf8), b = Data("broken-b".utf8)
        GameSession.store.set(a, forKey: saveKey)
        _ = GameSession.loadedOrNew()
        XCTAssertTrue(GameSession.lastLoadFailed)
        GameSession.store.set(b, forKey: saveKey)
        _ = GameSession.loadedOrNew()
        XCTAssertEqual(GameSession.store.data(forKey: saveKey + ".broken"), b)
        XCTAssertEqual(GameSession.store.data(forKey: saveKey + ".broken2"), a)
    }

    func testFlagClearsOnCleanStart() {
        GameSession.store.set(Data("x".utf8), forKey: saveKey)
        _ = GameSession.loadedOrNew()
        XCTAssertTrue(GameSession.lastLoadFailed)
        _ = GameSession.loadedOrNew()                       // 本キーは消えている＝普通の新規
        XCTAssertFalse(GameSession.lastLoadFailed)
    }

    func testGoodSaveDoesNotRaiseFlag() {
        GameSession(startState: GameSession.debugNetaState()).saveNow()
        let s = GameSession.loadedOrNew()
        XCTAssertTrue(s.isRestored)
        XCTAssertFalse(GameSession.lastLoadFailed)
    }
}
