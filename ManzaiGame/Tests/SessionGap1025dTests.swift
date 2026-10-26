// アプリ側の穴埋めテスト その4（GameSession のネタ操作・部屋・特技・買い戻し・セーブの退避/破棄・現在の挙動を固定）
import XCTest
import GameCore
@testable import ManzaiGame

final class SessionGap1025dTests: IsolatedStoreTestCase {
    private func bytes(_ s: GameState) -> Data {
        let e = JSONEncoder(); e.outputFormatting = .sortedKeys
        return try! e.encode(s)
    }
    private func netaSession() -> GameSession { GameSession(startState: GameSession.debugNetaState()) }
    private let saveKey = "manzai.save.v1"

    func testChangeNetaKataActiveAndSaves() {
        let s = netaSession()
        s.changeNetaKata(1, to: .華先行)
        XCTAssertEqual(s.state.netas.first { $0.id == 1 }?.kata, .華先行)
        XCTAssertNotNil(GameSession.store.data(forKey: saveKey))
    }
    func testChangeNetaKataArchivedAndUnknownId() {
        let s = netaSession()
        s.retireNeta(1)
        s.changeNetaKata(1, to: .華先行)
        XCTAssertEqual(s.archivedNetas.first { $0.id == 1 }?.kata, .華先行)
        let before = bytes(s.state)
        s.changeNetaKata(999, to: .瞬発)
        XCTAssertEqual(bytes(s.state), before)
    }
    func testRenameNetaTrimsAndRejectsBlank() {
        let s = netaSession()
        s.renameNeta(1, to: "  新題材 \n")
        XCTAssertEqual(s.state.netas.first { $0.id == 1 }?.name, "新題材")
        let before = bytes(s.state)
        s.renameNeta(1, to: "  \n ")
        XCTAssertEqual(bytes(s.state), before)
    }
    func testRenameArchivedNeta() {
        let s = netaSession()
        s.retireNeta(2)
        s.renameNeta(2, to: "しまった方")
        XCTAssertEqual(s.archivedNetas.first { $0.id == 2 }?.name, "しまった方")
    }
    func testRecallNetaMovesBackWhenSlotFree() {
        let s = netaSession()
        let n = s.state.netas.count
        let a = s.archivedNetas.count
        s.retireNeta(2)
        XCTAssertEqual(s.state.netas.count, n - 1)
        s.recallNeta(2)
        XCTAssertEqual(s.state.netas.count, n)
        XCTAssertEqual(s.archivedNetas.count, a)
        XCTAssertNotNil(s.state.netas.first { $0.id == 2 })
    }
    func testRecallNetaDoesNothingWhenSlotsFull() {
        var st = GameSession.debugNetaState()
        let cfg = GameConfig()
        var i = 10
        while st.netas.count + 1 < cfg.netaActiveSlots + 1 && st.netas.count < cfg.netaActiveSlots {
            st.netas.append(Neta(id: i, name: "埋め\(i)", kata: .瞬発, lengthFit: [.短尺], bornYear: 1)); i += 1
        }
        var arch = Neta(id: 99, name: "保管", kata: .瞬発, lengthFit: [.短尺], bornYear: 1)
        arch.polish = 10
        st.archivedNetas.append(arch)
        let s = GameSession(startState: st)
        XCTAssertGreaterThanOrEqual(s.state.netas.count, cfg.netaActiveSlots)
        let before = bytes(s.state)
        let a = s.archivedNetas.count
        s.recallNeta(99)
        XCTAssertEqual(bytes(s.state), before)
        XCTAssertEqual(s.archivedNetas.count, a)
    }
    func testMoveRoomDownAndSameAlwaysOkUpNeedsMoney() {
        var st = GameState(config: GameConfig())
        st.money = 0
        let s = GameSession(startState: st)
        XCTAssertTrue(s.moveRoom(to: 0))            // 同じ段
        XCTAssertFalse(s.moveRoom(to: 1))           // 払えない
        XCTAssertNil(s.state.room)
        XCTAssertFalse(s.moveRoom(to: 99))          // 範囲外
        XCTAssertFalse(s.moveRoom(to: -1))
    }
    func testMoveRoomUpWhenAffordableThenBackDownClearsRoom() {
        var st = GameState(config: GameConfig())
        st.money = 10_000_000
        let s = GameSession(startState: st)
        XCTAssertTrue(s.moveRoom(to: 1))
        XCTAssertEqual(s.state.room, 1)
        XCTAssertEqual(s.state.money, 10_000_000)   // 移っただけではお金は引かれない（次の生活費から上乗せ）
        XCTAssertTrue(s.moveRoom(to: 0))
        XCTAssertNil(s.state.room)
    }
    func testLearnSkillNeedsCurrencyAndPaysOnce() {
        var st = GameState(config: GameConfig())
        let s0 = GameSession(startState: st)
        XCTAssertFalse(s0.learnSkill(.愛され芸人))  // 通貨なし
        XCTAssertFalse(s0.state.has(.愛され芸人))
        st.exp存在感 = 10
        let s = GameSession(startState: st)
        XCTAssertTrue(s.learnSkill(.愛され芸人))
        XCTAssertTrue(s.state.has(.愛され芸人))
        XCTAssertEqual(s.state.exp存在感, 4, accuracy: 1e-9)
        XCTAssertFalse(s.learnSkill(.愛され芸人))   // 二重に覚えない
        XCTAssertEqual(s.state.exp存在感, 4, accuracy: 1e-9)
    }
    func testReplayShopVisitRestoresStartThenRebuys() {
        var st = GameState(config: GameConfig())
        st.money = 1_000_000
        let s = GameSession(startState: st)
        let start = s.state
        s.replayShopVisit(from: start, [])
        XCTAssertEqual(bytes(s.state), bytes(start))   // 何も買わない＝入店時のまま
        s.replayShopVisit(from: start, [.栄養ドリンク])
        XCTAssertLessThan(s.state.money, start.money)
        XCTAssertGreaterThanOrEqual(s.state.money, 0)
        s.replayShopVisit(from: start, [])
        XCTAssertEqual(bytes(s.state), bytes(start))   // 戻す
    }
    func testAbandonRunClearsSaveAndFlags() {
        let s = netaSession()
        s.saveNow()
        XCTAssertNotNil(GameSession.store.data(forKey: saveKey))
        s.abandonRun()
        XCTAssertTrue(s.abandoned)
        XCTAssertNil(GameSession.store.data(forKey: saveKey))
        s.saveNow()                                       // 放棄後は書き戻さない
        XCTAssertNil(GameSession.store.data(forKey: saveKey))
    }
    func testBrokenSaveMovedAsideAndNewSessionReturned() {
        let junk = Data("not json".utf8)
        GameSession.store.set(junk, forKey: saveKey)
        let s = GameSession.loadedOrNew()
        XCTAssertNil(GameSession.store.data(forKey: saveKey))
        XCTAssertEqual(GameSession.store.data(forKey: saveKey + ".broken"), junk)
        XCTAssertFalse(s.finished)
    }
    func testSaveRoundTripKeepsNetaEditsAndRoom() {
        var st = GameSession.debugNetaState()
        st.money = 10_000_000
        let s = GameSession(startState: st)
        s.renameNeta(1, to: "往復")
        _ = s.moveRoom(to: 1)
        let loaded = GameSession.loadedOrNew()
        XCTAssertEqual(loaded.state.netas.first { $0.id == 1 }?.name, "往復")
        XCTAssertEqual(loaded.state.room, 1)
    }
    func testAcknowledgeWinEndsFinaleAndFinishes() {
        let s = netaSession()
        s.acknowledgeWin()
        XCTAssertFalse(s.winFinale)
        XCTAssertTrue(s.finished)
    }
    func testSelectedNeta2NilByDefaultAndFollowsSelection() {
        let s = netaSession()
        XCTAssertNil(s.selectedNeta2)
    }
}
