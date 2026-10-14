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

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 10) {
                    expStrip
                    jitsuryokuCard
                    ForEach(Ability.allCases, id: \.self) { row($0) }
                }
                .padding(.horizontal, 16).padding(.bottom, 16)
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
            Button(action: close) {
                Text("とじる").font(.maru(12, weight: .black)).foregroundStyle(Theme.goldLeafHi)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .overlay(Rectangle().stroke(Theme.goldLeafHi, lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(LinearGradient(colors: [Theme.curtainLit, Theme.curtain], startPoint: .top, endPoint: .bottom).ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.goldLeafMid).frame(height: 2) }
        .padding(.bottom, 10)
    }

    /// 持っている経験点（5種）
    private var expStrip: some View {
        HStack(spacing: 6) {
            ForEach(ExpCurrency.allCases, id: \.self) { c in
                VStack(spacing: 2) {
                    Text("\(Self.points(pv[currency: c]))").font(.maru(18, weight: .heavy)).monospacedDigit()
                        .foregroundStyle(Theme.ink)
                    Text("\(c)").font(.maru(10.5, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Theme.currencyColor(c), in: Capsule())
                }
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .mzPanel()
            }
        }
        .padding(.top, 2)
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
            Text("経験点で能力を上げる").font(.maru(11)).foregroundStyle(Theme.inkSub)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
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
        GameEngine.nextStepCost(a, state: pv, config: cfg).map { ($0.currency, max(1, Self.points($0.amount))) }
    }

    private func row(_ a: Ability) -> some View {
        let v = pv[a]
        let grade = Theme.rank(v)
        let gained = Int(v.rounded()) - Int(base[a].rounded())
        let next = nextPlusOne(a)
        let tag = next?.cost ?? priceTag(a)
        let cap = a == .メンタル ? cfg.mentalCap : cfg.abilityCap
        let nextG = Self.nextGrade(v, cap: cap)
        let canTap = next != nil
        return HStack(spacing: 10) {
            Text(grade).font(.maru(20, weight: .heavy)).foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Theme.gradeColor(grade), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(a)").font(.maru(15, weight: .bold)).foregroundStyle(Theme.ink)
                    Text("\(Int(v.rounded()))").font(.maru(18, weight: .heavy)).monospacedDigit().foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                        .scaleEffect(gained > 0 ? 1.12 : 1, anchor: .leading)
                    if gained > 0 {
                        Text("+\(gained)").font(.maru(13, weight: .heavy)).foregroundStyle(Theme.moneyDeep)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Spacer(minLength: 0)
                    if let g = nextG {
                        Text("次の\(g.name)まで あと\(g.remain)").font(.maru(11, weight: .bold)).foregroundStyle(Theme.inkSub)
                    } else {
                        Text("最高の等級").font(.maru(11, weight: .bold)).foregroundStyle(Theme.inkSub)
                    }
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.line)
                        Capsule().fill(Theme.abilityColor(a))
                            .frame(width: g.size.width * Theme.rankProgress(v, cap: cap))
                    }
                }
                .frame(height: 6)
                HStack(spacing: 4) {
                    Text("必要").font(.maru(10.5, weight: .bold)).foregroundStyle(Theme.inkSub).lineLimit(1).fixedSize()
                    ForEach(tag, id: \.0) { c, n in
                        let have = Self.points(pv[currency: c])
                        let lack = n - have
                        HStack(spacing: 3) {
                            Text("\(c) \(n)").font(.maru(10.5, weight: .heavy)).lineLimit(1).fixedSize()
                            if lack > 0 {
                                Text("あと\(lack)").font(.maru(10.5, weight: .bold)).lineLimit(1).fixedSize()
                            } else {
                                Image(systemName: "checkmark").font(.system(size: 10, weight: .black))
                            }
                        }
                        .foregroundStyle(lack > 0 ? Theme.ink : Theme.moneyDeep)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(lack > 0 ? Theme.line : Theme.moneyDeep.opacity(0.12), in: Capsule())
                        .overlay(Capsule().stroke(lack > 0 ? Theme.lineStrong : Theme.moneyDeep, lineWidth: 1.2))
                    }
                }
            }
            Spacer(minLength: 0)
            Button {
                guard let n = next?.steps else { return }
                Haptics.tick()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    taps += Array(repeating: a, count: n)
                }
            } label: {
                Image(systemName: "plus").font(.system(size: 20, weight: .black))
                    .foregroundStyle(canTap ? Color.white : Theme.inkSub)
                    .frame(width: 48, height: 48)
                    .background(canTap ? Theme.abilityColor(a) : Theme.card, in: Circle())
                    .overlay(Circle().stroke(canTap ? Theme.ink.opacity(0.85) : Theme.lineStrong,
                                             style: StrokeStyle(lineWidth: canTap ? 2 : 1.5, dash: canTap ? [] : [3, 3])))
                    .shadow(color: canTap ? Theme.ink.opacity(0.85) : .clear, radius: 0, y: 3)
            }
            .buttonStyle(PressableStyle(enabled: canTap))
            .disabled(!canTap)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .mzPanel()
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: gained)
    }

    /// 次の等級の名前と、そこまでの能力値（表示だけ）。最高等級なら nil
    static func nextGrade(_ v: Double, cap: Double) -> (name: String, remain: Int)? {
        guard let i = Theme.rankBounds.lastIndex(where: { v >= $0 }), i + 1 < Theme.rankBounds.count else { return nil }
        let hi = Theme.rankBounds[i + 1]
        return (Theme.rank(hi), max(1, Int((hi - v).rounded(.up))))
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button { taps.removeAll() } label: {
                Text("もどす").font(.maru(15, weight: .bold)).foregroundStyle(taps.isEmpty ? Theme.inkFaint : Theme.inkSub)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Theme.kinariPanel).overlay(Rectangle().stroke(Theme.sumi, lineWidth: 1.5))
            }
            .buttonStyle(PressableStyle(enabled: !taps.isEmpty)).disabled(taps.isEmpty)
            Button {
                taps = session.recommendedAllocation()
                Haptics.tick()
            } label: {
                Text("おまかせ").font(.maru(16, weight: .heavy)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Theme.verm).overlay(Rectangle().stroke(Theme.sumi, lineWidth: 1.5))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 12)
        .background(Theme.kinari)
    }

    /// とじる＝確定（押した段をそのまま反映。何も押していなければ閉じるだけ）
    private func close() {
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
