// AllocationView.swift
// 割り振り画面（経験点残高→能力へ注ぐ）。正典v3: docs/exp_currency_redesign_v0.md（パワプロ式5通貨・
// オーナー指示2026-08-02「経験値はパワーそのままじゃない。筋力技術などで振り分けて能力アップする」対応）。
// 旧・同色ロック+共通枠2グループ方式（docs/exp_abilityup_impl_reply_v0.md）を置換。借りるのは①現在→アップ後の
// 2値＋グレード ②▲1タップ=+1段の一括仮置き ③レシピ内訳（この能力がどの通貨から何%育つか）の常時表示
// ④まとめ確定＝の情報構造。機構・逓減カーブ・注ぐ量・golden には1ビットも触れない——コストの n は既存 pourStep の
// "再生回数の集計表示"（GameSession.costOfNextStep）であり、支払いは従来どおり pourStep が1段ずつ行う。
//
// 判読性の文法: 通貨バッジ（角丸・色+文字＝色弱対応）＝能力バッジ（丸・色+文字）と意図的に別シェイプ。
// 各能力行にレシピ内訳チップ（通貨バッジ+%）を常設＝「この能力は複数通貨のブレンドで伸びる」を毎回見せる。
// 操作は本作の「タップで即」文法: ▲で1段仮置き（バーに薄ゴースト・アップ後値が+1）→「注ぐ」で確定→段階リビール。
// 確定は session.allocate()＝RNG非消費・golden不変。プレビューと確定は同じ pourStep をタップ順に再生する。
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
            // フッタは safeAreaInset でなく通常の VStack 兄弟にする（診断済み・コミット参照）: コンテンツが
            // 画面に収まる（スクロール不要）とき、safeAreaInset は ScrollView のビューポート自体の高さを
            // フッタぶん縮めてくれず、最終カードがフッタの裏に食い込んでいた。VStack内でScrollViewを可変
            // （他が固定高のため自動でmaxHeightを埋める）にし、フッタを実兄弟にすれば構造的に重ならない。
            VStack(spacing: 0) {
                VStack(spacing: Theme.Sp.s12) {
                    header
                    expWallet(pv)   // パワプロの経験点常時表示＝上部の通貨バー（仮置きで残高が生きて減る）
                    ScrollView {
                        VStack(spacing: Theme.Sp.s16) {
                            jitsuryokuHeader(pv)
                            recipeLegend
                            ForEach(Ability.allCases, id: \.self) { a in
                                abilityCard(a, pv)
                            }
                            vesselCard(pv)
                        }
                        .padding(.horizontal, Theme.Sp.s16)
                        .padding(.bottom, Theme.Sp.s24)
                    }
                    .clipped()
                }
                .padding(.top, Theme.Sp.s12)
                footer(pv)
            }
        }
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

    // MARK: 経験点ウォレット（パワプロ式＝画面上部に5通貨を常時デカ表示。仮置きで減るのが見える）
    // 通貨は能力名と別立て（正典v3）＝角丸バッジ（AbilityBadgeの丸と意図的に別シェイプ）で「別物」と一目で分かる。

    private func expWallet(_ pv: GameState) -> some View {
        HStack(spacing: 5) {
            ForEach(ExpCurrency.allCases, id: \.self) { c in
                HStack(spacing: 4) {
                    CurrencyBadge(currency: c, size: 18)
                    Text("\(grains(pv[currency: c]))").font(.maru(15)).monospacedDigit()
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(.white, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.currencyColor(c).opacity(0.85), lineWidth: 2))
                .shadow(color: Theme.cmdShadow, radius: 0, y: 2)
            }
        }
        .padding(.horizontal, Theme.Sp.s16)
        .animation(.easeOut(duration: 0.25), value: walletSignature(pv))
    }

    /// 残高の合成キー（numericText を回すための変化検知）
    private func walletSignature(_ pv: GameState) -> Int {
        ExpCurrency.allCases.reduce(0) { $0 &* 31 &+ grains(pv[currency: $1]) }
    }

    /// 通貨の凡例（画面上部で1度だけ「これは能力と別物」を言う・パワプロには無いが初見の理解を助ける【仮】）
    private var recipeLegend: some View {
        Text("能力は複数の経験点をブレンドして伸びる。稽古の種類で稼げる通貨が変わる。")
            .font(.system(size: 11.5, design: .serif)).foregroundStyle(Theme.inkDim)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .overlay(RoundedRectangle(cornerRadius: Theme.Rad.card).stroke(Theme.line, lineWidth: 2.5))
        .shadow(color: Theme.cmdShadow, radius: 0, y: 3)
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

    // MARK: 能力カード（正典v3・グループ枠を廃し1能力1カードに統一＝レシピ内訳がグループの代わりに「多対多」を言う）

    private func abilityCard(_ a: Ability, _ pv: GameState) -> some View {
        VStack(alignment: .leading, spacing: Theme.Sp.s8) {
            abilityRow(a, pv)
            if a == .メンタル {
                Text("器を使わない。").font(.system(size: 11, design: .serif)).foregroundStyle(Theme.inkFaint)
            }
        }
        .padding(Theme.Sp.s16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Rad.card).stroke(Theme.line, lineWidth: 2.5))
        .shadow(color: Theme.cmdShadow, radius: 0, y: 3)
    }

    /// レシピ内訳チップ列（この能力がどの通貨から何%育つか・パワプロのコスト表に相当・正典v3の核）。
    /// 常設表示＝「経験値はパワーそのまま使わない」がボタンを押さずとも常に見える。
    private func recipeChips(_ a: Ability) -> some View {
        HStack(spacing: 5) {
            ForEach(config.abilityRecipes[a] ?? [], id: \.0) { c, w in
                HStack(spacing: 3) {
                    CurrencyBadge(currency: c, size: 13)
                    Text("\(Int((w * 100).rounded()))%").font(.maru(9.5)).monospacedDigit()
                        .foregroundStyle(Theme.inkDim)
                }
            }
        }
    }

    // MARK: 能力1行（§3-1）— 名前行[グレード＋現在→アップ後＋N]／バー／レシピ内訳／資源行[つぎの段数・▼▲]

    private func abilityRow(_ a: Ability, _ pv: GameState) -> some View {
        let cap = a == .メンタル ? config.mentalCap : config.abilityCap
        let cost = committing ? nil : session.costOfNextStep(a, in: pv)
        let cur = displayedValue(a)
        let after = pv[a]
        let showArrow = !committing && Int(after.rounded()) > Int(cur.rounded())
        let punchNow = committing && revealedRows.contains(a) && gradeCrossed(a)
        return VStack(spacing: 7) {
            HStack(spacing: 8) {
                // パワプロ式: 等級のデカ文字バッジが行の主役（D青地→C緑地…昇格で色ごと変わる）
                gradeBadge(cur, cap: cap, punch: punchNow)
                Text(String(describing: a)).font(.maru(13.5)).foregroundStyle(Theme.ink)
                Text("\(Int(cur.rounded()))").font(.maru(20)).monospacedDigit().foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                if showArrow {
                    Image(systemName: "arrowtriangle.right.fill")
                        .font(.system(size: 10)).foregroundStyle(Theme.gainOrange)
                    gradeBadge(after, cap: cap, small: true)
                    Text("\(Int(after.rounded()))").font(.maru(20)).monospacedDigit()
                        .foregroundStyle(Theme.abilityColor(a))
                        .contentTransition(.numericText())
                }
                gainLabel(a, pv)
                Spacer(minLength: 4)
            }
            abilityBar(a, pv)
            recipeChips(a)
            resourceRow(a, pv, cost: cost)
        }
    }

    /// パワプロ式の等級バッジ（等級色の角丸地に白デカ文字・上限＝金「極」・punch=昇格の一拍）。
    /// グレードは表示整数（丸め値）から引く＝「C 45」のような境界の食い違いを防ぐ（v8: 整数表示）
    private func gradeBadge(_ v: Double, cap: Double, small: Bool = false, punch: Bool = false) -> some View {
        let capped = v >= cap - GameEngine.pourEpsilon
        let grade = capped ? "極" : Theme.rank(v.rounded())
        let size: CGFloat = small ? 24 : 31
        return Text(grade)
            .font(.maru(small ? 13 : 16, weight: .black)).foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(capped ? Theme.gold : Theme.gradeColor(grade),
                        in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(.white, lineWidth: 1.5))
            .shadow(color: Theme.cmdShadow, radius: 0, y: 1.5)
            .scaleEffect(punch ? 1.25 : 1)
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

    /// 資源行（正典v3）: つぎの+1 に要る段数（レシピの全通貨を同時消費・costOfNextStep は不変）・▼▲。
    /// 「のこり」は通貨ごとの単一残高でなくなった＝画面上部の通貨ウォレットが担う（重複表示をやめた）。
    private func resourceRow(_ a: Ability, _ pv: GameState, cost: Int?) -> some View {
        HStack(spacing: 10) {
            costChip(a, pv, cost: cost)
            Spacer()
            stepper(a, pv, cost: cost)
        }
    }

    /// 「つぎの+1 段」＝参照系コストグリッドの本作版（§3-2）。逓減ぶん n が増えていく様が「上げるほど高い」を言う。
    /// 正典v3: 1段でレシピの全通貨を同時消費するため、通貨個別でなく「段数」で見せる（内訳は recipeChips が常設）。
    /// nil の内訳: 上限→値側「極」が言う（ここは空）／器切れ→「器が足りない」／通貨切れ・端数→「つぎ —」
    @ViewBuilder private func costChip(_ a: Ability, _ pv: GameState, cost: Int?) -> some View {
        let cap = a == .メンタル ? config.mentalCap : config.abilityCap
        if pv[a] >= cap - GameEngine.pourEpsilon {
            EmptyView()
        } else if let n = cost {
            HStack(spacing: 4) {
                Text("つぎの+1").font(.maru(9.5)).foregroundStyle(Theme.inkDim)
                Text("\(n)段").font(.maru(11)).monospacedDigit().foregroundStyle(Theme.ink)
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

    // MARK: ▲▼（パワプロ実機準拠・2026-08-02オーナー指示＝丸+ではなく縦積みの三角ボタン対）
    // 押せない時は沈まず横ブレ＋トースト・振動なし（§3-3）。▲=1段仮置き／▼=1段取り消し（常時2つとも表示）。

    private func stepper(_ a: Ability, _ pv: GameState, cost: Int?) -> some View {
        let canUp = cost != nil && !committing
        let canDown = stagedBlocks(a) > 0 && !committing
        return VStack(spacing: 3) {
            Button { stage(a, pv, cost: cost) } label: { triangleGlyph(up: true, active: canUp) }
                .buttonStyle(PressableStyle(enabled: canUp, silent: true))
                .modifier(ShakeEffect(animatableData: shakeSeed["plus\(a)"] ?? 0))
            Button { Sound.play(.cancel); unstage(a) } label: { triangleGlyph(up: false, active: canDown) }
                .buttonStyle(PressableStyle(enabled: canDown, silent: true))
        }
    }

    /// パワプロ実機の▲▼＝小さな角丸スクエアに三角。有効時は朱・無効時は淡いグレーで沈む。
    private func triangleGlyph(up: Bool, active: Bool) -> some View {
        Image(systemName: up ? "triangle.fill" : "arrowtriangle.down.fill")
            .font(.system(size: 11, weight: .black))
            .foregroundStyle(active ? .white : Theme.inkFaint)
            .frame(width: 30, height: 22)
            .background(active
                        ? AnyShapeStyle(LinearGradient(colors: [Theme.verm, Theme.vermD],
                                                       startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(Theme.card2),
                        in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(active ? .white.opacity(0.6) : Theme.line, lineWidth: 1.5))
            .shadow(color: active ? Theme.vermD.opacity(0.4) : .clear, radius: 0, y: 1.5)
    }

    /// この能力に仮置き済みの+1段ブロック数（＝手振りの+N・▼の有無）
    private func stagedBlocks(_ a: Ability) -> Int {
        blocks.reduce(0) { $0 + ($1.ability == a ? 1 : 0) }
    }

    /// ▲=「+1到達に要する n 粒ぶん」を一括仮置き。cost は body 描画時に costOfNextStep で確定済み（同一pv）
    private func stage(_ a: Ability, _ pv: GameState, cost: Int?) {
        guard !committing else { return }
        if let n = cost {
            Sound.play(.kira)   // 仮置き＝キラッ（粒を積む手応え）
            withAnimation(Theme.Motion.appearQuick) { blocks.append((ability: a, steps: n)) }
        } else {
            Sound.play(.deny)
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
        if pv.pourable(a, config: config) <= GameEngine.pourEpsilon { return "注げる経験点がない。" }
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
                    Text("おすすめ").font(.maru(13)).foregroundStyle(Theme.verm)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(.white, in: Capsule())
                        .overlay(Capsule().stroke(Theme.verm.opacity(0.7), lineWidth: 2.5))
                        .shadow(color: Theme.cmdShadow, radius: 0, y: 2)
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
            // パワプロの「決定！」＝画面の締めの大ボタン（朱グラデ・白内枠線・ハード影）
            Button { commit(pv) } label: {
                Text(blocks.isEmpty ? "注ぐ" : "注ぐ！（\(blocks.count)段）")
                    .font(.maru(17)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(blocks.isEmpty || committing
                                ? AnyShapeStyle(Theme.inkFaint)
                                : AnyShapeStyle(LinearGradient(colors: [Theme.verm, Theme.vermD],
                                                               startPoint: .top, endPoint: .bottom)),
                                in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(.white.opacity(0.35), lineWidth: 1.5).padding(3))
                    .shadow(color: blocks.isEmpty ? Theme.cmdShadow : Theme.vermD.opacity(0.45), radius: 0, y: 3)
            }
            .buttonStyle(PressableStyle(enabled: !blocks.isEmpty && !committing, silent: true))
            .modifier(ShakeEffect(animatableData: shakeSeed["commit"] ?? 0))
        }
        .padding(.horizontal, Theme.Sp.s16).padding(.top, Theme.Sp.s12).padding(.bottom, Theme.Sp.s8)
        // 不透明な地色（診断済み・コミット参照）: 上端が透明なグラデーションだと、ScrollView側の
        // クリップ境界とフッタの表示領域がズレた時（このView階層で実測済み）にカードの端が薄く透けて見える。
        // 不透明にして確実に覆うことで、レイアウトの微妙なズレに対しても症状（重なって見える）を出さない。
        .background(Theme.bg2)
    }

    /// おすすめ注ぎ＝GameCore正典 recommendedPlan（golden台本と同じ1関数）を「能力ごと+1段ブロック」に畳んで仮置き（§3-4）。
    /// 平坦な粒列を順に再生し、表示整数が+1する境界でブロックを閉じる＝flatten すれば元の plan と1:1（確定は不変）。
    /// 端数（+1未満）は最後のブロックに残る＝確定後「伸びわずか」で正直に見える（手振りからは端数が消え、出口はここだけ）。
    private func suggest() {
        guard !committing else { return }
        let plan = session.recommendedAllocation()
        if plan.isEmpty {
            Sound.play(.deny)
            withAnimation(.linear(duration: 0.15)) { shakeSeed["suggest", default: 0] += 1 }
            toast = "いま注げる経験点がない。"
            return
        }
        Sound.play(.pop)
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
            Sound.play(.deny)
            withAnimation(.linear(duration: 0.15)) { shakeSeed["commit", default: 0] += 1 }
            toast = "まだ、経験点を選んでいない。"
            return
        }
        Haptics.confirm()   // 割り振り確定＝hConfirm（Haptics 3段）
        Sound.play(.success)
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
                // パワプロの昇格演出: 上がった行はキラ・等級が繰り上がった行はランクアップ音＋Haptics
                if gradeCrossed(a) { Sound.play(.rankup); Haptics.confirm() }
                else { Sound.play(.grain) }
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
        .overlay(RoundedRectangle(cornerRadius: Theme.Rad.card).stroke(Theme.line, lineWidth: 2.5))
        .shadow(color: Theme.cmdShadow, radius: 0, y: 3)
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
