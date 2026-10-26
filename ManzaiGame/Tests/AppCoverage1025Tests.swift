// アプリ側の追加テスト（NetaCatalog 表示名・既定尺・相性 / RentStatement.make・yen / FanReportData.ordered）
import XCTest
import GameCore
@testable import ManzaiGame

final class AppCoverage1025Tests: XCTestCase {
    // MARK: NetaCatalog
    func testKataDisplayNamesNonEmptyAndUnique() {
        let names = NetaKata.allCases.map { NetaCatalog.displayName($0) }
        XCTAssertTrue(names.allSatisfy { !$0.isEmpty })
        XCTAssertEqual(Set(names).count, NetaKata.allCases.count)
        XCTAssertEqual(NetaCatalog.displayName(NetaKata.リターン), "リターン型")
    }
    func testLengthDisplayNames() {
        XCTAssertEqual(NetaCatalog.displayName(NetaLength.短尺), "短め")
        XCTAssertEqual(NetaCatalog.displayName(NetaLength.中尺), "ふつう")
        XCTAssertEqual(NetaCatalog.displayName(NetaLength.長尺), "長め")
    }
    func testDefaultLengthFitNeverEmptyAndHonorsCases() {
        for k in NetaKata.allCases { XCTAssertFalse(NetaCatalog.defaultLengthFit(for: k).isEmpty) }
        XCTAssertEqual(NetaCatalog.defaultLengthFit(for: .伏線回収), [.長尺])
        XCTAssertEqual(NetaCatalog.defaultLengthFit(for: .華先行), [.短尺])
    }
    func testAutoNameDeterministicAndWrapsNegative() {
        XCTAssertEqual(NetaCatalog.autoName(forID: 0), "商店街の福引")
        XCTAssertEqual(NetaCatalog.autoName(forID: 3), NetaCatalog.autoName(forID: 3))
        for id in [-1, -7, 0, 5, 1000, 99999] { XCTAssertFalse(NetaCatalog.autoName(forID: id).isEmpty) }
        XCTAssertNotEqual(NetaCatalog.autoName(forID: 1), NetaCatalog.autoName(forID: 2))
    }
    func testAffinityKnownUnknownAndAllowedSymbols() {
        XCTAssertEqual(NetaCatalog.affinity(.王道しゃべくり, judge: "天堂寺 銀郎"), "◎")
        XCTAssertEqual(NetaCatalog.affinity(.華先行, judge: "卯月 走太"), "×")
        XCTAssertEqual(NetaCatalog.affinity(.瞬発, judge: "存在しない審査員"), "○")   // 未登録は○
        let judges = ["天堂寺 銀郎", "花園 千代", "卯月 走太", "目白 慧", "白波 剛", "神楽坂 とんぼ", "音羽 ルリ"]
        for k in NetaKata.allCases { for j in judges {
            XCTAssertTrue(["◎", "○", "△", "×"].contains(NetaCatalog.affinity(k, judge: j)))
        } }
    }

    // MARK: RentStatement
    func testRentMakeShortfallAndPaid() {
        let paid = RentStatement.make(livingCost: 1000, moneyAfter: 500)
        XCTAssertEqual(paid.moneyBefore, 1500)
        XCTAssertEqual(paid.shortfall, 0)
        XCTAssertTrue(paid.paid)
        XCTAssertEqual(paid.lines.reduce(0) { $0 + $1.amount }, 1000)
        let short = RentStatement.make(livingCost: 1000, moneyAfter: -300)   // 払う前 700 → 300 不足
        XCTAssertEqual(short.shortfall, 300)
        XCTAssertFalse(short.paid)
        let debt = RentStatement.make(livingCost: 1000, moneyAfter: -1500)   // 払う前が負＝全額が借金
        XCTAssertEqual(debt.shortfall, 1000)
    }
    func testRentMakeRoomExtraAndNameGoOnFirstLine() {
        let r = RentStatement.make(livingCost: 1000, moneyAfter: 0, roomExtra: 200, roomName: "6畳")
        XCTAssertEqual(r.lines[0].label, "家賃（6畳）")
        XCTAssertEqual(r.lines[0].amount, RentStatement.breakdown(total: 800)[0].amount + 200)
        XCTAssertEqual(r.lines.reduce(0) { $0 + $1.amount }, 1000)
        XCTAssertEqual(Array(r.lines.dropFirst().map(\.label)), ["食費", "光熱費・携帯", "交通費"])
    }
    func testRentYen() {
        XCTAssertEqual(RentStatement.yen(0), "0")
        XCTAssertEqual(RentStatement.yen(1234567), "1,234,567")
        XCTAssertEqual(RentStatement.yen(-5000), "5,000")   // 絶対値
    }

    // MARK: FanReportData.ordered
    func testOrderedEmptyPoolAndRotation() {
        XCTAssertEqual(FanReportData.ordered([], salt: 3, name: "X", used: []), [])
        let pool = ["a", "b", "c", "d"]
        XCTAssertEqual(FanReportData.ordered(pool, salt: 1, name: "X", used: []), ["b", "c", "d", "a"])
        XCTAssertEqual(FanReportData.ordered(pool, salt: -1, name: "X", used: []), ["d", "a", "b", "c"])
    }
    func testOrderedPutsUsedLastOldestFirstAndReplacesName() {
        let pool = ["〈名〉1", "〈名〉2", "〈名〉3", "〈名〉4"]
        let out = FanReportData.ordered(pool, salt: 0, name: "N", used: ["N3", "N1"])
        XCTAssertEqual(out, ["〈名〉2", "〈名〉4", "〈名〉3", "〈名〉1"])   // 未使用が先・使用済みは古い順
    }
}
