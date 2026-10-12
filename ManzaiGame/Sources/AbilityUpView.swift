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
        .background(LinearGradient(colors: [Theme.bgTop, Theme.bg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            Text("能力アップ").font(.maru(22, weight: .heavy)).foregroundStyle(Theme.ink)
            Spacer()
            Button(action: close) {
                Text("とじる").font(.maru(14, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Theme.verm, in: Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 10)
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
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
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
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card))
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
        return HStack(spacing: 10) {
            Text(grade).font(.maru(20, weight: .heavy)).foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Theme.gradeColor(grade), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(a)").font(.maru(15, weight: .bold)).foregroundStyle(Theme.ink)
                    Text("\(Int(v.rounded()))").font(.maru(18, weight: .heavy)).monospacedDigit().foregroundStyle(Theme.ink)
                    if gained > 0 {
                        Text("+\(gained)").font(.maru(13, weight: .heavy)).foregroundStyle(Theme.moneyDeep)
                    }
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.line)
                        Capsule().fill(Theme.abilityColor(a))
                            .frame(width: g.size.width * Theme.rankProgress(v, cap: a == .メンタル ? cfg.mentalCap : cfg.abilityCap))
                    }
                }
                .frame(height: 6)
                HStack(spacing: 4) {
                    ForEach(tag, id: \.0) { c, n in
                        let short = Self.points(pv[currency: c]) < n
                        Text("\(c) \(n)").font(.maru(10.5, weight: .bold))
                            .foregroundStyle(short ? Theme.inkFaint : Theme.currencyColor(c))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .overlay(Capsule().stroke(short ? Theme.line : Theme.currencyColor(c), lineWidth: 1.2))
                    }
                }
            }
            Spacer(minLength: 0)
            Button {
                guard let n = next?.steps else { return }
                Haptics.tick()
                taps += Array(repeating: a, count: n)
            } label: {
                Image(systemName: "plus").font(.system(size: 18, weight: .heavy)).foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(next == nil ? Theme.inkFaint : Theme.abilityColor(a), in: Circle())
            }
            .buttonStyle(PressableStyle(enabled: next != nil))
            .disabled(next == nil)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card))
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button { taps.removeAll() } label: {
                Text("もどす").font(.maru(15, weight: .bold)).foregroundStyle(taps.isEmpty ? Theme.inkFaint : Theme.inkSub)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.btn))
            }
            .buttonStyle(PressableStyle(enabled: !taps.isEmpty)).disabled(taps.isEmpty)
            Button {
                taps = session.recommendedAllocation()
                Haptics.tick()
            } label: {
                Text("おまかせ").font(.maru(16, weight: .heavy)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Theme.verm, in: RoundedRectangle(cornerRadius: Theme.Rad.btn))
                    .shadow(color: Theme.vermD, radius: 0, y: 3)
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 12)
        .background(Theme.bg2)
    }

    /// とじる＝確定（押した段をそのまま反映。何も押していなければ閉じるだけ）
    private func close() {
        if !taps.isEmpty { _ = session.allocate(taps) }
        onClose()
    }
}
