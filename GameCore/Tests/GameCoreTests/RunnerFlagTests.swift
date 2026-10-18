// RunnerFlagTests.swift
// テストから一度も読まれていなかった表示用の読み取り専用プロパティ
// （WeekRunner.isGPAlive / isFinalist / hasRevival・GameState.expTotal）の値を、GP の進み方ごとに確かめる。
// ★式・乱数・golden には触れない（ラインを極端値に固定して経路だけを見る＝CareerLogicTests と同じ作法）。

import XCTest
@testable import GameCore

final class RunnerFlagTests: XCTestCase {

    private func config(semiLine: Double, revivalLine: Double) -> GameConfig {
        var c = GameConfig()
        c.calendar.tournaments = []
        c.offerRates = [(999, 0.0)]
        c.calendar.gpRounds = [(30, -999), (39, -999), (41, -999), (43, -999), (45, semiLine)]
        c.calendar.gpRevivalLine = revivalLine
        c.calendar.gpFinalLine = -999
        return c
    }

    /// GP の各回戦の直後に (通過数, isGPAlive, isFinalist, hasRevival) を記録しながら1年回す
    private func trace(_ c: GameConfig) -> [(Int, Bool, Bool, Bool)] {
        var s = GameState(config: c)
        s.money = 10_000_000
        var r = WeekRunner(state: s, year: 1, config: c, rng: FixedRandom(value: 0.5))
        XCTAssertTrue(r.isGPAlive); XCTAssertFalse(r.isFinalist); XCTAssertFalse(r.hasRevival)
        var out: [(Int, Bool, Bool, Bool)] = []
        var phase = r.begin()
        var guardSteps = 0
        while guardSteps < 2000 {
            guardSteps += 1
            switch phase {
            case .tournamentDecision: phase = r.resolveTournament(travel: nil)
            case .freeAction: phase = r.resolveAction(.rest(.完全休養))
            case .gpRound:
                phase = r.resolveAuto()
                out.append((r.gpRoundsPassed, r.isGPAlive, r.isFinalist, r.hasRevival))
            case .weekDone: phase = r.begin()
            case .yearDone: return out
            default: phase = r.resolveAuto()
            }
        }
        XCTFail("1年が終わらない")
        return out
    }

    /// 5回戦すべて通過＝決勝進出：最後は通過5・決勝の資格あり・敗者復活なし
    func testAllRoundsPassedMakesFinalist() {
        let t = trace(config(semiLine: -999, revivalLine: -999))
        XCTAssertEqual(t.count, 5)
        for (i, row) in t.dropLast().enumerated() {
            XCTAssertEqual(row.0, i + 1)
            XCTAssertTrue(row.1, "途中の回戦では GP に残っている")
            XCTAssertFalse(row.2)
        }
        let last = t.last!
        XCTAssertEqual(last.0, 5)
        XCTAssertTrue(last.2, "準決勝通過で決勝の資格")
        XCTAssertFalse(last.3, "通過組に敗者復活は無い")
    }

    /// 準決勝だけ落ちる：通過4のまま、敗者復活に回る（hasRevival）・まだ決勝の資格は無い
    func testSemifinalLossGoesToRevival() {
        let t = trace(config(semiLine: 999, revivalLine: -999))
        XCTAssertEqual(t.count, 5)
        let last = t.last!
        XCTAssertEqual(last.0, 4)
        XCTAssertTrue(last.3, "準決勝敗退は敗者復活へ")
        XCTAssertFalse(last.2)
    }

    /// 1回戦で落ちる（全ライン999）：GP から外れる・以降の回戦は来ない
    func testFirstRoundLossLeavesGP() {
        var c = config(semiLine: 999, revivalLine: 999)
        c.calendar.gpRounds = c.calendar.gpRounds.map { ($0.0, 999) }
        let t = trace(c)
        XCTAssertEqual(t.count, 1)
        XCTAssertEqual(t[0].0, 0)
        XCTAssertFalse(t[0].1, "敗退で GP から外れる")
        XCTAssertFalse(t[0].2); XCTAssertFalse(t[0].3)
    }

    func testExpTotalSumsFiveCurrencies() {
        var s = GameState(config: GameConfig())
        s.exp閃き = 1; s.exp語彙 = 2; s.exp間合い = 3; s.exp存在感 = 4; s.exp胆力 = 5.5
        XCTAssertEqual(s.expTotal, 15.5, accuracy: 1e-9)
    }
}
