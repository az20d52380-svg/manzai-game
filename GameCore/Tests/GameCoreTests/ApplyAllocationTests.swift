// ApplyAllocationTests.swift
// テストから一度も呼ばれていなかった WeekRunner.applyAllocation（能力アップ画面の確定）と
// WeekPolicy.acceptInvite の既定値を確かめる。★式・乱数・golden には触れない。

import XCTest
@testable import GameCore

final class ApplyAllocationTests: XCTestCase {

    private func richState(_ c: GameConfig) -> GameState {
        var s = GameState(config: c)
        s.exp閃き = 500; s.exp語彙 = 500; s.exp間合い = 500; s.exp存在感 = 500; s.exp胆力 = 500
        return s
    }

    /// 確定＝タップ順に pourStep を再生したのと同じ結果（プレビューと確定が食い違わない）
    func testApplyAllocationReplaysPourStepsInOrder() throws {
        let c = GameConfig()
        let taps: [Ability] = [.センス, .センス, .発想, .表現, .センス]
        var r = WeekRunner(state: richState(c), year: 1, config: c, rng: SplitMix64(seed: 5))
        var expected = r.state   // 年初の準備を済ませた後の状態が起点
        r.applyAllocation(taps)

        for a in taps { _ = GameEngine.pourStep(a, to: &expected, config: c) }

        let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]
        XCTAssertEqual(try e.encode(r.state), try e.encode(expected))
        XCTAssertGreaterThan(r.state.センス, c.initAbility, "経験点が足りていれば能力が上がる")
    }

    /// 確定は乱数を1つも使わない（golden の消費順を動かさない）
    func testApplyAllocationDoesNotConsumeRandom() {
        let c = GameConfig()
        var r = WeekRunner(state: richState(c), year: 1, config: c, rng: SplitMix64(seed: 5))
        r.applyAllocation([.センス, .発想, .表現])
        var fresh = SplitMix64(seed: 5)
        var used = r.rng
        XCTAssertEqual(used.nextUInt64(), fresh.nextUInt64())
    }

    /// 空のタップ列は何も変えない
    func testApplyAllocationEmptyIsNoop() throws {
        let c = GameConfig()
        var r = WeekRunner(state: richState(c), year: 1, config: c, rng: SplitMix64(seed: 5))
        let before = r.state
        r.applyAllocation([])
        let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]
        XCTAssertEqual(try e.encode(r.state), try e.encode(before))
    }

    /// 飲みの誘いの既定（ボット・golden 台本）は「行く」
    func testDefaultAcceptInviteIsTrue() {
        var p = RestOnlyPolicy()
        XCTAssertTrue(p.acceptInvite(state: GameState(config: GameConfig())))
    }
}
