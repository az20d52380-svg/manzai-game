// AllocationView.swift
// 割り振り画面（経験点残高→能力へ注ぐ）。正典: docs/exp_abilityup_impl_reply_v0.md（二区画中間・割り振り時予算）。
// UI再設計: Fable 01_能力アップUI再設計_参照忠実（2026-07-18・[golden影響=無]）＝参照系「能力アップ画面」の
// 情報構造・操作を既存二区画機構の"上に"忠実翻案。借りるのは①現在→アップ後の2値＋グレード ②▲1タップ=+1段の
// 一括仮置き ③「つぎの+1 ●n」逓増コストの常時表示 ④まとめ確定＝の情報構造だけ。機構・逓減カーブ・注ぐ量・golden
// には1ビットも触れない——コストの n は既存 pourStep の"再生回数の集計表示"（GameSession.costOfNextStep）であり、
// 支払いは従来どおり pourStep が1粒ずつ行う。実力ヘッダ/グレード/実力の絶対値表示はオーナー承認（2026-07-18・推奨線）。
//
// 判読性の文法: 色付き粒（塗りドット）＝その色の能力にだけ入る／共通粒（輪郭ドット）＝グループ枠ヘッダ（ρ>0で復活）。
// 操作は本作の「タップで即」文法: ▲で1段仮置き（バーに薄ゴースト・「のこり」が n 減る・アップ後値が+1）→「注ぐ」で確定→
// 段階リビール。確定は session.allocate()＝RNG非消費・golden不変。プレビューと確定は同じ pourStep をタップ順に再生する。
//
// ⚠️ // MARK: 要Mac実機ビルド — UIは swift test で検証できない。レイアウト/コスト表示/ブロック仮置き/ゴースト/
//    リビール/グレードpunch/器3枚目/端数トーストは simulator でビルド→起動→目視まで確認して初めて「完了」（規律D-10）。
//    目視フック: MZ_UI=allocate（RootView・粒を積んだ【仮】開始状態）。数値は全て【仮】。

import SwiftUI
import GameCore

struct AllocationView: View {
    @Bindable var session: GameSession
    var onClose: () -> Void

    /// 仮置き＝「+1段ブロック」のタップ順スタック（§3-3）。1ブロック=表示整数を1つ上げるのに要した n 粒。
    /// 確定・プレビューへは flatten した `taps` を渡す＝session.allocate/previewAllocation のシグネチャ・意味は不変。
    @State private var blocks: [(ability: Ability, steps: Int)] = []
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
    /// リビール中の実力ヘッダ ロールアップ用（確定直前state）
    @State private var beforeState: GameState?

    /// flatten した粒列（確定・プレビューの唯一の入力・リプレイ決定論）
    private var taps: [Ability] {
        blocks.flatMap { Array(repeating: $0.ability, count: $0.steps) }
    }

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
                    // 情報階層（§3）: 判断材料（実力ヘッダ）→ 操作（能力群）→ 会計（成長の器）
                    VStack(spacing: Theme.Sp.s16) {
                        jitsuryokuHeader(pv)
                        explainer
                        groupCard(.ネタ, pv)
                        groupCard(.舞台, pv)
                        mentalCard(pv)
                        vesselCard(pv)
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

    // MARK: 実力ヘッダカード（§3-5・参照系の「総合値 現在→アップ後」＋つぎの本番を1枚に統合）

    private func jitsuryokuHeader(_ pv: GameState) -> some View {
        let now = jitsuryokuNow()
        let after = GameEngine.jitsuryoku(pv, config: config) + pv.compat
        let staged = !blocks.isEmpty
        let gain = Int(after.rounded()) - Int(now.rounded())
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("いまの実力").font(.maru(11)).foregroundStyle(Theme.inkDim)
                Text("\(Int(now.rounded()))").font(.maru(21)).monospacedDigit().foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                if staged {
                    Text("→").font(.maru(15)).foregroundStyle(Theme.inkDim)
                    Text("\(Int(after.rounded()))").font(.maru(21)).monospacedDigit().foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                    if gain >= 1 {
                        Text("+\(gain)").font(.maru(12)).monospacedDigit().foregroundStyle(Theme.gainOrange)
                            .transition(.asymmetric(
                                insertion: .offset(y: 8).combined(with: .opacity),
                                removal: .offset(y: -8).combined(with: .opacity)))
                    }
                }
                Spacer()
            }
            nextStageBar(pv)
        }
        .padding(Theme.Sp.s16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card))
        .e1()
    }

    /// リビール中は revealedRows までを反映した実力（段階ロールアップ・§4）。平時は確定stateの実力。
    private func jitsuryokuNow() -> Double {
        if committing {
            let grown = Ability.allCases.filter { (afterVals[$0] ?? 0) - (beforeVals[$0] ?? 0) > 0.0005 }
            let done = grown.allSatisfy { revealedRows.contains($0) }
            let st = done ? s : (beforeState ?? s)
            return GameEngine.jitsuryoku(st, config: config) + st.compat
        }
        return GameEngine.jitsuryoku(s, config: config) + s.compat
    }

    /// つぎの本番バー（旧 nextStageCard の中身・朱線=要求ライン・数値は出さない＝v8確定）
    @ViewBuilder private func nextStageBar(_ pv: GameState) -> some View {
        if let stage = nextStage() {
            let now = jitsuryokuNow()
            let after = committing ? now : (GameEngine.jitsuryoku(pv, config: config) + pv.compat)
            let scale = max(stage.line, after, now) * 1.2
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("つぎの本番").font(.maru(11)).foregroundStyle(Theme.inkDim)
                    Text(stage.name).font(.maru(12)).foregroundStyle(Theme.ink).lineLimit(1)
                    Spacer()
                    Text(stage.week <= session.week ? "今週" : "\(stage.week - session.week)週後")
                        .font(.maru(11)).monospacedDigit().foregroundStyle(Theme.goldD)
                }
                // 地力（実力値＋相性）の現在＝濃い ink／仮置き後＝薄い ink。朱の縦線＝要求ライン（数値なし）
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
            }
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

    /// 二区画の一行説明（枠のかたちが本体・これは補助線）。ρ=0 の間は休眠＝出さない（監査§2）
    @ViewBuilder private var explainer: some View {
        if config.expFreeShare != 0 {
            Text("色の粒は、その色の項へ。共通の粒は、同じ枠のどちらへも。")
                .font(.system(size: 12, design: .serif)).foregroundStyle(Theme.inkDim)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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

    /// 共通粒チップ（輪郭ドット＝色がまだ決まっていない粒）。ρ(expFreeShare)=0 の間は休眠＝出さない（監査§2）
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

    // MARK: 能力1行（§3-1）— 名前行[グレード＋現在→アップ後＋N]／バー／資源行[のこり・つぎの+1・▼▲]

    private func abilityRow(_ a: Ability, _ pv: GameState) -> some View {
        let cap = a == .メンタル ? config.mentalCap : config.abilityCap
        let cost = committing ? nil : session.costOfNextStep(a, in: pv)
        let cur = displayedValue(a)
        let after = pv[a]
        let showArrow = !committing && Int(after.rounded()) > Int(cur.rounded())
        let punchNow = committing && revealedRows.contains(a) && gradeCrossed(a)
        return VStack(spacing: 7) {
            HStack(spacing: 6) {
                Circle().fill(Theme.abilityColor(a)).frame(width: 8, height: 8)
                Text("\(a)").font(.maru(12.5)).foregroundStyle(Theme.ink)
                valSlot(cur, cap: cap, color: Theme.abilityColor(a), accent: false, punch: punchNow)
                if showArrow {
                    Text("→").font(.maru(13)).foregroundStyle(Theme.inkDim)
                    valSlot(after, cap: cap, color: Theme.abilityColor(a), accent: true)
                }
                gainLabel(a, pv)
                Spacer(minLength: 4)
            }
            abilityBar(a, pv)
            resourceRow(a, pv, cost: cost)
        }
    }

    /// グレード＋数値の1スロット（上限は数値の代わりに「極」金・§3-1）。accent=アップ後（能力色）／punch=昇格演出
    @ViewBuilder private func valSlot(_ v: Double, cap: Double, color: Color, accent: Bool, punch: Bool = false) -> some View {
        if v >= cap - GameEngine.pourEpsilon {
            Text("極").font(.maru(16)).foregroundStyle(Theme.gold)
                .scaleEffect(punch ? 1.18 : 1)
        } else {
            HStack(spacing: 3) {
                // グレードは表示整数（丸め値）から引く＝「C 45」のような境界の食い違いを防ぐ（v8: 整数表示）
                Text(Theme.rank(v.rounded())).font(.maru(11, weight: .bold))
                    .foregroundStyle(punch ? Theme.gold : (accent ? color : Theme.inkDim))
                    .scaleEffect(punch ? 1.18 : 1)
                Text("\(Int(v.rounded()))").font(.maru(15)).monospacedDigit()
                    .foregroundStyle(accent ? color : Theme.ink)
                    .contentTransition(.numericText())
            }
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

    /// 資源行（§3-1）: のこり ●n（同色ロック残高）・つぎの+1 ●m（次段コスト）・▼▲
    private func resourceRow(_ a: Ability, _ pv: GameState, cost: Int?) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Text("のこり").font(.maru(9.5)).foregroundStyle(Theme.inkDim)
                Circle().fill(Theme.abilityColor(a)).frame(width: 6, height: 6)
                Text("\(grains(pv[bank: a]))").font(.maru(11)).monospacedDigit().foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
            }
            costChip(a, pv, cost: cost)
            Spacer()
            stepper(a, pv, cost: cost)
        }
    }

    /// 「つぎの+1 ●n」＝参照系コストグリッドの本作版（§3-2）。逓減ぶん n が増えていく様が「上げるほど高い」を言う。
    /// nil の内訳: 上限→値側「極」が言う（ここは空）／器切れ→「器が足りない」／粒切れ・端数→「つぎ —」
    @ViewBuilder private func costChip(_ a: Ability, _ pv: GameState, cost: Int?) -> some View {
        let cap = a == .メンタル ? config.mentalCap : config.abilityCap
        if pv[a] >= cap - GameEngine.pourEpsilon {
            EmptyView()
        } else if let n = cost {
            HStack(spacing: 4) {
                Text("つぎの+1").font(.maru(9.5)).foregroundStyle(Theme.inkDim)
                Circle().fill(Theme.abilityColor(a)).frame(width: 6, height: 6)
                Text("\(n)").font(.maru(11)).monospacedDigit().foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
            }
        } else if a != .メンタル, let b = pv.growthBudget, b - pv.growthUsed <= GameEngine.pourEpsilon {
            Text("器が足りない").font(.maru(9.5)).foregroundStyle(Theme.inkFaint)
        } else {
            Text("つぎ —").font(.maru(9.5)).foregroundStyle(Theme.inkFaint)
        }
    }

    /// +N（丸め差分≥1）／「伸びわずか」（実伸びはあるが丸めで0＝おすすめの端数のみ）。WeekMainView の整数ゲイン規約と同じ
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

    /// グレードが仮置き/リビールで跨いだか（punch判定・グレードは表示写像のみ＝判定に無関係を崩さない）。
    /// 表示整数（丸め値）で判定＝valSlot のグレード表示と一致させる
    private func gradeCrossed(_ a: Ability) -> Bool {
        guard let b = beforeVals[a], let af = afterVals[a] else { return false }
        return Theme.rank(b.rounded()) != Theme.rank(af.rounded())
    }

    // MARK: ▼▲（§3-3・仮置きの単位を「+1段ブロック」へ。押せない時は沈まず横ブレ＋トースト・振動なし）

    private func stepper(_ a: Ability, _ pv: GameState, cost: Int?) -> some View {
        HStack(spacing: 6) {
            if stagedBlocks(a) > 0 {
                Button { unstage(a) } label: { stepGlyph("minus", active: true) }
                    .buttonStyle(PressableStyle())
                    .transition(.opacity)
            }
            let ok = cost != nil && !committing
            Button { stage(a, pv, cost: cost) } label: { stepGlyph("plus", active: ok) }
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

    /// この能力に仮置き済みの+1段ブロック数（＝手振りの+N・▼の有無）
    private func stagedBlocks(_ a: Ability) -> Int {
        blocks.reduce(0) { $0 + ($1.ability == a ? 1 : 0) }
    }

    /// ▲=「+1到達に要する n 粒ぶん」を一括仮置き。cost は body 描画時に costOfNextStep で確定済み（同一pv）
    private func stage(_ a: Ability, _ pv: GameState, cost: Int?) {
        guard !committing else { return }
        if let n = cost {
            withAnimation(Theme.Motion.appearQuick) { blocks.append((ability: a, steps: n)) }
        } else {
            withAnimation(.linear(duration: 0.15)) { shakeSeed["plus\(a)", default: 0] += 1 }
            toast = blockReason(a, pv)
        }
    }

    /// ▼=その能力の最後のブロックを1つ戻す（表示上「+1ずつ戻る」）
    private func unstage(_ a: Ability) {
        guard !committing, let i = blocks.lastIndex(where: { $0.ability == a }) else { return }
        withAnimation(Theme.Motion.appearQuick) { _ = blocks.remove(at: i) }
    }

    private func blockReason(_ a: Ability, _ pv: GameState) -> String {
        if pv.pourable(a) <= GameEngine.pourEpsilon { return "注げる経験点がない。" }
        let cap = a == .メンタル ? config.mentalCap : config.abilityCap
        if pv[a] >= cap - GameEngine.pourEpsilon { return "ここは、上限まで来ている。" }
        if a != .メンタル, let b = pv.growthBudget, b - pv.growthUsed <= GameEngine.pourEpsilon {
            return "この年の器は、満ちた。"
        }
        return "一段には、あと少し足りない。"   // 粒はあるが+1段に届かない（端数）＝出口はおすすめ（§3-4）
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
                if !blocks.isEmpty {
                    Button { withAnimation(Theme.Motion.exit) { blocks = [] } } label: {
                        Text("もどす").font(.maru(12)).foregroundStyle(Theme.inkDim)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Theme.card, in: Capsule())
                            .overlay(Capsule().stroke(Theme.line, lineWidth: 1.5))
                    }
                    .buttonStyle(PressableStyle())
                    .transition(.opacity)
                }
                Spacer()
                if !blocks.isEmpty {
                    Text("仮置き \(blocks.count)").font(.maru(11)).monospacedDigit()
                        .foregroundStyle(Theme.inkDim)
                        .transition(.opacity)
                }
            }
            Button { commit(pv) } label: {
                Text(blocks.isEmpty ? "注ぐ" : "注ぐ（\(blocks.count)）")
                    .font(.maru(15)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(blocks.isEmpty || committing ? Theme.inkFaint : Theme.verm,
                                in: RoundedRectangle(cornerRadius: Theme.Rad.btn))
            }
            .buttonStyle(PressableStyle(enabled: !blocks.isEmpty && !committing))
            .modifier(ShakeEffect(animatableData: shakeSeed["commit"] ?? 0))
        }
        .padding(.horizontal, Theme.Sp.s16).padding(.top, Theme.Sp.s12).padding(.bottom, Theme.Sp.s8)
        .background(LinearGradient(colors: [Theme.bg2.opacity(0), Theme.bg2],
                                   startPoint: .top, endPoint: .center))
    }

    /// おすすめ注ぎ＝GameCore正典 recommendedPlan（golden台本と同じ1関数）を「能力ごと+1段ブロック」に畳んで仮置き（§3-4）。
    /// 平坦な粒列を順に再生し、表示整数が+1する境界でブロックを閉じる＝flatten すれば元の plan と1:1（確定は不変）。
    /// 端数（+1未満）は最後のブロックに残る＝確定後「伸びわずか」で正直に見える（手振りからは端数が消え、出口はここだけ）。
    private func suggest() {
        guard !committing else { return }
        let plan = session.recommendedAllocation()
        if plan.isEmpty {
            withAnimation(.linear(duration: 0.15)) { shakeSeed["suggest", default: 0] += 1 }
            toast = "いま注げる経験点がない。"
            return
        }
        var probe = s
        var newBlocks: [(ability: Ability, steps: Int)] = []
        var runAbility: Ability?
        var runSteps = 0
        var runBase = 0
        func closeRun() {
            if let ra = runAbility, runSteps > 0 { newBlocks.append((ability: ra, steps: runSteps)) }
            runSteps = 0
        }
        for a in plan {
            if runAbility != a { closeRun(); runAbility = a; runBase = Int(probe[a].rounded()) }
            GameEngine.pourStep(a, to: &probe, config: config)
            runSteps += 1
            if Int(probe[a].rounded()) >= runBase + 1 {
                newBlocks.append((ability: a, steps: runSteps))
                runSteps = 0
                runBase = Int(probe[a].rounded())
            }
        }
        closeRun()
        withAnimation(Theme.Motion.appear) { blocks = newBlocks }
    }

    // MARK: 確定（先に権威stateへ確定→リビールは後追い表示。途中で閉じても状態は正しい）

    private func commit(_ pv: GameState) {
        guard !committing else { return }
        guard !blocks.isEmpty else {
            withAnimation(.linear(duration: 0.15)) { shakeSeed["commit", default: 0] += 1 }
            toast = "まだ、経験点を選んでいない。"
            return
        }
        Haptics.confirm()   // 割り振り確定＝hConfirm（Haptics 3段）
        let currentTaps = taps
        var before: [Ability: Double] = [:]
        var after: [Ability: Double] = [:]
        for a in Ability.allCases {
            before[a] = s[a]
            after[a] = pv[a]
        }
        beforeVals = before
        afterVals = after
        beforeState = s
        revealedRows = []
        committing = true
        session.allocate(currentTaps)
        blocks = []
        Task {
            // 溜め0.25s→1行ずつ emphSpring で立ち上げ0.34s間隔→余韻0.5s（グレード昇格行は punch＋金・§4）
            try? await Task.sleep(nanoseconds: 250_000_000)
            for a in Ability.allCases where (afterVals[a] ?? 0) - (beforeVals[a] ?? 0) > 0.0005 {
                withAnimation(Theme.Motion.emphSpring) { _ = revealedRows.insert(a) }
                try? await Task.sleep(nanoseconds: 340_000_000)
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
            withAnimation(Theme.Motion.appear) {
                committing = false
                revealedRows = []
                beforeState = nil
            }
        }
    }

    // MARK: 成長の器（会計の残量＝操作の下・§3。数値なし＝growthRoom文法。3枚目=器の食い合い・§5-1）

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
            Text(vesselLine(frac: frac))
                .font(.system(size: 13, design: .serif)).foregroundStyle(Theme.ink)
        }
        .padding(Theme.Sp.s16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card))
        .e1()
    }

    /// 器の状態一文（3枚・排他）。満了＞食い合い＞平常。食い合い=手持ち粒を全部注ぐと器が先に尽きる（§5-1）
    private func vesselLine(frac: Double) -> String {
        if frac >= 0.98 { return "この年の器は、満ちた。" }
        if overflowingGrains() { return "のこりの器より、粒が多い。" }
        return "まだ、伸びしろがある。"
    }

    /// 手持ち粒を全量おすすめ注ぎしたら器が先に満ちて粒が余るか（純関数・RNG非消費・golden台本 pourRecommended の再生）
    private func overflowingGrains() -> Bool {
        guard let budget = s.growthBudget, budget > 0 else { return false }
        var probe = s
        GameEngine.pourRecommended(to: &probe, config: config)
        let filled = probe.growthUsed >= budget - 1e-6
        return filled && probe.expTotal > 1e-9
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
