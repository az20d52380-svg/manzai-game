// PourSkipZero1108Tests.swift
// おすすめ注ぎ：その年の伸びの上限に達しても、まだ伸びるメンタルで止まらず注ぐ（docs/pour_stop_1108_v0.md）。
import XCTest
@testable import GameCore

final class PourSkipZero1108Tests: XCTestCase {
    func testBudgetFullStillPoursMental() {
        let config = GameConfig()
        var s = GameState(config: config)
        s.growthBudget = 6
        s.growthUsed = 6   // 器が満ちている＝メンタル以外は伸びない
        s.センス = 10; s.発想 = 10; s.表現 = 10; s.キャラ = 10; s.メンタル = 30   // 一番低いのは伸びない能力
        s.exp閃き = 5; s.exp語彙 = 5; s.exp間合い = 5; s.exp胆力 = 5; s.exp存在感 = 5
        let plan = GameEngine.recommendedPlan(state: s, config: config)
        XCTAssertFalse(plan.isEmpty, "伸びない能力で止まっている")
        XCTAssertTrue(plan.allSatisfy { $0 == .メンタル }, "器が満ちた年に注げるのはメンタルだけ")
        var after = s
        GameEngine.pourRecommended(to: &after, config: config)
        XCTAssertGreaterThan(after.メンタル, s.メンタル)
        XCTAssertEqual(after.センス, s.センス)
        XCTAssertEqual(after.growthUsed, s.growthUsed)
    }
}
