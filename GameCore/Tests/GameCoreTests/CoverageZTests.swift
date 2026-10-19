// CoverageZTests.swift
// オファー（抽選・テレビ慣れ・追加札）／家賃と生活費／ネタの派生状態（鉄板・再演・liveBuzz）の固定。
// Sources は不変。

import XCTest
@testable import GameCore

final class CoverageZTests: XCTestCase {
    let cfg = GameConfig()

    /// 決まった値を順に返す乱数（尽きたら最後の値）
    struct Fixed: RandomSource {
        var vals: [Double]
        var i = 0
        init(_ v: [Double]) { vals = v }
        mutating func nextUniform() -> Double { defer { i += 1 }; return vals[min(i, vals.count - 1)] }
    }

    // MARK: rollOffer

    func testRollOfferRateBandsAndKinds() {
        var s = GameState(config: cfg)
        s.fame = 0
        var r = Fixed([0.049, 0.4, 0.4])          // 帯 <10 は 5%：0.049 は当たり、0.4<0.5 → money、sub=1
        XCTAssertEqual(GameEngine.rollOffer(state: s, config: cfg, rng: &r)?.name, "営業")
        var r2 = Fixed([0.05, 0.1, 0.1])          // ちょうど 5% は外れ
        XCTAssertNil(GameEngine.rollOffer(state: s, config: cfg, rng: &r2))
        XCTAssertEqual(r2.i, 1)                   // 外れは乱数1回だけ消費
        s.fame = 10                                // 帯 <30 は 15%
        var r3 = Fixed([0.149, 0.6, 0.6])         // 0.6>=0.5 → exp 系、sub=0 → ひな壇
        XCTAssertEqual(GameEngine.rollOffer(state: s, config: cfg, rng: &r3)?.name, "ひな壇")
        XCTAssertEqual(r3.i, 3)                   // 当たりは3回消費
        s.fame = 100                               // 最終帯は 50%
        var r4 = Fixed([0.499, 0.4, 0.6])         // money、sub=0 → ロケ
        XCTAssertEqual(GameEngine.rollOffer(state: s, config: cfg, rng: &r4)?.name, "ロケ")
        var r5 = Fixed([0.5, 0, 0])
        XCTAssertNil(GameEngine.rollOffer(state: s, config: cfg, rng: &r5))
    }

    // MARK: テレビ慣れ

    func testOfferFatiguedThresholdAndWindow() {
        var s = GameState(config: cfg)
        s.offerWeeks = [10, 11, 12]
        XCTAssertFalse(GameEngine.offerFatigued(state: s, atWeek: 13, config: cfg))   // 3回<K=4
        s.offerWeeks = [8, 10, 11, 12]
        XCTAssertTrue(GameEngine.offerFatigued(state: s, atWeek: 13, config: cfg))    // 4回とも窓内
        XCTAssertFalse(GameEngine.offerFatigued(state: s, atWeek: 14, config: cfg))   // 14-8=6 は窓の外
    }

    func testApplyOfferRecordsWeekPrunesAndPenalizesWhenFatigued() {
        var s = GameState(config: cfg)
        let o = cfg.offersNamed[2]   // ロケ
        let m0 = s.money
        GameEngine.applyOffer(o, to: &s, config: cfg)                 // atWeek なし＝記録しない
        XCTAssertEqual(s.money, m0 + 220_000)
        XCTAssertNil(s.offerWeeks)
        s.offerWeeks = [1, 20, 21, 22, 23]
        let sense0 = s.センス
        GameEngine.applyOffer(o, to: &s, config: cfg, atWeek: 24)    // 窓内は 20〜23 の4回→慣れ発動
        XCTAssertEqual(s.offerWeeks ?? [], [20, 21, 22, 23, 24])     // 古い 1 は掃除される
        XCTAssertEqual(s.センス, sense0 - cfg.offerFatigueD, accuracy: 1e-9)
        var t = GameState(config: cfg)
        let sense1 = t.センス
        GameEngine.applyOffer(o, to: &t, config: cfg, atWeek: 5)     // 初回は慣れなし
        XCTAssertEqual(t.センス, sense1, accuracy: 1e-9)
        XCTAssertEqual(t.offerWeeks ?? [], [5])
    }

    // MARK: 追加の札

    func testExtraOffersCountByFameAndDeterminism() {
        let first = cfg.offersNamed[0]
        XCTAssertTrue(GameEngine.extraOffers(first: first, fame: 29.9, seed: 1, year: 1, week: 1, config: cfg).isEmpty)
        let two = GameEngine.extraOffers(first: first, fame: 30, seed: 1, year: 1, week: 1, config: cfg)
        XCTAssertEqual(two.count, 1)
        let three = GameEngine.extraOffers(first: first, fame: 55, seed: 1, year: 1, week: 1, config: cfg)
        XCTAssertEqual(three.count, 2)
        XCTAssertFalse(three.contains { $0.name == first.name })
        XCTAssertEqual(Set(three.map(\.name)).count, 2)
        let again = GameEngine.extraOffers(first: first, fame: 55, seed: 1, year: 1, week: 1, config: cfg)
        XCTAssertEqual(three.map(\.name), again.map(\.name))
    }

    // MARK: 家賃・生活費・部屋

    func testRoomRentAndLivingCostDue() {
        var s = GameState(config: cfg)
        XCTAssertEqual(GameEngine.roomRent(s, config: cfg), 0)
        XCTAssertEqual(GameEngine.livingCostDue(s, config: cfg), 140_000)
        s.room = 1
        XCTAssertEqual(GameEngine.roomRent(s, config: cfg), 50_000)
        XCTAssertEqual(GameEngine.livingCostDue(s, config: cfg), 190_000)
        s.room = 2
        XCTAssertEqual(GameEngine.livingCostDue(s, config: cfg), 290_000)
        s.room = 9                                   // 範囲外は家賃0
        XCTAssertEqual(GameEngine.roomRent(s, config: cfg), 0)
    }

    func testCanMoveRoomAndMoveRoom() {
        var s = GameState(config: cfg)
        s.money = 49_999
        XCTAssertFalse(GameEngine.canMoveRoom(to: 1, state: s, config: cfg))
        XCTAssertFalse(GameEngine.canMoveRoom(to: 3, state: s, config: cfg))
        XCTAssertFalse(GameEngine.canMoveRoom(to: -1, state: s, config: cfg))
        XCTAssertFalse(GameEngine.moveRoom(to: 1, state: &s, config: cfg))
        XCTAssertNil(s.room)
        s.money = 50_000
        XCTAssertTrue(GameEngine.moveRoom(to: 1, state: &s, config: cfg))
        XCTAssertEqual(s.room, 1)
        XCTAssertEqual(s.money, 50_000)              // お金は引かない
        s.money = 0
        XCTAssertTrue(GameEngine.moveRoom(to: 0, state: &s, config: cfg))   // 下げるのは無料
        XCTAssertNil(s.room)                          // 0 は nil に戻る
    }

    // MARK: ネタの派生状態

    func testTeppanBoundaries() {
        var n = Neta(id: 1, name: "a", kata: .王道しゃべくり, lengthFit: [.中尺], bornYear: 1)
        n.polish = 80; n.stageCount = 8; n.buzz = 60
        XCTAssertTrue(n.isTeppan(config: cfg))
        n.polish = 79.9; XCTAssertFalse(n.isTeppan(config: cfg))
        n.polish = 80; n.stageCount = 7; XCTAssertFalse(n.isTeppan(config: cfg))
        n.stageCount = 8; n.buzz = 59.9; XCTAssertFalse(n.isTeppan(config: cfg))
    }

    func testIsRevivalBoundary() {
        let n = Neta(id: 1, name: "a", kata: .瞬発, lengthFit: [.短尺], bornYear: 2)
        XCTAssertFalse(n.isRevival(currentYear: 4, config: cfg))
        XCTAssertTrue(n.isRevival(currentYear: 5, config: cfg))
    }

    func testLiveBuzzFormulaAndClamp() {
        var s = GameState(config: cfg)
        var n = Neta(id: 1, name: "a", kata: .関係性, lengthFit: [.長尺], bornYear: 1)
        n.polish = 40
        let p = GameEngine.jitsuryoku(s, config: cfg)
        let want = min(100, max(0, p * 0.7 + 40 * 0.5))
        XCTAssertEqual(Neta.liveBuzz(state: s, neta: n, config: cfg), want, accuracy: 1e-9)
        n.polish = 100
        s.センス = 1000; s.発想 = 1000; s.表現 = 1000; s.華 = 1000
        XCTAssertEqual(Neta.liveBuzz(state: s, neta: n, config: cfg), 100)
    }
}
