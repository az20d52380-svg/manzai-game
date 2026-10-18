// AbilityUpView.swift
// 能力アップ（パワプロのサクセス式・オーナー指示 2026-10-12／判断 2026-10-10 ②手動の能力アップ復活）。
// 1能力＝1行（等級・値・次の+1に要る経験点・＋ボタン）。おまかせ＝今までの自動注ぎと同じ1関数。
// 旧「のばす」（AllocationView・レシピ表と小数の粒）の置き換え。確定は session.allocate(taps)＝RNG非消費・golden不変。
// 経験点は内部値×10 の整数で見せる（内部は 0.5 刻みの小数＝表示写像だけ）。

import SwiftUI
import GameCore

struct AbilityUpView: View {
    @Bindable var session: GameSession
    let onClose: () -> Void
    /// この画面で押した段の並び（pourStep を順に再生＝見積もりと確定が同じ）
    @State private var taps: [Ability] = []
    /// ＋を押した行が一瞬「金」に光る
    @State private var flash: Ability? = nil

    private var cfg: GameConfig { session.config }
    private var base: GameState { session.state }
    private var pv: GameState { session.previewAllocation(taps) }

    /// 経験点の表示値（内部×10・切り捨て）。ExpDisplay.value へ集約
    static func points(_ v: Double) -> Int { ExpDisplay.value(v) }

    /// 列の固定幅（Gemini r2）：能力名70・＋50・経験点5列は各42・列間6。現在の経験点の行と下の費用が同じ中心線に乗る
    @State private var pulse = false
    @State private var hint: HintSpec?   // 初めて開いた時だけの説明（`？` で読み返せる）
    @State private var bumped: Ability? = nil

    /// 和の五色（閃・語・間・存・胆）＝正本 §2 の経験点5色
    private func wa(_ c: ExpCurrency) -> Color {
        switch c {
        case .閃き: return YoseColor.expSen
        case .語彙: return YoseColor.expGo
        case .間合い: return YoseColor.expMa
        case .存在感: return YoseColor.expSon
        case .胆力: return YoseColor.expTan
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            YoseHeaderBar(title: "能力アップ")
                .overlay(alignment: .trailing) {
                    HintMarkButton { hint = Self.hintSpec }.padding(.trailing, 6).padding(.top, 20)
                }
            ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 10) {
                    compareBox
                    matrixHeader
                    ForEach(Ability.allCases, id: \.self) { row($0) }
                    HStack(alignment: .top, spacing: 8) {
                        Text("数字＝その能力を1上げるのに使う経験点。灰色は持ち分が足りない")
                            .font(YoseFont.gothic(11, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
                            .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                        // 特技は画面の下に隠れやすい（目視 visual_check_q90_q106_v0）＝ここから飛べる
                        Button { withAnimation { proxy.scrollTo("skills", anchor: .top) } } label: {
                            Text("特技 ↓").font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.shu)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .overlay(Rectangle().stroke(YoseColor.shu, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    skillsSection.id("skills")
                }
                .padding(.horizontal, YoseMetrics.screenMargin).padding(.top, 12).padding(.bottom, 16)
            }
            #if DEBUG
            .task { if ProcessInfo.processInfo.environment["MZ_SKILL"] == "scroll" { try? await Task.sleep(nanoseconds: 800_000_000); proxy.scrollTo("skills", anchor: .top) } }   // 目視用: 特技の段へ
            #endif
            }
            footer
        }
        .background(YoseColor.kinari.ignoresSafeArea())
        .overlay { if let h = hint { HintModal(spec: h) { OneTimeHint.markDone(h.key); hint = nil } } }
        .task {
            if !OneTimeHint.suppressedForDebug, !OneTimeHint.isDone(Self.hintSpec.key) {
                try? await Task.sleep(nanoseconds: 450_000_000)
                hint = Self.hintSpec
            }
        }
        #if DEBUG
        .task { if ProcessInfo.processInfo.environment["MZ_TAPS"] != nil { try? await Task.sleep(nanoseconds: 1_500_000_000); taps = [.センス, .発想, .センス] } }   // 目視用: ＋を押した後の状態
        #endif
    }

    // MARK: 特技（キュー106）：余った経験点の使い道。各1回きり・覚えたらずっと効く

    @State private var skillToLearn: Skill? = nil

    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("特技").font(YoseFont.gothic(15, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                .padding(.top, 8)
            Text("余った経験点で覚える。一度覚えたらずっと効く")
                .font(YoseFont.gothic(11, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
                .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Skill.allCases, id: \.self) { skillCard($0) }
        }
        .confirmationDialog(skillToLearn.map { "「\($0.rawValue)」を覚える？" } ?? "", isPresented: Binding(
            get: { skillToLearn != nil }, set: { if !$0 { skillToLearn = nil } }), titleVisibility: .visible) {
            Button("覚える") {
                guard let k = skillToLearn else { return }
                if !taps.isEmpty { _ = session.allocate(taps); taps.removeAll() }   // 押した段を先に確定してから覚える
                if session.learnSkill(k) { Haptics.tick() }
                skillToLearn = nil
            }
            Button("やめる", role: .cancel) { skillToLearn = nil }
        }
    }

    private func skillCard(_ k: Skill) -> some View {
        let learned = base.has(k)
        let affordable = GameEngine.canLearn(k, state: pv)
        return Button { if affordable, !learned { skillToLearn = k } } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(k.rawValue).font(YoseFont.gothic(14, weight: .heavy))
                    Text(k.summary).font(YoseFont.gothic(11, weight: .bold)).lineLimit(2)
                    HStack(spacing: 4) {   // 費用は上の持ち分と同じ一字＋色（胆・存…）でそろえる
                        Text("経験点").font(YoseFont.gothic(11, weight: .bold)).opacity(0.8)
                        ForEach(Array(k.cost.enumerated()), id: \.offset) { _, c in
                            HStack(spacing: 2) {
                                Text(Theme.currencyChar(c.currency)).font(YoseFont.gothic(10, weight: .black)).foregroundStyle(.white)
                                    .frame(width: 16, height: 16).background(wa(c.currency))
                                Text("\(ExpDisplay.cost(c.amount, have: pv[currency: c.currency]))").font(YoseFont.number(12, weight: .heavy))
                            }
                        }
                    }
                }
                Spacer(minLength: 4)
                if !learned, !affordable {   // 足りない数（持ち分との差・表示値は能力アップの表と同じ丸め）
                    VStack(alignment: .trailing, spacing: 1) {
                        ForEach(Array(k.cost.enumerated()), id: \.offset) { _, c in
                            let lack = ExpDisplay.cost(c.amount, have: pv[currency: c.currency]) - ExpDisplay.value(pv[currency: c.currency])
                            if c.amount > pv[currency: c.currency] + 1e-9, lack > 0 {
                                Text("\(String(describing: c.currency)) あと\(lack)").font(YoseFont.gothic(11, weight: .heavy)).foregroundStyle(YoseColor.shu)
                            }
                        }
                    }
                }
                if learned {
                    Text("覚えた").font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3).background(YoseColor.shu)
                }
            }
            .foregroundStyle(learned || affordable ? YoseColor.sumi : YoseColor.haiSumi)
            .padding(.horizontal, 10).padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(learned ? YoseColor.kinBright.opacity(0.14) : (affordable ? YoseColor.washi : YoseColor.sumi.opacity(0.08)))
            .overlay(Rectangle().stroke(YoseColor.sumi.opacity(affordable || learned ? 0.5 : 0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!learned && !affordable)   // 覚えた札は薄くせず（印を読めるように）、押しても何も起きない
    }

    static var hintSpec: HintSpec {
        HintSpec(key: "abilityUp", title: "能力アップ", rows: [
            .init(term: "経験点", text: "練習やネタ書きでたまる。閃・語・間・存・胆の数字が、いま持っている分。"),
            .init(term: "＋", text: "能力の「＋」で経験点を使うと、その能力が上がり、実力が伸びる。"),
            .init(term: "おまかせ", text: "迷ったら「おまかせ」。自動で割り振る。「確定」を押すまで決まらない。"),
            .init(term: "ランク", text: "G、F……と上がっていく。「Fまで5」は、Fに上がるまでの残り。"),
        ])
    }

    /// ランクの色（墓石に見えないよう、G/F=真鍮・E/D=青銅・A=朱＋金枠・S=黄金）
    static func emblemFill(_ g: String) -> AnyShapeStyle {
        switch g {
        // 全ランク同じ文法（メタリックのグラデ＋縁）。F/E=鉄・D/C=青銅・B/A=赤金・S=紫紺のプラチナ
        case "S": return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x5B4B9A), Color(hex: 0x2A2060)], startPoint: .top, endPoint: .bottom))
        case "A": return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xD4452F), Color(hex: 0x962012)], startPoint: .top, endPoint: .bottom))
        case "B": return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xE0932E), Color(hex: 0xB06418)], startPoint: .top, endPoint: .bottom))
        case "C", "D": return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x8D6350), Color(hex: 0x4E342E)], startPoint: .top, endPoint: .bottom))
        default: return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x5A5A5A), Color(hex: 0x2C2C2C)], startPoint: .top, endPoint: .bottom))
        }
    }
    /// ランクの縁色（鉄=銀・青銅=銅・金=金・S=薄紫の白金）
    static func emblemRim(_ g: String) -> Color {
        switch g {
        case "S": return Color(hex: 0xC9BDF2)
        case "A", "B": return Color(hex: 0xF1C40F)
        case "C", "D": return Color(hex: 0xC8875A)
        default: return Color(hex: 0xB8BEC4)
        }
    }
    static func emblemText(_ g: String) -> Color {
        switch g {
        default: return .white
        }
    }

    /// 上段：「現在」と「能力アップ後」の2段（能力5つのランクと値）。上がる所は色と↑矢印（全画面のランクアップ演出は出さない）
    private var compareBox: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Color.clear.frame(width: 52, height: 1)
                ForEach(Ability.allCases, id: \.self) { a in
                    Text("\(a)").font(YoseFont.gothic(11, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                        .lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 4).background(YoseColor.ki)
            compareRow(title: "現在", state: base, after: false)
            Rectangle().fill(YoseColor.sumi).frame(height: 1.5)
            compareRow(title: "アップ後", state: pv, after: true)
        }
        .background(YoseColor.washi)
        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
        .animation(.easeOut(duration: 0.25), value: taps.count)
    }

    private func compareRow(title: String, state s: GameState, after: Bool) -> some View {
        HStack(spacing: 0) {
            Text(title).font(YoseFont.gothic(11, weight: .heavy)).foregroundStyle(after ? YoseColor.shu : YoseColor.haiSumi)
                .lineLimit(1).minimumScaleFactor(0.7).frame(width: 52)
            ForEach(Ability.allCases, id: \.self) { a in
                let v = Int(s[a].rounded())
                let g = Theme.rank(s[a])
                let up = after && Theme.rank(base[a]) != g
                let raised = after && v > Int(base[a].rounded())
                VStack(spacing: 0) {
                    HStack(spacing: 1) {
                        Text(g).font(YoseFont.number(20, weight: .heavy)).foregroundStyle(up ? YoseColor.shu : YoseColor.sumi)
                        if up { Image(systemName: "arrow.up").font(.system(size: Font.mzScaled(10), weight: .black)).foregroundStyle(YoseColor.shu).accessibilityHidden(true) }
                    }
                    HStack(spacing: 1) {
                        Text("\(v)").font(YoseFont.number(13, weight: .bold)).foregroundStyle(raised ? YoseColor.shu : YoseColor.haiSumi)
                        if raised { Image(systemName: "arrow.up").font(.system(size: Font.mzScaled(8), weight: .black)).foregroundStyle(YoseColor.shu).accessibilityHidden(true) }
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 4)
                .background(up ? YoseColor.kinBright.opacity(0.3) : (raised ? YoseColor.kinBright.opacity(0.12) : Color.clear))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(a) \(title) \(g) \(v)\(up ? "、ランクアップ" : "")")
            }
        }
    }

    /// 下の表の見出し：横＝経験点5種（今の持ち分・使った分は減って見える）
    private var matrixHeader: some View {
        HStack(spacing: 4) {
            Text("持ち分").font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.kinari)
                .frame(width: 58 + 4 + 28 + 4 + 36 + 4, alignment: .leading).padding(.leading, 6)
            ForEach(ExpCurrency.allCases, id: \.self) { c in
                VStack(spacing: 1) {
                    Text(Theme.currencyChar(c)).font(YoseFont.gothic(12, weight: .black)).foregroundStyle(YoseColor.kinari)
                        .frame(width: 22, height: 22).background(wa(c), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1)).accessibilityLabel("\(c)")
                    Text("\(Self.points(pv[currency: c]))").font(YoseFont.number(15, weight: .heavy)).foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 5).padding(.trailing, 4)
        .background(YoseColor.sumi)
    }

    /// 次の+1 に要る経験点（通貨ごと）と段数。nil＝届かない
    private func nextPlusOne(_ a: Ability) -> (steps: Int, cost: [(ExpCurrency, Int)])? {
        guard let n = session.costOfNextStep(a, in: pv) else { return nil }
        var s = pv
        for _ in 0..<n { GameEngine.pourStep(a, to: &s, config: cfg) }
        let cost = ExpCurrency.allCases.compactMap { c -> (ExpCurrency, Int)? in
            let d = pv[currency: c] - s[currency: c]
            return d > 0.0001 ? (c, ExpDisplay.cost(d, have: pv[currency: c])) : nil
        }
        return (n, cost)
    }

    /// 届かない時に見せる次の+1の値札（いまの残高を無視して1段の重さ×段数の目安）
    private func priceTag(_ a: Ability) -> [(ExpCurrency, Int)] {
        GameEngine.nextStepCost(a, state: pv, config: cfg).map { ($0.currency, ExpDisplay.cost($0.amount, have: pv[currency: $0.currency])) }
    }

    private func plusTap(_ a: Ability, steps: Int) {
        Haptics.confirm()
        flash = a
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            taps += Array(repeating: a, count: steps)
            bumped = a
        }
        Task { try? await Task.sleep(nanoseconds: 100_000_000); withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { bumped = nil } }
        Task { try? await Task.sleep(nanoseconds: 250_000_000); withAnimation(.easeOut(duration: 0.25)) { flash = nil } }
    }

    private func row(_ a: Ability) -> some View {
        let v = pv[a]
        let gained = Int(v.rounded()) - Int(base[a].rounded())
        let next = nextPlusOne(a)
        let tag = next?.cost ?? priceTag(a)
        let canTap = next != nil
        let canUndo = gained > 0
        let line = HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(a)").font(YoseFont.gothic(14, weight: .heavy)).foregroundStyle(YoseColor.sumi).lineLimit(1).minimumScaleFactor(0.6)
                Text("\(Int(v.rounded()))").font(YoseFont.number(16, weight: .black)).foregroundStyle(gained > 0 ? YoseColor.shu : YoseColor.haiSumi)
                    .lineLimit(1).contentTransition(.numericText()).scaleEffect(bumped == a ? 1.25 : 1, anchor: .leading)
            }
            .frame(width: 58, alignment: .leading)
            Button {
                Haptics.tick()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { taps.removeAll { $0 == a } }
            } label: {
                Image(systemName: "minus").font(.system(size: Font.mzScaled(13), weight: .black))
                    .foregroundStyle(canUndo ? YoseColor.sumi : YoseColor.disabledText)
                    .frame(width: 28, height: 40)
                    .background(Rectangle().fill(canUndo ? YoseColor.ki : YoseColor.ginNezu))
                    .overlay(Rectangle().stroke(canUndo ? YoseColor.sumi : YoseColor.haiSumi, lineWidth: canUndo ? 2 : 1))
            }
            .buttonStyle(PressableStyle(enabled: canUndo)).disabled(!canUndo)
            .accessibilityLabel("\(a)を元に戻す")
            Button { if let n = next?.steps { plusTap(a, steps: n) } } label: {
                Image(systemName: "plus").font(.system(size: Font.mzScaled(18), weight: .black))
                    .foregroundStyle(canTap ? YoseColor.kinari : YoseColor.disabledText)
                    .frame(width: 36, height: 40)
                    .background(Rectangle().fill(canTap ? YoseColor.shu : YoseColor.ginNezu))
                    .overlay { if !canTap { YoseDiagonalStripes().stroke(YoseColor.sumi.opacity(0.07), lineWidth: 4).clipped() } }
                    .overlay(Rectangle().stroke(canTap ? YoseColor.sumi : YoseColor.haiSumi, lineWidth: canTap ? 2 : 1))
                    .shadow(color: canTap ? YoseColor.sumi : .clear, radius: 0, y: 2)
            }
            .buttonStyle(PressableStyle(scale: 0.95, enabled: canTap)).disabled(!canTap)
            .accessibilityLabel("\(a)を上げる")
            .accessibilityHint(canTap ? "経験点を使って1上げる" : "経験点が足りない")
            ForEach(ExpCurrency.allCases, id: \.self) { c in
                let n = tag.first(where: { $0.0 == c })?.1
                let short = n != nil && n! > Self.points(pv[currency: c])
                Group {
                    if let n {
                        Text("\(n)").font(YoseFont.number(15, weight: .heavy))
                            .foregroundStyle(short ? YoseColor.disabledText : YoseColor.sumi)
                            .minimumScaleFactor(0.7).lineLimit(1)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(short ? YoseColor.ginNezu : wa(c).opacity(0.18))
                            .overlay(Rectangle().stroke(short ? YoseColor.haiSumi.opacity(0.5) : wa(c), lineWidth: 1))
                    } else {
                        Text("-").font(YoseFont.gothic(13, weight: .bold)).foregroundStyle(YoseColor.ginNezu)
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                }
            }
        }
        .padding(.leading, 6).padding(.trailing, 4).padding(.vertical, 4)
        .background(flash == a ? YoseColor.kinBright.opacity(0.35) : (gained > 0 ? YoseColor.kinBright.opacity(0.14) : YoseColor.washi))
        .overlay(alignment: .leading) { if gained > 0 { Rectangle().fill(YoseColor.shu).frame(width: 4) } }
        .overlay(Rectangle().stroke(YoseColor.sumi.opacity(0.35), lineWidth: 1))
        let caption = canTap ? [] : Self.shortageLines(a, state: pv, config: cfg)
        return VStack(alignment: .leading, spacing: 2) {
            line
            ForEach(caption, id: \.self) { l in
                Text(l).font(YoseFont.gothic(11, weight: .bold)).foregroundStyle(YoseColor.shu)
                    .lineLimit(2).minimumScaleFactor(0.8).padding(.horizontal, 8)
            }
        }
    }

    /// 次の+1の値札に対して、いま足りない粒（通貨, あと何点）。行の赤い印と同じ基準（1段の重さ ＞ いまの残高）。表示専用
    static func shortages(_ a: Ability, state s: GameState, config cfg: GameConfig) -> [(currency: ExpCurrency, short: Int)] {
        GameEngine.nextStepCost(a, state: s, config: cfg).compactMap { c in
            let price = ExpDisplay.cost(c.amount, have: s[currency: c.currency])
            let have = points(s[currency: c.currency])
            return price > have ? (c.currency, price - have) : nil
        }
    }

    /// 能力アップ画面での練習の呼び名（コマンド一覧と同じ言葉）
    static func practiceLabel(_ t: Training) -> String {
        switch t {
        case .ネタ作り: return "ネタを書く"
        case .ネタ見せ会: return "ネタ見せ会"
        case .ネタ合わせ: return "相方と合わせる"
        case .ランニング・サウナ: return "エントリーライブに出る"
        case .フリーライブ: return "舞台に立つ"
        case .喫茶店で書く: return "喫茶店で書く"
        case .ファミレスで書く: return "ファミレスで朝まで"
        case .作家の勉強会: return "大喜利ライブに出る"
        case .ボイトレ: return "カラオケボックスで声出し"
        }
    }

    /// その粒が貯まる練習（TrainingSpec の主効果から。主効果が無い粒は副効果から）。お金のかからない物を先に、最大2つ
    static func practices(for c: ExpCurrency, config cfg: GameConfig) -> [String] {
        func rank(_ pick: (TrainingSpec) -> (StatKey, Double)?) -> [(Training, TrainingSpec)] {
            cfg.trainings.compactMap { t, spec -> (Training, TrainingSpec)? in
                if let e = pick(spec), case .currency(let cc) = e.0, cc == c { return (t, spec) }
                return nil
            }
        }
        var list = rank { $0.main }
        if list.isEmpty { list = rank { $0.sub } }
        let sorted = list.sorted { ($0.1.cost, practiceLabel($0.0)) < ($1.1.cost, practiceLabel($1.0)) }
        return Array(sorted.prefix(2).map { practiceLabel($0.0) })
    }

    /// 押せない行の下に出す「何の粒があと何つ足りないか」と貯まる練習。足りない粒が無ければ nil
    static func shortageLines(_ a: Ability, state s: GameState, config cfg: GameConfig) -> [String] {
        let all = shortages(a, state: s, config: cfg).sorted { $0.short > $1.short }
        guard let sh = all.first else { return [] }
        // 読みにくいので不足の1つ目だけ。他にもあれば「ほか」で省略
        let more = all.count > 1 ? "　ほか" : ""
        return ["\(Theme.currencyChar(sh.currency))（\(sh.currency)）あと\(sh.short) → " + (practices(for: sh.currency, config: cfg).first ?? "") + more]
    }

    /// ＋が1つでも押せる状態か（週メインの「経験点が残ってる」を出す条件）
    static func anyPlusEnabled(_ session: GameSession, state s: GameState) -> Bool {
        Ability.allCases.contains { session.costOfNextStep($0, in: s) != nil }
    }

    /// 次の等級の名前と、そこまでの能力値（表示だけ）。最高等級なら nil
    static func nextGrade(_ v: Double, cap: Double) -> (name: String, remain: Int)? {
        guard let i = Theme.rankBounds.lastIndex(where: { v >= $0 }), i + 1 < Theme.rankBounds.count else { return nil }
        let hi = Theme.rankBounds[i + 1]
        return (Theme.rank(hi), max(1, Int((hi - v).rounded(.up))))
    }

    private var footer: some View {
        let active = !taps.isEmpty
        return HStack(spacing: 8) {
            Button { onClose() } label: { Text("戻る").lineLimit(1).minimumScaleFactor(0.85) }   // 反映せずに閉じる
                .buttonStyle(YoseButtonStyle(.secondary)).frame(width: 72, height: 48)
            Button { taps.removeAll() } label: { Text("リセット").lineLimit(1).minimumScaleFactor(0.6) }
                .buttonStyle(YoseButtonStyle(.secondary)).frame(width: 72, height: 48).disabled(!active)
            Button { taps = session.recommendedAllocation(); Haptics.tick() } label: { Text("おまかせ").lineLimit(1).minimumScaleFactor(0.6) }
                .buttonStyle(YoseButtonStyle(.secondary)).frame(width: 72, height: 48)
            Button { confirm() } label: { Text("確定").padding(.trailing, active ? 34 : 0) }
                .buttonStyle(YoseButtonStyle(.primary, badgeText: active ? "+\(taps.count)段階" : nil)).frame(maxWidth: .infinity, minHeight: 48)
        }
        .font(YoseFont.gothic(14, weight: .heavy))
        .frame(height: 52)
        .padding(.horizontal, YoseMetrics.screenMargin).padding(.top, 10).padding(.bottom, 12)
        .background(YoseColor.kinari)
        .overlay(alignment: .top) { Rectangle().fill(YoseColor.kiDark).frame(height: 1.5) }
    }

    /// 確定＝押した段をそのまま反映（RNG非消費）。何も押していなければ閉じるだけ
    private func confirm() {
        if !taps.isEmpty { _ = session.allocate(taps) }
        onClose()
    }
}

extension View {
    /// 罫線パネル: 生成りの面＋墨の罫＋朱の左帯（設定・ショップと同じ）
    func mzPanel() -> some View {
        self.background(Theme.kinariPanel)
            .overlay(alignment: .leading) { Rectangle().fill(Theme.verm).frame(width: 4) }
            .overlay(Rectangle().stroke(Theme.sumi, lineWidth: 1.5))
    }
}

/// ランクの六角エンブレム（縦長・上下に頂点）
struct HexEmblem: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: r.minX + w / 2, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + h * 0.25))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + h * 0.75))
        p.addLine(to: CGPoint(x: r.minX + w / 2, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + h * 0.75))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + h * 0.25))
        p.closeSubpath()
        return p
    }
}


/// 経験点の表示用変換（内部値×10の整数）。画面に経験点の数を出す所はすべてここを通す。表示専用＝GameCore・判定は不変。
/// 持ち分・増分は切り捨て、必要数は切り上げ（ただし内部で足りるなら持ち分の表示値を超えない）＝「14持ち・15必要なのに押せる」を出さない。
enum ExpDisplay {
    /// 持ち分・増分（合計は内部で足してから渡す＝掛けてから丸める）
    static func value(_ raw: Double) -> Int { Int(raw * 10 + 1e-6) }
    /// 必要数（切り上げ・最低1）。have＝その時の内部の持ち分。内部で足りる(amount<=have)なら持ち分の表示値以下に収める
    static func cost(_ amount: Double, have: Double) -> Int {
        let up = max(1, Int((amount * 10 - 1e-6).rounded(.up)))
        return amount <= have + 1e-9 ? min(up, max(1, value(have))) : up
    }
}
