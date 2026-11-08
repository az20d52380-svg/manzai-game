// SaveFixtureTests.swift
// 古い中断セーブが読めなくなる変更を赤で止める（code_review_2026-10-25e §3-1・§3-4）。
// 2026-10-25 時点の WeekRunnerSnapshot を固定 JSON（Tests/Fixtures/runner_snapshot_1025.json）にして、今のコードで復号できるかを見る。
//  - 保存に載る enum（Skill／NetaKata／NetaLength など）の case を消す・名前を変える → 復号に失敗して赤
//  - 保存される型に非 Optional のキーを足す → 旧 JSON にキーが無く keyNotFound で赤（足すなら Optional にする）
// 固定 JSON の作り直しは `MZ_WRITE_FIXTURE=1 swift test --filter SaveFixtureTests` だけ（形を変えたい時はセーブの移行を先に考える）。

import Foundation
import XCTest
@testable import GameCore

final class SaveFixtureTests: XCTestCase {

    private var fixtureURL: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Fixtures/runner_snapshot_1025.json")
    }

    /// 保存に載る enum の全 case を含む、週の途中（自由週）の状態
    private func makeSnapshot() -> WeekRunnerSnapshot<SplitMix64> {
        let config = GameConfig()
        var s = GameState(config: config)
        s.skills = Skill.allCases
        var r = WeekRunner(state: s, year: 1, config: config, rng: SplitMix64(seed: 20_261_025), inviteSeed: 424243)
        for kata in NetaKata.allCases { _ = r.applyNetaCreate(kata: kata, lengthFit: NetaLength.allCases, name: "\(kata)") }
        var phase = r.begin()
        for _ in 0..<400 {
            if case .freeAction = phase, r.week >= 10 { break }
            switch phase {
            case .tournamentDecision: phase = r.resolveTournament(travel: nil)
            case .freeAction: phase = r.resolveAction(.rest(.完全休養))
            case .weekDone, .yearDone: phase = r.begin()
            default: phase = r.resolveAuto()
            }
        }
        return r.snapshot()
    }

    func testFixtureSaveStillDecodes() throws {
        if ProcessInfo.processInfo.environment["MZ_WRITE_FIXTURE"] != nil {
            let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys, .prettyPrinted]
            try FileManager.default.createDirectory(at: fixtureURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try enc.encode(makeSnapshot()).write(to: fixtureURL)
            throw XCTSkip("固定 JSON を書き出した: \(fixtureURL.path)")
        }
        let data = try Data(contentsOf: fixtureURL)
        let snap = try JSONDecoder().decode(WeekRunnerSnapshot<SplitMix64>.self, from: data)
        XCTAssertEqual(Set(snap.state.skills ?? []), Set(Skill.allCases), "特技の全 case が残っている")
        // 特技は知らない値を捨てて読む（save_compat_audit_1108）ので、case を消したら数の一致で赤にする
        let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let rawSkills = try XCTUnwrap((raw?["state"] as? [String: Any])?["skills"] as? [String])
        XCTAssertEqual(snap.state.skills?.count, rawSkills.count, "固定 JSON の特技が全部今も在る")
        XCTAssertEqual(Set(snap.state.netas.map(\.kata)), Set(NetaKata.allCases), "ネタの型の全 case が残っている")
        // 復元して週を進めても落ちない
        var r = WeekRunner(restoring: snap, config: GameConfig())
        _ = r.resolveAction(.rest(.完全休養))
        _ = r.begin()
    }

    /// 知らない特技（消した case）が混じった旧セーブでも全体は読める＝その要素だけ捨てる（save_compat_audit_1108_v0）
    func testUnknownSkillIsDroppedNotFatal() throws {
        var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: fixtureURL)) as? [String: Any])
        var state = try XCTUnwrap(obj["state"] as? [String: Any])
        let skills = try XCTUnwrap(state["skills"] as? [String])
        state["skills"] = skills + ["removedSkillForTest"]
        obj["state"] = state
        let snap = try JSONDecoder().decode(WeekRunnerSnapshot<SplitMix64>.self, from: JSONSerialization.data(withJSONObject: obj))
        XCTAssertEqual(snap.state.skills?.count, skills.count)
    }
}
