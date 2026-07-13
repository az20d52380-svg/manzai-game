// GoldenTests.swift
// Python検証機との数式同期テスト（CLAUDE.mdルール5）。
// 期待値は tools/balance_sim.py（会計移設後: 稽古→二区画クレジット→pour_all全量注ぎ・成長逓減D=120）で
// 同じ行動列を実行して生成した。生成方法: docs/gamecore_design.md「golden値の再生成」を参照。
// 会計移設2026-07-13: 稽古は能力を直接 add せず粒を発行し、行動直後に recommendedPlan で注ぐ（WeekRunner と同順）。
// この12週台本は growthBudget=nil（エンジン単体）なので予算②は通らず、逓減①→clamp③と供給スケール0.48・ρ=0【仮】が効く。
// このテストが落ちたら Swift と Python の数式がズレている。

import XCTest
@testable import GameCore

final class GoldenTests: XCTestCase {

    enum Act {
        case train(Training)
        case job(Job)
        case rest(Rest)
    }

    struct Expected {
        let money: Int
        let stamina: Double
        let fame: Double
        let sense: Double
        let idea: Double
        let expr: Double
        let chara: Double
        let mental: Double
        let compat: Double
    }

    // 12週の決定的な行動列（乱数不使用）。生活費は4週ごとに自動で引かれる
    let script: [(act: Act, exp: Expected)] = [
        (.train(.ネタ作り),     Expected(money: 300000, stamina: 80, fame: 3, sense: 10.44, idea: 11.316638888888889, expr: 10, chara: 10, mental: 10, compat: 5)),
        (.train(.ネタ合わせ),   Expected(money: 300000, stamina: 60, fame: 3, sense: 11.751372333333332, idea: 11.316638888888889, expr: 10, chara: 10, mental: 10, compat: 6)),
        (.train(.フリーライブ),     Expected(money: 300000, stamina: 30, fame: 4, sense: 11.751372333333332, idea: 11.316638888888889, expr: 10.44, chara: 11.316638888888889, mental: 10, compat: 6)),
        (.job(.標準),           Expected(money: 280000, stamina: 10, fame: 4, sense: 11.751372333333332, idea: 11.316638888888889, expr: 10.44, chara: 11.316638888888889, mental: 10, compat: 6)),
        (.rest(.完全休養),      Expected(money: 280000, stamina: 70, fame: 4, sense: 11.751372333333332, idea: 11.316638888888889, expr: 10.44, chara: 11.316638888888889, mental: 11.833333333333334, compat: 6)),
        (.train(.ネタ見せ会),     Expected(money: 200000, stamina: 40, fame: 4, sense: 11.751372333333332, idea: 11.316638888888889, expr: 13.048496794444445, chara: 11.316638888888889, mental: 13.128028240740742, compat: 6)),
        (.train(.ランニング・サウナ), Expected(money: 120000, stamina: 30, fame: 4, sense: 11.751372333333332, idea: 11.316638888888889, expr: 13.048496794444445, chara: 11.316638888888889, mental: 15.672526193916944, compat: 6)),
        (.job(.キツい),         Expected(money: 140000, stamina: 0, fame: 4, sense: 11.751372333333332, idea: 11.316638888888889, expr: 13.048496794444445, chara: 11.316638888888889, mental: 15.672526193916944, compat: 6)),
        (.rest(.相方と過ごす),  Expected(money: 140000, stamina: 20, fame: 4, sense: 11.751372333333332, idea: 11.316638888888889, expr: 13.048496794444445, chara: 11.316638888888889, mental: 15.672526193916944, compat: 7)),
        (.train(.ネタ作り),     Expected(money: 140000, stamina: 0, fame: 4, sense: 12.184366844, idea: 12.617518341743827, expr: 13.048496794444445, chara: 11.316638888888889, mental: 15.672526193916944, compat: 7)),
        (.job(.楽),             Expected(money: 180000, stamina: 0, fame: 4, sense: 12.184366844, idea: 12.617518341743827, expr: 13.048496794444445, chara: 11.316638888888889, mental: 15.672526193916944, compat: 7)),
        (.rest(.気分転換),      Expected(money: 80000, stamina: 35, fame: 4, sense: 12.184366844, idea: 12.617518341743827, expr: 13.048496794444445, chara: 11.316638888888889, mental: 16.541921808967636, compat: 7)),
    ]

    func testTwelveWeekScriptMatchesPython() {
        let config = GameConfig()   // 逓減D=120を含む既定値
        var s = GameState(config: config)
        let acc = 1e-9

        for (index, step) in script.enumerated() {
            let week = index + 1
            switch step.act {
            case .train(let t):
                XCTAssertTrue(GameEngine.applyTraining(t, to: &s, config: config), "week \(week): 稽古費が払えない想定外")
            case .job(let j):
                GameEngine.applyJob(j, to: &s, config: config)
            case .rest(let r):
                GameEngine.applyRest(r, to: &s, config: config)
            }
            // 会計移設: 行動直後に稼いだ粒を注ぐ（WeekRunner.proceed と同順・週末生活費の前）
            GameEngine.pourRecommended(to: &s, config: config)
            GameEngine.applyWeekEnd(week: week, to: &s, config: config)

            let e = step.exp
            XCTAssertEqual(s.money, e.money, "week \(week) money")
            XCTAssertEqual(s.stamina, e.stamina, accuracy: acc, "week \(week) stamina")
            XCTAssertEqual(s.fame, e.fame, accuracy: acc, "week \(week) fame")
            XCTAssertEqual(s.センス, e.sense, accuracy: acc, "week \(week) センス")
            XCTAssertEqual(s.発想, e.idea, accuracy: acc, "week \(week) 発想")
            XCTAssertEqual(s.表現, e.expr, accuracy: acc, "week \(week) 表現")
            XCTAssertEqual(s.華, e.chara, accuracy: acc, "week \(week) 華")
            XCTAssertEqual(s.メンタル, e.mental, accuracy: acc, "week \(week) メンタル")
            XCTAssertEqual(s.compat, e.compat, accuracy: acc, "week \(week) 相性")
        }

        // 最終状態での派生値も Python と一致すること
        XCTAssertEqual(GameEngine.blurWidth(mental: s.メンタル), 17.518711728654857, accuracy: acc)
        XCTAssertEqual(GameEngine.jitsuryoku(s, config: config), 12.400185587667591, accuracy: acc)
    }
}
