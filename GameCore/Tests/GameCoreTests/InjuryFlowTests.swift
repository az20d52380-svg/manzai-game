// InjuryFlowTests.swift
// 体調ダウン→療養の流れを WeekRunner で固定（懸念の台帳 L54「発生 draw を固定した網羅」）。Sources は不変。

import XCTest
@testable import GameCore

final class InjuryFlowTests: XCTestCase {
    let cfg = GameConfig()

    /// 自由週は毎回 action を選び、週ごとに (週, 行動前の体力 or nil=自由週なし, 結果名) を記録して1年回す
    private func trace(draw: Double, action: WeekAction) -> [(week: Int, preStamina: Double?, names: [String], recovery: Int)] {
        var s = GameState(config: cfg)
        s.money = 10_000_000
        var r = WeekRunner(state: s, year: 1, config: cfg, rng: FixedRandom(value: draw))
        var out: [(Int, Double?, [String], Int)] = []
        var pre: Double? = nil
        var phase = r.begin()
        var steps = 0
        while steps < 3000 {
            steps += 1
            switch phase {
            case .tournamentDecision: phase = r.resolveTournament(travel: nil)
            case .freeAction:
                pre = r.state.stamina
                phase = r.resolveAction(action)
            case .weekDone(let sum):
                out.append((sum.week, pre, sum.results.map(\.name), sum.state.recoveryWeeks))
                pre = nil
                phase = r.begin()
            case .yearDone: return out
            default: phase = r.resolveAuto()
            }
        }
        XCTFail("1年が終わらない")
        return out
    }

    func testInjuryFiresAtFirstRiskyWeekBelowThresholdThenTwoRecoveryWeeks() {
        let t = trace(draw: 0.0, action: .job(.キツい))   // draw=0 は確率>0 なら必ず当たる
        guard let i = t.firstIndex(where: { ($0.preStamina ?? 999) < cfg.injuryThreshold }) else {
            return XCTFail("体力が閾値を割らない")
        }
        XCTAssertFalse(t[..<i].contains { $0.names.contains("体調ダウン") }, "閾値より上では起きない")
        XCTAssertTrue(t[i].names.contains("体調ダウン"))
        XCTAssertEqual(t[i].recovery, cfg.injuryRestWeeks - 1)
        // 続く療養の週は自由週が出ず（行動前の体力 nil）、「療養」が残り週数ぶん並ぶ
        let rest = t[(i + 1)...].prefix(cfg.injuryRestWeeks - 1)
        XCTAssertEqual(rest.count, cfg.injuryRestWeeks - 1)
        for (k, w) in rest.enumerated() {
            XCTAssertNil(w.preStamina, "第\(w.week)週：療養中は行動を選ばない")
            XCTAssertTrue(w.names.contains("療養"))
            XCTAssertEqual(w.recovery, cfg.injuryRestWeeks - 2 - k)
        }
    }

    func testNoInjuryWhenDrawIsHighOrActionIsSafe() {
        XCTAssertFalse(trace(draw: 0.999, action: .job(.キツい)).contains { $0.names.contains("体調ダウン") })
        XCTAssertFalse(trace(draw: 0.0, action: .rest(.完全休養)).contains { $0.names.contains("体調ダウン") })
    }
}
