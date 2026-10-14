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
    @Bindable var session: GameSession
    let offer: OfferSpec?

    /// 週送りの直後だけ true。実力/相性バーにこの週の伸びをオレンジで一瞬重ねる（既存の lastGains 機構を流用）。
    @State private var gainsVisible = false
    /// 無効タップ（体力/お金不足）の一時トースト。
    @State private var toast: String?
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
    /// 進行中の設定（監査G-04）
    @State private var showSettings = false
    /// 買い物（ShopView・アイテム）
    @State private var showShop = false
    /// 能力アップ（AllocationView・経験点を能力に振る）
    @State private var showAllocation = false

    private var s: GameState { session.state }
    /// 開いている4ボタンの下位一覧（nil＝4ボタン）。パワプロ式（オーナー指示 2026-10-12）
    @State private var openCat: CommandCategory?
    /// 練習→ネタを書く の下の「どのネタを磨くか」一覧を開いているか
    @State private var openNetaWrite = false
    /// 新しいネタの題名入力（nil＝入力欄を閉じている）。空欄で書く＝おまかせの題名
    @State private var newNetaTitle: String?
    /// 「書くネタ」を替える一覧を開いているか
    @State private var pickingNeta = false
    /// 書いた直後に付ける題名（新ネタの id と題名）
    @State private var pendingNetaTitle: (id: Int, title: String)?
    private var mainCards: [CommandVariant] {
        CommandCatalog.mainCards(config: session.config, money: s.money)
    }
    private var extraCards: [CommandVariant] {
        CommandCatalog.extraCards(config: session.config, offer: offer, money: s.money)
    }

    var body: some View {
        VStack(spacing: 0) {
            stageHeaderBand
            sceneZone
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            commandZone
            botbar
        }
        // パワプロ・サクセスの文法＝日常パートは明るくポップ（暗転は本番系画面の語彙）。
        .background(Theme.bgGradient.ignoresSafeArea())
        .fullScreenCover(isPresented: $showNotebook) {
            NotebookView(session: session) { showNotebook = false }   // S5 ネタ帳
        }
        .fullScreenCover(isPresented: $showCalendar) {
            CalendarView(session: session) { showCalendar = false }   // S4 年間カレンダー
        }
        .fullScreenCover(isPresented: Binding(
            // Beat2 バースト表示中は提示を待たせる（burstHold）＝獲得の一拍がcoverに隠れない。
            // 提示の判定は syncEventPresentation（イベントが立った／保留が外れた の変化で呼ぶ）に一本化。
            get: { showEvent },
            set: { if !$0 { showEvent = false; session.dismissChoiceEvent() } }
        )) {
            // 選択肢イベント（0024ピース3・確定発火）。pendingChoiceEvent は private(set) なので
            // Bool の合成 Binding 経由（既存 showNotebook 等と同じ isPresented パターン）。
            if let kind = session.pendingChoiceEvent {
                ChoiceEventOverlay(session: session, kind: kind) {}
            }
        }
        .fullScreenCover(isPresented: $showAllocation) {
            AbilityUpView(session: session) { showAllocation = false }
        }
        .sheet(isPresented: $showShop) {
            ShopView(session: session) { showShop = false }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(onClose: { showSettings = false },
                         onQuitRun: { showSettings = false; session.abandonRun() })
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
            } else if burstHold {
                Color.clear.contentShape(Rectangle())
                    .onTapGesture { burstSkip = true }
            }
        }
        .onChange(of: burstHold) { _, holding in
            // 保留が外れたら、チップが引いた後に0.3秒の間を置いてから、立っているイベントを出す（G2）。
            guard !holding else { return }
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                syncEventPresentation()
            }
        }
        .onChange(of: session.pendingChoiceEvent) { _, kind in
            if kind == nil { showEvent = false } else { syncEventPresentation() }
        }
        .onAppear { syncEventPresentation() }   // 中断セーブ復帰・MZ_UI=event など、最初から立っている時
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
            func clearBeat() { if gen == burstGen { withAnimation(Theme.Motion.exit) { beatAdvice = nil } } }
            guard session.lastDeltaWeek == session.week else { clearBeat(); return }
            let chips = makeBurstChips()
            guard !chips.isEmpty else { clearBeat(); return }
            burstChips = chips
            burstVisible = true   // 出現は per-chip の emphSpring+stagger（burstOverlay 側）
            if chips.contains(where: \.up) {
                particleFire += 1     // 同時に立ち絵の頭上で火花が爆ぜる（獲得の「効いた」）
                // 獲得の音: 実力が伸びた週はキラキラ＞汎用ポップ。収支が動いた週はお金の音も重ねる。
                Sound.play(lastJitsuryokuGain > 0.001 ? .grain : .pop)
            }   // 体力が減るだけの週は火花も集中線も音も出さない（損を祝わない・R4 の穴①）
            if session.lastMoneyDelta > 0 { Sound.play(.money) }
            await waitOrSkip(seconds: 1.2)   // 画面タップで畳める（K6）
            clearBeat()
            burstVisible = false   // 退場も per-chip アニメ（下へ沈みつつフェード）
            try? await Task.sleep(nanoseconds: 250_000_000)   // 退場を見せ切ってから cover 解禁（defer）
        }
        .task(id: session.week) {
            // 週送りスタンプ: 週が明けたら「第N週」を一拍（出現spring→0.7s→退場）。入力は遮らない。
            if session.week > 1 { Sound.play(.transition) }   // 週めくりの音（初週の起動時は鳴らさない）
            withAnimation(Theme.Motion.emphSpring) { weekStampVisible = true }
            try? await Task.sleep(nanoseconds: 700_000_000)
            withAnimation(Theme.Motion.exit) { weekStampVisible = false }
        }
        .onAppear { Sound.bgm(.daily) }   // 育成パートのBGM（大会系画面から戻った時も復帰）
        .onChange(of: session.week) { _, _ in banterIndex = 0 }   // 掛け合いの読み位置は週頭でリセット
        .task(id: toast) {
            if let t = toast {
                try? await Task.sleep(nanoseconds: t.count > 20 ? 2_600_000_000 : 1_400_000_000)
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

    /// 試作: 舞台の臙脂＋金の共通ヘッダー帯（決勝の幕と同じ色）。
    private var stageHeaderBand: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Theme.goldLeafHi).frame(height: 1).frame(maxWidth: .infinity)
            Text("\(session.year)年目　第\(session.week)週")
                .font(.maru(15, weight: .black)).foregroundStyle(Theme.goldLeafHi)
                .shadow(color: .black.opacity(0.5), radius: 0, x: 1, y: 1)
            Rectangle().fill(Theme.goldLeafHi).frame(height: 1).frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Theme.curtainLit, Theme.curtain], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.goldLeafMid).frame(height: 2) }
    }

    private var sceneZone: some View {
        sceneBackground
            .background(Color(hex: 0xFFFBF0).ignoresSafeArea(edges: .top))   // ステータスバー裏も稽古場の白
            // 上端中央の目標バナー（2行になる週がある）の下に置く＝重ならない
            .overlay(alignment: .topLeading) { statBars.padding(.leading, 12).padding(.top, 50) }
            .overlay(alignment: .bottomLeading) {
                // 声の席は一つ: Beat1 発話 > 週頭の掛け合い（タップ送り） > 独白。
                if let b = beatAdvice {
                    adviceBox(b).padding(14)
                } else if let lines = session.weekBanter, !lines.isEmpty {
                    banterBox(lines).padding(14)
                } else {
                    monoBox.padding(14)
                }
            }
            .overlay {
                // Beat2 と同時: 集中線（漫画のドン！）＋二人の頭上で獲得チップ同色の火花。
                SpeedLinesBurst(trigger: particleFire, center: UnitPoint(x: 0.62, y: 0.55))
                ParticleBurst(trigger: particleFire,
                              colors: burstChips.filter(\.up).map(\.bg),
                              style: .spark, count: 26,
                              origin: UnitPoint(x: 0.62, y: 0.60))
            }
            .overlay(alignment: .bottomTrailing) {
                // Beat2 獲得バースト: 立ち絵の頭上に獲得チップが立ち上る（触れない・入力遮断なし）。
                // 人形の大型化に合わせ頭上へ逃がす（頭に被ると谷口が首なしに見える）。
                burstOverlay
                    .padding(.trailing, 36).padding(.bottom, 150)   // 谷口の頭のすぐ上（旧262＝寄席ポスターに重なっていた）
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .top) {
                // 常時目標バナー（パワプロの「ドラフトまであとN週」の席）。タップでカレンダー。
                goalBanner.padding(.top, 10)
            }
            .overlay {
                // 週送りスタンプ: 週が明けた瞬間に「第N週」が一拍だけ立つ（Beat2 の前座・触れない）。
                if weekStampVisible {
                    Text("第\(session.week)週")
                        .font(.maru(21)).tracking(6).foregroundStyle(Theme.ink.opacity(0.88))
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .background(.white.opacity(0.88), in: Capsule())
                        .e1()
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
        if let m = nextMilestone() {
            Button { showCalendar = true } label: {
                VStack(spacing: 1) {
                    HStack(spacing: 5) {
                        Image(systemName: "flag.fill").font(.system(size: 8.5))
                            .foregroundStyle(m.weeksLeft <= 3 ? Theme.verm : Theme.gold)
                        Text(m.name).font(.maru(10.5)).foregroundStyle(.white.opacity(0.92)).lineLimit(1)
                        Text(m.weeksLeft <= 0 ? "今週！" : "あと\(m.weeksLeft)週")
                            .font(.maru(12)).monospacedDigit()
                            .foregroundStyle(m.weeksLeft <= 3 ? Theme.verm : Theme.gold)
                            .contentTransition(.numericText())
                    }
                    if m.weeksLeft <= 2 && unspentBeforeStage {
                        // 大会前の振り忘れ（オーナー判断 2026-10-12：知らせるだけ・自動では振らない）
                        Text("経験点が残ってる ・ 能力アップで使おう")
                            .font(.maru(10.5, weight: .bold)).foregroundStyle(Theme.gold)   // 9.5pt は小さすぎた
                    } else if m.weeksLeft >= 6 {
                        Text(lullLine())
                            .font(.maru(10.5)).foregroundStyle(.white.opacity(0.8))   // 9pt・白65%は小さく薄すぎた
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Theme.pillDark, in: Capsule())
                .overlay(Capsule().stroke((m.weeksLeft <= 3 ? Theme.verm : Theme.gold).opacity(0.55), lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
        }
    }

    private var sceneBackground: some View {
        // 稽古場シーン（StageScene.swift）: 明るい昼の稽古場＋板張り＋センターマイク＋漫才師2人＋光の中の塵。
        // 立ち絵イラスト導入までの見た目の到達点（TODO: 本イラスト差替）。上端はステータスバー裏まで届かせる。
        StageScene().ignoresSafeArea(edges: .top)
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
        return VStack(alignment: .leading, spacing: 7) {
            statBar(name: "実力", glyph: "sparkles", color: Theme.curtainLit,
                    value: GameEngine.jitsuryoku(s, config: cfg), fill: jitsuFill,
                    gainFill: budget > 0 ? lastJitsuryokuGain / budget : 0)
            statBar(name: "相性", glyph: "heart.fill", color: Theme.curtainLit,
                    value: s.compat, fill: compatFill,
                    gainFill: max(0, session.lastCompatGain) / cfg.compatCap)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(width: 214)
        .background(Color(hex: 0xFBF3E2).opacity(0.94))
        .overlay(Rectangle().stroke(Theme.sumi, lineWidth: 1.5))
        .overlay(Rectangle().stroke(Theme.goldLeafMid, lineWidth: 0.8).padding(3))
    }

    /// 1本のバー。週送りの直後（gainsVisible）だけ、この週に伸びた分をオレンジで重ねる＝「押した週に何が動いたか」。
    /// 満ちたら縁が金（旧ピルの上限到達と同じ文法）。色＋アイコン＋名前で区別（§6-5）。
    private func statBar(name: String, glyph: String, color: Color, value: Double, fill: Double, gainFill: Double) -> some View {
        let full = fill >= 0.999
        let shown = gainsVisible && session.lastDeltaWeek == session.week ? min(gainFill, fill) : 0
        return HStack(spacing: 7) {
            Text(name).font(.maru(13, weight: .black)).foregroundStyle(Theme.sumi).fixedSize()
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.14))
                    Capsule().fill(color).frame(width: w * fill)
                    Rectangle().fill(Theme.gainOrange)
                        .frame(width: w * shown)
                        .offset(x: w * (fill - shown))
                        .opacity(shown > 0 ? 1 : 0)
                }
                .clipShape(Capsule())
                .overlay(Capsule().stroke(full ? Theme.gold : color.opacity(0.5), lineWidth: full ? 2 : 1))
                .animation(.easeOut(duration: 0.6), value: fill)
                .animation(.easeOut(duration: 0.3), value: shown)
            }
            .frame(height: 8)
            Text("\(Int(value.rounded()))").font(.maru(26, weight: .black)).monospacedDigit().foregroundStyle(Theme.curtain)
                .shadow(color: Theme.goldLeafHi, radius: 0, x: 1, y: 1)
                .frame(minWidth: 26, alignment: .trailing).fixedSize()   // 3桁でも切れない（旧 width 26 は「100」で溢れた）
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.3), value: Int(value.rounded()))
                .punch(on: Int(value.rounded()), peak: 1.35)   // 整数が動いた瞬間だけ跳ねる
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
            .overlay(alignment: .bottomTrailing) {
                if i < lines.count - 1 {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 8)).foregroundStyle(Theme.inkFaint)
                        .padding(6)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if i < lines.count - 1 { withAnimation(.easeOut(duration: 0.18)) { banterIndex += 1 } }
            }
    }

    private func adviceBox(_ a: Advice) -> some View {
        // パワプロ・サクセス式の会話: 顔グラ＋名前タブ＋白地チャンキーの台詞ボックス。
        let name = a.name ?? "俺"
        return HStack(alignment: .bottom, spacing: 8) {
            VStack(spacing: 3) {
                CharacterFace(spec: FaceCatalog.speaker(name), size: 52)
                    .overlay(Circle().stroke(.white, lineWidth: 2.5))
                    .shadow(color: Theme.ink.opacity(0.2), radius: 0, y: 2)
                Text(name).font(.maru(11)).foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(name == "谷口" ? Theme.verm : Color(hex: 0x4A7BE8), in: Capsule())
            }
            Text(a.text)
                .font(.system(size: 13.5, weight: .medium)).lineSpacing(3)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .frame(maxWidth: 250, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(.white).shadow(color: Theme.cmdShadow, radius: 0, y: 3))   // 影は形だけ（全体に掛けると中の文字にも影が付いた）
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 2.5))
        }
        .id(a.text)
        .transition(.opacity)
    }

    // MARK: 行動カード（常設4枚 2×2＋条件付きの小カード。タップ＝即実行・ゲート/¥不足は toast で無効化）

    private var commandZone: some View {
        let extras = extraCards
        let showYearEnd = session.noStagesLeft && session.week < session.config.weeks
        return VStack(spacing: 9) {
            // 常設4枚は位置を動かさない（条件付きのカードは下に足す＝親指が覚えた場所が週ごとにずれない）
            if let cat = openCat {
                // 下位一覧：戻る＋種類のカード（小さめ・2列）。実行したら4ボタンへ戻る
                HStack(spacing: 8) {
                    Button { withAnimation(Theme.Motion.appearQuick) { if pickingNeta { pickingNeta = false } else { openCat = nil; openNetaWrite = false; newNetaTitle = nil } } } label: {
                        Label("もどる", systemImage: "chevron.left").font(.maru(13, weight: .bold))
                            .foregroundStyle(Theme.inkSub).padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Theme.card, in: Capsule())
                    }.buttonStyle(PressableStyle())
                    Text(openNetaWrite ? "ネタを書く" : cat.rawValue).font(.maru(16, weight: .heavy)).foregroundStyle(Theme.ink)
                    Spacer()
                }
                if openNetaWrite {
                    netaWriteList.transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 2), spacing: 9) {
                        ForEach(CommandCatalog.cards(cat, config: session.config, money: s.money)) { v in
                            actionCard(v, compact: true, dashed: false)
                        }
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            } else {
                // 6つを同じ大きさの2×3（オーナー 2026-10-12「視認性悪いからアイテムショップもここに」）
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 2), spacing: 9) {
                    ForEach(CommandCategory.allCases) { c in categoryTile(c) }
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
            if !extras.isEmpty || showYearEnd {
                HStack(spacing: 9) {
                    ForEach(extras) { v in actionCard(v, compact: true) }
                    if showYearEnd { yearEndTile }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 8)
        .background(LinearGradient(colors: [.clear, Color(hex: 0xFFEFDD)], startPoint: .top, endPoint: .center))
        .animation(Theme.Motion.appearQuick, value: extras.map(\.id))
    }

    // MARK: ネタを書く（どのネタを磨くか／新しく書くか）

    /// 完成度の段階名（表示のみ・閾値【仮】）。業界語を避けた普通の言葉（会話ルールv3）
    static func netaStage(_ polish: Double) -> String {
        switch polish {
        case ..<25: return "書きかけ"
        case ..<50: return "形になってきた"
        case ..<75: return "仕上がってきた"
        case ..<90: return "よく仕上がった"
        default: return "完成"
        }
    }

    /// 書く対象のネタ（エンジンの規則どおり：勝負ネタ→無ければ枠が空いていれば新ネタ→満杯なら最後のネタ）
    private var writeTarget: Neta? {
        if newNetaTitle != nil { return nil }
        if let n = session.selectedNeta { return n }
        return session.activeNetas.count < session.config.netaActiveSlots ? nil : session.activeNetas.last
    }

    /// ネタを書く＝場所の一覧（家／喫茶店／ファミレス）＋上に「書くネタ」（替える・新しく書く＋題名）
    private var netaWriteList: some View {
        let cfg = session.config
        return VStack(spacing: 7) {
            netaTargetBar
            if pickingNeta { netaPicker }
            if newNetaTitle != nil || (writeTarget == nil && !pickingNeta) { netaTitleField }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 2), spacing: 9) {
                ForEach(CommandCatalog.netaPlaces(config: cfg, money: s.money)) { v in
                    actionCard(v, compact: true, dashed: false)
                }
            }
        }
    }

    private var netaTargetBar: some View {
        let t = writeTarget
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("書くネタ").font(.maru(10.5, weight: .bold)).foregroundStyle(Theme.inkSub)
                if let n = t {
                    HStack(spacing: 6) {
                        Text("「\(n.name)」").font(.maru(14, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(1)
                        Text("\(Self.netaStage(n.polish)) ・ 完成度 \(Int(n.polish))").font(.maru(10.5, weight: .bold))
                            .foregroundStyle(Theme.ideaDeep).lineLimit(1)
                    }
                } else {
                    Text("新しいネタ").font(.maru(14, weight: .bold)).foregroundStyle(Theme.ideaDeep)
                }
            }
            Spacer(minLength: 4)
            if !session.activeNetas.isEmpty {
                Button { withAnimation(Theme.Motion.appearQuick) { pickingNeta.toggle() } } label: {
                    Text(pickingNeta ? "とじる" : "替える").font(.maru(12, weight: .bold)).foregroundStyle(Theme.ideaDeep)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .overlay(Capsule().stroke(Theme.cIdea.opacity(0.7), lineWidth: 1.5))
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card))
    }

    /// 書くネタを替える（持ちネタ＋新しく書く）。選ぶだけ（週は進まない・乱数なし）
    private var netaPicker: some View {
        let cfg = session.config
        return VStack(spacing: 6) {
            ForEach(session.activeNetas, id: \.id) { n in
                Button {
                    session.selectNeta(n.id)
                    withAnimation(Theme.Motion.appearQuick) { newNetaTitle = nil; pickingNeta = false }
                } label: {
                    HStack(spacing: 8) {
                        Text("「\(n.name)」").font(.maru(13.5, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(1)
                        Text(Self.netaStage(n.polish)).font(.maru(10, weight: .bold)).foregroundStyle(Theme.ideaDeep)
                        Spacer()
                        Text("完成度 \(Int(n.polish)) ・ 舞台 \(n.stageCount)回").font(.maru(10.5)).monospacedDigit().foregroundStyle(Theme.inkSub)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(n.id == writeTarget?.id ? Theme.cIdea.opacity(0.10) : Theme.card, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(PressableStyle())
            }
            if session.activeNetas.count < cfg.netaActiveSlots {
                Button {
                    session.selectNeta(nil)
                    withAnimation(Theme.Motion.appearQuick) { newNetaTitle = ""; pickingNeta = false }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 12, weight: .heavy))
                        Text("新しく書く").font(.maru(13.5, weight: .bold))
                        Spacer()
                        Text("あと\(cfg.netaActiveSlots - session.activeNetas.count)本").font(.maru(10.5)).foregroundStyle(Theme.inkSub)
                    }
                    .foregroundStyle(Theme.ideaDeep)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cIdea.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    /// 新しいネタの題名（空欄＝おまかせ）。オーナー 2026-10-12「タイトル決めとかこっちでかけるように」
    private var netaTitleField: some View {
        HStack(spacing: 8) {
            Text("題名").font(.maru(11, weight: .bold)).foregroundStyle(Theme.inkSub)
            TextField(NetaCatalog.autoName(forID: s.nextNetaID),
                      text: Binding(get: { newNetaTitle ?? "" }, set: { newNetaTitle = String($0.prefix(16)) }))
                .font(.maru(15, weight: .bold)).foregroundStyle(Theme.ink)
                .submitLabel(.done)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(Theme.card2, in: RoundedRectangle(cornerRadius: 10))
    }

    /// 場所を押した時：新しく書くなら題名を予約して、エンジンが新ネタを作るようにする
    private func prepareNetaTarget() {
        guard writeTarget == nil else { return }
        session.selectNeta(nil)
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
            burstGen += 1               // choose が選択肢イベントを立てても Beat2 退場まで cover を待たせる
            burstHold = true
            Haptics.tick()              // 振動は実行（=週送り）のみ（Haptics 3段）
            session.choose(v.action)    // ＝即実行・1週進む（つぎへ廃止）
            if let p = pendingNetaTitle {   // 新しいネタに、プレイヤーが付けた題名を付ける
                if session.activeNetas.contains(where: { $0.id == p.id }) { session.renameNeta(p.id, to: p.title) }
                pendingNetaTitle = nil
            }
            withAnimation(Theme.Motion.appear) { pulledID = nil; openCat = nil; openNetaWrite = false; newNetaTitle = nil; pickingNeta = false }   // 実行したら4ボタンへ戻る
        }
    }

    private func actionCard(_ v: CommandVariant, compact: Bool = false, dashed: Bool? = nil) -> some View {
        let preoccupied = v.isTrain && s.preoccupiedWeeks > 0                       // 0022 撮影で稽古枠が埋まった週
        let gated = v.isTrain && (s.stamina < session.config.staminaGate || s.preoccupiedWeeks > 0)
        let blocked = gated || !v.affordable
        return Button {
            guard pulledID == nil, !burstHold, session.pendingChoiceEvent == nil else { return }   // 多重タップ・バースト中は無視（監査F-10）
            if blocked {
                // 沈まず横ブレ＝「押せない」の触感文法（§3-1）。振動は付けない（閲覧扱い）。
                Sound.play(.deny)
                withAnimation(.linear(duration: 0.15)) { shakeSeed[v.id, default: 0] += 1 }
                showToast(preoccupied ? "今週は撮影。稽古の時間がない。" : gated ? "体力が足りない。今日は休もう。" : "お金が足りない。")
                return
            }
            if openCat == .ネタを書く { prepareNetaTarget() }
            perform(v)
        } label: {
            actionCardLabel(v, gated: gated, preoccupied: preoccupied, compact: compact, dashed: dashed ?? compact)
                .scaleEffect(pulledID == v.id ? 1.06 : 1)   // 実行時に軽くポップ（引き抜きの手応え・0.12s budget内）
                .opacity(pulledID == v.id ? 0 : 1)
        }
        .buttonStyle(PressableStyle(enabled: !blocked))
        .modifier(ShakeEffect(animatableData: shakeSeed[v.id] ?? 0))
    }

    /// 大会が近く（2週以内）、まだ振れる経験点がある＝バナーと能力アップの縁で知らせる（振るのは自分）
    private var unspentBeforeStage: Bool {
        guard expGrains > 0, let m = nextMilestone(), m.weeksLeft <= 2 else { return false }
        return !session.recommendedAllocation().isEmpty
    }

    /// たまっている経験点の合計（粒・切り捨て）
    private var expGrains: Int { AbilityUpView.points(s.expTotal) }

    /// 4ボタンの1枚（パワプロ式）。押すと下位一覧へ。能力アップは経験点の振り分け画面（AllocationView）
    private func categoryTile(_ c: CommandCategory) -> some View {
        let tint: Color = { switch c { case .ネタを書く: return Theme.cIdea; case .練習: return Theme.cExpr; case .バイト: return Theme.cMoney
                                      case .休む: return Theme.night; case .能力アップ: return Theme.gold; case .お店: return Theme.cChara } }()
        let ready = c == .能力アップ && expGrains > 0
        let gated = (c == .練習 || c == .ネタを書く) && (s.stamina < session.config.staminaGate || s.preoccupiedWeeks > 0)
        let sub: String = {
            switch c {
            case .ネタを書く:
                if gated { return s.preoccupiedWeeks > 0 ? "今週は撮影" : "体力が足りない" }
                if let n = session.selectedNeta { return "\(session.activeNetas.count)本 ・ 勝負ネタ「\(n.name)」" }
                return session.activeNetas.isEmpty ? "まだネタがない。まず一本" : "\(session.activeNetas.count)本 書いた"
            case .練習: return gated ? (s.preoccupiedWeeks > 0 ? "今週は撮影" : "体力が足りない") : "合わせ・舞台 ほか"
            case .バイト: return "お金を稼ぐ"
            case .休む: return "体力を戻す"
            case .能力アップ:
                if unspentBeforeStage { return "大会前に経験点を使おう" }
                return expGrains > 0 ? "経験点 \(expGrains) たまってる" : "経験点で能力を上げる"
            case .お店: return "アイテムを買う"
            }
        }()
        return Button {
            guard pulledID == nil, !burstHold, session.pendingChoiceEvent == nil else { return }
            if gated {
                Sound.play(.deny)
                showToast(s.preoccupiedWeeks > 0 ? "今週は撮影。稽古の時間がない。" : "体力が足りない。今日は休もう。")
                return
            }
            Sound.play(.tap)
            if c == .能力アップ { showAllocation = true; return }
            if c == .お店 { showShop = true; return }
            withAnimation(Theme.Motion.appearQuick) {
                openCat = c
                if c == .ネタを書く { openNetaWrite = true }
            }
        } label: {
            let big = (c == .ネタを書く || c == .練習)
            VStack(alignment: .leading, spacing: 6) {
                Text(c.rawValue).font(.maru(big ? 26 : 19, weight: .black))
                    .foregroundStyle(gated ? Theme.inkFaint : Theme.sumi)
                    .shadow(color: gated ? .clear : Theme.goldLeafHi.opacity(0.8), radius: 0, x: 1, y: 1)
                Text(sub).font(.maru(12, weight: .bold)).foregroundStyle(gated ? Theme.vermD : ready ? Theme.goldDeep : Theme.inkSub).lineLimit(1)
            }
            .padding(.horizontal, 14).padding(.vertical, big ? 14 : 9)
            .frame(maxWidth: .infinity, minHeight: big ? 84 : 62, alignment: .leading)
            .background(Rectangle().fill(gated ? Color(hex: 0xEFE8DA) : Color(hex: 0xFBF3E2)))
            .overlay(alignment: .leading) { Rectangle().fill(gated ? Theme.line : Theme.verm).frame(width: 5) }
            .overlay(Rectangle().stroke(gated ? Theme.line : (c == .能力アップ && unspentBeforeStage) ? Theme.gold : Theme.sumi,
                                        lineWidth: (c == .能力アップ && unspentBeforeStage) ? 3.5 : 1.5))
        }
        .buttonStyle(PressableStyle())
    }

    /// カードの顔: アイコン＋名前／伸び（実力 ↑・相性 +N・ネタ +N）／コスト（所持金・体力）。
    /// compact（条件付きの小カード）は伸びとコストを1行にまとめ、破線の縁で「今だけのカード」と分ける。
    private func actionCardLabel(_ v: CommandVariant, gated: Bool, preoccupied: Bool, compact: Bool, dashed: Bool) -> some View {
        let after = session.previewAfterPour(v.action, offer: offer)
        let effects = (gated || !v.affordable) ? [] : cardEffects(v, after: after)
        let moneyDelta = after.money - s.money
        let stamDelta = Int(after.stamina.rounded()) - Int(s.stamina.rounded())
        let tint = cardTint(v)
        return VStack(alignment: .leading, spacing: compact ? 5 : 7) {
            HStack(spacing: 7) {
                Image(systemName: v.glyph)
                    .font(.system(size: compact ? 11 : 13, weight: .bold)).foregroundStyle(.white)
                    .frame(width: compact ? 22 : 26, height: compact ? 22 : 26)
                    .background(gated ? Theme.inkFaint : tint, in: RoundedRectangle(cornerRadius: 7))
                Text(v.name).font(.maru(compact ? 13 : 15)).foregroundStyle(gated ? Theme.inkSub : Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                if case .acceptOffer = v.action {
                    Text(v.desc).font(.maru(10)).foregroundStyle(Theme.goldD).lineLimit(1)   // オファー名（既存の OfferSpec.name）
                }
            }
            if compact, !dashed, !gated {
                Text(v.desc).font(.maru(10.5)).foregroundStyle(Theme.inkSub).lineLimit(1)
            }
            if gated {
                Text(preoccupied ? "今週は撮影で練習できない" : "体力が足りない ・ 休もう").font(.maru(13, weight: .bold)).foregroundStyle(Theme.vermD)
            } else if !v.affordable {
                Text("¥不足").font(.maru(10.5)).foregroundStyle(Theme.verm)
            } else if !compact, !effects.isEmpty {
                HStack(spacing: 4) { ForEach(effects, id: \.text) { effectPill($0) } }
            }
            if !compact { Spacer(minLength: 0) }
            // 一覧（compact かつ実線）は伸びとコストを2行に分ける＝2列の幅でも札が切れない
            if compact, !dashed, !effects.isEmpty {
                ViewThatFits(in: .horizontal) {   // 入りきらなければ2段に折る（札を「…」で切らない）
                    HStack(spacing: 4) { ForEach(effects, id: \.text) { effectPill($0).fixedSize() } }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) { ForEach(effects.prefix(2), id: \.text) { effectPill($0).fixedSize() } }
                        HStack(spacing: 4) { ForEach(effects.dropFirst(2), id: \.text) { effectPill($0).fixedSize() } }
                    }
                }
            }
            HStack(spacing: 4) {
                if compact, dashed { ForEach(effects, id: \.text) { effectPill($0) } }
                if moneyDelta != 0 { costPill(money: moneyDelta, insufficient: !v.affordable) }
                if stamDelta != 0 { staminaPill(stamDelta, insufficient: gated) }
            }
        }
        .padding(.horizontal, 11).padding(.vertical, compact ? 8 : 10)
        .frame(maxWidth: .infinity, minHeight: compact ? nil : 92, maxHeight: compact ? .infinity : nil, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: Theme.Rad.card).fill(gated ? Color(hex: 0xF3EFE7) : Theme.card).shadow(color: Theme.cmdShadow, radius: 0, y: 3))   // 影は形だけ（全体に掛けると中の文字にも影が付いた）
        .overlay(RoundedRectangle(cornerRadius: Theme.Rad.card)
            .stroke(gated ? Theme.line : tint.opacity(compact ? 0.8 : 0.55),
                    style: StrokeStyle(lineWidth: 3, dash: dashed ? [6, 4] : [])))
        // 押せないカードは地と縁で言う（全体を薄くすると一番読ませたい「今日は休め」が1.8〜2.2:1まで落ちた）
    }

    /// カードごとの地色（アイコン地・縁）。色だけに頼らずアイコン＋名前でも区別する（§6-5）。
    private func cardTint(_ v: CommandVariant) -> Color {
        switch v.action {
        case .train(.ネタ作り), .train(.喫茶店で書く), .train(.ファミレスで書く): return Theme.cIdea   // 書く場所は3つとも「ネタを書く」の色
        case .train(.ネタ合わせ): return Theme.cCompat
        case .train: return Theme.cExpr
        case .rest: return Theme.night
        case .job: return Theme.cMoney
        case .acceptOffer: return Theme.gold
        }
    }

    private func effectPill(_ e: CardEffect) -> some View {
        // 字は濃い版（白地/10%地で4.5:1以上・K3）。3枚並んでも溢れないよう縮小可
        Text(e.text).font(.maru(12, weight: .heavy)).foregroundStyle(e.color)
            .lineLimit(1).minimumScaleFactor(0.8)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(e.color.opacity(0.10), in: Capsule())
            .overlay(Capsule().stroke(e.color.opacity(0.7), lineWidth: 1.5))
    }

    // MARK: Beat2 獲得バースト（この週の行動で入ったものが立ち絵の頭上に立ち上る）

    /// 出現は下から stagger（0.07s刻み・emphSpring）、退場は逆再生。チップの色はカードの伸びと同じ＝予告と着地が同じ顔。
    private var burstOverlay: some View {
        VStack(alignment: .trailing, spacing: 5) {
            ForEach(Array(burstChips.enumerated()), id: \.element.id) { i, chip in
                burstChipView(chip)
                    .opacity(burstVisible ? 1 : 0)
                    .offset(y: burstVisible ? 0 : 16)
                    .scaleEffect(burstVisible ? 1 : 0.7, anchor: .bottomTrailing)
                    .animation(Theme.Motion.emphSpring.delay(Double(i) * 0.07), value: burstVisible)
            }
        }
    }

    private func burstChipView(_ chip: BurstChip) -> some View {
        // パワプロの「＋経験点ドン」＝でかく・白縁・ハード影（小さくつつましい獲得表示は手応えが死ぬ）。
        Text(chip.text).font(.maru(17, weight: .black)).foregroundStyle(chip.fg)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(chip.bg, in: Capsule())
            .overlay(Capsule().stroke(chip.up ? .white : Theme.lineStrong, lineWidth: 2))
            .shadow(color: Theme.ink.opacity(0.25), radius: 0, y: 3)
    }

    /// 立っている選択肢イベントを、今出してよければ出す（獲得の一拍・引き抜きの最中は待たせる）。
    private func syncEventPresentation() {
        if session.pendingChoiceEvent != nil, !burstHold, pulledID == nil { showEvent = true }
    }

    /// 指定秒だけ待つ。途中で burstSkip が立てば即戻る（タスクの取り消しでも即戻る）。
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
        if fd > 0.001 {
            chips.append(BurstChip(id: chips.count, text: "知名度 +\(max(1, Int(fd.rounded())))", fg: .white, bg: Theme.goldDeep))
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
        let man = Double(abs(money)) / 10000
        let txt = (man == man.rounded() ? String(Int(man)) : String(format: "%.1f", man))
        return Text("\(up ? "+" : "-")¥\(txt)万")
            .font(.system(size: 12, weight: .heavy)).lineLimit(1).fixedSize()
            .foregroundStyle(insufficient ? .white : (up ? Theme.cMoney : Theme.verm))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(insufficient ? Theme.staminaCrit : (up ? Theme.cMoney : Theme.verm).opacity(0.14), in: Capsule())
    }

    private func staminaPill(_ delta: Int, insufficient: Bool = false) -> some View {
        let up = delta > 0
        return Text("体力 \(up ? "+" : "")\(delta)")
            .font(.system(size: 12, weight: .heavy)).lineLimit(1).fixedSize()
            .foregroundStyle(insufficient ? .white : (up ? Theme.cMental : Theme.inkDim))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(insufficient ? Theme.staminaCrit : (up ? Theme.cMental : Theme.inkDim).opacity(0.14), in: Capsule())
    }

    // MARK: 最下部の帯（年週・大会までN週・体力ゲージ・所持金）

    /// 最下帯（2026-10-12 作り直し・オーナー「アイテムとかの下のUIUXまだ悪い」）：
    /// 上段＝年週・体力・所持金（いつも見る数字）／下段＝名前付きのメニュー4つ（日程・コンビ・お店・設定）。
    /// 大会までの週は上の目標バナーと重複するので外した。
    private var botbar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(session.year)年目").font(.maru(11)).foregroundStyle(.white.opacity(0.7))
                    Text("\(session.week)週").font(.maru(24, weight: .black)).foregroundStyle(Theme.goldLeafHi)
                        .contentTransition(.numericText())
                }
                .fixedSize()
                staminaGauge
                Spacer(minLength: 4)
                Text(Yen.text(s.money)).font(.maru(15)).monospacedDigit()
                    .foregroundStyle(s.money < 0 ? Theme.verm : .white)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .contentTransition(.numericText())            // 収支が動くと数字が繰る
                    .punch(on: s.money, peak: 1.18)               // ＋跳ねる（ジュース核）
                    .animation(.easeOut(duration: 0.4), value: s.money)
            }
            HStack(spacing: 6) {
                menuButton("calendar", "日程") { showCalendar = true }              // S4 カレンダー
                menuButton("person.2.fill", "コンビ") { showNotebook = true }       // S5 コンビの情報（旧ネタ帳）
                menuButton("gearshape.fill", "設定") { showSettings = true }        // 音量・この年をやめる（監査G-04）
            }
        }
        .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 12)
        .background(Theme.curtainShade.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Theme.goldLeafMid).frame(height: 2) }
    }

    private func menuButton(_ glyph: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: glyph).font(.system(size: 16, weight: .semibold))
                Text(label).font(.maru(10.5, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.9))
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }

    private var staminaColor: Color {
        if s.stamina < 20 { return Theme.staminaCrit }      // 危険（赤・staminaGate可視化）
        if s.stamina < 50 { return Theme.staminaWarn }      // 警告（黄）
        return Theme.cMental                                // 好調（緑）
    }

    /// 体力の3段ゾーン（2=緑/1=黄/0=赤）。閾値は黄50未満・赤20未満（第1便§0裁定①）。
    private var staminaZone: Int {
        if s.stamina < 20 { return 0 }
        if s.stamina < 50 { return 1 }
        return 2
    }

    private var staminaGauge: some View {
        HStack(spacing: 5) {
            Text("体力").font(.maru(10)).foregroundStyle(.white.opacity(0.8)).fixedSize()
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.16))
                Capsule()
                    .fill(LinearGradient(colors: [staminaColor.opacity(0.82), staminaColor], startPoint: .top, endPoint: .bottom))
                    .frame(width: 96 * CGFloat(max(0, min(100, s.stamina)) / 100))
                    .shadow(color: staminaColor.opacity(0.6), radius: 3)
                    .animation(.easeOut(duration: 0.4), value: s.stamina)
                    .animation(.easeInOut(duration: 0.15), value: staminaZone)  // 閾値跨ぎの色クロスフェード（§3-4）
            }
            .frame(width: 96, height: 10)
            .opacity(gaugeFlash ? 0.25 : 1)
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
            Text("\(Int(s.stamina.rounded()))").font(.maru(13)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
                .foregroundStyle(staminaColor).frame(width: 30, alignment: .trailing)
        }
    }

    // MARK: トースト

    @ViewBuilder private var toastBar: some View {
        if let toast {
            Text(toast).font(.maru(12)).foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 9)
                .background(Theme.pillDark, in: Capsule())
                .e1()
                .padding(.bottom, 78)   // 最下帯の上+16pt（§3-5）
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func showToast(_ t: String) { toast = t }

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
            out.append(CardEffect(text: "実力 ↑", color: Theme.senseDeep))
        }
        // 手動の能力アップ：稽古で入る経験点を出す（パワプロの練習画面と同じ「何が貯まるか」）。大きい順に最大2つ
        let gains = ExpCurrency.allCases.map { ($0, after[currency: $0] - s[currency: $0]) }.filter { $0.1 > 0.001 }
            .sorted { $0.1 > $1.1 }.prefix(2)
        for (c, d) in gains {
            out.append(CardEffect(text: "\(c) +\(max(1, Int(d.rounded())))", color: Theme.currencyColor(c)))
        }
        let cd = Int(after.compat.rounded()) - Int(s.compat.rounded())
        if cd > 0 { out.append(CardEffect(text: "相性 +\(cd)", color: Theme.vermD)) }
        if let neta = netaEffect(v.action) { out.append(CardEffect(text: neta, color: Theme.ideaDeep)) }
        // G1: 舞台に立つ週は知名度が上がる＝押した週に必ず何かが残ることをカードで予告する
        let fd = after.fame - s.fame
        if fd > 0.001 { out.append(CardEffect(text: "知名度 +\(max(1, Int(fd.rounded())))", color: Theme.goldDeep)) }
        return out
    }

    /// ネタへの効き（旧 trainExtras と同じ名目値・監査E-06）。ネタを書く＝選択中ネタの改稿 or 新ネタ／舞台に立つ＝客前で磨く。
    private func netaEffect(_ action: WeekAction) -> String? {
        guard case .train(let t) = action else { return nil }
        let cfg = session.config
        switch t {
        case .ネタ作り, .喫茶店で書く, .ファミレスで書く:
            let gain = cfg.netaPlaceGain[t] ?? cfg.netaReviseGain
            return writeTarget != nil ? "ネタ +\(Int(gain))" : "新ネタ"
        case .ネタ見せ会 where !s.netas.isEmpty:
            return "ネタ +\(Int(cfg.netaLivePolishShow))"
        case .フリーライブ where !s.netas.isEmpty:
            return "ネタ +\(Int(cfg.netaLivePolishFree))"
        default:
            return nil
        }
    }

    /// 本番が遠い週の目標バナー2行目＝いまのネタの完成度（監査A-01: 中だるみ帯の副目標）
    private func lullLine() -> String {
        let cur = s.selectedNetaID.flatMap { id in s.netas.first { $0.id == id } } ?? s.netas.last
        guard let n = cur else { return "大会まで間がある ・ まずはネタを書こう" }
        return "大会まで間がある ・ ネタ「\(n.name)」完成度 \(Int(n.polish))/100"
    }

    /// 年末へ（GPの道が閉じ、出られる本番が残っていない時だけ・二度押しで実行＝監査A-03）
    private var yearEndTile: some View {
        Button {
            if burstHold || session.pendingChoiceEvent != nil { return }
            if yearEndArmed {
                yearEndArmed = false
                session.fastForwardToYearEnd()
            } else {
                yearEndArmed = true
                showToast("もう一度押すと、残りの週を休んで年末の結果へ進む。")
                Task { try? await Task.sleep(nanoseconds: 3_000_000_000); yearEndArmed = false }
            }
        } label: {
            // 条件付きの小カード（オファー/バイト）と同じ顔＝常設4枚の下に破線で並ぶ
            HStack(spacing: 7) {
                Image(systemName: "forward.end.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Theme.inkDim, in: RoundedRectangle(cornerRadius: 7))
                Text(yearEndArmed ? "もう一度" : "年末へ").font(.maru(13)).foregroundStyle(Theme.inkDim).lineLimit(1)
            }
            .padding(.horizontal, 11).padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Theme.card2, in: RoundedRectangle(cornerRadius: Theme.Rad.card))
            .overlay(RoundedRectangle(cornerRadius: Theme.Rad.card).stroke(Theme.line, style: StrokeStyle(lineWidth: 3, dash: [6, 4])))
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
