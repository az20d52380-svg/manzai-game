// RiftTests.swift
// 途中解散（すれ違いゲージ）docs/dissolution_rift_spec_v1.md。Python: sim_career.rift_weekend と同じ式・乱数なし。
import XCTest
@testable import GameCore

final class RiftTests: XCTestCase {
    func testRiftGrowsWhenCompatStaysAndHealsWhenItRises() {
        let config = GameConfig()
        var s = GameState(config: config)
        s.compat = 5; s.riftWeekStartCompat = 5
        XCTAssertFalse(GameEngine.applyRiftWeekEnd(year: 2, to: &s, config: config))
        XCTAssertEqual(s.rift ?? 0, 0.5 * 15 / 20, accuracy: 1e-9)   // 上がらない週：+0.5×(20−5)/20
        s.riftWeekStartCompat = 5; s.compat = 6
        _ = GameEngine.applyRiftWeekEnd(year: 2, to: &s, config: config)
        XCTAssertEqual(s.rift ?? 0, 0, accuracy: 1e-9)               // 上がった週：−3（下限0）
    }

    func testMaxCompatNeverDrifts() {
        let config = GameConfig()
        var s = GameState(config: config)
        s.compat = config.compatCap; s.riftWeekStartCompat = config.compatCap
        for _ in 0..<500 { _ = GameEngine.applyRiftWeekEnd(year: 5, to: &s, config: config) }
        XCTAssertEqual(s.rift ?? 0, 0, accuracy: 1e-9)               // 仲の良い二人は解散しない
    }

    func testWarnThenDissolveOnlyFromYearTwo() {
        let config = GameConfig()
        var s = GameState(config: config)
        s.compat = 0; s.riftWeekStartCompat = 0
        for _ in 0..<200 { XCTAssertFalse(GameEngine.applyRiftWeekEnd(year: 1, to: &s, config: config)) }
        XCTAssertEqual(s.rift ?? 0, 99, accuracy: 1e-9)              // 1年目は 99 で止まる
        XCTAssertEqual(s.riftWarned, true)                           // 予告は出ている
        XCTAssertFalse(GameEngine.applyRiftWeekEnd(year: 2, to: &s, config: config))   // 99.5
        XCTAssertTrue(GameEngine.applyRiftWeekEnd(year: 2, to: &s, config: config))    // 100
        XCTAssertEqual(s.dissolved, true)
    }

    func testRiftWarningChoices() {
        let config = GameConfig()
        let cs = ChoiceEventTable.choices(for: .riftWarning, config: config)
        XCTAssertEqual(cs.map(\.id), ["A", "B"])
        var s = GameState(config: config); s.rift = 55; s.stamina = 80
        for e in cs[0].effects { s.applyEventEffect(e, config: config) }
        XCTAssertEqual(s.rift ?? 0, 25, accuracy: 1e-9)
        XCTAssertEqual(s.stamina, 70, accuracy: 1e-9)
        var t = GameState(config: config); t.rift = 10
        for e in cs[0].effects { t.applyEventEffect(e, config: config) }
        XCTAssertEqual(t.rift ?? 0, 0, accuracy: 1e-9)   // 下限0
        XCTAssertTrue(cs[1].effects.isEmpty)
    }

    // --- §94 予選で落ちたら相性↓・二人でやる週はすれ違いがたまらない ---

    /// 弱い状態で GP の最初の回戦（seeded なら2回戦）を落とした時の相性の下げ幅を測る
    private func compatDropAtFirstGPLoss(seeded: Bool) -> (stage: Int, drop: Double) {
        let config = GameConfig()
        var s = GameState(config: config)
        s.compat = 10; s.money = 5_000_000
        var r = WeekRunner(state: s, year: 1, config: config, rng: SplitMix64(seed: 3), gpSeeded: seeded)
        var phase = r.begin()
        while true {
            switch phase {
            case .tournamentDecision: phase = r.resolveTournament(travel: nil)
            case .freeAction: phase = r.resolveAction(.rest(.完全休養))
            case .gpRound:
                let before = r.state.compat
                let stage = r.gpRoundsPassed
                phase = r.resolveAuto()
                if r.gpRoundsPassed == stage { return (stage, before - r.state.compat) }   // 落ちた回戦
            case .weekDone: phase = r.begin()
            case .yearDone: XCTFail("GP回戦で落ちなかった"); return (-1, -1)
            default: phase = r.resolveAuto()
            }
        }
    }

    func testGPQualifierLossLowersCompatPerRound() {
        XCTAssertEqual(GameConfig().gpLossCompat, [0.5, 0.5, 0.5, 0.25, 0.125])   // 準々は半分・準決勝は1/4
        for seeded in [false, true] {
            let (stage, drop) = compatDropAtFirstGPLoss(seeded: seeded)
            XCTAssertEqual(drop, GameConfig().gpLossCompat[stage], accuracy: 1e-9)   // 落ちた回戦の下げ幅
        }
    }

    func testJointWeekDoesNotAccumulateRift() {
        let config = GameConfig()
        var s = GameState(config: config)
        s.compat = 5; s.riftWeekStartCompat = 5; s.rift = 10; s.riftJointWeek = true
        _ = GameEngine.applyRiftWeekEnd(year: 2, to: &s, config: config)
        XCTAssertEqual(s.rift ?? 0, 10, accuracy: 1e-9)      // 増えない・減らない
        XCTAssertEqual(s.riftJointWeek, false)               // 週末で印は戻る
        s.riftWeekStartCompat = 5; s.riftJointWeek = true; s.compat = 6
        _ = GameEngine.applyRiftWeekEnd(year: 2, to: &s, config: config)
        XCTAssertEqual(s.rift ?? 0, 7, accuracy: 1e-9)       // 相性が上がった週は今どおり減る
    }

    func testSoloWeekStillAccumulatesRift() {
        let config = GameConfig()
        var s = GameState(config: config)
        s.compat = 5; s.riftWeekStartCompat = 5; s.rift = 10
        _ = GameEngine.applyRiftWeekEnd(year: 2, to: &s, config: config)
        XCTAssertEqual(s.rift ?? 0, 10 + 0.5 * 15 / 20, accuracy: 1e-9)   // 一人の週は今どおり増える
    }
}
