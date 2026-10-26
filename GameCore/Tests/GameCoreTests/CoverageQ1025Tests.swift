// CoverageQ1025Tests.swift
// 10/20 以降に変わった WeekRunner（restoredPhase・復元時の丸め）と JudgeTalk（band・pickup・hook・pick）の現状固定。Sources/式/golden は不変。

import XCTest
@testable import GameCore

final class CoverageQ1025Tests: XCTestCase {
    typealias Runner = WeekRunner<SplitMix64>
    private let enc: JSONEncoder = { let e = JSONEncoder(); e.outputFormatting = .sortedKeys; return e }()
    private let cfg = GameConfig()

    private func makeRunner() -> Runner {
        Runner(state: GameState(config: cfg), year: 1, config: cfg, rng: SplitMix64(seed: 20_261_025))
    }

    // MARK: WeekRunner

    func testRestoredPhaseIsNilBeforeBegin() {
        XCTAssertNil(makeRunner().restoredPhase)
    }

    func testRestoredPhaseMatchesBeginPhaseAndHasNoSideEffect() throws {
        var r = makeRunner()
        let p = r.begin()
        let before = try enc.encode(r.snapshot())
        switch p {
        case .tournamentDecision, .freeAction, .gpRound, .gpRevival, .gpFinal:
            let again = try XCTUnwrap(r.restoredPhase)
            XCTAssertEqual(try enc.encode(again), try enc.encode(p))
        default: break
        }
        _ = r.restoredPhase
        XCTAssertEqual(try enc.encode(r.snapshot()), before, "副作用・乱数なし")
    }

    func testRestoredPhaseSurvivesSnapshotRestore() throws {
        var r = makeRunner()
        let p = r.begin()
        let restored = Runner(restoring: r.snapshot(), config: cfg)
        if let rp = restored.restoredPhase {
            XCTAssertEqual(try enc.encode(rp), try enc.encode(p))
        }
    }

    func testRestoreClampsGpStageAndDropsRoundPending() {
        var r = makeRunner()
        _ = r.begin()
        var snap = r.snapshot()
        snap.gpStage = 99
        snap.pendingAuto = .round
        let restored = Runner(restoring: snap, config: cfg)
        XCTAssertEqual(restored.gpRoundsPassed, cfg.calendar.gpRounds.count, "回戦数で丸める")
        XCTAssertNil(restored.snapshot().pendingAuto, "丸めた段に回戦は無い")
        XCTAssertFalse(restored.isGPAlive)
    }

    func testRestoreKeepsRevivalPendingEvenWhenStageClamped() {
        var r = makeRunner()
        _ = r.begin()
        var snap = r.snapshot()
        snap.gpStage = 99
        snap.pendingAuto = .revival
        let restored = Runner(restoring: snap, config: cfg)
        XCTAssertEqual(restored.snapshot().pendingAuto, .revival)
    }

    func testRestoreWithinRangeKeepsStageAndGpRoundNamePhase() throws {
        var r = makeRunner()
        _ = r.begin()
        var snap = r.snapshot()
        snap.pendingSpec = nil
        snap.gpStage = 1
        snap.pendingAuto = .round
        let restored = Runner(restoring: snap, config: cfg)
        XCTAssertEqual(restored.gpRoundsPassed, 1)
        guard case .gpRound(let idx, let name)? = restored.restoredPhase else { return XCTFail("gpRound のはず") }
        XCTAssertEqual(idx, 1)
        XCTAssertEqual(name, cfg.calendar.gpRoundNames[1])
    }

    func testRestoredPhaseWeekDoneIsNotRebuilt() throws {
        // 週が閉じた後は currentPhase が pending を持たない＝freeAction/auto にはならない（閉じた週の再現は resolve* 側）
        var r = makeRunner()
        var phase = r.begin()
        for _ in 0..<20 {
            switch phase {
            case .freeAction: phase = r.resolveAction(.rest(.完全休養))
            case .tournamentDecision: phase = r.resolveTournament(travel: nil)
            case .weekDone: break
            default: phase = r.resolveAuto()
            }
            if case .weekDone = phase { break }
        }
        guard case .weekDone = phase else { throw XCTSkip("weekDone に届かず") }
        if let rp = r.restoredPhase { XCTAssertFalse(rp.isFreeAction); XCTAssertFalse(rp.isAuto) }
    }

    func testSnapshotWeekClosedFalseAtStart() {
        var r = makeRunner()
        _ = r.begin()
        XCTAssertEqual(r.snapshot().weekClosed, false)
    }

    // MARK: JudgeTalk

    func testBandBoundaries() {
        XCTAssertEqual(JudgeTalk.band(100), "A")
        XCTAssertEqual(JudgeTalk.band(95), "A")
        XCTAssertEqual(JudgeTalk.band(94), "B")
        XCTAssertEqual(JudgeTalk.band(91), "B")
        XCTAssertEqual(JudgeTalk.band(90), "C")
        XCTAssertEqual(JudgeTalk.band(87), "C")
        XCTAssertEqual(JudgeTalk.band(86), "D")
        XCTAssertEqual(JudgeTalk.band(0), "D")
    }

    func testPickupMatchesByPrefixAndRepliesAreFilled() {
        for p in JudgeTalk.pickups {
            let got = JudgeTalk.pickup(after: p.head + "続き")
            XCTAssertEqual(got?.mc, p.mc)
            if let reply = got?.reply { XCTAssertFalse(reply.contains("{"), "差し込み済み") }
            else { XCTAssertNil(p.reply) }
        }
        XCTAssertNil(JudgeTalk.pickup(after: "関係ない講評です。"))
    }

    func testIsLowOnlyIsPrefixBased() {
        XCTAssertTrue(JudgeTalk.isLowOnly("点は辛うつけたけど、好きは好きやねん。"))
        XCTAssertFalse(JudgeTalk.isLowOnly("好きは好きやねん。点は辛うつけたけど"))
    }

    func testHookLinesRequireMatchingStateAndSide() {
        // 相性が高く最高点の天堂寺：フックあり／最低点側（high=false）では褒めフックは出ない
        let compat = JudgeTalk.Scene(compat: 20)
        XCTAssertNotNil(JudgeTalk.hookLines(judge: "天堂寺 銀郎", scene: compat, high: true))
        XCTAssertNil(JudgeTalk.hookLines(judge: "天堂寺 銀郎", scene: compat, high: false))
        // 疲れ（体力<30）は最低点側だけ
        let tired = JudgeTalk.Scene(stamina: 10)
        XCTAssertNotNil(JudgeTalk.hookLines(judge: "天堂寺 銀郎", scene: tired, high: false))
        XCTAssertNil(JudgeTalk.hookLines(judge: "天堂寺 銀郎", scene: tired, high: true))
        // 既定の場面はフックなし・未知の審査員も nil
        XCTAssertNil(JudgeTalk.hookLines(judge: "天堂寺 銀郎", scene: JudgeTalk.Scene(), high: true))
        XCTAssertNil(JudgeTalk.hookLines(judge: "だれか", scene: compat, high: true))
    }

    func testRevivalAndHanaHooksForHighSide() {
        XCTAssertNotNil(JudgeTalk.hookLines(judge: "花園 千代", scene: JudgeTalk.Scene(viaRevival: true), high: true))
        XCTAssertNotNil(JudgeTalk.hookLines(judge: "卯月 走太", scene: JudgeTalk.Scene(hana: 90), high: true))
        XCTAssertNil(JudgeTalk.hookLines(judge: "卯月 走太", scene: JudgeTalk.Scene(hana: 89), high: true))
        XCTAssertNotNil(JudgeTalk.hookLines(judge: "音羽 ルリ", scene: JudgeTalk.Scene(mental: 39), high: false))
        XCTAssertNil(JudgeTalk.hookLines(judge: "音羽 ルリ", scene: JudgeTalk.Scene(mental: 40), high: false))
    }

    func testPickDropsTitleLinesWhenNoNetaNameAndFallsBackWhenAllDropped() {
        let none = JudgeTalk.Scene()
        let named = JudgeTalk.Scene(netaName: "福引")
        let pool = ["{題}の話", "ふつうの話"]
        for k in 0..<10 {
            XCTAssertEqual(JudgeTalk.pick(pool, scene: none, salt: 1, k: k), "ふつうの話")
        }
        XCTAssertEqual(JudgeTalk.pick(["{題}だけ"], scene: none, salt: 1, k: 0), "{題}だけ", "全部外れたら元の候補")
        XCTAssertNil(JudgeTalk.pick([], scene: named, salt: 1, k: 0))
        XCTAssertNotNil(JudgeTalk.pick(pool, scene: named, salt: 1, k: 0))
    }

    func testFinalCommentHighNeverUsesLowOnlyLineAndIsFilled() {
        for j in JudgeTalk.judgeNames {
            for salt in 0..<30 {
                let c = JudgeTalk.finalComment(judge: j, score: 96, high: true, scene: JudgeTalk.Scene(), salt: salt)
                XCTAssertFalse(JudgeTalk.isLowOnly(c.text))
                XCTAssertFalse(c.text.contains("{"), "未差し込みの印が残らない")
                XCTAssertFalse(c.text.isEmpty)
            }
        }
    }
}
