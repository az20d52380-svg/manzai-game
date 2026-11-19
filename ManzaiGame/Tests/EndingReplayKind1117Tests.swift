import XCTest
import GameCore
@testable import ManzaiGame

/// 図鑑の読み返しで、見た時のコンビの形を使う（code_review_endings_meta_1117 #1・表示のみ）
final class EndingReplayKind1117Tests: XCTestCase {
    private var saved: UserDefaults!
    private var savedKind: ComboKind = .maleMale
    override func setUp() {
        saved = GameSession.store
        savedKind = Names.kind
        GameSession.store = UserDefaults(suiteName: "erk1117-\(UUID().uuidString)")!
    }
    override func tearDown() { GameSession.store = saved; Names.setKind(savedKind) }

    func testRecordKeepsComboKind() throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["MZ_BOOKSEEN"] != nil)
        EndingBook.record(.breakup, partner: "花子", kind: .femaleFemale)
        XCTAssertEqual(EndingBook.load()[.breakup]?.lastComboKind, ComboKind.femaleFemale.rawValue)
        EndingBook.record(.breakup, partner: "太郎", kind: .maleFemale)
        let r = EndingBook.load()[.breakup]
        XCTAssertEqual(r?.count, 2)
        XCTAssertEqual(r?.lastComboKind, ComboKind.maleFemale.rawValue, "最後に見た形で上書き")
    }

    func testOldRecordWithoutKindIsMaleMale() throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["MZ_BOOKSEEN"] != nil)
        let old = #"{"breakup":{"count":1,"firstSeenAt":0,"lastPartnerName":"谷口"}}"#
        GameSession.store.set(Data(old.utf8), forKey: EndingBook.key)
        let r = EndingBook.load()[.breakup]
        XCTAssertEqual(r?.count, 1, "旧データも読める")
        XCTAssertNil(r?.lastComboKind)
        XCTAssertEqual(ComboKind.from(r?.lastComboKind), .maleMale)
    }
}
