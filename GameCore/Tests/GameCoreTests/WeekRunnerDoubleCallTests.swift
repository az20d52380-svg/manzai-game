// WeekRunnerDoubleCallTests.swift
// 懸念の台帳 L37：週が閉じた（weekDone を返した）後の resolve* の再呼び出しは何もしない。
// 正しい呼び順では守りが立たない＝乱数消費順・golden 不変（golden 系テストが担保）。

import XCTest
@testable import GameCore

final class WeekRunnerDoubleCallTests: XCTestCase {

    private let enc: JSONEncoder = { let e = JSONEncoder(); e.outputFormatting = .sortedKeys; return e }()

    /// 自由週まで進めて休みを選び、weekDone の直後の状態を返す
    private func runnerAtWeekDone(config: GameConfig) throws -> (WeekRunner<SplitMix64>, WeekRunner<SplitMix64>.Phase) {
        var r = WeekRunner(state: GameState(config: config), year: 1, config: config, rng: SplitMix64(seed: 20_261_025))
        var phase = r.begin()
        for _ in 0..<20 {
            switch phase {
            case .freeAction:
                phase = r.resolveAction(.rest(.完全休養))
                guard case .weekDone = phase else { throw XCTSkip("休みの後が weekDone でない") }
                return (r, phase)
            case .tournamentDecision: phase = r.resolveTournament(travel: nil)
            case .weekDone: phase = r.begin()
            default: phase = r.resolveAuto()
            }
        }
        throw XCTSkip("20歩のうちに自由週が来なかった")
    }

    func testResolveActionTwiceAfterWeekDoneIsNoOp() throws {
        let config = GameConfig()
        var (r, first) = try runnerAtWeekDone(config: config)
        let before = try enc.encode(r.snapshot())
        let again = r.resolveAction(.job(.キツい))   // 二度押し（別の行動）
        XCTAssertEqual(try enc.encode(again), try enc.encode(first), "同じ週の結果を返す")
        XCTAssertEqual(try enc.encode(r.snapshot()), before, "生活費・乱数・状態が動かない")
        _ = r.resolveTournament(travel: .夜行バス)
        _ = r.resolveAuto()
        XCTAssertEqual(try enc.encode(r.snapshot()), before, "他の resolve も何もしない")
    }

    func testBeginReopensNextWeek() throws {
        let config = GameConfig()
        var (r, _) = try runnerAtWeekDone(config: config)
        let week = r.week
        _ = r.resolveAction(.rest(.完全休養))
        _ = r.begin()
        XCTAssertEqual(r.week, week + 1, "begin() で次の週へ進み、守りは外れる")
    }

    func testWeekClosedSurvivesSnapshotAndOldSavesDefaultOpen() throws {
        let config = GameConfig()
        let (r, _) = try runnerAtWeekDone(config: config)
        var snap = r.snapshot()
        XCTAssertEqual(snap.weekClosed, true)
        var restored = WeekRunner(restoring: snap, config: config)
        let before = try enc.encode(restored.snapshot())
        _ = restored.resolveAction(.rest(.完全休養))
        XCTAssertEqual(try enc.encode(restored.snapshot()), before, "復元後も閉じた週は動かない")
        snap.weekClosed = nil   // 旧セーブ（キーなし）
        XCTAssertEqual(WeekRunner(restoring: snap, config: config).snapshot().weekClosed, false)
    }

    func testWrongPhaseCallsAreNoOp() throws {
        let config = GameConfig()
        var r = WeekRunner(state: GameState(config: config), year: 1, config: config, rng: SplitMix64(seed: 20_261_025))
        var phase = r.begin()
        var sawTournament = false, sawFree = false
        for _ in 0..<200 where !(sawTournament && sawFree) {
            let before = try enc.encode(r.snapshot())
            switch phase {
            case .tournamentDecision:
                XCTAssertTrue(r.resolveAction(.job(.キツい)).isTournamentDecision, "大会の決断中の行動は無視")
                XCTAssertFalse(r.resolveAuto().isAuto)
                XCTAssertEqual(try enc.encode(r.snapshot()), before)
                sawTournament = true
                phase = r.resolveTournament(travel: nil)
            case .freeAction:
                XCTAssertTrue(r.resolveTournament(travel: .夜行バス).isFreeAction, "自由週の大会回答は無視")
                XCTAssertTrue(r.resolveAuto().isFreeAction)
                XCTAssertEqual(try enc.encode(r.snapshot()), before)
                sawFree = true
                phase = r.resolveAction(.rest(.完全休養))
            case .weekDone: phase = r.begin()
            case .yearDone: phase = r.begin()
            default: phase = r.resolveAuto()
            }
        }
        XCTAssertTrue(sawTournament && sawFree, "大会週と自由週の両方を通る")
    }

    func testOldSaveJSONWithoutWeekClosedKeyDecodes() throws {
        let config = GameConfig()
        let (r, _) = try runnerAtWeekDone(config: config)
        var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: enc.encode(r.snapshot())) as? [String: Any])
        XCTAssertNotNil(obj.removeValue(forKey: "weekClosed"), "今のセーブにはキーがある")
        let old = try JSONSerialization.data(withJSONObject: obj)
        let snap = try JSONDecoder().decode(WeekRunnerSnapshot<SplitMix64>.self, from: old)
        XCTAssertNil(snap.weekClosed)
        var restored = WeekRunner(restoring: snap, config: config)
        XCTAssertEqual(restored.snapshot().weekClosed, false, "旧セーブは閉じていない扱い")
        if case .weekDone = restored.begin() { XCTFail("begin() は次の週を始める") }
    }

    /// code_review_2026-10-25d §2：保存した GP の段が、更新後の回戦数より大きくても落ちない
    func testRestoreClampsGPStageToFewerRounds() throws {
        let config = GameConfig()
        let (r, _) = try runnerAtWeekDone(config: config)
        var snap = r.snapshot()
        snap.gpStage = config.calendar.gpRounds.count + 3
        let restored = WeekRunner(restoring: snap, config: config)
        XCTAssertEqual(restored.snapshot().gpStage, config.calendar.gpRounds.count)
        snap.pendingAuto = .round   // 回戦の演出待ちで保存されていても
        snap.weekClosed = false     // 週の途中の保存として扱う（閉じた週の守りで素通りさせない）
        var r2 = WeekRunner(restoring: snap, config: config)
        XCTAssertNil(r2.snapshot().pendingAuto)
        _ = r2.resolveAuto()          // 落ちない
    }
}
