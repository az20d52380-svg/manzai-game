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
        XCTAssertEqual(s.rift ?? 0, 1.5 * 15 / 20, accuracy: 1e-9)   // 上がらない週：+1.5×(20−5)/20
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
        XCTAssertTrue(GameEngine.applyRiftWeekEnd(year: 2, to: &s, config: config))
        XCTAssertEqual(s.dissolved, true)
    }
}
