// CalibrationA1102Tests.swift
// 較正A（docs/calibration_all_1101_v0.md §5・2026-11-02 規律Aで正典へ）のうち、3年 golden が通らない所（11年目以降）を押さえる。
// 期待値は Python 正典（tools/sim_career.py・gen_golden.year_budget / tourney_exp）で出した値。

import XCTest
@testable import GameCore

final class CalibrationA1102Tests: XCTestCase {
    let cfg = GameConfig()

    private func budget(year: Int) -> Double {
        WeekRunner(state: GameState(config: cfg), year: year, config: cfg, rng: SplitMix64(seed: 1)).state.growthBudget ?? -1
    }

    /// 成長予算：10年目までは従来どおり、11年目以降の加算は ×0.6^(年−10)（Python gen_golden.year_budget と同値）
    func testLateGrowthBudget() {
        XCTAssertEqual(budget(year: 10), 42.0, accuracy: 1e-12)
        XCTAssertEqual(budget(year: 11), 43.2, accuracy: 1e-12)
        XCTAssertEqual(budget(year: 15), 44.76672000000001, accuracy: 1e-12)
    }

    /// 11年目以降だけ決勝・敗者復活のライン +2。王者ライン上書きには足さない
    func testLateFinalLine() {
        XCTAssertEqual(cfg.careerYears, 15)
        XCTAssertEqual(cfg.calendar.gpLateBonus(year: 10), 0)
        XCTAssertEqual(cfg.calendar.gpLateBonus(year: 11), 2)
        let r10 = WeekRunner(state: GameState(config: cfg), year: 10, config: cfg, rng: SplitMix64(seed: 1))
        let r11 = WeekRunner(state: GameState(config: cfg), year: 11, config: cfg, rng: SplitMix64(seed: 1))
        let r11o = WeekRunner(state: GameState(config: cfg), year: 11, config: cfg, rng: SplitMix64(seed: 1), finalLineOverride: 90)
        XCTAssertEqual(r10.snapshot().finalLine, 81)
        XCTAssertEqual(r11.snapshot().finalLine, 83)
        XCTAssertEqual(r11o.snapshot().finalLine, 90)
        // 復元しても年に応じた上乗せが付く
        XCTAssertEqual(WeekRunner(restoring: r11.snapshot(), config: cfg).snapshot().finalLine, 83)
    }

    /// 大会の経験点：基本点×K×重み を5通貨に均等（供給スケール込み）。Python sim_career.tourney_exp と同値
    func testTourneyExpCredit() {
        var s = GameState(config: cfg)
        GameEngine.creditTourneyExp(1.0, weight: cfg.tourneyExpWeightRoad, to: &s, config: cfg)
        for v in [s.exp閃き, s.exp語彙, s.exp間合い, s.exp存在感, s.exp胆力] { XCTAssertEqual(v, 0.096, accuracy: 1e-15) }
        var t = GameState(config: cfg)   // GP 準決勝（i=5）で敗退
        GameEngine.creditTourneyExp((1 + cfg.tourneyExpRoundStep * 4) * cfg.tourneyExpLoss, weight: cfg.tourneyExpWeightRound, to: &t, config: cfg)
        XCTAssertEqual(t.exp間合い, 0.2304, accuracy: 1e-15)
    }

    /// 温泉に一泊＝体力回復だけ（メンタルは動かない）
    func testOnsenRecoveryOnly() {
        var s = GameState(config: cfg)
        s.stamina = 0
        let m = s.メンタル
        GameEngine.applyRest(.温泉に一泊, to: &s, config: cfg)
        XCTAssertEqual(s.stamina, 100)
        XCTAssertEqual(s.メンタル, m)
    }
}
