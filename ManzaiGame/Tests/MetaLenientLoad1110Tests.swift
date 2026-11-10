import XCTest
@testable import ManzaiGame

/// 周回メタの読み込みを寛容に（save_compat_audit_1108 §足すべきテストの案 5）：
/// 1件・1鍵の型違いで図鑑や通算記録が丸ごと空に戻らないこと。
final class MetaLenientLoad1110Tests: XCTestCase {
    private var saved: UserDefaults!
    override func setUp() {
        saved = GameSession.store
        GameSession.store = UserDefaults(suiteName: "ml1110-\(UUID().uuidString)")!
    }
    override func tearDown() { GameSession.store = saved }

    func testEndingBookKeepsGoodRecordsWhenOneIsBroken() throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["MZ_BOOKSEEN"] != nil)
        let json = """
        {"breakup":{"count":2,"firstSeenAt":0,"lastPartnerName":"谷口"},
         "gaveUp":{"firstSeenAt":0,"lastPartnerName":"谷口"},
         "keptGoing":{"count":"x","firstSeenAt":0,"lastPartnerName":"谷口"}}
        """
        GameSession.store.set(Data(json.utf8), forKey: EndingBook.key)
        let got = EndingBook.load()
        XCTAssertEqual(Set(got.keys), [.breakup], "壊れた2件だけ捨て、正しい1件は残る")
        XCTAssertEqual(got[.breakup]?.count, 2)
        // 次の記録で正しい1件が消えない
        EndingBook.record(.championPair, partner: "谷口")
        XCTAssertEqual(Set(EndingBook.load().keys), [.breakup, .championPair])
    }

    func testCareerRecordsKeepsPresentKeys() throws {
        let env = ProcessInfo.processInfo.environment
        try XCTSkipIf(env["MZ_RECORDS"] != nil)
        // bestStreak が欠け、hanaWins が型違い、知らない鍵がある
        GameSession.store.set(Data(#"{"totalWins":3,"fastestWinYear":4,"hanaWins":"x","future":1}"#.utf8), forKey: TrophyBook.recordKey)
        XCTAssertEqual(TrophyBook.loadRecords(), CareerRecords(bestStreak: 0, fastestWinYear: 4, totalWins: 3, hanaWins: nil))
        // 全部そろった保存はそのまま往復する
        let full = CareerRecords(bestStreak: 2, fastestWinYear: 1, totalWins: 5, hanaWins: 1)
        GameSession.store.set(try JSONEncoder().encode(full), forKey: TrophyBook.recordKey)
        XCTAssertEqual(TrophyBook.loadRecords(), full)
    }
}
