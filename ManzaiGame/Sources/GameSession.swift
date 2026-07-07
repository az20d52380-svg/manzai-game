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
    /// 直前に選んだ行動（心の声の反応・変種IDを出すため。週頭は nil）
    private(set) var lastAction: WeekAction?
    /// 直前の行動で伸びた能力（バー伸び演出＆「+N」用）
    private(set) var lastGains: [(ability: Ability, amount: Double)] = []
    /// 直前の行動で伸びた相性（v8ピルの「+N」用。相性は Ability enum 外なので別枠で保持）
    private(set) var lastCompatGain: Double = 0
    /// 連敗数（大会・GPで敗退が続いた回数。心の声「何が足りないんだ…」用）
    private(set) var lossStreak = 0
    /// 直近の大会で通過したか（先週の結果を心の声に反映。行動すると失効）
    private(set) var justPassedStage = false
    /// 優勝が確定した瞬間。ここが true の間は「勝ち版」決勝演出を出す（S4ボードの前）
    private(set) var winFinale = false
    /// S6 行動内訳帯用: 週インデックス→その週のカテゴリ（UI層の記録のみ・golden非対象）
    private(set) var categoryLog: [Int: BandCategory] = [:]
    /// S6 年計用: その年の獲得賞金合計（UI層の記録のみ・golden非対象）
    private(set) var totalPrize = 0

    let config: GameConfig
    let year = 1                       // MVPは1年目のみ
    let combiName: String              // S1で入力（表示専用・golden非対象）

    // MARK: 進行の実体（WeekRunner が週処理と乱数消費の正典を持つ）
    private var runner: WeekRunner<SplitMix64>

    init(seed: UInt64 = 424242, config: GameConfig = GameConfig(), startState: GameState? = nil,
         combiName: String = "あなたのコンビ") {
        self.config = config
        self.combiName = combiName
        let start = startState ?? GameState(config: config)
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
        let before = state
        lastAction = action
        categoryLog[week] = BandCategory(action)   // S6 行動内訳帯（この自由週のカテゴリ）
        justPassedStage = false   // 行動したら「先週通過」の余韻は失効
        phase = runner.resolveAction(action)
        pump()
        lastGains = Ability.allCases.compactMap { a in
            let d = state[a] - before[a]
            return d > 0.001 ? (a, d) : nil
        }
        lastCompatGain = state.compat - before.compat
    }

    // MARK: v8育成メイン用プレビュー（RNG非消費の純getter）
    //
    // ⚠️ この関数群は RandomSource を一切触らない = 乱数を消費しない = golden不変。
    //    self.state の「コピー」に GameEngine.apply* を適用して差分を取るだけ。
    //    runner.resolveAction は絶対に呼ばないこと（injury抽選・rollOffer で乱数を消費し、
    //    以降の3年ビット一致 golden が壊れるため）。
    //    なお resolveAction 側の staminaGate 強制remap / 体調ダウン抽選 は反映しない＝
    //    プレビューは「名目値」。体力ゲートは View 側で state.stamina<staminaGate をグレー表示して実害を消す。

    /// action を今の state に適用した「実行後の状態」を返す（乱数非消費・純関数）。
    /// offer プレビューは runner が pendingOffer を内部に隠すため、View から OfferSpec を渡す。
    func previewState(_ action: WeekAction, offer: OfferSpec? = nil) -> GameState {
        var s = state
        switch action {
        case .train(let t):
            if !GameEngine.applyTraining(t, to: &s, config: config) {
                GameEngine.applyRest(.完全休養, to: &s, config: config)   // 払えなければ休む（resolveActionと同じフォールバック）
            }
        case .job(let j):
            GameEngine.applyJob(j, to: &s, config: config)
        case .rest(let r):
            GameEngine.applyRest(r, to: &s, config: config)
        case .acceptOffer:
            if let o = offer {
                GameEngine.applyOffer(o, to: &s, config: config)
            }
        }
        return s
    }

    /// action で伸びる能力の差分（名目値・乱数非消費）。カードの「+N」プレビュー用。
    /// 相性/体力/所持金/知名度は Ability 外なので previewState の after を直接読むこと。
    func previewGains(_ action: WeekAction, offer: OfferSpec? = nil) -> [(ability: Ability, amount: Double)] {
        let after = previewState(action, offer: offer)
        return Ability.allCases.compactMap { a in
            let d = after[a] - state[a]
            return d > 0.001 ? (a, d) : nil
        }
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

    /// 「勝ち版」決勝演出の「次へ」。年末結果（S4）へ
    func acknowledgeWin() {
        winFinale = false
        finished = true
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
                    // 連敗カウント＆直近通過（心の声用）: 通過でリセット・敗退で加算
                    for r in big {
                        if r.passed { lossStreak = 0; justPassedStage = true }
                        else { lossStreak += 1; justPassedStage = false }
                        totalPrize += r.prize   // S6 賞金年計
                    }
                    categoryLog[summary.week] = .taikai   // S6 行動内訳帯（大会週）
                    // 大会・GPの結果 → S3結果画面へ（自動送りしない）
                    pendingResult = WeekSummary(year: summary.year, week: summary.week,
                                                results: big, state: summary.state)
                    break loop
                }
                phase = runner.begin()
            case .yearDone(let outcome):
                state = runner.state
                self.outcome = outcome
                if outcome.champion {
                    winFinale = true   // 優勝＝「勝ち版」演出を挟んでから S4 へ
                } else {
                    finished = true
                }
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
    /// stopAtEntry=true なら最初の大会入口（tournamentDecision）で止める（入口画面の目視用）。
    /// 画面レイアウトの目視確認を素早く行うための開発フック（リリースには含まれない）。
    func debugAdvanceToFirstResult(maxSteps: Int = 240, stopAtEntry: Bool = false) {
        var steps = 0
        while pendingResult == nil, !finished, steps < maxSteps {
            steps += 1
            switch phase {
            case .tournamentDecision:
                if stopAtEntry { return }
                decideTournament(.夜行バス)
            case .freeAction:         choose(.job(.標準))
            case .gpRound, .gpRevival, .gpFinal: advanceAuto()
            default: return
            }
        }
    }

    /// DEBUG: 能力を上限近くまで盛った開始状態（数式・乱数は不変・GameStateの初期値だけ変更）。
    /// これで決勝ラインを突破でき、優勝演出を実機で確認できる。
    static func debugMaxedState(config: GameConfig = GameConfig()) -> GameState {
        var s = GameState(config: config)
        s.センス = 115; s.発想 = 115; s.表現 = 115; s.華 = 115; s.メンタル = 115
        s.compat = 19
        return s
    }

    /// DEBUG: 決勝優勝が確定する（winFinale）まで自動プレイ。自由週はバイトで破産回避。
    func debugAdvanceToChampionFinale(maxSteps: Int = 500) {
        var steps = 0
        while !winFinale, !finished, steps < maxSteps {
            steps += 1
            if pendingResult != nil { acknowledgeResult(); continue }
            switch phase {
            case .tournamentDecision: decideTournament(.夜行バス)
            case .freeAction:         choose(.job(.標準))   // 稼いで破産回避（能力は既にマックス）
            case .gpRound, .gpRevival, .gpFinal: advanceAuto()
            default: return
            }
        }
    }

    /// QA用: 年末（S4）まで一気に自動プレイ（結果は自動で送る）。
    func debugPlayToEnd(maxSteps: Int = 400) {
        var steps = 0
        while !finished, steps < maxSteps {
            steps += 1
            if pendingResult != nil { acknowledgeResult(); continue }
            switch phase {
            case .tournamentDecision: decideTournament(.夜行バス)
            case .freeAction:         choose(.rest(.完全休養))   // 体力を保って稽古も混ぜたいが最短確認用
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
