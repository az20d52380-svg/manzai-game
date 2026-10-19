// CoverageSTests.swift
// WeekRunner.resolveTournament の資金境界（エントリー費＋大阪交通費）と新幹線回数券の固定。
// Sources は不変。

import XCTest
@testable import GameCore

final class CoverageSTests: XCTestCase {
    let cfg = GameConfig()

    /// 年1の最初の大会判断（春新人賞A・大阪開催）まで休養で進めたランナー
    func runnerAtOsakaDecision() -> WeekRunner<SplitMix64> {
        var r = WeekRunner(state: GameState(config: cfg), year: 1, config: cfg, rng: SplitMix64(seed: 7))
        var phase = r.begin()
        while true {
            switch phase {
            case .tournamentDecision(let spec):
                XCTAssertTrue(spec.osaka)
                return r
            case .freeAction: phase = r.resolveAction(.rest(.完全休養))
            case .weekDone: phase = r.begin()
            case .gpRound, .gpRevival, .gpFinal: phase = r.resolveAuto()
            case .yearDone: XCTFail("大阪の大会判断に到達しなかった"); return r
            }
        }
    }

    /// 判断直前のスナップショットを書き換えて復元（state は外から代入できないため）
    func prepared(money: Int, ticket: Bool = false) -> WeekRunner<SplitMix64> {
        var snap = runnerAtOsakaDecision().snapshot()
        snap.state.money = money
        if ticket { snap.state.shinkansenActive = true }
        return WeekRunner(restoring: snap, config: cfg)
    }

    func results(_ p: WeekRunner<SplitMix64>.Phase) -> [StageResult] {
        if case .weekDone(let sm) = p { return sm.results }
        return []
    }

    func testBusNeedsEntryFeePlusTravelExactly() {
        let fee = cfg.calendar.entryFee, bus = cfg.calendar.busTravel
        var r = prepared(money: fee + bus.cost - 1)
        let st = r.state.stamina
        let res = results(r.resolveTournament(travel: .夜行バス))
        XCTAssertTrue(res.isEmpty)                          // 1円足りず不出場
        XCTAssertEqual(r.state.money, fee + bus.cost - 1)   // 何も引かれない
        XCTAssertEqual(r.state.stamina, st)
    }

    func testBusEntersWhenMoneyExactlyEnough() {
        let fee = cfg.calendar.entryFee, bus = cfg.calendar.busTravel
        var r = prepared(money: fee + bus.cost)
        let res = results(r.resolveTournament(travel: .夜行バス))
        XCTAssertEqual(res.count, 1)
        var base = prepared(money: fee + bus.cost)          // 同条件で不出場にした週末の所持金（生活費込み）
        _ = base.resolveTournament(travel: nil)
        _ = base.resolveAction(.rest(.完全休養))   // 不出場なら自由行動週になる
        let prize = res[0].passed ? res[0].prize : 0
        XCTAssertEqual(r.state.money, base.state.money - fee - bus.cost + prize)
    }

    func testShinkansenTicketMakesTravelFree() {
        let fee = cfg.calendar.entryFee
        var r = prepared(money: fee, ticket: true)          // 交通費0＝エントリー費ちょうどで出られる
        let res = results(r.resolveTournament(travel: .夜行バス))   // バスを選んでも回数券が優先
        XCTAssertEqual(res.count, 1)
        var base = prepared(money: fee, ticket: true)
        _ = base.resolveTournament(travel: nil)
        _ = base.resolveAction(.rest(.完全休養))   // 不出場なら自由行動週になる
        let prize = res[0].passed ? res[0].prize : 0
        XCTAssertEqual(r.state.money, base.state.money - fee + prize)   // 交通費は引かれない
        var bus = prepared(money: 1_000_000)                // 同じ乱数・同じ状態でチケット無しのバス
        let busRes = results(bus.resolveTournament(travel: .夜行バス))
        XCTAssertEqual(busRes[0].passed, res[0].passed)
        XCTAssertEqual(r.state.stamina - bus.state.stamina, 25, accuracy: 1e-9)   // バスの体力-25が掛からない
    }

    func testShinkansenTicketStillNeedsEntryFee() {
        let fee = cfg.calendar.entryFee
        var r = prepared(money: fee - 1, ticket: true)
        let res = results(r.resolveTournament(travel: .新幹線))
        XCTAssertTrue(res.isEmpty)
        XCTAssertEqual(r.state.money, fee - 1)
    }

    func testNilTravelSkipsWithoutCost() {
        var r = prepared(money: 1_000_000)
        let res = results(r.resolveTournament(travel: nil))
        XCTAssertTrue(res.isEmpty)
        XCTAssertEqual(r.state.money, 1_000_000)
    }
}
