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
        // 週処理の実体は WeekRunner（ステップ実行機）に一本化し、runYear はそれを policy で駆動する薄い委譲にする。
        // これで「週処理＋乱数消費順」の重複が解消され、正典ロジックは WeekRunner だけが持つ（docs/ui_design_v0.md §5）。
        // 等価性は WeekRunnerGoldenTests / CareerGoldenTests の3年ビット一致で二重に担保される。
        var runner = WeekRunner(state: s, year: year, config: config, rng: rng,
                                seedFinal: seedFinal, finalLineOverride: finalLineOverride,
                                gpSeeded: gpSeeded)
        var phase = runner.begin()
        while true {
            switch phase {
            case .tournamentDecision(let spec):
                let travel = policy.enterTournament(spec, year: year, state: runner.state)
                phase = runner.resolveTournament(travel: travel)
            case .freeAction(let offer):
                let action = policy.action(week: runner.week, year: year, state: runner.state, offer: offer)
                phase = runner.resolveAction(action)
            case .gpRound, .gpRevival, .gpFinal:
                phase = runner.resolveAuto()   // 回戦・敗者復活・決勝は入力不要（runYear では即消化）
            case .weekDone(let summary):
                onWeekEnd?(summary.week, summary.state)
                phase = runner.begin()
            case .yearDone(let outcome):
                s = runner.state     // 年末（優勝/夜逃げ含む）の状態と乱数列を呼び出し側へ書き戻す
                rng = runner.rng
                return outcome
            }
        }
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
