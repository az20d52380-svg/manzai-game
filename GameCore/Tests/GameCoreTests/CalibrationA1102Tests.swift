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

    /// 周回（案2＋型1・calibration_meta_1102_v0 §5）：結成時のボーナスと年の予算が Python 正典と同値。点0 は今と同一
    func testMetaStartAndBudget() {
        let s0 = GameState(config: cfg, metaPoints: 0)
        XCTAssertNil(s0.metaPoints)
        XCTAssertEqual(s0.money, cfg.initMoney)
        XCTAssertEqual(s0.exp閃き, 0)
        // Python: sim_career.new_state(meta_points=P) / gen_golden.year_budget(年, P)
        let cases: [(Int, Int, Double, [Double], [Double])] = [
            (8, 540000, 11.420529573173852, [11.200405172930049, 5.760208374649739, 8.64031256197461, 3.2001157636943, 3.2001157636943],
             [6.373352113047883, 47.15619880054921, 49.015279090249315]),
            (38, 1300000, 18.993219786739576, [158.2, 81.36, 122.04, 45.2, 45.2],
             [42.59561424314387, 85.51351097732507, 87.54681135083425]),
        ]
        for (P, money, compat, exps, budgets) in cases {
            let s = GameState(config: cfg, metaPoints: P)
            XCTAssertEqual(s.metaPoints, P)
            XCTAssertEqual(s.money, money)
            XCTAssertEqual(s.compat, compat, accuracy: 1e-12)
            for (v, e) in zip([s.exp閃き, s.exp語彙, s.exp間合い, s.exp存在感, s.exp胆力], exps) { XCTAssertEqual(v, e, accuracy: 1e-12, "P\(P)") }
            for (y, b) in zip([1, 11, 15], budgets) {
                let r = WeekRunner(state: s, year: y, config: cfg, rng: SplitMix64(seed: 1))
                XCTAssertEqual(r.state.growthBudget ?? -1, b, accuracy: 1e-12, "P\(P) 年\(y)")
            }
        }
    }

    /// THE HANA：男コンビ（既定）では一切出ない・女性コンビは4段（優勝で手元250万・優勝回数）
    func testTheHanaFemaleOnly() {
        let male = GameState(config: cfg), female = GameState(config: cfg, femaleCombo: true)
        for w in [32, 37, 42, 44] {
            XCTAssertNil(cfg.calendar.tournament(inWeek: w, state: male), "男コンビに THE HANA が出た（週\(w)）")
            XCTAssertNotNil(cfg.calendar.tournament(inWeek: w, state: female))
        }
        XCTAssertNil(male.femaleCombo)
        // 2段目以降はその年に前の段を通過した時だけ
        let r2 = cfg.calendar.hanaTournaments[1]
        XCTAssertFalse(r2.isEligible(year: 3, state: female))
        var passed = female
        passed.hanaYear = 3; passed.hanaNext = 1
        XCTAssertTrue(r2.isEligible(year: 3, state: passed))
        XCTAssertFalse(r2.isEligible(year: 4, state: passed))
        // 強い女性コンビは4段とも通って優勝する（決勝は週44・GP より前）
        var s = GameState(config: cfg, femaleCombo: true)
        for a in Ability.allCases { s[a] = 100 }
        s.compat = 20
        var policy = GoldenPolicy()
        var rng = SplitMix64(seed: 7)
        var names: [String] = []
        _ = GameCareer.runYear(state: &s, year: 1, config: cfg, policy: &policy, rng: &rng)
        names = cfg.calendar.hanaTournaments.map(\.name)
        XCTAssertEqual(names, ["HANA1回戦", "HANA2回戦", "HANA準決勝", "HANA決勝"])
        XCTAssertEqual(s.hanaWins, 1)
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
