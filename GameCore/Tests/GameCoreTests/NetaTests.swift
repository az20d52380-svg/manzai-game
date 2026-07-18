// NetaTests.swift
// 持ちネタ Phase 0（正典: docs/neta_system_redesign_v2.md）のロジック検証。
// ★golden非干渉の証明は WeekRunnerGoldenTests/CareerGoldenTests（既存32件・不変）が担う。
//   本ファイルは applyNeta*（RNG非消費の純適用）と Neta 純関数（liveBuzz/isTeppan/isRevival）の挙動だけを検証する。

import XCTest
@testable import GameCore

final class NetaTests: XCTestCase {

    private func makeRunner(year: Int = 1, config: GameConfig = GameConfig()) -> WeekRunner<SplitMix64> {
        WeekRunner(state: GameState(config: config), year: year, config: config, rng: SplitMix64(seed: 1))
    }

    // MARK: 生成

    func testCreateAppendsAndNumbers() {
        var r = makeRunner(year: 2)
        let id0 = r.applyNetaCreate(kata: .伏線回収, lengthFit: [.中尺, .長尺], name: "A")
        let id1 = r.applyNetaCreate(kata: .関係性, lengthFit: [.短尺], name: "B")
        XCTAssertEqual(id0, 0)
        XCTAssertEqual(id1, 1)
        XCTAssertEqual(r.state.nextNetaID, 2)
        XCTAssertEqual(r.state.netas.count, 2)
        XCTAssertEqual(r.state.netas[0].polish, 30)      // 初期完成度
        XCTAssertEqual(r.state.netas[0].bornYear, 2)     // 作成年＝runner.year
        XCTAssertFalse(r.state.netas[0].isDown)          // 未おろし
    }

    func testLengthFitIsCanonicalSorted() {
        var r = makeRunner()
        let id = r.applyNetaCreate(kata: .王道しゃべくり, lengthFit: [.長尺, .短尺, .中尺, .短尺], name: "X")
        // NetaLength.allCases 順（短→中→長）に正規化＋重複除去＝Codable決定論
        XCTAssertEqual(r.state.netas.first(where: { $0.id == id })?.lengthFit, [.短尺, .中尺, .長尺])
    }

    // MARK: 改稿

    func testReviseRaisesPolishAndClamps() {
        var config = GameConfig(); config.netaReviseGain = 8
        var r = makeRunner(config: config)
        let id = r.applyNetaCreate(kata: .瞬発, lengthFit: [.短尺], name: "N")
        r.applyNetaRevise(id: id)
        XCTAssertEqual(r.state.netas[0].polish, 38)      // 30 + 8
        for _ in 0..<20 { r.applyNetaRevise(id: id) }
        XCTAssertEqual(r.state.netas[0].polish, 100)     // 100 で頭打ち
    }

    // MARK: ライブ（磨く・おろし・buzz）

    func testLiveRaisesPolishStageDownAndBuzz() {
        var config = GameConfig()
        config.netaLivePolishShow = 12; config.netaLivePolishFree = 6; config.netaBuzzAlpha = 0.4
        var r = makeRunner(config: config)
        let id = r.applyNetaCreate(kata: .華先行, lengthFit: [.短尺], name: "L")
        XCTAssertEqual(r.state.netas[0].buzz, 0)

        r.applyNetaLive(id: id, hard: true)              // ネタ見せ会
        XCTAssertEqual(r.state.netas[0].polish, 42)      // 30 + 12
        XCTAssertEqual(r.state.netas[0].stageCount, 1)
        XCTAssertTrue(r.state.netas[0].isDown)           // 初回＝おろし
        XCTAssertGreaterThan(r.state.netas[0].buzz, 0)   // 手応えが移動平均で入る

        let buzzAfter1 = r.state.netas[0].buzz
        r.applyNetaLive(id: id, hard: false)             // フリーライブ
        XCTAssertEqual(r.state.netas[0].polish, 48)      // 42 + 6
        XCTAssertEqual(r.state.netas[0].stageCount, 2)
        XCTAssertNotEqual(r.state.netas[0].buzz, buzzAfter1)  // buzz が更新される
    }

    // MARK: 二層（退避・呼び戻し）

    func testRetireAndRecallMoveBetweenLayers() {
        var r = makeRunner()
        let id = r.applyNetaCreate(kata: .リターン, lengthFit: [.長尺], name: "R")
        r.applyNetaSelect(id: id)
        r.applyNetaRetire(id: id)
        XCTAssertEqual(r.state.netas.count, 0)
        XCTAssertEqual(r.state.archivedNetas.count, 1)
        XCTAssertNil(r.state.selectedNetaID)             // 退避で選択解除
        r.applyNetaRecall(id: id)
        XCTAssertEqual(r.state.netas.count, 1)
        XCTAssertEqual(r.state.archivedNetas.count, 0)   // 呼び戻せる（消えない）
    }

    // MARK: 型の組み替え（アクティブ/保管庫どちらも）

    func testChangeKataOnActiveAndArchived() {
        var r = makeRunner()
        let id = r.applyNetaCreate(kata: .王道しゃべくり, lengthFit: [.中尺], name: "K")
        r.applyNetaChangeKata(id: id, to: .非定型)
        XCTAssertEqual(r.state.netas[0].kata, .非定型)
        r.applyNetaRetire(id: id)
        r.applyNetaChangeKata(id: id, to: .伏線回収)
        XCTAssertEqual(r.state.archivedNetas[0].kata, .伏線回収)
    }

    // MARK: 純関数（決定論・非スコア表示）

    func testLiveBuzzIsDeterministic() {
        let config = GameConfig()
        var s = GameState(config: config); s.センス = 40; s.発想 = 40; s.表現 = 40; s.華 = 40
        let neta = Neta(id: 0, name: "D", kata: .王道しゃべくり, lengthFit: [.中尺], bornYear: 1)
        let a = Neta.liveBuzz(state: s, neta: neta, config: config)
        let b = Neta.liveBuzz(state: s, neta: neta, config: config)
        XCTAssertEqual(a, b)                              // 乱数を引かない＝同入力同出力
        XCTAssertGreaterThanOrEqual(a, 0); XCTAssertLessThanOrEqual(a, 100)
    }

    func testTeppanAndRevivalThresholds() {
        var config = GameConfig()
        config.netaTeppanPolish = 80; config.netaTeppanStage = 8; config.netaTeppanBuzz = 60
        config.netaRevivalYears = 3
        var neta = Neta(id: 0, name: "T", kata: .王道しゃべくり, lengthFit: [.長尺], bornYear: 2)
        XCTAssertFalse(neta.isTeppan(config: config))
        neta.polish = 85; neta.stageCount = 10; neta.buzz = 65
        XCTAssertTrue(neta.isTeppan(config: config))     // 三条件を満たす
        XCTAssertFalse(neta.isRevival(currentYear: 4, config: config))  // 4-2=2 < 3
        XCTAssertTrue(neta.isRevival(currentYear: 5, config: config))   // 5-2=3 >= 3
    }
}
