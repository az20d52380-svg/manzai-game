// GameSession.swift
// ui_design_v0.md §5 の ViewModel。WeekRunner（GameCore）を保持し、Phase に応じて人の入力を待つ。
// ロジックは一切持たず、WeekRunner を駆動して結果を @Observable な表示用プロパティに写すだけ。
// 複数年キャリア（core_loop_reconsideration_v0 §7・2026-10-10）: 年末（S6）→ startNextYear() で翌年の WeekRunner を
// GameCareer.runCareer と同じ形（状態と乱数列を持ち越し・前年準々決勝以上で1回戦シード）で立てる。
// 区切り＝優勝（勇退）／夜逃げ／結成 config.careerYears 年目の年末。

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
    private(set) var lastGrainGains: [(currency: ExpCurrency, amount: Double)] = []
    /// 直前の行動でネタに入ったもの（Beat2 獲得バースト用・表示専用・golden非対象）。
    /// isNew=新しく書いた／それ以外は既存ネタの完成度の伸び（polish）。何も無ければ nil。
    private(set) var lastNetaGain: (isNew: Bool, polish: Double)?
    /// 直前の行動での所持金/体力の増減（Beat2 獲得バースト用・表示専用）。週末の生活費も含む「この週の収支」。
    private(set) var lastMoneyDelta = 0   // 行動による差のみ（生活費は lastLivingPaid に分けた）
    /// この週の週末に引かれた生活費（引かれない週は 0・表示専用）。
    private(set) var lastLivingPaid = 0
    private(set) var lastStaminaDelta = 0
    /// Beat2 獲得チップ用の知名度の増分（表示専用・golden非対象）。舞台に立つ週の「押した→残った」を見せる（G1）
    private(set) var lastFameDelta: Double = 0
    /// 大会結果画面の知名度の増分（decideTournament 経由・表示専用・golden非対象）
    private(set) var lastResultFameDelta: Double = 0
    /// 上記の増減が属する週。View は lastDeltaWeek == week の時だけバーストを出す＝大会画面を
    /// 挟んで戻った時に古い増減が再生される事故を防ぐ（表示ゲートのみ・golden非対象）。
    private(set) var lastDeltaWeek = -1
    /// 連敗数（大会・GPで敗退が続いた回数。心の声「何が足りないんだ…」用）
    private(set) var lossStreak = 0
    /// §97 体調ダウンの知らせ待ち（表示専用）。倒れた週を pump が見つけたら、療養の週数をここに積む＝週メインが1回だけ知らせる
    private(set) var injuryNoticeWeeks = 0
    /// 「書く対象」のネタ（勝負ネタ selectedNetaID とは別。nil＝指定なし＝勝負ネタを磨く＝旧セーブと同じ動き）。アプリ層のみ・GameCore不変
    private(set) var writeNetaID: Int? = nil
    /// 「新しく書く」を選んだ印（次にネタを書く週に新ネタを作る）。セーブしない（再起動で勝負ネタの磨きに戻るだけ）
    private(set) var writeNewNeta = false
    func clearInjuryNotice() { injuryNoticeWeeks = 0 }
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
    /// 0017「負けた日の稽古場」/0018「通った日の分かれ道」/0010「前夜の一本」の一発化（監査D-01）。
    /// 以前は条件成立のたびに同文で再発していた。2回目以降の負け/通過は心の声プールへ落ちる。
    private(set) var didFireLostRehearsal = false
    private(set) var didFirePassFork = false
    private(set) var didFireEve = false
    /// 0050「会わない週が続いた」（途中解散の予告）を出したか。キャリア1回（docs/endings_spec_v1 §2-3）
    private(set) var didFireRiftWarn = false
    /// 予告で選んだもの："A"＝向き合った／"B"＝流した／nil＝予告なし（#2 解散の一行と図鑑に使う・表示専用・golden非対象）
    private(set) var riftWarnChoice: String?
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
    /// 選んで効果を適用済み（選択後の会話を見せている間）。この間は保存に保留イベントを入れない＝落として再起動しても選び直して二重にかからない（code_review_2026-10-19c §1-1）
    private var choiceApplied = false
    /// §102 週末に来た先輩の誘いを次の自由週の頭に札で出すための待ち（メモリのみ。アプリを落とすと流れる＝軽い誘いなので許容）と、行った時に発想が付くか
    private var inviteWaiting = false
    private var inviteIdea = false
    /// 週頭の掛け合い（俺⇄谷口の短い会話・タップ送り）。nil=この週は独白。行動すると失効。
    /// 発火はUI専用乱数（uiEventRng）＝runnerの乱数列に非干渉＝golden不変。イベント発火週は譲る。
    private(set) var weekBanter: [Advice]?
    /// 場面ごとの「このキャリアで出した文の番号」（古い順・表示専用・乱数非消費・golden非対象）。
    /// 年が替わっても消さない＝同じキャリアでは使った文を避け、プールが尽きたら最も古い物から使い回す。セーブに載せる（Optional）。
    @ObservationIgnored private var usedPicks: [String: [Int]] = [:]
    /// 同じ key（週など）での再描画では同じ番号を返すための記憶（body の再評価で記録が進まないように）。
    @ObservationIgnored private var stablePicks: [String: (key: Int, idx: Int)] = [:]
    /// このキャリアで観客の声（客席アンケート）に出した文（古い順）。セーブに載せる（Optional）。
    @ObservationIgnored private var usedFanLines: [String] = []
    @ObservationIgnored private var fanVoiceCache: (key: Int, lines: [String])?
    /// このキャリアで一度出した固定の一文（決勝の最後の一行 等）の印。セーブに載せる（Optional）。
    @ObservationIgnored private var shownOnce: Set<String> = []
    /// 使った文を避けた番号を返す。key が同じ間は同じ番号（View の再評価対策）。
    func pickIndex(scene: String, count: Int, salt: Int, key: Int? = nil) -> Int {
        guard count > 0 else { return 0 }
        if let key, let s = stablePicks[scene], s.key == key, s.idx < count { return s.idx }
        var used = (usedPicks[scene] ?? []).filter { $0 < count }
        let idx = DialogueData.indexAvoidingUsed(count: count, salt: salt, used: used)
        used.removeAll { $0 == idx }
        used.append(idx)
        usedPicks[scene] = used
        if let key { stablePicks[scene] = (key, idx) }
        return idx
    }
    /// 観客の声を、このキャリアで使っていない物から選んで返す。同じ key の間は同じ並び（View の再評価対策）。
    func fanVoices(key: Int, make: (_ used: [String]) -> [String]) -> [String] {
        if let c = fanVoiceCache, c.key == key { return c.lines }
        let lines = make(usedFanLines)
        fanVoiceCache = (key, lines)
        for l in lines { usedFanLines.removeAll { $0 == l }; usedFanLines.append(l) }
        if usedFanLines.count > 600 { usedFanLines.removeFirst(usedFanLines.count - 600) }
        return lines
    }
    /// 固定の一文を、このキャリアで初めて出す時だけ true（出した印を付ける）。同じ id の再描画では同じ答え。
    func firstShow(_ id: String, key: Int) -> Bool {
        let tag = "\(id)#\(key)"
        if shownOnce.contains(tag) { return true }          // 同じ場面の再描画
        if shownOnce.contains(where: { $0.hasPrefix("\(id)#") }) { return false }
        shownOnce.insert(tag)
        return true
    }
    /// pickIndex を DialogueData.Picker の形にしたもの。
    func picker(key: Int? = nil) -> DialogueData.Picker {
        { [self] scene, count, salt in pickIndex(scene: scene, count: count, salt: salt, key: key) }
    }
    /// 掛け合いの1週1回抽選ガード（pump 複数回呼びでの二重抽選＝UI乱数の余分消費を防ぐ・イベント抽選と同型）
    private var lastBanterRollWeek = -1
    /// 優勝が確定した瞬間。ここが true の間は「勝ち版」決勝演出を出す（S4ボードの前）
    private(set) var winFinale = false
    /// S6 行動内訳帯用: 週インデックス→その週のカテゴリ（UI層の記録のみ・golden非対象）
    private(set) var categoryLog: [Int: BandCategory] = [:]
    /// 相方と過ごす／ネタ合わせをしていない自由週の連続数（週メインの一行案内用・表示専用・golden非対象・セーブはOptional）
    private(set) var weeksWithoutPartner = 0
    /// S6 年計用: その年の獲得賞金合計（UI層の記録のみ・golden非対象）
    private(set) var totalPrize = 0
    /// 進行中に「この年をやめてタイトルへ」が選ばれた（RootView がタイトルへ戻す・監査G-04）
    private(set) var abandoned = false
    /// 観客版決勝を観ている最中（監査H-01: 決勝に進めなかった年の第47週・RootView が切り替える）
    private(set) var watchingFinal = false
    /// 今年の観客版決勝を観終えたか（1年1回）
    private(set) var didWatchFinal = false
    /// 借金の知らせを出した最も深い段（0=未・1=初マイナス・2=−50万割れ・3=−80万割れ）。1キャリアで各段1回（表示のみ・golden非対象）
    private(set) var debtWarnTier = 0
    /// 0050 の後の「すれ違いが減る」知らせを出したか（キャリア1回・表示のみ）
    private(set) var didShowRiftHint = false
    /// 今年の決勝のスコアとラインの差（score − 実効ライン）。決勝演出の順位・票を内部の結果に沿って合成するため
    /// （正＝優勝。0に近いほど接戦）。表示専用・golden非対象
    private(set) var lastFinalMargin: Double?

    let config: GameConfig
    /// 結成何年目か（WeekRunner が持つ値をそのまま読む＝セーブ・復元も runner のスナップショットに乗る）
    var year: Int { runner.year }
    /// この年の4月（年初）の状態。年末の「この1年で育ったもの」とレーダーの4月線の基準（表示専用・golden非対象）
    private(set) var yearStartState: GameState
    /// 年初の状態が実際に分かっているか。旧セーブ(yearStartState なし・2年目以降)の復元後は false＝「育ったもの」の差分を出さない（A-5）
    private(set) var hasYearStart = true
    /// 1年＝1行の記録（年末の「これまで」と勇退エンディングの年表に使う・表示専用・golden非対象）
    private(set) var yearHistory: [YearRecord] = []
    let combiName: String              // S1で入力（表示専用・golden非対象）
    /// 自分の名前・相方の名前（S1で入力・nil/空＝俺・谷口のまま・表示専用・golden非対象）
    let myName: String?
    let partnerName: String?
    /// コンビの形（旧セーブ＝男コンビ・表示専用・golden非対象）
    let comboKind: ComboKind
    /// 相方との出会い方（導入の回想の型・旧セーブ＝①高校の同級生・表示専用・golden非対象）
    let meetingKind: MeetingKind
    /// 中断セーブから復元されたセッションか（RootView が IntroFlow をスキップする判定に使う）
    let isRestored: Bool

    // MARK: 進行の実体（WeekRunner が週処理と乱数消費の正典を持つ）
    private var runner: WeekRunner<SplitMix64>

    init(seed: UInt64 = 424242, config: GameConfig = GameConfig(), startState: GameState? = nil,
         combiName: String = "あなたのコンビ", myName: String? = nil, partnerName: String? = nil,
         comboKind: ComboKind = .maleMale, meetingKind: MeetingKind = .highSchool) {
        // 実ゲームも自動注ぎ（A「削る」スライス1・fun_uiux_overhaul_v0 §5-1 A列）＝稽古で稼いだ粒は行動直後に
        // recommendedPlan で全量注がれ、のばす画面（AllocationView）は通らない。GameConfig 既定値（true）と同じ＝
        // sim/golden の前提と実ゲームが一致する（golden 不変）。明示しておくのは、既定値が将来変わっても実ゲームを固定するため。
        var cfg = config
        // 2026-10-12：手動の能力アップを戻す（オーナー判断 2026-10-10 core_loop_reconsideration_v0 ②・パワプロ式4ボタン）。
        // 経験点は貯まり、週メインの「能力アップ」（AllocationView）で振る。おすすめ＝今までの自動注ぎと同じ1関数。golden は既定 true のまま。
        cfg.autoPourAllocation = false
        self.config = cfg
        var combiName = combiName
        #if DEBUG
        if let c = ProcessInfo.processInfo.environment["MZ_COMBI"], !c.isEmpty { combiName = c }   // 目視用: 長いコンビ名の検証
        #endif
        self.combiName = combiName
        var myName = myName, partnerName = partnerName
        #if DEBUG
        // 目視用: MZ_NAMES="自分名,相方名"（どちらか空でも可）
        if let v = ProcessInfo.processInfo.environment["MZ_NAMES"] {
            let p = v.components(separatedBy: ",")
            myName = p.first.flatMap { $0.isEmpty ? nil : $0 }
            partnerName = p.count > 1 && !p[1].isEmpty ? p[1] : nil
        }
        #endif
        self.myName = myName
        self.partnerName = partnerName
        #if DEBUG
        var comboKind = comboKind
        if let k = ProcessInfo.processInfo.environment["MZ_KIND"].flatMap({ ComboKind(rawValue: $0) }) { comboKind = k }   // 目視用: MZ_KIND=femaleFemale 等
        #endif
        self.comboKind = comboKind
        self.meetingKind = meetingKind
        Names.set(me: myName, partner: partnerName)
        Names.setKind(comboKind)
        self.isRestored = false
        // 週次イベント抽選用の UI 乱数を seed から導出（runner の乱数列とは別シード＝独立列＝golden非干渉）。
        self.uiEventRng = SplitMix64(seed: seed &+ 0x9E3779B97F4A7C15)
        let start = startState ?? GameState(config: cfg)
        self.state = start
        var r = WeekRunner(state: start, year: 1, config: cfg, rng: SplitMix64(seed: seed), inviteSeed: seed)
        self.yearStartState = r.state   // 年初処理（体力全回復・成長予算）後の4月の状態
        let firstPhase = r.begin()   // r を消費してから確定させる（値型なので順序が重要）
        self.runner = r
        self.phase = firstPhase
        pump()
    }

    /// 中断セーブからの復元（0039）。年初処理は走らせず、保存時点の位相・UI層フラグをそのまま書き戻す。
    /// config は毎回新規生成して注入（バランス値は永続化しない＝更新後の値で続きが進む）。
    init(restoring save: SaveData, config: GameConfig = GameConfig()) {
        var cfg = config
        cfg.autoPourAllocation = false  // 新規と同じ（上の init の注記・2026-10-12 手動へ戻す）
        self.config = cfg
        self.combiName = save.combiName
        self.myName = save.myName
        self.partnerName = save.partnerName
        self.comboKind = ComboKind.from(save.comboKind)
        self.meetingKind = MeetingKind.from(save.meetingKind)
        Names.set(me: save.myName, partner: save.partnerName)
        Names.setKind(self.comboKind)
        self.isRestored = true
        self.uiEventRng = save.uiEventRng
        let restoredRunner = WeekRunner(restoring: save.runner, config: cfg)
        self.runner = restoredRunner
        self.state = save.runner.state
        // 段の種類が同じなら、中身（大会・オファー・回戦名）は runner が新しい config から取り直した物を使う
        // （保存時の古い値が画面に出て、実際に効く値と食い違っていた＝code_review_2026-10-25e §3-3）
        if let now = restoredRunner.restoredPhase, Self.sameStep(save.phase, now) { self.phase = now } else { self.phase = save.phase }
        self.week = save.runner.week
        // 複数年（v3）: 旧セーブ（1年完結時代）には無い＝1年目の新規と同じ基準に落とす
        self.yearStartState = save.yearStartState ?? GameState(config: cfg)
        self.hasYearStart = save.yearStartState != nil || save.runner.year <= 1
        // A-5: 復元で空になる決勝の点差は、保存された週内結果から引き直す（986行付近と同じ手）
        self.lastFinalMargin = save.runner.weekResults.last(where: { $0.name == "GP決勝" })?.margin
        self.yearHistory = save.yearHistory ?? []
        if case .yearDone(let o) = save.phase {
            // 年末の画面（S6）で中断した＝翌年へ進む前。年末の結果をそのまま出し直す
            self.outcome = o
            if o.champion {
                self.winFinale = true      // A-3: 勝利演出の途中で閉じた＝演出から出し直す（「次へ」で S4）
            } else {
                self.finished = true
            }
        }
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
        self.didFireLostRehearsal = save.didFireLostRehearsal ?? false
        self.didFirePassFork = save.didFirePassFork ?? false
        self.didFireEve = save.didFireEve ?? false
        self.riftWarnChoice = save.riftWarnChoice
        // 予告を出した扱いでも、選んでおらず保留にも残っていない＝見ないまま消えた（旧版の「年末へ」）→ 未発火に戻して次の週頭に出す
        let firedRaw = save.didFireRiftWarn ?? false
        self.didFireRiftWarn = (firedRaw && save.riftWarnChoice == nil && save.pendingChoiceEvent != .riftWarning
                                && save.runner.state.riftWarned == true) ? false : firedRaw
        self.didWatchFinal = save.didWatchFinal ?? false
        self.debtWarnTier = save.debtWarnTier ?? 0
        self.didShowRiftHint = save.didShowRiftHint ?? false
        self.usedPicks = save.usedPicks ?? [:]
        self.usedFanLines = save.usedFanLines ?? []
        self.shownOnce = Set(save.shownOnce ?? [])
        self.weeksWithoutPartner = save.weeksWithoutPartner ?? 0
        self.injuryNoticeWeeks = save.injuryNoticeWeeks ?? 0
        self.writeNetaID = save.writeNetaID   // 旧セーブ＝nil＝勝負ネタを書く対象にも使う
        checkSpectatorFinal()
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

    /// 2つの段が同じ種類で、中身を config から取り直せる段か（大会の決断・自由週・回戦）。
    /// weekDone／yearDone は保存した中身のまま（週末の誘いの解決などで runner の状態と違いうる）
    static func sameStep(_ a: WeekRunner<SplitMix64>.Phase, _ b: WeekRunner<SplitMix64>.Phase) -> Bool {
        switch (a, b) {
        case (.tournamentDecision, .tournamentDecision), (.freeAction, .freeAction), (.gpRound, .gpRound): return true
        default: return false
        }
    }

    // MARK: UI からの入力（Phase 別）

    /// 大会週の回答（travel=nil は見送り）
    func decideTournament(_ travel: Travel?) {
        guard case .tournamentDecision = phase else { return }   // 二度押し・別の段からの呼び出しは無視（懸念の台帳 L37）
        let fameBefore = state.fame
        phase = runner.resolveTournament(travel: travel)
        pump()
        lastResultFameDelta = state.fame - fameBefore   // 表示専用（大会結果画面の「知名度 +n」札）
        saveNow()
    }

    /// 自由行動週の回答
    func choose(_ action: WeekAction) {
        guard case .freeAction = phase else { return }   // 二度押し・別の段からの呼び出しは無視（懸念の台帳 L37）
        let before = state
        let actedWeek = week   // pump 後に week が進むので、生活費の判定は行動した週で行う
        var action = action
        // 0022 稽古拘束（撮られる仕事）: その週は撮影で稽古枠が埋まる＝稽古を選んでも自動休養化（UI層・golden非経路）。
        // WeekMainView が稽古カードをグレーにするので通常ここには来ないが、二重の安全網（谷口の体力ゲートと同型）。
        if state.preoccupiedWeeks > 0, case .train = action { action = .rest(.完全休養) }
        lastAction = action
        let prevWithoutPartner = weeksWithoutPartner
        switch action {   // 週メインの一行案内用（表示専用）
        case .train(.ネタ合わせ), .rest(.相方と過ごす): weeksWithoutPartner = 0
        default: weeksWithoutPartner += 1
        }
        categoryLog[week] = BandCategory(action)   // S6 行動内訳帯（この自由週のカテゴリ）
        if case .job = action { jobCount += 1 }     // 0023 発火条件用のバイト実行回数（UI層・golden非対象）
        justPassedStage = false   // 行動したら「先週通過」の余韻は失効
        justLostStage = false     // 「負けた翌週」の一言も行動で失効（justPassedと対称）
        justOroshiNeta = nil      // ネタおろしの一言も行動で失効（justPassedと同型）
        weekBanter = nil          // 週頭の掛け合いも行動で失効（次週の抽選は pump 側）
        phase = runner.resolveAction(action)
        // 練習が休みに差し替わった週（体力ゲート・体調ダウン・お金不足）は、日程の印も「回復」で残す（稽古の印が付いていた）
        if case .train = action, runner.lastTrainingDone == nil { categoryLog[week] = .kaifuku }
        if case .train(.ネタ合わせ) = action, runner.lastTrainingDone == nil { weeksWithoutPartner = prevWithoutPartner + 1 }   // 休みに差し替わった週は相方と合わせていない（code_review_2026-10-19j §3）
        applyNetaWork(for: action)   // ネタ作り/ネタ見せ会/フリーライブの後段フック（RNG非消費・golden不変・v2 §3）
        pump()
        lastGains = Ability.allCases.compactMap { a in
            let d = state[a] - before[a]
            return d > 0.001 ? (a, d) : nil
        }
        lastCompatGain = state.compat - before.compat
        // 正典v3: 稽古は能力を直接伸ばさず経験点通貨を稼ぐ＝この週に入った通貨の増分（§1-3 受け取りの一拍）。
        lastGrainGains = ExpCurrency.allCases.compactMap { c in
            let d = state[currency: c] - before[currency: c]
            return d > 0.001 ? (c, d) : nil
        }
        // Beat2 獲得バースト用のネタの伸び（applyNetaWork の結果の差分・RNG非消費・golden非対象）
        if state.nextNetaID > before.nextNetaID {
            lastNetaGain = (true, 0)
        } else {
            let d = state.netas.compactMap { n in before.netas.first { $0.id == n.id }.map { n.polish - $0.polish } }.max() ?? 0
            lastNetaGain = d > 0.001 ? (false, d) : nil
        }
        // Beat2 獲得バースト用の収支（表示専用・golden非対象）。pump 後の state＝週末処理込みの実増減。
        // 生活費（livingInterval 週ごとの週末処理）は行動の差と分けて持つ（GameEngine.applyWeekEnd と同条件・表示専用）。
        lastLivingPaid = (actedWeek % config.livingInterval == 0) ? GameEngine.livingCostDue(state, config: config) : 0   // 部屋の上乗せ込み
        lastMoneyDelta = state.money - before.money + lastLivingPaid
        lastStaminaDelta = Int(state.stamina.rounded()) - Int(before.stamina.rounded())
        lastFameDelta = state.fame - before.fame
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
    /// キュー96：次にオファーを受けると腕が落ちる（テレビ慣れ）か。乱数非消費
    var offerFatigued: Bool {
        GameEngine.offerFatigued(state: state, atWeek: (runner.year - 1) * config.weeks + runner.week, config: config)
    }

    /// キュー96：今週の札の一覧（2枚以上ある時だけ・先頭＝本編の乱数の札）。知名度で増える
    var offerChoices: [OfferSpec]? { runner.offerChoices }
    /// キュー96：札を選ぶ（受ける直前に呼ぶ）。乱数非消費
    func chooseOffer(index: Int) { runner.chooseOffer(index: index) }

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
                GameEngine.applyOffer(o, to: &s, config: config, atWeek: (year - 1) * config.weeks + week)   // テレビ慣れも予告に乗せる（実際の受諾＝WeekRunner と同じ・code_review_2026-10-19 §3-2）
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

    /// action で稼ぐ経験点通貨の差分（乱数非消費・純関数）。稽古カードの「+N粒」プレビュー用。
    /// previewState と同型で state のコピーに applyTraining を適用し state[currency: c] の before/after 差分を返す。
    /// 正典v3: 稽古は能力を直接伸ばさず通貨を稼ぐ＝現行の previewGains（能力差分）は0になるため、稼ぎの手応えはこちらで出す。
    /// RNG非消費＝golden不変。
    func previewGrainGains(_ action: WeekAction, offer: OfferSpec? = nil) -> [(currency: ExpCurrency, amount: Double)] {
        let after = previewState(action, offer: offer)
        return ExpCurrency.allCases.compactMap { c in
            let d = after[currency: c] - state[currency: c]
            return d > 0.001 ? (c, d) : nil
        }
    }

    /// 行動カードの伸び表示用: action を適用し、自動注ぎ（config.autoPourAllocation）なら WeekRunner と同じ順で
    /// 粒を全量注いだ後の状態（週末の生活費は含まない＝名目値）。乱数非消費・純関数＝golden不変。
    func previewAfterPour(_ action: WeekAction, offer: OfferSpec? = nil) -> GameState {
        var s = previewState(action, offer: offer)
        if config.autoPourAllocation { GameEngine.pourRecommended(to: &s, config: config) }
        return s
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
    /// 監査F-02: 正典台本は「最も低い能力」が器満了でゼロ利得になると止まるため、器を使わない能力（メンタル）へ
    /// まだ注げる粒が残っていても空になる。UI専用に、台本の続きから「注げる能力を低い順に拾う」延長を足す。
    /// 正典の recommendedPlan（golden台本）自体は不変・RNG非消費。
    func recommendedAllocation() -> [Ability] {
        var plan = GameEngine.recommendedPlan(state: state, config: config)
        var probe = state
        for a in plan { GameEngine.pourStep(a, to: &probe, config: config) }
        var n = 0
        outer: while n < 2_000 {
            n += 1
            for a in Ability.allCases.sorted(by: { probe[$0] < probe[$1] }) {
                if GameEngine.pourStep(a, to: &probe, config: config) > 0 {
                    plan.append(a)
                    continue outer
                }
            }
            break
        }
        return plan
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
        #if DEBUG
        // 目視用：MZ_NOEVENT=1 で選択イベントを発火させない（MZ_UI=grown が起動直後にイベントで隠れた）。本導線は不変
        if ProcessInfo.processInfo.environment["MZ_NOEVENT"] != nil { return }
        #endif
        if state.riftWarned == true, !didFireRiftWarn {
            // 0050: 週末に riftWarned が初めて true になった週の次の週頭（決定的フラグ・抽選なし・キャリア1回）
            pendingChoiceEvent = .riftWarning
            didFireRiftWarn = true
        } else if justLostStage, !didFireLostRehearsal {
            pendingChoiceEvent = .justLostRehearsal
            didFireLostRehearsal = true
        } else if lossStreak >= 3, !styleTalkDone {
            pendingChoiceEvent = .styleTalk
            styleTalkDone = true   // 出した時点で一発化（選ばず閉じても連敗中は毎週出ない。通過で再武装）。GameCore非経路
        } else if justPassedStage, !didFirePassFork, let m = nextMilestoneForEvent(), m.week - week >= 3, state.stamina >= 15 {
            pendingChoiceEvent = .justPassedFork
            didFirePassFork = true
        } else if !didFireEve, let m = nextMilestoneForEvent(), m.week - week == 1, m.highStakes {
            pendingChoiceEvent = .preTournamentEve
            didFireEve = true
        } else if !didFireEarlyFormality, year == 1, week >= 3, week < 15, state.compat <= 7 {   // 結成初期＝1年目だけ
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
        } else if inviteWaiting {
            // §102 週末に来た先輩の誘い（別乱数・runner.pendingInvite が出所）。確定発火が無い自由週の頭で札を出す。
            // 確定発火（前夜・負けた後・通過の分かれ道等）はその週を逃すと二度と出ないので先に出し、誘いは次の空いた週へ送る（code_review_2026-10-19b §1）
            inviteWaiting = false
            pendingChoiceEvent = .weekendInvite
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
        weekBanter = DialogueData.banter(band: banterBand(), salt: year &* 131 &+ week, picker: picker())   // 年も混ぜる＝毎年同じ週に同じ掛け合いにしない／直近の掛け合いは避ける
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
        // 相方以外の人とのイベント（docs/choice_events_others_v1.md §2）
        case .kouhaiInvite:
            // 後輩がいる頃（2年目以降か、1年目の後半）
            return year >= 2 || week >= 24
        case .senpaiAllNight:
            // 朝まで付き合う夜が本番の前週に重ならない
            guard let m = nextMilestoneForEvent() else { return true }
            return m.week - week >= 2
        case .baitoInventory:
            // バイト先で頼られる程度に入っている（0023 と同じ UI 層カウンタ）
            return jobCount >= 3
        case .homecomingCall:
            // 帰省の数日が追い込みを食わない
            return noTournamentWithin3Weeks()
        case .summerFestivalGig:
            // 0051: 炎天下の営業が本番の前週に重ならない（0042 と同じ）
            guard let m = nextMilestoneForEvent() else { return true }
            return m.week - week >= 2
        default:
            return true
        }
    }

    /// 今後の本番1件（表示・発火判定用）。
    struct StageInfo {
        let week: Int
        let name: String
        let line: Double
        /// 0010「前夜の一本」の対象か（新人賞級・GP準決勝・決勝/敗者復活＝高格／GP1回戦〜準々決勝＝低格）
        let highStakes: Bool
        var isGP: Bool
        /// 舞台の尺の目安（表示専用）
        var length: NetaLength = .中尺
    }

    /// これから実際に立てる本番の一覧（週順）。WeekMainView/AllocationView/イベント発火の唯一の走査（監査F-01）。
    /// GP は敗退済みなら除外し、決勝/敗者復活は資格がある時だけ載せる（監査A-02: 敗退後の誤カウントダウンを止める）。
    /// 自由週の画面では今週の本番は既に済んでいる（or 見送った）ので、今週は含めない。RNG非消費・golden不変。
    func upcomingStages() -> [StageInfo] {
        let cal = config.calendar
        var ms: [StageInfo] = []
        if runner.isGPAlive {
            for i in runner.gpRoundsPassed..<cal.gpRounds.count {
                let name = i < cal.gpRoundNames.count ? cal.gpRoundNames[i] : "頂GP\(i + 1)回戦"
                ms.append(StageInfo(week: cal.gpRounds[i].week, name: GPName.display(name), line: cal.gpRounds[i].line,
                                    highStakes: i == cal.gpRounds.count - 1, isGP: true,
                                    length: NetaCatalog.lengthForGPRound(index: i)))
            }
        }
        if runner.isFinalist || runner.isGPAlive {
            ms.append(StageInfo(week: cal.gpFinalWeek, name: "頂GP 決勝", line: cal.gpFinalLine, highStakes: true, isGP: true, length: NetaCatalog.lengthForGPFinal))
        } else if runner.hasRevival {
            ms.append(StageInfo(week: cal.gpFinalWeek, name: "敗者復活", line: cal.gpRevivalLine, highStakes: true, isGP: true, length: NetaCatalog.lengthForGPRevival))
        }
        for t in cal.tournaments where t.isEligible(year: year, state: state) {
            ms.append(StageInfo(week: t.week, name: t.name, line: t.line, highStakes: true, isGP: false, length: NetaCatalog.lengthForTournament))
        }
        let includeThisWeek: Bool = { if case .freeAction = phase { return false }; return true }()
        return ms.filter { $0.week > week || (includeThisWeek && $0.week == week) }
            .sorted { $0.week < $1.week }
    }

    /// 今年の決勝に敗者復活から上がったか（準決勝を通っていない決勝進出者＝講評の「昼からもう一本」用・表示専用）
    var reachedFinalViaRevival: Bool {
        runner.gpRoundsPassed < config.calendar.gpRounds.count
    }

    /// 次の本番（無ければ nil）
    var nextStage: StageInfo? { upcomingStages().first }

    /// GP の道が閉じ、この年に出られる本番が残っていないか（監査A-03「年末へ」の条件）
    var noStagesLeft: Bool { upcomingStages().isEmpty }

    private func nextMilestoneForEvent() -> (week: Int, highStakes: Bool)? {
        nextStage.map { ($0.week, $0.highStakes) }
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
        guard let kind = pendingChoiceEvent, !choiceApplied else { return }   // 二度押しで二重にかけない
        let choices = ChoiceEventTable.choices(for: kind, config: config)
        guard let choice = choices.first(where: { $0.id == choiceID }), choice.gate(state) else { return }
        choiceApplied = true
        runner.applyEventEffects(choice.effects)
        if kind == .weekendInvite, choiceID == "A" { runner.applyInviteGo(idea: inviteIdea) }   // §102 行く: 所持金-5,000・体力-10・メンタル+1・(半分で)発想+0.5
        state = runner.state
        switch kind {
        case .justLostRehearsal: justLostStage = false
        case .styleTalk: styleTalkDone = true
        case .justPassedFork: justPassedStage = false
        case .riftWarning: riftWarnChoice = choiceID   // 0050: 何を選んだか（#2 の一行の差し替え・図鑑）。発火時に didFireRiftWarn 済み
        case .preTournamentEve: break   // 週送りで weeksLeft==1 の条件が自然に外れる＝追加フラグ不要
        case .tsuukaBreak: didFireTsuukaChoice = true
        case .earlyFormality: didFireEarlyFormality = true
        case .brokeDrinkingInvite, .senpaiMeishi, .peerFoldedChair, .lineupTop, .greenroomSilentTen,
             .lastTrainReview, .luckyThirdLine, .wroteOneTonight, .photoShootOffer,
             .kouhaiInvite, .senpaiAllNight, .stageCrewChairs, .writerPostcards, .doukiJointLive,
             .baitoInventory, .homecomingCall, .regularFanOranges, .officeTicketQuota,
             .summerFestivalGig, .doukiOnTV, .theaterRenovation, .classmateInAudience, .partnerFever,
             .lostNotebook, .yearEndLive:
            break   // 週次イベントは発火時に firedWeeklyEvents で1回制管理済み
        case .regularEmployment:
            break   // 0023 廃止（抽選外）。古いセーブの保留中イベント互換のためケースだけ残す
        case .namelessReservationSlip:
            break   // 選択肢なしフレーバー＝発火時に didFireNamelessSlip 済み（applyEventChoice は実際には呼ばれない）
        case .weekendInvite:
            break   // §102 一回ごとの札＝フラグ不要（inviteWaiting は表示時に落とし済み）
        case .taniguchiShortJob:
            break   // 確定発火＝発火時に didFireTaniguchiJob 済み（A の compatFreeze は EventEffect が適用）
        }
        saveNow()
    }

    /// 選択後の会話を見終えてオーバーレイを閉じる（UI側の「閉じる」タップから呼ぶ）
    func dismissChoiceEvent() {
        pendingChoiceEvent = nil
        choiceApplied = false
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
        guard case .train(let t) = action, GameConfig.netaWriteTrainings.contains(t) || t == .ネタ見せ会 || t == .フリーライブ else { return }
        // 体力ゲート・体調ダウン・お金不足で休みに差し替わった週はネタも進まない（休んだのに完成度が上がっていた）
        guard runner.lastTrainingDone == t else { return }
        let placeGain = config.netaPlaceGain[t]   // 喫茶店・ファミレスで書くと完成度が多め（家＝nil）
        switch t {
        case .ネタ作り, .喫茶店で書く, .ファミレスで書く:
            if let id = writeTargetID {
                runner.applyNetaRevise(id: id, gain: placeGain)
            } else if state.netas.count < config.netaActiveSlots {
                let kata = NetaCatalog.autoKata(forID: state.nextNetaID)
                let id = runner.applyNetaCreate(kata: kata, lengthFit: NetaCatalog.defaultLengthFit(for: kata),
                                                 name: NetaCatalog.autoName(forID: state.nextNetaID))
                writeNetaID = id; writeNewNeta = false   // 書いたネタは「書く対象」へ。手で選んだ勝負ネタ(selectedNetaID)は触らない
                // 勝負ネタが未選択(nil)の時だけ、新しく書いたネタを勝負ネタにも入れる（大会の入口画面を通らない経路＝GPの回戦/決勝/敗者復活/自動進行でも補正0にならない・code_review_2026-10-25 §2）
                if runner.state.selectedNetaID == nil { runner.applyNetaSelect(id: id) }
            } else if let last = state.netas.last {
                runner.applyNetaRevise(id: last.id, gain: placeGain)
                writeNewNeta = false   // 枠が満杯で新しく書けなかった週は「新しく書く」を下ろす（後で枠が空いた週に黙って新ネタが出ない・code_review_2026-10-25 §7a）
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

    /// 書く対象のネタID（新しく書く指定なら nil。指定が無い/消えていれば勝負ネタ）
    var writeTargetID: Int? {
        if writeNewNeta { return nil }
        if let id = writeNetaID, state.netas.contains(where: { $0.id == id }) { return id }
        if let id = state.selectedNetaID, state.netas.contains(where: { $0.id == id }) { return id }
        return nil
    }
    var writeTargetNeta: Neta? { writeTargetID.flatMap { id in state.netas.first { $0.id == id } } }
    /// 書く対象を替える（勝負ネタは変えない）
    func setWriteNeta(_ id: Int) { writeNetaID = id; writeNewNeta = false; saveNow() }
    /// 「新しく書く」にする（勝負ネタは変えない）
    func beginNewWrite() { writeNewNeta = true; writeNetaID = nil; saveNow() }

    /// 本番の前に出すネタの既定を整える（playtest_v4 ③）。選び忘れ(nil)、または「新しく書いた直後で舞台に一度も立っていない低い完成度のネタ」が
    /// 選び忘れ(nil)の時だけ完成度が一番高いネタを入れる。手で選んだネタには触れない（書く対象は別状態＝書いても勝負ネタは動かない）。UI層のみ・乱数非消費。
    func ensureStageNetaDefault() {
        if let id2 = state.selectedNetaID2, id2 == state.selectedNetaID { runner.applyNetaSelect2(id: nil); state = runner.state }   // 直す前の旧セーブで1本目＝2本目なら2本目を外す（review_today_fixes_1019 §2）
        guard let best = state.netas.max(by: { $0.polish < $1.polish }) else { return }
        if selectedNeta == nil { selectNeta(best.id) }   // 選び忘れの時だけ最高完成度を入れる。手で選んだネタは戻さない（queue108・19g §4）
    }

    /// 「今かけるネタ」を選ぶ（大会入口・持ちネタ帳から。保管庫のネタでも可＝自動でアクティブへ呼び戻さない・
    /// 呼び戻しは recallNeta を先に呼ぶ設計。ここはアクティブ枠内のIDのみ有効）。
    func selectNeta(_ id: Int?) {
        if let id, id == state.selectedNetaID2 { runner.applyNetaSelect2(id: nil) }   // 1本目に2本目と同じネタ＝2本目を外す（同じネタ2本で減点を免れない・code_review_2026-10-19f §2）
        runner.applyNetaSelect(id: id)
        state = runner.state
        saveNow()
    }

    /// 決勝の2本目を選ぶ（v2 §4-2）
    func selectNeta2(_ id: Int?) {
        if let id, id == state.selectedNetaID { return }   // 1本目と同じネタは2本目にできない（§2）
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
    /// 買い物（ShopView）。買えなければ何もしない
    @discardableResult
    func buyItem(_ item: ShopItem) -> Bool {
        guard runner.applyItemPurchase(item) else { return false }
        state = runner.state
        saveNow()   // 買い物を保存（落とした時に消えない・乱数非消費・code_review_2026-10-19e §5）
        return true
    }

    /// 部屋を選び直す（お店・乱数なし）。選べたら true。
    @discardableResult
    func moveRoom(to target: Int) -> Bool {
        guard runner.applyRoomMove(to: target) else { return false }
        state = runner.state
        saveNow()
        return true
    }

    /// 特技を覚える（乱数非消費・golden不変）。覚えたら true
    @discardableResult
    func learnSkill(_ k: Skill) -> Bool {
        guard runner.applyLearnSkill(k) else { return false }
        state = runner.state
        saveNow()
        return true
    }

    /// お店の「戻す」：店に入った時の状態 start から、残った買い物 items だけを順に買い直す（乱数非消費）
    func replayShopVisit(from start: GameState, _ items: [ShopItem]) {
        runner.replayItemPurchases(from: start, items)
        state = runner.state
        saveNow()
    }

    func renameNeta(_ id: Int, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        runner.applyNetaRename(id: id, to: trimmed)
        state = runner.state
        saveNow()
    }

    /// アクティブ枠→保管庫（削除でも封印でもない・いつでも呼び戻せる・v2 §2-2）
    func retireNeta(_ id: Int) {
        if state.selectedNetaID2 == id { runner.applyNetaSelect2(id: nil) }   // しまったネタが2本目に残って、出した時に黙って復活しない（code_review_2026-10-19f §3）
        if writeNetaID == id { writeNetaID = nil }   // しまったネタを書く対象に残さない（呼び戻した時に黙って書く対象へ戻らない・code_review_2026-10-25 §7c）
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
        switch phase {   // 二度押し・別の段からの呼び出しは無視（懸念の台帳 L37）
        case .gpRound, .gpRevival, .gpFinal: break
        default: return
        }
        phase = runner.resolveAuto()
        pump()
        saveNow()
    }

    /// S3結果画面の「次へ」。結果を閉じて次週へ進める
    func acknowledgeResult() {
        guard pendingResult != nil else { return }   // 最後のページの二度タップで週が2つ進まない（呼び手はすべて結果を見せている時だけ・code_review_2026-10-19c §2-2／19d）
        pendingResult = nil
        phase = runner.begin()
        pump()
        saveNow()
    }

    /// 「年末へ」（監査A-03）: GPの道が閉じ出られる本番が無い時、残りの週を完全休養で送って年を閉じる。
    /// 通常の choose/advance と同じ経路で進める（UIの近道であって、規則も乱数の使い方も通常プレイと同じ）。
    func fastForwardToYearEnd() {
        var steps = 0
        while !finished, !winFinale, !watchingFinal, steps < 200 {   // 決勝の夜は止めて観せる（H-01）
            steps += 1
            if pendingChoiceEvent != nil {   // 年を閉じる意思表示＝イベントは見送る
                // 0050 予告は見ないまま消さない＝未発火に戻し、次の年の第1週頭に必ず出す（riftWarned は持ち越される）
                if pendingChoiceEvent == .riftWarning, riftWarnChoice == nil { didFireRiftWarn = false }
                dismissChoiceEvent(); continue
            }
            if pendingResult != nil { acknowledgeResult(); continue }
            switch phase {
            case .freeAction:         choose(.rest(.完全休養))
            case .tournamentDecision: decideTournament(nil)
            case .gpRound, .gpRevival, .gpFinal: advanceAuto()
            default: return
            }
        }
    }

    /// 決勝週に自由週を迎えた（＝決勝にも敗者復活にも出ない）なら、観客版決勝を立てる（監査H-01）。
    private func checkSpectatorFinal() {
        guard !didWatchFinal, case .freeAction = phase, week == config.calendar.gpFinalWeek,
              !runner.isFinalist, !runner.hasRevival else { return }
        watchingFinal = true
    }

    /// 観客版決勝を観終えた。優勝組を「出来事」に残して週メインへ戻る。
    func finishWatchingFinal(winner: String) {
        guard watchingFinal else { return }   // 終わりのボタンの二度押しで「（客席から）」が2行積まれた（code_review_2026-10-26 低1）
        watchingFinal = false
        didWatchFinal = true
        log.append("第\(week)週: 頂GP 決勝 優勝「\(winner)」（客席から）")
        saveNow()
    }

    /// 【候補・キュー117 案A】この周を閉じる（エンディングに入る時・年末から「もう一度」でタイトルへ戻る時）。以後 saveNow は書かずに消す（background の書き直し防止）。非保存
    private(set) var careerClosed = false
    func closeCareer() {
        careerClosed = true
        Self.store.removeObject(forKey: Self.saveKey)
    }

    /// 「この年をやめてタイトルへ」（監査G-04）。セーブを消し、RootView がタイトルへ戻す。
    func abandonRun() {
        Self.store.removeObject(forKey: Self.saveKey)
        abandoned = true
    }

    /// この年の頂GPの回戦に出たか（週の記録に1回戦の行があるか）。記録は表示名（GPName.display）で書くので、生のキー「GP1回戦」では探さない
    /// （年末の画面が生のキーで探して、1回戦で負けた年を「エントリー費が払えず不出場」と出していた＝10/26 定期の目視）。表示専用
    /// 週の記録の1行を、読む側（戦績・年末）が使う形に分ける。書く側は summarize（「第N週: 大会 札 [+N万] / 大会 札」）・観戦（…（客席から））・決勝優勝の3形。
    /// 札は「優勝/通過/敗退/休/観戦」。1週に複数大会が「 / 」で並ぶ行は大会ごとに分ける。表示専用
    struct LogPart: Equatable { let week: String; let title: String; let mark: String; let prize: Int }
    static func parseLogLine(_ line: String) -> [LogPart] {
        var week = "", body = line
        if let r = line.range(of: ": ") { week = String(line[..<r.lowerBound]); body = String(line[r.upperBound...]) }
        if line.contains("客席") { return [LogPart(week: week, title: body, mark: "観戦", prize: 0)] }
        return body.components(separatedBy: " / ").map { raw in
            var prize = 0
            var rest = raw
            if let re = try? NSRegularExpression(pattern: "\\+(\\d+)万") {
                for m in re.matches(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
                    if let r = Range(m.range(at: 1), in: raw) { prize += Int(raw[r]) ?? 0 }
                }
                rest = re.stringByReplacingMatches(in: raw, range: NSRange(raw.startIndex..., in: raw), withTemplate: "")
                    .trimmingCharacters(in: .whitespaces)
            }
            let last = rest.split(separator: " ").last.map(String.init) ?? ""
            let mark = ["優勝", "通過", "敗退"].contains(last) ? last : "休"
            return LogPart(week: week, title: rest, mark: mark, prize: prize)
        }
    }

    var loggedGPEntry: Bool { Self.loggedGPEntry(in: log, config: config) }
    static func loggedGPEntry(in log: [String], config: GameConfig) -> Bool {
        let first = config.calendar.gpRoundNames.first ?? "GP1回戦"
        return log.contains { $0.contains(GPName.display(first)) }
    }

    /// 設定の「解散」の別れの場面に出す、この周の最高成績1行（表示専用・乱数なし）。
    /// 終わった年（yearHistory）＋進行中の年の頂GPの到達から一番上を選ぶ。大会に一度も出ていなければ nil
    var bestRunLine: String? {
        var recs = yearHistory.filter { $0.enteredGP != false }
            .map { YearRecord(year: $0.year, roundsPassed: $0.roundsPassed, reachedFinal: $0.reachedFinal,
                              champion: $0.champion, bankrupt: false, prize: 0) }   // 夜逃げ・解散の印は外して到達だけを比べる
        // 進行中の年はまだ負けていない＝「〜敗退」ではなく通過した段で言う（code_review_2026-10-25 §3）。prize=-1 を目印に使う
        if !finished, runner.gpRoundsPassed > 0 || runner.isFinalist {
            recs.append(YearRecord(year: year, roundsPassed: runner.gpRoundsPassed, reachedFinal: runner.isFinalist,
                                   champion: false, bankrupt: false, prize: -1))
        }
        func rank(_ r: YearRecord) -> Int { r.champion ? 100 : (r.reachedFinal ? 50 : r.roundsPassed) }
        guard let best = recs.max(by: { rank($0) < rank($1) || (rank($0) == rank($1) && $0.year > $1.year) }) else { return nil }
        let names = config.calendar.gpRoundNames
        let label: String
        if best.champion { label = "優勝" }
        else if best.prize == -1 {
            label = best.reachedFinal ? "決勝進出"
                : names[min(best.roundsPassed, names.count) - 1].replacingOccurrences(of: "GP", with: "") + "通過"
        } else { label = YearResultView.reachLabel(best, names: names) }
        return "\(best.year)年目　頂GP \(label)"
    }

    /// 「勝ち版」決勝演出の「次へ」。年末結果（S4）へ
    func acknowledgeWin() {
        winFinale = false
        finished = true
        saveNow()   // 優勝＝キャリアの区切り（勇退）なのでセーブは消える
    }

    // MARK: 複数年キャリア（core_loop_reconsideration_v0 §7・2026-10-10）

    /// 1年＝1行の記録（表示専用・golden非対象）
    struct YearRecord: Codable, Equatable {
        let year: Int
        let roundsPassed: Int
        let reachedFinal: Bool
        let champion: Bool
        let bankrupt: Bool
        let prize: Int
        /// その年GPに出たか（エントリー費が払えず出られない年がある）。nil＝旧セーブ（出た扱い）。表示専用
        var enteredGP: Bool? = nil
        /// 途中解散でキャリアが終わった年。nil＝旧セーブ（解散なし）。年表に「解散」の行を出す（表示専用）
        var dissolved: Bool? = nil
        /// その年の決勝を客席から観たか。nil＝観ていない／旧セーブ。戦績の年表の灰「観戦」札（表示専用）
        var watchedFinal: Bool? = nil
    }

    /// このキャリアがこの年末で区切られるか（優勝＝勇退／夜逃げ／解散／結成 careerYears 年目の年末）
    var careerOver: Bool {
        guard let o = outcome else { return false }
        return o.champion || o.bankrupt || o.dissolved || year >= config.careerYears
    }

    /// 年末（S6）の「◯年目へ」。GameCareer.runCareer と同じ形で翌年の WeekRunner を立てる＝
    /// 状態と乱数列を持ち越し、年初処理（体力全回復・その年までの成長予算）は WeekRunner(year:) が行う。
    /// 前年に準々決勝以上（roundsPassed>=3）なら1回戦シード（runCareer の gpSeeded と同じ条件）。RNG非消費。
    func startNextYear() {
        guard finished, !careerOver, let o = outcome else { return }
        var r = WeekRunner(state: runner.state, year: year + 1, config: config, rng: runner.rng,
                           gpSeeded: o.roundsPassed >= 3, inviteSeed: runner.inviteSeed)
        yearStartState = r.state
        hasYearStart = true   // 旧セーブ（年初の状態なし）から続けた時も、次の年からは年末の差分を出す（code_review_2026-10-19c §2-3）
        // その年だけの記録と、直前の行動への反応はリセット（キャリア通算のイベント進行フラグ・連敗数・UI乱数は持ち越す）
        finished = false
        outcome = nil
        pendingResult = nil
        log = []
        categoryLog = [:]
        totalPrize = 0
        didWatchFinal = false
        watchingFinal = false
        lastFinalMargin = nil
        lastAction = nil
        lastGains = []
        lastCompatGain = 0
        lastGrainGains = []
        lastNetaGain = nil
        lastMoneyDelta = 0
        lastLivingPaid = 0
        lastStaminaDelta = 0
        lastFameDelta = 0
        lastDeltaWeek = -1
        justPassedStage = false
        justLostStage = false
        justOroshiNeta = nil
        weekBanter = nil
        stablePicks = [:]   // 使った文の記録（usedPicks）はキャリア通算＝年が替わっても消さない
        pendingChoiceEvent = nil
        choiceApplied = false
        lastEventRollWeek = -1
        lastBanterRollWeek = -1
        let first = r.begin()
        runner = r
        phase = first
        pump()
        saveNow()
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
        // ---- ここから下は後から足したフィールド。必ず Optional にする（旧セーブに無くても復号できる・監査G-03） ----
        var version: Int?
        var didFireLostRehearsal: Bool?
        var didFirePassFork: Bool?
        var didFireEve: Bool?
        var didWatchFinal: Bool?
        // v3（複数年キャリア）
        var yearStartState: GameState?
        var yearHistory: [YearRecord]?
        var debtWarnTier: Int?
        var myName: String?        // 自分の名前（旧セーブ＝nil＝俺）
        var partnerName: String?   // 相方の名前（旧セーブ＝nil＝谷口）
        var comboKind: String?     // コンビの形 ComboKind.rawValue（旧セーブ＝nil＝男コンビ）
        var meetingKind: String?   // 出会い方 MeetingKind.rawValue（旧セーブ＝nil＝高校の同級生）
        var didFireRiftWarn: Bool? // 途中解散の予告を出したか（旧セーブ＝nil＝まだ）
        var riftWarnChoice: String? // 予告の選択 "A"/"B"（旧セーブ＝nil）
        var didShowRiftHint: Bool?  // 予告の後の知らせを出したか（旧セーブ＝nil＝まだ）
        var usedPicks: [String: [Int]]?   // このキャリアで使った文の番号（旧セーブ＝nil＝まだ使っていない）
        var usedFanLines: [String]?       // このキャリアで出した観客の声（旧セーブ＝nil）
        var shownOnce: [String]?          // このキャリアで一度出した固定の一文の印（旧セーブ＝nil）
        var weeksWithoutPartner: Int?     // 相方と過ごさない週の連続数（旧セーブ＝nil＝0）
        var injuryNoticeWeeks: Int?       // 体調ダウンの知らせ待ち（旧セーブ＝nil＝0・code_review_2026-10-19c §2-4）
        var writeNetaID: Int?             // 書く対象のネタ（旧セーブ＝nil＝勝負ネタを磨く・queue108）
    }

    /// 所持金から借金の段（円。−50万・−80万を割った段）。表示専用
    static func debtTier(money: Int) -> Int { money < -800_000 ? 3 : money < -500_000 ? 2 : money < 0 ? 1 : 0 }
    /// 今の所持金で新しく知らせるべき段（まだ出していない深い段があれば、その段。なければ nil）。表示専用
    func debtNoticeTierToShow(money: Int) -> Int? {
        let tier = GameSession.debtTier(money: money)
        return tier > debtWarnTier ? tier : nil
    }
    /// 借金の知らせを出した段を記録（深い方へだけ進む）
    func markDebtWarned(_ tier: Int) {
        guard tier > debtWarnTier else { return }
        debtWarnTier = tier
        saveNow()
    }

    /// 予告0050を選び終えた後、週メインで一度だけ出す事実の一言を出すべきか。表示専用
    var riftHintToShow: Bool { riftWarnChoice != nil && !didShowRiftHint && pendingChoiceEvent == nil }
    func markRiftHintShown() {
        guard !didShowRiftHint else { return }
        didShowRiftHint = true
        saveNow()
    }

    /// 保存先（本番は .standard 固定。単体テストだけが専用 suite に差し替える）
    static var store: UserDefaults = .standard
    private static let saveKey = "manzai.save.v1"
    /// 読めなかったセーブの退避先（黙って消さない・監査G-03）
    private static let brokenSaveKey = "manzai.save.v1.broken"
    /// セーブ形式の版数（フィールドを足したら上げる。足すフィールドは必ず Optional）
    static let saveVersion = 3

    /// 中断セーブを書く。キャリアが区切られた（優勝・夜逃げ・最終年の年末）ら逆にセーブを消す。
    /// 区切りでない年末は、翌年へ進む前の年末画面として残す（復元で S6 を出し直す）。
    /// 呼び出しはプレイヤー入力の各確定点（choose/decideTournament/advanceAuto/acknowledge*/allocate/
    /// applyEventChoice/ネタ操作）＋RootView の scenePhase(.background) 保険。init からは呼ばない
    /// （IntroFlow 前のプレースホルダ・セッションがセーブを作らないように）。
    func saveNow() {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        // QA自動走行で実プレイのセーブを潰さない（MZ_ALLOWSAVE=1 は中断→再開の目視用に、あえて書く）
        if (env["MZ_SMOKE"] != nil || env["MZ_UI"] != nil || env["MZ_ENDING"] != nil), env["MZ_ALLOWSAVE"] == nil { return }
        #endif
        // 【候補・キュー117 案A】区切りの年末もセーブを残し、エンディングに入った時（closeCareer）に消す＝年末で落ちても周と図鑑が消えない
        guard !abandoned, !careerClosed else {
            Self.store.removeObject(forKey: Self.saveKey)
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
                            pendingChoiceEvent: choiceApplied ? nil : pendingChoiceEvent, weekBanter: weekBanter,
                            lastBanterRollWeek: lastBanterRollWeek, categoryLog: categoryLog,
                            totalPrize: totalPrize, combiName: combiName,
                            version: Self.saveVersion,
                            didFireLostRehearsal: didFireLostRehearsal, didFirePassFork: didFirePassFork,
                            didFireEve: didFireEve, didWatchFinal: didWatchFinal,
                            yearStartState: yearStartState, yearHistory: yearHistory,
                            debtWarnTier: debtWarnTier, myName: myName, partnerName: partnerName, comboKind: comboKind.rawValue, meetingKind: meetingKind.rawValue,
                            didFireRiftWarn: didFireRiftWarn, riftWarnChoice: riftWarnChoice,
                            didShowRiftHint: didShowRiftHint,
                            usedPicks: usedPicks, usedFanLines: usedFanLines, shownOnce: Array(shownOnce).sorted(), weeksWithoutPartner: weeksWithoutPartner,
                            injuryNoticeWeeks: injuryNoticeWeeks, writeNetaID: writeNetaID)
        do {
            let data = try JSONEncoder().encode(save)
            Self.store.set(data, forKey: Self.saveKey)
        } catch {
            print("[save] encode failed: \(error)")   // 前回のセーブは残したまま（上書きしない）
        }
    }

    /// 起動時のエントリポイント: セーブがあれば復元、無ければ新規（IntroFlow 前のプレースホルダ）。
    static func loadedOrNew(config: GameConfig = GameConfig()) -> GameSession {
        let defaults = store
        if let data = defaults.data(forKey: saveKey) {
            do {
                let save = try JSONDecoder().decode(SaveData.self, from: data)
                return GameSession(restoring: save, config: config)
            } catch {
                // 形式が合わず読めない＝黙って捨てずに退避してから新規へ（後の版で救出できるように）
                print("[save] decode failed, moved to \(brokenSaveKey): \(error)")
                defaults.set(data, forKey: brokenSaveKey)
                defaults.removeObject(forKey: saveKey)
            }
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
                if summary.results.contains(where: { $0.name == "体調ダウン" }) { injuryNoticeWeeks = config.injuryRestWeeks }
                if summary.results.contains(where: { $0.name == "体調ダウン" || $0.name == "療養" }) { categoryLog[summary.week] = .kaifuku }   // 日程表に「回」を残す（療養週が空白にならない）
                if let idea = runner.pendingInvite { inviteWaiting = true; inviteIdea = idea }   // §102 先輩の誘い（週末・別乱数）
                if !summary.results.isEmpty {
                    log.append(summarize(summary))
                }
                let big = summary.results.filter(\.isStage)
                if let f = big.last(where: { $0.name == "GP決勝" }) { lastFinalMargin = f.margin }
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
                // 1年＝1行の記録（優勝年の賞金は下で totalPrize に足すので、ここでは同じ式で先に数える）。
                // pump が同じ年末に再入しても二重に積まない
                if yearHistory.last?.year != runner.year {
                    // 夜逃げ・解散で終わった週は weekDone を経ない＝その週の大会の結果が出来事ログ・賞金年計に載らなかった
                    // （懸念の台帳 L52）。優勝の時と同じく、runner の週内結果から表示用の記録だけ足す（GameCore 不変）。
                    if outcome.bankrupt || outcome.dissolved {
                        let rs = runner.snapshot().weekResults
                        if !rs.isEmpty {
                            log.append(summarize(WeekSummary(year: runner.year, week: runner.week, results: rs, state: runner.state)))
                            totalPrize += rs.filter(\.isStage).reduce(0) { $0 + $1.prize }
                        }
                    }
                    yearHistory.append(YearRecord(year: runner.year, roundsPassed: outcome.roundsPassed,
                                                  reachedFinal: outcome.reachedFinal, champion: outcome.champion,
                                                  bankrupt: outcome.bankrupt,
                                                  prize: totalPrize + (outcome.champion ? config.calendar.gpPrize : 0),
                                                  enteredGP: outcome.roundsPassed > 0 || outcome.reachedFinal || outcome.champion
                                                      || loggedGPEntry,
                                                  dissolved: outcome.dissolved ? true : nil,
                                                  watchedFinal: didWatchFinal ? true : nil))
                }
                if outcome.champion {
                    // 優勝の週は weekDone を経ないので、決勝の点差は runner のスナップショットの週内結果から読む（表示専用）
                    lastFinalMargin = runner.snapshot().weekResults.last(where: { $0.name == "GP決勝" })?.margin
                    // GP決勝の優勝は WeekRunner が週の結果を返さず即 yearDone になる（Calendar の即時リターン）＝
                    // .weekDone 経由の記録（出来事ログ・賞金年計）に載らない。表示用の記録だけここで足す（GameCore 不変）。
                    week = runner.week
                    log.append("第\(runner.week)週: 頂GP 決勝 優勝 +\(config.calendar.gpPrize / 10000)万")
                    totalPrize += config.calendar.gpPrize
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
                    checkSpectatorFinal()
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
    /// テスト用: runner が持つ正の状態（懸念の台帳 L55＝表示用の state が runner から写した唯一の派生かを突き合わせる）
    var debugRunnerState: GameState { runner.state }

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

    /// DEBUG: 週メインの一行案内（MZ_UI=weekhint）の目視用。action を n 回選んで週を進める（途中の選択イベントは流す）
    func debugFreeWeeks(_ n: Int, _ action: WeekAction) {
        var steps = 0, done = 0
        while done < n, !finished, steps < 200 {
            steps += 1
            if let kind = pendingChoiceEvent {
                if let c = ChoiceEventTable.choices(for: kind, config: config).first(where: { $0.gate(state) }) { applyEventChoice(c.id) }
                dismissChoiceEvent(); continue
            }
            guard case .freeAction = phase else { return }
            choose(action); done += 1
        }
        if let kind = pendingChoiceEvent { dismissChoiceEvent(); _ = kind }
    }

    /// DEBUG: オファーが来る週まで休んで進める（MZ_UI=offer の目視用）
    func debugUntilOffer() {
        var steps = 0
        while !finished, steps < 120 {
            steps += 1
            if let kind = pendingChoiceEvent {
                if let c = ChoiceEventTable.choices(for: kind, config: config).first(where: { $0.gate(state) }) { applyEventChoice(c.id) }
                dismissChoiceEvent(); continue
            }
            guard case .freeAction(let o) = phase else { return }
            if o != nil { return }
            choose(.rest(.完全休養))
        }
    }

    /// DEBUG: 大会前の振り忘れの知らせ（MZ_UI=prestage）の目視用。練習（体力が落ちたら休む）で、最初の大会の
    /// weeksBefore 週前まで進める＝経験点が貯まったまま大会が近い状態。RNG は通常の週送りと同じ（golden非対象）。
    func debugAdvanceUntilStage(weeksBefore: Int, stageWeek: Int) {
        var steps = 0
        while week < stageWeek - weeksBefore, !finished, steps < 120 {
            steps += 1
            if let kind = pendingChoiceEvent {   // 途中の選択イベントは1つ目の選択肢で流す
                if let c = ChoiceEventTable.choices(for: kind, config: config).first(where: { $0.gate(state) }) {
                    applyEventChoice(c.id)
                }
                dismissChoiceEvent()
                continue
            }
            guard case .freeAction = phase else { return }
            choose(state.stamina < config.staminaGate + 10 ? .rest(.完全休養) : .train(.ネタ作り))
        }
        if let kind = pendingChoiceEvent {   // 着いた週の頭に出た選択イベント（前夜など）も流す
            if let c = ChoiceEventTable.choices(for: kind, config: config).first(where: { $0.gate(state) }) {
                applyEventChoice(c.id)
            }
            dismissChoiceEvent()
        }
    }

    /// DEBUG: ネタ帳「大会の記録」（MZ_UI=notebook MZ_TAB=kiroku）の目視用に、判の4種（通過/敗退/休/優勝）を踏む記録を積む。
    /// 客席から（観戦）と自組の優勝が同じ週に並ぶのは見本だけ（判の種類を1画面で見るため。本編では同じ年に両方は出ない・playtest_v13 §2-1）
    func debugSeedKirokuLog() {
        log = ["第12週: 頂GP 1回戦 通過", "第20週: 頂GP 2回戦 敗退", "第30週: 体調ダウン 休",
               "第44週: 頂GP 決勝 優勝「ひだまり座」（客席から）", "第44週: 頂GP 決勝 優勝 +\(config.calendar.gpPrize / 10000)万"]
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

        #if DEBUG
        teppan.tiredYears = 2; midway.tiredYears = 1   // 飽きの札の目視用（fresh は nil＝札なし）
        #endif
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
        // 参照系UI再設計の目視用（§6チェックリスト①〜⑦を一画面で踏む）。数値は全て【仮】。
        // 通貨総量は年初器(6.0)を超える貯め込み＝「注ぐ→器が満ちて弾かれる」＋器の食い合い⑤まで一続きで目視できる残高。
        s.センス = 43; s.発想 = 24; s.表現 = 78; s.華 = 18; s.メンタル = 35   // センス43→45でC→B跨ぎ④／表現78=高値
        // 正典v3: 5通貨に配分（多対多＝複数能力のレシピを同時に満たせる残高を用意）
        s.exp閃き = 12; s.exp語彙 = 14; s.exp間合い = 10; s.exp存在感 = 14; s.exp胆力 = 9
        return s   // growthBudget は WeekRunner が年初 year1 値(6.0)へ設定＝上の通貨総量がそれを上回る＝食い合いが立つ
    }

    /// DEBUG: 指定週の大会の入口（tournamentDecision）まで、最初の大会等は夜行バスで流して進める（MZ_UI=wintercup の目視用）。
    func debugAdvanceToTournamentEntry(week target: Int, maxSteps: Int = 600) {
        var steps = 0
        while !finished, steps < maxSteps {
            steps += 1
            if pendingResult != nil { acknowledgeResult(); continue }
            switch phase {
            case .tournamentDecision:
                if nextStage?.week == target { return }
                decideTournament(.夜行バス)
            case .freeAction: choose(.job(.標準))
            case .gpRound, .gpRevival, .gpFinal: advanceAuto()
            default: return
            }
        }
    }

    /// DEBUG: 体調ダウンが起きるまで、体力の低い状態でキツいバイトを続ける（MZ_UI=injury の目視用）
    func debugUntilInjury(maxSteps: Int = 200) {
        var steps = 0
        while !finished, steps < maxSteps, injuryNoticeWeeks == 0 {
            steps += 1
            if let kind = pendingChoiceEvent {
                if let c = ChoiceEventTable.choices(for: kind, config: config).first(where: { $0.gate(state) }) { applyEventChoice(c.id) }
                dismissChoiceEvent(); continue
            }
            if pendingResult != nil { acknowledgeResult(); continue }
            if case .tournamentDecision = phase { decideTournament(nil); continue }
            guard case .freeAction = phase else { return }
            choose(.job(.キツい))
        }
    }

    /// DEBUG: 決勝優勝が確定する（winFinale）まで自動プレイ。自由週はバイトで破産回避。
    /// DEBUG: 本番前カード（gpRound / gpFinal）の手前で止まる（MZ_UI=prelude/prelude_final）
    func debugAdvanceToPrelude(final: Bool, maxSteps: Int = 500) {
        var steps = 0
        while !finished, steps < maxSteps {
            steps += 1
            if pendingResult != nil { acknowledgeResult(); continue }
            switch phase {
            case .gpRound: if !final { return }; advanceAuto()
            case .gpFinal: return
            case .gpRevival: advanceAuto()
            case .tournamentDecision: decideTournament(.夜行バス)
            case .freeAction: choose(.job(.標準))
            default: return
            }
        }
    }

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

    /// DEBUG: 今の年を年末（finished）まで自動プレイ（翌年へは進まない）
    func debugAdvanceToYearEnd() {
        var steps = 0
        while !finished, !winFinale, steps < 600 {
            steps += 1
            if watchingFinal { finishWatchingFinal(winner: "—"); continue }
            if pendingChoiceEvent != nil { dismissChoiceEvent(); continue }
            if pendingResult != nil { acknowledgeResult(); continue }
            switch phase {
            case .tournamentDecision: decideTournament(.新幹線)
            case .freeAction:
                if state.money < 250_000 { choose(.job(.標準)) }
                else if state.stamina >= 45 { choose(.train(.ネタ作り)) }
                else { choose(.rest(.完全休養)) }
            case .gpRound, .gpRevival, .gpFinal: advanceAuto()
            default: steps = 600
            }
        }
    }

    /// QA用（複数年）: n 年ぶん年末まで自動プレイして翌年へ進める（MZ_YEARS=n）。区切りに当たったら止まる。
    /// 自由週は「金が細ればバイト・体力があればネタ作り・無ければ休む」の素朴な台本（夜逃げで止まらないように）。
    func debugAdvanceYears(_ n: Int) {
        let care = ProcessInfo.processInfo.environment["MZ_CARE"] == "1"
        for _ in 0..<n {
            var steps = 0
            while !finished, !winFinale, steps < 600 {
                steps += 1
                if watchingFinal { finishWatchingFinal(winner: "—"); continue }
                if pendingChoiceEvent != nil { dismissChoiceEvent(); continue }
                if pendingResult != nil { acknowledgeResult(); continue }
                switch phase {
                case .tournamentDecision: decideTournament(.新幹線)
                case .freeAction:
                    debugFreeWeek(care: care)
                case .gpRound, .gpRevival, .gpFinal: advanceAuto()
                default: steps = 600
                }
            }
            guard finished, !careerOver else { return }
            startNextYear()
        }
        // MZ_STOPWEEK=w: 今の年の第w週の自由行動の手前まで同じ台本で進めて止める（10年目の年末を手で遊ぶ用）
        if let w = Int(ProcessInfo.processInfo.environment["MZ_STOPWEEK"] ?? ""), w > 0 {
            var steps = 0
            while !finished, !winFinale, steps < 600 {
                if case .freeAction = phase, week >= w, pendingResult == nil, pendingChoiceEvent == nil, !watchingFinal { return }
                steps += 1
                if watchingFinal { finishWatchingFinal(winner: "—"); continue }
                if pendingChoiceEvent != nil { dismissChoiceEvent(); continue }
                if pendingResult != nil { acknowledgeResult(); continue }
                switch phase {
                case .tournamentDecision: decideTournament(.新幹線)
                case .freeAction: debugFreeWeek(care: care)
                case .gpRound, .gpRevival, .gpFinal: advanceAuto()
                default: steps = 600
                }
            }
        }
    }

    /// 自由週の台本。care=true（MZ_CARE=1）は相方を大事にする：体力に余裕があれば週に一度ネタ合わせ・隔週で相方と過ごす。
    private func debugFreeWeek(care: Bool) {
        if care {
            if state.money < 250_000 { choose(.job(.標準)) }
            else if state.stamina < 45 { choose(.rest(.相方と過ごす)) }
            else if week % 2 == 0 { choose(.rest(.相方と過ごす)) }
            else if activeNetas.isEmpty { choose(.train(.ネタ作り)) }   // 書かないままだと6年目でも「まだネタがない」の画面になっていた（10/26 定期の目視）
            else { choose(.train(.ネタ合わせ)) }
            return
        }
        if state.stamina < 25 { choose(.rest(.完全休養)) }   // 体力が尽きるまでバイトを続けて、目視の画面が「体力0」ばかりになっていた（blank_weeks_screen_check_1026_v0）
        else if state.money < 250_000 { choose(.job(.標準)) }
        else if state.stamina >= 45 { choose(.train(.ネタ作り)) }
        else { choose(.rest(.完全休養)) }
    }

    /// QA用: 年末（S4）まで一気に自動プレイ（結果は自動で送る）。
    func debugPlayToEnd(maxSteps: Int = 400) {
        var steps = 0
        while !finished, steps < maxSteps {
            steps += 1
            if pendingResult != nil { acknowledgeResult(); continue }
            switch phase {
            case .tournamentDecision: decideTournament(.夜行バス)
            case .freeAction:         choose(state.stamina >= 40 ? .job(.標準) : .rest(.完全休養))   // 休むだけだと数年目で夜逃げの年になる（playtest_v11 #1）＝バイトと休みを交互に
            case .gpRound, .gpRevival, .gpFinal: advanceAuto()
            default: return
            }
        }
    }
    #endif

    private func summarize(_ s: WeekSummary) -> String { Self.summarize(s) }
    static func summarize(_ s: WeekSummary) -> String {
        let parts = s.results.map { r -> String in
            let mark = r.isStage ? (r.passed ? (r.prize > 0 ? "優勝" : "通過") : "敗退") : "休"   // 賞金の出る勝ち＝その大会の優勝（結果の札と同じ言葉）   // 体調ダウン/療養は合否でなく「休」（監査§1-4-5・Fable13§2）
            let prize = r.prize > 0 ? " +\(r.prize / 10000)万" : ""
            return "\(GPName.display(r.name)) \(mark)\(prize)"
        }
        return "第\(s.week)週: " + parts.joined(separator: " / ")
    }
}

#if DEBUG
// MARK: QA自己点検（MZ_SMOKE=selftest で RootView.task から呼ぶ・標準出力に [ST] 行だけ出す・実プレイ非経路）
extension GameSession {
    /// 区切り（careerOver）まで自動プレイ。止まったら nil。firedKinds に出た選択肢イベントを集計
    static func debugSelfPlay(_ s: GameSession, pick: Int = 0, kinds: inout [String: Int], maxSteps: Int = 40000) -> String? {
        var steps = 0
        while steps < maxSteps {
            steps += 1
            if s.winFinale { s.acknowledgeWin(); continue }
            if s.finished { if s.careerOver { return nil }; s.startNextYear(); continue }
            if s.watchingFinal { s.finishWatchingFinal(winner: "—"); continue }
            if let k = s.pendingChoiceEvent {
                kinds["\(k)", default: 0] += 1
                let cs = s.availableEventChoices()
                if !cs.isEmpty { s.applyEventChoice(cs[min(pick, cs.count - 1)].id) }
                s.dismissChoiceEvent(); continue
            }
            if s.pendingResult != nil { s.acknowledgeResult(); continue }
            switch s.phase {
            case .tournamentDecision: s.decideTournament(.新幹線)
            case .freeAction:
                if s.state.money < 250_000 { s.choose(.job(.標準)) }
                else if s.state.stamina >= 45 { s.choose(.train(.ネタ作り)) }
                else { s.choose(.rest(.完全休養)) }
            case .gpRound, .gpRevival, .gpFinal: s.advanceAuto()
            default: return "STUCK phase=\(s.phase) y=\(s.year) w=\(s.week)"
            }
        }
        return "STUCK steps y=\(s.year) w=\(s.week) phase=\(s.phase)"
    }

    /// 調査用: 毎週バイトを押した時の「週・所持金・保留イベント」を前後で出す（行動が捨てられていないかの確認）
    static func debugActionTrace() {
        let s = GameSession()
        for _ in 0..<8 {
            guard case .freeAction = s.phase else { break }
            if let k = s.pendingChoiceEvent { fputs("[AT] w\(s.week) PENDING-BEFORE \(k)\n", stderr); s.dismissChoiceEvent() }
            let w0 = s.week, m0 = s.state.money, st0 = s.state.stamina
            s.choose(.job(.標準))
            fputs("[AT] w\(w0)->w\(s.week) money \(Int(m0))->\(Int(s.state.money)) stamina \(Int(st0))->\(Int(s.state.stamina)) lastAction=\(String(describing: s.lastAction)) pendingAfter=\(String(describing: s.pendingChoiceEvent))\n", stderr)
        }
    }

    static func debugSelfTest() {
        func line(_ s: String) { fputs("[ST] \(s)\n", stderr) }
        var kinds: [String: Int] = [:]
        func report(_ label: String, _ s: GameSession, _ stuck: String?) {
            let o = s.outcome
            let e = s.endingID
            if let e { EndingBook.record(e, partner: Names.partner) }
            line("\(label): y=\(s.year) w=\(s.week) champ=\(o?.champion ?? false) bank=\(o?.bankrupt ?? false) diss=\(o?.dissolved ?? false) compat=\(s.state.compat) money=\(s.state.money) rift=\(s.state.rift ?? -1) ending=#\(e?.number ?? 0) \(stuck ?? "ok")")
        }
        GameSession.store.removeObject(forKey: EndingBook.key)
        // 1 夜逃げ
        do { var st = GameState(config: GameConfig()); st.compat = 10; st.money = GameConfig().bankruptLine + 5000
             let s = GameSession(startState: st); var k = [String: Int]()
             var steps = 0
             while !s.finished, steps < 500 { steps += 1
                 if s.pendingChoiceEvent != nil { s.dismissChoiceEvent(); continue }
                 if s.pendingResult != nil { s.acknowledgeResult(); continue }
                 switch s.phase { case .tournamentDecision: s.decideTournament(nil); case .freeAction: s.choose(.rest(.完全休養)); case .gpRound, .gpRevival, .gpFinal: s.advanceAuto(); default: steps = 500 } }
             _ = k; k = [:]
             report("#1 nightEscape", s, s.finished ? nil : "STUCK") }
        // 2 解散（既定bot・シード数本）
        for seed in [424242, 1, 2, 3] as [UInt64] {
            let s = GameSession(seed: seed); let r = debugSelfPlay(s, kinds: &kinds); report("#2 dissolve seed=\(seed)", s, r)
        }
        // 2b 解散（rift を直接上げる）
        do { var st = GameState(config: GameConfig()); st.compat = 4; st.money = 500_000; st.rift = 97; st.riftWarned = true
             let s = GameSession(startState: st); let r = debugSelfPlay(s, kinds: &kinds); report("#2b rift97", s, r) }
        // 7/8 優勝
        for c in [19.0, 10.0] {
            var st = GameSession.debugMaxedState(); st.compat = c
            let s = GameSession(startState: st); s.debugAdvanceToChampionFinale(); s.acknowledgeWin()
            report("champ compat=\(c)", s, s.finished ? nil : "STUCK")
        }
        // 10年完走（相性上限・能力マックス）／能力なし
        for (n, mk) in [("maxed", true), ("plain", false)] {
            var st = mk ? GameSession.debugMaxedState() : GameState(config: GameConfig()); st.compat = 20; st.money = 800_000
            if mk { st.センス = 60; st.発想 = 60; st.表現 = 60; st.華 = 60 }
            let s = GameSession(startState: st); let r = debugSelfPlay(s, kinds: &kinds); report("10y \(n) compat20", s, r)
        }
        // 10年完走（riftOn=false で解散を外す）: 能力・相性を変えて #3〜#6 に到達するか
        for (n, ab, c) in [("weak c5", 20.0, 5.0), ("weak c20", 20.0, 20.0), ("mid c5", 70.0, 5.0), ("mid c20", 70.0, 20.0), ("high c5", 95.0, 5.0)] {
            var cfg = GameConfig(); cfg.riftOn = false
            var st = GameState(config: cfg); st.センス = ab; st.発想 = ab; st.表現 = ab; st.華 = ab; st.メンタル = ab; st.compat = c; st.money = 800_000
            let s = GameSession(config: cfg, startState: st); var k = [String: Int](); let r = debugSelfPlay(s, kinds: &k, maxSteps: 60000)
            report("10y norift \(n)", s, r)
        }
        // 判定表（#3〜#6）
        let o = YearOutcome(champion: false, roundsPassed: 2, reachedFinal: false)
        let rec = { (f: Bool) in GameSession.YearRecord(year: 1, roundsPassed: 1, reachedFinal: f, champion: false, bankrupt: false, prize: 0) }
        for (f, c) in [(false, 5.0), (false, 16.0), (true, 5.0), (true, 16.0)] {
            line("judge finals=\(f) compat=\(c) -> #\(EndingID.judge(outcome: o, compat: c, history: [rec(f)], year: 10, careerYears: 10)?.number ?? 0)")
        }
        line("book=\(EndingBook.load().keys.map { $0.number }.sorted())")
        // 0050 予告（rift 49 開始・compat 低）
        for pick in [0, 1] {
            var st = GameState(config: GameConfig()); st.compat = 3; st.money = 500_000; st.rift = 49
            let s = GameSession(startState: st); var seen = false; var steps = 0
            while steps < 3000, !s.finished { steps += 1
                if s.pendingChoiceEvent == .riftWarning {
                    let before = s.state.rift ?? 0
                    let cs = s.availableEventChoices(); s.applyEventChoice(cs[min(pick, cs.count - 1)].id)
                    line("0050 fired y=\(s.year) w=\(s.week) choices=\(cs.map { $0.id }) pick=\(pick) rift \(before)->\(s.state.rift ?? -1) stamina=\(s.state.stamina) choice=\(s.riftWarnChoice ?? "-")")
                    s.dismissChoiceEvent(); seen = true; break }
                if s.pendingChoiceEvent != nil { s.dismissChoiceEvent(); continue }
                if s.pendingResult != nil { s.acknowledgeResult(); continue }
                switch s.phase { case .tournamentDecision: s.decideTournament(.新幹線); case .freeAction: s.choose(.rest(.完全休養)); case .gpRound, .gpRevival, .gpFinal: s.advanceAuto(); default: steps = 3000 } }
            if !seen { line("0050 NOT FIRED pick=\(pick) rift=\(s.state.rift ?? -1) warned=\(s.state.riftWarned ?? false)") }
        }
        // 週次抽選（0041〜0049）を多シードで集計
        var wk: [String: Int] = [:]
        for seed in 1...60 {
            var st = GameState(config: GameConfig()); st.compat = 20; st.money = 300_000
            let s = GameSession(seed: UInt64(seed) &* 7919, startState: st); var k = [String: Int]()
            _ = debugSelfPlay(s, kinds: &k, maxSteps: 12000)
            for (a, b) in k { wk[a, default: 0] += b }
        }
        line("weekly kinds over 60 seeds: " + wk.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " "))
        // 古いセーブ
        do { var st = GameState(config: GameConfig()); st.compat = 10; st.money = 500_000
             let s = GameSession(startState: st); s.debugAdvanceYears(1); s.saveNow()
             if let d = UserDefaults.standard.data(forKey: "manzai.save.v1"), var o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                 for k in ["version", "yearStartState", "yearHistory", "debtWarnTier", "myName", "partnerName", "comboKind", "meetingKind", "didFireRiftWarn", "riftWarnChoice", "didShowRiftHint", "didFireLostRehearsal", "didFirePassFork", "didFireEve", "didWatchFinal"] { o.removeValue(forKey: k) }
                 if var r = o["runner"] as? [String: Any], var stt = r["state"] as? [String: Any] {
                     for k in ["rift", "riftWarned", "riftWeekStartCompat", "dissolved"] { stt.removeValue(forKey: k) }
                     r["state"] = stt; o["runner"] = r
                 }
                 UserDefaults.standard.set(try! JSONSerialization.data(withJSONObject: o), forKey: "manzai.save.v1")
                 let l = GameSession.loadedOrNew()
                 line("oldsave restored=\(l.isRestored) y=\(l.year) w=\(l.week) broken=\(UserDefaults.standard.data(forKey: "manzai.save.v1.broken") != nil)")
                 var k2 = [String: Int](); let r2 = debugSelfPlay(l, kinds: &k2, maxSteps: 3000); line("oldsave play: \(r2 ?? "ok") y=\(l.year)")
             } else { line("oldsave: no save written") }
             UserDefaults.standard.removeObject(forKey: "manzai.save.v1"); UserDefaults.standard.removeObject(forKey: "manzai.save.v1.broken") }
        GameSession.store.removeObject(forKey: EndingBook.key)
        // 結果画面の「次へ」二度押しで週が2つ進まない（code_review_2026-10-19c §2-2）
        do { let s = GameSession(startState: GameSession.debugMaxedState()); s.debugAdvanceToFirstResult()
             if s.pendingResult != nil { let w1 = { s.acknowledgeResult(); return s.week }(); s.acknowledgeResult()
                 line("double ack: second moved \(s.week - w1) \(s.week == w1 ? "ok" : "NG")") } else { line("double ack: no result") } }
        // イベントを選んだ直後の保存に保留イベントが残らない＝落として再起動しても選び直せない（code_review_2026-10-19c §1-1）
        if ProcessInfo.processInfo.environment["MZ_ALLOWSAVE"] == nil { line("choice-applied save: skip（MZ_ALLOWSAVE=1 で確かめる＝自己点検はセーブを書かない）") } else {
        do { let backup = UserDefaults.standard.data(forKey: "manzai.save.v1")   // 遊び途中のセーブを退避して最後に戻す（review_today_fixes_1019b §1）
             defer { if let backup { UserDefaults.standard.set(backup, forKey: "manzai.save.v1") } else { UserDefaults.standard.removeObject(forKey: "manzai.save.v1") } }
             let s = GameSession(startState: GameSession.debugMaxedState())
             if let (kind, c) = ChoiceEventKind.allCases.lazy.compactMap({ k -> (ChoiceEventKind, ChoiceEventChoice)? in s.debugForceEvent(k); return s.availableEventChoices().first.map { (k, $0) } }).first {
                 s.debugForceEvent(kind); s.applyEventChoice(c.id); s.saveNow()
                 let l = GameSession.loadedOrNew()
                 line("choice-applied save: \(kind) restored=\(l.isRestored) pending=\(String(describing: l.pendingChoiceEvent)) \(l.isRestored && l.pendingChoiceEvent == nil ? "ok" : "NG")")
                 s.dismissChoiceEvent()
             } else { line("choice-applied save: no event") } } }
        // 決勝の7審査員の点の和＝合計（code_review_2026-10-19h §1：頭打ちで和がずれた）。強い状態×優勝/上位×年1〜40
        var judgeSumBad = 0
        for y in 1...40 {
            for champ in [true, false] {
                let d = FinalsData(state: GameSession.debugMaxedState(), champion: champ, year: y, selfName: "あなたのコンビ")
                if d.judges.reduce(0, { $0 + $1.score }) != d.total { judgeSumBad += 1 }
            }
        }
        line("finals judge sum mismatch=\(judgeSumBad)/80 \(judgeSumBad == 0 ? "ok" : "NG")")
        line("DONE")
    }
}
#endif
