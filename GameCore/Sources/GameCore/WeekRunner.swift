// WeekRunner.swift
// runYear（Career.swift）と同一セマンティクスの「ステップ実行機」。UIが週の途中で人の入力を待てる形にする。
// 正典性: runYear と完全に同じ順序で GameEngine を呼び、乱数消費順を一致させる（正典は tools/gen_golden.py の docstring）。
// 同値性は WeekRunnerGoldenTests（CareerGoldenTests と同じ3年期待値でのビット一致）で担保する。
// 【docs/ui_design_v0.md §5・2026-07-05 委譲済み】GameCareer.runYear はこの WeekRunner を policy で
// 駆動するだけの薄いラッパになった。週処理と乱数消費順の正典実体はこのファイルが唯一持つ。

/// 大会・回戦の結果1件（UIの結果トースト用）
public struct StageResult {
    public let name: String
    public let passed: Bool
    public let prize: Int      // 通過時のみ賞金額、敗退は0
    /// 大会・GP各回戦・敗者復活・決勝など「結果画面(S3)を出す本番」か。
    /// 体調ダウン/療養など週内の付随イベントは false（UIが名前で判別せず型で分岐できるように）。
    public let isStage: Bool

    public init(name: String, passed: Bool, prize: Int, isStage: Bool = true) {
        self.name = name
        self.passed = passed
        self.prize = prize
        self.isStage = isStage
    }
}

/// 週の結果（UIの差分ポップは前週スナップショットとの比較で出す）
public struct WeekSummary {
    public let year: Int
    public let week: Int
    public let results: [StageResult]   // この週に起きた大会・回戦の結果（0〜複数件）
    public let state: GameState         // 週末処理後のスナップショット

    public init(year: Int, week: Int, results: [StageResult], state: GameState) {
        self.year = year
        self.week = week
        self.results = results
        self.state = state
    }
}

/// 1年48週を「入力が要る所で止まりながら」進める実行機。
/// 使い方: begin() → Phaseに応じて resolveTournament / resolveAction / resolveAuto → weekDone → 再び begin()
public struct WeekRunner<R: RandomSource> {

    public enum Phase {
        case tournamentDecision(TournamentSpec)   // 大会週: 出るか・移動手段は? → resolveTournament(travel:)
        case freeAction(offer: OfferSpec?)        // 自由週: オファー抽選済み → resolveAction(_:)
        case gpRound(index: Int, name: String)    // GP回戦: 入力不要。演出後 resolveAuto()
        case gpRevival                            // 敗者復活: 入力不要。演出後 resolveAuto()
        case gpFinal                              // 決勝: 入力不要。演出後 resolveAuto()
        case weekDone(WeekSummary)                // 週の結果 → 次の begin() へ
        case yearDone(YearOutcome)                // 年の終わり（優勝時は即時・週末処理なし=runYearと同じ）
    }

    /// UIとテストが読み出す現在状態（年をまたぐときは state / rng を次の WeekRunner に渡す）
    public private(set) var state: GameState
    public private(set) var rng: R
    public private(set) var year: Int
    public private(set) var week = 0

    private let config: GameConfig
    private let finalLine: Double
    private var gpStage: Int
    private var gpEntryPaid = false   // エントリー費はその年最初に出る回戦で徴収
    private var gpAlive: Bool
    private var finalist: Bool
    private var revival = false

    // 週内の進行位置（runYear のブロック1〜5に対応）
    private enum Section { case tournament, gp, finalWeek, free, end }
    private var section = Section.tournament
    private var acted = false
    private var weekResults: [StageResult] = []
    private var pendingSpec: TournamentSpec?
    private var pendingOffer: OfferSpec?
    private enum AutoStage { case round, revival, final }
    private var pendingAuto: AutoStage?
    private var revivalTried = false
    private var finalTried = false
    private var finished: YearOutcome?

    public init(
        state: GameState,
        year: Int,
        config: GameConfig,
        rng: R,
        seedFinal: Bool = false,
        finalLineOverride: Double? = nil,
        gpSeeded: Bool = false   // 前年準々決勝以上（roundsPassed>=3）で1回戦免除
    ) {
        precondition(year >= 1, "year は1以上（成長予算の累計計算が前提）")
        var s = state
        s.stamina = config.initStamina   // 体力のみ年初に全回復（runYear冒頭と同一）
        var budget = 0.0                 // 成長予算の更新（キャリア累計・正典v2）
        for k in 1...min(year, config.growthEndYear) {
            budget += max(config.capCurveFloor, config.capCurveBase - config.capCurveSlope * Double(k - 1))
        }
        s.growthBudget = budget
        self.state = s
        self.year = year
        self.config = config
        self.rng = rng
        self.gpStage = gpSeeded ? 1 : 0   // シード組は2回戦から
        self.gpAlive = !seedFinal
        self.finalist = seedFinal
        self.finalLine = finalLineOverride ?? config.calendar.gpFinalLine
    }

    /// 次の週を開始する（初回も含む）。年が終わっていれば yearDone を返し続ける
    public mutating func begin() -> Phase {
        if let outcome = finished {
            return .yearDone(outcome)
        }
        week += 1
        if week > config.weeks {
            let outcome = YearOutcome(champion: false, roundsPassed: gpStage, reachedFinal: finalist)
            finished = outcome
            return .yearDone(outcome)
        }
        acted = false
        weekResults = []
        section = .tournament
        revivalTried = false
        finalTried = false
        pendingSpec = nil      // 呼び出し順ミスの残留状態を週頭で必ず掃除（レッドチーム指摘）
        pendingOffer = nil
        pendingAuto = nil
        return proceed()
    }

    /// 大会週の回答。travel=nil は不出場（乱数は消費されない）。大阪で交通費が払えない場合も不出場（runYearと同一）
    public mutating func resolveTournament(travel: Travel?) -> Phase {
        defer { pendingSpec = nil }
        if let spec = pendingSpec, let travel = travel {
            let ts = config.calendar.travelSpec(travel)
            let need = config.calendar.entryFee + (spec.osaka ? ts.cost : 0)
            if state.money >= need {
                state.money -= config.calendar.entryFee
                if spec.osaka {
                    state.money -= ts.cost
                    GameEngine.add(.体力, ts.stamina, to: &state, config: config)
                }
                let result = GameEngine.perform(state, line: spec.line, config: config, rng: &rng)
                if result.passed {
                    state.money += spec.prize
                    GameEngine.add(.知名度, spec.fame, to: &state, config: config)
                }
                acted = true
                weekResults.append(StageResult(name: spec.name, passed: result.passed,
                                               prize: result.passed ? spec.prize : 0))
            }
        }
        return proceed()
    }

    /// GP回戦・敗者復活・決勝の消化（UI演出のあとに呼ぶ）
    public mutating func resolveAuto() -> Phase {
        guard let auto = pendingAuto else { return proceed() }
        pendingAuto = nil
        let cal = config.calendar
        switch auto {
        case .round:
            if !gpEntryPaid {
                state.money -= cal.entryFee   // GPエントリー費（その年最初の回戦週に1回・runYearと同一順序）
                gpEntryPaid = true
            }
            let round = cal.gpRounds[gpStage]
            let name = gpStage < cal.gpRoundNames.count ? cal.gpRoundNames[gpStage] : "GP回戦\(gpStage + 1)"
            let result = GameEngine.perform(state, line: round.line, config: config, rng: &rng)
            acted = true
            if result.passed {
                GameEngine.add(.知名度, cal.gpRoundFame, to: &state, config: config)
                gpStage += 1
                if gpStage == cal.gpRounds.count {
                    finalist = true
                }
            } else {
                if gpStage == cal.gpRounds.count - 1 {
                    revival = true   // 準決勝敗退のみ敗者復活へ
                }
                gpAlive = false
            }
            weekResults.append(StageResult(name: name, passed: result.passed, prize: 0))
        case .revival:
            revivalTried = true
            let result = GameEngine.perform(state, line: cal.gpRevivalLine, config: config, rng: &rng)
            acted = true
            if result.passed {
                GameEngine.add(.知名度, cal.gpRoundFame, to: &state, config: config)
                finalist = true
            }
            weekResults.append(StageResult(name: "敗者復活", passed: result.passed, prize: 0))
        case .final:
            finalTried = true
            // 決勝のみの人気補正（機微・judge_design §10-F）。王者防衛のライン上書き時にも適用
            let effLine = finalLine - cal.fameFinalBonus * (state.fame - 50) / 50
            let result = GameEngine.perform(state, line: effLine, config: config, rng: &rng)
            acted = true
            weekResults.append(StageResult(name: "GP決勝", passed: result.passed,
                                           prize: result.passed ? cal.gpPrize : 0))
            if result.passed {
                state.money += cal.gpPrize
                GameEngine.add(.知名度, cal.champFame, to: &state, config: config)
                // runYear と同一: 優勝は即時リターン＝この週の週末処理（生活費）は走らない
                let outcome = YearOutcome(champion: true, roundsPassed: gpStage, reachedFinal: true)
                finished = outcome
                return .yearDone(outcome)
            }
        }
        return proceed()
    }

    /// 自由行動週の回答（.acceptOffer はオファーがある週のみ有効。無ければ完全休養にフォールバック=runYearと同一）。
    /// 体力ゲート（稽古不可）と体調ダウン判定はここで強制する（UI側のグレーアウトはこの規則の表示）
    public mutating func resolveAction(_ action: WeekAction) -> Phase {
        let offer = pendingOffer
        pendingOffer = nil
        var action = action
        if case .train = action, state.stamina < config.staminaGate {
            action = .rest(.完全休養)                    // 体力ゲート（谷口が止める）
        }
        let risky: Bool
        switch action {
        case .train: risky = true
        case .job(let j): risky = (j == .キツい)
        default: risky = false
        }
        if risky, state.stamina < config.injuryThreshold,
           rng.nextUniform() < (config.injuryThreshold - state.stamina) * config.injuryProbPerPoint {
            action = .rest(.完全休養)                    // 体調ダウン発生（「喉をやられた」等）
            state.recoveryWeeks = config.injuryRestWeeks - 1
            GameEngine.add(.ability(.メンタル), config.injuryMentalHit, to: &state, config: config)
            weekResults.append(StageResult(name: "体調ダウン", passed: false, prize: 0, isStage: false))
        }
        switch action {
        case .acceptOffer:
            if let o = offer {
                GameEngine.applyOffer(o, to: &state, config: config)
            } else {
                GameEngine.applyRest(.完全休養, to: &state, config: config)
            }
        case .train(let t):
            if !GameEngine.applyTraining(t, to: &state, config: config) {
                GameEngine.applyRest(.完全休養, to: &state, config: config)   // 払えなければ休む（Python同様）
            }
        case .job(let j):
            GameEngine.applyJob(j, to: &state, config: config)
        case .rest(let r):
            GameEngine.applyRest(r, to: &state, config: config)
        }
        acted = true
        return proceed()
    }

    /// runYear のブロック1〜5を、入力が要る箇所で止めながら順に評価する
    private mutating func proceed() -> Phase {
        let cal = config.calendar

        if section == .tournament {
            section = .gp
            if !acted, let spec = cal.tournament(inWeek: week), spec.isEligible(year: year, state: state) {
                pendingSpec = spec
                return .tournamentDecision(spec)
            }
        }

        if section == .gp {
            section = .finalWeek
            if !acted && gpAlive && gpStage < cal.gpRounds.count && week == cal.gpRounds[gpStage].week {
                if !gpEntryPaid && state.money < cal.entryFee {
                    gpAlive = false   // エントリー費が払えない＝その年は出られない（runYearと同一）
                } else {
                    pendingAuto = .round
                    let name = gpStage < cal.gpRoundNames.count ? cal.gpRoundNames[gpStage] : "GP回戦\(gpStage + 1)"
                    return .gpRound(index: gpStage, name: name)
                }
            }
        }

        if section == .finalWeek {
            // runYear と同一: 決勝週の処理は acted に関係なく走る
            if week == cal.gpFinalWeek {
                if revival && !revivalTried {
                    pendingAuto = .revival
                    return .gpRevival
                }
                if finalist && !finalTried {
                    pendingAuto = .final
                    return .gpFinal
                }
            }
            section = .free
        }

        if section == .free {
            section = .end
            if !acted {
                let offer = GameEngine.rollOffer(state: state, config: config, rng: &rng)
                if state.recoveryWeeks > 0 {
                    state.recoveryWeeks -= 1                 // 療養中（オファーは受けられない・runYearと同一順序）
                    GameEngine.applyRest(.完全休養, to: &state, config: config)
                    weekResults.append(StageResult(name: "療養", passed: false, prize: 0, isStage: false))
                } else {
                    pendingOffer = offer
                    return .freeAction(offer: offer)
                }
            }
        }

        // 週末処理（生活費→生活苦→夜逃げ判定）→ 週の結果
        if GameEngine.applyWeekEnd(week: week, to: &state, config: config) {
            let outcome = YearOutcome(champion: false, roundsPassed: gpStage, reachedFinal: finalist, bankrupt: true)
            finished = outcome
            return .yearDone(outcome)
        }
        return .weekDone(WeekSummary(year: year, week: week, results: weekResults, state: state))
    }
}
