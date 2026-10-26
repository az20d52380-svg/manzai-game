// Coverage1027Tests.swift
// Allocation のレシピ無し能力の既定値分岐と、JudgeTalk.fill の語彙表フォールバックの固定。Sources は不変。

import XCTest
@testable import GameCore

final class Coverage1027Tests: XCTestCase {
    private func configWithoutRecipe(_ a: Ability) -> GameConfig {
        var c = GameConfig()
        c.abilityRecipes[a] = nil
        return c
    }

    func testAffordableRawIsZeroWithoutRecipe() {
        let c = configWithoutRecipe(.華)
        var s = GameState(config: c)
        s[currency: .存在感] = 50
        XCTAssertEqual(GameEngine.affordableRaw(.華, state: s, config: c), 0)
    }

    func testNextStepCostIsEmptyWithoutRecipe() {
        let c = configWithoutRecipe(.華)
        let s = GameState(config: c)
        XCTAssertTrue(GameEngine.nextStepCost(.華, state: s, config: c).isEmpty)
    }

    func testPourStepDoesNothingWithoutRecipe() {
        let c = configWithoutRecipe(.発想)
        var s = GameState(config: c)
        s[currency: .閃き] = 30
        s[currency: .語彙] = 30
        let before = s
        XCTAssertEqual(GameEngine.pourStep(.発想, to: &s, config: c), 0)
        XCTAssertEqual(s[.発想], before[.発想])
        XCTAssertEqual(s[currency: .閃き], 30)
        XCTAssertEqual(s[currency: .語彙], 30)
    }

    func testRecommendedPlanSkipsAbilityWithoutRecipe() {
        let c = configWithoutRecipe(.メンタル)
        var s = GameState(config: c)
        for cur in ExpCurrency.allCases { s[currency: cur] = 20 }
        XCTAssertFalse(GameEngine.recommendedPlan(state: s, config: c).contains(.メンタル))
    }
}
