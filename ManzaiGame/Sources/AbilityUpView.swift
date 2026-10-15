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

    /// 経験点の表示値（内部×10・切り捨て）
    static func points(_ v: Double) -> Int { Int(v * 10 + 1e-6) }

    /// 列の固定幅（Gemini r2）：能力名70・＋50・経験点5列は各42・列間6。現在の経験点の行と下の費用が同じ中心線に乗る
    private let nameW: CGFloat = 66
    private let plusW: CGFloat = 74   // ［−］34＋隙間2＋［＋］38 で固定（幅は絶対に変えない・Gemini r6）
    private let colW: CGFloat = 38
    private let minusW: CGFloat = 34
    private let colGap: CGFloat = 6
    @State private var pulse = false
    @State private var bumped: Ability? = nil

    /// 和の五色（閃・語・間・存・胆）
    private func wa(_ c: ExpCurrency) -> Color {
        switch c {
        case .閃き: return Color(hex: 0xD4A017)
        case .語彙: return Color(hex: 0x1F5E5B)
        case .間合い: return Color(hex: 0x4A2E6D)
        case .存在感: return Color(hex: 0xA63A2A)
        case .胆力: return Color(hex: 0x2A4B7C)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 10) {
                    rankStrip
                    jitsuryokuCard
                    expRow
                    ForEach(Ability.allCases, id: \.self) { row($0) }
                }
                .padding(.horizontal, 12).padding(.bottom, 16)
            }
            footer
        }
        .background(Theme.kinari.ignoresSafeArea())
        #if DEBUG
        .task { if ProcessInfo.processInfo.environment["MZ_TAPS"] != nil { try? await Task.sleep(nanoseconds: 1_500_000_000); taps = [.センス, .発想, .センス] } }   // 目視用: ＋を押した後の状態
        #endif
    }

    /// 臙脂＋金の帯（週のメイン・設定と同じ色）。
    private var header: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Theme.gold).frame(height: 1).frame(maxWidth: .infinity)
            Text("能力アップ").font(.maru(20, weight: .black)).foregroundStyle(Theme.gold).fixedSize()
                .shadow(color: .black.opacity(0.5), radius: 0, x: 1, y: 1)
            Rectangle().fill(Theme.gold).frame(height: 1).frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Theme.curtain.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.gold).frame(height: 2) }
        .padding(.bottom, 10)
    }

    /// いちばん上：能力ごとのランクと次のランクまでのゲージ
    private var rankStrip: some View {
        HStack(spacing: 6) {
            ForEach(Ability.allCases, id: \.self) { a in
                let v = pv[a]
                let grade = Theme.rank(v)
                let cap = a == .メンタル ? cfg.mentalCap : cfg.abilityCap
                VStack(spacing: 4) {
                    Text("\(a)").font(.maru(11, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.8)
                    Text(grade).font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(Self.emblemText(grade))
                        .shadow(color: .black.opacity(Self.emblemText(grade) == .white ? 0.35 : 0), radius: 0, x: 1, y: 1)
                        .frame(width: 42, height: 46)
                        .background(HexEmblem().fill(Self.emblemFill(grade)))
                        .overlay(HexEmblem().fill(LinearGradient(colors: [.white.opacity(0.25), .clear], startPoint: .top, endPoint: .center)))   // 金属の光沢
                        .overlay(HexEmblem().stroke(Self.emblemRim(grade), lineWidth: 2))
                        .shadow(color: .black.opacity(0.35), radius: 0, y: 2)
                    GeometryReader { g in
                        let prog = Theme.rankProgress(v, cap: cap)
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(hex: 0x2B2B2B))
                            Capsule().fill(prog >= 0.7 ? Theme.gold : Theme.abilityColor(a))
                                .frame(width: g.size.width * prog)
                                .shadow(color: prog >= 0.7 ? Theme.gold.opacity(0.9) : .clear, radius: 3)   // 次のランクが近いほど金に発光
                        }
                    }
                    .frame(height: 7)
                    if let n = Self.nextGrade(v, cap: cap) {
                        Text("\(n.name)まで\(n.remain)").font(.maru(10.5, weight: .bold)).foregroundStyle(Theme.inkSub).lineLimit(1).minimumScaleFactor(0.8)
                    } else {
                        Text("最高").font(.maru(10.5, weight: .bold)).foregroundStyle(Theme.inkSub)
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 8).padding(.horizontal, 3)
                .background(Theme.kinariPanel).overlay(Rectangle().stroke(Theme.sumi, lineWidth: 1.5))   // 朱の縦線は削除
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

    /// 現在の経験点（5種）＝見出し＋5列。下の行の費用列と同じ幅でそろえる
    private var expRow: some View {
        HStack(spacing: colGap) {
            Text("所持\nポイント").font(.maru(12, weight: .heavy)).foregroundStyle(Color(hex: 0x4A2E1A))
                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
                .frame(width: nameW + colGap + plusW + 6).frame(maxHeight: .infinity)
                .background(Color(hex: 0xE0C9A6))   // 軽い木札（重い臙脂の塊をやめる）
                .overlay(alignment: .trailing) { Rectangle().fill(Theme.sumi.opacity(0.35)).frame(width: 1) }
            ForEach(ExpCurrency.allCases, id: \.self) { c in
                VStack(spacing: 3) {
                    Text(Theme.currencyChar(c)).font(.maru(16, weight: .black)).foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(wa(c), in: Circle())
                        .overlay(Circle().stroke(Theme.sumi, lineWidth: 1.5))
                        .accessibilityLabel("\(c)")
                    Text("\(Self.points(pv[currency: c]))").font(.maru(18, weight: .heavy)).monospacedDigit()
                        .foregroundStyle(Theme.ink).minimumScaleFactor(0.7).lineLimit(1)
                    let spent = Self.points(base[currency: c]) - Self.points(pv[currency: c])
                    Text(spent > 0 ? "(-\(spent))" : " ").font(.maru(10, weight: .heavy)).monospacedDigit()
                        .foregroundStyle(Theme.vermD).minimumScaleFactor(0.7).lineLimit(1)
                }
                .frame(width: colW).padding(.vertical, 4)
            }
        }
        .padding(.trailing, 6)
        .frame(height: 74)
        .background(Theme.kinariPanel)
        .overlay(Rectangle().stroke(Theme.sumi, lineWidth: 1.5))
    }

    private var jitsuryokuCard: some View {
        let before = Int(GameEngine.jitsuryoku(base, config: cfg).rounded())
        let after = Int(GameEngine.jitsuryoku(pv, config: cfg).rounded())
        let em = Color(hex: 0x2ECC71)
        return HStack(spacing: 8) {
            Text("実力").font(.maru(14, weight: .bold)).foregroundStyle(Theme.gold)
            Text("\(before)").font(.maru(24, weight: .heavy)).monospacedDigit().foregroundStyle(.white)
            if after != before {
                // 確定前に伸びが見える：(+3) → 45
                Text("(+\(after - before))").font(.maru(16, weight: .heavy)).monospacedDigit().foregroundStyle(em)
                    .transition(.scale.combined(with: .opacity))
                Image(systemName: "arrow.right").font(.system(size: 13, weight: .bold)).foregroundStyle(em)
                Text("\(after)").font(.maru(24, weight: .heavy)).monospacedDigit().foregroundStyle(em)
                    .contentTransition(.numericText())
                    .transition(.scale.combined(with: .opacity))
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Color(hex: 0x1C1412))   // 黒漆（画面の臙脂に馴染む）
        .overlay(alignment: .top) { Rectangle().fill(Color(hex: 0xD4AF37).opacity(0.6)).frame(height: 0.5) }
        .overlay(alignment: .bottom) { Rectangle().fill(Color(hex: 0xD4AF37).opacity(0.6)).frame(height: 0.5) }   // 極細の金線
        .animation(.easeOut(duration: 0.25), value: after)
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
                Text("\(a)").font(.maru(15, weight: .heavy)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: 3) {
                    Text("\(Int(v.rounded()))").font(.maru(14, weight: .heavy)).monospacedDigit().foregroundStyle(Theme.inkSub)
                        .contentTransition(.numericText())
                        .scaleEffect(bumped == a ? 1.3 : 1, anchor: .leading)
                    if gained > 0 {
                        Text("+\(gained)").font(.maru(13, weight: .heavy)).foregroundStyle(Theme.moneyDeep)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .frame(width: nameW, alignment: .leading)
            plusMark(canTap: canTap)
            ForEach(ExpCurrency.allCases, id: \.self) { c in
                let n = tag.first(where: { $0.0 == c })?.1
                let have = Self.points(pv[currency: c])
                Text(n.map { "\($0)" } ?? "-")
                    .font(n == nil ? .maru(14, weight: .regular) : .maru(18, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(n == nil ? Color(hex: 0xA0A0A0) : (n! > have ? Theme.vermD : Theme.ink))
                    .minimumScaleFactor(0.7).lineLimit(1)
                    .frame(width: colW, height: 40)
                    .background(RoundedRectangle(cornerRadius: 4).fill(n == nil ? Color.black.opacity(0.03) : (n! > have ? Theme.verm.opacity(0.12) : Color(hex: 0xF5EFE6))))
            }
        }
        .padding(.leading, 6).padding(.trailing, 6).padding(.vertical, 8)
        .background(flash == a ? Theme.gold : Theme.kinariPanel)
        .overlay(Rectangle().stroke(Theme.sumi, lineWidth: 1.5))
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
        } label: { content }
        .buttonStyle(PressableStyle(scale: 0.98, enabled: canTap))
        .disabled(!canTap)
        return main.overlay(alignment: .leading) {
            // ［−］：常に同じ場所に出す（振った分をまるごと戻す）。振っていない時は灰色で押せない＝幅も位置も動かない
            let canUndo = gained > 0
            Button {
                Haptics.tick()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { taps.removeAll { $0 == a } }
            } label: {
                Image(systemName: "minus").font(.system(size: 16, weight: .black))
                    .foregroundStyle(canUndo ? .white : Color(hex: 0x9E988D))
                    .frame(width: minusW, height: 46)
                    .background(Rectangle().fill(canUndo ? Color(hex: 0x606060) : Color(hex: 0xE5E0D8)))
                    .overlay(Rectangle().stroke(canUndo ? Theme.sumi : Color(hex: 0xBDB7AA), lineWidth: 1.5))
            }
            .buttonStyle(PressableStyle(enabled: canUndo))
            .disabled(!canUndo)
            .padding(.leading, 6 + nameW + colGap).padding(.bottom, 2)
        }
    }

    /// ＋の印（行全体がボタン。押せる＝朱の立体／足りない＝灰で形は残す）
    private func plusMark(canTap: Bool) -> some View {
        Image(systemName: "plus").font(.system(size: 20, weight: .black))
            .foregroundStyle(canTap ? .white : Color(hex: 0x9E988D))
            .frame(width: plusW - minusW - 2, height: 46)
            .background(Rectangle().fill(canTap ? Color(hex: 0xBD3C28) : Color(hex: 0xD0CBC0)))
            .overlay(Rectangle().stroke(canTap ? Theme.sumi : Color(hex: 0xBDB7AA), lineWidth: 1.5))
            .shadow(color: canTap ? Color(hex: 0x7A1F13) : .clear, radius: 0, y: 2)
            .frame(width: plusW, height: 46, alignment: .trailing)   // 左の minusW＋隙間は［−］の場所（常に固定）
            .padding(.bottom, 2)
    }

    /// 次の等級の名前と、そこまでの能力値（表示だけ）。最高等級なら nil
    static func nextGrade(_ v: Double, cap: Double) -> (name: String, remain: Int)? {
        guard let i = Theme.rankBounds.lastIndex(where: { v >= $0 }), i + 1 < Theme.rankBounds.count else { return nil }
        let hi = Theme.rankBounds[i + 1]
        return (Theme.rank(hi), max(1, Int((hi - v).rounded(.up))))
    }

    private var footer: some View {
        let active = !taps.isEmpty
        return GeometryReader { geo in
            let unit = (geo.size.width - 24) / 5.2   // 戻る:リセット:おまかせ:確定 ＝ 1:1:1.2:2
            HStack(spacing: 8) {
                subBtn("戻る", w: unit, fg: Theme.ink, bg: Color(hex: 0xE8E2D2), stroke: Theme.sumi.opacity(0.6), enabled: true) { onClose() }   // 反映せずに閉じる
                subBtn("リセット", w: unit, fg: active ? Theme.ink : Theme.inkFaint, bg: Color(hex: 0xE8E2D2), stroke: Theme.sumi.opacity(0.6), enabled: active) { taps.removeAll() }
                    .opacity(active ? 1 : 0.4)
                subBtn("おまかせ", w: unit * 1.2, fg: Theme.verm, bg: Color(hex: 0xF5F0E1), stroke: Theme.verm, enabled: true) {
                    taps = session.recommendedAllocation(); Haptics.tick()
                }
                // 主役：確定（金枠は同じ矩形の内側・光は小さく隣へ漏らさない）
                Button { confirm() } label: {
                    Text("確定").font(.maru(20, weight: .heavy)).foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                        .frame(width: unit * 2, height: 46)
                        .background(LinearGradient(colors: [Color(hex: 0xB83A2A), Color(hex: 0x8A1F13)], startPoint: .top, endPoint: .bottom))
                        .overlay(Rectangle().strokeBorder(Color(hex: 0xE5C158), lineWidth: 1.5))
                        .overlay(Rectangle().strokeBorder(Color(hex: 0xFFD700), lineWidth: 2).opacity(active ? (pulse ? 1 : 0.2) : 0))   // 上げている間だけ金枠が呼吸
                        .shadow(color: Color(hex: 0xFFD700).opacity(active ? (pulse ? 0.5 : 0) : 0), radius: 3)
                }
                .buttonStyle(PressableStyle())
            }
        }
        .frame(height: 46)
        .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 12)
        .background(Theme.kinari)
        .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true } }
    }

    private func subBtn(_ t: String, w: CGFloat, fg: Color, bg: Color, stroke: Color, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.maru(14, weight: .heavy)).foregroundStyle(fg)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(width: w, height: 46)
                .background(bg).overlay(Rectangle().stroke(stroke, lineWidth: 1))
        }
        .buttonStyle(PressableStyle(enabled: enabled)).disabled(!enabled)
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
