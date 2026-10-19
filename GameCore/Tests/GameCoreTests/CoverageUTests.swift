// CoverageUTests.swift
// WeekRunner の初期フラグ・年初の飽き進行の境界・週数超過の yearDone・ネタ操作の「存在しないid」no-op・
// 改稿の gain 指定とブースト倍率の固定。Sources は不変。
import XCTest
@testable import GameCore

final class CoverageUTests: XCTestCase {

    private func runner(year: Int = 1, config: GameConfig = GameConfig(), state: GameState? = nil,
                        seedFinal: Bool = false, gpSeeded: Bool = false) -> WeekRunner<SplitMix64> {
        WeekRunner(state: state ?? GameState(config: config), year: year, config: config,
                   rng: SplitMix64(seed: 7), seedFinal: seedFinal, gpSeeded: gpSeeded)
    }

    // MARK: 初期フラグ

    func testDefaultInitFlags() {
        let r = runner()
        XCTAssertTrue(r.isGPAlive)
        XCTAssertFalse(r.isFinalist)
        XCTAssertFalse(r.hasRevival)
        XCTAssertEqual(r.gpRoundsPassed, 0)
        XCTAssertEqual(r.week, 0)
    }

    func testSeedFinalMakesFinalistAndGpSeededSkipsFirstRound() {
        let f = runner(seedFinal: true)
        XCTAssertTrue(f.isFinalist)
        let g = runner(gpSeeded: true)
        XCTAssertEqual(g.gpRoundsPassed, 1)   // 1回戦免除
        XCTAssertFalse(g.isFinalist)
    }

    func testInitRefillsStaminaAndSetsGrowthBudget() {
        let config = GameConfig()
        var s = GameState(config: config)
        s.stamina = 3
        let r = runner(year: 1, config: config, state: s)
        XCTAssertEqual(r.state.stamina, config.initStamina)
        let expected = max(config.capCurveFloor, config.capCurveBase)   // year1 = k=1 のみ
        XCTAssertEqual(r.state.growthBudget ?? -1, expected, accuracy: 1e-9)
    }

    // MARK: 年初の飽き進行

    func testTiredAdvancesOnlyForPreviousYearUseAndCapsAtConfig() {
        var config = GameConfig(); config.netaTiredCap = 2
        var s = GameState(config: config)
        var a = Neta(id: 0, name: "a", kata: .瞬発, lengthFit: [.短尺], bornYear: 1)
        a.lastUsedTaikaiYear = 4; a.tiredYears = 1
        var b = Neta(id: 1, name: "b", kata: .瞬発, lengthFit: [.短尺], bornYear: 1)
        b.lastUsedTaikaiYear = 3; b.tiredYears = 1       // 一昨年＝進まない
        var c = Neta(id: 2, name: "c", kata: .瞬発, lengthFit: [.短尺], bornYear: 1)
        c.lastUsedTaikaiYear = 4; c.tiredYears = 2        // 上限＝据え置き
        var d = Neta(id: 3, name: "d", kata: .瞬発, lengthFit: [.短尺], bornYear: 1)
        d.lastUsedTaikaiYear = 4                           // nil から 1
        s.netas = [a, b, c]
        s.archivedNetas = [d]
        let r = runner(year: 5, config: config, state: s)
        XCTAssertEqual(r.state.netas[0].tiredYears, 2)
        XCTAssertEqual(r.state.netas[1].tiredYears, 1)
        XCTAssertEqual(r.state.netas[2].tiredYears, 2)
        XCTAssertEqual(r.state.archivedNetas[0].tiredYears, 1)
    }

    // MARK: 週数超過

    func testBeginPastWeeksReturnsYearDoneAndKeepsReturningIt() {
        var config = GameConfig(); config.weeks = 1
        var r = runner(config: config)
        _ = r.begin()                    // 1週目（何らかの入力待ち）
        _ = r.resolveAction(.rest(.完全休養))
        let p = r.begin()                // 2週目＝週数超過
        guard case .yearDone(let o) = p else { return XCTFail("yearDone を期待") }
        XCTAssertFalse(o.champion)
        XCTAssertEqual(o.roundsPassed, 0)
        XCTAssertFalse(o.reachedFinal)
        guard case .yearDone = r.begin() else { return XCTFail("yearDone は返り続ける") }
        XCTAssertEqual(r.week, 2)        // 終了後は週が進まない
    }

    // MARK: ネタ操作の境界

    private func withNeta() -> WeekRunner<SplitMix64> {
        var r = runner()
        r.applyNetaCreate(kata: .関係性, lengthFit: [.中尺], name: "n")
        return r
    }

    func testNetaOpsOnUnknownIdAreNoOps() {
        var r = withNeta()
        let before = r.state.netas
        r.applyNetaRevise(id: 99)
        r.applyNetaLive(id: 99, hard: true)
        r.applyNetaRename(id: 99, to: "zzz")
        r.applyNetaChangeKata(id: 99, to: .瞬発)
        r.applyNetaRetire(id: 99)
        r.applyNetaRecall(id: 99)
        XCTAssertEqual(r.state.netas, before)
        XCTAssertTrue(r.state.archivedNetas.isEmpty)
    }

    func testRetireClearsOnlyMatchingSelection() {
        var r = withNeta()
        let id2 = r.applyNetaCreate(kata: .瞬発, lengthFit: [.短尺], name: "m")
        r.applyNetaSelect(id: 0)
        r.applyNetaRetire(id: id2)
        XCTAssertEqual(r.state.selectedNetaID, 0)        // 別ネタの退避では選択は残る
        r.applyNetaRetire(id: 0)
        XCTAssertNil(r.state.selectedNetaID)
        XCTAssertEqual(r.state.archivedNetas.map(\.id), [id2, 0])
        r.applyNetaRecall(id: id2)
        XCTAssertEqual(r.state.netas.map(\.id), [id2])
        XCTAssertEqual(r.state.archivedNetas.map(\.id), [0])
    }

    func testReviseGainOverrideUsesGivenGain() {
        var config = GameConfig(); config.netaReviseGain = 4; config.netaBoostMult = 2
        var r = runner(config: config)
        let id = r.applyNetaCreate(kata: .関係性, lengthFit: [.中尺], name: "n")   // polish 30
        r.applyNetaRevise(id: id)                 // 既定 gain=4
        XCTAssertEqual(r.state.netas[0].polish, 34, accuracy: 1e-9)
        r.applyNetaRevise(id: id, gain: 10)       // 指定 gain
        XCTAssertEqual(r.state.netas[0].polish, 44, accuracy: 1e-9)
    }
}
