// 終盤イベント40本（E1〜E20・N1〜N20）の本文の形を見張る（late_events_cand_1108）。
// 決まり: ト書き30字以内・1吹き出し40字以内・本文に実在の名前や数値の復唱を入れない。選択肢との対応は ChoiceEventPairing1027Tests が全 kind で見る。
import XCTest
import GameCore
@testable import ManzaiGame

final class LateEvents1108Tests: XCTestCase {
    private var late: [ChoiceEventKind] { ChoiceEventKind.allCases.filter(\.isLateEvent) }

    func testEveryLateEventHasText() {
        XCTAssertEqual(late.count, 40)
        for k in late {
            let t = ChoiceEventData.text(for: k)
            XCTAssertFalse(t.title.isEmpty, "\(k)")
            XCTAssertNil(t.setup.first?.name, "\(k) の先頭はト書き（話者なし）")
            XCTAssertGreaterThanOrEqual(t.setup.count, 4, "\(k) の導入")
        }
    }

    func testLengthLimits() {
        for k in late {
            let t = ChoiceEventData.text(for: k)
            let all = t.setup + t.afterChoice.values.flatMap { $0 }
            for a in all {
                if a.name == nil { XCTAssertLessThanOrEqual(a.text.count, 30, "\(k) ト書き「\(a.text)」") }
                else { XCTAssertLessThanOrEqual(a.text.count, 40, "\(k) 吹き出し「\(a.text)」") }
            }
        }
    }
}
