import XCTest
import GameCore
@testable import ManzaiGame

/// 未カバー分（11/09 定期・カバレッジで拾った）：
/// （①ChoiceEventData.scene(for:) の節は、この候補で scene(for:) を消すので外した＝場面の絵は EventBackdropTable 側のテストが見る）
/// ②StageOutfit.current の戻し方（未所有・壊れた値・未保存は standard）と wear の保存
final class OutfitScene1109Tests: XCTestCase {

    // MARK: ② 着ている衣装
    private var savedOutfit: Any?
    override func setUp() { savedOutfit = UserDefaults.standard.object(forKey: StageOutfit.defaultsKey) }
    override func tearDown() {
        if let v = savedOutfit { UserDefaults.standard.set(v, forKey: StageOutfit.defaultsKey) }
        else { UserDefaults.standard.removeObject(forKey: StageOutfit.defaultsKey) }
    }

    @MainActor func testCurrentFallsBackToStandard() throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["MZ_COSTUME"] != nil, "DEBUG の強制が効いている")
        UserDefaults.standard.removeObject(forKey: StageOutfit.defaultsKey)
        XCTAssertEqual(StageOutfit.current, .standard, "未保存")
        UserDefaults.standard.set("no-such-outfit", forKey: StageOutfit.defaultsKey)
        XCTAssertEqual(StageOutfit.current, .standard, "壊れた値")
        StageOutfit.wear(.standard)
        XCTAssertEqual(StageOutfit.current, .standard)
    }

    @MainActor func testCurrentKeepsOnlyOwnedOutfits() throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["MZ_COSTUME"] != nil, "DEBUG の強制が効いている")
        for o in StageOutfit.allCases where o != .standard {
            StageOutfit.wear(o)
            XCTAssertEqual(UserDefaults.standard.string(forKey: StageOutfit.defaultsKey), o.rawValue, "wear が保存する")
            XCTAssertEqual(o.isOwned, GachaStore.shared.owns(o))
            XCTAssertEqual(StageOutfit.current, o.isOwned ? o : .standard, "\(o)")
        }
    }
}
