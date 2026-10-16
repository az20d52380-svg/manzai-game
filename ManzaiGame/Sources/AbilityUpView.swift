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
    /// 「交換して上げる」の確認待ちの能力（押すと内容を出して確定）
    @State private var pendingExchange: Ability?

    private var cfg: GameConfig { session.config }
    private var base: GameState { session.state }
    private var pv: GameState { session.previewAllocation(taps) }

    /// 経験点の表示値（内部×10・切り捨て）
    static func points(_ v: Double) -> Int { Int(v * 10 + 1e-6) }

    /// 列の固定幅（Gemini r2）：能力名70・＋50・経験点5列は各42・列間6。現在の経験点の行と下の費用が同じ中心線に乗る
    private let nameW: CGFloat = 66
    private let plusW: CGFloat = 74   // ［−］34＋隙間2＋［＋］38 で固定（幅は絶対に変えない・Gemini r6）
    private let colW: CGFloat = 38
    private let minusW: CGFloat = 34
    private let colGap: CGFloat = 6
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

    private var exchangeAlertText: String {
        guard let a = pendingExchange, let q = GameEngine.exchangeQuote(a, state: pv, config: cfg) else { return "" }
        let fmt: ([ExpCurrency: Double]) -> String = { m in
            ExpCurrency.allCases.compactMap { c in
                guard let v = m[c], Self.points(v) > 0 else { return nil }
                return "\(c)\(Self.points(v))"
            }.joined(separator: "と")
        }
        return "\(fmt(q.paid))を\(fmt(q.got))に替えて、\(a)を1段上げる"
    }

    var body: some View {
        VStack(spacing: 0) {
            YoseHeaderBar(title: "能力アップ")
                .overlay(alignment: .trailing) {
                    HintMarkButton { hint = Self.hintSpec }.padding(.trailing, 6).padding(.top, 20)
                }
            ScrollView {
                VStack(spacing: 10) {
                    rankStrip
                    summaryBox
                    exchangeNote
                    ForEach(Ability.allCases, id: \.self) { row($0) }
                }
                .padding(.horizontal, YoseMetrics.screenMargin).padding(.top, 12).padding(.bottom, 16)
            }
            footer
        }
        .background(YoseColor.kinari.ignoresSafeArea())
        .alert("交換して上げる", isPresented: Binding(get: { pendingExchange != nil }, set: { if !$0 { pendingExchange = nil } })) {
            Button("交換する") {
                if let a = pendingExchange { Haptics.tick(); taps.append(a) }   // 再生は pourTap＝確定・もどすと同じ道
                pendingExchange = nil
            }
            Button("やめる", role: .cancel) { pendingExchange = nil }
        } message: { Text(exchangeAlertText) }
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

    static var hintSpec: HintSpec {
        HintSpec(key: "abilityUp", title: "能力アップ", rows: [
            .init(term: "経験点", text: "練習やネタ書きでたまる。閃・語・間・存・胆の数字が、いま持っている分。"),
            .init(term: "＋", text: "能力の「＋」で経験点を使うと、その能力が上がり、実力が伸びる。"),
            .init(term: "おまかせ", text: "迷ったら「おまかせ」。自動で割り振る。「確定」を押すまで決まらない。"),
            .init(term: "ランク", text: "G、F……と上がっていく。「Fまで5」は、Fに上がるまでの残り。"),
        ])
    }

    /// いちばん上：能力ごとのランクと次のランクまでのゲージ
    private var rankStrip: some View {
        HStack(spacing: 6) {
            ForEach(Ability.allCases, id: \.self) { a in
                let v = pv[a]
                let grade = Theme.rank(v)
                let cap = a == .メンタル ? cfg.mentalCap : cfg.abilityCap
                VStack(spacing: 4) {
                    Text("\(a)").font(YoseFont.gothic(11, weight: .heavy)).foregroundStyle(YoseColor.sumi).lineLimit(1).minimumScaleFactor(0.8)
                    Text(grade).font(YoseFont.number(24, weight: .heavy)).foregroundStyle(Self.emblemText(grade))
                        .frame(width: 42, height: 46)
                        .background(HexEmblem().fill(Self.emblemFill(grade)))
                        .overlay(HexEmblem().stroke(Self.emblemRim(grade), lineWidth: 2))
                    let prog = Theme.rankProgress(v, cap: cap)
                    YoseGauge(value: prog, total: 1, fill: prog >= 0.7 ? YoseColor.kinBright : YoseColor.enji, height: 8, showTicks: false)
                    if let n = Self.nextGrade(v, cap: cap) {
                        Text("\(n.name)まで\(n.remain)").font(YoseFont.gothic(10.5, weight: .bold)).foregroundStyle(YoseColor.haiSumi).lineLimit(1).minimumScaleFactor(0.8)
                    } else {
                        Text("最高").font(YoseFont.gothic(10.5, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 8).padding(.horizontal, 3)
                .yoseKifuda()
            }
        }
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

    /// 統合ヘッダー箱（型B）：左＝実力（振った後の伸びも）／右＝所持している経験点5色。下の行の費用列と同じ幅・中心線でそろえる
    private var summaryBox: some View {
        let before = Int(GameEngine.jitsuryoku(base, config: cfg).rounded())
        let after = Int(GameEngine.jitsuryoku(pv, config: cfg).rounded())
        return HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("実力").font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.enji)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(YoseColor.enji.opacity(0.12))
                    .overlay(Rectangle().stroke(YoseColor.enji, lineWidth: 1))
                if after != before {
                    // 確定前に伸びが見える：42 → 45
                    HStack(spacing: 3) {
                        Text("\(before)").font(YoseFont.number(16, weight: .heavy)).foregroundStyle(YoseColor.haiSumi)
                        Image(systemName: "arrow.right").font(.system(size: Font.mzScaled(11), weight: .black)).foregroundStyle(YoseColor.shu).accessibilityHidden(true)
                        Text("\(after)").font(YoseFont.number(26, weight: .black)).foregroundStyle(YoseColor.shu)
                            .contentTransition(.numericText())
                    }
                    Text("+\(after - before)").font(YoseFont.number(12, weight: .heavy)).foregroundStyle(YoseColor.shu)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text("\(before)").font(YoseFont.numHero).foregroundStyle(YoseColor.sumi)
                }
            }
            .frame(width: nameW + colGap + plusW + 6).frame(maxHeight: .infinity)
            .background(YoseColor.ki)
            .overlay(alignment: .trailing) { Rectangle().fill(YoseColor.sumi).frame(width: 2) }
            HStack(spacing: colGap) {
                ForEach(ExpCurrency.allCases, id: \.self) { c in
                    let spent = Self.points(base[currency: c]) - Self.points(pv[currency: c])
                    VStack(spacing: 2) {
                        Text(Theme.currencyChar(c)).font(YoseFont.gothic(15, weight: .black)).foregroundStyle(YoseColor.kinari)
                            .frame(width: 26, height: 26)
                            .background(wa(c), in: Circle())
                            .overlay(Circle().stroke(YoseColor.sumi, lineWidth: 1.5))
                            .accessibilityLabel("\(c)")
                        Text("\(Self.points(pv[currency: c]))").font(YoseFont.number(17, weight: .heavy))
                            .foregroundStyle(YoseColor.sumi).minimumScaleFactor(0.7).lineLimit(1)
                        Text(spent > 0 ? "-\(spent)" : " ").font(YoseFont.number(10, weight: .heavy))
                            .foregroundStyle(YoseColor.shu).minimumScaleFactor(0.7).lineLimit(1)
                    }
                    .frame(width: colW)
                }
            }
            .padding(.trailing, 6).padding(.leading, 6)
            .frame(maxHeight: .infinity)
        }
        .frame(height: 78)
        .background(YoseColor.washi)
        .clipShape(Rectangle())
        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
        .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))
        .animation(.easeOut(duration: 0.25), value: after)
    }

    /// 交換が起きた時の一言（試作・おまかせ列だけで起きる）。例「余った間合い14を、胆力7に替えた」
    static func exchangeLine(_ recs: [GameEngine.ExchangeRecord]) -> String? {
        guard !recs.isEmpty else { return nil }
        var paid: [ExpCurrency: Double] = [:], got: [ExpCurrency: Double] = [:]
        for r in recs {
            for (c, v) in r.paid { paid[c, default: 0] += v }
            for (c, v) in r.got { got[c, default: 0] += v }
        }
        let fmt: ([ExpCurrency: Double]) -> String = { m in
            ExpCurrency.allCases.compactMap { c in
                guard let v = m[c], points(v) > 0 else { return nil }
                return "\(c)\(points(v))"
            }.joined(separator: "と")
        }
        let p = fmt(paid), g = fmt(got)
        guard !p.isEmpty, !g.isEmpty else { return nil }
        return "余った\(p)を、\(g)に替えた"
    }

    @ViewBuilder private var exchangeNote: some View {
        if let line = Self.exchangeLine(session.exchangesIn(taps)) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.arrow.right").font(.system(size: 13, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
                VStack(alignment: .leading, spacing: 2) {
                    Text(line).font(YoseFont.gothic(13, weight: .bold)).foregroundStyle(YoseColor.sumi)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Text("押せる＋が無い時だけ、余り\(Int(cfg.exchangeRate))つを足りない1つに替える").font(YoseFont.gothic(10.5)).foregroundStyle(YoseColor.haiSumi)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(YoseColor.kinari)
        }
    }

    /// 次の+1 に要る経験点（通貨ごと）と段数。nil＝届かない
    private func nextPlusOne(_ a: Ability) -> (steps: Int, cost: [(ExpCurrency, Int)])? {
        guard let n = session.costOfNextStep(a, in: pv) else { return nil }
        var s = pv
        for _ in 0..<n { GameEngine.pourStep(a, to: &s, config: cfg) }
        let cost = ExpCurrency.allCases.compactMap { c -> (ExpCurrency, Int)? in
            let d = Self.points(pv[currency: c]) - Self.points(s[currency: c])
            return d > 0 ? (c, d) : nil
        }
        return (n, cost)
    }

    /// 届かない時に見せる次の+1の値札（いまの残高を無視して1段の重さ×段数の目安）
    private func priceTag(_ a: Ability) -> [(ExpCurrency, Int)] {
        GameEngine.nextStepCost(a, state: pv, config: cfg).map { ($0.currency, max(1, Self.points(pv[currency: $0.currency]) - Self.points(pv[currency: $0.currency] - $0.amount))) }
    }

    private func row(_ a: Ability) -> some View {
        let v = pv[a]
        let gained = Int(v.rounded()) - Int(base[a].rounded())
        let next = nextPlusOne(a)
        let tag = next?.cost ?? priceTag(a)
        let canTap = next != nil
        let steps = next?.steps
        let content = HStack(spacing: colGap) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(a)").font(YoseFont.gothic(15, weight: .heavy)).foregroundStyle(YoseColor.sumi).lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: 1) {
                    if gained > 0 {
                        Text("\(Int(base[a].rounded()))→").font(YoseFont.number(11, weight: .bold)).foregroundStyle(YoseColor.haiSumi).lineLimit(1).fixedSize()
                    }
                    Text("\(Int(v.rounded()))").font(YoseFont.number(19, weight: .black)).foregroundStyle(gained > 0 ? YoseColor.shu : YoseColor.sumi).lineLimit(1).fixedSize()
                        .contentTransition(.numericText())
                        .scaleEffect(bumped == a ? 1.3 : 1, anchor: .leading)
                    if gained > 0 {
                        Text("+\(gained)").font(YoseFont.number(11, weight: .heavy)).foregroundStyle(YoseColor.shu).lineLimit(1).fixedSize()
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                // 現在値のミニバー（枠＋朱の塗り・長さは全能力共通の物差し）
                Rectangle().fill(YoseColor.ginNezu).frame(width: 48, height: 4)
                    .overlay(alignment: .leading) { Rectangle().fill(YoseColor.shu).frame(width: 48 * min(1, max(0, v / 120)), height: 4) }
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1))
            }
            .frame(width: nameW, alignment: .leading)
            plusMark(canTap: canTap)
            ForEach(ExpCurrency.allCases, id: \.self) { c in
                let n = tag.first(where: { $0.0 == c })?.1
                let have = Self.points(pv[currency: c])
                let short = n != nil && n! > have
                Group {
                    if let n {
                        Text("\(n)").font(YoseFont.number(16, weight: .heavy)).foregroundStyle(short ? YoseColor.shu : YoseColor.sumi)
                            .minimumScaleFactor(0.7).lineLimit(1)
                            .frame(width: colW, height: 40)
                            .background(short ? YoseColor.shu.opacity(0.18) : wa(c).opacity(0.12))
                            .overlay(Rectangle().stroke(short ? YoseColor.shu : wa(c), lineWidth: short ? 2 : 1))
                            .overlay(alignment: .topTrailing) { if short { Circle().fill(YoseColor.shu).frame(width: 7, height: 7).offset(x: -2, y: 2) } }   // 足りない粒の目印
                    } else {
                        Text("・").font(YoseFont.gothic(14, weight: .bold)).foregroundStyle(YoseColor.ginNezu)   // 消費しない列は箱を置かない
                            .frame(width: colW, height: 40)
                    }
                }
            }
        }
        .padding(.leading, 6).padding(.trailing, 6).padding(.vertical, 8)
        .background(flash == a ? YoseColor.kinBright.opacity(0.35) : (gained > 0 ? YoseColor.kinBright.opacity(0.14) : Color.clear))
        .overlay(alignment: .leading) { if gained > 0 { Rectangle().fill(YoseColor.shu).frame(width: 4) } }   // 変更中の行
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: gained)
        .contentShape(Rectangle())
        let main = Button {
            guard let n = steps else { return }
            Haptics.confirm()   // 中程度の衝撃
            flash = a
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                taps += Array(repeating: a, count: n)
                bumped = a    // 能力値が一瞬ふくらんで戻る
            }
            Task { try? await Task.sleep(nanoseconds: 100_000_000); withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { bumped = nil } }
            Task { try? await Task.sleep(nanoseconds: 250_000_000); withAnimation(.easeOut(duration: 0.25)) { flash = nil } }
        } label: { content.yoseHarigami() }
        .buttonStyle(PressableStyle(scale: 0.98, enabled: canTap))
        .disabled(!canTap)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(a)、いま\(Int(v.rounded()))\(gained > 0 ? "、\(gained)上げる予定" : "")")
        .accessibilityHint(canTap ? "押すと能力を上げる" : "粒が足りない")
        let caption = canTap ? [] : Self.shortageLines(a, state: pv, config: cfg)
        let quote = GameEngine.exchangeQuote(a, state: pv, config: cfg)
        return VStack(alignment: .leading, spacing: 2) { main.overlay(alignment: .leading) {
            // ［−］：常に同じ場所に出す（振った分をまるごと戻す）。振っていない時は灰色で押せない＝幅も位置も動かない
            let canUndo = gained > 0
            Button {
                Haptics.tick()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { taps.removeAll { $0 == a } }
            } label: {
                Image(systemName: "minus").font(.system(size: Font.mzScaled(16), weight: .black))
                    .foregroundStyle(canUndo ? YoseColor.sumi : YoseColor.disabledText)
                    .frame(width: minusW, height: 46)
                    .background(Rectangle().fill(canUndo ? YoseColor.ki : YoseColor.ginNezu))
                    .overlay { if !canUndo { YoseDiagonalStripes().stroke(YoseColor.sumi.opacity(0.07), lineWidth: 4).clipped() } }
                    .overlay(Rectangle().stroke(canUndo ? YoseColor.sumi : YoseColor.haiSumi, lineWidth: canUndo ? 2 : 1.5))
                    .shadow(color: canUndo ? YoseColor.sumi : .clear, radius: 0, y: 2)
            }
            .buttonStyle(PressableStyle(enabled: canUndo))
            .disabled(!canUndo)
            .accessibilityLabel("\(a)を元に戻す")
            .padding(.leading, 6 + nameW + colGap).padding(.bottom, 2)
        }
            ForEach(caption, id: \.self) { line in
                Text(line).font(YoseFont.gothic(11, weight: .bold)).foregroundStyle(YoseColor.shu)
                    .lineLimit(2).minimumScaleFactor(0.8).padding(.horizontal, 8)
            }
            if quote != nil {
                Button { pendingExchange = a } label: {
                    Label("交換して上げる", systemImage: "arrow.left.arrow.right")
                        .font(YoseFont.gothic(11.5, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .overlay(Capsule().stroke(YoseColor.shu, lineWidth: 1.4))
                }
                .buttonStyle(PressableStyle())
                .padding(.horizontal, 8)
                .accessibilityIdentifier("exchange_\(a)")
            }
        }
    }

    /// ＋の印（行全体がボタン。押せる＝朱の立体／足りない＝灰で形は残す）
    private func plusMark(canTap: Bool) -> some View {
        Image(systemName: "plus").font(.system(size: Font.mzScaled(20), weight: .black))
            .foregroundStyle(canTap ? YoseColor.kinari : YoseColor.disabledText)
            .frame(width: plusW - minusW - 2, height: 46)
            .background(Rectangle().fill(canTap ? YoseColor.shu : YoseColor.ginNezu))
            .overlay { if !canTap { YoseDiagonalStripes().stroke(YoseColor.sumi.opacity(0.07), lineWidth: 4).clipped() } }
            .overlay(Rectangle().stroke(canTap ? YoseColor.sumi : YoseColor.haiSumi, lineWidth: canTap ? 2 : 1.5))
            .shadow(color: canTap ? YoseColor.sumi : .clear, radius: 0, y: 2)
            .frame(width: plusW, height: 46, alignment: .trailing)   // 左の minusW＋隙間は［−］の場所（常に固定）
            .padding(.bottom, 2)
    }

    /// 次の+1の値札に対して、いま足りない粒（通貨, あと何点）。行の赤い印と同じ基準（1段の重さ ＞ いまの残高）。表示専用
    static func shortages(_ a: Ability, state s: GameState, config cfg: GameConfig) -> [(currency: ExpCurrency, short: Int)] {
        GameEngine.nextStepCost(a, state: s, config: cfg).compactMap { c in
            let price = max(1, points(s[currency: c.currency]) - points(s[currency: c.currency] - c.amount))
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
        shortages(a, state: s, config: cfg).sorted { $0.short > $1.short }.prefix(2).map { sh in
            "\(Theme.currencyChar(sh.currency))（\(sh.currency)）あと\(sh.short) → " + practices(for: sh.currency, config: cfg).joined(separator: "・")
        }
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
