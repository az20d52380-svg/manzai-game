// 提供割合ページ（docs/release/gacha_rates_page.md）と StoreKit の設定を、コードの割合表と突き合わせる。
// 表示と実際のズレは景品表示法の問題になるので、文書の表を手で直し忘れたらここで赤にする（release_checklist §6）。
import XCTest
@testable import ManzaiGame

final class GachaRatesPage1107Tests: XCTestCase {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    /// 文書の表の行を、セルの配列にして返す（「袴（はかま）」の読みがなは外す）
    private func pageRows() throws -> [[String]] {
        let url = root.appendingPathComponent("docs/release/gacha_rates_page.md")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "実機ではリポジトリを読めない")
        return try String(contentsOf: url, encoding: .utf8).split(separator: "\n").filter { $0.hasPrefix("|") }.map { line in
            line.split(separator: "|").map {
                $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "（[^）]*）", with: "", options: .regularExpression)
            }
        }
    }

    func testTierRatesMatchCatalog() throws {
        let rows = try pageRows()
        for r in OutfitRarity.allCases {
            let want = [r.label, GachaCatalog.display(Double(r.tierPercent)), "\(GachaCatalog.items(r).count)"]
            XCTAssertTrue(rows.contains(want), "段の行が違う: \(want)")
        }
        XCTAssertTrue(rows.contains(["合計", "100.00%", "\(GachaCatalog.pool.count)"]))
    }

    func testEveryOutfitRateMatchesCatalog() throws {
        let rows = try pageRows()
        for o in GachaCatalog.pool {
            let want = [o.rarity!.label, o.displayName, GachaCatalog.display(GachaCatalog.percent(of: o))]
            XCTAssertTrue(rows.contains(want), "衣装の行が違う: \(want)")
        }
        // 文書にだけ残っている衣装が無いこと
        let outfitRows = rows.filter { $0.count == 3 && $0[2].hasSuffix("%") }
        XCTAssertEqual(outfitRows.count, GachaCatalog.pool.count)
    }

    func testShardsAndPityMatchCatalog() throws {
        let rows = try pageRows()
        for r in OutfitRarity.allCases {
            XCTAssertTrue(rows.contains([r.label, "\(r.shardGain)"]), "かけらの数: \(r.label)")
            XCTAssertTrue(rows.contains([r.label, "\(r.shardCost)"]), "交換に要る数: \(r.label)")
        }
        let text = try String(contentsOf: root.appendingPathComponent("docs/release/gacha_rates_page.md"), encoding: .utf8)
        XCTAssertTrue(text.contains("\(GachaCatalog.pityGoal)ポイント"))
    }

    /// StoreKit の設定（値段・消耗型か）がカタログと同じこと
    func testStoreKitConfigMatchesCatalog() throws {
        let url = root.appendingPathComponent("ManzaiGame/Configuration.storekit")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "実機ではリポジトリを読めない")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let products = try XCTUnwrap(json["products"] as? [[String: Any]])
        func product(_ id: String) -> [String: Any]? { products.first { $0["productID"] as? String == id } }
        let t1 = try XCTUnwrap(product(StoreIDs.ticket1))
        let t10 = try XCTUnwrap(product(StoreIDs.ticket10))
        XCTAssertEqual(t1["displayPrice"] as? String, "\(GachaCatalog.price1)")
        XCTAssertEqual(t10["displayPrice"] as? String, "\(GachaCatalog.price10)")
        XCTAssertEqual(t1["type"] as? String, "Consumable")
        XCTAssertEqual(t10["type"] as? String, "Consumable")
    }
}
