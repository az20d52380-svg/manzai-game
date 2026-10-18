// BoundaryGapTests.swift
// 未カバーだった境目を「今の振る舞いのまま」固定するテスト（式・乱数・golden・ソースは不変）。
// 能力アップの等級コスト倍率の境目 / おすすめ注ぎが通貨の足りない能力を選ばないこと / 週次抽選イベントの発火帯の境目。

import XCTest
@testable import GameCore

final class BoundaryGapTests: XCTestCase {
    private let cfg = GameConfig()

    // MARK: 等級コスト倍率（RANK_COST_BANDS）

    /// しきい値ちょうどは「未満」ではないので次の帯。しきい値の直前は手前の帯
    func testRankCostMultiplierBandEdges() {
        let expected: [(Double, Double)] = [
            (0, 1.00), (14.999, 1.00), (15, 1.15), (24.999, 1.15), (25, 1.35), (34.999, 1.35),
            (35, 1.60), (44.999, 1.60), (45, 2.00), (54.999, 2.00), (55, 2.50), (69.999, 2.50),
            (70, 3.20), (89.999, 3.20), (90, 4.20), (100, 4.20),
        ]
        for (v, m) in expected {
            var s = GameState(config: cfg)
            s.発想 = v
            XCTAssertEqual(GameEngine.rankCostMultiplier(.発想, state: s, config: cfg), m, accuracy: 1e-12, "値 \(v)")
        }
    }

    /// 次の1段の通貨量＝allocationStep×重み×倍率（境目をまたぐと倍率分だけ増える）
    func testNextStepCostAcrossBandEdge() {
        var s = GameState(config: cfg)
        s.発想 = 14.999
        let before = GameEngine.nextStepCost(.発想, state: s, config: cfg)
        s.発想 = 15
        let after = GameEngine.nextStepCost(.発想, state: s, config: cfg)
        for (b, a) in zip(before, after) {
            XCTAssertEqual(a.amount / b.amount, 1.15, accuracy: 1e-9)
        }
        let w = cfg.abilityRecipes[.発想]!
        XCTAssertEqual(after.map(\.amount), w.map { cfg.allocationStep * $0.1 * 1.15 })
    }

    // MARK: おすすめ注ぎ

    /// 通貨が全く無ければ空
    func testRecommendedPlanEmptyWithoutCurrency() {
        var s = GameState(config: cfg)
        s.growthBudget = nil
        XCTAssertTrue(GameEngine.recommendedPlan(state: s, config: cfg).isEmpty)
    }

    /// 閃き・語彙・間合いだけ持っている時、胆力・存在感が要る能力は選ばれない（発想だけ）
    func testRecommendedPlanSkipsUnaffordableAbilities() {
        var s = GameState(config: cfg)
        s.growthBudget = nil
        s.exp閃き = 20; s.exp語彙 = 20; s.exp間合い = 20   // 発想のレシピ（閃き・語彙・間合い）だけ揃う（§93）
        s.センス = 0; s.発想 = 30   // 現在値はセンスの方が低いが、センスは間合い・胆力が無く注げない
        let plan = GameEngine.recommendedPlan(state: s, config: cfg)
        XCTAssertFalse(plan.isEmpty)
        XCTAssertEqual(Set(plan), [.発想])
    }

    // MARK: 週次抽選イベントの発火帯

    private func fire(_ k: ChoiceEventKind, _ s: GameState, week: Int = 10) -> Bool {
        ChoiceEventTable.weeklyFireable(k, state: s, week: week, config: cfg)
    }

    /// 金欠帯（<5万）は5万ちょうどで外れる／相性が上限なら出ない
    func testBrokeDrinkingInviteBand() {
        var s = GameState(config: cfg)
        s.compat = 5
        s.money = 49_999
        XCTAssertTrue(fire(.brokeDrinkingInvite, s))
        s.money = 50_000
        XCTAssertFalse(fire(.brokeDrinkingInvite, s))
        s.money = 0; s.compat = cfg.compatCap
        XCTAssertFalse(fire(.brokeDrinkingInvite, s))
    }

    /// 先輩の名刺: 所持金<20万 かつ 知名度<50（どちらも境目ちょうどで外れる）
    func testSenpaiMeishiBand() {
        var s = GameState(config: cfg)
        s.money = 199_999; s.fame = 49
        XCTAssertTrue(fire(.senpaiMeishi, s))
        s.money = 200_000
        XCTAssertFalse(fire(.senpaiMeishi, s))
        s.money = 0; s.fame = 50
        XCTAssertFalse(fire(.senpaiMeishi, s))
    }

    /// 噛み合い帯は相性 8〜14（両端含む）
    func testGreenroomSilentTenBand() {
        var s = GameState(config: cfg)
        for (c, want) in [(7.0, false), (8.0, true), (14.0, true), (15.0, false)] {
            s.compat = c
            XCTAssertEqual(fire(.greenroomSilentTen, s), want, "相性 \(c)")
        }
    }

    /// 撮られる仕事: 知名度 20〜50（両端含む）。前座帯 lineupTop は <20
    func testFameBandsPhotoShootAndLineupTop() {
        var s = GameState(config: cfg)
        for (f, photo, top) in [(19.0, false, true), (20.0, true, false), (50.0, true, false), (51.0, false, false)] {
            s.fame = f
            XCTAssertEqual(fire(.photoShootOffer, s), photo, "photo fame \(f)")
            XCTAssertEqual(fire(.lineupTop, s), top, "lineupTop fame \(f)")
        }
    }

    /// 好調帯は体力80以上／母からの電話などの週ゲートは確定発火の kind には効かない
    func testLuckyThirdLineStaminaEdgeAndConfirmedKindsNeverFire() {
        var s = GameState(config: cfg)
        s.stamina = 79.9
        XCTAssertFalse(fire(.luckyThirdLine, s))
        s.stamina = 80
        XCTAssertTrue(fire(.luckyThirdLine, s))
        for k in [ChoiceEventKind.justLostRehearsal, .styleTalk, .riftWarning, .tsuukaBreak] {
            XCTAssertFalse(fire(k, s, week: 30), "\(k) は抽選プール外")
        }
    }
}
