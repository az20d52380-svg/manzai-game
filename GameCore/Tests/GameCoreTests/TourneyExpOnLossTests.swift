import XCTest
@testable import GameCore

/// 大会で負けても経験点が少し入る（playtest_v11b #7 の確認：実際の週送り経由）
final class TourneyExpOnLossTests: XCTestCase {
    func testLosingTournamentStillCreditsExp() {
        let cfg = GameConfig()
        func total(_ s: GameState) -> Double { ExpCurrency.allCases.reduce(0) { $0 + s[currency: $1] } }
        var lossesChecked = 0
        for seed in UInt64(1)...60 {
            var r = WeekRunner(state: GameState(config: cfg), year: 1, config: cfg, rng: SplitMix64(seed: seed))
            var phase = r.begin()
            for _ in 0..<200 {
                switch phase {
                case .tournamentDecision:
                    let before = total(r.state)
                    phase = r.resolveTournament(travel: .夜行バス)
                    if case .weekDone(let sm) = phase, let res = sm.results.last, res.isStage, !res.passed {
                        XCTAssertGreaterThan(total(r.state), before, "負けても経験点は入る")
                        lossesChecked += 1
                    }
                case .gpRound, .gpRevival, .gpFinal: phase = r.resolveAuto()
                case .weekDone: phase = r.begin()
                case .freeAction: phase = r.resolveAction(.rest(.完全休養))
                case .yearDone: break
                }
                if case .yearDone = phase { break }
            }
        }
        XCTAssertGreaterThan(lossesChecked, 0, "敗退の例が1件は見つかる")
    }
}
