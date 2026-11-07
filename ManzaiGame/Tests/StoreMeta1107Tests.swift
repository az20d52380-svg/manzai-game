import XCTest
@testable import ManzaiGame

/// 未カバー分：GachaStore の操作口・GachaState の旧データ/日付・TrophyBook のカウンタと壊れた保存・MetaBook の文
final class StoreMeta1107Tests: XCTestCase {
    private var saved: UserDefaults!
    override func setUp() {
        saved = GameSession.store
        GameSession.store = UserDefaults(suiteName: "sm1107-\(UUID().uuidString)")!
    }
    override func tearDown() { GameSession.store = saved }

    @MainActor private func freshStore() -> (GachaStore, UserDefaults) {
        let d = UserDefaults(suiteName: "sm1107g-\(UUID().uuidString)")!
        return (GachaStore(defaults: d, useCloud: false), d)
    }

    // MARK: GachaStore
    @MainActor func testClaimLoginOncePerDayAndNoRewind() {
        let (s, _) = freshStore()
        XCTAssertTrue(s.claimLogin(today: "2026-11-07"))
        XCTAssertFalse(s.claimLogin(today: "2026-11-07"))   // 二重押し
        XCTAssertFalse(s.claimLogin(today: "2026-11-06"))   // 日付を戻しても取れない
        XCTAssertTrue(s.claimLogin(today: "2027-01-01"))    // 年またぎ
        XCTAssertEqual(s.state.loginStamps, 2)
    }

    @MainActor func testSevenStampsBecomeFreeTicket() {
        let (s, _) = freshStore()
        let before = s.state.freeTickets
        for d in 1...7 { XCTAssertTrue(s.claimLogin(today: String(format: "2026-12-%02d", d))) }
        XCTAssertEqual(s.state.loginStamps, 0)
        XCTAssertEqual(s.state.freeTickets, before + 1)
    }

    @MainActor func testExchangeShardsBoundaryAndPersist() {
        let (s, d) = freshStore()
        s.mutate { $0.shards = OutfitRarity.iro.shardCost - 1 }
        XCTAssertFalse(s.exchangeShards(for: .kon))          // 1足りない
        XCTAssertFalse(s.state.owns(.kon))
        s.mutate { $0.shards += 1 }
        XCTAssertTrue(s.exchangeShards(for: .kon))
        XCTAssertEqual(s.state.shards, 0)
        XCTAssertFalse(s.exchangeShards(for: .kon))          // 持っている物は不可
        XCTAssertFalse(s.exchangeShards(for: .standard))     // ガチャ対象外
        let b = GachaStore(defaults: d, useCloud: false)
        XCTAssertTrue(b.state.owns(.kon))
    }

    @MainActor func testExchangePityBoundary() {
        let (s, _) = freshStore()
        s.mutate { $0.pity = GachaCatalog.pityGoal - 1 }
        XCTAssertFalse(s.exchangePity(for: .kira))
        s.mutate { $0.pity += 1 }
        XCTAssertTrue(s.exchangePity(for: .kira))
        XCTAssertEqual(s.state.pity, 0)
        XCTAssertFalse(s.exchangePity(for: .kira))
        XCTAssertFalse(s.exchangePity(for: .kuromontsuki))
    }

    @MainActor func testBrokenStoredDataFallsBackToFresh() {
        let d = UserDefaults(suiteName: "sm1107b-\(UUID().uuidString)")!
        d.set(Data("{壊れ".utf8), forKey: GachaStore.key)
        let s = GachaStore(defaults: d, useCloud: false)
        XCTAssertEqual(s.state, GachaState())
        XCTAssertEqual(s.state.freeTickets, 1)
    }

    @MainActor func testZeroPullExistingDataGetsFirstFreeTicket() throws {
        let d = UserDefaults(suiteName: "sm1107z-\(UUID().uuidString)")!
        var old = GachaState(); old.freeTickets = 0   // 一度も回さず無料券0の保存
        d.set(try JSONEncoder().encode(old), forKey: GachaStore.key)
        XCTAssertEqual(GachaStore(defaults: d, useCloud: false).state.freeTickets, 1)
        var used = GachaState(); used.freeTickets = 0; used.totalPulls = 3
        d.set(try JSONEncoder().encode(used), forKey: GachaStore.key)
        XCTAssertEqual(GachaStore(defaults: d, useCloud: false).state.freeTickets, 0)   // 回した後は増やさない
    }

    @MainActor func testPullWithNoTicketsReturnsEmpty() {
        let (s, _) = freshStore()
        s.mutate { $0.freeTickets = 0 }
        XCTAssertEqual(s.pull(count: 3).count, 0)
        XCTAssertEqual(s.state.totalPulls, 0)
    }

    @MainActor func testKuromontsukiFollowsAdFreeNotState() {
        let (s, _) = freshStore()
        s.mutate { $0.owned.insert(StageOutfit.kuromontsuki.rawValue) }
        XCTAssertEqual(s.owns(.kuromontsuki), StoreManager.shared.isAdFree)
    }

    // MARK: GachaState
    func testAvailableTicketsAndPaidPendingSetter() {
        var s = GachaState()
        s.freeTickets = 2
        s.paidPending = 5
        XCTAssertEqual(s.availableTickets, 7)
        s.paidPending = 0
        XCTAssertEqual(s.availableTickets, 2)
        s.paidPending = -3                                   // 負は0扱い
        XCTAssertEqual(s.paidPending, 0)
    }

    func testPullUsesFreeBeforePaid() {
        var s = GachaState(); s.freeTickets = 1; s.paidPending = 2
        var g = SystemRandomNumberGenerator()
        XCTAssertNotNil(s.pullOne(&g))
        XCTAssertEqual(s.freeTickets, 0); XCTAssertEqual(s.paidOpened, 0)
        XCTAssertNotNil(s.pullOne(&g))
        XCTAssertEqual(s.paidOpened, 1); XCTAssertEqual(s.paidPending, 1)
    }

    func testDayKeyZeroPaddedAndYearBoundary() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let d1 = cal.date(from: DateComponents(year: 2026, month: 1, day: 5))!
        XCTAssertEqual(GachaState.dayKey(d1, calendar: cal), "2026-01-05")
        let d2 = cal.date(from: DateComponents(year: 2026, month: 12, day: 31, hour: 23, minute: 59))!
        XCTAssertEqual(GachaState.dayKey(d2, calendar: cal), "2026-12-31")
        XCTAssertLessThan(GachaState.dayKey(d2, calendar: cal), GachaState.dayKey(cal.date(byAdding: .minute, value: 2, to: d2)!, calendar: cal))
    }

    func testDecodeEmptyObjectAndLegacyTxIDs() throws {
        let e = try JSONDecoder().decode(GachaState.self, from: Data("{}".utf8))
        XCTAssertEqual(e.freeTickets, 1); XCTAssertTrue(e.ledger.isEmpty)
        let json = #"{"paidPending":2,"creditedTx":["a","b"]}"#
        let o = try JSONDecoder().decode(GachaState.self, from: Data(json.utf8))
        XCTAssertEqual(o.paidPending, 2)
        XCTAssertEqual(o.ledger["a"], 0)                      // 旧IDは0回で登録＝再付与されない
        var m = o
        XCTAssertFalse(m.credit(txID: "a", count: 5))
        XCTAssertEqual(m.paidPending, 2)
    }

    func testMergedSameTotalsPrefersMoreOwned() {
        var a = GachaState(); a.totalPulls = 5; a.shards = 30
        var b = a; b.owned.insert(StageOutfit.kon.rawValue); b.shards = 0   // 交換して持ち物が増えた側
        XCTAssertEqual(a.merged(with: b).shards, 0)
        XCTAssertEqual(b.merged(with: a).shards, 0)
        XCTAssertEqual(a.merged(with: b).owned, b.owned)
    }

    // MARK: TrophyBook / MetaBook
    func testCounterBumpAndIndependentNames() {
        XCTAssertEqual(TrophyBook.counter("bus"), 0)
        XCTAssertEqual(TrophyBook.bump("bus"), 1)
        XCTAssertEqual(TrophyBook.bump("bus"), 2)
        XCTAssertEqual(TrophyBook.counter("bus"), 2)
        XCTAssertEqual(TrophyBook.counter("keiko"), 0)
    }

    func testBrokenTrophyDataAndUnknownIDs() throws {
        GameSession.store.set(Data("xx".utf8), forKey: TrophyBook.key)
        XCTAssertTrue(TrophyBook.load().isEmpty)
        XCTAssertEqual(TrophyBook.points, 0)
        GameSession.store.set(try JSONEncoder().encode(["t01", "t99", "t22"]), forKey: TrophyBook.key)
        XCTAssertEqual(TrophyBook.load(), [.t01, .t22])        // 知らないIDは捨てる
        XCTAssertFalse(TrophyBook.award(.t01))
        XCTAssertTrue(TrophyBook.award(.t02))
        XCTAssertEqual(TrophyBook.points, 1 + 3 + 1)
    }

    func testBrokenRecordsFallBack() {
        GameSession.store.set(Data("zz".utf8), forKey: TrophyBook.recordKey)
        XCTAssertEqual(TrophyBook.loadRecords(), CareerRecords())
        TrophyBook.recordChampion(year: 7, streak: 2)
        TrophyBook.recordChampion(year: 3, streak: 1)
        let r = TrophyBook.loadRecords()
        XCTAssertEqual(r.totalWins, 2); XCTAssertEqual(r.bestStreak, 2); XCTAssertEqual(r.fastestWinYear, 3)
    }

    func testTrophyTextsAndPointTotal() {
        XCTAssertEqual(TrophyID.allCases.count, 22)
        XCTAssertEqual(TrophyID.allCases.reduce(0) { $0 + $1.pt }, 30)
        XCTAssertEqual(Set(TrophyID.allCases.map(\.title)).count, 22)
        XCTAssertTrue(TrophyID.allCases.allSatisfy { !$0.condition.isEmpty && !$0.id.isEmpty })
        XCTAssertFalse(TrophyID.allCases.contains { $0.condition.contains("%") || $0.condition.contains("％") })
    }

    func testBannerLinesZeroAndPositive() {
        XCTAssertNil(MetaBook.bannerLines(points: 0))
        XCTAssertNil(MetaBook.bannerLines(points: -3))
        let l = try! XCTUnwrap(MetaBook.bannerLines(points: 10))
        XCTAssertEqual(l.count, 3)
        let pv = try! XCTUnwrap(MetaBook.preview(points: 10))
        XCTAssertTrue(l[1].contains("+\(pv.exp)"))
        XCTAssertTrue(l[1].contains("+\(pv.money / 10_000)万円"))
    }
}
