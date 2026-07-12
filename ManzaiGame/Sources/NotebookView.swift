// NotebookView.swift
// S5 ネタ帳（正本: uiux_vision_reply_part2 §S5）。見開きメタファ（縦持ちはタブで代替）。
// ちから=レーダー5角形(演技4+メンタル・共用RadarChart)＋相性は別系統のverm帯＋成長の伸びしろ(器の空き・数値なし)。
// きろく=大会履歴(判ミニチュア+回戦名)・称号。効果量の事前表示はしない既定を維持（ここは「育ったか」を見る場所）。
// 表示専用（RNG非消費・golden非対象）。育成メインの「データ」から開く。

import SwiftUI
import GameCore

struct NotebookView: View {
    let session: GameSession
    var onClose: () -> Void
    @State private var tab: Tab = .chikara
    private enum Tab { case chikara, kiroku }

    private var s: GameState { session.state }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.bgTop, Theme.bg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: Theme.Sp.s16) {
                header
                tabBar
                ScrollView {
                    Group { tab == .chikara ? AnyView(chikaraPage) : AnyView(kirokuPage) }
                        .padding(.horizontal, Theme.Sp.s16).padding(.bottom, Theme.Sp.s24)
                }
            }
            .padding(.top, Theme.Sp.s12)
        }
    }

    private var header: some View {
        HStack {
            Text("ネタ帳").font(.maru(16)).foregroundStyle(Theme.ink)
            Spacer()
            Text(session.combiName).font(.maru(12)).foregroundStyle(Theme.inkDim)
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundStyle(Theme.inkFaint)
            }.buttonStyle(PressableStyle())
        }
        .padding(.horizontal, Theme.Sp.s16)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton("ちから", .chikara)
            tabButton("きろく", .kiroku)
        }
        .padding(4).background(Theme.card2, in: Capsule()).padding(.horizontal, Theme.Sp.s24)
    }

    private func tabButton(_ label: String, _ t: Tab) -> some View {
        Button { withAnimation(Theme.Motion.appearQuick) { tab = t } } label: {
            Text(label).font(.maru(13)).foregroundStyle(tab == t ? .white : Theme.inkDim)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(tab == t ? Theme.verm : .clear, in: Capsule())
        }.buttonStyle(.plain)
    }

    // MARK: ちから（レーダー＋相性帯＋伸びしろ）

    private var chikaraPage: some View {
        VStack(spacing: Theme.Sp.s16) {
            RadarChart(axes: RadarChart.abilityAxes(current: s, base: GameState(config: session.config), config: session.config))
                .frame(height: 240)
                .padding(Theme.Sp.s16)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card)).e2()

            // 相性は別系統＝verm帯（器なし・位置でも分離）
            VStack(alignment: .leading, spacing: 6) {
                HStack { Text("相性").font(.maru(11)).foregroundStyle(Theme.cCompat); Spacer()
                    Text("\(Int(s.compat)) / \(Int(session.config.compatCap))").font(.maru(12)).monospacedDigit().foregroundStyle(Theme.inkDim) }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.card2)
                        Capsule().fill(Theme.cCompat)
                            .frame(width: geo.size.width * CGFloat(min(1, s.compat / session.config.compatCap)))
                    }
                }.frame(height: 10)
            }
            .padding(Theme.Sp.s16).background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card)).e1()

            growthRoom
        }
    }

    // 成長の伸びしろ（器の空き＝成長予算の残り・数値なし）＋未割り振りの経験点残高
    // （正典: docs/exp_abilityup_impl_reply_v0.md §B。塗りドット＝同色ロック粒／輪郭ドット＝共通粒、
    //  AllocationView と同じ粒の文法。ここは読む場所＝注ぐ操作は「のばす」に置く）
    private var growthRoom: some View {
        let budget = s.growthBudget ?? 0
        let used = min(budget, s.growthUsed)
        let frac = budget > 0 ? used / budget : 0
        let hasGrain = s.expTotal >= 1
        return VStack(alignment: .leading, spacing: 8) {
            Text("成長の器").font(.maru(11)).foregroundStyle(Theme.inkDim)
            HStack(spacing: Theme.Sp.s16) {
                ZStack {
                    Circle().stroke(Theme.card2, lineWidth: 10)
                    Circle().trim(from: 0, to: CGFloat(frac))
                        .stroke(Theme.gold, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }.frame(width: 56, height: 56)
                Text(frac < 0.98 ? "まだ、伸びしろがある。" : "この年の器は、満ちた。")
                    .font(.system(size: 13, design: .serif)).foregroundStyle(Theme.ink)
                Spacer()
            }
            if hasGrain {
                Divider().padding(.vertical, 2)
                Text("のこりの粒").font(.maru(11)).foregroundStyle(Theme.inkDim)
                HStack(spacing: Theme.Sp.s8) {
                    ForEach(Ability.allCases, id: \.self) { a in
                        if s[bank: a] >= 1 {
                            HStack(spacing: 3) {
                                Circle().fill(Theme.abilityColor(a)).frame(width: 7, height: 7)
                                Text("\(Int(s[bank: a]))").font(.maru(11)).monospacedDigit()
                                    .foregroundStyle(Theme.ink)
                            }
                        }
                    }
                    ForEach(ExpGroup.allCases, id: \.self) { g in
                        if s[free: g] >= 1 {
                            HStack(spacing: 3) {
                                Circle().stroke(Theme.inkDim, lineWidth: 1.2).frame(width: 7, height: 7)
                                Text("\(g.rawValue) \(Int(s[free: g]))").font(.maru(11)).monospacedDigit()
                                    .foregroundStyle(Theme.ink)
                            }
                        }
                    }
                    Spacer()
                }
                Text("注いでいない粒がある。「のばす」から注ぐ。")
                    .font(.system(size: 12, design: .serif)).foregroundStyle(Theme.inkDim)
            }
        }
        .padding(Theme.Sp.s16).background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card)).e1()
    }

    // MARK: きろく（大会履歴＋称号）

    private var kirokuPage: some View {
        VStack(alignment: .leading, spacing: Theme.Sp.s12) {
            Text("大会の記録").font(.maru(12)).foregroundStyle(Theme.inkDim)
            if session.log.isEmpty {
                Text("——まだ、舞台の記録はない。").font(.system(size: 13, design: .serif)).foregroundStyle(Theme.inkDim)
                    .padding(.vertical, Theme.Sp.s8)
            } else {
                ForEach(Array(session.log.enumerated()), id: \.offset) { _, line in
                    HStack(spacing: 10) {
                        // 判ミニチュア（通過=verm/敗退=ink）
                        Text(line.contains("通過") ? "通過" : "敗退")
                            .font(.maru(10)).foregroundStyle(.white)
                            .frame(width: 40, height: 24)
                            .background(line.contains("通過") ? Theme.verm : Theme.ink, in: RoundedRectangle(cornerRadius: Theme.Rad.stamp))
                        Text(line).font(.system(size: 12.5, design: .serif)).foregroundStyle(Theme.ink)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
            Text("称号").font(.maru(12)).foregroundStyle(Theme.inkDim).padding(.top, Theme.Sp.s8)
            Text("〈まだ無い〉【仮】").font(.maru(12)).foregroundStyle(Theme.inkFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Sp.s16).background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card)).e2()
    }
}
