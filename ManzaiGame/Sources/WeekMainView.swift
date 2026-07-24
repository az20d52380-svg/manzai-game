// WeekMainView.swift
// SCREEN 01 育成メイン（v8）。上＝立ち絵シーン（左上に6軸ダークピル・実行時オレンジ「+N」／未選択時のみ心の声）／
// 下＝コマンドゾーン（カテゴリのアイコン列 ⇄ 変種カードの横スクロール列を「同じ場所」で切替。戻るは右上のみ）／
// 最下部＝帯（1年目N週・大会までN週・体力ゲージ・所持金）。
// 決定ボタン（つぎへ）は無い：変種カードのタップ＝二拍（Beat1 発話0.7s→choose＝1週進む→Beat2 獲得バースト）。
// ビート中の画面タップは即スキップ（＝早送り）＝3秒動線のテンポは保つ（phase遷移・RootViewは無改修）。
// 伸びの数値は GameSession.previewState/previewGains（RNG非消費・golden不変）から「現在値の整数→実行後の整数の差」で表示。
// 怪我率・稽古Lvは出さない。体力<staminaGate の稽古はグレー＋「谷口：今日は休め」。
//
// ⚠️ // MARK: 要Mac実機ビルド — UIは swift test で検証できない。レイアウト/ゲージ色/ピル+N/カード横スクロール/
//    戻る導線/トーストは simulator でビルド→起動→目視まで確認して初めて「完了」（規律D-10）。

import SwiftUI
import GameCore

struct WeekMainView: View {
    @Bindable var session: GameSession
    let offer: OfferSpec?

    /// 開いているカテゴリ（nil=カテゴリのアイコン列を表示）。カードのタップで即実行→nil に戻す。
    @State private var openCategory: String?
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
    /// 割り振り（「のばす」タイル）を全画面表示。RNG非消費・週は進まない（正典: exp_abilityup_impl_reply）。
    @State private var showAllocate = false
    /// 「のばす」タイルの一拍（バッジ繰り上がりに合わせて scale 1.0→1.05→1.0）。
    @State private var badgeBeat = false
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
    /// 谷口評（5能力平均のランク）がランクアップした瞬間の punch（AllocationView のグレード昇格と同じ文法）。
    @State private var rankPunch = false

    private var s: GameState { session.state }
    private var groups: [CommandGroup] {
        CommandCatalog.groups(config: session.config, offer: offer, money: s.money)
    }
    private var openGroup: CommandGroup? {
        guard let openCategory else { return nil }
        return groups.first(where: { $0.id == openCategory })
    }

    var body: some View {
        VStack(spacing: 0) {
            sceneZone
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            commandZone
            botbar
        }
        .background(Theme.bgGradient.ignoresSafeArea())
        .fullScreenCover(isPresented: $showNotebook) {
            NotebookView(session: session) { showNotebook = false }   // S5 ネタ帳
        }
        .fullScreenCover(isPresented: $showCalendar) {
            CalendarView(session: session) { showCalendar = false }   // S4 年間カレンダー
        }
        .fullScreenCover(isPresented: $showAllocate) {
            AllocationView(session: session) { showAllocate = false }   // 割り振り（経験点→能力）
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
        .task {
            #if DEBUG
            // UIスモーク（MZ_SMOKE と同じ慣習）: MZ_UI=cards で稽古カテゴリを開いた状態で起動＝カード列の目視用
            if ProcessInfo.processInfo.environment["MZ_UI"] == "cards" { openCategory = "keiko" }
            #endif
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
            if !session.lastGrainGains.isEmpty {
                try? await Task.sleep(nanoseconds: 100_000_000)
                withAnimation(Theme.Motion.emphSpring) { badgeBeat = true }   // 粒→「のばす」バッジ繰り上がりの一拍
                try? await Task.sleep(nanoseconds: 150_000_000)
                withAnimation(Theme.Motion.appear) { badgeBeat = false }
            }
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(Theme.Motion.exit) { beatAdvice = nil }
            burstVisible = false   // 退場も per-chip アニメ（下へ沈みつつフェード）
            try? await Task.sleep(nanoseconds: 250_000_000)   // 退場を見せ切ってから cover 解禁（defer）
        }
        .task(id: session.week) {
            // 週送りスタンプ: 週が明けたら「第N週」を一拍（出現spring→0.7s→退場）。入力は遮らない。
            withAnimation(Theme.Motion.emphSpring) { weekStampVisible = true }
            try? await Task.sleep(nanoseconds: 700_000_000)
            withAnimation(Theme.Motion.exit) { weekStampVisible = false }
        }
        .onChange(of: partnerRank) { old, new in
            // 谷口評のランクが上がった瞬間だけ punch（下がりは黙る）。AllocationView のグレード昇格と同じ文法。
            let order = ["D", "C", "B", "A", "S"]
            guard let o = order.firstIndex(of: old), let n = order.firstIndex(of: new), n > o else { return }
            Haptics.confirm()
            Task {
                withAnimation(Theme.Motion.emphSpring) { rankPunch = true }
                try? await Task.sleep(nanoseconds: 650_000_000)
                withAnimation(Theme.Motion.appear) { rankPunch = false }
            }
        }
        .task(id: toast) {
            if toast != nil {
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                toast = nil
            }
        }
        .onChange(of: vesselIsFull) { _, full in
            // §4 満了成立時の週メイン初回だけトースト（この年1回・器カード/Notebook/トーストの三面が同じ一文）。
            maybeShowVesselFullToast(full)
        }
        .onChange(of: showAllocate) { _, showing in
            // 割り振り画面から戻った初回にも満了を拾う（満了は「注ぐ」瞬間＝AllocationView 内で成立するため）。
            if !showing { maybeShowVesselFullToast(vesselIsFull) }
        }
    }

    // MARK: 立ち絵シーン（左上ピル・右上戻る・心の声）

    private var sceneZone: some View {
        sceneBackground
            .overlay(alignment: .topLeading) { pillsColumn.padding(12) }
            .overlay(alignment: .topTrailing) {
                if openCategory != nil { backButton.padding(12) }
            }
            .overlay(alignment: .bottomLeading) {
                // Beat1 の発話バブルはモノローグと同じ席（表示中は独白を隠す＝一度に一つの声）。
                if let b = beatAdvice {
                    adviceBox(b).padding(14)
                } else if openCategory == nil {
                    monoBox.padding(14)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                // Beat2 獲得バースト: 立ち絵の頭上に獲得チップが立ち上る（触れない・入力遮断なし）。
                burstOverlay
                    .padding(.trailing, 18).padding(.bottom, 148)
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
                        Text("仕込みどき ・ 弱点は\(weakAbility())")
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
        RadialGradient(colors: [Color(hex: 0xFFE3B0), Color(hex: 0xFFC98A)],
                       center: .bottom, startRadius: 20, endRadius: 340)
            .overlay(alignment: .bottomTrailing) {
                // TODO: 本イラスト差替（現状はシルエット仮＝立ち絵プレースホルダ）
                HStack(alignment: .bottom, spacing: 4) {
                    silhouette(color: Color(hex: 0x3B6FE0), w: 74, h: 116)
                    silhouette(color: Theme.verm, w: 84, h: 130)
                }
                .padding(.trailing, 20).padding(.bottom, 4)
            }
    }

    private func silhouette(color: Color, w: CGFloat, h: CGFloat) -> some View {
        UnevenRoundedRectangle(topLeadingRadius: 30, bottomLeadingRadius: 14, bottomTrailingRadius: 14, topTrailingRadius: 30)
            .fill(LinearGradient(colors: [color.opacity(0.85), color], startPoint: .top, endPoint: .bottom))
            .frame(width: w, height: h)
            .overlay(alignment: .top) { Circle().fill(Color(hex: 0xFFE0C4)).frame(width: w * 0.55, height: w * 0.55).offset(y: 12) }
            .shadow(color: Theme.ink.opacity(0.22), radius: 5, y: 5)   // 影はink系（純黒禁止・§1-0）
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

    /// 谷口評: 5能力平均のランク（Theme.rank）。数字を並べず一字で「いまどの辺か」を言う常設メーター。
    /// ランクアップの瞬間は punch（scale1.18+金・Haptics.confirm）＝パワプロの評価アップの一拍。
    private var partnerRank: String {
        Theme.rank((s.センス + s.発想 + s.表現 + s.華 + s.メンタル) / 5)
    }

    private var rankChip: some View {
        HStack(spacing: 5) {
            Text("谷口評").font(.maru(9.5)).foregroundStyle(.white.opacity(0.92))
            Text(partnerRank).font(.maru(13))
                .foregroundStyle(rankPunch ? Theme.gold : .white)
                .scaleEffect(rankPunch ? 1.18 : 1)
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Theme.pillDark, in: Capsule())
        .overlay(Capsule().stroke(rankPunch ? Theme.gold : Color.white.opacity(0.35), lineWidth: rankPunch ? 1.5 : 1))
        .padding(.top, 2)
    }

    private func statPill(name: String, ability: Ability?, value: Double, color: Color) -> some View {
        // 能力5種は lastGains、相性は lastCompatGain から「実際に伸びた分」を出す（プレビューではなく確定値）。
        let gain: Double? = {
            if let a = ability { return session.lastGains.first(where: { $0.ability == a })?.amount }
            return session.lastCompatGain > 0.001 ? session.lastCompatGain : nil
        }()
        // 演技系4種のみ「器の充填」＝成長予算(abilityCap)に対する薄い満ち（§3-3・数値は出さない）。
        // メンタル・相性は器なし＝上限の系統が違うことを形で言う。上限到達で縁がgoldに変わる。
        let isPerf = ability != nil && ability != .メンタル
        let fill = isPerf ? min(1, max(0, value / session.config.abilityCap)) : 0
        let capped = isPerf && value >= session.config.abilityCap
        return HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(name).font(.maru(9.5)).foregroundStyle(.white.opacity(0.92))
            Text("\(Int(value.rounded()))").font(.maru(11)).monospacedDigit().foregroundStyle(.white)
            if let gain, gainsVisible, Int(gain.rounded()) >= 1 {
                Text("+\(Int(gain.rounded()))").font(.maru(10)).foregroundStyle(Theme.gainOrange)
                    // +N規格（§3-3）: 出現0.2s=+8ptから浮き上がる／滞留（taskの1.2sから逆算0.6s）／退場0.4s=上昇フェード
                    .transition(.asymmetric(
                        insertion: .offset(y: 8).combined(with: .opacity),
                        removal: .offset(y: -8).combined(with: .opacity)))
            }
        }
        .padding(.leading, 6).padding(.trailing, 8).padding(.vertical, 3)
        .background {
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.pillDark)
                if isPerf {
                    GeometryReader { geo in
                        Rectangle().fill(color.opacity(0.32))
                            .frame(width: geo.size.width * fill)
                            .animation(.easeOut(duration: 0.4), value: fill)
                    }
                }
            }
            .clipShape(Capsule())
        }
        .overlay(Capsule().stroke(capped ? Theme.gold : color.opacity(0.55), lineWidth: capped ? 1.5 : 1))
        .animation(.easeOut(duration: gainsVisible ? 0.2 : 0.4), value: gainsVisible)
    }

    private var backButton: some View {
        Button {
            openCategory = nil
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left").font(.system(size: 11, weight: .heavy))
                Text("戻る").font(.maru(12))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Theme.pillDark, in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: 心の声（カテゴリ未選択時のみ・状態駆動モノローグ）／Beat1 発話バブル（同じ器を共用）

    private var monoBox: some View {
        adviceBox(DialogueData.innerVoice(state: s, lossStreak: session.lossStreak,
                                          justPassed: session.justPassedStage, justLost: session.justLostStage,
                                          nextMilestone: nextMilestone(), weakAbility: weakAbility()))
    }

    private func adviceBox(_ a: Advice) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(a.name ?? "俺").font(.maru(9.5)).tracking(1).foregroundStyle(Theme.inkDim)
            Text(a.text).font(.system(size: 13)).italic().foregroundStyle(Color(hex: 0x4A4360))
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .frame(maxWidth: 250, alignment: .leading)
        .background(Color.white.opacity(0.92), in: UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 4, bottomTrailingRadius: 12, topTrailingRadius: 12))
        .overlay(alignment: .leading) { Rectangle().fill(Theme.inkDim).frame(width: 3) }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 4, bottomTrailingRadius: 12, topTrailingRadius: 12))
        .shadow(color: Theme.ink.opacity(0.12), radius: 5, y: 4)   // 影はink系（純黒禁止・§1-0）
        .id(a.text)
        .transition(.opacity)
    }

    // MARK: コマンドゾーン（カテゴリアイコン列 ⇄ 変種カード列）

    private var commandZone: some View {
        VStack(spacing: 0) {
            if let g = openGroup {
                variantRow(g)   // .info（のばす/データ）は categoryTile 側で全画面を出すためここへ来ない
            } else {
                categoryRow
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10).padding(.top, 10).padding(.bottom, 8)
        .background(LinearGradient(colors: [.clear, Color(hex: 0xFFEFDD)], startPoint: .top, endPoint: .center))
        .animation(Theme.Motion.appearQuick, value: openCategory)   // カテゴリ⇄変種は同位置0.18s（(B)版）
    }

    private var categoryRow: some View {
        HStack(spacing: 7) {
            ForEach(groups) { g in categoryTile(g) }
        }
        .frame(height: 118)
    }

    private func categoryTile(_ g: CommandGroup) -> some View {
        let isOffer = g.id == "offer"
        return Button {
            if g.id == "data" { showNotebook = true; return }   // データ→S5ネタ帳（全画面）
            if g.id == "allocate" { showAllocate = true; return }   // のばす→割り振り（全画面）
            openCategory = g.id
        } label: {
            VStack(spacing: 5) {
                Image(systemName: g.glyph).font(.system(size: 19)).foregroundStyle(isOffer ? Theme.goldD : Theme.ink)
                Text(g.title).font(.maru(10.5)).foregroundStyle(isOffer ? Theme.goldD : Theme.ink).lineLimit(1).minimumScaleFactor(0.8)
                HStack(spacing: 3) {
                    ForEach(Array(g.dotColors.enumerated()), id: \.offset) { _, c in
                        Circle().fill(c).frame(width: 5, height: 5)
                    }
                }
            }
            .frame(maxWidth: .infinity).frame(height: 84)
            .background(isOffer ? Color(hex: 0xFFF3D6) : Theme.card, in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(isOffer ? Theme.gold : Theme.line, lineWidth: 2))
            .overlay(alignment: .topTrailing) {
                // 「のばす」タイルだけ: バッジ＝いま注げば伸びる段数（recommendedPlan.count・§2）。
                // 見た目は現行の gainOrange カプセルのまま、意味だけ「粒総数」→「注げば伸びる段数」へ。
                // 器満了・上限・逓減死では 0 になり自動消灯＝「開いたのに何もできない」空振りがゼロ。
                if g.id == "allocate", pourableSteps >= 1 {
                    Text("\(pourableSteps)")
                        .font(.maru(10)).monospacedDigit().foregroundStyle(.white)
                        .contentTransition(.numericText())   // §1-3 数字が繰り上がる
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.gainOrange, in: Capsule())
                        .scaleEffect(badgeBeat ? 1.05 : 1)   // §1-3 受け取りに合わせた一拍
                        .offset(x: 5, y: -5)
                }
            }
        }
        .buttonStyle(PressableStyle())
    }

    /// パワプロ（参考画像）同様「スクロールせず全変種が見える・タップできる」ため、横スクロール1行をやめ
    /// 3列グリッドへ折り返す。TV版パワプロほど横幅が無い縦画面のため、1行に詰め込んで小さくするより
    /// 2段に畳んで可読性・タップしやすさを保つ（最大5変種=稽古で2段・3変種以下は1段）。
    private func variantRow(_ g: CommandGroup) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3), spacing: 9) {
            ForEach(g.variants) { v in variantCard(v) }
        }
        .padding(.horizontal, 2).padding(.vertical, 2)
    }

    // MARK: 変種カード（タップ＝即実行。ゲート/¥不足は toast で無効化）

    private func variantCard(_ v: CommandVariant) -> some View {
        let preoccupied = v.isTrain && s.preoccupiedWeeks > 0                       // 0022 撮影で稽古枠が埋まった週
        let gated = v.isTrain && (s.stamina < session.config.staminaGate || s.preoccupiedWeeks > 0)
        let blocked = gated || !v.affordable
        return Button {
            guard pulledID == nil else { return }   // 引き抜き中の多重タップは無視
            if blocked {
                // 沈まず横ブレ＝「押せない」の触感文法（§3-1）。振動は付けない（閲覧扱い）。
                withAnimation(.linear(duration: 0.15)) { shakeSeed[v.id, default: 0] += 1 }
                showToast(preoccupied ? "今週は撮影。稽古の時間がない。" : gated ? "体力が足りない。今日は休もう。" : "お金が足りない。")
                return
            }
            // 二拍実行: 引き抜き0.12s→Beat1 発話0.7s（画面タップで即スキップ）→週送り→Beat2 バースト。
            // cancel() されても choose は必ず一度だけ走る（sleep が即返るだけ）＝スキップ＝早送り。
            withAnimation(.easeOut(duration: 0.18)) {
                beatAdvice = DialogueData.reaction(variantID: v.id, salt: session.week)
            }
            withAnimation(.easeIn(duration: 0.12)) { pulledID = v.id }
            beatTask = Task {
                try? await Task.sleep(nanoseconds: 120_000_000)
                openCategory = nil          // カードを畳んで次週はカテゴリ列から
                try? await Task.sleep(nanoseconds: 700_000_000)   // 発話の一拍
                burstGen += 1               // choose が選択肢イベントを立てても Beat2 退場まで cover を待たせる
                burstHold = true
                Haptics.tick()              // 振動は実行（=週送り）のみ（Haptics 3段）
                session.choose(v.action)    // ＝即実行・1週進む（つぎへ廃止）
                pulledID = nil
            }
        } label: {
            cardLabel(v, gated: gated, preoccupied: preoccupied)
                .scaleEffect(pulledID == v.id ? 1.06 : 1)   // ⑤: 実行時に軽くポップ（引き抜きの手応え・0.12s budget内）
                .opacity(pulledID == v.id ? 0 : 1)
        }
        .buttonStyle(PressableStyle(enabled: !blocked))
        .modifier(ShakeEffect(animatableData: shakeSeed[v.id] ?? 0))
    }

    private func cardLabel(_ v: CommandVariant, gated: Bool, preoccupied: Bool = false) -> some View {
        let after = session.previewState(v.action, offer: offer)
        // 会計移設: 稽古は能力でなく粒を稼ぐ＝稽古カードの伸び行は「+N粒」（同色塗りドット）。
        // 稽古以外（バイト/休む/オファー）は従来どおり能力/相性の直接効果ピル。
        let grains = (v.isTrain && v.affordable && !gated) ? intGrainGains(v.action) : []
        let gains = (!v.isTrain && v.affordable && !gated) ? intGains(v.action) : []
        // §4 満了: 器が満ちている間、稽古カードの伸び行位置は金縁の「満」判（稼ぎは無駄にならないが今年は注げない）。
        let vesselFull = v.isTrain && vesselIsFull
        let moneyDelta = after.money - s.money
        let stamDelta = Int(after.stamina.rounded()) - Int(s.stamina.rounded())
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: v.glyph).font(.system(size: 15)).foregroundStyle(gated ? Theme.inkFaint : Theme.verm)
                Text(v.name).font(.maru(12.5)).foregroundStyle(gated ? Theme.inkDim : Theme.ink).lineLimit(1)
            }
            // 伸び or ゲート or ¥不足 or 満 or 粒わずか/伸びわずか
            if gated {
                Text(preoccupied ? "撮影で埋まる" : "谷口：今日は休め").font(.maru(10.5)).foregroundStyle(Theme.verm)
            } else if !v.affordable {
                Text("¥不足").font(.maru(10.5)).foregroundStyle(Theme.verm)
            } else if vesselFull {
                fullStamp
            } else if !grains.isEmpty {
                grainPills(grains)
            } else if !gains.isEmpty {
                gainPills(gains)
            } else if v.isTrain {
                // 全粒差分0の稀な稽古（副収穫の端数のみ等）は「粒わずか」（伸びわずかの型流用・§1-2）。
                Text("わずか").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.inkFaint)
            }
            Spacer(minLength: 0)
            // コスト行（所持金/体力の増減）。不足している項目だけ staminaCrit で塗る（§3-2: 何が足りないか一目で）
            HStack(spacing: 5) {
                if moneyDelta != 0 { costPill(money: moneyDelta, insufficient: !v.affordable) }
                if stamDelta != 0 { staminaPill(stamDelta, insufficient: gated) }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 104, maxHeight: 104, alignment: .topLeading)
        .background(gated ? Color(hex: 0xF3EFE7) : Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Rad.card).stroke(gated ? Theme.line : Theme.verm.opacity(0.5), lineWidth: 2))
        .e2()
        .opacity(gated ? 0.6 : 1)
    }

    private func gainPills(_ gains: [(name: String, color: Color, delta: Int)]) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(gains.prefix(3).enumerated()), id: \.offset) { _, g in
                Text("\(g.name) +\(g.delta)")
                    .font(.system(size: 9.5, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(g.color, in: Capsule())
            }
        }
    }

    /// 稽古の「+N粒」チップ（塗りドット＝能力色＝行き先が決まっている粒／AllocationView・NotebookView と同じ粒の文法）。
    /// ρ=0なので同色ロック粒のみ（共通粒は発行されない＝チップは全て塗りドット）。地=card2カプセル（貯まる粒＝即効の塗りピルと形で分ける・§1-2）。
    private func grainPills(_ grains: [(name: String, color: Color, delta: Int)]) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(grains.prefix(3).enumerated()), id: \.offset) { _, g in
                HStack(spacing: 3) {
                    Circle().fill(g.color).frame(width: 6, height: 6)
                    Text("\(g.name) +\(g.delta)").font(.system(size: 9.5, weight: .bold)).foregroundStyle(Theme.ink)
                }
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(Theme.card2, in: Capsule())
            }
        }
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
        HStack(spacing: 4) {
            if let dot = chip.dot {
                Circle().fill(dot).frame(width: 7, height: 7)
            }
            Text(chip.text).font(.system(size: 12, weight: .heavy)).foregroundStyle(chip.fg)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(chip.bg, in: Capsule())
        .e1()
    }

    /// この週の獲得チップ列を組む（表示専用・RNG非消費）。順序: 粒（稽古の主収穫）→能力/相性（直接効果）→
    /// 体力→収支。差分0は出さない（+0を印字しない・§1-1）。
    private func makeBurstChips() -> [BurstChip] {
        var chips: [BurstChip] = []
        var id = 0
        for g in intGrains(from: session.lastGrainGains) {
            chips.append(BurstChip(id: id, dot: g.color, text: "\(g.name) +\(g.delta)",
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

    /// §4 満了の抑制表示: 器が満ちた後、稽古カードの粒チップ位置に金縁の「満」判（TournamentResultView の押印の語彙）。
    private var fullStamp: some View {
        Text("満")
            .font(.system(size: 10.5, weight: .heavy)).foregroundStyle(Theme.goldD)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color(hex: 0xFFF3D6), in: RoundedRectangle(cornerRadius: Theme.Rad.stamp))
            .overlay(RoundedRectangle(cornerRadius: Theme.Rad.stamp).stroke(Theme.gold, lineWidth: 1.5))
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
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 5) {
                staminaGauge
                Text("¥\(s.money.formatted())").font(.maru(12)).monospacedDigit()
                    .foregroundStyle(s.money < 0 ? Theme.verm : .white)
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
            Text("体力").font(.maru(10)).foregroundStyle(.white.opacity(0.8))
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.16))
                Capsule()
                    .fill(LinearGradient(colors: [staminaColor.opacity(0.82), staminaColor], startPoint: .top, endPoint: .bottom))
                    .frame(width: 78 * CGFloat(max(0, min(100, s.stamina)) / 100))
                    .shadow(color: staminaColor.opacity(0.6), radius: 3)
                    .animation(.easeOut(duration: 0.4), value: s.stamina)
                    .animation(.easeInOut(duration: 0.15), value: staminaZone)  // 閾値跨ぎの色クロスフェード（§3-4）
            }
            .frame(width: 78, height: 10)
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
                .foregroundStyle(staminaColor).frame(width: 26, alignment: .trailing)
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

    // MARK: 導出（プレビュー整数ゲイン・弱点能力・次のマイルストン）

    /// カード用の整数ゲイン。previewGains（RNG非消費・伸びる能力の判定）＋previewState の after から
    /// 「round(after)−round(before)」を能力/相性で出す（>0 のみ）。全0（高ステ逓減）は呼び出し側で「伸びわずか」。
    private func intGains(_ action: WeekAction) -> [(name: String, color: Color, delta: Int)] {
        let after = session.previewState(action, offer: offer)
        var out: [(name: String, color: Color, delta: Int)] = []
        for g in session.previewGains(action, offer: offer) {
            let d = Int(after[g.ability].rounded()) - Int(s[g.ability].rounded())
            if d > 0 { out.append((name: "\(g.ability)", color: Theme.abilityColor(g.ability), delta: d)) }
        }
        let cd = Int(after.compat.rounded()) - Int(s.compat.rounded())
        if cd > 0 { out.append((name: "相性", color: Theme.cCompat, delta: cd)) }
        return out
    }

    /// 稽古カードの「+N粒」用の整数粒ゲイン。previewGrainGains（RNG非消費・同色ロック粒の増分）を
    /// intGains と同じ丸め差分規約（Int(after)−Int(before)＝ここは 0 が before なので Int(amount)）で >0 のみ返す。
    /// 差分0の粒はチップを出さない（+0を印字しない・§1-1）。全粒0の稀な稽古は呼び出し側で「粒わずか」。
    private func intGrainGains(_ action: WeekAction) -> [(name: String, color: Color, delta: Int)] {
        intGrains(from: session.previewGrainGains(action, offer: offer))
    }

    /// 粒差分（[(ability, amount)]）→表示タプル。Int(amount.rounded()) で丸め・>0 のみ（+0を印字しない）。
    /// カード予告（previewGrainGains）と受け取り（lastGrainGains）が同じ丸めを通る＝予告と着地が一致する。
    private func intGrains(from grains: [(ability: Ability, amount: Double)]) -> [(name: String, color: Color, delta: Int)] {
        var out: [(name: String, color: Color, delta: Int)] = []
        for g in grains {
            let d = Int(g.amount.rounded())
            if d > 0 { out.append((name: "\(g.ability)", color: Theme.abilityColor(g.ability), delta: d)) }
        }
        return out
    }

    /// §2 「のばす」バッジ値＝いま注げば伸びる段数（recommendedPlan.count・RNG非消費・表示専用でgolden非干渉）。
    /// AllocationView の＋ボタン押せる判定・§3誘導文と同じ recommendedPlan 由来＝構造的に食い違わない。
    private var pourableSteps: Int {
        session.recommendedAllocation().count
    }

    /// §4 器満了: 成長予算を使い切ったか（AllocationView の器バー満ちと同一判定＝三面で食い違わない）。
    /// 満了成立は「注ぐ」瞬間だけなので growthUsed≥growthBudget で判定（budget未設定=無制限は満了なし）。
    private var vesselIsFull: Bool {
        guard let budget = s.growthBudget, budget > 0 else { return false }
        return s.growthUsed >= budget - GameEngine.pourEpsilon
    }

    private func weakAbility() -> String {
        let pairs: [(String, Double)] = [("センス", s.センス), ("発想", s.発想), ("表現", s.表現), ("華", s.華), ("メンタル", s.メンタル)]
        return pairs.min(by: { $0.1 < $1.1 })?.0 ?? "表現"
    }

    private func nextMilestone() -> (name: String, weeksLeft: Int)? {
        let cal = session.config.calendar
        var ms: [(Int, String)] = []
        for (i, r) in cal.gpRounds.enumerated() { ms.append((r.week, i < cal.gpRoundNames.count ? cal.gpRoundNames[i] : "頂GP\(i + 1)回戦")) }
        ms.append((cal.gpFinalWeek, "頂GP 決勝"))
        // 出場資格で絞る（AllocationView.nextStage と同じ走査）。絞らないと知名度不足でも
        // 「推薦制中堅賞」が次目標に出る＝出られない大会へ逆算させる誤誘導になる。
        for t in cal.tournaments where t.isEligible(year: session.year, state: s) { ms.append((t.week, t.name)) }
        guard let next = ms.filter({ $0.0 >= session.week }).min(by: { $0.0 < $1.0 }) else { return nil }
        return (next.1, next.0 - session.week)
    }
}

/// Beat2 獲得バーストの1チップ。dot!=nil は「貯まる粒」（card2地・塗りドット）、nil は即効の効果ピル（色地・白字）。
private struct BurstChip: Identifiable {
    let id: Int
    let dot: Color?
    let text: String
    let fg: Color
    let bg: Color
}
