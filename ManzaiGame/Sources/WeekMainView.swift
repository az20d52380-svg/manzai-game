// WeekMainView.swift
// SCREEN 01 育成メイン（v8）。上＝立ち絵シーン（左上に6軸ダークピル・実行時オレンジ「+N」／未選択時のみ心の声）／
// 下＝コマンドゾーン（カテゴリのアイコン列 ⇄ 変種カードの横スクロール列を「同じ場所」で切替。戻るは右上のみ）／
// 最下部＝帯（1年目N週・大会までN週・体力ゲージ・所持金）。
// 決定ボタン（つぎへ）は無い：変種カードのタップ＝即 session.choose(action)＝1週進む（phase遷移・RootViewは無改修）。
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
    /// §1-3 受け取りの一拍: 今週稼いだ粒チップ行を「のばす」タイル直上に一瞬出す。表示中の粒（消えても値は残す）。
    @State private var receiptGrains: [(name: String, color: Color, delta: Int)] = []
    /// 受け取りチップ行の表示フラグ（下から浮き上がり→約1.3s後に消える・入力遮断なし・状態差分駆動）。
    @State private var receiptVisible = false
    /// 「のばす」タイルの一拍（バッジ繰り上がりに合わせて scale 1.0→1.05→1.0）。
    @State private var badgeBeat = false
    /// 満了成立後の週メイン初回トースト（この年1回だけ）用フラグ。
    @State private var vesselFullToastShown = false

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
        .overlay(alignment: .bottom) {
            // トーストは最下帯の上+16pt（§3-5）
            toastBar.animation(.easeOut(duration: 0.2), value: toast)
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
            // §1-3 受け取りの一拍: 今週稼いだ粒があれば、のばすタイル直上に粒チップ行を一瞬出す（状態差分駆動・入力遮断なし）。
            // 大会/イベント画面が挟まっても週メインに戻った時に成立する（演出の振り付けに依存しない）。
            let grains = intGrains(from: session.lastGrainGains)
            guard !grains.isEmpty else { return }
            receiptGrains = grains
            withAnimation(Theme.Motion.appear) { receiptVisible = true }   // 下から浮き上がり出現（easeOut 0.25s）
            try? await Task.sleep(nanoseconds: 100_000_000)
            withAnimation(Theme.Motion.emphSpring) { badgeBeat = true }     // +0.10s バッジ繰り上がり＋タイル一拍
            try? await Task.sleep(nanoseconds: 150_000_000)
            withAnimation(Theme.Motion.appear) { badgeBeat = false }
            try? await Task.sleep(nanoseconds: 1_050_000_000)              // 合計+1.30sで退場（〜1.7s・新規ハプティクスなし）
            withAnimation(Theme.Motion.exit) { receiptVisible = false }
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
                if openCategory == nil { monoBox.padding(14) }
            }
            .clipped()
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
        }
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

    // MARK: 心の声（カテゴリ未選択時のみ・状態駆動モノローグ）

    private var monoBox: some View {
        let a = DialogueData.innerVoice(state: s, lossStreak: session.lossStreak,
                                        justPassed: session.justPassedStage,
                                        nextMilestone: nextMilestone(), weakAbility: weakAbility())
        return VStack(alignment: .leading, spacing: 2) {
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

    // MARK: コマンドゾーン（カテゴリアイコン列 ⇄ 変種カード列・準備中パネル）

    private var commandZone: some View {
        VStack(spacing: 0) {
            if let g = openGroup {
                if g.kind == .info {
                    comingSoonPanel(g)
                } else {
                    variantRow(g)
                }
            } else {
                categoryRow
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10).padding(.top, 10).padding(.bottom, 8)
        .background(LinearGradient(colors: [.clear, Color(hex: 0xFFEFDD)], startPoint: .top, endPoint: .center))
        .animation(Theme.Motion.appearQuick, value: openCategory)   // カテゴリ⇄変種は同位置0.18s（(B)版）
        .overlay(alignment: .topTrailing) {
            // §1-3 受け取りの一拍: 今週入った粒チップ行を「のばす」タイル（右寄り・topTrailingにバッジ）直上に一瞬出す。
            // カテゴリ列表示中のみ（タイルが在る時）。次タップで即消え（タイルを開けば openCategory 変化で消える）。
            if receiptVisible, openCategory == nil, !receiptGrains.isEmpty {
                receiptRow
                    .padding(.trailing, 12).offset(y: -6)
                    .transition(.asymmetric(
                        insertion: .offset(y: 8).combined(with: .opacity),   // 下から8pt浮き上がり
                        removal: .offset(y: -8).combined(with: .opacity)))
                    .allowsHitTesting(false)   // 入力遮断ゼロ（触れない・下のタイルに素通し）
            }
        }
    }

    /// 受け取りチップ行（今週稼いだ粒。card2地の浮き紙＝グレインチップと同じ塗りドット文法）。
    private var receiptRow: some View {
        HStack(spacing: 4) {
            ForEach(Array(receiptGrains.prefix(3).enumerated()), id: \.offset) { _, g in
                HStack(spacing: 3) {
                    Circle().fill(g.color).frame(width: 6, height: 6)
                    Text("\(g.name) +\(g.delta)").font(.system(size: 9.5, weight: .bold)).foregroundStyle(Theme.ink)
                }
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(Theme.card2, in: Capsule())
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(Theme.card, in: Capsule())
        .e1()
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

    private func variantRow(_ g: CommandGroup) -> some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(g.variants) { v in variantCard(v) }
                }
                .padding(.horizontal, 2).padding(.vertical, 2)
            }
        }
        .frame(height: 118)
    }

    // MARK: 変種カード（タップ＝即実行。ゲート/¥不足は toast で無効化）

    private func variantCard(_ v: CommandVariant) -> some View {
        let gated = v.isTrain && s.stamina < session.config.staminaGate
        let blocked = gated || !v.affordable
        return Button {
            guard pulledID == nil else { return }   // 引き抜き中の多重タップは無視
            if blocked {
                // 沈まず横ブレ＝「押せない」の触感文法（§3-1）。振動は付けない（閲覧扱い）。
                withAnimation(.linear(duration: 0.15)) { shakeSeed[v.id, default: 0] += 1 }
                showToast(gated ? "体力が足りない。今日は休もう。" : "お金が足りない。")
                return
            }
            // 「引き抜き」(B)版: フェード0.12s→実行（押下0.08+引き抜き0.12で次入力≤0.35s予算内）
            withAnimation(.easeIn(duration: 0.12)) { pulledID = v.id }
            Task {
                try? await Task.sleep(nanoseconds: 120_000_000)
                Haptics.tick()              // 振動は実行（=週送り）のみ（Haptics 3段）
                openCategory = nil          // カードを畳んで次週はカテゴリ列から
                session.choose(v.action)    // ＝即実行・1週進む（つぎへ廃止）
                pulledID = nil
            }
        } label: {
            cardLabel(v, gated: gated)
                .opacity(pulledID == v.id ? 0 : 1)
        }
        .buttonStyle(PressableStyle(enabled: !blocked))
        .modifier(ShakeEffect(animatableData: shakeSeed[v.id] ?? 0))
    }

    private func cardLabel(_ v: CommandVariant, gated: Bool) -> some View {
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
                Text("谷口：今日は休め").font(.maru(10.5)).foregroundStyle(Theme.verm)
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
                Text("粒わずか").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.inkFaint)
            }
            Spacer(minLength: 0)
            // コスト行（所持金/体力の増減）。不足している項目だけ staminaCrit で塗る（§3-2: 何が足りないか一目で）
            HStack(spacing: 5) {
                if moneyDelta != 0 { costPill(money: moneyDelta, insufficient: !v.affordable) }
                if stamDelta != 0 { staminaPill(stamDelta, insufficient: gated) }
            }
        }
        .padding(10)
        .frame(width: 134, height: 104, alignment: .topLeading)
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
            .font(.system(size: 9.5, weight: .bold))
            .foregroundStyle(insufficient ? .white : (up ? Theme.cMoney : Theme.verm))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(insufficient ? Theme.staminaCrit : (up ? Theme.cMoney : Theme.verm).opacity(0.14), in: Capsule())
    }

    private func staminaPill(_ delta: Int, insufficient: Bool = false) -> some View {
        let up = delta > 0
        return Text("体力 \(up ? "+" : "")\(delta)")
            .font(.system(size: 9.5, weight: .bold))
            .foregroundStyle(insufficient ? .white : (up ? Theme.cMental : Theme.inkDim))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(insufficient ? Theme.staminaCrit : (up ? Theme.cMental : Theme.inkDim).opacity(0.14), in: Capsule())
    }

    private func comingSoonPanel(_ g: CommandGroup) -> some View {
        HStack(spacing: 12) {
            Image(systemName: g.glyph).font(.system(size: 22)).foregroundStyle(Theme.inkFaint)
            VStack(alignment: .leading, spacing: 2) {
                Text(g.title).font(.maru(13)).foregroundStyle(Theme.ink)
                Text("準備中。この機能はまだ使えません。").font(.system(size: 11)).foregroundStyle(Theme.inkDim)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 118)
        .frame(maxWidth: .infinity)
        .background(Theme.card2, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 2))
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
                    Text(m.weeksLeft <= 0 ? "今週！" : "大会まで\(m.weeksLeft)週").font(.maru(12)).foregroundStyle(Theme.gold)
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
            Text("体力").font(.maru(9)).foregroundStyle(.white.opacity(0.7))
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.16))
                Capsule().fill(staminaColor)
                    .frame(width: 78 * CGFloat(max(0, min(100, s.stamina)) / 100))
                    .animation(.easeOut(duration: 0.4), value: s.stamina)
                    .animation(.easeInOut(duration: 0.15), value: staminaZone)  // 閾値跨ぎの色クロスフェード（§3-4）
            }
            .frame(width: 78, height: 8)
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
            Text("\(Int(s.stamina.rounded()))").font(.maru(10)).monospacedDigit()
                .foregroundStyle(.white.opacity(0.9)).frame(width: 24, alignment: .trailing)
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
        for t in cal.tournaments { ms.append((t.week, t.name)) }
        guard let next = ms.filter({ $0.0 >= session.week }).min(by: { $0.0 < $1.0 }) else { return nil }
        return (next.1, next.0 - session.week)
    }
}
