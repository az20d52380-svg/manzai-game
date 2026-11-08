// イベントの背景（EventBackdropTable＝今使っている表）と、導入のト書き（最初の1文）の場所・時間帯がずれないか（11/08）
// ※ ChoiceEventData.scene(for:) は古い背景の表で今は参照されない（unused_parts_1027 #118）＝こちらを突き合わせる
import XCTest
import GameCore
@testable import ManzaiGame

final class EventScene1108Tests: XCTestCase {
    /// ト書きの言葉 → 合う背景（いずれか）。ト書きで最初に出る言葉で判定（「劇場の楽屋」は劇場が先に出るので劇場に楽屋も含める）
    private let placeWords: [(String, Set<EventPlace>)] = [
        ("楽屋", [.gakuya]), ("焼肉", [.yakiniku]), ("ファミレス", [.famires]), ("喫茶", [.kissaten]),
        ("事務所", [.office]), ("公園", [.park]), ("アパート", [.apartment, .street]), ("受付", [.uketsuke]),
        ("改札", [.stationGate]), ("忘れ物の窓口", [.stationGate]), ("ホーム", [.station]), ("電車", [.train, .station]),
        ("銭湯", [.sento]), ("劇場", [.theater, .theaterOutside, .gakuya]), ("稽古場", [.keikoba, .street, .uketsuke]),
    ]
    private let timeWords: [(String, EventTimeOfDay)] = [("深夜", .night), ("朝", .morning), ("昼", .day), ("夕", .evening), ("夜", .night)]

    private func opening(_ k: ChoiceEventKind) -> String? {
        guard let line = ChoiceEventData.text(for: k).setup.first?.text else { return nil }
        return line.components(separatedBy: "。").prefix(2).joined(separator: "。")   // 場所の1文＋時間の1文
    }

    func testBackdropPlaceMatchesOpening() {
        for k in ChoiceEventKind.allCases {
            guard let t = opening(k), let hit = placeWords.filter({ t.contains($0.0) })
                .min(by: { t.range(of: $0.0)!.lowerBound < t.range(of: $1.0)!.lowerBound }) else { continue }   // ト書きで最初に出る場所
            let b = EventBackdrop.forEvent(k)
            XCTAssertTrue(hit.1.contains(b.place), "\(k)：ト書き『\(t)』の『\(hit.0)』なのに背景は \(b.place.label)")
        }
    }

    func testBackdropTimeMatchesOpening() {
        for k in ChoiceEventKind.allCases {
            guard let t = opening(k), let hit = timeWords.first(where: { t.contains($0.0) }) else { continue }
            let b = EventBackdrop.forEvent(k)
            XCTAssertEqual(b.time, hit.1, "\(k)：ト書き『\(t)』の『\(hit.0)』なのに背景は \(b.time.label)")
        }
    }

    func testHiddenEffectNotesOnlyForKnownChoices() {
        XCTAssertNotNil(ChoiceEventData.hiddenEffectNote(for: .photoShootOffer, choice: "A"))
        XCTAssertNil(ChoiceEventData.hiddenEffectNote(for: .photoShootOffer, choice: "B"))
        for k in ChoiceEventKind.allCases {
            for id in ["A", "B", "C"] {
                if let n = ChoiceEventData.hiddenEffectNote(for: k, choice: id) {
                    XCTAssertNotNil(ChoiceEventData.text(for: k).choiceLabels[id], "\(k) に選択肢 \(id) が無いのに一言がある")
                    XCTAssertFalse(n.contains { $0.isASCII && $0.isNumber || ("０"..."９").contains($0) }, "一言に数字: \(n)")   // 数字に出ない効果だけ
                }
            }
        }
    }
}
