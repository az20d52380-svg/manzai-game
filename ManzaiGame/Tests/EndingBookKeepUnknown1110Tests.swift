// 候補 meta-lenient-load の続き（candidate_review_1110b 低）：record() が知らない番号・読めない1件を書き戻しで消さない
import XCTest
@testable import ManzaiGame

final class EndingBookKeepUnknown1110Tests: XCTestCase {
    private var saved: UserDefaults!
    override func setUp() {
        saved = GameSession.store
        GameSession.store = UserDefaults(suiteName: "ebku1110-\(UUID().uuidString)")!
    }
    override func tearDown() { GameSession.store = saved }

    func testRecordKeepsUnknownAndUnreadableEntriesInStorage() throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["MZ_BOOKSEEN"] != nil)
        let json = """
        {"breakup":{"count":2,"firstSeenAt":0,"lastPartnerName":"谷口"},
         "futureEnding":{"count":1,"firstSeenAt":0,"lastPartnerName":"谷口"},
         "keptGoing":{"count":"x","firstSeenAt":0,"lastPartnerName":"谷口"}}
        """
        GameSession.store.set(Data(json.utf8), forKey: EndingBook.key)
        EndingBook.record(.breakup, partner: "山本")
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(GameSession.store.data(forKey: EndingBook.key))) as? [String: Any])
        XCTAssertEqual(Set(obj.keys), ["breakup", "futureEnding", "keptGoing"], "知らない番号・読めない1件も残す")
        let got = EndingBook.load()
        XCTAssertEqual(got[.breakup]?.count, 3)
        XCTAssertEqual(got[.breakup]?.lastPartnerName, "山本")
    }

    func testRecordOnEmptyStoreWritesOneEntry() throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["MZ_BOOKSEEN"] != nil)
        EndingBook.record(.championPair, partner: "谷口")
        XCTAssertEqual(Set(EndingBook.load().keys), [.championPair])
        XCTAssertEqual(EndingBook.load()[.championPair]?.count, 1)
    }
}
