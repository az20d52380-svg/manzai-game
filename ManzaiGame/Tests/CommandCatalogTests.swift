// アプリ側の追加テスト（CommandCatalog の行動カード一覧・お金での押せる/押せない・台詞キーの対応 / NetaStage の段）
import XCTest
import GameCore
@testable import ManzaiGame

final class CommandCatalogTests: XCTestCase {
    private let config = GameConfig()

    private func allVariants(money: Int) -> [CommandVariant] {
        var v = CommandCatalog.mainCards(config: config, money: money)
        for cat in CommandCategory.allCases { v += CommandCatalog.cards(cat, config: config, money: money) }
        v += CommandCatalog.netaPlaces(config: config, money: money)
        if let w = CommandCatalog.netaWrite(config: config) { v.append(w) }
        return v
    }

    // MARK: 常設カード
    func testMainCardsAreFourInOrder() {
        let ids = CommandCatalog.mainCards(config: config, money: 0).map(\.id)
        XCTAssertEqual(ids, ["t_ネタ作り", "t_ネタ合わせ", "t_フリーライブ", "rest_完全休養"])
    }
    func testMainCardsFreeTrainsAffordableWithZeroMoney() {
        for c in CommandCatalog.mainCards(config: config, money: 0) { XCTAssertTrue(c.affordable, c.id) }
    }
    func testMainCardsTrainFlag() {
        let cards = CommandCatalog.mainCards(config: config, money: 0)
        XCTAssertEqual(cards.map(\.isTrain), [true, true, true, false])
    }

    // MARK: 種類の一覧
    func testEmptyCategories() {
        for cat in [CommandCategory.ネタを書く, .能力アップ, .お店] {
            XCTAssertTrue(CommandCatalog.cards(cat, config: config, money: 10_000_000).isEmpty, cat.rawValue)
        }
    }
    func testCategoryCounts() {
        XCTAssertEqual(CommandCatalog.cards(.練習, config: config, money: 0).count, 6)
        XCTAssertEqual(CommandCatalog.cards(.バイト, config: config, money: 0).count, 3)
        XCTAssertEqual(CommandCatalog.cards(.休む, config: config, money: 0).count, 5)
    }
    func testPaidTrainingsAffordabilityFollowsCost() {
        for c in CommandCatalog.cards(.練習, config: config, money: 0) {
            guard case .train(let t) = c.action, let spec = config.trainings[t] else { return XCTFail(c.id) }
            XCTAssertEqual(c.affordable, spec.cost <= 0, c.id)
        }
        // ちょうど足りる額では押せる・1円足りないと押せない
        let spec = config.trainings[.ネタ見せ会]!
        let at = CommandCatalog.cards(.練習, config: config, money: spec.cost).first { $0.id == "t_ネタ見せ会" }!
        let below = CommandCatalog.cards(.練習, config: config, money: spec.cost - 1).first { $0.id == "t_ネタ見せ会" }!
        XCTAssertTrue(at.affordable)
        XCTAssertFalse(below.affordable)
    }
    func testRestAffordabilityUsesRestCosts() {
        for c in CommandCatalog.cards(.休む, config: config, money: 0) {
            guard case .rest(let r) = c.action else { return XCTFail(c.id) }
            XCTAssertEqual(c.affordable, (config.restCosts[r] ?? 0) <= 0, c.id)
            XCTAssertFalse(c.isTrain)
        }
        let onsen = config.restCosts[.温泉に一泊]!
        XCTAssertTrue(CommandCatalog.cards(.休む, config: config, money: onsen).first { $0.id == "rest_温泉に一泊" }!.affordable)
    }
    func testJobsAlwaysAffordableAndNotTrain() {
        for c in CommandCatalog.cards(.バイト, config: config, money: 0) {
            XCTAssertTrue(c.affordable); XCTAssertFalse(c.isTrain)
            guard case .job = c.action else { return XCTFail(c.id) }
        }
    }

    // MARK: ネタを書く
    func testNetaPlacesOrderAndCosts() {
        let places = CommandCatalog.netaPlaces(config: config, money: 0)
        XCTAssertEqual(places.map(\.id), ["t_ネタ作り", "t_喫茶店で書く", "t_ファミレスで書く"])
        XCTAssertEqual(places.map(\.affordable), [true, false, false])
        XCTAssertTrue(CommandCatalog.netaPlaces(config: config, money: 10_000).allSatisfy(\.affordable))
    }
    func testNetaWriteIsNetaSakusei() {
        let w = CommandCatalog.netaWrite(config: config)
        XCTAssertEqual(w?.id, "t_ネタ作り")
        XCTAssertEqual(w?.isTrain, true)
    }

    // MARK: オファー
    func testExtraCardsOnlyWithOffer() {
        XCTAssertTrue(CommandCatalog.extraCards(config: config, offer: nil, money: 0).isEmpty)
        for o in config.offersNamed {
            let cards = CommandCatalog.extraCards(config: config, offer: o, money: 0)
            XCTAssertEqual(cards.count, 1)
            XCTAssertEqual(cards[0].id, "offer")
            XCTAssertEqual(cards[0].name, "オファー：\(o.name)")
            XCTAssertNotEqual(cards[0].desc, o.name, "説明文が未登録: \(o.name)")
        }
    }
    func testOfferBlurbFallbackIsName() {
        XCTAssertEqual(CommandCatalog.offerBlurb("未知の仕事"), "未知の仕事")
    }

    // MARK: 全体の整合
    func testIdsMatchActionAndHaveReactions() {
        let fallback = "よし、いくか。"
        for c in allVariants(money: 10_000_000) {
            switch c.action {
            case .train(let t): XCTAssertEqual(c.id, "t_\(t)")
            case .job(let j): XCTAssertEqual(c.id, "job_\(j)")
            case .rest(let r): XCTAssertEqual(c.id, "rest_\(r)")
            default: XCTFail("想定外の行動: \(c.id)")
            }
            XCTAssertFalse(c.name.isEmpty); XCTAssertFalse(c.desc.isEmpty); XCTAssertFalse(c.glyph.isEmpty)
            let texts = (0..<12).map { DialogueData.reaction(variantID: c.id, salt: $0).text }
            XCTAssertTrue(texts.contains { $0 != fallback }, "台詞が未登録: \(c.id)")
        }
        XCTAssertTrue((0..<12).map { DialogueData.reaction(variantID: "offer", salt: $0).text }.contains { $0 != fallback })
    }
    func testIdsUniqueWithinEachList() {
        for cat in CommandCategory.allCases {
            let ids = CommandCatalog.cards(cat, config: config, money: 0).map(\.id)
            XCTAssertEqual(Set(ids).count, ids.count, cat.rawValue)
        }
        XCTAssertEqual(Set(CommandCategory.allCases.map(\.glyph)).count, CommandCategory.allCases.count)
    }

    // MARK: NetaStage
    func testNetaStageThresholds() {
        XCTAssertEqual(NetaStage.index(0), 0)
        XCTAssertEqual(NetaStage.index(34.99), 0)
        XCTAssertEqual(NetaStage.index(35), 1)
        XCTAssertEqual(NetaStage.index(59.99), 1)
        XCTAssertEqual(NetaStage.index(60), 2)
        XCTAssertEqual(NetaStage.index(84.99), 2)
        XCTAssertEqual(NetaStage.index(85), 3)
        XCTAssertEqual(NetaStage.index(100), 3)
        XCTAssertEqual(NetaStage.index(-5), 0)
        XCTAssertEqual(NetaStage.name(90), "仕上がった")
        XCTAssertEqual(NetaStage.name(10), "書きかけ")
    }
    func testNetaStageMonotonic() {
        var prev = 0
        for p in stride(from: 0.0, through: 100.0, by: 0.5) {
            let i = NetaStage.index(p); XCTAssertGreaterThanOrEqual(i, prev); prev = i
        }
    }
}
