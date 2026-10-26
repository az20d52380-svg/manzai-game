// アプリ側の追加テスト（bestRunLine / WeekHint 撮影週 / 観戦札の Codable / 書く対象 code_review_2026-10-25 §7a・§7c）
import XCTest
import GameCore
@testable import ManzaiGame

final class BestRunLineTests: IsolatedStoreTestCase {
    private func rec(_ y: Int, passed: Int = 0, final f: Bool = false, champ: Bool = false,
                     bank: Bool = false, entered: Bool? = nil, dissolved: Bool? = nil) -> GameSession.YearRecord {
        GameSession.YearRecord(year: y, roundsPassed: passed, reachedFinal: f, champion: champ, bankrupt: bank,
                               prize: 0, enteredGP: entered, dissolved: dissolved)
    }
    /// 保存→SaveData を書き換え→復元。yearHistory と進行中の年の到達（runner 側）を差し込む
    /// （yearHistory/runner は private(set) なので、本体を変えず SaveData 経由で作る）
    private func session(history: [GameSession.YearRecord], year: Int = 9, stage: Int = 0, finalist: Bool = false) throws -> GameSession {
        let s0 = GameSession(seed: 1)
        s0.saveNow()
        let data = try XCTUnwrap(GameSession.store.data(forKey: "manzai.save.v1"))
        var save = try JSONDecoder().decode(GameSession.SaveData.self, from: data)
        save.yearHistory = history
        save.runner.year = year
        save.runner.gpStage = stage
        save.runner.finalist = finalist
        return GameSession(restoring: save)
    }

    func testNoTournamentIsNil() throws {
        XCTAssertNil(try session(history: []).bestRunLine)
        XCTAssertNil(try session(history: [rec(1, entered: false)]).bestRunLine)   // 出ていない年は数えない
    }
    func testPicksBestFinishedYear() throws {
        let s = try session(history: [rec(1, passed: 2), rec(2, final: true), rec(3, champ: true), rec(4, final: true)])
        XCTAssertEqual(s.bestRunLine, "3年目　頂GP 優勝")
        let f = try session(history: [rec(1, passed: 4), rec(2, final: true)])
        XCTAssertEqual(f.bestRunLine, "2年目　頂GP 決勝")
        let r = try session(history: [rec(1, passed: 1), rec(2, passed: 3)])
        XCTAssertEqual(r.bestRunLine, "2年目　頂GP 準々決勝敗退")
    }
    func testTieGoesToEarlierYear() throws {
        let s = try session(history: [rec(2, passed: 2), rec(1, passed: 2)])
        XCTAssertEqual(s.bestRunLine, "1年目　頂GP 3回戦敗退")
    }
    func testInProgressYearSaysPassedNotEliminated() throws {
        let s = try session(history: [rec(1, passed: 1)], year: 2, stage: 2)
        XCTAssertEqual(s.bestRunLine, "2年目　頂GP 2回戦通過")
        XCTAssertFalse(s.bestRunLine!.contains("敗退"))
        let f = try session(history: [rec(1, passed: 1)], year: 2, stage: 5, finalist: true)
        XCTAssertEqual(f.bestRunLine, "2年目　頂GP 決勝進出")
    }
    func testBankruptAndDissolvedCompareByReach() throws {
        let s = try session(history: [rec(1, passed: 1), rec(2, passed: 3, bank: true), rec(3, final: true, dissolved: true)])
        XCTAssertEqual(s.bestRunLine, "3年目　頂GP 決勝")   // 「夜逃げ」「解散」ではなく到達で言う
        let b = try session(history: [rec(1, passed: 3, bank: true)])
        XCTAssertEqual(b.bestRunLine, "1年目　頂GP 準々決勝敗退")
    }
}

final class WeekHintPreoccupiedTests: XCTestCase {
    private func base() -> WeekHint.Input {
        .init(netaCount: 2, stageWeeksLeft: 10, stageLength: .中尺, netaFitsStage: true, stamina: 80,
              livingThisWeek: false, money: 500_000, livingCost: 140_000, weeksWithoutPartner: 0,
              plusAvailable: false, expBannerShown: false)
    }
    func testPreoccupiedBeatsNoNeta() {
        var i = base(); i.netaCount = 0; i.preoccupied = true
        XCTAssertEqual(WeekHint.line(i), "今週は撮影の仕事で、稽古には出られない。")
        i.preoccupied = false
        XCTAssertEqual(WeekHint.line(i), "まだネタがない。まずはネタを書こう。")
    }
    func testLivingShortfallBeatsPreoccupied() {
        var i = base(); i.preoccupied = true; i.livingThisWeek = true; i.money = 100_000
        XCTAssertEqual(WeekHint.line(i), "今週末に生活費。所持金が足りない。")
    }
}

final class WatchedFinalCodableTests: XCTestCase {
    func testRoundTripKeepsWatchedFinal() throws {
        var r = GameSession.YearRecord(year: 3, roundsPassed: 2, reachedFinal: false, champion: false, bankrupt: false, prize: 0)
        XCTAssertNil(r.watchedFinal)
        r.watchedFinal = true
        let back = try JSONDecoder().decode(GameSession.YearRecord.self, from: JSONEncoder().encode(r))
        XCTAssertEqual(back.watchedFinal, true)
        XCTAssertEqual(back, r)
    }
    func testLegacyDataIsNil() throws {
        let json = #"{"year":1,"roundsPassed":2,"reachedFinal":false,"champion":false,"bankrupt":false,"prize":0}"#
        let r = try JSONDecoder().decode(GameSession.YearRecord.self, from: Data(json.utf8))
        XCTAssertNil(r.watchedFinal)
    }
}

final class WriteTargetTests: IsolatedStoreTestCase {
    func testRetireClearsWriteTarget() {
        let s = GameSession(startState: GameSession.debugNetaState())
        s.setWriteNeta(2)
        XCTAssertEqual(s.writeNetaID, 2)
        s.retireNeta(2)
        XCTAssertNil(s.writeNetaID)
        XCTAssertNotEqual(s.writeTargetID, 2)
    }
    func testNewWriteDroppedWhenSlotsFull() {
        var st = GameSession.debugNetaState()
        var extra = Neta(id: 4, name: "満席", kata: .瞬発, lengthFit: [.短尺], bornYear: 1)
        extra.polish = 20
        st.netas.append(extra); st.nextNetaID = 5
        let s = GameSession(startState: st)
        s.beginNewWrite()
        XCTAssertTrue(s.writeNewNeta)
        s.debugFreeWeeks(1, .train(.ネタ作り))
        XCTAssertFalse(s.writeNewNeta)
        XCTAssertEqual(s.activeNetas.count, 4)   // 枠は増えない
    }
}
