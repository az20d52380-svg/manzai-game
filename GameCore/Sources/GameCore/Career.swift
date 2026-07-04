// Career.swift
// 1年48週の進行エンジン（大会・多段階グランプリ・オファー・生活費）と、王者編用のシード/ライン上書き。
// 週処理と乱数消費の順序は tools/gen_golden.py が正典。変更時は必ず両方を更新し、
// CareerGoldenTests（同一乱数列での3年ビット一致）を再生成すること（CLAUDE.mdルール5）。

public enum WeekAction {
    case train(Training)
    case job(Job)
    case rest(Rest)
    case acceptOffer
}

/// 週次の意思決定の注入点。UI（プレイヤー）もテスト（スクリプト）もこれを実装する
public protocol WeekPolicy {
    /// 自由行動週の選択。offer が nil でないときのみ .acceptOffer が有効
    mutating func action(week: Int, year: Int, state: GameState, offer: OfferSpec?) -> WeekAction
    /// 大会に出るか（nil=出場しない）。出るなら移動手段（東京開催では無視される）
    mutating func enterTournament(_ spec: TournamentSpec, year: Int, state: GameState) -> Travel?
}

public struct YearOutcome {
    public let champion: Bool
    public let roundsPassed: Int    // 通過したGP回戦数 0〜5
    public let reachedFinal: Bool   // 決勝の舞台に立ったか（敗者復活経由含む）
    public let bankrupt: Bool       // 夜逃げ（-100万未満）でキャリア終了したか【正典v2】

    public init(champion: Bool, roundsPassed: Int, reachedFinal: Bool, bankrupt: Bool = false) {
        self.champion = champion
        self.roundsPassed = roundsPassed
        self.reachedFinal = reachedFinal
        self.bankrupt = bankrupt
    }
}

public enum GameCareer {

    /// 1年を回す。優勝したら即座に返る（勇退/王者編の分岐は呼び出し側）。
    /// seedFinal=true で王者シード（予選免除・決勝直行）、finalLineOverride で王者ライン（飽きられ）を注入。
    /// gpSeeded=true で1回戦免除（前年に準々決勝以上へ進出=roundsPassed>=3・実在準拠のシード制）
    public static func runYear<P: WeekPolicy, R: RandomSource>(
        state s: inout GameState,
        year: Int,
        config: GameConfig,
        policy: inout P,
        rng: inout R,
        seedFinal: Bool = false,
        finalLineOverride: Double? = nil,
        gpSeeded: Bool = false,
        onWeekEnd: ((Int, GameState) -> Void)? = nil
    ) -> YearOutcome {
        s.stamina = config.initStamina   // 体力のみ年初に全回復
        // 成長予算の更新（キャリア累計・正典v2。growthUsed はリセットしない）
        var budget = 0.0
        for k in 1...min(year, config.growthEndYear) {
            budget += max(config.capCurveFloor, config.capCurveBase - config.capCurveSlope * Double(k - 1))
        }
        s.growthBudget = budget
        let cal = config.calendar
        var gpStage = gpSeeded ? 1 : 0   // シード組は2回戦から
        var gpEntryPaid = false          // エントリー費はその年最初に出る回戦で徴収
        var gpAlive = !seedFinal
        var finalist = seedFinal
        var revival = false
        let finalLine = finalLineOverride ?? cal.gpFinalLine

        for week in 1...config.weeks {
            var acted = false

            // 1) 道中の大会（資格→出場判断→エントリー費＋大阪なら交通費）
            if let spec = cal.tournament(inWeek: week), spec.isEligible(year: year, state: s) {
                if let travel = policy.enterTournament(spec, year: year, state: s) {
                    let ts = cal.travelSpec(travel)
                    let need = cal.entryFee + (spec.osaka ? ts.cost : 0)
                    if s.money >= need {
                        s.money -= cal.entryFee
                        if spec.osaka {
                            s.money -= ts.cost
                            GameEngine.add(.体力, ts.stamina, to: &s, config: config)
                        }
                        let result = GameEngine.perform(s, line: spec.line, config: config, rng: &rng)
                        if result.passed {
                            s.money += spec.prize
                            GameEngine.add(.知名度, spec.fame, to: &s, config: config)
                        }
                        acted = true
                    }
                }
            }

            // 2) グランプリ各回戦（東京・遠征不要・毎年1回戦から。1回戦週にエントリー費）
            if !acted && gpAlive && gpStage < cal.gpRounds.count && week == cal.gpRounds[gpStage].week {
                if !gpEntryPaid && s.money < cal.entryFee {
                    gpAlive = false   // エントリー費が払えない＝その年は出られない（週は自由行動へ）
                } else {
                    if !gpEntryPaid {
                        s.money -= cal.entryFee
                        gpEntryPaid = true
                    }
                    let result = GameEngine.perform(s, line: cal.gpRounds[gpStage].line, config: config, rng: &rng)
                    acted = true
                    if result.passed {
                        GameEngine.add(.知名度, cal.gpRoundFame, to: &s, config: config)
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
                }
            }

            // 3) 決勝週（敗者復活 → 通過なら同週の決勝へ）
            if week == cal.gpFinalWeek {
                if revival {
                    let result = GameEngine.perform(s, line: cal.gpRevivalLine, config: config, rng: &rng)
                    acted = true
                    if result.passed {
                        GameEngine.add(.知名度, cal.gpRoundFame, to: &s, config: config)
                        finalist = true
                    }
                }
                if finalist {
                    // 決勝のみの人気補正（機微・judge_design §10-F）。王者防衛のライン上書き時にも適用
                    let effLine = finalLine - cal.fameFinalBonus * (s.fame - 50) / 50
                    let result = GameEngine.perform(s, line: effLine, config: config, rng: &rng)
                    acted = true
                    if result.passed {
                        s.money += cal.gpPrize
                        GameEngine.add(.知名度, cal.champFame, to: &s, config: config)
                        return YearOutcome(champion: true, roundsPassed: gpStage, reachedFinal: true)
                    }
                }
            }

            // 4) 自由行動週（オファー抽選 → 療養 → 体力ゲート → 体調ダウン判定 → 行動）
            if !acted {
                let offer = GameEngine.rollOffer(state: s, config: config, rng: &rng)
                if s.recoveryWeeks > 0 {
                    s.recoveryWeeks -= 1                                          // 療養中（オファーは受けられない）
                    GameEngine.applyRest(.完全休養, to: &s, config: config)
                } else {
                    var action = policy.action(week: week, year: year, state: s, offer: offer)
                    if case .train = action, s.stamina < config.staminaGate {
                        action = .rest(.完全休養)                                 // 体力ゲート（谷口が止める）
                    }
                    let risky: Bool
                    switch action {
                    case .train: risky = true
                    case .job(let j): risky = (j == .キツい)
                    default: risky = false
                    }
                    if risky, s.stamina < config.injuryThreshold,
                       rng.nextUniform() < (config.injuryThreshold - s.stamina) * config.injuryProbPerPoint {
                        action = .rest(.完全休養)                                 // 体調ダウン発生
                        s.recoveryWeeks = config.injuryRestWeeks - 1
                        GameEngine.add(.ability(.メンタル), config.injuryMentalHit, to: &s, config: config)
                    }
                    switch action {
                    case .acceptOffer:
                        if let o = offer {
                            GameEngine.applyOffer(o, to: &s, config: config)
                        } else {
                            GameEngine.applyRest(.完全休養, to: &s, config: config)   // 防御的フォールバック
                        }
                    case .train(let t):
                        if !GameEngine.applyTraining(t, to: &s, config: config) {
                            GameEngine.applyRest(.完全休養, to: &s, config: config)   // 払えなければ休む（Python同様）
                        }
                    case .job(let j):
                        GameEngine.applyJob(j, to: &s, config: config)
                    case .rest(let r):
                        GameEngine.applyRest(r, to: &s, config: config)
                    }
                }
            }

            // 5) 週末処理（生活費→生活苦→夜逃げ判定）
            if GameEngine.applyWeekEnd(week: week, to: &s, config: config) {
                return YearOutcome(champion: false, roundsPassed: gpStage, reachedFinal: finalist, bankrupt: true)
            }
            onWeekEnd?(week, s)
        }
        return YearOutcome(champion: false, roundsPassed: gpStage, reachedFinal: finalist)
    }

    /// 通常キャリア（最大 years 年・優勝で勇退）。優勝年（なければ nil）を返す
    public static func runCareer<P: WeekPolicy, R: RandomSource>(
        state s: inout GameState,
        years: Int,
        config: GameConfig,
        policy: inout P,
        rng: inout R
    ) -> Int? {
        var prevStage = 0
        for year in 1...years {
            let outcome = runYear(state: &s, year: year, config: config, policy: &policy, rng: &rng,
                                  gpSeeded: prevStage >= 3)
            prevStage = outcome.roundsPassed
            if outcome.champion {
                return year
            }
            if outcome.bankrupt {
                return nil   // 夜逃げ＝キャリア終了（Python: run_career の _bankrupt break と同期）
            }
        }
        return nil
    }
}
