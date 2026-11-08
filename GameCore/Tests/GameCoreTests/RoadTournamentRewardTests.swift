// RoadTournamentRewardTests.swift
// 道中の大会：勝てば 参加費（＋大阪は交通費）を払って賞金と知名度が入る／負ければ払うだけ、を1年の通しで全大会ぶん固定する。
// これまでは参加費と交通費の境目（CoverageSTests）と負けても経験点（TourneyExpOnLossTests）だけだった。Sources／式／golden は不変。

import XCTest
@testable import GameCore

final class RoadTournamentRewardTests: XCTestCase {
    private func config(line: Double) -> GameConfig {
        var c = GameConfig()
        c.calendar.tournaments = c.calendar.tournaments.map {
            TournamentSpec(name: $0.name, week: $0.week, line: line, prize: $0.prize, fame: $0.fame, osaka: $0.osaka, eligibility: $0.eligibility)
        }
        return c
    }

    /// 1年回し、出られる道中の大会に夜行バスで全部出て、大会ごとに (名前, お金の差, 知名度の差, 期待のお金, 期待の知名度, 通過) を返す
    private func run(line: Double) -> [(name: String, dMoney: Int, dFame: Double, eMoney: Int, eFame: Double, passed: Bool)] {
        let c = config(line: line)
        let cal = c.calendar
        var s = GameState(config: c)
        s.money = 50_000_000
        s.fame = 5
        var r = WeekRunner(state: s, year: 1, config: c, rng: SplitMix64(seed: 21))
        var out: [(String, Int, Double, Int, Double, Bool)] = []
        var phase = r.begin()
        var steps = 0
        while steps < 10_000 {
            steps += 1
            switch phase {
            case .tournamentDecision(let spec):
                let before = r.state
                phase = r.resolveTournament(travel: .夜行バス)
                // 通ったかどうかは週の結果（StageResult）で見る
                var passed = false
                if case .weekDone(let sum) = phase { passed = sum.results.first(where: { $0.name == spec.name })?.passed ?? false }
                var eMoney = -cal.entryFee - (spec.osaka ? cal.busTravel.cost : 0)
                var expect = before
                if passed {
                    eMoney += spec.prize
                    GameEngine.add(.知名度, spec.fame, to: &expect, config: c)
                }
                // weekDone の時点の状態は週末処理（生活費）の後なので、その週の生活費を足し戻して比べる
                let after: GameState
                if case .weekDone(let sum) = phase { after = sum.state } else { after = r.state }
                let living = (spec.week % c.livingInterval == 0) ? GameEngine.livingCostDue(before, config: c) : 0
                out.append((spec.name, after.money - before.money + living, after.fame - before.fame, eMoney, expect.fame - before.fame, passed))
            case .freeAction: phase = r.resolveAction(.rest(.完全休養))
            case .weekDone: phase = r.begin()
            case .yearDone: return out
            default: phase = r.resolveAuto()
            }
        }
        XCTFail("1年が終わらない")
        return out
    }

    func testWinningRoadTournamentsPayPrizeAndFame() {
        let t = run(line: -10_000)
        XCTAssertFalse(t.isEmpty, "道中の大会が1つも出ない")
        for row in t {
            XCTAssertTrue(row.passed, row.name)
            XCTAssertEqual(row.dMoney, row.eMoney, "\(row.name) のお金")
            XCTAssertEqual(row.dFame, row.eFame, accuracy: 1e-9, "\(row.name) の知名度")
            XCTAssertGreaterThan(row.eFame, 0, "\(row.name)：勝てば知名度が上がる")
        }
    }

    func testLosingRoadTournamentsOnlyCostFees() {
        let t = run(line: 10_000)
        XCTAssertFalse(t.isEmpty)
        for row in t {
            XCTAssertFalse(row.passed, row.name)
            XCTAssertEqual(row.dMoney, row.eMoney, "\(row.name)：払うだけ")
            XCTAssertLessThan(row.dMoney, 0)
            XCTAssertEqual(row.dFame, 0, accuracy: 1e-9, "\(row.name)：負けても知名度は動かない")
        }
    }
}
