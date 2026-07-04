// GameSession.swift
// ui_design_v0.md §5 の ViewModel。WeekRunner（GameCore）を保持し、Phase に応じて人の入力を待つ。
// ロジックは一切持たず、WeekRunner を駆動して結果を @Observable な表示用プロパティに写すだけ。
// MVP は1年完結（S6 リザルト→タイトル）。多年キャリアは本編で（ui_design §1）。

import Foundation
import Observation
import GameCore

@Observable
final class GameSession {

    // MARK: 表示用（View が読むのはここだけ。すべて runner から写した値）
    private(set) var week: Int = 0
    private(set) var state: GameState
    private(set) var phase: WeekRunner<SplitMix64>.Phase
    private(set) var log: [String] = []
    private(set) var finished = false
    private(set) var outcome: YearOutcome?
    /// 大会・GPの結果が出た週。ここに値がある間は S3 結果画面を挟む（テンポの緩急・§3）
    private(set) var pendingResult: WeekSummary?

    let config: GameConfig
    let year = 1                       // MVPは1年目のみ

    // MARK: 進行の実体（WeekRunner が週処理と乱数消費の正典を持つ）
    private var runner: WeekRunner<SplitMix64>

    init(seed: UInt64 = 424242, config: GameConfig = GameConfig()) {
        self.config = config
        let start = GameState(config: config)
        self.state = start
        var r = WeekRunner(state: start, year: 1, config: config, rng: SplitMix64(seed: seed))
        let firstPhase = r.begin()   // r を消費してから確定させる（値型なので順序が重要）
        self.runner = r
        self.phase = firstPhase
        pump()
    }

    // MARK: UI からの入力（Phase 別）

    /// 大会週の回答（travel=nil は見送り）
    func decideTournament(_ travel: Travel?) {
        phase = runner.resolveTournament(travel: travel)
        pump()
    }

    /// 自由行動週の回答
    func choose(_ action: WeekAction) {
        phase = runner.resolveAction(action)
        pump()
    }

    /// GP回戦・敗者復活・決勝の演出後（入力不要）
    func advanceAuto() {
        phase = runner.resolveAuto()
        pump()
    }

    /// S3結果画面の「次へ」。結果を閉じて次週へ進める
    func acknowledgeResult() {
        pendingResult = nil
        phase = runner.begin()
        pump()
    }

    // MARK: 内部

    /// 自由週の weekDone は自動で次週へ送り（3秒動線・§2）、大会・GPの結果が出た週は止めて
    /// S3結果画面を挟む。入力/演出待ち・年終わりでも止める。
    private func pump() {
        loop: while true {
            switch phase {
            case .weekDone(let summary):
                state = summary.state
                week = summary.week
                if !summary.results.isEmpty {
                    log.append(summarize(summary))
                }
                let big = summary.results.filter(\.isStage)
                if !big.isEmpty {
                    // 大会・GPの結果 → S3結果画面へ（自動送りしない）
                    pendingResult = WeekSummary(year: summary.year, week: summary.week,
                                                results: big, state: summary.state)
                    break loop
                }
                phase = runner.begin()
            case .yearDone(let outcome):
                state = runner.state
                self.outcome = outcome
                finished = true
                break loop
            default:
                // tournamentDecision / freeAction / gpRound / gpRevival / gpFinal → 入力or演出待ち
                week = runner.week
                state = runner.state
                break loop
            }
        }
    }

    #if DEBUG
    /// QA用: 既定行動で自動プレイし、最初の大会/GP結果（S3）が出た時点で止める。
    /// 画面レイアウトの目視確認を素早く行うための開発フック（リリースには含まれない）。
    func debugAdvanceToFirstResult(maxSteps: Int = 240) {
        var steps = 0
        while pendingResult == nil, !finished, steps < maxSteps {
            steps += 1
            switch phase {
            case .tournamentDecision: decideTournament(.夜行バス)
            case .freeAction:         choose(.job(.標準))
            case .gpRound, .gpRevival, .gpFinal: advanceAuto()
            default: return
            }
        }
    }
    #endif

    private func summarize(_ s: WeekSummary) -> String {
        let parts = s.results.map { r -> String in
            let mark = r.passed ? "通過" : "敗退"
            let prize = r.prize > 0 ? " +\(r.prize / 10000)万" : ""
            return "\(r.name) \(mark)\(prize)"
        }
        return "第\(s.week)週: " + parts.joined(separator: " / ")
    }
}
