// WeekMainView.swift
// SCREEN 01 育成メイン（A「削る」スライス1・docs/fun_uiux_overhaul_v0.md §5-1 A列／§6-1）。
// 上＝立ち絵シーン（左上にピル・未選択時は心の声）／下＝行動カード4枚（2×2・常設）＋条件付きの小カード
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

    /// 実行直後だけ true。ピルの「+N」を一瞬見せる（既存の lastGains 機構を流用）。
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
    /// 満了成立後の週メイン初回トースト（この年1回だけ）用フラグ。
    @State private var vesselFullToastShown = false
    /// 週送りスタンプ「第N週」（週が明けた瞬間に中央で0.7sフラッシュ・触れない）。
    @State private var weekStampVisible = false
    /// Beat2 と同時に爆ぜる獲得パーティクル（+1で一回・Juice.swift）。
    @State private var particleFire = 0
    /// 谷口評（5能力平均のランク）がランクアップした瞬間の punch（AllocationView のグレード昇格と同じ文法）。
    @State private var rankPunch = false
    /// 週頭の掛け合いのタップ送り位置（週が明けたら0に戻す）。
    @State private var banterIndex = 0
    /// Beat1 の一言を最後に出した週（変種ごと）。直近4週に出した変種は一言を省く＝最頻出テキストの間引き（監査A-04）
    @State private var lastBeatWeek: [String: Int] = [:]
    /// 「年末へ」の二度押し確認（監査A-03）
    @State private var yearEndArmed = false
    /// 進行中の設定（監査G-04）
    @State private var showSettings = false

    private var s: GameState { session.state }
    private var mainCards: [CommandVariant] {
        CommandCatalog.mainCards(config: session.config, money: s.money)
    }
    private var extraCards: [CommandVariant] {
        CommandCatalog.extraCards(config: session.config, offer: offer, money: s.money)
    }

    var body: some View {
        VStack(spacing: 0) {
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
            // burstHold は choose 直前に立ち、バースト退場（または対象なし）で必ず下りる。
            get: { session.pendingChoiceEvent != nil && !burstHold },
            set: { if !$0 { session.dismissChoiceEvent() } }
        )) {
            // 選択肢イベント（0024ピース3・確定発火）。pendingChoiceEvent は private(set) なので
            // Bool の合成 Binding 経由（既存 showNotebook 等と同じ isPresented パターン）。
            if let kind = session.pendingChoiceEvent {
                ChoiceEventOverlay(session: session, kind: kind) {}
            }
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
            // 別カードが暴発しない安全網を兼ねる。週送り後（Beat2 中）は即座に外れて入力自由。
            if pulledID != nil {
                Color.clear.contentShape(Rectangle())
                    .onTapGesture { beatTask?.cancel() }
            }
        }
        .task(id: session.week) {
            // 新しい週に入ったら「+N」を一瞬見せる（ピルのオレンジ）。相性/オファー能力は今も直接効くのでこのまま。
            if !session.lastGains.isEmpty || session.lastCompatGain > 0.001 {
                gainsVisible = true
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                gainsVisible = false
            }
        }
        .task(id: session.week) {
            // Beat2 獲得の一拍: この週の行動で入った粒/能力/相性/体力/収支をチップ列で立ち上げる
            // （状態差分駆動・入力遮断なし・RNG非消費）。lastDeltaWeek ゲートで、大会画面を挟んで
            // 戻った時に古い増減が再生される事故を防ぐ。終端で burstHold を必ず下ろす（世代一致時のみ＝
            // 週送り直後に旧タスクの後始末が新しい保留を下ろす競合を防ぐ）。
            let gen = burstGen
            defer { if gen == burstGen { burstHold = false } }
            guard session.lastDeltaWeek == session.week else {
                withAnimation(Theme.Motion.exit) { beatAdvice = nil }
                return
            }
            let chips = makeBurstChips()
            guard !chips.isEmpty else {
                withAnimation(Theme.Motion.exit) { beatAdvice = nil }
                return
            }
            burstChips = chips
            burstVisible = true   // 出現は per-chip の emphSpring+stagger（burstOverlay 側）
            particleFire += 1     // 同時に立ち絵の頭上で火花が爆ぜる（獲得の「効いた」）
            // 獲得の音: 粒（キラキラ）＞汎用ポップ。収支が動いた週はお金の音も重ねる。
            Sound.play(session.lastGrainGains.isEmpty ? .pop : .grain)
            if session.lastMoneyDelta > 0 { Sound.play(.money) }
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(Theme.Motion.exit) { beatAdvice = nil }
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
        .onChange(of: partnerRank) { old, new in
            // 谷口評のランクが上がった瞬間だけ punch（下がりは黙る）。AllocationView のグレード昇格と同じ文法。
            let order = ["D", "C", "B", "A", "S"]
            guard let o = order.firstIndex(of: old), let n = order.firstIndex(of: new), n > o else { return }
            Haptics.confirm()
            Sound.play(.rankup)   // 谷口評ランクアップ（パワプロの評価アップの音）
            Task {
                withAnimation(Theme.Motion.emphSpring) { rankPunch = true }
                try? await Task.sleep(nanoseconds: 650_000_000)
                withAnimation(Theme.Motion.appear) { rankPunch = false }
            }
        }
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

    // MARK: 立ち絵シーン（左上ピル・心の声）

    private var sceneZone: some View {
        sceneBackground
            .background(Color(hex: 0xFFFBF0).ignoresSafeArea(edges: .top))   // ステータスバー裏も稽古場の白
            .overlay(alignment: .topLeading) { pillsColumn.padding(12) }
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
                              colors: burstChips.map { $0.dot ?? ($0.bg == Theme.card2 ? Theme.gainOrange : $0.bg) },
                              style: .spark, count: 26,
                              origin: UnitPoint(x: 0.62, y: 0.60))
            }
            .overlay(alignment: .bottomTrailing) {
                // Beat2 獲得バースト: 立ち絵の頭上に獲得チップが立ち上る（触れない・入力遮断なし）。
                // 人形の大型化に合わせ頭上へ逃がす（頭に被ると谷口が首なしに見える）。
                burstOverlay
                    .padding(.trailing, 16).padding(.bottom, 262)
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
                    if m.weeksLeft >= 6 {
                        Text(lullLine())
                            .font(.maru(9)).foregroundStyle(.white.opacity(0.65))
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

    // MARK: 6軸ダークピル（センス/発想/表現/華/メンタル/相性・data-theme無関係の暗色固定）

    private var pillsColumn: some View {
        let rows: [(String, Ability?, Double, Color)] = [
            ("センス", .センス, s.センス, Theme.cSense),
            ("発想", .発想, s.発想, Theme.cIdea),
            ("表現", .表現, s.表現, Theme.cExpr),
            ("華", .華, s.華, Theme.cChara),
            ("メンタル", .メンタル, s.メンタル, Theme.cMental),
            ("相性", nil, s.compat, Theme.cCompat),
        ]
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(rows, id: \.0) { r in
                statPill(name: r.0, ability: r.1, value: r.2, color: r.3)
            }
            rankChip
        }
    }

    /// 能力ピルのアイコン（色弱対応で色だけに頼らない・オーナー指摘2026-08-03）
    private func pillGlyph(_ a: Ability?) -> String {
        guard let a else { return "heart.fill" }   // 相性
        switch a {
        case .センス: return "sparkles"
        case .発想: return "lightbulb.fill"
        case .表現: return "theatermasks.fill"
        case .華: return "star.fill"
        case .メンタル: return "brain.head.profile"
        }
    }

    /// 谷口評: 5能力平均のランク（Theme.rank）。数字を並べず一字で「いまどの辺か」を言う常設メーター。
    /// ランクアップの瞬間は punch（scale1.18+金・Haptics.confirm）＝パワプロの評価アップの一拍。
    private var partnerRank: String {
        Theme.rank((s.センス + s.発想 + s.表現 + s.華 + s.メンタル) / 5)
    }

    private var rankChip: some View {
        HStack(spacing: 5) {
            Text("谷口評").font(.maru(9.5)).foregroundStyle(Theme.ink.opacity(0.85))
            Text(partnerRank).font(.maru(14))
                .foregroundStyle(rankPunch ? Theme.gold : Theme.gradeColor(partnerRank))
                .scaleEffect(rankPunch ? 1.25 : 1)
        }
        .padding(.horizontal, 9).padding(.vertical, 3)
        .background(.white, in: Capsule())
        .overlay(Capsule().stroke(rankPunch ? Theme.gold : Theme.gradeColor(partnerRank), lineWidth: 2))
        .shadow(color: Theme.cmdShadow, radius: 0, y: 2)
        .padding(.top, 2)
    }

    private func statPill(name: String, ability: Ability?, value: Double, color: Color) -> some View {
        // 能力5種は lastGains、相性は lastCompatGain から「実際に伸びた分」を出す（プレビューではなく確定値）。
        let gain: Double? = {
            if let a = ability { return session.lastGains.first(where: { $0.ability == a })?.amount }
            return session.lastCompatGain > 0.001 ? session.lastCompatGain : nil
        }()
        // パワプロ式: 白地チャンキーピル＋等級バッジ（D→S）。等級が「いまどの辺か」を一字で言う。
        // 相性は 0..compatCap を 0..100 に写像して同じ等級尺で読む。上限到達で縁がgold。
        let isPerf = ability != nil && ability != .メンタル
        let capped = isPerf && value >= session.config.abilityCap
        let gradeBase = ability != nil ? value : value / session.config.compatCap * 100
        let grade = Theme.rank(gradeBase)
        // 監査C-01: 塗りは「0〜上限の比」でなく「いまの等級帯の中での進み」。1年目でも注ぐたびに満ちて見え、
        // 等級を跨ぐと空に戻る（等級の閾値そのものは経済と共有＝不変）。
        let barCap = ability == nil ? 100 : (ability == .メンタル ? session.config.mentalCap : session.config.abilityCap)
        let fill = Theme.rankProgress(gradeBase, cap: barCap)
        return HStack(spacing: 6) {
            // 能力アイコン（色+アイコンで常時判別・オーナー指摘2026-08-03「見えづらい」対応）:
            // 序盤は全員グレードGで等級バッジが同色（灰）になり、かつ比例塗りは低値でほぼ見えず
            // ピルが識別不能になっていた。能力固有色の丸を常設し、色だけに頼らないアイコンも添える。
            ZStack {
                Circle().fill(color).frame(width: 22, height: 22)
                Image(systemName: pillGlyph(ability))
                    .font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
            }
            // 等級バッジ（パワプロの G..S 相当・色は等級固有）
            Text(grade).font(.maru(11)).foregroundStyle(.white)
                .frame(width: 21, height: 21)
                .background(Circle().fill(Theme.gradeColor(grade)))
                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                .punch(on: grade, peak: 1.4)
            VStack(alignment: .leading, spacing: 0) {
                Text(name).font(.maru(10.5)).foregroundStyle(Theme.ink)
                Text("\(Int(value.rounded()))").font(.maru(15)).monospacedDigit().foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.3), value: Int(value.rounded()))
                    .punch(on: Int(value.rounded()), peak: 1.35)   // 値が動いた瞬間だけ跳ねる（ジュース核）
            }
            if let gain, gainsVisible, Int(gain.rounded()) >= 1 {
                Text("+\(Int(gain.rounded()))").font(.maru(12)).foregroundStyle(Theme.gainOrange)
                    // +N規格（§3-3）: 出現0.2s=+8ptから浮き上がる／滞留（taskの1.2sから逆算0.6s）／退場0.4s=上昇フェード
                    .transition(.asymmetric(
                        insertion: .offset(y: 8).combined(with: .opacity),
                        removal: .offset(y: -8).combined(with: .opacity)))
            }
        }
        .padding(.leading, 5).padding(.trailing, 10).padding(.vertical, 4)
        .background {
            ZStack(alignment: .leading) {
                // 常時見える下地の色帯（比例0%でも識別できる・§旧: 比例塗りのみだと低値で消えていた）
                color.opacity(0.14)
                GeometryReader { geo in
                    Rectangle().fill(color.opacity(0.30))
                        .frame(width: geo.size.width * fill)
                        .animation(.easeOut(duration: 0.4), value: fill)
                }
            }
            .clipShape(Capsule())
        }
        .background(.white, in: Capsule())
        .overlay(Capsule().stroke(capped ? Theme.gold : color, lineWidth: 2.5))
        .shadow(color: Theme.cmdShadow, radius: 0, y: 2)   // ハード影＝チャンキー
        .animation(.easeOut(duration: gainsVisible ? 0.2 : 0.4), value: gainsVisible)
    }

    // MARK: 心の声（状態駆動モノローグ）／Beat1 発話バブル（同じ器を共用）

    private var monoBox: some View {
        adviceBox(DialogueData.innerVoice(state: s, lossStreak: session.lossStreak,
                                          justPassed: session.justPassedStage, justLost: session.justLostStage,
                                          nextMilestone: nextMilestone(), weakAbility: weakAbility(),
                                          week: session.week))
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
                Text(name).font(.maru(9.5)).foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(name == "谷口" ? Theme.verm : Color(hex: 0x4A7BE8), in: Capsule())
            }
            Text(a.text)
                .font(.system(size: 13.5, weight: .medium)).lineSpacing(3)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .frame(maxWidth: 250, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 2.5))
                .shadow(color: Theme.cmdShadow, radius: 0, y: 3)   // ハード影＝チャンキー
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
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 2), spacing: 9) {
                ForEach(mainCards) { v in actionCard(v) }
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

    private func actionCard(_ v: CommandVariant, compact: Bool = false) -> some View {
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
            Sound.play(.tap)   // 実行の決定音（週送りの一拍目）
            // 二拍実行: 引き抜き0.12s→Beat1 発話0.7s（画面タップで即スキップ）→週送り→Beat2 バースト。
            // cancel() されても choose は必ず一度だけ走る（sleep が即返るだけ）＝スキップ＝早送り。
            // 監査A-04: 一言はこのカードで直近4週に出していない時だけ（毎週同じ3本が回るのを避ける）
            let showBeat = session.week - (lastBeatWeek[v.id] ?? -100) > 4
            if showBeat {
                lastBeatWeek[v.id] = session.week
                withAnimation(.easeOut(duration: 0.18)) {
                    beatAdvice = DialogueData.reaction(variantID: v.id, salt: session.week)
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
                withAnimation(Theme.Motion.appear) { pulledID = nil }   // 常設カードは同じ場所に戻る＝次の週の手札
            }
        } label: {
            actionCardLabel(v, gated: gated, preoccupied: preoccupied, compact: compact)
                .scaleEffect(pulledID == v.id ? 1.06 : 1)   // 実行時に軽くポップ（引き抜きの手応え・0.12s budget内）
                .opacity(pulledID == v.id ? 0 : 1)
        }
        .buttonStyle(PressableStyle(enabled: !blocked))
        .modifier(ShakeEffect(animatableData: shakeSeed[v.id] ?? 0))
    }

    /// カードの顔: アイコン＋名前／伸び（実力 ↑・相性 +N・ネタ +N）／コスト（所持金・体力）。
    /// compact（条件付きの小カード）は伸びとコストを1行にまとめ、破線の縁で「今だけのカード」と分ける。
    private func actionCardLabel(_ v: CommandVariant, gated: Bool, preoccupied: Bool, compact: Bool) -> some View {
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
                Text(v.name).font(.maru(compact ? 13 : 15)).foregroundStyle(gated ? Theme.inkDim : Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                if case .acceptOffer = v.action {
                    Text(v.desc).font(.maru(10)).foregroundStyle(Theme.goldD).lineLimit(1)   // オファー名（既存の OfferSpec.name）
                }
            }
            if gated {
                Text(preoccupied ? "撮影で埋まる" : "谷口：今日は休め").font(.maru(10.5)).foregroundStyle(Theme.verm)
            } else if !v.affordable {
                Text("¥不足").font(.maru(10.5)).foregroundStyle(Theme.verm)
            } else if !compact, !effects.isEmpty {
                HStack(spacing: 4) { ForEach(effects, id: \.text) { effectPill($0) } }
            }
            if !compact { Spacer(minLength: 0) }
            HStack(spacing: 4) {
                if compact { ForEach(effects, id: \.text) { effectPill($0) } }
                if moneyDelta != 0 { costPill(money: moneyDelta, insufficient: !v.affordable) }
                if stamDelta != 0 { staminaPill(stamDelta, insufficient: gated) }
            }
        }
        .padding(.horizontal, 11).padding(.vertical, compact ? 8 : 10)
        .frame(maxWidth: .infinity, minHeight: compact ? nil : 92, maxHeight: compact ? .infinity : nil, alignment: .topLeading)
        .background(gated ? Color(hex: 0xF3EFE7) : Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Rad.card)
            .stroke(gated ? Theme.line : tint.opacity(compact ? 0.8 : 0.55),
                    style: StrokeStyle(lineWidth: 3, dash: compact ? [6, 4] : [])))
        .shadow(color: Theme.cmdShadow, radius: 0, y: 3)   // ハード影＝チャンキー
        .opacity(gated ? 0.6 : 1)
    }

    /// カードごとの地色（アイコン地・縁）。色だけに頼らずアイコン＋名前でも区別する（§6-5）。
    private func cardTint(_ v: CommandVariant) -> Color {
        switch v.action {
        case .train(.ネタ作り): return Theme.cIdea
        case .train(.ネタ合わせ): return Theme.cCompat
        case .train: return Theme.cExpr
        case .rest: return Theme.night
        case .job: return Theme.cMoney
        case .acceptOffer: return Theme.gold
        }
    }

    private func effectPill(_ e: CardEffect) -> some View {
        Text(e.text).font(.system(size: 11, weight: .heavy)).foregroundStyle(e.color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(e.color.opacity(0.10), in: Capsule())
            .overlay(Capsule().stroke(e.color.opacity(0.7), lineWidth: 1.5))
    }

    // MARK: Beat2 獲得バースト（この週の行動で入ったものが立ち絵の頭上に立ち上る）

    /// 出現は下から stagger（0.07s刻み・emphSpring）、退場は逆再生。チップの文法はカードの
    /// 粒チップ（dot+card2）と効果ピル（色地+白字）をそのまま流用＝予告と着地が同じ顔。
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
        HStack(spacing: 5) {
            if let dot = chip.dot {
                Circle().fill(dot).frame(width: 9, height: 9)
            }
            Text(chip.text).font(.system(size: 16, weight: .black)).foregroundStyle(chip.fg)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(chip.bg, in: Capsule())
        .overlay(Capsule().stroke(.white, lineWidth: 2))
        .shadow(color: Theme.ink.opacity(0.25), radius: 0, y: 3)
    }

    /// この週の獲得チップ列を組む（表示専用・RNG非消費）。順序: 粒（稽古の主収穫）→能力/相性（直接効果）→
    /// 体力→収支。差分0は出さない（+0を印字しない・§1-1）。
    private func makeBurstChips() -> [BurstChip] {
        var chips: [BurstChip] = []
        var id = 0
        for g in session.lastGrainGains {
            // バーストは横幅に余裕がある＝通貨のフル名で出す（単漢字は初見で読めない・監査C-04）
            let d = Int(g.amount.rounded())
            guard d > 0 else { continue }
            chips.append(BurstChip(id: id, dot: Theme.currencyColor(g.currency), text: "\(g.currency) +\(d)",
                                   fg: Theme.ink, bg: Theme.card2)); id += 1
        }
        for g in session.lastGains {
            let d = Int(g.amount.rounded())
            guard d > 0 else { continue }
            chips.append(BurstChip(id: id, dot: nil, text: "\(g.ability) +\(d)",
                                   fg: .white, bg: Theme.abilityColor(g.ability))); id += 1
        }
        let cd = Int(session.lastCompatGain.rounded())
        if cd > 0 {
            chips.append(BurstChip(id: id, dot: nil, text: "相性 +\(cd)", fg: .white, bg: Theme.cCompat)); id += 1
        }
        let sd = session.lastStaminaDelta
        if sd != 0 {
            chips.append(BurstChip(id: id, dot: nil, text: "体力 \(sd > 0 ? "+" : "")\(sd)",
                                   fg: sd > 0 ? .white : Theme.inkDim,
                                   bg: sd > 0 ? Theme.cMental : Theme.card2)); id += 1
        }
        let md = session.lastMoneyDelta
        if md != 0 {
            let man = Double(abs(md)) / 10000
            let txt = man == man.rounded() ? String(Int(man)) : String(format: "%.1f", man)
            chips.append(BurstChip(id: id, dot: nil, text: "\(md > 0 ? "+" : "-")¥\(txt)万",
                                   fg: md > 0 ? .white : Theme.verm,
                                   bg: md > 0 ? Theme.cMoney : Theme.verm.opacity(0.14))); id += 1
        }
        return chips
    }

    private func costPill(money: Int, insufficient: Bool = false) -> some View {
        let up = money > 0
        let man = Double(abs(money)) / 10000
        let txt = (man == man.rounded() ? String(Int(man)) : String(format: "%.1f", man))
        return Text("\(up ? "+" : "-")¥\(txt)万")
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(insufficient ? .white : (up ? Theme.cMoney : Theme.verm))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(insufficient ? Theme.staminaCrit : (up ? Theme.cMoney : Theme.verm).opacity(0.14), in: Capsule())
    }

    private func staminaPill(_ delta: Int, insufficient: Bool = false) -> some View {
        let up = delta > 0
        return Text("体力 \(up ? "+" : "")\(delta)")
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(insufficient ? .white : (up ? Theme.cMental : Theme.inkDim))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(insufficient ? Theme.staminaCrit : (up ? Theme.cMental : Theme.inkDim).opacity(0.14), in: Capsule())
    }

    // MARK: 最下部の帯（年週・大会までN週・体力ゲージ・所持金）

    private var botbar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(session.year)年目").font(.maru(9)).foregroundStyle(.white.opacity(0.65))
                Text("\(session.week)週").font(.maru(17)).foregroundStyle(.white)
            }
            if let m = nextMilestone() {
                Rectangle().fill(.white.opacity(0.18)).frame(width: 1, height: 26)
                VStack(alignment: .leading, spacing: 0) {
                    Text(m.name).font(.maru(9)).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                    Text(m.weeksLeft <= 0 ? "今週！" : "大会まで\(m.weeksLeft)週").font(.maru(12))
                        .foregroundStyle(m.weeksLeft <= 3 ? Theme.verm : Theme.gold)   // 残3週から追い込みの朱
                        .contentTransition(.numericText())   // 週送りで数字が繰り下がる
                }
            }
            Button { showCalendar = true } label: {   // S4 カレンダーを開く
                Image(systemName: "calendar").font(.system(size: 15)).foregroundStyle(.white.opacity(0.8))
            }.buttonStyle(PressableStyle())
            .accessibilityLabel("カレンダー")
            Button { showNotebook = true } label: {   // S5 ネタ帳（旧「ネタ帳」タイルの移設・A「削る」）
                Image(systemName: "book.closed.fill").font(.system(size: 14)).foregroundStyle(.white.opacity(0.8))
            }.buttonStyle(PressableStyle())
            .accessibilityLabel("ネタ帳")
            Button { showSettings = true } label: {   // 進行中の設定（音量・プライバシーポリシー・この年をやめる＝監査G-04）
                Image(systemName: "gearshape.fill").font(.system(size: 14)).foregroundStyle(.white.opacity(0.7))
            }.buttonStyle(PressableStyle())
            .accessibilityLabel("設定")
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 5) {
                staminaGauge
                Text("¥\(s.money.formatted())").font(.maru(12)).monospacedDigit()
                    .foregroundStyle(s.money < 0 ? Theme.verm : .white)
                    .contentTransition(.numericText())            // 収支が動くと数字が繰る
                    .punch(on: s.money, peak: 1.18)               // ＋跳ねる（ジュース核）
                    .animation(.easeOut(duration: 0.4), value: s.money)
            }
        }
        .padding(.horizontal, 14).padding(.top, 9).padding(.bottom, 16)
        .background(Theme.botbarDark.ignoresSafeArea(edges: .bottom))
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
                    .frame(width: 64 * CGFloat(max(0, min(100, s.stamina)) / 100))
                    .shadow(color: staminaColor.opacity(0.6), radius: 3)
                    .animation(.easeOut(duration: 0.4), value: s.stamina)
                    .animation(.easeInOut(duration: 0.15), value: staminaZone)  // 閾値跨ぎの色クロスフェード（§3-4）
            }
            .frame(width: 64, height: 10)   // 歯車を足した分詰める（ラベルが押し出されないように）
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
        showToast("この年の器は、満ちた。")
    }

    // MARK: 導出（カードの伸び・弱点能力・次のマイルストン）

    /// カードの伸び（最大2つ）: 実力 ↑（自動注ぎの後に実力値が伸びる時）／相性 +N／ネタ +N or 新ネタ。
    /// 実力は1週で整数が動かない週が多い＝数字でなく「↑」で出す（％は出さない）。名目値＝RNG非消費。
    /// 器が満ちた後は実力 ↑ が自然に消える（旧「満」判の代わり）。
    private func cardEffects(_ v: CommandVariant, after: GameState) -> [CardEffect] {
        let cfg = session.config
        var out: [CardEffect] = []
        if GameEngine.jitsuryoku(after, config: cfg) - GameEngine.jitsuryoku(s, config: cfg) > 0.001 {
            out.append(CardEffect(text: "実力 ↑", color: Theme.cSense))
        }
        let cd = Int(after.compat.rounded()) - Int(s.compat.rounded())
        if cd > 0 { out.append(CardEffect(text: "相性 +\(cd)", color: Theme.cCompat)) }
        if let neta = netaEffect(v.action) { out.append(CardEffect(text: neta, color: Theme.cIdea)) }
        return out
    }

    /// ネタへの効き（旧 trainExtras と同じ名目値・監査E-06）。ネタを書く＝選択中ネタの改稿 or 新ネタ／舞台に立つ＝客前で磨く。
    private func netaEffect(_ action: WeekAction) -> String? {
        guard case .train(let t) = action else { return nil }
        let cfg = session.config
        switch t {
        case .ネタ作り:
            let hasTarget = s.selectedNetaID.map { id in s.netas.contains { $0.id == id } } ?? false
            return hasTarget || s.netas.count >= cfg.netaActiveSlots ? "ネタ +\(Int(cfg.netaReviseGain))" : "新ネタ"
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
        guard let n = cur else { return "仕込みどき ・ まずはネタ作りから" }
        return "仕込みどき ・ ネタ「\(n.name)」完成度 \(Int(n.polish))"
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
                showToast("もう一度押すと、年末まで休んで1年を閉じる。")
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

/// Beat2 獲得バーストの1チップ。dot!=nil は「貯まる粒」（card2地・塗りドット）、nil は即効の効果ピル（色地・白字）。
private struct BurstChip: Identifiable {
    let id: Int
    let dot: Color?
    let text: String
    let fg: Color
    let bg: Color
}
