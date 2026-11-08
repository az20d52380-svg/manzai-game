// イベントの場面の絵（ChoiceEventData.scene）と本文の場所がずれないか（カバー率の点検 11/08 で scene(for:) が 0%）
import XCTest
import GameCore
@testable import ManzaiGame

final class EventScene1108Tests: XCTestCase {
    /// 場所の絵と、その場所を示す言葉
    private let placeWords: [(EventScene, [String])] = [
        (.gakuya, ["楽屋"]), (.yakiniku, ["焼肉"]), (.station, ["駅", "ホーム"]),
        (.famires, ["ファミレス"]), (.office, ["事務所"]),
    ]

    private func setupText(_ k: ChoiceEventKind) -> String {
        ChoiceEventData.text(for: k).setup.map(\.text).joined(separator: "\n")
    }

    /// 場所の絵を出すイベントは、導入の文にその場所が出てくる
    func testPlaceSceneMatchesSetupText() {
        for k in ChoiceEventKind.allCases {
            let scene = ChoiceEventData.scene(for: k)
            guard let words = placeWords.first(where: { $0.0 == scene })?.1 else { continue }
            let t = setupText(k)
            XCTAssertTrue(words.contains { t.contains($0) }, "\(k) は \(scene) の絵なのに導入の文に \(words) が無い")
        }
    }

    /// 場所の絵の対応表に無い既定の場面（稽古場・夕景）の時は、どれか1つの場所でしか起きない話になっていない
    /// （導入の最初の地の文に場所の言葉があるのに稽古場の絵＝絵と文の食い違い）
    func testDefaultSceneHasNoPlaceInOpening() {
        for k in ChoiceEventKind.allCases {
            let scene = ChoiceEventData.scene(for: k)
            guard scene == .keiko || scene == .dusk else { continue }
            guard let line = ChoiceEventData.text(for: k).setup.first?.text else { continue }
            let first = line.components(separatedBy: "。").first ?? line   // 最初の1文（場所のト書き）だけを見る
            if first.contains("稽古場") { continue }                         // 稽古場で受ける電話など＝絵は稽古場で合う
            for (s, words) in placeWords {
                for w in words where first.contains(w) {
                    XCTFail("\(k)：最初の地の文に『\(w)』があるのに絵は \(scene)（\(s) が合う？）: \(first)")
                }
            }
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
