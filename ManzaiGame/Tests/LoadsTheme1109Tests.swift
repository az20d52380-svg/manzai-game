import XCTest
import SwiftUI
import GameCore
@testable import ManzaiGame

/// 未カバー分（11/09 定期・カバレッジで拾った）：
/// ①図鑑（エンディング）・通算記録の読み込みが壊れた保存・知らない鍵で落ちず空に戻ること
/// ②Theme の1文字ラベル（色弱対応＝色だけで区別させない）が能力・通貨ごとに重ならないこと
final class LoadsTheme1109Tests: XCTestCase {
    private var saved: UserDefaults!
    override func setUp() {
        saved = GameSession.store
        GameSession.store = UserDefaults(suiteName: "lt1109-\(UUID().uuidString)")!
    }
    override func tearDown() { GameSession.store = saved }

    // MARK: ① 読み込み
    func testEndingBookBrokenDataIsEmpty() throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["MZ_BOOKSEEN"] != nil)
        XCTAssertTrue(EndingBook.load().isEmpty, "未保存")
        GameSession.store.set(Data("not json".utf8), forKey: EndingBook.key)
        XCTAssertTrue(EndingBook.load().isEmpty, "壊れた保存")
    }

    func testEndingBookDropsUnknownKeys() throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["MZ_BOOKSEEN"] != nil)
        let rec = EndingRecord(count: 2, firstSeenAt: Date(timeIntervalSince1970: 0), lastPartnerName: "谷口")
        let raw: [String: EndingRecord] = [EndingID.breakup.rawValue: rec, "futureEnding": rec]
        GameSession.store.set(try JSONEncoder().encode(raw), forKey: EndingBook.key)
        let got = EndingBook.load()
        XCTAssertEqual(got.count, 1)
        XCTAssertEqual(got[.breakup], rec)
    }

    func testTrophyLoadsSurviveBrokenData() throws {
        let env = ProcessInfo.processInfo.environment
        try XCTSkipIf(env["MZ_TROPHIES"] != nil || env["MZ_RECORDS"] != nil)
        GameSession.store.set(Data("x".utf8), forKey: TrophyBook.key)
        GameSession.store.set(Data("x".utf8), forKey: TrophyBook.recordKey)
        XCTAssertTrue(TrophyBook.load().isEmpty)
        XCTAssertEqual(TrophyBook.loadRecords(), CareerRecords())
        // 知らない番号は捨て、知っている番号だけ残す
        GameSession.store.set(try JSONEncoder().encode(["t01", "t999"]), forKey: TrophyBook.key)
        XCTAssertEqual(TrophyBook.load().map(\.rawValue), ["t01"])
    }

    // MARK: ② 1文字ラベル
    func testAbilityAndCurrencyCharsAreDistinctSingleLetters() {
        let a = Ability.allCases.map(Theme.abilityChar)
        XCTAssertEqual(Set(a).count, Ability.allCases.count)
        XCTAssertTrue(a.allSatisfy { $0.count == 1 })
        let c = ExpCurrency.allCases.map(Theme.currencyChar)
        XCTAssertEqual(Set(c).count, ExpCurrency.allCases.count)
        XCTAssertTrue(c.allSatisfy { $0.count == 1 })
        XCTAssertTrue(Set(a).isDisjoint(with: c), "能力バッジと通貨バッジの文字が重ならない")
    }

    func testThemeColorsAreDistinctPerKind() {
        XCTAssertEqual(Set(Ability.allCases.map(Theme.abilityColor)).count, Ability.allCases.count)
        XCTAssertEqual(Set(ExpCurrency.allCases.map(Theme.currencyColor)).count, ExpCurrency.allCases.count)
        let grades = ["S", "A", "B", "C", "D", "E", "F", "G"]
        XCTAssertEqual(Set(grades.map(Theme.gradeColor)).count, grades.count)
        XCTAssertEqual(Theme.gradeColor("?"), Theme.gradeColor("G"), "知らない等級は G の色")
    }
}
