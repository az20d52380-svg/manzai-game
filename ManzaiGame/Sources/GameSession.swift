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
    /// 直前の行動で稼いだ粒（同色ロック粒の増分。§1-3 受け取りの一拍＝週メインの獲得チップ行用）。
    /// ρ=0なので同色バンクのみ増える（共通枠は発行されない）。状態差分駆動で消費順・golden非対象。
    private(set) var lastGrainGains: [(ability: Ability, amount: Double)] = []
    /// 直前の行動での所持金/体力の増減（Beat2 獲得バースト用・表示専用）。週末の生活費も含む「この週の収支」。
    private(set) var lastMoneyDelta = 0
    private(set) var lastStaminaDelta = 0
    /// 上記の増減が属する週。View は lastDeltaWeek == week の時だけバーストを出す＝大会画面を
    /// 挟んで戻った時に古い増減が再生される事故を防ぐ（表示ゲートのみ・golden非対象）。
    private(set) var lastDeltaWeek = -1
    /// 連敗数（大会・GPで敗退が続いた回数。心の声「何が足りないんだ…」用）
    private(set) var lossStreak = 0
    /// 直近の大会で通過したか（先週の結果を心の声に反映。行動すると失効）
    private(set) var justPassedStage = false
    /// 直近の大会で敗退したか（負けた翌週の一言＝温度事故の停止。justPassedと対称・行動すると失効）
    private(set) var justLostStage = false
    /// 直近の行動でおろした（isDown:false→true）ネタのID。ネタ帳で一言を出す・次の行動で失効（justPassedと同型）
    private(set) var justOroshiNeta: (id: Int, text: String)?
    /// 選択肢イベント（正典: proposals/0024・0010/0017/0018/0019/0020/0021）。確定発火・確定効果のみ＝golden不変。
    /// 0019「型を捨てる相談」の一発化フラグ。lossStreak=0（通過）と同一トランザクションでリセット。
    private(set) var styleTalkDone = false
    /// 0021「慣れの外し方」の一発化フラグ。相性が初めて15に到達した週に一度だけ発火（キャリア1回・再発なし）。
    private(set) var didFireTsuukaChoice = false
    /// 0020「まだ敬語の残る間」の一発化フラグ。結成初期(week<15)×他人行儀帯(compat 0-7)で一度だけ発火。
    private(set) var didFireEarlyFormality = false
    /// 0028「名前の無い予約票」の一発化フラグ。確定発火＝選択がないので発火時に立てる（キャリア1回）。
    private(set) var didFireNamelessSlip = false
    /// 0012「谷口の耳寄りな話」の一発化フラグ。確定発火（金欠×相性8+×大会3週以内なし）・キャリア1回。
    private(set) var didFireTaniguchiJob = false
    // --- 週次ランダムイベント（UI層抽選・golden非干渉。runner.rng とは別インスタンスの独立乱数列） ---
    /// 発火抽選に使う UI 専用乱数。runner が消費する乱数列には一切食い込まない＝3年 golden 不変。
    private var uiEventRng = SplitMix64(seed: 424242)   // init で seed 由来値に上書き
    /// 週次イベントの1回制（発火済みの kind は再抽選しない）
    private var firedWeeklyEvents: Set<ChoiceEventKind> = []
    /// キャリア通算のイベント発火数（config.weeklyEventCap の総量予算）
    private var weeklyEventFiredCount = 0
    /// その週に既に抽選したか（1週1回・pump 複数回呼びでの二重抽選＝UI乱数の余分消費を防ぐ）
    private var lastEventRollWeek = -1
    /// バイト実行回数（UI層カウンタ・0023 正社員の話の発火条件。golden非対象）
    private var jobCount = 0
    /// 週頭に確定発火した保留中の選択肢イベント（nil=無し）。choose 側でなく自由週の描画時に1件だけ立てる。
    private(set) var pendingChoiceEvent: ChoiceEventKind?
    /// 週頭の掛け合い（俺⇄谷口の短い会話・タップ送り）。nil=この週は独白。行動すると失効。
    /// 発火はUI専用乱数（uiEventRng）＝runnerの乱数列に非干渉＝golden不変。イベント発火週は譲る。
    private(set) var weekBanter: [Advice]?
    /// 掛け合いの1週1回抽選ガード（pump 複数回呼びでの二重抽選＝UI乱数の余分消費を防ぐ・イベント抽選と同型）
    private var lastBanterRollWeek = -1
    /// 優勝が確定した瞬間。ここが true の間は「勝ち版」決勝演出を出す（S4ボードの前）
    private(set) var winFinale = false
    /// S6 行動内訳帯用: 週インデックス→その週のカテゴリ（UI層の記録のみ・golden非対象）
    private(set) var categoryLog: [Int: BandCategory] = [:]
    /// S6 年計用: その年の獲得賞金合計（UI層の記録のみ・golden非対象）
    private(set) var totalPrize = 0

    let config: GameConfig
    let year = 1                       // MVPは1年目のみ
    let combiName: String              // S1で入力（表示専用・golden非対象）
    /// 中断セーブから復元されたセッションか（RootView が IntroFlow をスキップする判定に使う）
    let isRestored: Bool

    // MARK: 進行の実体（WeekRunner が週処理と乱数消費の正典を持つ）
    private var runner: WeekRunner<SplitMix64>

    init(seed: UInt64 = 424242, config: GameConfig = GameConfig(), startState: GameState? = nil,
         combiName: String = "あなたのコンビ") {
        // 実ゲームは自動注ぎを切る＝稽古で稼いだ粒がプレイヤーの手元に貯まり、AllocationView で手動割り振り（パワプロ式）。
        // golden/sim は既定 true（決定論的おすすめ台本）のまま＝この分離で golden 不変・実ゲームだけ手動化。
        var cfg = config
        cfg.autoPourAllocation = false
        self.config = cfg
        self.combiName = combiName
        self.isRestored = false
        // 週次イベント抽選用の UI 乱数を seed から導出（runner の乱数列とは別シード＝独立列＝golden非干渉）。
        self.uiEventRng = SplitMix64(seed: seed &+ 0x9E3779B97F4A7C15)
        let start = startState ?? GameState(config: cfg)
        self.state = start
        var r = WeekRunner(state: start, year: 1, config: cfg, rng: SplitMix64(seed: seed))
        let firstPhase = r.begin()   // r を消費してから確定させる（値型なので順序が重要）
        self.runner = r
        self.phase = firstPhase
        pump()
    }

    /// 中断セーブからの復元（0039）。年初処理は走らせず、保存時点の位相・UI層フラグをそのまま書き戻す。
    /// config は毎回新規生成して注入（バランス値は永続化しない＝更新後の値で続きが進む）。
    init(restoring save: SaveData, config: GameConfig = GameConfig()) {
        var cfg = config
        cfg.autoPourAllocation = false
        self.config = cfg
        self.combiName = save.combiName
        self.isRestored = true
        self.uiEventRng = save.uiEventRng
        self.runner = WeekRunner(restoring: save.runner, config: cfg)
        self.state = save.runner.state
        self.phase = save.phase
        self.week = save.runner.week
        self.pendingResult = save.pendingResult
        self.log = save.log
        self.lossStreak = save.lossStreak
        self.justPassedStage = save.justPassedStage
        self.justLostStage = save.justLostStage
        self.styleTalkDone = save.styleTalkDone
        self.didFireTsuukaChoice = save.didFireTsuukaChoice
        self.didFireEarlyFormality = save.didFireEarlyFormality
        self.didFireNamelessSlip = save.didFireNamelessSlip
        self.didFireTaniguchiJob = save.didFireTaniguchiJob
        self.firedWeeklyEvents = save.firedWeeklyEvents
        self.weeklyEventFiredCount = save.weeklyEventFiredCount
        self.lastEventRollWeek = save.lastEventRollWeek
        self.jobCount = save.jobCount
        self.pendingChoiceEvent = save.pendingChoiceEvent
        self.weekBanter = save.weekBanter
        self.lastBanterRollWeek = save.lastBanterRollWeek
        self.categoryLog = save.categoryLog
        self.totalPrize = save.totalPrize
        // lastAction/lastGains 等の「直前の選択への反応」装飾は復元しない（再開直後は直前の選択が存在しない）
    }

    // MARK: UI からの入力（Phase 別）

    /// 大会週の回答（travel=nil は見送り）
    func decideTournament(_ travel: Travel?) {
        phase = runner.resolveTournament(travel: travel)
        pump()
        saveNow()
    }

    /// 自由行動週の回答
    func choose(_ action: WeekAction) {
        let before = state
        var action = action
        // 0022 稽古拘束（撮られる仕事）: その週は撮影で稽古枠が埋まる＝稽古を選んでも自動休養化（UI層・golden非経路）。
        // WeekMainView が稽古カードをグレーにするので通常ここには来ないが、二重の安全網（谷口の体力ゲートと同型）。
        if state.preoccupiedWeeks > 0, case .train = action { action = .rest(.完全休養) }
        lastAction = action
        categoryLog[week] = BandCategory(action)   // S6 行動内訳帯（この自由週のカテゴリ）
        if case .job = action { jobCount += 1 }     // 0023 発火条件用のバイト実行回数（UI層・golden非対象）
        justPassedStage = false   // 行動したら「先週通過」の余韻は失効
        justLostStage = false     // 「負けた翌週」の一言も行動で失効（justPassedと対称）
        justOroshiNeta = nil      // ネタおろしの一言も行動で失効（justPassedと同型）
        weekBanter = nil          // 週頭の掛け合いも行動で失効（次週の抽選は pump 側）
        phase = runner.resolveAction(action)
        applyNetaWork(for: action)   // ネタ作り/ネタ見せ会/フリーライブの後段フック（RNG非消費・golden不変・v2 §3）
        pump()
        lastGains = Ability.allCases.compactMap { a in
            let d = state[a] - before[a]
            return d > 0.001 ? (a, d) : nil
        }
        lastCompatGain = state.compat - before.compat
        // 会計移設で稽古は能力を直接伸ばさず粒を稼ぐ＝この週に入った同色ロック粒の増分（§1-3 受け取りの一拍）。
        lastGrainGains = Ability.allCases.compactMap { a in
            let d = state[bank: a] - before[bank: a]
            return d > 0.001 ? (a, d) : nil
        }
        // Beat2 獲得バースト用の収支（表示専用・golden非対象）。pump 後の state＝週末処理込みの実増減。
        lastMoneyDelta = state.money - before.money
        lastStaminaDelta = Int(state.stamina.rounded()) - Int(before.stamina.rounded())
        lastDeltaWeek = week
        // 0012 相性凍結の週送り減算（UI層・golden非対象）。この週の行動は freeze 有効で処理され、週が明けて1減る。
        if state.compatFreezeWeeks > 0 { runner.tickCompatFreeze(); state = runner.state }
        // 0016 ネタ合わせブーストの週送り減算（UI層・golden非対象・freeze と同型）。この週の revise はブースト有効で
        // 処理され、週が明けて1減る＝設定週を含む向こう config.netaBoostWeeks 週だけ乗る。
        if state.netaBoostWeeks > 0 { runner.tickNetaBoost(); state = runner.state }
        // 0022 稽古拘束の週送り減算（UI層・golden非対象・freeze と同型）。撮影を受けた週は稽古がロックされ、
        // 週が明けて1減る＝設定週（＝撮影を受けたその週）だけ稽古不可。
        if state.preoccupiedWeeks > 0 { runner.tickPreoccupied(); state = runner.state }
        saveNow()
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

    /// action で稼ぐ「粒」の差分（同色ロック粒の増分・乱数非消費・純関数）。稽古カードの「+N粒」プレビュー用。
    /// previewState と同型で state のコピーに applyTraining を適用し state[bank: a] の before/after 差分を返す。
    /// 会計移設で稽古は能力を直接伸ばさず粒を稼ぐ＝現行の previewGains（能力差分）は0になるため、稼ぎの手応えはこちらで出す。
    /// ρ=0なので同色バンクのみ増える（共通枠は発行されない）。RNG非消費＝golden不変。
    func previewGrainGains(_ action: WeekAction, offer: OfferSpec? = nil) -> [(ability: Ability, amount: Double)] {
        let after = previewState(action, offer: offer)
        return Ability.allCases.compactMap { a in
            let d = after[bank: a] - state[bank: a]
            return d > 0.001 ? (a, d) : nil
        }
    }

    // MARK: 割り振り（経験点残高→能力。docs/exp_abilityup_impl_reply_v0.md）
    //
    // ⚠️ previewState/previewGains と同じ規律: RandomSource を一切触らない＝乱数を消費しない＝golden不変。
    //    確定は runner.applyAllocation（applyEventEffects と同じ「権威stateへの適用」経路）——
    //    session.state だけを書き換えると次の pump() で runner.state に上書きされて消えるため。

    /// AllocationView のプレビュー: タップ列を今の state のコピーに再生した後の状態（純関数・乱数非消費）。
    /// 確定（allocate）と同じ GameEngine.pourStep を同じ順で回す＝見積もりと結果が構造的に一致する
    func previewAllocation(_ taps: [Ability]) -> GameState {
        var copy = state
        for a in taps { GameEngine.pourStep(a, to: &copy, config: config) }
        return copy
    }

    /// 割り振りの確定（RNG非消費・golden不変）。taps は AllocationView のタップ順。
    /// 戻り値=能力ごとの実効伸び（リビール確認・デバッグ用。表示は View 側が before/after から丸め差分で出す）
    @discardableResult
    func allocate(_ taps: [Ability]) -> [(ability: Ability, amount: Double)] {
        let before = state
        runner.applyAllocation(taps)
        state = runner.state
        saveNow()
        return Ability.allCases.compactMap { a in
            let d = state[a] - before[a]
            return d > 0.001 ? (a, d) : nil
        }
    }

    /// おすすめ注ぎ＝GameCore正典の単一台本（golden台本・simボットと同じ recommendedPlan）を返す。
    /// View はこれを「仮置き」に展開するだけで、確定はプレイヤーの「注ぐ」タップ
    func recommendedAllocation() -> [Ability] {
        GameEngine.recommendedPlan(state: state, config: config)
    }

    /// AllocationView の「つぎの+1 ●n」: probe 状態から表示整数（Int(v.rounded())）を1つ上げるのに要する
    /// allocationStep 段の回数 n。**既存 pourStep を回して数えるだけ**＝式の複製ゼロ・「見積もり=確定の単一化」
    /// の家風を維持（§3-2）。RandomSource 非消費＝golden不変（View/Session層の表示専用純関数・tools鏡像不要）。
    /// nil＝この+1に届かない（粒切れ/器切れ/上限/逓減で端数死）。probe には previewAllocation(taps) を渡す。
    func costOfNextStep(_ a: Ability, in probe: GameState) -> Int? {
        var s = probe
        let base = Int(s[a].rounded())
        var n = 0
        while n < 60 {   // 暴走ガード【仮】。1年の粒総量では十数段が上限の見込み
            let gain = GameEngine.pourStep(a, to: &s, config: config)
            if gain <= GameEngine.pourEpsilon { return nil }   // 届かない（残高/器/上限）
            n += 1
            if Int(s[a].rounded()) >= base + 1 { return n }     // 表示整数が+1に到達
        }
        return nil
    }

    // MARK: 選択肢イベント（正典: proposals/0024実装ブリーフ・0010/0017/0018/0019）
    //
    // ⚠️ 確定発火（フラグを見て点火・抽選しない）＋確定効果（runner.applyEventEffects＝RNG非消費）のみ。
    //    抽選プール化・効果内の乱数ロールは入れない（0024確定・0010のA内部判定は本編送り＝MVP対象外）。

    /// 週頭（.freeAction 確定直後）に確定発火を判定。優先順位: justLost > 連敗の底(一発) >
    /// 通過の分かれ道(余白+体力ガード) > 前夜(格の高い大会のみ) > 結成初期の他人行儀(一発) >
    /// ツーカー帯初到達(一発・キャリア1回)。複数回呼ばれても保留が有れば再評価しない。
    private func evaluateChoiceEventFire() {
        guard pendingChoiceEvent == nil else { return }
        if justLostStage {
            pendingChoiceEvent = .justLostRehearsal
        } else if lossStreak >= 3, !styleTalkDone {
            pendingChoiceEvent = .styleTalk
        } else if justPassedStage, let m = nextMilestoneForEvent(), m.week - week >= 3, state.stamina >= 15 {
            pendingChoiceEvent = .justPassedFork
        } else if let m = nextMilestoneForEvent(), m.week - week == 1, m.highStakes {
            pendingChoiceEvent = .preTournamentEve
        } else if !didFireEarlyFormality, week < 15, state.compat <= 7 {
            pendingChoiceEvent = .earlyFormality
        } else if !didFireTsuukaChoice, state.compat >= 15 {
            pendingChoiceEvent = .tsuukaBreak
        } else if !didFireNamelessSlip, state.compat >= 8,
                  let m = nextMilestoneForEvent(), (2...5).contains(m.week - week) {
            // 0028: 相性8以上・大会2-5週前（詰め期・前夜ではない）。選択がないので発火時にフラグを立てる。
            pendingChoiceEvent = .namelessReservationSlip
            didFireNamelessSlip = true
        } else if !didFireTaniguchiJob, state.money < 100_000, state.compat >= 8, noTournamentWithin3Weeks() {
            // 0012: 金欠×相性8+×今後3週に大会なし（3週凍結が直近大会の追い込みを食い潰さない・proposalレッドA-1）。
            pendingChoiceEvent = .taniguchiShortJob
            didFireTaniguchiJob = true
        } else {
            // 確定発火なし → 週次ランダム抽選（UI乱数・golden非干渉）。1週1回だけ引く。
            rollWeeklyRandomEvent()
        }
    }

    /// 週次ランダムイベントの抽選（UI専用乱数＝runner の乱数列に非干渉＝golden不変）。
    /// 確定発火が無い自由週にのみ来る。1週1回・総量予算(weeklyEventCap)・1回制(firedWeeklyEvents)で希釈を防ぐ。
    private func rollWeeklyRandomEvent() {
        guard week != lastEventRollWeek else { return }   // 同一週の pump 複数回呼びで二重に引かない
        lastEventRollWeek = week
        guard weeklyEventFiredCount < config.weeklyEventCap else { return }
        guard uiEventRng.nextUniform() < config.weeklyEventRate else { return }   // 12%【仮】で抽選成立
        // 発火帯に入っていて未発火の候補（proposals 各票のゲート）を集める
        let candidates = ChoiceEventKind.allCases.filter {
            $0.isWeeklyRandom
                && !firedWeeklyEvents.contains($0)
                && ChoiceEventTable.weeklyFireable($0, state: state, week: week, config: config)
                && weeklyExtraGate($0)
        }
        guard !candidates.isEmpty else { return }
        let idx = min(Int(uiEventRng.nextUniform() * Double(candidates.count)), candidates.count - 1)
        let kind = candidates[idx]
        pendingChoiceEvent = kind
        firedWeeklyEvents.insert(kind)
        weeklyEventFiredCount += 1
    }

    /// 週頭の掛け合い抽選（UI専用乱数・golden非干渉）。イベントが立った週は譲る（一度に一つの声）。
    /// 頻度はUI定数【仮】: 基礎30%／本番が6週以上先の空白帯（週16-26の中だるみ等）は55%に上げる
    /// ＝§7-B の正規レバー「会話・イベントの差し込み頻度UP」（バランス数値ではない・判定に非干渉）。
    private func rollWeekBanter() {
        guard week != lastBanterRollWeek else { return }
        lastBanterRollWeek = week
        weekBanter = nil
        guard pendingChoiceEvent == nil else { return }
        let farFromStage = nextMilestoneForEvent().map { $0.week - week >= 6 } ?? true
        let rate = farFromStage ? 0.55 : 0.30   // 【仮】UI頻度定数（体感調整はここ・GameConfigに置かない=判定非関与）
        guard uiEventRng.nextUniform() < rate else { return }
        // 中身の選択は salt=週番号の決定的回転（乱数は発火の1drawのみ＝UI列の消費を最小に）。
        weekBanter = DialogueData.banter(band: banterBand(), salt: week)
    }

    /// 掛け合いの帯（innerVoice の優先順位と同じ並び: 連敗 > 金欠 > 通過後 > 大会前 > 空白帯 > 平常）。
    private func banterBand() -> BanterBand {
        if lossStreak >= 2 { return .streak }
        if state.money < 50_000 { return .broke }
        if justPassedStage { return .afterPass }
        if let m = nextMilestoneForEvent(), (1...2).contains(m.week - week) { return .eve }
        if let m = nextMilestoneForEvent(), m.week - week >= 6 { return .lull }
        return .plain
    }

    /// weeklyFireable（GameState+week の純関数）で判定できない、GameSession 固有の状態を要する追加ゲート。
    private func weeklyExtraGate(_ kind: ChoiceEventKind) -> Bool {
        switch kind {
        case .luckyThirdLine:
            // 0029: 連敗していない＋大会が視界（2-4週前）＝好調が"負けの反動"に読まれない帯（lossStreak/次マイルストンを要する）
            guard lossStreak == 0, let m = nextMilestoneForEvent() else { return false }
            return (2...4).contains(m.week - week)
        case .regularEmployment:
            return jobCount >= 8   // 0023: バイトを重ねた金欠中盤【仮】。UI層カウンタ
        default:
            return true
        }
    }

    /// 次に来る本番の週と「格が高いか」（0010: 新人賞級・準決・GP決勝＝高格／GP1-3回戦・準々決勝＝低格）。
    /// AllocationView.nextStage() と同型の走査（View層の既存実装には触れず、GameSession側にも1つ持つ）。
    private func nextMilestoneForEvent() -> (week: Int, highStakes: Bool)? {
        let cal = config.calendar
        var ms: [(week: Int, highStakes: Bool)] = []
        for (i, r) in cal.gpRounds.enumerated() {
            ms.append((r.week, i == cal.gpRounds.count - 1))   // 最後の回戦（準決勝）だけ高格
        }
        ms.append((cal.gpFinalWeek, true))   // GP決勝
        for t in cal.tournaments where t.isEligible(year: year, state: state) {
            ms.append((t.week, true))        // 道中大会（新人賞等）は全て高格
        }
        return ms.filter { $0.week >= week }.min { $0.week < $1.week }
    }

    /// 今後3週以内に本番（大会/GP/決勝）が無いか（0012の発火ゲート＝3週凍結が追い込みを食い潰さない条件）。
    private func noTournamentWithin3Weeks() -> Bool {
        guard let m = nextMilestoneForEvent() else { return true }
        return m.week - week > 3
    }

    /// 選択肢イベントの選択を確定（RNG非消費・golden不変）。発火元フラグを対称に失効させる。
    /// pendingChoiceEvent はここでは落とさない＝選択後の会話をオーバーレイに見せ切ってから
    /// dismissChoiceEvent() で閉じる（先に落とすと .fullScreenCover(item:) が即座に閉じてしまう）。
    func applyEventChoice(_ choiceID: String) {
        guard let kind = pendingChoiceEvent else { return }
        let choices = ChoiceEventTable.choices(for: kind, config: config)
        guard let choice = choices.first(where: { $0.id == choiceID }), choice.gate(state) else { return }
        runner.applyEventEffects(choice.effects)
        state = runner.state
        switch kind {
        case .justLostRehearsal: justLostStage = false
        case .styleTalk: styleTalkDone = true
        case .justPassedFork: justPassedStage = false
        case .preTournamentEve: break   // 週送りで weeksLeft==1 の条件が自然に外れる＝追加フラグ不要
        case .tsuukaBreak: didFireTsuukaChoice = true
        case .earlyFormality: didFireEarlyFormality = true
        case .brokeDrinkingInvite, .senpaiMeishi, .peerFoldedChair, .lineupTop, .greenroomSilentTen,
             .lastTrainReview, .luckyThirdLine, .regularEmployment, .wroteOneTonight, .photoShootOffer:
            break   // 週次イベントは発火時に firedWeeklyEvents で1回制管理済み
        case .namelessReservationSlip:
            break   // 選択肢なしフレーバー＝発火時に didFireNamelessSlip 済み（applyEventChoice は実際には呼ばれない）
        case .taniguchiShortJob:
            break   // 確定発火＝発火時に didFireTaniguchiJob 済み（A の compatFreeze は EventEffect が適用）
        }
        saveNow()
    }

    /// 選択後の会話を見終えてオーバーレイを閉じる（UI側の「閉じる」タップから呼ぶ）
    func dismissChoiceEvent() {
        pendingChoiceEvent = nil
        saveNow()   // 閉じた状態を保存（復帰時に選択済みイベントが再表示されないように）
    }

    /// 現在保留中のイベントで選択可能な選択肢（gate通過分のみ・UI用）
    func availableEventChoices() -> [ChoiceEventChoice] {
        guard let kind = pendingChoiceEvent else { return [] }
        return ChoiceEventTable.choices(for: kind, config: config).filter { $0.gate(state) }
    }

    // MARK: 持ちネタ（正典: docs/neta_system_redesign_v2.md Phase 0）
    //
    // ⚠️ このセクションは runner.applyNeta*（RandomSource 非依存の純適用・WeekRunner.swift）だけを呼ぶ＝
    //    golden不変。「反応で磨く（当たり外れ）」「選択が勝敗に効く」はスコア/乱数を要する＝Phase 1（規律A・別便）。
    //    ここは「作る・貯める・選ぶ器」まで（v2 §0-補）。

    /// アクティブな持ちネタ（少数・磨き対象＝鉄板枠）
    var activeNetas: [Neta] { state.netas }
    /// 保管庫（多数・年跨ぎ資産・いつでも呼び戻せる）
    var archivedNetas: [Neta] { state.archivedNetas }
    /// 大会に「今かける」ネタ（1本目）
    var selectedNeta: Neta? { state.netas.first { $0.id == state.selectedNetaID } }
    /// 決勝の2本目
    var selectedNeta2: Neta? { state.netas.first { $0.id == state.selectedNetaID2 } }

    /// `ネタ作り`/`ネタ見せ会`/`フリーライブ` の後段フック。resolveAction の直後に呼ぶ（choose() 内）。
    /// 3秒動線を壊さない（v2 §3-1）＝ここではシートを挟まず自動で「今作業中のネタ」を決める:
    ///  - ネタ作り: 選択中ネタがアクティブにあれば改稿。無ければ枠が空いていれば自動生成して選択。
    ///    枠が満杯なら直近のアクティブネタ（末尾）を改稿（誤操作より手応え優先の既定・【仮】）。
    ///  - ネタ見せ会/フリーライブ: 選択中ネタがあればそれを、無ければ直近のアクティブネタを客前にかける。
    ///    アクティブネタが1本も無ければ何もしない（まだ書いた ネタが無い＝最初の ネタ作り が先）。
    private func applyNetaWork(for action: WeekAction) {
        guard case .train(let t) = action, t == .ネタ作り || t == .ネタ見せ会 || t == .フリーライブ else { return }
        switch t {
        case .ネタ作り:
            if let id = state.selectedNetaID, state.netas.contains(where: { $0.id == id }) {
                runner.applyNetaRevise(id: id)
            } else if state.netas.count < config.netaActiveSlots {
                let kata = NetaCatalog.autoKata(forID: state.nextNetaID)
                let id = runner.applyNetaCreate(kata: kata, lengthFit: NetaCatalog.defaultLengthFit(for: kata),
                                                 name: NetaCatalog.autoName(forID: state.nextNetaID))
                runner.applyNetaSelect(id: id)
            } else if let last = state.netas.last {
                runner.applyNetaRevise(id: last.id)
            }
        case .ネタ見せ会, .フリーライブ:
            let targetID = (state.selectedNetaID.flatMap { id in state.netas.contains { $0.id == id } ? id : nil })
                ?? state.netas.last?.id
            if let id = targetID {
                let wasDown = state.netas.first { $0.id == id }?.isDown ?? true
                runner.applyNetaLive(id: id, hard: t == .ネタ見せ会)
                let nowDown = runner.state.netas.first { $0.id == id }?.isDown ?? false
                if !wasDown, nowDown {   // おろし（初披露）の瞬間だけ一言（v2 §3-2補2）
                    justOroshiNeta = (id, DialogueData.netaOroshi(salt: id &+ week))
                }
            }
        default: break
        }
        state = runner.state
    }

    /// 「今かけるネタ」を選ぶ（大会入口・持ちネタ帳から。保管庫のネタでも可＝自動でアクティブへ呼び戻さない・
    /// 呼び戻しは recallNeta を先に呼ぶ設計。ここはアクティブ枠内のIDのみ有効）。
    func selectNeta(_ id: Int?) {
        runner.applyNetaSelect(id: id)
        state = runner.state
        saveNow()
    }

    /// 決勝の2本目を選ぶ（v2 §4-2）
    func selectNeta2(_ id: Int?) {
        runner.applyNetaSelect2(id: id)
        state = runner.state
        saveNow()
    }

    /// 型の組み替え（大改稿で1度・v2 §3-1補）
    func changeNetaKata(_ id: Int, to kata: NetaKata) {
        runner.applyNetaChangeKata(id: id, to: kata)
        state = runner.state
        saveNow()
    }

    /// 改名（自動命名の上書き・v2 §9決点3）
    func renameNeta(_ id: Int, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        runner.applyNetaRename(id: id, to: trimmed)
        state = runner.state
        saveNow()
    }

    /// アクティブ枠→保管庫（削除でも封印でもない・いつでも呼び戻せる・v2 §2-2）
    func retireNeta(_ id: Int) {
        runner.applyNetaRetire(id: id)
        state = runner.state
        saveNow()
    }

    /// 保管庫→アクティブ枠（古いネタの再演・v2 §2-2/§4-2）。枠が満杯なら何もしない（先に retireNeta で空ける）。
    func recallNeta(_ id: Int) {
        guard state.netas.count < config.netaActiveSlots else { return }
        runner.applyNetaRecall(id: id)
        state = runner.state
        saveNow()
    }

    /// GP回戦・敗者復活・決勝の演出後（入力不要）
    func advanceAuto() {
        phase = runner.resolveAuto()
        pump()
        saveNow()
    }

    /// S3結果画面の「次へ」。結果を閉じて次週へ進める
    func acknowledgeResult() {
        pendingResult = nil
        phase = runner.begin()
        pump()
        saveNow()
    }

    /// 「勝ち版」決勝演出の「次へ」。年末結果（S4）へ
    func acknowledgeWin() {
        winFinale = false
        finished = true
        saveNow()   // finished=true なのでセーブは消える（周回は持ち越さない）
    }

    // MARK: 中断セーブ（proposals/0039＋UI層フラグ拡張）
    //
    // ⚠️ RNG非消費・golden不変（snapshot は読み出しのみ）。保存は UserDefaults 単一キー・1スロット。
    //    GameConfig は保存しない（復元時に毎回新規生成＝バランス値更新が古いセーブに固定化されない）。

    /// 中断セーブの全内容。runner のスナップショットに加え、UI層のイベント進行フラグを持たないと
    /// 復帰後に一発化イベントが再発火する（didFire系/fired集合/uiEventRng が本体）。
    struct SaveData: Codable {
        var runner: WeekRunnerSnapshot<SplitMix64>
        var phase: WeekRunner<SplitMix64>.Phase
        var pendingResult: WeekSummary?
        var log: [String]
        var lossStreak: Int
        var justPassedStage: Bool
        var justLostStage: Bool
        var styleTalkDone: Bool
        var didFireTsuukaChoice: Bool
        var didFireEarlyFormality: Bool
        var didFireNamelessSlip: Bool
        var didFireTaniguchiJob: Bool
        var uiEventRng: SplitMix64
        var firedWeeklyEvents: Set<ChoiceEventKind>
        var weeklyEventFiredCount: Int
        var lastEventRollWeek: Int
        var jobCount: Int
        var pendingChoiceEvent: ChoiceEventKind?
        var weekBanter: [Advice]?
        var lastBanterRollWeek: Int
        var categoryLog: [Int: BandCategory]
        var totalPrize: Int
        var combiName: String
    }

    private static let saveKey = "manzai.save.v1"

    /// 中断セーブを書く。年が終わっていれば逆にセーブを消す（周回は持ち越さない）。
    /// 呼び出しはプレイヤー入力の各確定点（choose/decideTournament/advanceAuto/acknowledge*/allocate/
    /// applyEventChoice/ネタ操作）＋RootView の scenePhase(.background) 保険。init からは呼ばない
    /// （IntroFlow 前のプレースホルダ・セッションがセーブを作らないように）。
    func saveNow() {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if env["MZ_SMOKE"] != nil || env["MZ_UI"] != nil { return }   // QA自動走行で実プレイのセーブを潰さない
        #endif
        guard !finished, !winFinale else {
            UserDefaults.standard.removeObject(forKey: Self.saveKey)
            return
        }
        let save = SaveData(runner: runner.snapshot(), phase: phase, pendingResult: pendingResult,
                            log: log, lossStreak: lossStreak,
                            justPassedStage: justPassedStage, justLostStage: justLostStage,
                            styleTalkDone: styleTalkDone, didFireTsuukaChoice: didFireTsuukaChoice,
                            didFireEarlyFormality: didFireEarlyFormality, didFireNamelessSlip: didFireNamelessSlip,
                            didFireTaniguchiJob: didFireTaniguchiJob, uiEventRng: uiEventRng,
                            firedWeeklyEvents: firedWeeklyEvents, weeklyEventFiredCount: weeklyEventFiredCount,
                            lastEventRollWeek: lastEventRollWeek, jobCount: jobCount,
                            pendingChoiceEvent: pendingChoiceEvent, weekBanter: weekBanter,
                            lastBanterRollWeek: lastBanterRollWeek, categoryLog: categoryLog,
                            totalPrize: totalPrize, combiName: combiName)
        if let data = try? JSONEncoder().encode(save) {
            UserDefaults.standard.set(data, forKey: Self.saveKey)
        }
    }

    /// 起動時のエントリポイント: セーブがあれば復元、無ければ新規（IntroFlow 前のプレースホルダ）。
    static func loadedOrNew(config: GameConfig = GameConfig()) -> GameSession {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let save = try? JSONDecoder().decode(SaveData.self, from: data) {
            return GameSession(restoring: save, config: config)
        }
        return GameSession()
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
                        if r.passed {
                            lossStreak = 0; justPassedStage = true; justLostStage = false
                            styleTalkDone = false   // 0019一発化フラグ: 通過(lossStreak=0)と同一トランザクションでリセット
                        } else {
                            lossStreak += 1; justPassedStage = false; justLostStage = true
                        }
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
                if case .freeAction = phase {
                    evaluateChoiceEventFire()
                    // 掛け合いはイベント抽選の「後」に引く＝イベント出現週のUI乱数再現列を崩さない
                    // （以後の列は banter の消費分だけずれるが UI 層のみ＝golden非対象）。
                    rollWeekBanter()
                }
                break loop
            }
        }
    }

    #if DEBUG
    /// QA用: 選択肢イベントのオーバーレイを強制表示（発火抽選を経ず kind を直接立てる・目視専用）。
    func debugForceEvent(_ kind: ChoiceEventKind) { pendingChoiceEvent = kind }

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

    /// DEBUG: ネタ帳（MZ_UI=neta）の目視用に持ちネタを積んだ開始状態。全状態（鉄板/おろし前/擦り切れ/保管庫）を
    /// 一画面で踏めるよう組む。数値は全て【仮】＝目視の都合だけ（水準確定はPhase 1・sim較正）。
    static func debugNetaState(config: GameConfig = GameConfig()) -> GameState {
        var s = GameState(config: config)
        var teppan = Neta(id: 0, name: "商店街の福引", kata: .伏線回収, lengthFit: [.長尺], bornYear: 1)
        teppan.polish = 88; teppan.buzz = 70; teppan.stageCount = 12; teppan.isDown = true; teppan.exposure = 40
        teppan.record = [NetaStamp(year: 1, stage: "GP2回戦", passed: true), NetaStamp(year: 1, stage: "GP3回戦", passed: true)]

        var fresh = Neta(id: 1, name: "満員電車", kata: .瞬発, lengthFit: [.短尺, .中尺], bornYear: 1)
        fresh.polish = 34   // 未おろし（isDown=false のまま）

        var midway = Neta(id: 2, name: "婚活パーティー", kata: .華先行, lengthFit: [.短尺], bornYear: 1)
        midway.polish = 55; midway.buzz = 42; midway.stageCount = 3; midway.isDown = true

        s.netas = [teppan, fresh, midway]
        s.nextNetaID = 3
        s.selectedNetaID = 0

        var old = Neta(id: 3, name: "終電の二人", kata: .関係性, lengthFit: [.中尺, .長尺], bornYear: -2)   // 3年以上前＝再演対象
        old.polish = 72; old.buzz = 50; old.stageCount = 9; old.isDown = true
        s.archivedNetas = [old]
        return s
    }

    /// DEBUG: 能力を上限近くまで盛った開始状態（数式・乱数は不変・GameStateの初期値だけ変更）。
    /// これで決勝ラインを突破でき、優勝演出を実機で確認できる。
    static func debugMaxedState(config: GameConfig = GameConfig()) -> GameState {
        var s = GameState(config: config)
        s.センス = 115; s.発想 = 115; s.表現 = 115; s.華 = 115; s.メンタル = 115
        s.compat = 19
        return s
    }

    /// DEBUG: 割り振り画面（MZ_UI=allocate）の目視用に経験点残高を積んだ開始状態。
    /// 数値は全て【仮】＝目視の都合だけで置いた値（水準の確定はMac側のsim較正）。
    /// 器（growthBudget）は WeekRunner が年初に year1 の値へ上書きするので、
    /// 「注げる→器が満ちて弾かれる（横ブレ）」までひと続きで目視できる残高にしてある。
    static func debugAllocationState(config: GameConfig = GameConfig()) -> GameState {
        var s = GameState(config: config)
        // 参照系UI再設計の目視用（§6チェックリスト①〜⑦を一画面で踏む）。数値は全て【仮】・ρ=0-honest。
        // 粒総量は年初器(6.0)を超える貯め込み＝「注ぐ→器が満ちて弾かれる」＋器の食い合い⑤まで一続きで目視できる残高。
        s.センス = 43; s.発想 = 24; s.表現 = 78; s.華 = 18; s.メンタル = 35   // センス43→45でC→B跨ぎ④／表現78=高値
        s.expセンス = 12; s.exp発想 = 14; s.exp表現 = 1; s.exp華 = 14; s.expメンタル = 9  // 表現は+1に2粒要るが1粒＝端数③
        s.expネタ = 0; s.exp舞台 = 0   // ρ=0（共通枠は休眠）に忠実＝のこり(bank)と▲活性が食い違わない
        return s   // growthBudget は WeekRunner が年初 year1 値(6.0)へ設定＝上の粒総量がそれを上回る＝食い合いが立つ
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
            let mark = r.isStage ? (r.passed ? "通過" : "敗退") : "休"   // 体調ダウン/療養は合否でなく「休」（監査§1-4-5・Fable13§2）
            let prize = r.prize > 0 ? " +\(r.prize / 10000)万" : ""
            return "\(r.name) \(mark)\(prize)"
        }
        return "第\(s.week)週: " + parts.joined(separator: " / ")
    }
}
