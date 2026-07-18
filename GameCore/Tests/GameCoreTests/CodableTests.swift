// CodableTests.swift
// 中断セーブの土台（docs/ui_design_v0.md §5「週末ごとに GameState+進行状態を Codable でローカル保存」）の検証。
// GameState と SplitMix64 が JSON ラウンドトリップで一切ずれないこと＝セーブ→再開で状態と乱数列が保たれることを保証する。

import XCTest
@testable import GameCore

final class CodableTests: XCTestCase {

    /// GameState を符号化→復号→再符号化して、バイト列が一致する（全フィールドが往復で保存される）
    func testGameStateJSONRoundTrip() throws {
        var s = GameState(config: GameConfig())
        s.money = 148000
        s.stamina = 42.5
        s.fame = 13
        s.センス = 14.530052083333333
        s.発想 = 15.43125
        s.recoveryWeeks = 2
        s.growthBudget = 6.0
        s.growthUsed = 1.25
        s.bankrupt = false

        // 持ちネタ（Phase 0・neta_system_redesign_v2.md §6-1補）: 追加フィールドが往復で保存され、
        // lengthFit（正準ソート配列）・record・selectedNetaID までバイト等価で復元されることを担保。
        var neta = Neta(id: 0, name: "商店街の福引", kata: .伏線回収,
                        lengthFit: [.長尺, .中尺], bornYear: 2)   // init が正準順に並べ替える
        neta.polish = 62.5
        neta.buzz = 40.0
        neta.stageCount = 7
        neta.isDown = true
        neta.exposure = 15.0
        neta.record = [NetaStamp(year: 2, stage: "GP3回戦", passed: true)]
        neta.lastUsedTaikaiYear = 2
        s.netas = [neta]
        s.archivedNetas = [Neta(id: 1, name: "終電の二人", kata: .関係性, lengthFit: [.短尺], bornYear: 1)]
        s.nextNetaID = 2
        s.selectedNetaID = 0

        let enc = JSONEncoder()
        enc.outputFormatting = .sortedKeys
        let data = try enc.encode(s)
        let restored = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(try enc.encode(restored), data, "GameState のラウンドトリップで内容がずれた")
    }

    /// SplitMix64 を途中まで消費してから保存→復元し、続きの乱数列が元と完全一致する
    func testSplitMix64ResumesSameStream() throws {
        var rng = SplitMix64(seed: 424242)
        for _ in 0..<5 { _ = rng.nextUInt64() }   // 週の途中まで進めた状態を模擬

        let data = try JSONEncoder().encode(rng)
        var restored = try JSONDecoder().decode(SplitMix64.self, from: data)

        for i in 0..<16 {
            XCTAssertEqual(rng.nextUInt64(), restored.nextUInt64(), "復元後 \(i) 手目で乱数列がずれた")
        }
    }
}
