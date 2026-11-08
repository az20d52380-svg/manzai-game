// GPRewardTests.swift
// GP の回戦通過・決勝進出・優勝で入るお金と知名度を WeekRunner の通しで固定する（今の振る舞いを固定するだけ・Sources／式／golden は不変）。
// gpPrize・champFame・fameFinalist・gpRoundFame・entryFee は check_config_sync で定数の一致だけ見ていて、加わる場所の直接のテストが無かった。

import XCTest
@testable import GameCore

final class GPRewardTests: XCTestCase {
    /// 回戦・決勝のラインをどんな出来でも通る値まで下げた設定（式そのものは触らない）
    private func easyConfig() -> GameConfig {
        var c = GameConfig()
        c.calendar.gpRounds = c.calendar.gpRounds.map { (week: $0.week, line: -10_000) }
        c.calendar.gpFinalLine = -10_000
        return c
    }

    func testGPRoundsFinalistAndChampionRewards() {
        let config = easyConfig()
        let cal = config.calendar
        var s = GameState(config: config)
        s.money = 5_000_000
        s.fame = 10
        var r = WeekRunner(state: s, year: 1, config: config, rng: SplitMix64(seed: 11))
        var phase = r.begin()
        var roundsSeen = 0
        var sawFinal = false
        var guardCount = 0
        loop: while guardCount < 10_000 {
            guardCount += 1
            switch phase {
            case .tournamentDecision: phase = r.resolveTournament(travel: nil)
            case .freeAction: phase = r.resolveAction(.rest(.完全休養))
            case .gpRound(let index, _):
                let before = r.state
                phase = r.resolveAuto()
                // 回戦は必ず通る：知名度 +gpRoundFame（最後の回戦はさらに決勝進出の逓減つき +fameFinalist）
                var expect = before
                GameEngine.add(.知名度, cal.gpRoundFame, to: &expect, config: config)
                if index == cal.gpRounds.count - 1 {
                    GameEngine.addFameBig(cal.fameFinalist, to: &expect)
                }
                XCTAssertEqual(r.state.fame, expect.fame, accuracy: 1e-9, "回戦\(index + 1) の知名度")
                // お金：エントリー費はその年最初の回戦で1回だけ
                XCTAssertEqual(r.state.money, before.money - (roundsSeen == 0 ? cal.entryFee : 0), "回戦\(index + 1) のお金")
                roundsSeen += 1
            case .gpRevival:
                XCTFail("全回戦を通る設定で敗者復活に来た"); break loop
            case .gpFinal:
                let before = r.state
                phase = r.resolveAuto()
                sawFinal = true
                guard case .yearDone(let outcome) = phase else { XCTFail("優勝は即時に年が終わる"); break loop }
                XCTAssertTrue(outcome.champion)
                XCTAssertTrue(outcome.reachedFinal)
                XCTAssertEqual(outcome.roundsPassed, cal.gpRounds.count)
                // 賞金 gpPrize がそのまま入る（週末の生活費は走らない＝runYear と同じ）
                XCTAssertEqual(r.state.money, before.money + cal.gpPrize)
                // 優勝の知名度は逓減なしで +champFame
                XCTAssertEqual(r.state.fame, min(100, before.fame + cal.champFame), accuracy: 1e-9)
                break loop
            case .weekDone: phase = r.begin()
            case .yearDone: XCTFail("決勝の前に年が終わった"); break loop
            }
        }
        XCTAssertEqual(roundsSeen, cal.gpRounds.count, "回戦は全部で gpRounds の数だけ")
        XCTAssertTrue(sawFinal)
    }

    /// 大会の経験点 1通貨ぶん（5通貨に均等）＝基本点 × K × 重み × unit × split × 供給スケール
    private func expPerCurrency(_ pw: Double, weight: Double, _ c: GameConfig) -> Double {
        pw * c.tourneyExpK * weight * c.tourneyExpUnit * c.tourneyExpSplit * c.expSupplyScale
    }

    /// 準決勝だけ落ちる設定で、回戦・敗者復活・決勝に積まれる経験点（閃き）を段ごとに確かめる
    private func runRevivalPath(finalPasses: Bool) -> [(stage: String, gain: Double, expect: Double)] {
        var c = GameConfig()
        c.autoPourAllocation = false   // 実ゲームと同じ＝粒を貯める（true だと行動直後に能力へ全量注いで残高が0に戻る）
        let n = c.calendar.gpRounds.count
        c.calendar.gpRounds = c.calendar.gpRounds.enumerated().map { (i, r) in (week: r.week, line: i == n - 1 ? 10_000 : -10_000) }
        c.calendar.gpRevivalLine = -10_000
        c.calendar.gpFinalLine = finalPasses ? -10_000 : 10_000
        var s = GameState(config: c)
        s.money = 5_000_000
        var r = WeekRunner(state: s, year: 1, config: c, rng: SplitMix64(seed: 5))
        var out: [(String, Double, Double)] = []
        var phase = r.begin()
        var steps = 0
        while steps < 10_000 {
            steps += 1
            switch phase {
            case .tournamentDecision: phase = r.resolveTournament(travel: nil)
            case .freeAction: phase = r.resolveAction(.rest(.完全休養))
            case .gpRound(let i, _):
                let before = r.state[currency: .閃き]
                phase = r.resolveAuto()
                let passed = i < n - 1
                let pw = (1 + c.tourneyExpRoundStep * Double(i)) * (passed ? 1.0 : c.tourneyExpLoss)
                out.append(("回戦\(i + 1)", r.state[currency: .閃き] - before, expPerCurrency(pw, weight: c.tourneyExpWeightRound, c)))
            case .gpRevival:
                let before = r.state[currency: .閃き]
                phase = r.resolveAuto()
                out.append(("敗者復活", r.state[currency: .閃き] - before, expPerCurrency(c.tourneyExpRevival, weight: c.tourneyExpWeightFinal, c)))
            case .gpFinal:
                let before = r.state[currency: .閃き]
                phase = r.resolveAuto()
                let pw = c.tourneyExpFinal * (finalPasses ? 1.0 : c.tourneyExpLoss)
                out.append(("決勝", r.state[currency: .閃き] - before, expPerCurrency(pw, weight: c.tourneyExpWeightFinal, c)))
            case .weekDone: phase = r.begin()
            case .yearDone: return out
            }
        }
        XCTFail("1年が終わらない")
        return out
    }

    func testTourneyExpPerStageThroughRevivalToFinal() {
        for finalPasses in [true, false] {
            let t = runRevivalPath(finalPasses: finalPasses)
            XCTAssertEqual(t.map(\.stage), (1...GameConfig().calendar.gpRounds.count).map { "回戦\($0)" } + ["敗者復活", "決勝"])
            for row in t {
                XCTAssertGreaterThan(row.expect, 0)
                XCTAssertEqual(row.gain, row.expect, accuracy: 1e-9, "\(row.stage)（決勝\(finalPasses ? "優勝" : "敗退")）")
            }
        }
    }

    func testChampionFameIsNotDiminishedAndClampsAt100() {
        // addFameRaw（優勝）は逓減なし・addFameBig（決勝進出）は (1−知名度/100) で縮む
        var a = GameState(config: GameConfig()); a.fame = 95
        GameEngine.addFameRaw(GameConfig().calendar.champFame, to: &a)
        XCTAssertEqual(a.fame, 100, accuracy: 1e-12)
        var b = GameState(config: GameConfig()); b.fame = 50
        GameEngine.addFameBig(GameConfig().calendar.fameFinalist, to: &b)
        XCTAssertEqual(b.fame, 50 + GameConfig().calendar.fameFinalist * 0.5, accuracy: 1e-12)
        var c = GameState(config: GameConfig()); c.fame = 50
        GameEngine.addFameBig(-5, to: &c)   // 負の量は何もしない
        XCTAssertEqual(c.fame, 50, accuracy: 1e-12)
    }
}
