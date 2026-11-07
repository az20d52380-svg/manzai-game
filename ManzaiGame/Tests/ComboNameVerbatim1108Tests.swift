// コンビ名が相方名・一人称に置き換わらない（code_review_1108d #2・combi_name_verbatim_1108_v0）
import XCTest
@testable import ManzaiGame

final class ComboNameVerbatim1108Tests: XCTestCase {
    override func tearDown() {
        Names.set(me: nil, partner: nil); Names.setCombi(nil); Names.setKind(.maleMale)
        super.tearDown()
    }

    func testComboNameWithTaniguchiStaysVerbatim() {
        Names.set(me: nil, partner: "ケン"); Names.setCombi("谷口一座")
        XCTAssertEqual(Names.show("谷口一座"), "谷口一座")
        XCTAssertEqual(Names.show("谷口一座　最後の舞台"), "谷口一座　最後の舞台")
        XCTAssertEqual(Names.show("—— 谷口一座 ——"), "—— 谷口一座 ——")
    }

    func testComboNameWithMePlaceholderStaysVerbatim() {
        Names.set(me: nil, partner: nil); Names.setCombi("{me}ズ")
        XCTAssertEqual(Names.show("{me}ズ"), "{me}ズ")
        XCTAssertEqual(Names.show("結成3年目 —— {me}ズ"), "結成3年目 —— {me}ズ")
    }

    func testDialogueAroundComboNameStillReplaced() {
        Names.set(me: nil, partner: "ケン"); Names.setCombi("谷口一座")
        XCTAssertEqual(Names.show("谷口が、谷口一座の名を呼んだ。{me}も笑う。"), "ケンが、谷口一座の名を呼んだ。俺も笑う。")
        XCTAssertEqual(Names.show("谷口「やるぞ」"), "ケン「やるぞ」")
    }

    func testOrdinaryComboNameUnchanged() {
        Names.set(me: nil, partner: "ケン"); Names.setCombi("満月ロケット")
        XCTAssertEqual(Names.show("満月ロケット"), "満月ロケット")
        XCTAssertEqual(Names.show("谷口と満月ロケット"), "ケンと満月ロケット")
    }

    func testDefaultPartnerAndNoComboBehaviorUnchanged() {
        Names.set(me: nil, partner: nil); Names.setCombi("あなたのコンビ")
        XCTAssertEqual(Names.show("谷口が来た。{me}は行く。"), "谷口が来た。俺は行く。")
        XCTAssertEqual(Names.show("俺"), "俺")
        Names.set(me: "タロウ", partner: "ケン"); Names.setCombi(nil)
        XCTAssertEqual(Names.show("俺"), "タロウ")
        XCTAssertEqual(Names.show("谷口一座"), "ケン一座")
    }

    func testExactTaniguchiComboNameIsNotProtected() {
        // コンビ名がちょうど「谷口」だと台詞の谷口と区別できないので従来どおり（残り）
        Names.set(me: nil, partner: "ケン"); Names.setCombi("谷口")
        XCTAssertEqual(Names.show("谷口が来た。"), "ケンが来た。")
    }
}
