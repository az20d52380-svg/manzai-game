// InjuryMentalHitTests.swift
// 体調ダウンの週にメンタルが injuryMentalHit だけ下がることを固定する（InjuryFlowTests は発生と療養の週数だけを見ていた）。
// 同じ乱数・同じ行動で injuryMentalHit だけを 0 にした設定と比べ、差がちょうど injuryMentalHit になるかを見る。Sources／式／golden は不変。

import XCTest
@testable import GameCore

final class InjuryMentalHitTests: XCTestCase {
    /// 1年回して、最初に体調ダウンが起きた週の終わりの状態を返す
    private func stateAtFirstInjury(config: GameConfig) -> (week: Int, state: GameState)? {
        var s = GameState(config: config)
        s.money = 10_000_000
        s.メンタル = 30
        var r = WeekRunner(state: s, year: 1, config: config, rng: FixedRandom(value: 0.0))   // draw=0：確率>0 なら必ず当たる
        var phase = r.begin()
        var steps = 0
        while steps < 3000 {
            steps += 1
            switch phase {
            case .tournamentDecision: phase = r.resolveTournament(travel: nil)
            case .freeAction: phase = r.resolveAction(.job(.キツい))
            case .weekDone(let sum):
                if sum.results.contains(where: { $0.name == "体調ダウン" }) { return (sum.week, sum.state) }
                phase = r.begin()
            case .yearDone: return nil
            default: phase = r.resolveAuto()
            }
        }
        return nil
    }

    /// 同じ週の休養の伸び（growthDecayD の逓減＝メンタルが低いほど伸びる）で差が少し縮むので、逓減を切って厳密に見る
    func testInjuryWeekLowersMentalByInjuryMentalHit() {
        var base = GameConfig()
        base.growthDecayD = nil
        XCTAssertLessThan(base.injuryMentalHit, 0, "体調ダウンはメンタルを下げる値")
        var noHit = base
        noHit.injuryMentalHit = 0
        guard let a = stateAtFirstInjury(config: base), let b = stateAtFirstInjury(config: noHit) else {
            return XCTFail("体調ダウンが起きない")
        }
        XCTAssertEqual(a.week, b.week, "メンタルの差は発生の週を変えない（発生は体力だけで決まる）")
        XCTAssertEqual(a.state.メンタル - b.state.メンタル, base.injuryMentalHit, accuracy: 1e-9)
        XCTAssertEqual(a.state.stamina, b.state.stamina, accuracy: 1e-9, "体力には効かない")
        XCTAssertEqual(a.state.money, b.state.money, "お金には効かない")
    }

    /// 既定の設定（逓減あり）では、差は injuryMentalHit 以上・0 未満（休養の伸びで少しだけ戻る）
    func testInjuryMentalHitWithDefaultDecayIsSlightlySoftened() {
        let base = GameConfig()
        var noHit = base
        noHit.injuryMentalHit = 0
        guard let a = stateAtFirstInjury(config: base), let b = stateAtFirstInjury(config: noHit) else {
            return XCTFail("体調ダウンが起きない")
        }
        let d = a.state.メンタル - b.state.メンタル
        XCTAssertLessThan(d, 0)
        XCTAssertGreaterThanOrEqual(d, base.injuryMentalHit - 1e-9)
    }

    func testInjuryMentalHitClampsAtZero() {
        var c = GameConfig()
        c.injuryMentalHit = -1_000
        guard let a = stateAtFirstInjury(config: c) else { return XCTFail("体調ダウンが起きない") }
        XCTAssertGreaterThanOrEqual(a.state.メンタル, 0, "メンタルは0より下にならない")
    }
}
