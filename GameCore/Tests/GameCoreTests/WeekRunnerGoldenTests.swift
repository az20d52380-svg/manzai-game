// WeekRunnerGoldenTests.swift
// WeekRunner（ステップ実行機）の等価証明: CareerGoldenTests と同一の乱数列・同一の期待値（3年ビット一致）で駆動し、
// runYear と WeekRunner が完全に同じセマンティクスであることを検証する（docs/ui_design_v0.md §5）。
// このテストが green なら、runYear を「WeekRunnerを回してpolicyに聞くだけ」に書き換える準備が整ったことになる。

import XCTest
@testable import GameCore

final class WeekRunnerGoldenTests: XCTestCase {

    /// WeekRunner を GoldenPolicy で1年ぶん駆動する。週末ごとに onWeekEnd を呼ぶ（runYear と同じ観測点）
    func driveYear(
        state: GameState,
        year: Int,
        config: GameConfig,
        policy: inout GoldenPolicy,
        rng: SplitMix64,
        gpSeeded: Bool = false,
        onWeekEnd: ((Int, GameState) -> Void)? = nil
    ) -> (outcome: YearOutcome, state: GameState, rng: SplitMix64) {
        var runner = WeekRunner(state: state, year: year, config: config, rng: rng, gpSeeded: gpSeeded)
        var phase = runner.begin()
        while true {
            switch phase {
            case .tournamentDecision(let spec):
                let travel = policy.enterTournament(spec, year: year, state: runner.state)
                phase = runner.resolveTournament(travel: travel)
            case .freeAction(let offer):
                let action = policy.action(week: runner.week, year: year, state: runner.state, offer: offer)
                phase = runner.resolveAction(action)
            case .gpRound, .gpRevival, .gpFinal:
                phase = runner.resolveAuto()
            case .weekDone(let summary):
                onWeekEnd?(summary.week, summary.state)
                phase = runner.begin()
            case .yearDone(let outcome):
                return (outcome, runner.state, runner.rng)
            }
        }
    }

    func testThreeYearsMatchRunYearGolden() {
        let config = GameConfig()
        var rng = SplitMix64(seed: 424242)
        var policy = GoldenPolicy()
        var s = GameState(config: config)
        let golden = CareerGoldenTests()

        // 1年目: 週ごとの全状態が CareerGoldenTests.year1（Python生成）と一致
        var rowIndex = 0
        var result = driveYear(state: s, year: 1, config: config, policy: &policy, rng: rng) { week, state in
            guard rowIndex < CareerGoldenTests.year1.count else { return }
            let r = CareerGoldenTests.year1[rowIndex]
            XCTAssertEqual(week, r.1)
            golden.assertState(state, money: r.2, stamina: r.3, fame: r.4, sense: r.5, idea: r.6,
                               expr: r.7, chara: r.8, mental: r.9, compat: r.10, "runner y1w\(week)")
            rowIndex += 1
        }
        XCTAssertEqual(rowIndex, 48, "48週ぶんの検証が走っていない")
        XCTAssertFalse(result.outcome.champion)
        s = result.state
        rng = result.rng

        // 2〜3年目: 年末スナップショットが一致（乱数列が1消費もずれていない証明）。シード制も正典と同じく配線
        var prevStage = result.outcome.roundsPassed
        for expected in CareerGoldenTests.yearEnds {
            result = driveYear(state: s, year: expected.0, config: config, policy: &policy, rng: rng,
                               gpSeeded: prevStage >= 3)
            prevStage = result.outcome.roundsPassed
            XCTAssertFalse(result.outcome.champion, "goldenシードでは3年間優勝しない想定")
            s = result.state
            rng = result.rng
            golden.assertState(s, money: expected.1, stamina: expected.2, fame: expected.3,
                               sense: expected.4, idea: expected.5, expr: expected.6, chara: expected.7,
                               mental: expected.8, compat: expected.9, "runner y\(expected.0)end")
        }
    }

    /// 王者シード: 予選免除で決勝のみが発生する（挙動の骨格チェック・数値はgolden対象外）
    func testSeedFinalSkipsRounds() {
        let config = GameConfig()
        let rng = SplitMix64(seed: 7)
        var policy = GoldenPolicy()
        var sawRound = false
        var sawFinal = false

        var runner = WeekRunner(state: GameState(config: config), year: 1, config: config,
                                rng: rng, seedFinal: true, finalLineOverride: 999)
        var phase = runner.begin()
        loop: while true {
            switch phase {
            case .tournamentDecision(let spec):
                let travel = policy.enterTournament(spec, year: 1, state: runner.state)
                phase = runner.resolveTournament(travel: travel)
            case .freeAction(let offer):
                let action = policy.action(week: runner.week, year: 1, state: runner.state, offer: offer)
                phase = runner.resolveAction(action)
            case .gpRound:
                sawRound = true
                phase = runner.resolveAuto()
            case .gpRevival:
                phase = runner.resolveAuto()
            case .gpFinal:
                sawFinal = true
                phase = runner.resolveAuto()
            case .weekDone:
                phase = runner.begin()
            case .yearDone(let outcome):
                XCTAssertFalse(outcome.champion, "ライン999は越えられない想定")
                XCTAssertTrue(outcome.reachedFinal)
                break loop
            }
        }
        XCTAssertFalse(sawRound, "王者シードでは回戦が発生しない")
        XCTAssertTrue(sawFinal, "王者シードでは決勝が必ず発生する")
    }
}
