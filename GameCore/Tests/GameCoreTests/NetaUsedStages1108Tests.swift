// NetaUsedStages1108Tests.swift
// 大会で掛けたネタの年（lastUsedTaikaiYear）は GP の回戦だけでなく敗者復活・決勝でも付く（WeekRunner.markNetaUsed）。
// 既存の NetaTests.testTournamentMarksSelectedNetaYear は1年通しの結果だけを見る＝どの段で付いたかは見ていない。
// ここでは各段の直前で印を消してから resolveAuto を呼び、その段だけで付くことを確かめる。Sources は不変・乱数・golden 不変。
import XCTest
@testable import GameCore

final class NetaUsedStages1108Tests: XCTestCase {

    private func state(_ config: GameConfig, ability: Double) -> GameState {
        var s = GameState(config: config)
        s.money = 10_000_000
        s.センス = ability; s.発想 = ability; s.表現 = ability; s.華 = ability; s.メンタル = ability
        s.netas = [Neta(id: 1, name: "掛ける", kata: .王道しゃべくり, lengthFit: [.中尺], bornYear: 1),
                   Neta(id: 2, name: "掛けない", kata: .関係性, lengthFit: [.中尺], bornYear: 1)]
        s.selectedNetaID = 1
        return s
    }

    /// 1年を回し、GP の自動の段ごとに「その段だけで印が付くか」を確かめる。見た段の名前を返す
    private func runYear(seed: UInt64, year: Int, ability: Double, seedFinal: Bool) -> Set<String> {
        let config = GameConfig()
        var policy = GoldenPolicy()
        var runner = WeekRunner(state: state(config, ability: ability), year: year, config: config,
                                rng: SplitMix64(seed: seed), seedFinal: seedFinal)
        var seen = Set<String>()
        var phase = runner.begin()
        func clearAndResolve(_ label: String) -> WeekRunner<SplitMix64>.Phase {
            var snap = runner.snapshot()
            for i in snap.state.netas.indices { snap.state.netas[i].lastUsedTaikaiYear = nil }
            runner = WeekRunner(restoring: snap, config: config)
            let next = runner.resolveAuto()
            XCTAssertEqual(runner.state.netas.first { $0.id == 1 }?.lastUsedTaikaiYear, year, "\(label)で選択中のネタに年が付く")
            XCTAssertNil(runner.state.netas.first { $0.id == 2 }?.lastUsedTaikaiYear, "\(label)で選んでいないネタには付かない")
            seen.insert(label)
            return next
        }
        var guardCount = 0
        loop: while guardCount < 2000 {
            guardCount += 1
            switch phase {
            case .tournamentDecision(let spec):
                phase = runner.resolveTournament(travel: policy.enterTournament(spec, year: year, state: runner.state))
            case .freeAction(let offer):
                phase = runner.resolveAction(policy.action(week: runner.week, year: year, state: runner.state, offer: offer))
            case .gpRound:
                phase = clearAndResolve("回戦")
            case .gpRevival:
                phase = clearAndResolve("敗者復活")
            case .gpFinal:
                phase = clearAndResolve("決勝")
            case .weekDone:
                phase = runner.begin()
            case .yearDone:
                break loop
            }
        }
        return seen
    }

    func testFinalStageMarksSelectedNeta() {
        let seen = runYear(seed: 7, year: 3, ability: 40, seedFinal: true)
        XCTAssertTrue(seen.contains("決勝"))
    }

    func testRoundAndRevivalStagesMarkSelectedNeta() {
        var all = Set<String>()
        for seed in UInt64(1)...UInt64(300) where !all.contains("敗者復活") {
            for ability in [30.0, 45.0, 60.0] {
                all.formUnion(runYear(seed: seed, year: 3, ability: ability, seedFinal: false))
                if all.contains("敗者復活") { break }
            }
        }
        XCTAssertTrue(all.contains("回戦"))
        XCTAssertTrue(all.contains("敗者復活"), "敗者復活の段に一度も来なかった（能力・シードの範囲を見直す）")
    }
}
