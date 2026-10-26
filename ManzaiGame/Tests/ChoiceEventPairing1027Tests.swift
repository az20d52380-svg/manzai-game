// 選択イベント：GameCore の選択肢（ChoiceEventTable.choices）とアプリの文（ChoiceEventData のボタン名・選んだ後の会話）の対応。
// 片側だけ選択肢を足す・消すと、ボタン名が空のボタンや「選んだのに何も言わない」画面になる（10/27 定期で足した見張り）。
import XCTest
import GameCore
@testable import ManzaiGame

final class ChoiceEventPairing1027Tests: XCTestCase {
    private let config = GameConfig()

    func testEveryCoreChoiceHasLabelAndAfterTalk() {
        for kind in ChoiceEventKind.allCases {
            let ids = Set(ChoiceEventTable.choices(for: kind, config: config).map(\.id))
            // 選択肢が空＝読むだけのイベント（名無しの予約票・出番順の一番上・楽屋の十分・3行目の当たり）。文の側も空であることを下で見る
            var texts = [ChoiceEventData.text(for: kind)]
            if kind == .weekendInvite { texts += ChoiceEventData.weekendInviteVariants }
            if kind == .styleTalk { texts += ChoiceEventData.styleTalkVariants }
            for t in texts {
                XCTAssertEqual(Set(t.choiceLabels.keys), ids, "\(kind)「\(t.title)」のボタン名と GameCore の選択肢がずれている")
                XCTAssertEqual(Set(t.afterChoice.keys), ids, "\(kind)「\(t.title)」の選んだ後の会話と GameCore の選択肢がずれている")
                for id in ids {
                    XCTAssertFalse((t.choiceLabels[id] ?? "").trimmingCharacters(in: .whitespaces).isEmpty, "\(kind) \(id) のボタン名が空")
                    XCTAssertFalse((t.afterChoice[id] ?? []).isEmpty, "\(kind) \(id) の選んだ後の会話が空")
                }
            }
        }
    }
}
