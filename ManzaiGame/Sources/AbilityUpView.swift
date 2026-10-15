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
    private let nameW: CGFloat = 70
    private let plusW: CGFloat = 50
    private let colW: CGFloat = 42
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
                    Text(grade).font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 0, x: 1, y: 1)
                        .frame(width: 42, height: 46)
                        .background(HexEmblem().fill(Self.emblemColor(grade)))
                        .overlay(HexEmblem().stroke(Theme.sumi, lineWidth: 2))
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
                .mzPanel()
            }
        }
    }

    /// ランクの色（S金/A赤/B橙/C緑/D以下は藍灰）
    static func emblemColor(_ g: String) -> Color {
        switch g {
        case "S": return Color(hex: 0xC1A550)
        case "A": return Color(hex: 0xBD3C28)
        case "B": return Color(hex: 0xD97724)
        case "C": return Color(hex: 0x2E583C)
        default: return Color(hex: 0x5A6265)
        }
    }

    /// 現在の経験点（5種）＝見出し＋5列。下の行の費用列と同じ幅でそろえる
    private var expRow: some View {
        HStack(spacing: colGap) {
            Text("現在の\n経験点").font(.maru(13, weight: .heavy)).foregroundStyle(Theme.gold)
                .multilineTextAlignment(.center)
                .frame(width: nameW + colGap + plusW + 6).frame(maxHeight: .infinity)
                .background(Theme.curtain)
            ForEach(ExpCurrency.allCases, id: \.self) { c in
                VStack(spacing: 3) {
                    Text(Theme.currencyChar(c)).font(.maru(16, weight: .black)).foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(wa(c), in: Circle())
                        .overlay(Circle().stroke(Theme.sumi, lineWidth: 1.5))
                        .accessibilityLabel("\(c)")
                    Text("\(Self.points(pv[currency: c]))").font(.maru(18, weight: .heavy)).monospacedDigit()
                        .foregroundStyle(Theme.ink).minimumScaleFactor(0.7).lineLimit(1)
                }
                .frame(width: colW).padding(.vertical, 8)
            }
        }
        .padding(.trailing, 6)
        .frame(height: 64)
        .background(Theme.kinariPanel)
        .overlay(Rectangle().stroke(Theme.sumi, lineWidth: 1.5))
    }

    private var jitsuryokuCard: some View {
        let before = Int(GameEngine.jitsuryoku(base, config: cfg).rounded())
        let after = Int(GameEngine.jitsuryoku(pv, config: cfg).rounded())
        return HStack(spacing: 8) {
            Text("実力").font(.maru(14, weight: .bold)).foregroundStyle(Theme.gold)
            Text("\(before)").font(.maru(24, weight: .heavy)).monospacedDigit().foregroundStyle(.white)
            if after != before {
                // 確定前に伸びが見える：(+3) → 45
                Text("(+\(after - before))").font(.maru(16, weight: .heavy)).monospacedDigit().foregroundStyle(Color(hex: 0x38A169))
                Image(systemName: "arrow.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Color(hex: 0x38A169))
                Text("\(after)").font(.maru(24, weight: .heavy)).monospacedDigit().foregroundStyle(Color(hex: 0x38A169))
                    .contentTransition(.numericText())
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Color(hex: 0x2B2B2B))
        .overlay(Rectangle().stroke(Theme.gold, lineWidth: 1.5))
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
                Text(n.map { "\($0)" } ?? "0")
                    .font(.maru(18, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(n == nil ? Theme.inkFaint.opacity(0.7) : (n! > have ? Theme.vermD : Theme.ink))
                    .minimumScaleFactor(0.7).lineLimit(1)
                    .frame(width: colW, height: 40)
                    .background(n == nil ? Theme.card2.opacity(0.5) : (n! > have ? Theme.verm.opacity(0.12) : Theme.card2.opacity(0.9)))
            }
        }
        .padding(.leading, 6).padding(.trailing, 6).padding(.vertical, 8)
        .background(flash == a ? Theme.gold : Theme.kinariPanel)
        .overlay(alignment: .leading) { Rectangle().fill(Theme.abilityColor(a)).frame(width: 4) }
        .overlay(Rectangle().stroke(Theme.sumi, lineWidth: 1.5))
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: gained)
        .contentShape(Rectangle())
        return Button {
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
    }

    /// ＋の印（行全体がボタン。押せる＝朱の立体／足りない＝灰で形は残す）
    private func plusMark(canTap: Bool) -> some View {
        Image(systemName: "plus").font(.system(size: 24, weight: .black))
            .foregroundStyle(canTap ? .white : Color(hex: 0x9E988D))
            .frame(width: plusW, height: 46)
            .background(Rectangle().fill(canTap ? Color(hex: 0xBD3C28) : Color(hex: 0xD0CBC0)))
            .overlay(Rectangle().stroke(canTap ? Theme.sumi : Color(hex: 0xBDB7AA), lineWidth: 1.5))
            .shadow(color: canTap ? Color(hex: 0x7A1F13) : .clear, radius: 0, y: 2)
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
        return HStack(spacing: 8) {
            subBtn("戻る", w: 60, fg: Theme.ink, bg: Color(hex: 0xE8E2D2), stroke: Theme.sumi.opacity(0.6), enabled: true) { onClose() }   // 反映せずに閉じる
            subBtn("リセット", w: 60, fg: active ? Theme.ink : Theme.inkFaint, bg: Color(hex: 0xE8E2D2), stroke: Theme.sumi.opacity(0.6), enabled: active) { taps.removeAll() }
            subBtn("おまかせ", w: 80, fg: Theme.verm, bg: Color(hex: 0xF5F0E1), stroke: Theme.verm, enabled: true) {
                taps = session.recommendedAllocation(); Haptics.tick()
            }
            // 主役：確定
            Button { confirm() } label: {
                Text("確定").font(.maru(20, weight: .heavy)).foregroundStyle(.white)
                    .shadow(color: Theme.gold, radius: 0, x: 1, y: 1)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(LinearGradient(colors: [Color(hex: 0xBD3C28), Color(hex: 0x8B1E0F)], startPoint: .top, endPoint: .bottom))
                    .overlay(Rectangle().stroke(Theme.sumi, lineWidth: 1.5))
                    .overlay(Rectangle().stroke(Theme.gold, lineWidth: 3).opacity(active ? (pulse ? 1 : 0.15) : 0).padding(-3))   // 上げている間だけ金の枠がゆっくり光る
                    .shadow(color: Color(hex: 0x6A1207), radius: 0, y: 3)
            }
            .frame(minWidth: 130)
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 12)
        .background(Theme.kinari)
        .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true } }
    }

    private func subBtn(_ t: String, w: CGFloat, fg: Color, bg: Color, stroke: Color, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.maru(14, weight: .heavy)).foregroundStyle(fg)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(width: w, height: 44)
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
