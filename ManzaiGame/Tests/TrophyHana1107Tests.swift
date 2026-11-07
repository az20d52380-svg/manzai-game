// 六冠の年の数え方（THE HANA は勝ち上がり戦＝1大会）と、THE HANA の優勝の記録
import XCTest
import GameCore
@testable import ManzaiGame

final class TrophyHana1107Tests: XCTestCase {
    private var saved: UserDefaults!
    override func setUp() {
        saved = GameSession.store
        let d = UserDefaults(suiteName: "mz.trophyhana.test")!
        d.removePersistentDomain(forName: "mz.trophyhana.test")
        GameSession.store = d
    }
    override func tearDown() { GameSession.store = saved }

    private func count(_ results: [(String, Bool)]) -> (entered: Int, won: Int) {
        results.reduce((entered: 0, won: 0)) { sum, x in
            let c = TrophyBook.smallTournamentCount(StageResult(name: x.0, passed: x.1, prize: 0))
            return (sum.entered + c.entered, sum.won + c.won)
        }
    }

    func testHanaIsOneTournamentWhenWonOutright() {
        let c = count([("HANA1回戦", true), ("HANA2回戦", true), ("HANA準決勝", true), ("HANA決勝", true)])
        XCTAssertEqual(c.entered, 1)
        XCTAssertEqual(c.won, 1)
    }

    /// 通過だけでは優勝に数えない（途中で負けると「全部優勝」にならない）
    func testHanaLossBreaksAllWins() {
        let c = count([("春新人賞A", true), ("HANA1回戦", true), ("HANA2回戦", false)])
        XCTAssertEqual(c.entered, 2)
        XCTAssertEqual(c.won, 1)
    }

    /// 道中1大会＋HANA の回戦だけでは5大会に届かない（直す前は届いて六冠が取れた）
    func testHanaRoundsDoNotReachFiveEntries() {
        let c = count([("春新人賞A", true), ("HANA1回戦", true), ("HANA2回戦", true), ("HANA準決勝", true), ("HANA決勝", true)])
        XCTAssertEqual(c.entered, 2)
    }

    func testGPAndRevivalAreNotCounted() {
        let c = count([("GP1回戦", true), ("敗者復活", true), ("GP決勝", true)])
        XCTAssertEqual(c.entered, 0)
        XCTAssertEqual(c.won, 0)
    }

    func testHanaWinIsRecordedOnlyOnFinalPass() {
        XCTAssertNil(TrophyBook.loadRecords().hanaWins)
        let st = GameState(config: GameConfig())
        TrophyBook.onStage(StageResult(name: "HANA準決勝", passed: true, prize: 0), state: st, config: GameConfig())
        TrophyBook.onStage(StageResult(name: "HANA決勝", passed: false, prize: 0), state: st, config: GameConfig())
        XCTAssertNil(TrophyBook.loadRecords().hanaWins)
        TrophyBook.onStage(StageResult(name: "HANA決勝", passed: true, prize: 0), state: st, config: GameConfig())
        XCTAssertEqual(TrophyBook.loadRecords().hanaWins, 1)
    }

    /// 日程の表示名は結果画面と同じ「THE HANA 1回戦」（他の大会は名前のまま）
    func testHanaStageDisplayNames() {
        XCTAssertEqual(GPName.display("HANA1回戦"), "THE HANA 1回戦")
        XCTAssertEqual(GPName.display("春新人賞A"), "春新人賞A")
        let s = GameSession(comboKind: .femaleFemale)
        let names = s.upcomingStages().map(\.name)
        XCTAssertTrue(names.contains("THE HANA 1回戦"), "\(names)")
        XCTAssertFalse(names.contains("HANA1回戦"))
    }

    /// 年表の THE HANA の行は、その年の最後の結果
    func testHanaReachFromLog() {
        XCTAssertNil(GameSession.hanaReach(log: ["第12週: 春新人賞A 優勝 +50万"]))
        XCTAssertEqual(GameSession.hanaReach(log: ["第32週: THE HANA 1回戦 通過", "第37週: THE HANA 2回戦 敗退"]), "THE HANA 2回戦 敗退")
        XCTAssertEqual(GameSession.hanaReach(log: ["第32週: THE HANA 1回戦 通過"]), "THE HANA 1回戦 通過")
        XCTAssertEqual(GameSession.hanaReach(log: ["第44週: THE HANA 決勝 優勝 +250万"]), "THE HANA 優勝")
        XCTAssertEqual(GameSession.hanaReach(log: ["第44週: THE HANA 決勝 敗退"]), "THE HANA 決勝 敗退")
    }

    /// 図鑑の分母は「今取れる物」だけ（取れない T19・T20 を数えると全部そろわない）
    func testObtainableCountIsTwenty() {
        XCTAssertEqual(TrophyID.allCases.filter(\.obtainable).count, 21)
    }

    /// 旧データ（hanaWins の鍵なし）も読める
    func testOldRecordsDecode() throws {
        let old = #"{"totalWins":2,"bestStreak":1,"fastestWinYear":3}"#.data(using: .utf8)!
        let r = try JSONDecoder().decode(CareerRecords.self, from: old)
        XCTAssertEqual(r.totalWins, 2)
        XCTAssertNil(r.hanaWins)
    }
}
