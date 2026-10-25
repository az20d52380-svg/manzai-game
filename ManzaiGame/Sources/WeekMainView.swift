// WeekMainView.swift
// SCREEN 01 育成メイン（A「削る」スライス1・docs/fun_uiux_overhaul_v0.md §5-1 A列／§6-1）。
// 上＝立ち絵シーン（左上に実力/相性の2本バー・心の声）／下＝行動カード4枚（2×2・常設）＋条件付きの小カード
// （オファー／バイト／年末へ）／最下部＝帯（年週・大会までN週・カレンダー/ネタ帳/設定・体力ゲージ・所持金）。
// 1週1タップ: カードのタップ＝二拍（Beat1 発話0.7s→choose＝1週進む→Beat2 獲得バースト）。経験点は自動で全量注がれる
// （GameSession の autoPourAllocation=true）＝のばす画面は通らない。決定ボタンは無い。
// ビート中の画面タップは即スキップ（＝早送り）＝テンポは保つ（phase遷移・RootViewは無改修）。
// 伸びの表示は GameSession.previewAfterPour（RNG非消費・golden不変）から出す。％は出さない（オーナー判断 2026-10-07）。
// 体力<staminaGate の稽古はグレー＋「谷口：今日は休め」。
//
// ⚠️ // MARK: 要Mac実機ビルド — UIは swift test で検証できない。レイアウト/ゲージ色/カード/トーストは
//    simulator でビルド→起動→目視まで確認して初めて「完了」（規律D-10）。

import SwiftUI
import GameCore

struct WeekMainView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize   // AX の大きさで行動ボタンの副題を2行まで
    @Bindable var session: GameSession
    let offer: OfferSpec?

    /// 週送りの直後だけ true。実力/相性バーにこの週の伸びをオレンジで一瞬重ねる（既存の lastGains 機構を流用）。
    @State private var gainsVisible = false
    /// 無効タップ（体力/お金不足）の一時トースト。
    @State private var toast: String?
    @State private var hint: HintSpec?       // 初回だけの短い説明（初週・生活費の前の週。`？` からも開く）
    @State private var riftNotice: String?   // 0050 の後の一言（キャリア1回）
    @State private var rent: RentStatement?   // 月末の支払い（生活費の週末・約2秒・タップで閉じる）
    @State private var rentShownKey = 0
    @State private var injuryNotice: String?   // §97 体調ダウンの知らせ（倒れた直後の週メインで1回・タップで閉じる）
    @State private var debtNotice: String?   // 借金の知らせ（週の頭・各段1回・タップで閉じる）
    @State private var youthNoticeYear = 0   // 「若手の大会は今年が最後」を出した年（年初に1回だけ）
    @State private var tiredNoticeYear = 0   // 飽きの知らせを出した年（年初に1回だけ）
    /// 実行不可カードの横ブレ（§3-1: 沈まず±3pt×2往復0.15s）。カードidごとに+1で1回震える。
    @State private var shakeSeed: [String: CGFloat] = [:]
    /// 「引き抜き」実行中のカードid（(B)版: フェード0.12s→実行。多重タップ防止を兼ねる）。
    @State private var pulledID: String?
    /// 体力ゲージの閾値跨ぎ明滅（黄=1回/赤=2回）。
    @State private var gaugeFlash = false
    /// S5ネタ帳（データ入口）を全画面表示。
    @State private var showNotebook = false
    /// S4カレンダー（最下帯のカレンダーアイコン）を全画面表示。
    @State private var showCalendar = false
    // --- 行動の二拍（パワプロ核）: タップ→Beat1 発話→週送り→Beat2 獲得バースト ---
    /// Beat1 発話バブル（表示中はモノローグを隠す）。行動タップ→一言→週送り、の一拍目。
    @State private var beatAdvice: Advice?
    /// Beat1 の進行タスク。ビート中の画面タップで cancel()→残りの間が即スキップ＝テンポは殺さない。
    @State private var beatTask: Task<Void, Never>?
    /// Beat2 獲得バースト（粒/能力/相性/体力/収支のチップ列・立ち絵の上に立ち上る）。
    @State private var burstChips: [BurstChip] = []
    @State private var burstVisible = false
    /// バースト表示中は選択肢イベントの fullScreenCover を待たせる（choose 直前に立て、退場後に必ず下ろす）。
    /// 世代トークン burstGen で「古いバーストタスクの後始末が新しい保留を下ろす」競合を防ぐ。
    @State private var burstHold = false
    @State private var burstGen = 0
    /// Beat2 をタップで畳む要求（規格K6「待ちは畳める」）。立てると Beat2 の残りの間が即終わる（退場は見せる）。
    @State private var burstSkip = false
    /// 押した行動名（perform で立て、Beat2 のタスクが結果の一行にして消費する）と、その結果札の表示。
    @State private var resultName: String?
    @State private var resultLine: String?
    /// 選択肢イベントを今出すか。pendingChoiceEvent と burstHold の「変化」で明示的に判定し直す
    /// （合成 Binding の get だけに任せると、保留が外れても提示が読み直されず、次のタップまで出ない不具合があった）。
    @State private var showEvent = false
    /// 満了成立後の週メイン初回トースト（この年1回だけ）用フラグ。
    @State private var vesselFullToastShown = false
    /// 週送りスタンプ「第N週」（週が明けた瞬間に中央で0.7sフラッシュ・触れない）。
    @State private var weekStampVisible = false
    /// Beat2 と同時に爆ぜる獲得パーティクル（+1で一回・Juice.swift）。
    @State private var particleFire = 0
    /// 週頭の掛け合いのタップ送り位置（週が明けたら0に戻す）。
    @State private var banterIndex = 0
    /// Beat1 の一言を最後に出した週（変種ごと）。直近4週に出した変種は一言を省く＝最頻出テキストの間引き（監査A-04）
    @State private var lastBeatWeek: [String: Int] = [:]
    /// 「年末へ」の二度押し確認（監査A-03）
    @State private var yearEndArmed = false
    /// オファーを受ける前の二度押し確認（誤タップ事故＝playtest_v6 W31〜W34）
    @State private var offerArmed = false
    /// オファーの帯の実際の高さ（声の席をこの分だけ上げる＝固定値だと帯に吹き出しが重なった）
    @State private var offerBandH: CGFloat = 0
    /// 進行中の設定（監査G-04）
    @State private var showSettings = false
    @State private var showFarewell = false   // 設定の「解散」の後の別れの場面（図鑑に入れない）
    /// 買い物（ShopView・アイテム）
    @State private var showShop = false
    /// 能力アップ（AllocationView・経験点を能力に振る）
    @State private var showAllocation = false

    #if DEBUG
    /// 目視用: MZ_WEEK で週メインの下位画面へ直行（practice/baito/rest/netawrite/newneta/shop/allocate/settings/notebook/calendar）
    private func debugWeekHook() {
        guard let w = ProcessInfo.processInfo.environment["MZ_WEEK"] else { return }
        switch w {
        case "practice": openCat = .練習
        case "baito": openCat = .バイト
        case "rest": openCat = .休む
        case "netawrite": openCat = .ネタを書く; openNetaWrite = true
        case "newneta": openCat = .ネタを書く; openNetaWrite = true; newNetaTitle = ""
        case "netapick": openCat = .ネタを書く; openNetaWrite = true; pickingNeta = true   // 書く対象の候補（替える）を開いた状態
        case "shop": showShop = true
        case "allocate": showAllocation = true
        case "settings": showSettings = true
        case "notebook": showNotebook = true
        case "calendar": showCalendar = true
        case "rent":   // 月末の支払いの目視: 休むカードを1回実行（MZ_UI=rent と併用）
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if let v = CommandCatalog.cards(.休む, config: session.config, money: s.money).first { perform(v) }
            }
        case "autojob":   // 結果札の目視: 2.5秒おきにバイトを自動実行（結果→次週のイベントの順を撮る）
            Task {
                for _ in 0..<3 {
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    if let v = CommandCatalog.cards(.バイト, config: session.config, money: s.money).first, session.pendingChoiceEvent == nil { perform(v) }
                }
            }
        default: break
        }
    }
    #else
    private func debugWeekHook() {}
    #endif

    private var s: GameState { session.state }
    /// 開いている4ボタンの下位一覧（nil＝4ボタン）。パワプロ式（オーナー指示 2026-10-12）
    @State private var openCat: CommandCategory?
    /// 練習の一覧で「選んだ（ハイライト中）」カードのID。もう一度押すと実行（パワプロの練習メニュー式・2026-10-18）
    /// 練習→ネタを書く の下の「どのネタを磨くか」一覧を開いているか
    @State private var openNetaWrite = false
    @State private var titleDiceStep = 0
    /// 新しいネタの題名入力（nil＝入力欄を閉じている）。空欄で書く＝おまかせの題名
    @State private var newNetaTitle: String?
    /// 「書くネタ」を替える一覧を開いているか
    @State private var pickingNeta = false
    /// 書いた直後に付ける題名（新ネタの id と題名）
    @State private var pendingNetaTitle: (id: Int, title: String)?
    private var mainCards: [CommandVariant] {
        CommandCatalog.mainCards(config: session.config, money: s.money)
    }
    /// キュー96：今週の札（知名度で1〜3枚）。選んでいる札が activeOffer
    @State private var offerPick = 0
    private var offers: [OfferSpec] { session.offerChoices ?? (offer.map { [$0] } ?? []) }
    private var activeOffer: OfferSpec? { offers.indices.contains(offerPick) ? offers[offerPick] : offer }
    private var offerCard: CommandVariant? {
        extraCards.first { if case .acceptOffer = $0.action { return true } else { return false } }
    }
    private var extraCards: [CommandVariant] {
        CommandCatalog.extraCards(config: session.config, offer: activeOffer, money: s.money, fatigued: session.offerFatigued)
    }

    var body: some View {
        VStack(spacing: 0) {
            stageHeaderBand
            goalBanner
            weekHintLine
            sceneZone
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            commandZone
            botbar
        }
        // 立っているイベントがまだ出ていない間（獲得の一拍待ち等）は週メインの操作を受けない＝直後に割り込まれてタップが消えない
        .allowsHitTesting(!(session.pendingChoiceEvent != nil && !showEvent && pulledID == nil))   // 札を引いている途中は止めない（出せないイベントで固まらない）
        // パワプロ・サクセスの文法＝日常パートは明るくポップ（暗転は本番系画面の語彙）。
        .background(Theme.kinari.ignoresSafeArea())
        .fullScreenCover(isPresented: $showNotebook) {
            NotebookView(session: session) { instant { showNotebook = false } }.modifier(FadeInOnAppear())   // S5 ネタ帳
        }
        .fullScreenCover(isPresented: $showCalendar) {
            CalendarView(session: session) { instant { showCalendar = false } }.modifier(FadeInOnAppear())   // S4 年間カレンダー
        }
        .fullScreenCover(isPresented: Binding(
            // Beat2 バースト表示中は提示を待たせる（burstHold）＝獲得の一拍がcoverに隠れない。
            // 提示の判定は syncEventPresentation（イベントが立った／保留が外れた の変化で呼ぶ）に一本化。
            get: { showEvent },
            set: { if !$0 { instant { showEvent = false }; session.dismissChoiceEvent() } }
        )) {
            // 選択肢イベント（0024ピース3・確定発火）。pendingChoiceEvent は private(set) なので
            // Bool の合成 Binding 経由（既存 showNotebook 等と同じ isPresented パターン）。
            if let kind = session.pendingChoiceEvent {
                ChoiceEventOverlay(session: session, kind: kind) {}.modifier(FadeInOnAppear())
            }
        }
        .fullScreenCover(isPresented: $showAllocation) {
            AbilityUpView(session: session) { instant { showAllocation = false } }.modifier(FadeInOnAppear())
        }
        .fullScreenCover(isPresented: $showShop) {
            ShopView(session: session) { instant { showShop = false } }.modifier(FadeInOnAppear())
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(onClose: { showSettings = false },
                         onQuitRun: { showSettings = false; showFarewell = true })
        }
        .overlay {
            if showFarewell {
                DisbandFarewellView(bestLine: session.bestRunLine) { session.abandonRun() }
                    .zIndex(10)
            }
        }
        .overlay { burstCostOverlay }
        .overlay {
            if let r = rent { RentStatementView(statement: r) { rent = nil }.transition(.opacity) }
        }
        .overlay {
            if let m = injuryNotice {
                YoseModal(title: "体調ダウン", primaryTitle: "わかった", primaryAction: { injuryNotice = nil }, cancelTitle: nil) {
                    Text(m).font(YoseFont.gothic(15, weight: .bold)).foregroundStyle(YoseColor.sumi)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .overlay {
            if let m = debtNotice {
                YoseModal(title: "借金", primaryTitle: "わかった", primaryAction: { debtNotice = nil }, cancelTitle: nil) {
                    Text(m).font(YoseFont.gothic(15, weight: .bold)).foregroundStyle(YoseColor.sumi)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .overlay {
            if let m = riftNotice {
                YoseModal(title: "コンビ", primaryTitle: "わかった", primaryAction: { riftNotice = nil }, cancelTitle: nil) {
                    Text(m).font(YoseFont.gothic(15, weight: .bold)).foregroundStyle(YoseColor.sumi)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .overlay {
            if let h = hint {
                HintModal(spec: h) { OneTimeHint.markDone(h.key); hint = nil }
            }
        }
        .overlay(alignment: .bottom) {
            // トーストは最下帯の上+16pt（§3-5）
            toastBar.animation(.easeOut(duration: 0.2), value: toast)
        }
        .overlay {
            // Beat1 中は全面でタップを受けて即スキップ（＝早送り）。ビート中の誤タップで
            // 別カードが暴発しない安全網を兼ねる。Beat2（獲得チップ）中のタップは残りの間を畳む（K6）。
            if pulledID != nil {
                Color.clear.contentShape(Rectangle())
                    .onTapGesture { beatTask?.cancel() }
                    .accessibilityHidden(true)
            } else if burstHold {
                // 獲得チップ中のタップ：舞台側（上半分）だけで畳む。下の行動ボタンは覆わない（押した行動は tapOrQueue が畳んで予約実行）
                GeometryReader { g in
                    Color.clear.contentShape(Rectangle()).frame(height: g.size.height * 0.5)
                        .onTapGesture { burstSkip = true }
                        .accessibilityHidden(true)
                }
            }
        }
        .onChange(of: burstHold) { _, holding in
            // 保留が外れたら、チップが引いた後に0.3秒の間を置いてから、立っているイベントを出す（G2）。
            guard !holding else { return }
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                syncEventPresentation()
                try? await Task.sleep(nanoseconds: 300_000_000)
                maybeShowDebtNotice()   // 支払いの画面の後に借金の知らせ（イベントが立っていれば出ない）
            }
        }
        .onChange(of: session.pendingChoiceEvent) { _, kind in
            if kind == nil { instant { showEvent = false }; Task { try? await Task.sleep(nanoseconds: 500_000_000); maybeShowDebtNotice(); maybeShowFirstHints() } } else { syncEventPresentation() }
        }
        .onAppear { debugWeekHook(); syncEventPresentation(); Task { try? await Task.sleep(nanoseconds: 700_000_000); maybeShowTiredNotice(); maybeShowLastYouthNotice(); maybeShowDebtNotice(); try? await Task.sleep(nanoseconds: 600_000_000); maybeShowFirstHints() } }   // 中断セーブ復帰・MZ_UI=event など、最初から立っている時
        .task(id: session.week) {
            // 初回だけの説明（初週／最初の生活費の前の週）。獲得バースト・イベントが落ち着いてから。
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            maybeShowFirstHints()
        }
        .task(id: session.week) {
            // 新しい週に入ったら、この週の伸びをバーにオレンジで一瞬見せる（実力＝自動注ぎ後の能力差分・相性）。
            if !session.lastGains.isEmpty || session.lastCompatGain > 0.001 {
                gainsVisible = true
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                gainsVisible = false
            }
        }
        .task(id: session.week) {
            // Beat2 獲得の一拍: この週の行動で伸びた実力/相性/ネタ/体力をチップ（最大3枚）で立ち上げる
            // （状態差分駆動・入力遮断なし・RNG非消費）。lastDeltaWeek ゲートで、大会画面を挟んで
            // 戻った時に古い増減が再生される事故を防ぐ。終端で burstHold を必ず下ろす（世代一致時のみ＝
            // 週送り直後に旧タスクの後始末が新しい保留を下ろす競合を防ぐ）。
            let gen = burstGen
            burstSkip = false
            defer { if gen == burstGen { burstHold = false } }
            // 後始末（一言を消す等）は世代が一致する時だけ＝旧週のタスクの続きが次週の Beat1 を消さない（X4-04）。
            @MainActor func clearBeat() { if gen == burstGen { withAnimation(Theme.Motion.exit) { beatAdvice = nil } } }
            guard session.lastDeltaWeek == session.week else { resultName = nil; clearBeat(); return }
            let chips = makeBurstChips()
            let line = makeResultLine()
            resultName = nil
            guard !chips.isEmpty || line != nil else { clearBeat(); await presentRent(); return }
            burstChips = chips
            if let line { withAnimation(Theme.Motion.appear) { resultLine = line } }
            defer { if resultLine != nil { withAnimation(Theme.Motion.exit) { resultLine = nil } } }
            burstVisible = true   // 出現は per-chip の emphSpring+stagger（burstOverlay 側）
            if chips.contains(where: \.up) {
                particleFire += 1     // 同時に立ち絵の頭上で火花が爆ぜる（獲得の「効いた」）
                // 獲得の音: 実力が伸びた週はキラキラ＞汎用ポップ。収支が動いた週はお金の音も重ねる。
                Sound.play(lastJitsuryokuGain > 0.001 ? .grain : .pop)
            }   // 体力が減るだけの週は火花も集中線も音も出さない（損を祝わない・R4 の穴①）
            if session.lastMoneyDelta > 0 { Sound.play(.money) }
            await waitOrSkip(seconds: chips.isEmpty ? 1.0 : 1.2)   // 画面タップで畳める（K6）
            clearBeat()
            burstVisible = false   // 退場も per-chip アニメ（下へ沈みつつフェード）
            try? await Task.sleep(nanoseconds: 250_000_000)   // 退場を見せ切ってから cover 解禁（defer）
            await presentRent()   // 生活費の週末：獲得の後・次の週のイベントより前に支払いの画面
        }
        .task(id: session.week) {
            // 週送りスタンプ: 週が明けたら「第N週」を一拍（出現spring→0.7s→退場）。入力は遮らない。
            if session.week > 1 { Sound.play(.transition) }   // 週めくりの音（初週の起動時は鳴らさない）
            withAnimation(Theme.Motion.emphSpring) { weekStampVisible = true }
            try? await Task.sleep(nanoseconds: 700_000_000)
            withAnimation(Theme.Motion.exit) { weekStampVisible = false }
        }
        .onAppear { Sound.bgm(.daily) }   // 育成パートのBGM（大会系画面から戻った時も復帰）
        .onChange(of: session.year) { _, _ in maybeShowTiredNotice(); maybeShowLastYouthNotice() }
        .onChange(of: session.week) { _, _ in
            offerPick = 0   // キュー96：週が変わったら札の選びを先頭に戻す
            banterIndex = 0
            Task { try? await Task.sleep(nanoseconds: 2_000_000_000); maybeShowDebtNotice() }   // 週メインへ戻った後（Beat演出のあと）
        }   // 掛け合いの読み位置は週頭でリセット
        .task(id: toast) {
            if let t = toast {
                try? await Task.sleep(nanoseconds: t.count > 30 ? 4_500_000_000 : t.count > 20 ? 2_600_000_000 : 1_400_000_000)
                toast = nil
            }
        }
        .onChange(of: vesselIsFull) { _, full in
            // §4 満了成立時の週メイン初回だけトースト（この年1回・Notebook/トーストの二面が同じ一文）。
            // 自動注ぎ＝満了は行動の週送りで成立する＝ここ一経路で拾える。
            maybeShowVesselFullToast(full)
        }
    }

    // MARK: 立ち絵シーン（左上の実力/相性バー・心の声）

    /// 共通ヘッダー帯（YoseHeaderBar・臙脂は上端まで）。
    private var stageHeaderBand: some View {
        YoseHeaderBar(title: "\(session.year)年目　第\(session.week)週")
    }

    private var sceneZone: some View {
        sceneBackground
            .background(Color(hex: 0xFFFBF0).ignoresSafeArea(edges: .top))   // ステータスバー裏も稽古場の白
            // 上端中央の目標バナー（2行になる週がある）の下に置く＝重ならない
            .overlay(alignment: .topTrailing) { statBars.padding(.trailing, YoseMetrics.screenMargin).padding(.top, 8) }
            .overlay(alignment: .topLeading) {
                HintMarkButton { hint = Self.firstWeekHint }   // 用語の「？」（初回の説明を開き直す）
                    .padding(.leading, YoseMetrics.screenMargin - 10).padding(.top, 0)
            }
            .overlay(alignment: .bottom) {
                // オファーの帯：舞台の下端（＝行動ボタンの直上）に載せる。レイアウトに参加しない＝ボタンの位置は動かない。下位一覧を開いている間は隠す
                if openCat == nil, let o = offerCard {
                    VStack(spacing: 4) {
                        if offers.count > 1 { offerPicker }   // キュー96：知名度が上がると札が増える＝横に並べて1つ選ぶ（選ばなければ他の行動＝断る）
                        #if DEBUG
                        if ProcessInfo.processInfo.environment["MZ_TVTIRED"] != nil {   // キュー112 の見本：テレビ慣れを状態名で小さく出す（数字・％なし）。本編には出さない
                            HStack(spacing: 6) {
                                Text("テレビ慣れ").font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.kinari)
                                    .padding(.horizontal, 6).padding(.vertical, 2).background(YoseColor.shu)
                                Text(session.offerFatigued ? "続けて受けると、センスと表現が少し鈍る" : "（今は平気）").font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.sumi)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4).background(YoseColor.kinari)
                            .overlay(Rectangle().stroke(YoseColor.shu, lineWidth: 1))
                        }
                        #endif
                        actionCard(o, compact: true, dashed: false, row: true)   // 全幅の2段（名前／効果と収入を1行）＝帯を低くして声と人物を押し上げない
                    }
                        .fixedSize(horizontal: false, vertical: true)
                        .background(GeometryReader { g in
                            Color.clear.onAppear { offerBandH = g.size.height }
                                .onChange(of: g.size.height) { _, h in offerBandH = h }
                        })
                        .padding(.horizontal, YoseMetrics.screenMargin).padding(.bottom, 4)
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .bottomLeading) {
                // 声の席は一つ: Beat1 発話 > 週頭の掛け合い（タップ送り） > 独白。
                Group {
                if openCat != nil && beatAdvice == nil {
                    EmptyView()   // 下位一覧を開いている間は声を出さない（舞台が狭くなっても重ならない）
                } else if let b = beatAdvice {
                    adviceBox(b).padding(YoseMetrics.screenMargin)
                } else if let lines = session.weekBanter, !lines.isEmpty {
                    banterBox(lines).padding(YoseMetrics.screenMargin)
                } else if offerCard == nil || openCat != nil {
                    monoBox.padding(YoseMetrics.screenMargin)
                }   // オファーの帯が出ている週は独白を出さない（帯＋吹き出しで舞台の二人が隠れた・ui_sweep_2026-10-18）
                }
                .padding(.bottom, offerCard != nil && openCat == nil ? max(0, offerBandH + 14 - YoseMetrics.screenMargin) : 0)   // オファーの帯（下の余白4＋隙間10）の上に声を載せる
            }
            .overlay {
                // Beat2 と同時: 集中線（漫画のドン！）＋二人の頭上で獲得チップ同色の火花。
                SpeedLinesBurst(trigger: particleFire, center: UnitPoint(x: 0.62, y: 0.55))
                ParticleBurst(trigger: particleFire,
                              colors: [YoseColor.kinBright, YoseColor.shu, YoseColor.kin],
                              style: .spark, count: 26,
                              origin: UnitPoint(x: 0.62, y: 0.60))
            }
            .overlay(alignment: .bottomTrailing) {
                // Beat2 獲得バースト: 立ち絵の頭上に獲得チップが立ち上る（触れない・入力遮断なし）。
                // 人形の大型化に合わせ頭上へ逃がす（頭に被ると谷口が首なしに見える）。
                burstOverlay
                    .padding(.trailing, 50).padding(.bottom, 206)   // 谷口のめくりの頭の上（名前の字に被せない）
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .top) {
                // 結果札: 押した行動の実際の増減を一行で（次の週のイベントより先に見せる・触れない）。
                if let line = resultLine {
                    Text(line)
                        .font(YoseFont.gothic(15, weight: .heavy)).foregroundStyle(YoseColor.kinari)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(YoseColor.kuroUrushi)
                        .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1.5).padding(2))
                        .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))
                        .padding(.top, 74)
                        .transition(.asymmetric(insertion: .scale(scale: 0.88).combined(with: .opacity), removal: .opacity))
                        .allowsHitTesting(false)
                }
                // 週送りスタンプ: 週が明けた瞬間に「第N週」が一拍だけ立つ（Beat2 の前座・触れない）。
                // 黒漆の横札＋金枠（YoseToast と同じ語彙）。めくり札・マイクに被らない舞台の上段に掲げる。
                if weekStampVisible {
                    Text("第\(session.week)週")
                        .font(YoseFont.gothic(16, weight: .heavy)).tracking(6).foregroundStyle(YoseColor.kin)
                        .padding(.horizontal, 18).padding(.vertical, 7)
                        .background(YoseColor.kuroUrushi)
                        .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1.5).padding(2))
                        .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))
                        .padding(.top, 14)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.82).combined(with: .opacity),
                            removal: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .clipped()
    }

    /// 常時目標バナー: 次の本番と残り週（残3週以下は「追い込み」の朱）。次が遠い週は仕込みの副目標を添える。
    @ViewBuilder private var goalBanner: some View {
        // 今年の大会が全部終わった後は、帯だけ年末までの週を出す（playtest_v11 #4。独白・経験点の注意は大会基準のまま）
        if let m = bannerMilestone() {
            let hot = m.weeksLeft <= 3
            Button { instant { showCalendar = true } } label: {
                VStack(spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.fill").font(.system(size: Font.mzScaled(11))).accessibilityHidden(true)   // 12pt 未満の例外：アイコン記号（文字ではない）
                            .foregroundStyle(hot ? YoseColor.shu : YoseColor.kin)
                        if m.weeksLeft <= 0 {
                            Text("\(m.name)　今週！")
                                .font(YoseFont.gothic(16, weight: .black)).foregroundStyle(YoseColor.kinBright)
                                .lineLimit(1).minimumScaleFactor(0.6)
                        } else {
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("\(m.name) まで あと").font(YoseFont.gothic(15, weight: .heavy)).foregroundStyle(YoseColor.kin)
                                Text("\(m.weeksLeft)").font(YoseFont.number(24, weight: .black))
                                    .foregroundStyle(YoseColor.kinBright)
                                    .contentTransition(.numericText())
                                Text("週").font(YoseFont.gothic(15, weight: .heavy)).foregroundStyle(YoseColor.kin)
                            }
                            .lineLimit(1).minimumScaleFactor(0.6)
                        }
                    }
                    if m.weeksLeft <= 2 && unspentBeforeStage {
                        // 大会前の振り忘れ（オーナー判断 2026-10-12：知らせるだけ・自動では振らない）
                        Text("経験点が残ってる。能力アップで使おう")
                            .font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.kinari)
                            .frame(maxWidth: .infinity).padding(.vertical, 3)
                            .background(YoseColor.shu)
                    } else if m.weeksLeft >= 6 && nextMilestone() != nil {
                        Text(lullLine())
                            .font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.kinari.opacity(0.85)).lineLimit(1).minimumScaleFactor(0.85)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(YoseColor.kuroUrushi)
                .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1.5))
                .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))
            }
            .buttonStyle(PressableStyle())
            .padding(.horizontal, YoseMetrics.screenMargin).padding(.top, 8).padding(.bottom, 4)
            .background(Color(hex: 0xFFFBF0))
        }
    }

    /// 目標の帯の下の一行案内（優先順で最初に当てはまる1つ。表示専用）
    private var weekHintText: String? {
        let m = nextMilestone()
        let stage = session.nextStage
        let cur = s.selectedNetaID.flatMap { id in s.netas.first { $0.id == id } } ?? s.netas.max { $0.polish < $1.polish }
        let bannerShown = (m?.weeksLeft ?? 99) <= 2 && unspentBeforeStage
        return WeekHint.line(.init(
            netaCount: s.netas.count,
            preoccupied: s.preoccupiedWeeks > 0,
            stageWeeksLeft: m?.weeksLeft, stageLength: stage?.length,
            netaFitsStage: cur.flatMap { n in stage.map { n.fits($0.length) } },
            stamina: s.stamina,
            livingThisWeek: session.week % session.config.livingInterval == 0,
            livingInTwoWeeks: (session.week + 2) % session.config.livingInterval == 0,
            money: s.money, livingCost: GameEngine.livingCostDue(s, config: session.config),   // 部屋の上乗せ込み（実際の引き落としと一致）
            weeksWithoutPartner: session.weeksWithoutPartner,
            plusAvailable: expGrains > 0 && AbilityUpView.anyPlusEnabled(session, state: s),
            expBannerShown: bannerShown))
    }

    @ViewBuilder private var weekHintLine: some View {
        if let text = weekHintText {
            Text(text)
                .font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.sumi)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 44).padding(.top, 4).padding(.bottom, 22)
                .background(Color(hex: 0xFFFBF0))
                .accessibilityIdentifier("weekHintLine")
        }
    }

    private var sceneBackground: some View {
        // 稽古場シーン（StageScene.swift）: 明るい昼の稽古場＋板張り＋センターマイク＋漫才師2人＋光の中の塵。
        // 立ち絵イラスト導入までの見た目の到達点（TODO: 本イラスト差替）。上端はステータスバー裏まで届かせる。
        StageScene(compact: openCat != nil).ignoresSafeArea(edges: .top)
    }

    // MARK: 実力・相性の2本バー（A「削る」: 能力ピル6本・谷口評の置き換え。数字は整数・％は出さない）

    /// 実力＝その年の成長の器の満ち具合（growthUsed/growthBudget）。器は実力値の伸びしろ（実力値換算）なので、
    /// バーの左端＝年初の実力値・右端＝器いっぱいの実力値、併記の数字＝いまの実力値（整数）。
    /// 相性＝0〜compatCap。能力5本の内訳はネタ帳（最下帯のアイコン）で見る。
    private var statBars: some View {
        let cfg = session.config
        let budget = s.growthBudget ?? 0
        let jitsuFill = budget > 0 ? min(1, s.growthUsed / budget) : 0
        let compatFill = min(1, max(0, s.compat / cfg.compatCap))
        // 直角の木札（幅96）。実力は特大・相性はその下。能力5本の内訳はネタ帳で見る。
        return VStack(alignment: .leading, spacing: 5) {
            statBar(name: "実力", value: GameEngine.jitsuryoku(s, config: cfg), fill: jitsuFill,
                    gainFill: budget > 0 ? lastJitsuryokuGain / budget : 0)
            if openCat == nil {   // 下位一覧を開いている間は舞台が狭いので実力だけ
            Rectangle().fill(YoseColor.kiDark).frame(height: 1)
            statBar(name: "相性", value: s.compat, fill: compatFill,
                    gainFill: max(0, session.lastCompatGain) / cfg.compatCap, big: false)
            }
        }
        .padding(.horizontal, 8).padding(.top, 9).padding(.bottom, 7)
        .frame(width: 112)
        .yoseKifuda(showNail: true)
    }

    /// 1本のバー。週送りの直後（gainsVisible）だけ、この週に伸びた分を朱で重ねる＝「押した週に何が動いたか」。
    private func statBar(name: String, value: Double, fill: Double, gainFill: Double, big: Bool = true) -> some View {
        let shown = gainsVisible && session.lastDeltaWeek == session.week ? min(gainFill, fill) : 0
        return VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(name).font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.enji)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(YoseColor.enji.opacity(0.12))
                    .overlay(Rectangle().stroke(YoseColor.enji, lineWidth: 1))
                    .fixedSize()
                Spacer(minLength: 0)
                Text("\(Int(value.rounded()))").font(YoseFont.number(big ? 28 : 18, weight: .black))
                    .foregroundStyle(YoseColor.sumi)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.3), value: Int(value.rounded()))
                    .punch(on: Int(value.rounded()), peak: 1.35)   // 整数が動いた瞬間だけ跳ねる
            }
            // 空の時は出さない（年初で器がまだ空＝何も表さない枠はバグに見える）。伸びたら現れる。
            if fill > 0.001 || shown > 0 {
                YoseGauge(value: fill, total: 1, fill: shown > 0 ? YoseColor.shu : YoseColor.enji, height: 8, showTicks: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name) \(Int(value.rounded()))")
    }

    /// 直前の週に伸びた実力値（lastGains の演技系4能力×重み＝実力値の増分。メンタルは実力値に入らない）。
    private var lastJitsuryokuGain: Double {
        let c = session.config
        return session.lastGains.reduce(0) { acc, g in
            switch g.ability {
            case .センス: return acc + g.amount * c.weightSense
            case .発想: return acc + g.amount * c.weightIdea
            case .表現: return acc + g.amount * c.weightExpr
            case .華: return acc + g.amount * c.weightChara
            case .メンタル: return acc
            }
        }
    }

    // MARK: 心の声（状態駆動モノローグ）／Beat1 発話バブル（同じ器を共用）

    private var monoBox: some View {
        adviceBox(DialogueData.innerVoice(state: s, lossStreak: session.lossStreak,
                                          justPassed: session.justPassedStage, justLost: session.justLostStage,
                                          nextMilestone: nextMilestone(), weakAbility: weakAbility(),
                                          week: session.year &* 131 &+ session.week,
                                          picker: session.picker(key: session.year &* 131 &+ session.week)))   // 年も混ぜる／直近の行は避ける＝毎年同じ週に同じ行にしない
    }

    /// 週頭の掛け合い: 1行ずつタップ送り（ChoiceEventOverlay.advance と同じ読み口）。最終行で止まる。
    private func banterBox(_ lines: [Advice]) -> some View {
        let i = min(banterIndex, lines.count - 1)
        return adviceBox(lines[i])
            .contentShape(Rectangle())
            .onTapGesture {
                if i < lines.count - 1 { withAnimation(.easeOut(duration: 0.18)) { banterIndex += 1 } }
            }
    }

    private func adviceBox(_ a: Advice) -> some View {
        // 寄席のめくり名札＋明朝の貼り紙セリフ枠（YoseSpeechBox）。
        let name = a.name ?? "俺"
        return YoseSpeechBox(speaker: name, text: a.text, roleLabel: name == "谷口" ? "相方" : (name == "俺" ? "主人公" : nil))
            .id(a.text)
            // 前の文は即座に消し、新しい文だけ淡く出す（退場と登場が同じ席で重なって二重に読めた＝playtest_v5 W20・W25）
            .transition(.asymmetric(insertion: .opacity, removal: .identity))
    }

    // MARK: 行動カード（常設4枚 2×2＋条件付きの小カード。タップ＝即実行・ゲート/¥不足は toast で無効化）

    private var commandZone: some View {
        let extras = extraCards.filter { if case .acceptOffer = $0.action { return false } else { return true } }   // オファーは行動ボタンの上の帯へ（ボタンの位置を動かさない）
        let showYearEnd = session.noStagesLeft && session.week < session.config.weeks
        return VStack(spacing: 8) {
            // 常設4枚は位置を動かさない（条件付きのカードは下に足す＝親指が覚えた場所が週ごとにずれない）
            if let cat = openCat {
                // 下位一覧：戻る（副ボタン）＋見出し＋横罫線。実行したら4ボタンへ戻る
                HStack(spacing: 10) {
                    Button { withAnimation(Theme.Motion.appearQuick) { if pickingNeta { pickingNeta = false } else { openCat = nil; openNetaWrite = false; newNetaTitle = nil } } } label: {
                        Label("もどる", systemImage: "chevron.left").font(YoseFont.gothic(13, weight: .heavy))
                    }
                    .buttonStyle(YoseButtonStyle(.secondary))
                    .frame(width: 92)
                    Text(openNetaWrite ? "ネタを書く" : cat.rawValue).font(YoseFont.sectionTitle).foregroundStyle(YoseColor.sumi)
                    Rectangle().fill(YoseColor.sumi).frame(height: 2)
                    if cat == .休む && s.stamina >= 99.5 {
                        YoseTag(text: "満タン・回復は余る", style: .outlineShu)
                    }
                }
                if openNetaWrite {
                    netaWriteList.transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    let cardList = CommandCatalog.cards(cat, config: session.config, money: s.money)
                    if cat == .練習 { practiceExpPanel(cardList) }
                    let lastAlone = cat != .バイト && cardList.count > 2 && cardList.count % 2 == 1   // 奇数枚の最後は2列ぶち抜き（空きマスを作らない）
                    VStack(spacing: 8) {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: cat == .バイト ? 1 : 2), spacing: 8) {
                            ForEach(lastAlone ? Array(cardList.dropLast()) : cardList) { v in
                                actionCard(v, compact: true, dashed: false, wide: cat == .バイト)
                            }
                        }
                        if lastAlone, let v = cardList.last { actionCard(v, compact: true, dashed: false, row: true) }
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            } else {
                // 6つを同じ大きさの2×3（オーナー 2026-10-12「視認性悪いからアイテムショップもここに」）
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 6) {
                    ForEach(CommandCategory.allCases) { c in categoryTile(c) }
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
            if !extras.isEmpty || showYearEnd {
                HStack(spacing: 10) {
                    ForEach(extras) { v in actionCard(v, compact: true) }
                    if showYearEnd { yearEndTile }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, YoseMetrics.screenMargin).padding(.top, 10).padding(.bottom, 6)
        .background(LinearGradient(colors: [.clear, Color(hex: 0xFFEFDD)], startPoint: .top, endPoint: .center))
        .animation(Theme.Motion.appearQuick, value: extras.map(\.id))
    }

    // MARK: ネタを書く（どのネタを磨くか／新しく書くか）

    /// 書く対象のネタ（エンジンの規則どおり：勝負ネタ→無ければ枠が空いていれば新ネタ→満杯なら最後のネタ）
    private var writeTarget: Neta? {
        if newNetaTitle != nil || session.writeNewNeta { return nil }
        if let n = session.writeTargetNeta { return n }
        return session.activeNetas.count < session.config.netaActiveSlots ? nil : session.activeNetas.last
    }

    /// ネタを書く＝場所の一覧（家／喫茶店／ファミレス）＋上に「書くネタ」（替える・新しく書く＋題名）
    private var netaWriteList: some View {
        let cfg = session.config
        return VStack(spacing: 8) {
            netaTargetBar
            if pickingNeta { netaPicker }
            if newNetaTitle != nil || (writeTarget == nil && !pickingNeta) { netaTitleField }
            let places = CommandCatalog.netaPlaces(config: cfg, money: s.money)
            let lastAlone = places.count > 2 && places.count % 2 == 1   // 奇数枚の最後は2列ぶち抜き
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 8) {
                ForEach(lastAlone ? Array(places.dropLast()) : places) { v in
                    actionCard(v, compact: true, dashed: false)
                }
            }
            if lastAlone, let v = places.last { actionCard(v, compact: true, dashed: false, row: true) }
        }
    }

    private var netaTargetBar: some View {
        let t = writeTarget
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t == nil ? "書くネタ" : "磨くネタ").font(YoseFont.captionBold).foregroundStyle(YoseColor.haiSumi)
                    if let n = t {
                        Text("「\(n.name)」").font(YoseFont.mincho(19)).foregroundStyle(YoseColor.sumi).lineLimit(1).minimumScaleFactor(0.8)
                    } else {
                        Text("新しいネタ").font(YoseFont.mincho(18)).foregroundStyle(YoseColor.enji)
                    }
                }
                Spacer(minLength: 4)
                if !session.activeNetas.isEmpty {
                    Button { withAnimation(Theme.Motion.appearQuick) { pickingNeta.toggle() } } label: {
                        Text(pickingNeta ? "とじる" : "替える").font(YoseFont.gothic(13, weight: .heavy))
                    }
                    .buttonStyle(YoseButtonStyle(.secondary))
                    .frame(width: 84)
                }
            }
            if let n = t {
                HStack(spacing: 8) {
                    YoseGauge(value: n.polish, total: 100, fill: YoseColor.shu, height: 12, showTicks: true).frame(width: 130)
                    Text("完成度 \(Int(n.polish.rounded()))").font(YoseFont.number(18, weight: .heavy)).foregroundStyle(YoseColor.shu).fixedSize()
                    NetaStageBadge(netaID: n.id, polish: n.polish)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .yoseKifuda()
    }

    /// 書くネタを替える（持ちネタ＋新しく書く）。選ぶだけ（週は進まない・乱数なし）
    private var netaPicker: some View {
        let cfg = session.config
        return VStack(spacing: 8) {
            ForEach(session.activeNetas, id: \.id) { n in
                let sel = n.id == writeTarget?.id
                Button {
                    session.setWriteNeta(n.id)
                    withAnimation(Theme.Motion.appearQuick) { newNetaTitle = nil; pickingNeta = false }
                } label: {
                    // 題名は1行を丸ごと使う（横に札と数字を並べると題名・数字が切れた＝playtest_v13 §4-1）
                    VStack(alignment: .leading, spacing: 4) {
                        Text("「\(n.name)」").font(YoseFont.mincho(16)).foregroundStyle(YoseColor.sumi).lineLimit(1)
                        HStack(spacing: 8) {
                            NetaStageBadge(netaID: n.id, polish: n.polish)
                            Spacer(minLength: 4)
                            Text("完成度 \(Int(n.polish.rounded())) ・ 舞台 \(n.stageCount)回").font(YoseFont.number(11, weight: .bold)).foregroundStyle(YoseColor.haiSumi).lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .yoseHarigami(isFeatured: sel)
                }
                .buttonStyle(PressableStyle())
            }
            if session.activeNetas.count < cfg.netaActiveSlots {
                Button {
 session.beginNewWrite()
                    withAnimation(Theme.Motion.appearQuick) { newNetaTitle = ""; pickingNeta = false }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: Font.mzScaled(12), weight: .heavy))
                        Text("新しく書く").font(YoseFont.gothic(14, weight: .heavy))
                        Spacer()
                        Text("あと\(cfg.netaActiveSlots - session.activeNetas.count)本").font(YoseFont.captionBold).foregroundStyle(YoseColor.haiSumi)
                    }
                    .foregroundStyle(YoseColor.enji)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .yoseHarigami()
                    .overlay(Rectangle().stroke(YoseColor.kin, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])).padding(5))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    /// 新しいネタの題名（空欄＝おまかせ）。オーナー 2026-10-12「タイトル決めとかこっちでかけるように」
    private var netaTitleField: some View {
        HStack(spacing: 8) {
            YoseTag(text: "題名", style: .solidEnji)
            TextField("", text: Binding(get: { newNetaTitle ?? "" }, set: { newNetaTitle = String($0.prefix(16)) }),
                      prompt: Text("空欄ならおまかせ命名").foregroundColor(YoseColor.haiSumi.opacity(0.6)))
                .font(YoseFont.mincho(15)).foregroundStyle(YoseColor.sumi)
                .tint(YoseColor.shu)
                .submitLabel(.done)
                .padding(.horizontal, 8).frame(height: 36)
                .background(Color.white)   // 書き込める白紙（白地＋墨の枠）
                .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
            Button {
                titleDiceStep += 1
                newNetaTitle = NetaCatalog.autoName(forID: s.nextNetaID + titleDiceStep)   // 見た目の候補だけ（乱数は引かない）
                Haptics.tick()
            } label: {
                Label("候補", systemImage: "die.face.5").font(YoseFont.gothic(12, weight: .heavy)).lineLimit(1)
            }
            .buttonStyle(YoseButtonStyle(.secondary))
            .frame(width: 72)
        }
        .padding(.horizontal, 12).padding(.trailing, -6).frame(height: 54)
        .background(YoseColor.washi)
        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
        .padding(.bottom, 2)
    }

    /// 場所を押した時：新しく書くなら題名を予約して、エンジンが新ネタを作るようにする
    private func prepareNetaTarget() {
        guard writeTarget == nil else { return }
        session.beginNewWrite()
        let t = (newNetaTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { pendingNetaTitle = (s.nextNetaID, t) }
    }

    /// 行動の実行（二拍：引き抜き→一言→週送り→バースト）。行動カードとネタの一覧から呼ぶ。
    private func perform(_ v: CommandVariant) {
        Sound.play(.tap)   // 実行の決定音（週送りの一拍目）
        // 二拍実行: 引き抜き0.12s→Beat1 発話0.7s（画面タップで即スキップ）→週送り→Beat2 バースト。
        // cancel() されても choose は必ず一度だけ走る（sleep が即返るだけ）＝スキップ＝早送り。
        // 監査A-04: 一言はこのカードで直近4週に出していない時だけ（毎週同じ3本が回るのを避ける）
        let showBeat = session.week - (lastBeatWeek[v.id] ?? -100) > 4
        if showBeat {
            lastBeatWeek[v.id] = session.week
            withAnimation(.easeOut(duration: 0.18)) {
                beatAdvice = DialogueData.reaction(variantID: v.id, salt: session.week, picker: session.picker())
            }
        }
        withAnimation(.easeIn(duration: 0.12)) { pulledID = v.id }
        beatTask = Task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            if showBeat { try? await Task.sleep(nanoseconds: 700_000_000) }   // 発話の一拍
            resultName = v.name
            burstGen += 1               // choose が選択肢イベントを立てても Beat2 退場まで cover を待たせる
            burstHold = true
            Haptics.tick()              // 振動は実行（=週送り）のみ（Haptics 3段）
            if case .acceptOffer = v.action { session.chooseOffer(index: offerPick) }   // キュー96：選んだ札を今週のオファーにする
            session.choose(v.action)    // ＝即実行・1週進む（つぎへ廃止）
            if let p = pendingNetaTitle {   // 新しいネタに、プレイヤーが付けた題名を付ける
                if session.activeNetas.contains(where: { $0.id == p.id }) { session.renameNeta(p.id, to: p.title) }
                pendingNetaTitle = nil
            }
            withAnimation(Theme.Motion.appear) { pulledID = nil; openCat = nil; openNetaWrite = false; newNetaTitle = nil; pickingNeta = false }   // 実行したら4ボタンへ戻る
        }
    }

    /// キュー96：オファーの札を横に並べる（仕事の名前・お金・説明・テレビ慣れの一言）。タップで選ぶ（受けるのは下の帯をもう一度押す）。
    private var offerPicker: some View {
        HStack(spacing: 6) {
            ForEach(0..<offers.count, id: \.self) { i in offerPickCard(i) }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func offerPickCard(_ i: Int) -> some View {
        let o = offers[i]
        let on = i == offerPick
        return Button {
            Sound.play(.tap)
            offerPick = i
            offerArmed = false
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(o.name).font(YoseFont.gothic(13, weight: .heavy)).foregroundStyle(YoseColor.sumi).lineLimit(1)
                Text("+" + Yen.man(o.income)).font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.kinText)
                Text(CommandCatalog.offerBlurb(o.name)).font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
                    .lineLimit(3).fixedSize(horizontal: false, vertical: true)
            }
            .padding(6).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)   // 3枚の背丈をそろえる（ui_audit_1019 §3）
            .background(YoseColor.kinari)
            .overlay(Rectangle().stroke(on ? YoseColor.kinBright : YoseColor.sumi, lineWidth: on ? 3 : 1.5))
        }
        .buttonStyle(.plain)
    }

    private func actionCard(_ v: CommandVariant, compact: Bool = false, dashed: Bool? = nil, wide: Bool = false, row: Bool = false) -> some View {
        let preoccupied = v.isTrain && s.preoccupiedWeeks > 0                       // 0022 撮影で稽古枠が埋まった週
        let gated = v.isTrain && (s.stamina < session.config.staminaGate || s.preoccupiedWeeks > 0)
        let blocked = gated || !v.affordable
        let run: () -> Void = {
            guard pulledID == nil, !burstHold, session.pendingChoiceEvent == nil else { syncEventPresentation(); return }   // 多重タップ・バースト中は無視（監査F-10）
            if blocked {
                // 沈まず横ブレ＝「押せない」の触感文法（§3-1）。振動は付けない（閲覧扱い）。
                Sound.play(.deny)
                if !reduceMotion { withAnimation(.linear(duration: 0.15)) { shakeSeed[v.id, default: 0] += 1 } }
                showToast(preoccupied ? "今週は撮影。稽古の時間がない。" : gated ? "体力が足りない。今日は休もう。" : "お金が足りない。")
                return
            }
            if case .acceptOffer = v.action, !offerArmed {
                offerArmed = true
                showToast("もう一度押すと、このオファーを受ける。")
                Task { try? await Task.sleep(nanoseconds: 3_000_000_000); offerArmed = false }
                return
            }
            offerArmed = false
            if openCat == .ネタを書く { prepareNetaTarget() }
            perform(v)
        }
        return Button { tapOrQueue(run) } label: {
            actionCardLabel(v, gated: gated, preoccupied: preoccupied, compact: compact, dashed: dashed ?? compact, wide: wide, row: row)
                .scaleEffect(pulledID == v.id ? 1.06 : 1)   // 実行時に軽くポップ（引き抜きの手応え・0.12s budget内）
                .opacity(pulledID == v.id ? 0 : 1)
        }
        .buttonStyle(PressableStyle(enabled: !blocked))
        .modifier(ShakeEffect(animatableData: shakeSeed[v.id] ?? 0))
    }

    /// 練習を選ぶ画面の上段：経験点5種の今の持ち分（増える分は各練習の札に出す・表示専用）
    private func practiceExpPanel(_ cards: [CommandVariant]) -> some View {
        HStack(spacing: 6) {
            ForEach(ExpCurrency.allCases, id: \.self) { c in
                VStack(spacing: 1) {
                    Text(Theme.currencyChar(c)).font(YoseFont.gothic(12, weight: .black)).foregroundStyle(YoseColor.kinari)
                        .frame(width: 22, height: 22).background(Self.expColor(c), in: Circle())
                        .accessibilityLabel(c.displayName)
                    Text("\(ExpDisplay.value(s[currency: c]))").font(YoseFont.number(17, weight: .heavy)).foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(YoseColor.sumi)
        .overlay(Rectangle().stroke(YoseColor.kinBright.opacity(0.6), lineWidth: 1.5))
    }

    /// 大会が近く（2週以内）、まだ振れる経験点がある＝バナーと能力アップの縁で知らせる（振るのは自分）
    private var unspentBeforeStage: Bool {
        guard expGrains > 0, let m = nextMilestone(), m.weeksLeft <= 2 else { return false }
        return AbilityUpView.anyPlusEnabled(session, state: s)   // 実際に押せる＋が1つ以上ある時だけ
    }

    /// たまっている経験点の合計（粒・切り捨て）
    private var expGrains: Int { ExpDisplay.value(s.expTotal) }

    /// 4ボタンの1枚（パワプロ式）。押すと下位一覧へ。能力アップは経験点の振り分け画面（AllocationView）
    private func categoryTile(_ c: CommandCategory) -> some View {
        let ready = c == .能力アップ && expGrains > 0
        let gated = (c == .練習 || c == .ネタを書く) && (s.stamina < session.config.staminaGate || s.preoccupiedWeeks > 0)
        let sub: String = {
            switch c {
            case .ネタを書く:
                if gated { return "" }   // 理由は「出張中/休演」テープ1枚で言う（二重の文字を出さない）
                if let n = session.selectedNeta { return "\(session.activeNetas.count)本 ・ 勝負ネタ「\(n.name)」" }
                #if DEBUG
                if ProcessInfo.processInfo.environment["MZ_DEDUP"] == "sub", session.activeNetas.isEmpty { return "0本" }   // キュー111 の見本：ボタンの小さい字の方を短く
                #endif
                return session.activeNetas.isEmpty ? "まだネタがない。まず一本" : "\(session.activeNetas.count)本 書いた"
            case .練習: return gated ? "" : "合わせ・舞台 ほか"
            case .バイト: return "お金を稼ぐ"   // 6枚とも2段（名前＋一言）に揃える（監査 r4 04）
            case .休む: return "体力を回復"
            case .能力アップ:
                if unspentBeforeStage { return "" }   // 朱札「未振分あり」と上の看板が言う
                return expGrains > 0 ? "振れる経験点あり" : "能力を伸ばす"
            case .お店: return "アイテムを買う"
            }
        }()
        let run: () -> Void = {
            guard pulledID == nil, !burstHold, session.pendingChoiceEvent == nil else { syncEventPresentation(); return }
            if gated {
                Sound.play(.deny)
                showToast(s.preoccupiedWeeks > 0 ? "今週は撮影。稽古の時間がない。" : "体力が足りない。今日は休もう。")
                return
            }
            Sound.play(.tap)
            if c == .能力アップ { instant { showAllocation = true }; return }
            if c == .お店 { instant { showShop = true }; return }
            withAnimation(Theme.Motion.appearQuick) {
                openCat = c
                if c == .ネタを書く { openNetaWrite = true }
            }
        }
        return Button { tapOrQueue(run) } label: {
            let stamp: String? = { switch c { case .ネタを書く: return "square.and.pencil"; case .練習: return "music.mic"
                                          case .バイト: return "yensign.circle.fill"; case .休む: return "moon.zzz.fill"
                                          case .能力アップ: return "arrow.up.forward.circle.fill"; case .お店: return "bag.fill" } }()
            let urgent = c == .能力アップ && unspentBeforeStage
            VStack(spacing: 3) {
                HStack(spacing: 7) {
                    if let stamp {
                        Image(systemName: stamp).font(.system(size: Font.mzScaled(15), weight: .black)).foregroundStyle(YoseColor.kinari)
                            .frame(width: 28, height: 28)
                            .background(gated ? YoseColor.disabledText : YoseColor.enji)
                            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                    }
                    Text(c.rawValue).font(YoseFont.gothic(20, weight: .heavy))
                        .foregroundStyle(gated ? YoseColor.disabledText : YoseColor.sumi)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                if !sub.isEmpty {
                    Text(sub).font(YoseFont.gothic(12, weight: .bold))
                        .foregroundStyle(gated ? YoseColor.shu : ready ? YoseColor.kinText : YoseColor.haiSumi)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1).minimumScaleFactor(0.8)   // AX の大きさでは勝負ネタの名前が … で切れた＝2行まで（visual_check_after_12pt_v0 §AX）
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, (urgent || gated) ? 14 : 0)   // 朱札「未振分あり」・判子「出張中/休演」が名前に食い込まないよう文字を上げる（hooks_audit_1026）
            .overlay(alignment: .bottomTrailing) {
                // 選べない札は、判子で「今週は無理」を言う
                if gated {
                    Text(s.preoccupiedWeeks > 0 ? "出張中" : "休演")
                        .font(YoseFont.gothic(12, weight: .black)).tracking(2).foregroundStyle(YoseColor.kinari)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(YoseColor.shu)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                        .rotationEffect(.degrees(-8)).offset(x: 6, y: 10)
                }
            }
        }
        .buttonStyle(YoseButtonStyle(.command, badgeText: c == .能力アップ && unspentBeforeStage ? "未振分あり" : nil,
                                       highlight: c == .能力アップ && unspentBeforeStage))
    }

    /// カードの顔（貼り紙）: アイコン箱＋名前／説明／伸び（経験点は正本の5色）／コスト（所持金・体力）。
    /// 条件付きの小カード（dashed）は金の破線を内側に引いて「今だけのカード」と分ける。
    /// wide は全幅の横長（バイト用）＝左に名前と説明・右に稼ぎの大きな数字。
    private func actionCardLabel(_ v: CommandVariant, gated: Bool, preoccupied: Bool, compact: Bool, dashed: Bool, wide: Bool = false, row: Bool = false) -> some View {
        let after = session.previewAfterPour(v.action, offer: activeOffer)
        let effects = (gated || !v.affordable) ? [] : cardEffects(v, after: after)
        let moneyDelta = after.money - s.money
        var stamDelta = Int(after.stamina.rounded()) - Int(s.stamina.rounded())
        if case .rest(let r) = v.action, let rec = session.config.rests[r]?.recovery {   // 回復量は体力が満タンでも数字で見せる
            // 部屋の上乗せ・銭湯の回数券も GameEngine.applyRest と同じく足す（code_review_2026-10-19j §2）
            let room = s.room ?? 0
            let roomHeal = (room > 0 && (r == .完全休養 || r == .気分転換) && room < session.config.roomHeals.count) ? session.config.roomHeals[room] : 0
            let ticket = (s.sentoTickets ?? 0) > 0 ? session.config.itemSentoRecovery : 0
            stamDelta = Int((rec + roomHeal + ticket).rounded())
        }
        if !v.affordable { stamDelta = 0 }   // 払えない札は何も起きない＝休養に差し替えた見積もりの「体力 +」を出さない（§1）
        let tint = cardTint(v)
        let iconBox = Image(systemName: v.glyph)
            .font(.system(size: Font.mzScaled(compact ? 12 : 14), weight: .bold)).foregroundStyle(YoseColor.kinari)
            .frame(width: 26, height: 26)
            .background(gated ? YoseColor.disabledText : tint)
            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
        let body = VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                iconBox
                Text(v.name).font(YoseFont.gothic(compact ? 14 : 15, weight: .heavy)).foregroundStyle(gated ? YoseColor.disabledText : YoseColor.sumi)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            if case .acceptOffer = v.action {
                Text(offerArmed ? "もう一度押すと受ける" : v.desc).font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.kinText).lineLimit(2).fixedSize(horizontal: false, vertical: true)   // 仕事の説明（＋続けて受けている時は谷口の一言）
            } else if !dashed, !gated {
                Text(v.desc).font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.haiSumi).lineLimit(row ? 1 : 2).fixedSize(horizontal: false, vertical: true)
            }
            if gated {
                Text(preoccupied ? "今週は撮影で練習できない" : "体力が足りない ・ 休もう").font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.shu)
            } else if !v.affordable {
                Text("お金が足りない").font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.shu)
            }
            if v.isTrain, openCat == .練習, !gated, v.affordable {
                let gains = ExpCurrency.allCases.map { ($0, ExpDisplay.value(after[currency: $0] - s[currency: $0])) }.filter { $0.1 > 0 }
                if !gains.isEmpty {   // 増える経験点を最初から札に出す（黄色・×10の表示値）
                    HStack(spacing: 5) {
                        ForEach(gains, id: \.0) { c, n in
                            Text("\(Theme.currencyChar(c))+\(n)").font(YoseFont.number(12, weight: .black)).foregroundStyle(YoseColor.kinText)
                                .padding(.horizontal, 4).padding(.vertical, 1).background(YoseColor.kinBright.opacity(0.35))
                                .fixedSize()
                        }
                    }
                }
            }
            if !wide, !row, !effects.isEmpty {
                ViewThatFits(in: .horizontal) {   // 入りきらなければ2段に折る（札を「…」で切らない）
                    HStack(spacing: 4) { ForEach(effects, id: \.text) { effectPill($0).fixedSize() } }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) { ForEach(effects.prefix(2), id: \.text) { effectPill($0).fixedSize() } }
                        HStack(spacing: 4) { ForEach(effects.dropFirst(2), id: \.text) { effectPill($0).fixedSize() } }
                    }
                }
            }
            if !wide, !row {
                Spacer(minLength: 0)   // 消費（お金・体力）はカードの最下段へ揃える（隣のカードと同じ高さに並ぶ）
                HStack(spacing: 4) {
                    if moneyDelta != 0 { costPill(money: moneyDelta, insufficient: !v.affordable) }
                    if stamDelta != 0 { staminaPill(stamDelta, insufficient: gated) }
                }
            }
        }
        return Group {
            if row {
                // 奇数枚の最後（全幅）: 上段に名前・説明、下段に効果と消費を1行で（右だけが混まない2段）
                VStack(alignment: .leading, spacing: 7) {
                    body
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 4) {
                            ForEach(effects, id: \.text) { effectPill($0).fixedSize() }
                            Spacer(minLength: 4)
                            if moneyDelta != 0 { costPill(money: moneyDelta, insufficient: !v.affordable) }
                            if stamDelta != 0 { staminaPill(stamDelta, insufficient: gated) }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) { ForEach(effects, id: \.text) { effectPill($0).fixedSize() } }
                            HStack(spacing: 4) {
                                if moneyDelta != 0 { costPill(money: moneyDelta, insufficient: !v.affordable) }
                                if stamDelta != 0 { staminaPill(stamDelta, insufficient: gated) }
                            }
                        }
                    }
                }
            } else if wide {
                HStack(alignment: .center, spacing: 8) {
                    body
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 4) {
                        if moneyDelta != 0 {
                            HStack(spacing: 6) {
                                if moneyDelta > 0 {
                                    Text("収入").font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(Color(hex: 0x7A6218))
                                        .padding(.horizontal, 5).padding(.vertical, 1)
                                        .background(YoseColor.kin.opacity(0.25))
                                        .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1.5))
                                }
                                Text("\(moneyDelta > 0 ? "+" : "-")¥\(Yen.man(abs(moneyDelta)))")
                                    .font(YoseFont.number(22, weight: .heavy)).lineLimit(1).fixedSize()
                                    .foregroundStyle(moneyDelta > 0 ? YoseColor.sumi : YoseColor.shu)
                            }
                        }
                        if stamDelta != 0 { staminaPill(stamDelta, insufficient: gated) }
                    }
                }
            } else {
                body.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 11).padding(.vertical, compact ? 9 : 10)
        .frame(maxWidth: .infinity, minHeight: wide ? 70 : nil, maxHeight: wide ? nil : .infinity, alignment: .topLeading)
        .background(gated ? YoseColor.ginNezu.opacity(0.6) : Color.clear)
        .yoseHarigami()
        .overlay(alignment: .leading) {
            // 左端の種別帯（無料＝朱／有料＝金）。一覧のカードだけ
            if compact && !gated {
                Rectangle().fill(wide ? YoseColor.kin : (moneyDelta < 0 ? YoseColor.kin : YoseColor.shu)).frame(width: 5).padding(.vertical, 2).padding(.leading, 2)
            }
        }
        .overlay {
            if dashed && !gated {
                Rectangle().stroke(YoseColor.kin, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])).padding(5)
            }
        }
        .overlay {
            // 体力が満タンの休みでは、回復が余るので「相性 +」の付く札だけ朱の枠で目に留める（押せるのは全部そのまま）
            if case .rest = v.action, s.stamina >= 99.5, !gated, effects.contains(where: { $0.text.hasPrefix("相性") }) {
                Rectangle().stroke(YoseColor.shu, lineWidth: 2)
            }
        }
    }

    /// カードごとの地色（アイコン箱）。色だけに頼らずアイコン＋名前でも区別する（§6-5）。
    private func cardTint(_ v: CommandVariant) -> Color {
        switch v.action {
        case .train(.ネタ作り), .train(.喫茶店で書く), .train(.ファミレスで書く): return YoseColor.enji   // 書く場所のアイコンは寄席の臙脂（紫は『間合い』の色なので使わない）
        case .train(.ネタ合わせ): return YoseColor.shu
        case .train: return YoseColor.enji
        case .rest: return YoseColor.tokiwa
        case .job: return YoseColor.enji   // 常磐緑は体力・回復の色。お金の札は臙脂にして混ざらせない
        case .acceptOffer: return YoseColor.kin
        }
    }

    private func effectPill(_ e: CardEffect) -> some View {
        Text(e.text).font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(e.color)
            .lineLimit(1).minimumScaleFactor(0.8)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(e.color.opacity(0.12))
            .overlay(Rectangle().stroke(e.color, lineWidth: 1.5))
    }

    // MARK: Beat2 獲得バースト（この週の行動で入ったものが立ち絵の頭上に立ち上る）

    /// 出現は下から stagger（0.07s刻み・emphSpring）、退場は逆再生。チップの色はカードの伸びと同じ＝予告と着地が同じ顔。
    private var burstOverlay: some View {
        VStack(alignment: .trailing, spacing: 5) {
            ForEach(Array(burstChips.filter(\.up).enumerated()), id: \.element.id) { i, chip in
                burstChipView(chip)
                    .opacity(burstVisible ? 1 : 0)
                    .offset(y: burstVisible ? 0 : 16)
                    .scaleEffect(burstVisible ? 1 : 0.7, anchor: .bottomTrailing)
                    .animation(Theme.Motion.emphSpring.delay(Double(i) * 0.07), value: burstVisible)
            }
        }
    }

    private func burstChipView(_ chip: BurstChip) -> some View {
        // 伸びは山吹金の札＋墨2pt枠＋ハード影。「新ネタ」だけは朱の判子で叩きつける（ぼかし影・紫は使わない）。
        Group {
            if chip.text == "新ネタ" {
                YoseHankoStamp(text: "新ネタ", isSquare: true).rotationEffect(.degrees(-8))
                    .shadow(color: YoseColor.sumi.opacity(0.35), radius: 0, x: 0, y: 2)
            } else {
                Text(chip.text).font(YoseFont.gothic(17, weight: .black)).foregroundStyle(YoseColor.sumi)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(YoseColor.kinBright)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))
            }
        }
    }

    /// 体力の減りは体力ゲージの直上に黒漆の札で（祝わない・どのゲージが減ったか視線が繋がる）
    @ViewBuilder private var burstCostOverlay: some View {
        if let chip = burstChips.first(where: { !$0.up }) {
            Text(chip.text).font(YoseFont.gothic(14, weight: .black)).foregroundStyle(YoseColor.kinari)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(YoseColor.kuroUrushi)
                .overlay(Rectangle().stroke(YoseColor.shu, lineWidth: 1.5))
                .opacity(burstVisible ? 1 : 0)
                .offset(y: burstVisible ? 0 : 10)
                .animation(.spring(response: 0.28, dampingFraction: 0.7), value: burstVisible)
                .padding(.leading, 172).padding(.bottom, 80)   // 体力ゲージの右隣＝ボタンに被らない黒帯の空き
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .allowsHitTesting(false)
        }
    }

    /// 押した行動の結果を一行に（実際の状態差のみ・新規計算なし・％なし）。例「バイト　所持金 +64,000」
    private func makeResultLine() -> String? {
        guard let name = resultName else { return nil }
        func signed(_ n: Int) -> String {
            let f = NumberFormatter(); f.numberStyle = .decimal
            return (n > 0 ? "+" : "−") + (f.string(from: NSNumber(value: abs(n))) ?? "\(abs(n))")
        }
        var parts: [String] = []
        let md = session.lastMoneyDelta
        if md != 0 { parts.append("所持金 \(signed(md))") }
        let exp = ExpDisplay.value(session.lastGrainGains.reduce(0) { $0 + $1.amount })
        if exp > 0 { parts.append("経験点 +\(exp)") }
        let sd = session.lastStaminaDelta
        if sd != 0 { parts.append("体力 \(signed(sd))") }
        guard !parts.isEmpty else { return nil }
        // 生活費（週末処理）は「月末の支払い」の画面で見せる＝ここには出さない
        return ([name] + parts.prefix(2)).joined(separator: "　")
    }

    /// 生活費の週末なら、支払いの画面を出して閉じるまで待つ（獲得バーストの後・イベントより前）。1週1回。
    private func presentRent() async {
        let paid = session.lastLivingPaid
        let key = session.year * 1000 + session.week
        guard paid > 0, session.lastDeltaWeek == session.week, rentShownKey != key, !Task.isCancelled else { return }
        rentShownKey = key
        withAnimation(.easeOut(duration: 0.2)) { rent = RentStatement.make(livingCost: paid, moneyAfter: s.money, roomExtra: GameEngine.roomRent(s, config: session.config),
                                                                  roomName: ShopView.roomNames[min(max(s.room ?? 0, 0), ShopView.roomNames.count - 1)]) }
        while rent != nil && !Task.isCancelled { try? await Task.sleep(nanoseconds: 100_000_000) }
    }

    /// 立っている選択肢イベントを、今出してよければ出す（獲得の一拍・引き抜きの最中は待たせる）。
    private func syncEventPresentation() {
        if session.pendingChoiceEvent != nil, !burstHold, pulledID == nil { instant { showEvent = true } }
    }

    /// 指定秒だけ待つ。途中で burstSkip が立てば即戻る（タスクの取り消しでも即戻る）。
    /// 獲得チップ表示中に行動ボタンが押された：チップを畳み、終わったらその押下を実行する（押した分を空振りにしない）
    private func tapOrQueue(_ run: @escaping () -> Void) {
        guard burstHold, pulledID == nil, session.pendingChoiceEvent == nil else { run(); return }
        burstSkip = true
        Task {
            var n = 0
            while burstHold, n < 60 { try? await Task.sleep(nanoseconds: 50_000_000); n += 1 }
            if !burstHold { run() }
        }
    }

    private func waitOrSkip(seconds: Double) async {
        let steps = Int(seconds / 0.05)
        for _ in 0..<steps {
            if burstSkip || Task.isCancelled { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    /// この週の獲得チップ列を組む（表示専用・RNG非消費）。最大3枚、順序: 実力 ↑（自動注ぎで実力値が伸びた週）→
    /// 相性 +N→ネタ +N or 新ネタ→体力。経験点の通貨チップ・所持金チップは出さない（A「削る」）。差分0は出さない。
    private func makeBurstChips() -> [BurstChip] {
        var chips: [BurstChip] = []
        // G3: 等級（G〜S）が上がった週だけ、先頭の1枚を等級チップにして祝う（週メインに等級は常設しない＝スライス1の既決）
        if let up = rankUpThisWeek() {
            chips.append(BurstChip(id: chips.count, text: "\(up.ability) \(up.from)→\(up.to)", fg: .white,
                                   bg: Theme.gradeColor(up.to) == Theme.gold ? Theme.goldDeep : Theme.gradeColor(up.to)))
        }
        if lastJitsuryokuGain > 0.001 {
            // 実力は1週で整数が動かない週が多い＝数字でなく「↑」（バーのオレンジと対）
            chips.append(BurstChip(id: chips.count, text: "実力 ↑", fg: .white, bg: Theme.senseDeep))
        }
        let cd = Int(session.lastCompatGain.rounded())
        if cd > 0 {
            chips.append(BurstChip(id: chips.count, text: "相性 +\(cd)", fg: .white, bg: Theme.vermD))
        }
        if let n = session.lastNetaGain {
            let pd = Int(n.polish.rounded())
            if n.isNew || pd > 0 {
                chips.append(BurstChip(id: chips.count, text: n.isNew ? "新ネタ" : "ネタ +\(pd)", fg: .white, bg: Theme.ideaDeep))
            }
        }
        // G1: 舞台に立つ週の知名度（押した週に必ず何かが残る・最大3枚の枠の中）
        let fd = session.lastFameDelta
        if Int(fd.rounded()) > 0 {
            chips.append(BurstChip(id: chips.count, text: "知名度 +\(Int(fd.rounded()))", fg: .white, bg: Theme.goldDeep))
        }
        let sd = session.lastStaminaDelta
        if sd != 0 {
            // 体力の減りは白地＋縁＋補助色＝見えるが祝わない（旧 card2 地は壁と1.06:1で消えていた）
            chips.append(BurstChip(id: chips.count, text: "体力 \(sd > 0 ? "+" : "")\(sd)",
                                   fg: sd > 0 ? .white : Theme.inkSub,
                                   bg: sd > 0 ? Theme.mentalDeep : .white, up: sd > 0))
        }
        return Array(chips.prefix(3))
    }

    /// この週の行動で等級が上がった能力（最初の1つ）。lastGains の増分から週の前の値を戻して比べる（表示専用・RNG非消費）
    private func rankUpThisWeek() -> (ability: Ability, from: String, to: String)? {
        #if DEBUG
        if ProcessInfo.processInfo.environment["MZ_RANKUP"] != nil, session.lastDeltaWeek == session.week {
            return (.センス, "G", "F")   // 目視用（等級チップの見た目だけ確かめる）
        }
        #endif
        for g in session.lastGains {
            let after = s[g.ability], before = after - g.amount
            let from = Theme.rank(before), to = Theme.rank(after)
            if from != to { return (g.ability, from, to) }
        }
        return nil
    }

    private func costPill(money: Int, insufficient: Bool = false) -> some View {
        let up = money > 0
        let amt = abs(money) < 10000 ? "\(abs(money).formatted())" : Yen.man(abs(money))   // 1万円未満は整数円（¥0.5万を出さない）
        return Text("\(up ? "+" : "-")¥\(amt)")
            .font(YoseFont.gothic(12, weight: .heavy)).lineLimit(1).fixedSize()
            .foregroundStyle(insufficient ? YoseColor.kinari : (up ? YoseColor.tokiwa : YoseColor.shu))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(insufficient ? YoseColor.shu : (up ? YoseColor.tokiwa : YoseColor.shu).opacity(0.1))
            .overlay(Rectangle().stroke(insufficient ? YoseColor.sumi : (up ? YoseColor.tokiwa : YoseColor.shu), lineWidth: 1.5))
    }

    private func staminaPill(_ delta: Int, insufficient: Bool = false) -> some View {
        let up = delta > 0
        return Text("体力 \(up ? "+" : "")\(delta)")
            .font(YoseFont.gothic(12, weight: .heavy)).lineLimit(1).fixedSize()
            .foregroundStyle(insufficient ? YoseColor.kinari : (up ? YoseColor.tokiwa : YoseColor.sumi))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(insufficient ? YoseColor.shu : (up ? YoseColor.tokiwa.opacity(0.12) : YoseColor.ginNezu.opacity(0.5)))
            .overlay(Rectangle().stroke(insufficient ? YoseColor.sumi : (up ? YoseColor.tokiwa : YoseColor.haiSumi), lineWidth: 1.5))
    }

    // MARK: 最下部の帯（年週・大会までN週・体力ゲージ・所持金）

    /// 最下帯：上段＝体力ゲージ・所持金（YoseVitalMoneyBar）／下段＝日程・コンビ・設定（YoseFooterTabBar）。
    /// 大会までの週は上の目標バナーと重複するので外した。
    private var botbar: some View {
        VStack(spacing: 0) {
            YoseVitalMoneyBar(stamina: Int(s.stamina.rounded()), maxStamina: 100, money: s.money,
                              fame: Int(s.fame.rounded()),
                              staminaColor: s.stamina <= 40 ? YoseColor.shu : Color(hex: 0x3B7A4E))
                .opacity(gaugeFlash ? 0.5 : 1)
                .onChange(of: staminaZone) { old, new in
                    guard new < old else { return }     // 悪化方向に跨いだ時だけ明滅（黄=1回/赤=2回・§3-4）
                    Task {
                        for _ in 0..<(new == 0 ? 2 : 1) {
                            withAnimation(.easeIn(duration: 0.15)) { gaugeFlash = true }
                            try? await Task.sleep(nanoseconds: 150_000_000)
                            withAnimation(.easeOut(duration: 0.15)) { gaugeFlash = false }
                            try? await Task.sleep(nanoseconds: 150_000_000)
                        }
                    }
                }
            YoseFooterTabBar(items: [
                YoseFooterItem(title: "日程", symbol: "calendar") { instant { showCalendar = true } },              // S4 カレンダー
                YoseFooterItem(title: "コンビ", symbol: "person.2.fill") { instant { showNotebook = true } },       // S5 コンビの情報（旧ネタ帳）
                YoseFooterItem(title: "設定", symbol: "gearshape.fill") { showSettings = true },        // 音量・この年をやめる（監査G-04）
            ])
        }
        .background(YoseColor.kuroUrushi.ignoresSafeArea(edges: .bottom))
    }

    /// 体力の3段ゾーン（2=緑/1=黄/0=赤）。閾値は黄50未満・赤20未満（第1便§0裁定①）。
    private var staminaZone: Int {
        if s.stamina < 20 { return 0 }
        if s.stamina < 50 { return 1 }
        return 2
    }

    // MARK: トースト

    @ViewBuilder private var toastBar: some View {
        if let toast {
            Text(toast).font(.maru(13, weight: .bold)).foregroundStyle(Theme.kinari)
                .multilineTextAlignment(.leading)
                .padding(.leading, 18).padding(.trailing, 14).padding(.vertical, 10)
                .background(Theme.curtainShade, in: Rectangle())
                .overlay(alignment: .leading) { Rectangle().fill(Theme.verm).frame(width: 4) }
                .overlay(Rectangle().stroke(Theme.gold.opacity(0.7), lineWidth: 1))
                .clipShape(Rectangle())
                .e1()
                .padding(.horizontal, 24)
                .padding(.bottom, 78)   // 最下帯の上+16pt（§3-5）
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func showToast(_ t: String) { toast = t }

    /// 全画面の覆い（日程・コンビ・能力アップ・お店・イベント）の出し入れをシステムの遷移アニメ無しで行う。
    /// UIKit は覆いの提示/退場アニメの間、画面全体のタッチを止める＝閉じた直後・開いた直後の最初のタップが消えていた
    /// （実機でも同じ・押した行動が出ない／イベントの後に押した行動が戻る）。見た目の柔らかさは中身の FadeInOnAppear で補う。
    private func instant(_ body: () -> Void) {
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t, body)
    }

    /// 週の頭（生活費を払った後に週メインへ戻った時）に、借金の段が新しく深くなっていたら1回だけ知らせる（表示のみ）。
    private func maybeShowDebtNotice() {
        if session.injuryNoticeWeeks > 0, injuryNotice == nil, rent == nil, session.pendingChoiceEvent == nil, !showEvent, !burstHold, case .freeAction = session.phase {
            session.clearInjuryNotice()
            injuryNotice = "無理がたたって、体を壊した。しばらく療養で動けなかった。その間のバイト代は入らない。体力が低い時の稽古やキツいバイトは、体を壊しやすい。"
            return
        }
        guard debtNotice == nil, riftNotice == nil, rent == nil, session.pendingChoiceEvent == nil, !showEvent, !burstHold, case .freeAction = session.phase else { return }
        if session.riftHintToShow {
            session.markRiftHintShown()
            riftNotice = "相方と過ごす・ネタ合わせをした週は、すれ違いが減る。二人で舞台に立つ週は、すれ違いが溜まらない。"
            return
        }
        guard let tier = session.debtNoticeTierToShow(money: s.money) else { return }
        session.markDebtWarned(tier)
        switch tier {
        case 1: debtNotice = "生活費が払えず、借金になった。借金が100万を越えると、芸人を続けられない。"
        case 2: debtNotice = "借金が50万を越えた。あと50万で、芸人を続けられなくなる。バイトに専念すれば、まだ立て直せる。"
        default: debtNotice = "借金が80万を越えた。あと20万で終わりだ。今すぐバイトに専念すれば、まだ間に合う。"
        }
    }

    // MARK: 初めて遊ぶ人への一言説明（初回だけ）

    static var firstWeekHint: HintSpec {
        HintSpec(key: "firstWeek", title: "はじめに", rows: [
            .init(term: "実力", text: "コンビの強さ。大会では高いほど勝ち上がりやすい。"),
            .init(term: "相性", text: "二人の息の合い方。相方と合わせたり、休んだりで上がる。"),
            .init(term: "体力", text: "行動すると減る。休むと戻る。"),
            .init(term: "経験点", text: "練習やネタ書きでたまる。「能力アップ」で使うと実力が伸びる。"),
        ], note: "上の黒い帯は、次の大会までの週数。左上の「？」でいつでも読み返せる。")
    }

    private func livingHint() -> HintSpec {
        let c = session.config
        let living = GameEngine.livingCostDue(session.state, config: c)
        return HintSpec(key: "living", title: "生活費", rows: [
            .init(term: "生活費", text: "\(c.livingInterval)週に1度、週の終わりに、家賃や食費で\(living / 10_000)万円が引かれる。今週がその週。"),
            .init(term: "借金", text: "お金が足りないと、足りない分が借金になる。"),
        ])
    }

    /// 初回だけ出す短い説明（初週＝実力/相性/体力/経験点、最初の生活費の週＝引き落とし）。他の知らせと重ねない。
    private func maybeShowFirstHints() {
        guard !OneTimeHint.suppressedForDebug, hint == nil, rent == nil, debtNotice == nil, riftNotice == nil, toast == nil,
              session.pendingChoiceEvent == nil, !showEvent, !burstHold, pulledID == nil,
              !showAllocation, !showShop, !showNotebook, !showCalendar, !showSettings,
              case .freeAction = session.phase, session.year == 1 else { return }
        if !OneTimeHint.isDone("firstWeek"), session.week <= 1 {
            hint = Self.firstWeekHint
        } else if !OneTimeHint.isDone("living"), session.week >= session.config.livingInterval,
                  session.week % session.config.livingInterval == 0 {
            hint = livingHint()
        }
    }

    /// 若手の大会（芸歴の上限がある大会）に出られる最後の年の年初に1回だけ、谷口が一言知らせる（表示のみ・判定は不変）。
    /// 飽きの知らせの toast と重なる時は、それが消えるのを待ってから出す。
    private func maybeShowLastYouthNotice() {
        let caps = session.config.calendar.tournaments.compactMap { t -> Int? in
            if case .careerYearAtMost(let n) = t.eligibility, n < 10 { return n } else { return nil }
        }
        guard let cap = caps.min(), session.year == cap, session.week <= 1, youthNoticeYear != session.year else { return }
        youthNoticeYear = session.year
        Task {
            if toast != nil { try? await Task.sleep(nanoseconds: 4_500_000_000) }
            showToast("谷口「若手限定の大会に出られるのは、今年が最後だ」")
        }
    }

    /// 年初の週に1回だけ：前の年の大会で使って飽きが進んだネタを事実だけ知らせる（表示のみ）。
    private func maybeShowTiredNotice() {
        guard session.year >= 2, session.week <= 1, tiredNoticeYear != session.year,
              let n = session.activeNetas.first(where: { ($0.tiredYears ?? 0) >= 1 }) else { return }
        tiredNoticeYear = session.year
        showToast("『\(n.name)』は客に見飽きられてきた。新しいネタを書くと元どおり。")
    }

    /// §4 満了トーストを「この年1回だけ」出す（onChange の二経路から呼ばれても多重発火しない）。
    private func maybeShowVesselFullToast(_ full: Bool) {
        guard full, !vesselFullToastShown else { return }
        vesselFullToastShown = true
        showToast("今年の実力の伸びは、ここまで。来年また伸びる。")
    }

    // MARK: 導出（カードの伸び・弱点能力・次のマイルストン）

    /// カードの伸び（最大2つ）: 実力 ↑（自動注ぎの後に実力値が伸びる時）／相性 +N／ネタ +N or 新ネタ。
    /// 実力は1週で整数が動かない週が多い＝数字でなく「↑」で出す（％は出さない）。名目値＝RNG非消費。
    /// 器が満ちた後は実力 ↑ が自然に消える（旧「満」判の代わり）。
    private func cardEffects(_ v: CommandVariant, after: GameState) -> [CardEffect] {
        let cfg = session.config
        var out: [CardEffect] = []
        if GameEngine.jitsuryoku(after, config: cfg) - GameEngine.jitsuryoku(s, config: cfg) > 0.001 {
            out.append(CardEffect(text: "実力 ↑", color: YoseColor.enji))
        }
        // 手動の能力アップ：稽古で入る経験点を出す（パワプロの練習画面と同じ「何が貯まるか」）。大きい順に最大2つ
        let gains = ExpCurrency.allCases.map { ($0, after[currency: $0] - s[currency: $0]) }.filter { $0.1 > 0.001 }
            .sorted { $0.1 > $1.1 }.prefix(2)
        for (c, d) in gains where ExpDisplay.value(d) > 0 && !(v.isTrain && openCat == .練習) {
            out.append(CardEffect(text: "\(c) +\(ExpDisplay.value(d))", color: Self.expColor(c)))
        }
        let cd = Int(after.compat.rounded()) - Int(s.compat.rounded())
        if cd > 0 { out.append(CardEffect(text: "相性 +\(cd)", color: YoseColor.shu)) }
        if let neta = netaEffect(v.action) { out.append(CardEffect(text: neta, color: YoseColor.expMa)) }
        // G1: 舞台に立つ週は知名度が上がる＝押した週に必ず何かが残ることをカードで予告する
        let fd = after.fame - s.fame
        if Int(fd.rounded()) > 0 { out.append(CardEffect(text: "知名度 +\(Int(fd.rounded()))", color: YoseColor.kinText)) }
        return out
    }

    /// 経験点5色（正本 §2・能力アップ画面の5色と同じ）
    private static func expColor(_ c: ExpCurrency) -> Color {
        switch c {
        case .閃き: return YoseColor.expSen
        case .語彙: return YoseColor.expGo
        case .間合い: return YoseColor.expMa
        case .存在感: return YoseColor.expSon
        case .胆力: return YoseColor.expTan
        }
    }

    /// ネタへの効き（旧 trainExtras と同じ名目値・監査E-06）。ネタを書く＝選択中ネタの改稿 or 新ネタ／舞台に立つ＝客前で磨く。
    private func netaEffect(_ action: WeekAction) -> String? {
        guard case .train(let t) = action else { return nil }
        let cfg = session.config
        switch t {
        case .ネタ作り, .喫茶店で書く, .ファミレスで書く:
            let gain = cfg.netaPlaceGain[t] ?? cfg.netaReviseGain
            return writeTarget != nil ? "完成度 +\(Int(gain))" : "新ネタ"
        case .ネタ見せ会 where !s.netas.isEmpty:
            return "完成度 +\(Int(cfg.netaLivePolishShow))"
        case .フリーライブ where !s.netas.isEmpty:
            return "完成度 +\(Int(cfg.netaLivePolishFree))"
        default:
            return nil
        }
    }

    /// 本番が遠い週の目標バナー2行目＝いまのネタの完成度（監査A-01: 中だるみ帯の副目標）
    private func lullLine() -> String {
        let cur = s.selectedNetaID.flatMap { id in s.netas.first { $0.id == id } } ?? s.netas.last
        guard let n = cur else { return s.preoccupiedWeeks > 0 ? "大会まで間がある ・ ネタは来週から" : "大会まで間がある ・ まずはネタを書こう" }   // 撮影の週は書けない（playtest_v13 §2-3）
        return "大会まで間がある ・ ネタ「\(n.name)」完成度 \(Int(n.polish.rounded()))/100"
    }

    /// 年末へ（GPの道が閉じ、出られる本番が残っていない時だけ・二度押しで実行＝監査A-03）
    private var yearEndTile: some View {
        Button { tapOrQueue {
            if burstHold || session.pendingChoiceEvent != nil { return }
            if yearEndArmed {
                yearEndArmed = false
                session.fastForwardToYearEnd()
            } else {
                yearEndArmed = true
                showToast("もう一度押すと、残りの週を休んで年末の結果へ進む。")
                Task { try? await Task.sleep(nanoseconds: 3_000_000_000); yearEndArmed = false }
            }
        } } label: {
            // 条件付きの小カード（オファー/バイト）と同じ顔＝常設6枚の下に破線で並ぶ
            HStack(spacing: 7) {
                Image(systemName: "forward.end.fill").font(.system(size: Font.mzScaled(11), weight: .bold)).foregroundStyle(YoseColor.kinari).accessibilityHidden(true)   // 12pt 未満の例外：アイコン記号（文字ではない）
                    .frame(width: 26, height: 26)
                    .background(YoseColor.haiSumi)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                Text(yearEndArmed ? "もう一度" : "年末へ").font(YoseFont.gothic(14, weight: .heavy)).foregroundStyle(YoseColor.haiSumi).lineLimit(1)
            }
            .padding(.horizontal, 11).padding(.vertical, 9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .yoseHarigami()
            .overlay(Rectangle().stroke(YoseColor.kin, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])).padding(5))
        }
        .buttonStyle(PressableStyle())
    }

    /// §4 器満了: 成長予算を使い切ったか（NotebookView の器リングと同一判定＝食い違わない）。
    /// 自動注ぎ＝満了は行動の週送りで成立する。growthUsed≥growthBudget で判定（budget未設定=無制限は満了なし）。
    private var vesselIsFull: Bool {
        guard let budget = s.growthBudget, budget > 0 else { return false }
        return s.growthUsed >= budget - GameEngine.pourEpsilon
    }

    /// 一番低い能力名。差が1未満（第1週の全員10など）は「弱点なし」＝空文字（監査B-03: 根拠の無い助言を出さない）
    private func weakAbility() -> String {
        let pairs: [(String, Double)] = [("センス", s.センス), ("発想", s.発想), ("表現", s.表現), ("華", s.華), ("メンタル", s.メンタル)]
        guard let lo = pairs.min(by: { $0.1 < $1.1 }), let hi = pairs.max(by: { $0.1 < $1.1 }), hi.1 - lo.1 >= 1 else { return "" }
        return lo.0
    }

    /// 次の本番（GameSession.upcomingStages の先頭＝出場資格・GP敗退を反映済み・監査A-02/F-01）
    /// 帯に出す目標：次の大会、無ければ年末
    private func bannerMilestone() -> (name: String, weeksLeft: Int)? {
        nextMilestone() ?? (name: "年末", weeksLeft: session.config.weeks - session.week)
    }

    private func nextMilestone() -> (name: String, weeksLeft: Int)? {
        session.nextStage.map { ($0.name, $0.week - session.week) }
    }
}

/// 行動カードの伸び1つ（「実力 ↑」「相性 +1」「ネタ +8」「新ネタ」）。
private struct CardEffect {
    let text: String
    let color: Color
}

/// Beat2 獲得バーストの1チップ（色地・白字。体力の減りだけ card2 地）。
private struct BurstChip: Identifiable {
    let id: Int
    let text: String
    let fg: Color
    let bg: Color
    /// 伸び（祝う）か、減り（祝わない＝白地＋縁）か
    var up: Bool = true
}


/// 貼り紙の折れ角（右上の三角）
struct DogEar: Shape {
    var size: CGFloat
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.maxX - size, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + size))
        p.closeSubpath()
        return p
    }
}

/// 吹き出しの左向きのしっぽ（三角）。
struct BubbleTail: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        return p
    }
}


/// 吹き出しの「次へ」▼：ゆるく上下に弾む（タップで進める合図）。
struct BounceArrow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var up = false
    var body: some View {
        Image(systemName: "arrowtriangle.down.fill").accessibilityHidden(true)
            .font(.system(size: Font.mzScaled(9))).foregroundStyle(Theme.inkFaint)   // 12pt 未満の例外：アイコン記号（文字ではない）
            .offset(y: up ? 2.5 : -1.5)
            .onAppear { guard !reduceMotion else { return }; withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { up = true } }
    }
}


/// 全画面の覆いを出す時の柔らかさ（システムの提示アニメは入力を止めるので使わず、中身を 0.18 秒でふわっと出す）。
struct FadeInOnAppear: ViewModifier {
    @State private var on = false
    func body(content: Content) -> some View {
        content.opacity(on ? 1 : 0)
            .onAppear { withAnimation(.easeOut(duration: 0.18)) { on = true } }
    }
}
