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

    private var cfg: GameConfig { session.config }
    private var base: GameState { session.state }
    private var pv: GameState { session.previewAllocation(taps) }

    /// 経験点の表示値（内部×10・切り捨て）
    static func points(_ v: Double) -> Int { Int(v * 10 + 1e-6) }

    /// 左（能力名＋＋ボタン）の固定幅。上の「現在の経験点」行と5列をそろえる
    private let leadW: CGFloat = 118

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
            Rectangle().fill(Theme.goldLeafHi).frame(height: 1).frame(maxWidth: .infinity)
            Text("能力アップ").font(.maru(20, weight: .black)).foregroundStyle(Theme.goldLeafHi).fixedSize()
                .shadow(color: .black.opacity(0.5), radius: 0, x: 1, y: 1)
            Rectangle().fill(Theme.goldLeafHi).frame(height: 1).frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(LinearGradient(colors: [Theme.curtainLit, Theme.curtain], startPoint: .top, endPoint: .bottom).ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.goldLeafMid).frame(height: 2) }
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
                    Text(grade).font(.maru(20, weight: .heavy)).foregroundStyle(.white)
                        .frame(width: 36, height: 30)
                        .background(Theme.gradeColor(grade), in: RoundedRectangle(cornerRadius: 7))
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.line)
                            Capsule().fill(Theme.abilityColor(a)).frame(width: g.size.width * Theme.rankProgress(v, cap: cap))
                        }
                    }
                    .frame(height: 6)
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

    /// 現在の経験点（5種）＝見出し＋5列。下の行の費用列と同じ幅でそろえる
    private var expRow: some View {
        HStack(spacing: 4) {
            Text("現在の\n経験点").font(.maru(13, weight: .heavy)).foregroundStyle(Theme.goldLeafHi)
                .multilineTextAlignment(.center)
                .frame(width: leadW).frame(maxHeight: .infinity)
                .background(Theme.curtain)
            ForEach(ExpCurrency.allCases, id: \.self) { c in
                VStack(spacing: 3) {
                    Text("\(c)").font(.maru(10.5, weight: .bold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.8)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Theme.currencyColor(c), in: Capsule())
                    Text("\(Self.points(pv[currency: c]))").font(.maru(22, weight: .heavy)).monospacedDigit()
                        .foregroundStyle(Theme.ink).minimumScaleFactor(0.7).lineLimit(1)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 8)
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
            Text("実力").font(.maru(14, weight: .bold)).foregroundStyle(Theme.inkSub)
            Text("\(before)").font(.maru(22, weight: .heavy)).monospacedDigit().foregroundStyle(Theme.ink)
            if after != before {
                Image(systemName: "arrow.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.inkFaint)
                Text("\(after)").font(.maru(22, weight: .heavy)).monospacedDigit().foregroundStyle(Theme.moneyDeep)
            }
            Spacer()
            Text("＋を押すと1つ上がる").font(.maru(11)).foregroundStyle(Theme.inkSub)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .mzPanel()
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
        return HStack(spacing: 4) {
            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(a)").font(.maru(15, weight: .heavy)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.8)
                    HStack(spacing: 3) {
                        Text("\(Int(v.rounded()))").font(.maru(14, weight: .heavy)).monospacedDigit().foregroundStyle(Theme.inkSub)
                            .contentTransition(.numericText())
                        if gained > 0 {
                            Text("+\(gained)").font(.maru(13, weight: .heavy)).foregroundStyle(Theme.moneyDeep)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                plusButton(a, canTap: canTap, steps: next?.steps)
            }
            .frame(width: leadW - 4)
            ForEach(ExpCurrency.allCases, id: \.self) { c in
                let n = tag.first(where: { $0.0 == c })?.1
                let have = Self.points(pv[currency: c])
                Text(n.map { "\($0)" } ?? "0")
                    .font(.maru(18, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(n == nil ? Theme.inkFaint.opacity(0.7) : (n! > have ? Theme.vermD : Theme.ink))
                    .minimumScaleFactor(0.7).lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(n == nil ? Theme.line.opacity(0.5) : (n! > have ? Theme.verm.opacity(0.12) : Theme.line.opacity(0.9)))
            }
        }
        .padding(.leading, 8).padding(.trailing, 6).padding(.vertical, 8)
        .background(Theme.kinariPanel)
        .overlay(alignment: .leading) { Rectangle().fill(Theme.abilityColor(a)).frame(width: 4) }
        .overlay(Rectangle().stroke(Theme.sumi, lineWidth: 1.5))
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: gained)
    }

    /// 大きな＋ボタン（押せる＝朱の立体／足りない＝灰で形は残す）
    private func plusButton(_ a: Ability, canTap: Bool, steps: Int?) -> some View {
        Button {
            guard let n = steps else { return }
            Haptics.tick()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                taps += Array(repeating: a, count: n)
            }
        } label: {
            Image(systemName: "plus").font(.system(size: 24, weight: .black))
                .foregroundStyle(canTap ? Color.white : Theme.inkFaint)
                .frame(width: 50, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(canTap ? LinearGradient(colors: [Theme.verm, Theme.vermD], startPoint: .top, endPoint: .bottom)
                                     : LinearGradient(colors: [Theme.line, Theme.lineStrong.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                )
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(canTap ? Theme.sumi : Theme.lineStrong, lineWidth: 1.5))
                .shadow(color: canTap ? Theme.sumi.opacity(0.85) : Theme.lineStrong.opacity(0.6), radius: 0, y: 3)
        }
        .buttonStyle(PressableStyle(enabled: canTap))
        .disabled(!canTap)
    }

    /// 次の等級の名前と、そこまでの能力値（表示だけ）。最高等級なら nil
    static func nextGrade(_ v: Double, cap: Double) -> (name: String, remain: Int)? {
        guard let i = Theme.rankBounds.lastIndex(where: { v >= $0 }), i + 1 < Theme.rankBounds.count else { return nil }
        let hi = Theme.rankBounds[i + 1]
        return (Theme.rank(hi), max(1, Int((hi - v).rounded(.up))))
    }

    private var footer: some View {
        HStack(spacing: 8) {
            footBtn("戻る", fg: Theme.ink, bg: Theme.kinariPanel, enabled: true) { onClose() }   // 反映せずに閉じる
            footBtn("リセット", fg: taps.isEmpty ? Theme.inkFaint : Theme.ink, bg: Theme.line, enabled: !taps.isEmpty) { taps.removeAll() }
            footBtn("おまかせ", fg: .white, bg: Theme.verm, enabled: true) {
                taps = session.recommendedAllocation(); Haptics.tick()
            }
            footBtn("確定", fg: Theme.goldLeafHi, bg: Theme.curtain, enabled: true) { confirm() }
        }
        .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 12)
        .background(Theme.kinari)
    }

    private func footBtn(_ t: String, fg: Color, bg: Color, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.maru(15, weight: .heavy)).foregroundStyle(fg)
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(bg).overlay(Rectangle().stroke(Theme.sumi, lineWidth: 1.5))
                .shadow(color: Theme.sumi.opacity(0.85), radius: 0, y: 3)
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
