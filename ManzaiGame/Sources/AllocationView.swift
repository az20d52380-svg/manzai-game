// AllocationView.swift
// 割り振り画面（経験点残高→能力へ注ぐ）。正典: docs/exp_abilityup_impl_reply_v0.md（二区画中間・割り振り時予算）。
// 判読性の文法: 色付き粒（塗りドット）＝その色の能力にだけ入る／共通粒（輪郭ドット）＝グループ枠のヘッダに置かれ、
// 枠内の2行だけがそれを引ける（「どの粒がどこへ行けるか」を説明でなく枠のかたちで言う）。
// 操作は本作の「タップで即」文法: ＋で1段仮置き（バーに薄いゴースト・チップの数字が減る）→「注ぐ」で確定→
// 段階リビール（TournamentResultView のローカルTask模倣）。確定は session.allocate()＝RNG非消費・golden不変。
// プレビューと確定は同じ GameEngine.pourStep をタップ順に再生する＝表示と結果が構造的に食い違わない。
//
// ⚠️ // MARK: 要Mac実機ビルド — UIは swift test で検証できない。レイアウト/チップ減算/ゴースト/リビール/
//    シェイク/トーストは simulator でビルド→起動→目視まで確認して初めて「完了」（規律D-10）。
//    目視フック: MZ_UI=allocate（RootView・粒を積んだ【仮】開始状態）。数値は全て【仮】。

import SwiftUI
import GameCore

struct AllocationView: View {
    @Bindable var session: GameSession
    var onClose: () -> Void

    /// 仮置き＝タップ順の能力列。プレビューも確定もこの列を同じ順で再生する（リプレイ決定論）
    @State private var taps: [Ability] = []
    /// 実行不可タップの横ブレ（±3pt×2往復0.15s・振動なし＝閲覧扱い）
    @State private var shakeSeed: [String: CGFloat] = [:]
    /// 無効タップの一時トースト（WeekMainView と同じ1.4s自動消滅）
    @State private var toast: String?
    /// 確定リビール中（バーとラベルは before→after の段階表示に切り替わる）
    @State private var committing = false
    /// リビール済みの行（1行ずつ emphSpring で増える）
    @State private var revealedRows: Set<Ability> = []
    @State private var beforeVals: [Ability: Double] = [:]
    @State private var afterVals: [Ability: Double] = [:]

    private var s: GameState { session.state }
    private var config: GameConfig { session.config }

    var body: some View {
        let pv = session.previewAllocation(taps)
        ZStack {
            LinearGradient(colors: [Theme.bgTop, Theme.bg2], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: Theme.Sp.s16) {
                header
                ScrollView {
                    VStack(spacing: Theme.Sp.s16) {
                        vesselCard(pv)
                        explainer
                        nextStageCard(pv)
                        groupCard(.ネタ, pv)
                        groupCard(.舞台, pv)
                        mentalCard(pv)
                    }
                    .padding(.horizontal, Theme.Sp.s16)
                    .padding(.bottom, Theme.Sp.s24)
                }
            }
            .padding(.top, Theme.Sp.s12)
        }
        .safeAreaInset(edge: .bottom) { footer(pv) }
        .overlay(alignment: .bottom) {
            toastBar.animation(.easeOut(duration: 0.2), value: toast)
        }
        .task(id: toast) {
            if toast != nil {
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                toast = nil
            }
        }
    }

    // MARK: ヘッダ（NotebookView と同型）

    private var header: some View {
        HStack {
            Text("のばす").font(.maru(16)).foregroundStyle(Theme.ink)
            Spacer()
            Text("第\(session.week)週").font(.maru(12)).monospacedDigit().foregroundStyle(Theme.inkDim)
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundStyle(Theme.inkFaint)
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, Theme.Sp.s16)
    }

    // MARK: 器（成長予算の残り・数値なし＝growthRoomの文法）＋残粒総数

    private func vesselCard(_ pv: GameState) -> some View {
        let budget = s.growthBudget ?? 0
        let used = budget > 0 ? min(budget, s.growthUsed) : 0
        let staged = budget > 0 ? min(budget, pv.growthUsed) : 0
        let frac = budget > 0 ? staged / budget : 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("成長の器").font(.maru(11)).foregroundStyle(Theme.inkDim)
                Spacer()
                Text("経験点 のこり \(grains(pv.expTotal))").font(.maru(11)).monospacedDigit()
                    .foregroundStyle(Theme.inkDim)
                    .contentTransition(.numericText())
            }
            if budget > 0 {
                // 金の満ち＝使った器。薄い金＝仮置きぶんの先食い（ゴースト）
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.card2)
                        Capsule().fill(Theme.gold.opacity(0.38))
                            .frame(width: geo.size.width * CGFloat(min(1, staged / budget)))
                        Capsule().fill(Theme.gold)
                            .frame(width: geo.size.width * CGFloat(min(1, used / budget)))
                    }
                }
                .frame(height: 10)
            }
            Text(frac < 0.98 ? "まだ、伸びしろがある。" : "この年の器は、満ちた。")
                .font(.system(size: 13, design: .serif)).foregroundStyle(Theme.ink)
        }
        .padding(Theme.Sp.s16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card))
        .e1()
    }

    /// 二区画の一行説明（枠のかたちが本体・これは補助線）
    @ViewBuilder private var explainer: some View {
        // ①整理: ρ(expFreeShare)=0 の間は共通枠が休眠＝プレイヤーが体験しない機構を一等地で説明しない（監査§2）。
        if config.expFreeShare != 0 {
            Text("色の粒は、その色の項へ。共通の粒は、同じ枠のどちらへも。")
                .font(.system(size: 12, design: .serif)).foregroundStyle(Theme.inkDim)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: つぎの本番（要求ラインへの照準・生数値）

    @ViewBuilder private func nextStageCard(_ pv: GameState) -> some View {
        if let stage = nextStage() {
            let now = GameEngine.jitsuryoku(s, config: config) + s.compat
            let after = GameEngine.jitsuryoku(pv, config: config) + pv.compat
            let scale = max(stage.line, after, now) * 1.2
            let gain = Int(after.rounded()) - Int(now.rounded())
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("つぎの本番").font(.maru(11)).foregroundStyle(Theme.inkDim)
                    Text(stage.name).font(.maru(12)).foregroundStyle(Theme.ink).lineLimit(1)
                    Spacer()
                    Text(stage.week <= session.week ? "今週" : "\(stage.week - session.week)週後")
                        .font(.maru(11)).monospacedDigit().foregroundStyle(Theme.goldD)
                }
                // 地力（実力値＋相性）の現在＝濃い ink／仮置き後＝薄い ink。朱の縦線＝要求ライン
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.card2)
                        Capsule().fill(Theme.ink.opacity(0.25))
                            .frame(width: geo.size.width * CGFloat(min(1, after / scale)))
                        Capsule().fill(Theme.ink.opacity(0.55))
                            .frame(width: geo.size.width * CGFloat(min(1, now / scale)))
                        Rectangle().fill(Theme.verm)
                            .frame(width: 2, height: 14)
                            .offset(x: geo.size.width * CGFloat(min(1, stage.line / scale)) - 1)
                    }
                }
                .frame(height: 14)
                // ②: 通過ライン数値（要求/じぶん）は出さない（ui_redesign v4/v8＝ネタバレ回避）。
                // 朱の要求ライン（視覚・上のバー）は残す。仮置きの伸び「+N」だけ手応えとして残す（監査§3-1-3）。
                if gain >= 1 {
                    HStack(spacing: 6) {
                        Text("+\(gain)").font(.maru(11)).monospacedDigit().foregroundStyle(Theme.gainOrange)
                            .transition(.asymmetric(
                                insertion: .offset(y: 8).combined(with: .opacity),
                                removal: .offset(y: -8).combined(with: .opacity)))
                        Spacer()
                    }
                }
            }
            .padding(Theme.Sp.s16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card))
            .e1()
        }
    }

    /// 次に来る本番（大会 or GP回戦 or 決勝）とその要求ライン。WeekMainView.nextMilestone と同じ走査＋出場資格で絞る
    private func nextStage() -> (name: String, week: Int, line: Double)? {
        let cal = config.calendar
        var ms: [(week: Int, name: String, line: Double)] = []
        for (i, r) in cal.gpRounds.enumerated() {
            ms.append((r.week, i < cal.gpRoundNames.count ? cal.gpRoundNames[i] : "GP回戦\(i + 1)", r.line))
        }
        ms.append((cal.gpFinalWeek, "頂GP 決勝", cal.gpFinalLine))
        for t in cal.tournaments where t.isEligible(year: session.year, state: s) {
            ms.append((t.week, t.name, t.line))
        }
        return ms.filter { $0.week >= session.week }.min { $0.week < $1.week }
            .map { ($0.name, $0.week, $0.line) }
    }

    // MARK: グループ枠（二区画の判読性はこの「枠のかたち」が言う）

    private func groupCard(_ g: ExpGroup, _ pv: GameState) -> some View {
        VStack(spacing: Theme.Sp.s12) {
            HStack {
                Text(g.rawValue).font(.maru(11)).tracking(2).foregroundStyle(Theme.inkDim)
                Spacer()
                freeChip(g, pv)
            }
            ForEach(g.members, id: \.self) { a in
                abilityRow(a, pv)
            }
        }
        .padding(Theme.Sp.s16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card))
        .e2()
    }

    private func mentalCard(_ pv: GameState) -> some View {
        VStack(alignment: .leading, spacing: Theme.Sp.s8) {
            abilityRow(.メンタル, pv)
            Text("器を使わない。").font(.system(size: 11, design: .serif)).foregroundStyle(Theme.inkFaint)
        }
        .padding(Theme.Sp.s16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card))
        .e2()
    }

    /// 共通粒チップ（輪郭ドット＝色がまだ決まっていない粒）。枠ヘッダに1つ＝枠内2行で共有。
    /// ①整理: ρ(expFreeShare)=0 の間は休眠＝常時「共通 0」を出さない（監査§2・機構は残置・表示条件1つ）。
    @ViewBuilder private func freeChip(_ g: ExpGroup, _ pv: GameState) -> some View {
        if config.expFreeShare != 0 {
        HStack(spacing: 4) {
            Circle().stroke(Theme.inkDim, lineWidth: 1.5).frame(width: 7, height: 7)
            Text("共通").font(.maru(9.5)).foregroundStyle(Theme.inkDim)
            Text("\(grains(pv[free: g]))").font(.maru(11)).monospacedDigit().foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Theme.card, in: Capsule())
        .overlay(Capsule().stroke(Theme.line, lineWidth: 1.5))
        }
    }

    /// 同色ロック粒チップ（塗りドット＝行き先が固定の粒）
    private func lockedChip(_ a: Ability, _ pv: GameState) -> some View {
        HStack(spacing: 4) {
            Circle().fill(Theme.abilityColor(a)).frame(width: 7, height: 7)
            Text("\(grains(pv[bank: a]))").font(.maru(11)).monospacedDigit().foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Theme.card2, in: Capsule())
    }

    // MARK: 能力1行（名前・値・+N・残粒チップ・±・バー）

    private func abilityRow(_ a: Ability, _ pv: GameState) -> some View {
        VStack(spacing: 7) {
            HStack(spacing: 6) {
                Circle().fill(Theme.abilityColor(a)).frame(width: 8, height: 8)
                Text("\(a)").font(.maru(12.5)).foregroundStyle(Theme.ink)
                Text("\(Int(displayedValue(a).rounded()))").font(.maru(15)).monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                gainLabel(a, pv)
                Spacer(minLength: 4)
                lockedChip(a, pv)
                stepper(a, pv)
            }
            abilityBar(a, pv)
        }
    }

    /// バー: 濃い塗り＝現在（リビール中は段階値）／薄い塗り＝仮置き後のゴースト
    private func abilityBar(_ a: Ability, _ pv: GameState) -> some View {
        let cap = a == .メンタル ? config.mentalCap : config.abilityCap
        let current = displayedValue(a)
        let ghost = committing ? current : pv[a]
        let color = Theme.abilityColor(a)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.card2)
                Capsule().fill(color.opacity(0.35))
                    .frame(width: geo.size.width * CGFloat(min(1, max(0, ghost / cap))))
                Capsule().fill(color)
                    .frame(width: geo.size.width * CGFloat(min(1, max(0, current / cap))))
            }
        }
        .frame(height: 10)
    }

    /// +N（丸め差分≥1）／「伸びわずか」（実伸びはあるが丸めで0）。WeekMainView の整数ゲイン規約と同じ
    @ViewBuilder private func gainLabel(_ a: Ability, _ pv: GameState) -> some View {
        let from = committing ? (beforeVals[a] ?? s[a]) : s[a]
        let to = committing
            ? (revealedRows.contains(a) ? (afterVals[a] ?? s[a]) : (beforeVals[a] ?? s[a]))
            : pv[a]
        let d = Int(to.rounded()) - Int(from.rounded())
        if d >= 1 {
            Text("+\(d)").font(.maru(11)).monospacedDigit().foregroundStyle(Theme.gainOrange)
                .transition(.asymmetric(
                    insertion: .offset(y: 8).combined(with: .opacity),
                    removal: .offset(y: -8).combined(with: .opacity)))
        } else if to - from > 0.0005 {
            Text("伸びわずか").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.inkFaint)
                .transition(.opacity)
        }
    }

    /// リビール中は before→（行ごとに）after、平時は実値
    private func displayedValue(_ a: Ability) -> Double {
        if committing {
            return revealedRows.contains(a) ? (afterVals[a] ?? s[a]) : (beforeVals[a] ?? s[a])
        }
        return s[a]
    }

    // MARK: ±（タップで1段仮置き。押せない時は沈まず横ブレ＋トースト・振動なし）

    private func stepper(_ a: Ability, _ pv: GameState) -> some View {
        HStack(spacing: 6) {
            if stagedCount(a) > 0 {
                Button { unstage(a) } label: { stepGlyph("minus", active: true) }
                    .buttonStyle(PressableStyle())
                    .transition(.opacity)
            }
            let ok = canStage(a, pv)
            Button { stage(a, pv) } label: { stepGlyph("plus", active: ok) }
                .buttonStyle(PressableStyle(enabled: ok))
                .modifier(ShakeEffect(animatableData: shakeSeed["plus\(a)"] ?? 0))
        }
    }

    private func stepGlyph(_ name: String, active: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(active ? Theme.ink : Theme.inkFaint)
            .frame(width: 30, height: 30)
            .background(Theme.card2, in: Circle())
            .overlay(Circle().stroke(Theme.line, lineWidth: 2))
    }

    private func stagedCount(_ a: Ability) -> Int {
        taps.filter { $0 == a }.count
    }

    /// もう1段注げるか＝プレビュー状態に pourStep を1回試す（確定と同じ関数・同じ判定）
    private func canStage(_ a: Ability, _ pv: GameState) -> Bool {
        var probe = pv
        return GameEngine.pourStep(a, to: &probe, config: config) > GameEngine.pourEpsilon
    }

    private func stage(_ a: Ability, _ pv: GameState) {
        guard !committing else { return }
        if canStage(a, pv) {
            withAnimation(Theme.Motion.appearQuick) { taps.append(a) }
        } else {
            withAnimation(.linear(duration: 0.15)) { shakeSeed["plus\(a)", default: 0] += 1 }
            toast = blockReason(a, pv)
        }
    }

    private func unstage(_ a: Ability) {
        guard !committing, let i = taps.lastIndex(of: a) else { return }
        withAnimation(Theme.Motion.appearQuick) { _ = taps.remove(at: i) }
    }

    private func blockReason(_ a: Ability, _ pv: GameState) -> String {
        if pv.pourable(a) <= GameEngine.pourEpsilon { return "注げる経験点がない。" }
        if a != .メンタル, let b = pv.growthBudget, b - pv.growthUsed <= GameEngine.pourEpsilon {
            return "この年の器は、満ちた。"
        }
        return "ここは、上限まで来ている。"
    }

    // MARK: フッタ（おすすめ・もどす・注ぐ）

    private func footer(_ pv: GameState) -> some View {
        VStack(spacing: Theme.Sp.s8) {
            HStack(spacing: Theme.Sp.s8) {
                Button { suggest() } label: {
                    Text("おすすめ").font(.maru(12)).foregroundStyle(Theme.verm)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Theme.card, in: Capsule())
                        .overlay(Capsule().stroke(Theme.verm.opacity(0.55), lineWidth: 1.5))
                }
                .buttonStyle(PressableStyle())
                .modifier(ShakeEffect(animatableData: shakeSeed["suggest"] ?? 0))
                if !taps.isEmpty {
                    Button { withAnimation(Theme.Motion.exit) { taps = [] } } label: {
                        Text("もどす").font(.maru(12)).foregroundStyle(Theme.inkDim)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Theme.card, in: Capsule())
                            .overlay(Capsule().stroke(Theme.line, lineWidth: 1.5))
                    }
                    .buttonStyle(PressableStyle())
                    .transition(.opacity)
                }
                Spacer()
                if !taps.isEmpty {
                    Text("仮置き \(taps.count)").font(.maru(11)).monospacedDigit()
                        .foregroundStyle(Theme.inkDim)
                        .transition(.opacity)
                }
            }
            Button { commit(pv) } label: {
                Text(taps.isEmpty ? "注ぐ" : "注ぐ（\(taps.count)）")
                    .font(.maru(15)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(taps.isEmpty || committing ? Theme.inkFaint : Theme.verm,
                                in: RoundedRectangle(cornerRadius: Theme.Rad.btn))
            }
            .buttonStyle(PressableStyle(enabled: !taps.isEmpty && !committing))
            .modifier(ShakeEffect(animatableData: shakeSeed["commit"] ?? 0))
        }
        .padding(.horizontal, Theme.Sp.s16).padding(.top, Theme.Sp.s12).padding(.bottom, Theme.Sp.s8)
        .background(LinearGradient(colors: [Theme.bg2.opacity(0), Theme.bg2],
                                   startPoint: .top, endPoint: .center))
    }

    /// おすすめ注ぎ＝GameCore正典 recommendedPlan（golden台本と同じ1関数）を仮置きに展開（確定はしない）
    private func suggest() {
        guard !committing else { return }
        let plan = session.recommendedAllocation()
        if plan.isEmpty {
            withAnimation(.linear(duration: 0.15)) { shakeSeed["suggest", default: 0] += 1 }
            toast = "いま注げる経験点がない。"
        } else {
            withAnimation(Theme.Motion.appear) { taps = plan }
        }
    }

    // MARK: 確定（先に権威stateへ確定→リビールは後追い表示。途中で閉じても状態は正しい）

    private func commit(_ pv: GameState) {
        guard !committing else { return }
        guard !taps.isEmpty else {
            withAnimation(.linear(duration: 0.15)) { shakeSeed["commit", default: 0] += 1 }
            toast = "まだ、経験点を選んでいない。"
            return
        }
        Haptics.confirm()   // 割り振り確定＝hConfirm（Haptics 3段）
        var before: [Ability: Double] = [:]
        var after: [Ability: Double] = [:]
        for a in Ability.allCases {
            before[a] = s[a]
            after[a] = pv[a]
        }
        beforeVals = before
        afterVals = after
        revealedRows = []
        committing = true
        session.allocate(taps)
        taps = []
        Task {
            // 溜め0.25s→1行ずつ emphSpring で立ち上げ0.34s間隔→余韻0.5s（§3-5のローカルTask模倣）
            try? await Task.sleep(nanoseconds: 250_000_000)
            for a in Ability.allCases where (afterVals[a] ?? 0) - (beforeVals[a] ?? 0) > 0.0005 {
                withAnimation(Theme.Motion.emphSpring) { _ = revealedRows.insert(a) }
                try? await Task.sleep(nanoseconds: 340_000_000)
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
            withAnimation(Theme.Motion.appear) {
                committing = false
                revealedRows = []
            }
        }
    }

    // MARK: トースト（WeekMainView と同型）

    @ViewBuilder private var toastBar: some View {
        if let toast {
            Text(toast).font(.maru(12)).foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 9)
                .background(Theme.pillDark, in: Capsule())
                .e1()
                .padding(.bottom, 118)   // フッタ（おすすめ＋注ぐ）の上に出す【仮・目視調整】
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: 導出

    /// 粒の表示個数（切り捨て・浮動小数の塵は無視）
    private func grains(_ v: Double) -> Int {
        Int(v + 1e-9)
    }
}
