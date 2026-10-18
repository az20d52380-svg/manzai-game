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

    // MARK: 中断セーブ（proposals/0039・WeekRunnerSnapshot）

    /// 台本で1歩進める（自由週=バイト標準／大会=夜行バス／GP系=自動消化／weekDone=次週へ）
    private func step(_ runner: inout WeekRunner<SplitMix64>, _ phase: WeekRunner<SplitMix64>.Phase)
        -> WeekRunner<SplitMix64>.Phase {
        switch phase {
        case .freeAction: return runner.resolveAction(.job(.標準))
        case .tournamentDecision: return runner.resolveTournament(travel: .夜行バス)
        case .gpRound, .gpRevival, .gpFinal: return runner.resolveAuto()
        case .weekDone: return runner.begin()
        case .yearDone: return phase
        }
    }

    /// 数週進めた WeekRunner を snapshot→JSON往復→復元し、残りの年を同じ台本で完走したとき
    /// 「週ごとの位相と最終状態」が元の runner とビット一致することを確認する（=中断復帰で3年goldenの
    /// 消費順が1ビットもずれないことの実証）。
    func testWeekRunnerSnapshotResumesBitIdentical() throws {
        let config = GameConfig()
        let enc = JSONEncoder()
        enc.outputFormatting = .sortedKeys

        var original = WeekRunner(state: GameState(config: config), year: 1, config: config,
                                  rng: SplitMix64(seed: 20_260_724))
        var phase = original.begin()
        for _ in 0..<40 { phase = step(&original, phase) }   // 週の途中の中断を模擬（大会週を跨ぐ歩数）

        // snapshot → JSON 往復 → 復元（config は外から再注入・0039）
        let snap = original.snapshot()
        let data = try enc.encode(snap)
        let decoded = try JSONDecoder().decode(WeekRunnerSnapshot<SplitMix64>.self, from: data)
        var restored = WeekRunner(restoring: decoded, config: config)

        // 復元直後のスナップショット自体もバイト等価（全フィールドが往復で保存される）
        XCTAssertEqual(try enc.encode(restored.snapshot()), data, "復元直後のスナップショットがずれた")

        // 残りの年を同じ台本で完走し、位相と状態が毎歩ビット一致する
        var phaseR = phase
        for i in 0..<400 {
            phase = step(&original, phase)
            phaseR = step(&restored, phaseR)
            XCTAssertEqual(try enc.encode(phase), try enc.encode(phaseR), "復元後 \(i) 歩目で位相がずれた")
            XCTAssertEqual(try enc.encode(original.state), try enc.encode(restored.state),
                           "復元後 \(i) 歩目で state がずれた")
            if case .yearDone = phase { break }
        }
    }

    /// 旧セーブ互換：margin・burst の無い StageResult も復号でき、両方 nil になる（表示専用の任意項目）
    func testStageResultDecodesOldSaveWithoutBurst() throws {
        let old = #"{"name":"GP1回戦","passed":true,"prize":0,"isStage":true}"#.data(using: .utf8)!
        let r = try JSONDecoder().decode(StageResult.self, from: old)
        XCTAssertEqual(r.name, "GP1回戦")
        XCTAssertNil(r.margin)
        XCTAssertNil(r.burst)
        let now = StageResult(name: "敗者復活", passed: false, prize: 0, margin: -3, burst: true)
        let back = try JSONDecoder().decode(StageResult.self, from: JSONEncoder().encode(now))
        XCTAssertEqual(back.burst, true)
        XCTAssertEqual(back.margin, -3)
    }
}

extension CodableTests {
    /// A-4: 保留中のオファーは復元時に今の config から取り直す（バランス更新が古いセーブに固まらない）。名前が無ければ保存時のまま
    func testRestoreRefreshesPendingOfferFromConfig() throws {
        let config = GameConfig()
        var r = WeekRunner(state: GameState(config: config), year: 1, config: config, rng: SplitMix64(seed: 20_260_724))
        var phase = r.begin()
        var held: OfferSpec?
        for _ in 0..<400 {
            if case .freeAction(let o?) = phase { held = o; break }
            phase = step(&r, phase)
        }
        let o = try XCTUnwrap(held, "1年のうちにオファーが1回は来る")
        let snap = r.snapshot()

        var bumped = GameConfig()
        bumped.offersNamed = bumped.offersNamed.map { OfferSpec(name: $0.name, income: $0.income + 1, fame: $0.fame, ability: $0.ability, stamina: $0.stamina) }
        bumped.offerMoney = OfferSpec(name: bumped.offerMoney.name, income: bumped.offerMoney.income + 1, fame: bumped.offerMoney.fame, ability: bumped.offerMoney.ability, stamina: bumped.offerMoney.stamina)
        bumped.offerExp = OfferSpec(name: bumped.offerExp.name, income: bumped.offerExp.income + 1, fame: bumped.offerExp.fame, ability: bumped.offerExp.ability, stamina: bumped.offerExp.stamina)
        let restored = WeekRunner(restoring: snap, config: bumped)
        XCTAssertEqual(restored.snapshot().pendingOffer?.name, o.name)
        XCTAssertEqual(restored.snapshot().pendingOffer?.income, o.income + 1, "今の config の値に取り直す")
    }
}

