// WeekRunner.swift
// runYear（Career.swift）と同一セマンティクスの「ステップ実行機」。UIが週の途中で人の入力を待てる形にする。
// 正典性: runYear と完全に同じ順序で GameEngine を呼び、乱数消費順を一致させる（正典は tools/gen_golden.py の docstring）。
// 同値性は WeekRunnerGoldenTests（CareerGoldenTests と同じ3年期待値でのビット一致）で担保する。
// 【docs/ui_design_v0.md §5・2026-07-05 委譲済み】GameCareer.runYear はこの WeekRunner を policy で
// 駆動するだけの薄いラッパになった。週処理と乱数消費順の正典実体はこのファイルが唯一持つ。

/// 大会・回戦の結果1件（UIの結果トースト用）。Codable は中断セーブ用（proposals-0039）＝挙動不変。
public struct StageResult: Codable {
    public let name: String
    public let passed: Bool
    public let prize: Int      // 通過時のみ賞金額、敗退は0
    /// 大会・GP各回戦・敗者復活・決勝など「結果画面(S3)を出す本番」か。
    /// 体調ダウン/療養など週内の付随イベントは false（UIが名前で判別せず型で分岐できるように）。
    public let isStage: Bool
    /// 本番スコア − 実効ライン（負＝足りなかった分）。表示専用（負けの"距離"・監査E-03）。
    /// Optional＝旧セーブに無くても復号できる。乱数・判定には一切関与しない。
    public let margin: Double?
    /// その本番が「ハマった夜」だったか。表示専用（見える運・canonical_v2 §1）。Optional＝旧セーブに無くても復号できる。
    public let burst: Bool?

    public init(name: String, passed: Bool, prize: Int, isStage: Bool = true, margin: Double? = nil, burst: Bool? = nil) {
        self.name = name
        self.passed = passed
        self.prize = prize
        self.isStage = isStage
        self.margin = margin
        self.burst = burst
    }
}

/// 週の結果（UIの差分ポップは前週スナップショットとの比較で出す）。Codable は中断セーブ用。
public struct WeekSummary: Codable {
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

    /// Codable は中断セーブ用（GameSession.SaveData が「UIがいま待っている位相」ごと保存する）＝挙動不変。
    public enum Phase: Codable {
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
    /// 直前の resolveAction で実際に行った練習（体力ゲート・体調ダウン・お金不足で休みに差し替わったら nil）。
    /// 表示とネタの後段フック用（GameSession.applyNetaWork）。読むだけ＝式・乱数・golden に関与しない。中断セーブにも載せない
    public private(set) var lastTrainingDone: Training? = nil
    private var gpEntryPaid = false   // エントリー費はその年最初に出る回戦で徴収
    private var gpAlive: Bool
    private var finalist: Bool
    private var revival = false

    /// GP にまだ残っているか（読み取り専用・UIの「次の本番」表示用。ロジック・乱数消費は不変＝golden不変）。
    /// false＝回戦で敗退済み or エントリー費が払えず出場不可。決勝進出者は true のまま（finalist を併読）。
    public var isGPAlive: Bool { gpAlive && gpStage < config.calendar.gpRounds.count }
    /// 決勝（または敗者復活経由）の舞台に立つ資格があるか（読み取り専用・表示用）
    public var isFinalist: Bool { finalist }
    /// 準決勝敗退で敗者復活に回るか（読み取り専用・表示用）
    public var hasRevival: Bool { revival && !revivalTried }
    /// 通過済みGP回戦数（読み取り専用・表示用）
    public var gpRoundsPassed: Int { gpStage }

    // 週内の進行位置（runYear のブロック1〜5に対応）。
    // Section/AutoStage の public 化と Codable は中断セーブ（WeekRunnerSnapshot）用＝可視性のみの変更・挙動不変。
    public enum Section: Codable { case tournament, gp, finalWeek, free, end }
    private var section = Section.tournament
    private var acted = false
    private var weekResults: [StageResult] = []
    private var pendingSpec: TournamentSpec?
    private var pendingOffer: OfferSpec?
    public enum AutoStage: Codable { case round, revival, final }
    private var pendingAuto: AutoStage?
    private var revivalTried = false
    private var finalTried = false
    private var finished: YearOutcome?
    /// §102 誘い用のキャリアのシード（nil=誘いなし）。本編の rng とは独立の決定論。中断セーブに載る
    public private(set) var inviteSeed: UInt64?
    /// 週末に来た誘い（nil=なし）。値＝「行ったとき発想が付くか」。resolveInvite で解決するまで保留（解決せず begin() すると「断る」扱い）
    public private(set) var pendingInvite: Bool?

    public init(
        state: GameState,
        year: Int,
        config: GameConfig,
        rng: R,
        seedFinal: Bool = false,
        finalLineOverride: Double? = nil,
        gpSeeded: Bool = false,   // 前年準々決勝以上（roundsPassed>=3）で1回戦免除
        inviteSeed: UInt64? = nil   // §102 飲みの誘いのシード（nil=誘いなし）
    ) {
        precondition(year >= 1, "year は1以上（成長予算の累計計算が前提）")
        var s = state
        s.stamina = config.initStamina   // 体力のみ年初に全回復（runYear冒頭と同一）
        var budget = 0.0                 // 成長予算の更新（キャリア累計・正典v2）
        for k in 1...min(year, config.growthEndYear) {
            budget += max(config.capCurveFloor, config.capCurveBase - config.capCurveSlope * Double(k - 1))
        }
        s.growthBudget = budget
        GameEngine.resetYearlyItems(&s)  // その年だけのアイテム効果と回数を消す（未購入は恒等）
        // 同じネタは飽きられる（キュー60）：前の年に大会で掛けたネタは飽きが1段進む（乱数なし）。Python: run_career 年初
        for i in s.netas.indices where s.netas[i].lastUsedTaikaiYear == year - 1 {
            s.netas[i].tiredYears = min(config.netaTiredCap, (s.netas[i].tiredYears ?? 0) + 1)
        }
        // しまったネタも同じく進める（しまって寝かせても飽きは戻らない＝決定①。全体監査 A-2）。Python には保管庫が無いので golden 非経路
        for i in s.archivedNetas.indices where s.archivedNetas[i].lastUsedTaikaiYear == year - 1 {
            s.archivedNetas[i].tiredYears = min(config.netaTiredCap, (s.archivedNetas[i].tiredYears ?? 0) + 1)
        }
        self.state = s
        self.year = year
        self.config = config
        self.rng = rng
        self.inviteSeed = inviteSeed
        self.gpStage = gpSeeded ? 1 : 0   // シード組は2回戦から
        self.gpAlive = !seedFinal
        self.finalist = seedFinal
        self.finalLine = finalLineOverride ?? config.calendar.gpFinalLine
    }

    /// 大会で選択中のネタを掛けた印（年初の飽きの判定用・乱数なし）。Python: _neta_use の used_y
    private mutating func markNetaUsed() {
        if let id = state.selectedNetaID, let i = state.netas.firstIndex(where: { $0.id == id }) {
            state.netas[i].lastUsedTaikaiYear = year
        }
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
        pendingInvite = nil    // 解決されなかった誘いは「断る」
        acted = false
        weekResults = []
        state.riftWeekStartCompat = state.compat   // 途中解散：この週に相性が上がったか（乱数なし）
        state.riftJointWeek = false
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
            var ts = config.calendar.travelSpec(travel)
            if state.shinkansenActive == true { ts = TravelSpec(cost: 0, stamina: 0) }   // 新幹線回数券（Item.swift）
            let need = config.calendar.entryFee + (spec.osaka ? ts.cost : 0)
            if state.money >= need {
                state.money -= config.calendar.entryFee
                if spec.osaka {
                    state.money -= ts.cost
                    GameEngine.add(.体力, ts.stamina, to: &state, config: config)
                }
                let netaLine = spec.line - GameEngine.netaScoreBonus(state, isFinal: false, config: config)
                let result = GameEngine.perform(state, line: netaLine, config: config, rng: &rng)
                markNetaUsed()
                state.riftJointWeek = true   // §94 二人で舞台に立つ週
                if result.passed {
                    state.money += spec.prize
                    GameEngine.add(.知名度, spec.fame, to: &state, config: config)
                }
                acted = true
                weekResults.append(StageResult(name: spec.name, passed: result.passed,
                                               prize: result.passed ? spec.prize : 0,
                                               margin: result.score - netaLine, burst: result.burst))
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
            let roundLine = round.line - GameEngine.netaScoreBonus(state, isFinal: false, config: config)
            let result = GameEngine.perform(state, line: roundLine, config: config, rng: &rng)
            markNetaUsed()
            acted = true
            state.riftJointWeek = true
            if result.passed {
                GameEngine.add(.知名度, cal.gpRoundFame, to: &state, config: config)
                gpStage += 1
                if gpStage == cal.gpRounds.count {
                    finalist = true
                    GameEngine.addFameBig(cal.fameFinalist, to: &state)   // 決勝進出（キュー62）
                }
            } else {
                if gpStage < config.gpLossCompat.count {
                    GameEngine.add(.コンビ相性, -config.gpLossCompat[gpStage], to: &state, config: config)   // §94 予選で落ちたら相性↓
                }
                if gpStage == cal.gpRounds.count - 1 {
                    revival = true   // 準決勝敗退のみ敗者復活へ
                }
                gpAlive = false
            }
            weekResults.append(StageResult(name: name, passed: result.passed, prize: 0, margin: result.score - roundLine, burst: result.burst))
        case .revival:
            revivalTried = true
            let revivalLine = cal.gpRevivalLine - GameEngine.netaScoreBonus(state, isFinal: false, config: config)
            let result = GameEngine.perform(state, line: revivalLine, config: config, rng: &rng)
            markNetaUsed()
            acted = true
            state.riftJointWeek = true
            if result.passed {
                GameEngine.add(.知名度, cal.gpRoundFame, to: &state, config: config)
                finalist = true
                GameEngine.addFameBig(cal.fameFinalist, to: &state)
            }
            weekResults.append(StageResult(name: "敗者復活", passed: result.passed, prize: 0, margin: result.score - revivalLine, burst: result.burst))
        case .final:
            finalTried = true
            // 決勝のみの人気補正（機微・judge_design §10-F）。王者防衛のライン上書き時にも適用
            // ＋ネタ Phase 1-a: 決勝は2本制（isFinal: true）＝2本目の完成度も実効ラインに効く
            let effLine = finalLine - cal.fameFinalBonus * (state.fame - 50) / 50
                        - GameEngine.netaScoreBonus(state, isFinal: true, config: config)
            let result = GameEngine.perform(state, line: effLine, config: config, rng: &rng)
            markNetaUsed()
            acted = true
            state.riftJointWeek = true
            weekResults.append(StageResult(name: "GP決勝", passed: result.passed,
                                           prize: result.passed ? cal.gpPrize : 0, margin: result.score - effLine, burst: result.burst))
            if result.passed {
                state.money += cal.gpPrize
                GameEngine.addFameRaw(cal.champFame, to: &state)   // 優勝は逓減なし（キュー62）
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
        lastTrainingDone = nil
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
           rng.nextUniform() < (config.injuryThreshold - state.stamina) * config.injuryProbPerPoint * GameEngine.injuryProbMultiplier(state: state, config: config) * (state.has(.体が資本) ? Skill.injuryMult : 1.0) {
            action = .rest(.完全休養)                    // 体調ダウン発生（「喉をやられた」等）
            state.recoveryWeeks = config.injuryRestWeeks - 1
            GameEngine.add(.ability(.メンタル), config.injuryMentalHit, to: &state, config: config)
            weekResults.append(StageResult(name: "体調ダウン", passed: false, prize: 0, isStage: false))
        }
        switch action {
        case .acceptOffer:
            if let o = offer {
                GameEngine.applyOffer(o, to: &state, config: config, atWeek: (year - 1) * config.weeks + week)
            } else {
                GameEngine.applyRest(.完全休養, to: &state, config: config)
            }
        case .train(let t):
            if GameEngine.applyTraining(t, to: &state, config: config) {
                lastTrainingDone = t
                if t == .ネタ見せ会 || t == .フリーライブ { state.riftJointWeek = true }   // §94
            } else {
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
                    GameEngine.applyRest(.完全休養, to: &state, config: config, useTicket: false)   // A-10: 選んでいない療養週は回数券を使わない
                    weekResults.append(StageResult(name: "療養", passed: false, prize: 0, isStage: false))
                } else {
                    pendingOffer = offer
                    return .freeAction(offer: offer)
                }
            }
        }

        // 会計移設（golden台本・即時全量注ぎ）: 行動直後に稼いだ粒を recommendedPlan で全量注ぐ。
        // sim_career.run_year / gen_golden.run_year と同一順序（行動直後・週末生活費の前）。RNG非消費＝乱数消費順不変。
        // 稽古以外の週は粒が無い＝空注ぎ（no-op）。
        // ★ autoPourAllocation で分離: true（既定）= sim/golden/ボットの決定論的おすすめ台本＝golden期待値の前提。
        //   実ゲーム（GameSession）は false ＝ここでは注がず粒を貯め、プレイヤーが AllocationView で手動割り振り（applyAllocation）。
        if config.autoPourAllocation {
            GameEngine.pourRecommended(to: &state, config: config)
        }

        // 週末処理（生活費→生活苦→夜逃げ判定）→ 週の結果
        if GameEngine.applyWeekEnd(week: week, to: &state, config: config) {
            let outcome = YearOutcome(champion: false, roundsPassed: gpStage, reachedFinal: finalist, bankrupt: true)
            finished = outcome
            return .yearDone(outcome)
        }
        if GameEngine.applyRiftWeekEnd(year: year, to: &state, config: config) {
            let outcome = YearOutcome(champion: false, roundsPassed: gpStage, reachedFinal: finalist, dissolved: true)
            finished = outcome
            return .yearDone(outcome)
        }
        // §102 飲みの誘い（解散判定の後・乱数は別系統）。来たら保留し、UI/ポリシーが resolveInvite で選ぶ
        if let seed = inviteSeed {
            pendingInvite = GameEngine.rollInvite(seed: seed, year: year, week: week, config: config)
        }
        return .weekDone(WeekSummary(year: year, week: week, results: weekResults, state: state))
    }

    /// 誘いに「行く」効果だけを適用する（アプリは週を送った後に札で選ぶため、保留を介さず直接呼ぶ）。RandomSource 非消費
    public mutating func applyInviteGo(idea: Bool) {
        GameEngine.applyInviteGo(idea: idea, to: &state, config: config)
    }

    /// 誘いの回答。行く＝所持金−5,000・体力−10・メンタル+1・(半分で)発想+0.5／断る＝何も起きない。RandomSource 非消費。
    public mutating func resolveInvite(accept: Bool) {
        guard let idea = pendingInvite else { return }
        pendingInvite = nil
        if accept { GameEngine.applyInviteGo(idea: idea, to: &state, config: config) }
    }

    /// 選択肢イベントの確定効果を runner の権威 state に適用する（proposals/0024 ピース1）。
    /// RandomSource を一切呼ばない＝乱数消費順は1ビットも動かない＝3年 golden 不変。
    /// golden 生成器（gen_golden.py / このrunner）はイベントを走らせないので期待値も不変。
    public mutating func applyEventEffects(_ effects: [EventEffect]) {
        for e in effects { state.applyEventEffect(e, config: config) }
    }

    /// 経験点の割り振り（粒→能力）を runner の権威 state に適用する（applyEventEffects と同じ規律・
    /// docs/exp_abilityup_impl_reply_v0.md）。RandomSource を一切呼ばない＝乱数消費順は1ビットも動かない。
    /// golden/sim 経路は autoPourAllocation=true で行動直後に全量注ぐため、ここに来る残高は実ゲーム（手動注ぎ）だけ。
    /// taps は AllocationView のタップ順（プレビューと同一列を同一順で再生＝表示と確定が食い違わない）。
    public mutating func applyAllocation(_ taps: [Ability]) {
        for a in taps { GameEngine.pourStep(a, to: &state, config: config) }
    }

    // MARK: 持ちネタの純適用（正典: docs/neta_system_redesign_v2.md Phase 0-b / スコア寄与=Phase 1-a）
    // ★applyAllocation/applyEventEffects と同じ規律: これら apply* は RandomSource を一切呼ばない＝乱数消費順は
    //   1ビットも動かない。golden 生成器（gen_golden.py / runYear）はネタ個体を持たない＝selectedNetaID==nil。
    //   ▸Phase 1-a（実装済み）: perform の実効ラインが `GameEngine.netaScoreBonus` で下がる＝選択が勝敗に効く。
    //     ただし selectedNetaID==nil では恒等0＝golden 経路は不変（swift test/gen_golden で実証済み）。
    //   ▸未実装（見送り・オーナー2026-07-19）: 型×審査員相性スコア(1-b)・buzz の客層依存乱数(1-c)。

    /// 新ネタ生成（`ネタ作り`・新規時）。連番採番→アクティブ枠に追加→id を返す。乱数非依存。
    @discardableResult
    public mutating func applyNetaCreate(kata: NetaKata, lengthFit: [NetaLength], name: String) -> Int {
        let id = state.nextNetaID
        state.nextNetaID += 1
        state.netas.append(Neta(id: id, name: name, kata: kata, lengthFit: lengthFit, bornYear: year))
        return id
    }

    /// 改稿（`ネタ作り`・既存ネタ選択時）。完成度を上げる（0..100 clamp）。
    /// 0016 書けた一本（寝かせる）: netaBoostWeeks>0 の間は netaBoostMult 倍で乗る。★golden不変: gen_golden は
    /// ネタ個体を持たない＝この関数を呼ばない＋イベント非発火で netaBoostWeeks は常に0＝乗算は恒等（×1.0）。
    /// gain＝場所ごとの伸び（nil＝家で書く＝netaReviseGain・money_items_neta_v1 §1）
    public mutating func applyNetaRevise(id: Int, gain: Double? = nil) {
        guard let i = state.netas.firstIndex(where: { $0.id == id }) else { return }
        let mult = state.netaBoostWeeks > 0 ? config.netaBoostMult : 1.0
        state.netas[i].polish = GameEngine.clamp(state.netas[i].polish + (gain ?? config.netaReviseGain) * mult, 0, 100)
    }

    /// 客前でかける（`ネタ見せ会`＝hard/`フリーライブ`＝!hard）。手応え算出→buzz移動平均→完成度↑・場数↑・おろし。乱数非依存。
    public mutating func applyNetaLive(id: Int, hard: Bool) {
        guard let i = state.netas.firstIndex(where: { $0.id == id }) else { return }
        let lb = Neta.liveBuzz(state: state, neta: state.netas[i], config: config)   // 演じた時点の手応え（乱数なし）
        state.netas[i].buzz = state.netas[i].buzz * (1 - config.netaBuzzAlpha) + lb * config.netaBuzzAlpha
        let gain = hard ? config.netaLivePolishShow : config.netaLivePolishFree
        state.netas[i].polish = GameEngine.clamp(state.netas[i].polish + gain, 0, 100)
        state.netas[i].stageCount += 1
        state.netas[i].isDown = true   // 初回＝ネタおろし（一回性の節目・v2 §3-2補2）
    }

    /// 改名（v2 §9決点3・自動命名の上書き）。アクティブ/保管庫どちらのネタも対象。純データ変更・非スコア。
    public mutating func applyNetaRename(id: Int, to name: String) {
        if let i = state.netas.firstIndex(where: { $0.id == id }) { state.netas[i].name = name }
        else if let j = state.archivedNetas.firstIndex(where: { $0.id == id }) { state.archivedNetas[j].name = name }
    }

    /// 型の組み替え（大改稿で1度・v2 §3-1補）。アクティブ/保管庫どちらのネタも対象。
    public mutating func applyNetaChangeKata(id: Int, to kata: NetaKata) {
        if let i = state.netas.firstIndex(where: { $0.id == id }) { state.netas[i].kata = kata }
        else if let j = state.archivedNetas.firstIndex(where: { $0.id == id }) { state.archivedNetas[j].kata = kata }
    }

    /// アクティブ枠→保管庫へ退避（削除でも封印でもない・いつでも呼び戻せる・v2 §2-2）。
    public mutating func applyNetaRetire(id: Int) {
        guard let i = state.netas.firstIndex(where: { $0.id == id }) else { return }
        state.archivedNetas.append(state.netas.remove(at: i))
        if state.selectedNetaID == id { state.selectedNetaID = nil }
    }

    /// 保管庫→アクティブ枠へ呼び戻す（古いネタの再演・v2 §2-2/§4-2）。
    public mutating func applyNetaRecall(id: Int) {
        guard let i = state.archivedNetas.firstIndex(where: { $0.id == id }) else { return }
        state.netas.append(state.archivedNetas.remove(at: i))
    }

    /// 「今かけるネタ」の選択（大会/自由週・v2 §4）。1本目/2本目（決勝）。乱数非依存。
    /// ★選択自体は乱数を引かないが、Phase 1-a で本番の実効ラインに効く（netaScoreBonus）＝勝敗に効く選択。
    /// アイテムを買う（乱数非消費・Item.swift）。買えなければ false
    @discardableResult
    public mutating func applyItemPurchase(_ item: ShopItem) -> Bool {
        GameEngine.buy(item, to: &state, config: config)
    }

    /// 部屋を選び直す（乱数非消費・GameEngine.moveRoom）。選べなければ false
    @discardableResult
    public mutating func applyRoomMove(to target: Int) -> Bool {
        GameEngine.moveRoom(to: target, state: &state, config: config)
    }

    /// 特技を覚える（乱数非消費・Skill.swift）。足りなければ false
    @discardableResult
    public mutating func applyLearnSkill(_ k: Skill) -> Bool {
        GameEngine.learnSkill(k, to: &state)
    }

    /// お店の「戻す」（UI層・2026-10-12）：店に入った時の状態へ戻してから、残った買い物を順に買い直す。
    /// 購入は乱数を引かない純関数（GameEngine.buy）なので、買い直しで元と同じ状態になる＝RNG・数式は不変（golden不変）。
    public mutating func replayItemPurchases(from start: GameState, _ items: [ShopItem]) {
        state = start
        for it in items { _ = GameEngine.buy(it, to: &state, config: config) }
    }

    public mutating func applyNetaSelect(id: Int?) { state.selectedNetaID = id }
    public mutating func applyNetaSelect2(id: Int?) { state.selectedNetaID2 = id }

    /// 相性凍結（0012）の残り週数を1減らす。★UI層（GameSession）が週送りごとに呼ぶ＝gen_golden は呼ばない＝
    /// golden 経路では compatFreezeWeeks が常に0のまま＝この減算も add の凍結ゲートも恒等 no-op＝golden不変。
    public mutating func tickCompatFreeze() {
        if state.compatFreezeWeeks > 0 { state.compatFreezeWeeks -= 1 }
    }

    /// ネタ合わせブースト（0016）の残り週数を1減らす。★tickCompatFreeze と同型: UI層（GameSession）が週送りで
    /// 呼ぶ＝gen_golden は呼ばない＝golden 経路では netaBoostWeeks が常に0＝この減算も revise 乗算も恒等 no-op。
    public mutating func tickNetaBoost() {
        if state.netaBoostWeeks > 0 { state.netaBoostWeeks -= 1 }
    }

    /// 稽古拘束（0022）の残り週数を1減らす。★tickCompatFreeze と同型: UI層（GameSession）が週送りで呼ぶ＝
    /// gen_golden は呼ばない＝golden 経路では preoccupiedWeeks が常に0＝稽古ロックは一度も効かない（golden不変）。
    public mutating func tickPreoccupied() {
        if state.preoccupiedWeeks > 0 { state.preoccupiedWeeks -= 1 }
    }
}

// MARK: 中断セーブ（proposals/0039）。「今の内部状態を読み出す／書き戻す」だけの非破壊API＝
// RNG消費順・数式は一切変更なし＝golden不変（tools/*.py 同期不要）。
// private フィールドへのアクセスに同一ファイル内特権が要るため、この extension は WeekRunner.swift に置く。

/// 中断セーブ用のスナップショット。GameConfig は含まない（固定バランス値＝永続化しない。
/// 将来バランス値を更新したとき、古いセーブに古い値が固定化されるのを防ぐ＝復元時に外から注入する）。
public struct WeekRunnerSnapshot<R: RandomSource & Codable>: Codable {
    public var state: GameState
    public var rng: R
    public var year: Int
    public var week: Int
    public var finalLine: Double
    public var gpStage: Int
    public var gpEntryPaid: Bool
    public var gpAlive: Bool
    public var finalist: Bool
    public var revival: Bool
    public var section: WeekRunner<R>.Section
    public var acted: Bool
    public var weekResults: [StageResult]
    public var pendingSpec: TournamentSpec?
    public var pendingOffer: OfferSpec?
    public var pendingAuto: WeekRunner<R>.AutoStage?
    public var revivalTried: Bool
    public var finalTried: Bool
    public var finished: YearOutcome?
    public var inviteSeed: UInt64?     // §102（旧セーブには無い＝nil＝誘いなし）
    public var pendingInvite: Bool?
}

extension WeekRunner where R: Codable {
    /// 現在の内部状態を取り出す（セーブ用・非破壊・RNG非消費）
    public func snapshot() -> WeekRunnerSnapshot<R> {
        WeekRunnerSnapshot(state: state, rng: rng, year: year, week: week, finalLine: finalLine,
                           gpStage: gpStage, gpEntryPaid: gpEntryPaid, gpAlive: gpAlive,
                           finalist: finalist, revival: revival, section: section, acted: acted,
                           weekResults: weekResults, pendingSpec: pendingSpec, pendingOffer: pendingOffer,
                           pendingAuto: pendingAuto, revivalTried: revivalTried, finalTried: finalTried,
                           finished: finished, inviteSeed: inviteSeed, pendingInvite: pendingInvite)
    }

    /// スナップショットからの復元（ロード用）。年初処理（体力全回復・成長予算の再計算）は走らせず、
    /// 保存時点の値をそのまま書き戻す。config はアプリ起動時に生成した固定値を渡す。
    public init(restoring snap: WeekRunnerSnapshot<R>, config: GameConfig) {
        self.state = snap.state
        self.rng = snap.rng
        self.year = snap.year
        self.config = config
        // A-4: バランス更新が古いセーブに固定化されないよう、決勝ライン・保留中の大会/オファーは config から取り直す
        self.finalLine = config.calendar.gpFinalLine
        self.gpStage = snap.gpStage
        self.gpAlive = snap.gpAlive
        self.finalist = snap.finalist
        self.week = snap.week
        self.gpEntryPaid = snap.gpEntryPaid
        self.revival = snap.revival
        self.section = snap.section
        self.acted = snap.acted
        self.weekResults = snap.weekResults
        if snap.pendingSpec != nil {
            self.pendingSpec = config.calendar.tournament(inWeek: snap.week) ?? snap.pendingSpec
        } else {
            self.pendingSpec = nil
        }
        if let o = snap.pendingOffer {
            self.pendingOffer = (config.offersNamed + [config.offerMoney, config.offerExp]).first { $0.name == o.name } ?? o
        } else {
            self.pendingOffer = nil
        }
        self.pendingAuto = snap.pendingAuto
        self.revivalTried = snap.revivalTried
        self.finalTried = snap.finalTried
        self.finished = snap.finished
        self.inviteSeed = snap.inviteSeed
        self.pendingInvite = snap.pendingInvite
    }
}
