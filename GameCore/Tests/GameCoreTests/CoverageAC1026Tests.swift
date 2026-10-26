// CoverageAC1026Tests.swift
// カバー率の残り（10/26 定期・llvm-cov で 0 回の領域）を埋める現状固定。Sources/式/golden は不変。
// ①回戦名が足りない設定での「GP回戦N」の予備名 ②年が終わった後の restoredPhase
// ③今の設定に無い大会・オファー名を持つ中断セーブの復元（保存時の値をそのまま使う）

import XCTest
@testable import GameCore

final class CoverageAC1026Tests: XCTestCase {
    typealias Runner = WeekRunner<SplitMix64>
    private let enc: JSONEncoder = { let e = JSONEncoder(); e.outputFormatting = .sortedKeys; return e }()

    private func step(_ r: inout Runner, _ p: Runner.Phase) -> Runner.Phase {
        switch p {
        case .freeAction: return r.resolveAction(.job(.標準))
        case .tournamentDecision: return r.resolveTournament(travel: .夜行バス)
        case .gpRound, .gpRevival, .gpFinal: return r.resolveAuto()
        case .weekDone: return r.begin()
        case .yearDone: return p
        }
    }

    // MARK: ① 回戦名の予備

    func testGpRoundNameFallsBackWhenNamesMissing() {
        var cfg = GameConfig()
        cfg.calendar.gpRoundNames = []
        var r = Runner(state: GameState(config: cfg), year: 1, config: cfg, rng: SplitMix64(seed: 20_261_026))
        var p = r.begin()
        var seen: [(Int, String)] = []
        for _ in 0..<600 {
            if case .gpRound(let i, let n) = p { seen.append((i, n)) }
            if case .yearDone = p { break }
            p = step(&r, p)
        }
        XCTAssertFalse(seen.isEmpty, "回戦に届くはず（バイト標準でエントリー費は払える）")
        for (i, n) in seen { XCTAssertEqual(n, "GP回戦\(i + 1)") }
    }

    func testRestoredGpRoundPhaseUsesFallbackName() {
        let base = GameConfig()
        var r = Runner(state: GameState(config: base), year: 1, config: base, rng: SplitMix64(seed: 7))
        _ = r.begin()
        var snap = r.snapshot()
        snap.pendingSpec = nil
        snap.gpStage = 2
        snap.pendingAuto = .round
        var cfg = base
        cfg.calendar.gpRoundNames = ["だけ1つ"]
        let restored = Runner(restoring: snap, config: cfg)
        guard case .gpRound(let idx, let name)? = restored.restoredPhase else { return XCTFail("gpRound のはず") }
        XCTAssertEqual(idx, 2)
        XCTAssertEqual(name, "GP回戦3")
    }

    // MARK: ② 年が終わった後

    func testRestoredPhaseIsYearDoneAfterFinish() throws {
        let cfg = GameConfig()
        var r = Runner(state: GameState(config: cfg), year: 1, config: cfg, rng: SplitMix64(seed: 20_260_724))
        var p = r.begin()
        for _ in 0..<600 {
            if case .yearDone = p { break }
            p = step(&r, p)
        }
        guard case .yearDone = p else { return XCTFail("年が終わらない") }
        guard case .yearDone? = r.restoredPhase else { return XCTFail("終わった後は yearDone") }
        // 終わった後の resolve* は段違い＝何もせず yearDone を返す（二度押しの守り）
        let before = try enc.encode(r.snapshot())
        guard case .yearDone = r.resolveAuto() else { return XCTFail("resolveAuto も yearDone") }
        guard case .yearDone = r.resolveAction(.rest(.完全休養)) else { return XCTFail("resolveAction も yearDone") }
        XCTAssertEqual(try enc.encode(r.snapshot()), before, "状態・乱数は動かない")
    }

    // MARK: ③ 今の設定に無い名前の中断セーブ

    func testRestoreKeepsSnapshotSpecWhenWeekHasNoTournament() throws {
        let cfg = GameConfig()
        let spec = try XCTUnwrap(cfg.calendar.tournaments.first)
        let freeWeek = try XCTUnwrap((1...cfg.weeks).first { cfg.calendar.tournament(inWeek: $0) == nil })
        var r = Runner(state: GameState(config: cfg), year: 1, config: cfg, rng: SplitMix64(seed: 3))
        _ = r.begin()
        var snap = r.snapshot()
        snap.week = freeWeek
        snap.pendingSpec = spec
        let restored = Runner(restoring: snap, config: cfg)
        XCTAssertEqual(try enc.encode(restored.snapshot().pendingSpec), try enc.encode(spec), "週に大会が無ければ保存時の大会のまま")
    }

    func testRestoreKeepsUnknownOfferAndMapsKnownChoices() throws {
        let cfg = GameConfig()
        let unknown = OfferSpec(name: "消えた仕事", income: 1234, fame: 0.5, ability: nil, stamina: 3)
        var r = Runner(state: GameState(config: cfg), year: 1, config: cfg, rng: SplitMix64(seed: 4))
        _ = r.begin()
        var snap = r.snapshot()
        snap.pendingOffer = unknown
        let known = cfg.offerMoney
        let stale = OfferSpec(name: known.name, income: known.income + 999, fame: known.fame, ability: nil, stamina: known.stamina)
        snap.offerChoices = [unknown, stale]
        let restored = Runner(restoring: snap, config: cfg).snapshot()
        XCTAssertEqual(restored.pendingOffer?.name, "消えた仕事")
        XCTAssertEqual(restored.pendingOffer?.income, 1234, "設定に無い名前は保存時の値")
        XCTAssertEqual(restored.offerChoices?.map(\.name), ["消えた仕事", known.name])
        XCTAssertEqual(restored.offerChoices?[0].income, 1234)
        XCTAssertEqual(restored.offerChoices?[1].income, known.income, "設定に有る名前は今の値で取り直す")
    }

    // MARK: ④ 設定の表に無い行動（アプリ更新で表から外した時の守り）

    func testActionsMissingFromConfigTablesAreNoOps() throws {
        var cfg = GameConfig()
        let t = try XCTUnwrap(Training.allCases.first), j = try XCTUnwrap(Job.allCases.first)
        let r = try XCTUnwrap(Rest.allCases.first { (cfg.restCosts[$0] ?? 0) == 0 })
        cfg.trainings[t] = nil; cfg.jobs[j] = nil; cfg.rests[r] = nil
        let base = GameState(config: cfg)
        let before = try enc.encode(base)
        var s = base
        XCTAssertFalse(GameEngine.applyTraining(t, to: &s, config: cfg), "表に無い稽古は失敗を返す")
        GameEngine.applyJob(j, to: &s, config: cfg)
        GameEngine.applyRest(r, to: &s, config: cfg)
        XCTAssertEqual(try enc.encode(s), before, "状態は一切動かない")
    }
}
