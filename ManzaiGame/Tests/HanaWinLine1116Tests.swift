// THE HANA 優勝の夜の相方の一言 hanaWinLine（初・連覇・返り咲き＝頂GP の repeatWinLine と同じ型）
import XCTest
import GameCore
@testable import ManzaiGame

final class HanaWinLine1116Tests: IsolatedStoreTestCase {
    private func rec(_ y: Int, hana: String?) -> GameSession.YearRecord {
        var r = GameSession.YearRecord(year: y, roundsPassed: 1, reachedFinal: false, champion: false, bankrupt: false, prize: 0)
        r.hanaReach = hana
        return r
    }
    private func session(history: [GameSession.YearRecord], year: Int) throws -> GameSession {
        let s0 = GameSession(seed: 1)
        s0.saveNow()
        let data = try XCTUnwrap(GameSession.store.data(forKey: "manzai.save.v1"))
        var save = try JSONDecoder().decode(GameSession.SaveData.self, from: data)
        save.yearHistory = history
        save.runner.year = year
        return GameSession(restoring: save)
    }

    func testFirstWin() throws {
        XCTAssertEqual(try session(history: [], year: 1).hanaWinLine, "やったね。本当に、やったね")
        XCTAssertEqual(try session(history: [rec(1, hana: "THE HANA 決勝 敗退")], year: 2).hanaWinLine, "やったね。本当に、やったね")
    }
    func testBackToBack() throws {
        XCTAssertEqual(try session(history: [rec(1, hana: "THE HANA 優勝")], year: 2).hanaWinLine, "やったね。今年も、優勝だよ")
    }
    func testAgain() throws {
        XCTAssertEqual(try session(history: [rec(1, hana: "THE HANA 優勝"), rec(2, hana: nil)], year: 3).hanaWinLine, "やったね。もう一度、優勝だよ")
    }
}
