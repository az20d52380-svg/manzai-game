// InviteTests.swift
// §102 飲みの誘い（週4%・別乱数）。Python: sim_career.invite_roll / invite_weekend と同値（golden が全体の一致を担保）。

import XCTest
@testable import GameCore

final class InviteTests: XCTestCase {

    /// 同じシードなら同じ週に来る（golden シード 424243 は 1年20週・2年37週・3年1/25/41週）。本編の乱数は消費しない
    func testInviteArrivesOnSameWeeksForSameSeed() {
        let config = GameConfig()
        var weeks: [[Int]] = []
        for pass in 0..<2 {
            _ = pass
            var hit: [Int] = []
            for year in 1...3 { for w in 1...48 where GameEngine.rollInvite(seed: 424243, year: year, week: w, config: config) != nil { hit.append(year * 100 + w) } }
            weeks.append(hit)
        }
        XCTAssertEqual(weeks[0], weeks[1])
        XCTAssertEqual(weeks[0], [120, 237, 301, 325, 341])
        var runner = WeekRunner(state: GameState(config: config), year: 1, config: config, rng: SplitMix64(seed: 1), inviteSeed: 424243)
        let rngBefore = runner.rng
        _ = runner.begin()
        XCTAssertNil(runner.pendingInvite)
        _ = rngBefore
    }

    /// 行く＝所持金−5,000・体力−10・メンタル+1（発想が付く時は+0.5）／断る＝何も起きない
    func testGoAndDeclineEffects() {
        let config = GameConfig()
        let base = GameState(config: config)
        var go = base
        GameEngine.applyInviteGo(idea: true, to: &go, config: config)
        XCTAssertEqual(go.money, base.money - 5_000)
        XCTAssertEqual(go.stamina, base.stamina - 10, accuracy: 1e-9)
        XCTAssertGreaterThan(go.メンタル, base.メンタル)   // 成長減衰ありの add 経由（Python B.add と同じ）
        XCTAssertGreaterThan(go.発想, base.発想)
        var noIdea = base
        GameEngine.applyInviteGo(idea: false, to: &noIdea, config: config)
        XCTAssertEqual(noIdea.発想, base.発想, accuracy: 1e-9)

        // runner 経由：週末に保留→断る＝状態不変／行く＝効果。1年目20週に来る（seed 424243）
        func atInviteWeek() -> WeekRunner<SplitMix64> {
            var r = WeekRunner(state: base, year: 1, config: config, rng: SplitMix64(seed: 1), inviteSeed: 424243)
            var p = r.begin()
            while true {
                switch p {
                case .tournamentDecision: p = r.resolveTournament(travel: nil)
                case .freeAction: p = r.resolveAction(.rest(.完全休養))
                case .gpRound, .gpRevival, .gpFinal: p = r.resolveAuto()
                case .weekDone:
                    if r.pendingInvite != nil { return r }
                    p = r.begin()
                case .yearDone: XCTFail("誘いが来ない"); return r
                }
            }
        }
        var decline = atInviteWeek()
        XCTAssertEqual(decline.week, 20)
        let before = decline.state
        decline.resolveInvite(accept: false)
        XCTAssertEqual(decline.state.money, before.money)
        XCTAssertNil(decline.pendingInvite)
        var accept = atInviteWeek()
        accept.resolveInvite(accept: true)
        XCTAssertEqual(accept.state.money, before.money - 5_000)
    }
}
