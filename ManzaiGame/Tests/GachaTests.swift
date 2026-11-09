// 衣装ガチャのテスト（抽選の割合・初回・被り→かけら・天井・ログインボーナス・二重付与・保存）。本編の乱数とは無関係。
import XCTest
@testable import ManzaiGame

/// 固定列の乱数（テスト用）
struct SeededGen: RandomNumberGenerator {
    var s: UInt64
    mutating func next() -> UInt64 {
        s &+= 0x9E3779B97F4A7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

final class GachaTests: XCTestCase {
    func testCatalogRates() {
        XCTAssertEqual(GachaCatalog.pool.count, 12)
        XCTAssertEqual(OutfitRarity.allCases.map { $0.tierPercent }.reduce(0, +), 100)
        XCTAssertEqual(GachaCatalog.pool.map { GachaCatalog.percent(of: $0) }.reduce(0, +), 100, accuracy: 1e-9)
        XCTAssertEqual(GachaCatalog.display(GachaCatalog.percent(of: .kon)), "12.00%")
        XCTAssertEqual(GachaCatalog.display(GachaCatalog.percent(of: .stripe)), "7.50%")
        XCTAssertEqual(GachaCatalog.display(GachaCatalog.percent(of: .hakama)), "3.33%")
        XCTAssertNil(StageOutfit.kuromontsuki.rarity)
        XCTAssertNil(StageOutfit.standard.rarity)
    }

    func testDrawDistribution() {
        var g = SeededGen(s: 7)
        var counts: [OutfitRarity: Int] = [:]
        let n = 20000
        for _ in 0..<n {
            let r = GachaState.draw(&g).rarity!
            counts[r, default: 0] += 1
        }
        for r in OutfitRarity.allCases {
            XCTAssertEqual(Double(counts[r] ?? 0) / Double(n) * 100, Double(r.tierPercent), accuracy: 1.5, r.label)
        }
    }

    func testNoTicketNoPull() {
        var s = GachaState(); s.freeTickets = 0
        var g = SeededGen(s: 1)
        XCTAssertNil(s.pullOne(&g))
        XCTAssertEqual(s.totalPulls, 0)
    }

    func testFirstPullIsSpecialAndFreeSpentBeforePaid() {
        var s = GachaState()
        var g = SeededGen(s: 2)
        s.freeTickets = 1
        s.paidPending = 1
        let r = s.pullOne(&g)!
        XCTAssertEqual(r.outfit.rarity, .tokubetsu)
        XCTAssertTrue(r.isNew)
        XCTAssertEqual(s.freeTickets, 0)
        XCTAssertEqual(s.paidPending, 1)
        XCTAssertEqual(s.pity, 1)
        XCTAssertTrue(s.owns(r.outfit))
    }

    func testDuplicateBecomesShards() {
        var s = GachaState()
        var g = SeededGen(s: 3)
        s.totalPulls = 5
        s.paidPending = 400
        for _ in 0..<400 { _ = s.pullOne(&g) }
        XCTAssertEqual(s.owned.count, 12)
        XCTAssertGreaterThan(s.shards, 0)
        XCTAssertEqual(s.pity, 400)
        XCTAssertTrue(GachaCatalog.pool.allSatisfy { !s.canExchangeShards(for: $0) && !s.canExchangePity(for: $0) })
    }

    func testShardExchange() {
        var s = GachaState()
        s.shards = 9
        XCTAssertFalse(s.exchangeShards(for: .kon))
        s.shards = 10
        XCTAssertTrue(s.exchangeShards(for: .kon))
        XCTAssertEqual(s.shards, 0)
        XCTAssertTrue(s.owns(.kon))
        s.shards = 100
        XCTAssertFalse(s.exchangeShards(for: .kon))
        XCTAssertFalse(s.exchangeShards(for: .standard))
        XCTAssertFalse(s.exchangeShards(for: .kuromontsuki))
        XCTAssertTrue(s.exchangeShards(for: .hakama))
        XCTAssertEqual(s.shards, 60)
    }

    func testPityExchange() {
        var s = GachaState()
        s.pity = 39
        XCTAssertFalse(s.exchangePity(for: .kira))
        s.pity = 40
        XCTAssertTrue(s.exchangePity(for: .kira))
        XCTAssertEqual(s.pity, 0)
        XCTAssertTrue(s.owns(.kira))
        s.pity = 80
        XCTAssertFalse(s.exchangePity(for: .kira))
        XCTAssertEqual(s.pity, 80)
    }

    func testPityReachedAtFortyPulls() {
        var s = GachaState()
        var g = SeededGen(s: 9)
        s.paidPending = 40
        for _ in 0..<40 { _ = s.pullOne(&g) }
        XCTAssertGreaterThanOrEqual(s.pity, GachaCatalog.pityGoal)
    }

    func testFreshInstallHasFirstFreePull() {
        var s = GachaState()
        XCTAssertEqual(s.freeTickets, 1)
        var g = SeededGen(s: 5)
        let r = s.pullOne(&g)
        XCTAssertEqual(r?.outfit.rarity, .tokubetsu)   // はじめての1回は特別が必ず出る
        XCTAssertEqual(s.freeTickets, 0)
    }

    func testLoginBonus() {
        var s = GachaState()
        XCTAssertTrue(s.claimLogin(today: "2026-11-01"))
        XCTAssertFalse(s.claimLogin(today: "2026-11-01"))
        XCTAssertFalse(s.canClaimLogin(today: "2026-10-31"))
        for d in 2...6 { XCTAssertTrue(s.claimLogin(today: "2026-11-0\(d)")) }
        XCTAssertEqual(s.loginStamps, 6)
        XCTAssertEqual(s.freeTickets, 1)   // 新規の「はじめての1回」分のみ
        XCTAssertTrue(s.claimLogin(today: "2026-11-07"))
        XCTAssertEqual(s.freeTickets, 2)
        XCTAssertEqual(s.loginStamps, 0)
    }

    func testCreditOnlyOncePerTransaction() {
        var s = GachaState()
        XCTAssertTrue(s.credit(txID: "100", count: 10))
        XCTAssertFalse(s.credit(txID: "100", count: 10))
        XCTAssertEqual(s.paidPending, 10)
    }

    func testMergeKeepsOwnedUnion() {
        var a = GachaState()
        a.owned = ["kon"]; a.totalPulls = 3; a.pity = 3
        var b = GachaState()
        b.owned = ["gray"]; b.totalPulls = 5; b.pity = 5; b.shards = 4
        let m = a.merged(with: b)
        XCTAssertEqual(m.owned, ["kon", "gray"])
        XCTAssertEqual(m.pity, 5)
        XCTAssertEqual(m.shards, 4)
    }

    func testMergeDoesNotRefundExchangedShards() {
        var stale = GachaState()
        stale.owned = ["kon"]; stale.totalPulls = 5; stale.shards = 20
        var fresh = stale
        fresh.owned.insert("hakama"); fresh.shards = 0   // 別の端末で交換済み（回数は同じ）
        XCTAssertEqual(stale.merged(with: fresh).shards, 0)
        XCTAssertEqual(fresh.merged(with: stale).shards, 0)
    }

    func testMergeDoesNotResurrectOpenedPaidPulls() {
        var a = GachaState(); a.freeTickets = 0; a.credit(txID: "1", count: 10)
        let b = a                                  // 古い側（未開封10のまま）
        var g = SystemRandomNumberGenerator()
        for _ in 0..<10 { _ = a.pullOne(&g) }       // 端末Aが10回開封
        XCTAssertEqual(a.paidPending, 0)
        XCTAssertEqual(b.merged(with: a).paidPending, 0)
        XCTAssertEqual(a.merged(with: b).paidPending, 0)
        var mm = a.merged(with: b); XCTAssertFalse(mm.credit(txID: "1", count: 10))   // 同じ購入は二重に付かない
    }

    func testMergeKeepsPurchasesFromBothDevices() {
        var a = GachaState(); a.credit(txID: "A1", count: 1)
        var b = GachaState(); b.credit(txID: "B1", count: 10)
        XCTAssertEqual(a.merged(with: b).paidPending, 11)
        XCTAssertEqual(b.merged(with: a).paidPending, 11)
        var m = a.merged(with: b)
        XCTAssertFalse(m.credit(txID: "B1", count: 10))
        XCTAssertEqual(m.paidPending, 11)
    }

    func testLegacyPaidPendingMigrates() throws {
        let json = #"{"owned":["kon"],"freeTickets":0,"paidPending":3,"shards":0,"pity":0,"totalPulls":2,"loginStamps":0,"lastLoginDay":"","creditedTx":["9"]}"#
        let s = try JSONDecoder().decode(GachaState.self, from: Data(json.utf8))
        XCTAssertEqual(s.paidPending, 3)
        XCTAssertEqual(s.paidOpened, 0)
        XCTAssertEqual(s.ledger[GachaState.legacyID], 3)
        XCTAssertNil(s.ledger["9"] .flatMap { $0 > 0 ? $0 : nil })
        let back = try JSONDecoder().decode(GachaState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back, s)
    }

    @MainActor func testStorePersists() {
        let suite = UserDefaults(suiteName: "gacha-test-\(UUID().uuidString)")!
        let a = GachaStore(defaults: suite, useCloud: false)
        a.credit(txID: "1", count: 1)
        _ = a.pull(count: 1)
        let b = GachaStore(defaults: suite, useCloud: false)
        XCTAssertEqual(b.state.totalPulls, 1)
        XCTAssertEqual(b.state.owned.count, 1)
        XCTAssertTrue(b.owns(.standard))
    }

    /// 無料券を持ったまま10回を買って、買った直後に開ける＝購入分から10回開け、無料券は残る（code_review_2026-11-09 #1）
    func testPaidFirstKeepsFreeTicket() {
        var s = GachaState(); s.freeTickets = 1
        XCTAssertTrue(s.credit(txID: "t-paid10", count: 10))
        var g = SeededGen(s: 7)
        for _ in 0..<10 { XCTAssertNotNil(s.pullOne(&g, preferPaid: true)) }
        XCTAssertEqual(s.paidPending, 0)
        XCTAssertEqual(s.freeTickets, 1)
        // 既定（無料券の「はじめての1回」等）は今までどおり無料券から
        XCTAssertNotNil(s.pullOne(&g)); XCTAssertEqual(s.freeTickets, 0)
    }
}
