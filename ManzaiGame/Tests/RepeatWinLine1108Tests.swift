// アプリ側の未カバー2つ（カバー率の点検 11/08）：優勝の夜の相方の一言 repeatWinLine・「年末へ」の条件 noStagesLeft
import XCTest
import GameCore
@testable import ManzaiGame

final class RepeatWinLine1108Tests: IsolatedStoreTestCase {
    private func rec(_ y: Int, champ: Bool) -> GameSession.YearRecord {
        GameSession.YearRecord(year: y, roundsPassed: champ ? 5 : 1, reachedFinal: champ, champion: champ, bankrupt: false, prize: 0)
    }
    /// 保存→SaveData を書き換え→復元（yearHistory は private(set) なので SaveData 経由で作る＝CoverageRAppTests と同じ）
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
        XCTAssertEqual(try session(history: [], year: 1).repeatWinLine, "やったね。本当に、日本一だよ")
        XCTAssertEqual(try session(history: [rec(1, champ: false), rec(2, champ: false)], year: 3).repeatWinLine, "やったね。本当に、日本一だよ")
    }
    func testBackToBack() throws {
        XCTAssertEqual(try session(history: [rec(1, champ: false), rec(2, champ: true)], year: 3).repeatWinLine, "やったね。今年も、日本一だよ")
    }
    func testComeback() throws {
        XCTAssertEqual(try session(history: [rec(1, champ: true), rec(2, champ: false)], year: 3).repeatWinLine, "やったね。もう一度、日本一だよ")
    }
    /// 今年の記録が先に積まれていても、今年の優勝は「過去の優勝」に数えない（初優勝のまま）
    func testThisYearRecordIsNotPast() throws {
        XCTAssertEqual(try session(history: [rec(1, champ: false), rec(2, champ: true)], year: 2).repeatWinLine, "やったね。本当に、日本一だよ")
    }

    func testNoStagesLeftMatchesUpcoming() {
        let s = GameSession(seed: 1)
        XCTAssertFalse(s.noStagesLeft)   // 1年目の第1週は GP の道が開いている
        XCTAssertEqual(s.noStagesLeft, s.upcomingStages().isEmpty)
    }
}

/// 購入の成否の分かれ目（券は所有にならないので handle の結果を返す）。カバー率の点検 11/08 で 0%
final class StoreIDsTicket1108Tests: XCTestCase {
    func testOnlyTicketsAreConsumable() {
        XCTAssertTrue(StoreIDs.isTicket(StoreIDs.ticket1))
        XCTAssertTrue(StoreIDs.isTicket(StoreIDs.ticket10))
        XCTAssertFalse(StoreIDs.isTicket(StoreIDs.adFree))
        XCTAssertFalse(StoreIDs.isTicket(StoreIDs.agency))
        XCTAssertFalse(StoreIDs.isTicket(""))
        XCTAssertEqual(Set(StoreIDs.all), Set([StoreIDs.adFree, StoreIDs.agency]).union(StoreIDs.ticketCounts.keys))   // 券の表と商品一覧がずれない
    }
}
