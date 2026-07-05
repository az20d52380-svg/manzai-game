// WeekMainView.swift
// SCREEN 01 育成メイン（mockup v3）。上部＝年月週(1行)・やる気・体力・所持金／中＝キャラ＋俺の心の声（状態駆動・ボケない）／
// 能力6バー(伸び演出+「+N」)／下＝2段階コマンド（グループを押す→変種パネル→選ぶ→獲得プレビュー→つぎへ）。

import SwiftUI
import GameCore

struct WeekMainView: View {
    @Bindable var session: GameSession
    let offer: OfferSpec?

    @State private var openGroup: String?
    @State private var selected: CommandVariant?
    @State private var gainsVisible = false

    private var s: GameState { session.state }
    private var groups: [CommandGroup] { CommandCatalog.groups(config: session.config, offer: offer, money: s.money) }

    var body: some View {
        VStack(spacing: 0) {
            topbar
            goalBanner.padding(.horizontal, 14).padding(.top, 1)
            charaZone.padding(.horizontal, 14).padding(.top, 9)
            paramsGrid
            commandArea
        }
        .background(Theme.bgGradient.ignoresSafeArea())
        .task(id: session.week) {
            // 新しい週に入ったら「+N」を一瞬見せる（バー伸び演出の相棒）
            if !session.lastGains.isEmpty {
                gainsVisible = true
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                gainsVisible = false
            }
        }
    }

    // MARK: 上部（年月週1行・やる気・体力・所持金）

    private var topbar: some View {
        HStack(spacing: 9) {
            HStack(spacing: 3) {
                Text("\(session.year)年目").font(.maru(12)).foregroundStyle(Theme.verm)
                Text("\(session.week)週").font(.maru(20))
            }
            .lineLimit(1).fixedSize()
            genkiPill
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 5) {
                    Text("体力").font(.maru(9.5)).foregroundStyle(Theme.cMental)
                    staminaBar
                }
                Text("¥\(s.money.formatted())").font(.maru(13)).monospacedDigit()
                    .foregroundStyle(s.money < 0 ? Theme.verm : Theme.cMoney)
            }
        }
        .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 8)
    }

    private var genkiPill: some View {
        let (face, label) = genki(s.stamina)
        return HStack(spacing: 5) {
            Text(face).font(.system(size: 10)).frame(width: 18, height: 18).background(Theme.gold, in: Circle())
            Text(label).font(.maru(11)).foregroundStyle(Theme.goldD)
        }
        .padding(.leading, 6).padding(.trailing, 9).padding(.vertical, 3)
        .background(Color(hex: 0xFFF6D6), in: Capsule())
        .overlay(Capsule().stroke(Theme.gold, lineWidth: 1.5))
    }

    private var staminaBar: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color(hex: 0xEAF6EF))
            Capsule().fill(LinearGradient(colors: [Color(hex: 0x3FCE93), Theme.cMental], startPoint: .leading, endPoint: .trailing))
                .frame(width: 70 * CGFloat(max(0, min(100, s.stamina)) / 100))
                .animation(.easeOut(duration: 0.4), value: s.stamina)
        }
        .frame(width: 70, height: 8)
        .overlay(Capsule().stroke(Color(hex: 0xCDEBDB), lineWidth: 1.5))
    }

    // MARK: 目標（1行・あとN週は右）

    private var goalBanner: some View {
        let g = goal()
        return HStack(spacing: 7) {
            Text("🎯").font(.system(size: 13))
            Text(g.0).font(.maru(12)).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 6)
            Text(g.1).font(.maru(11)).foregroundStyle(Theme.verm).fixedSize()
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(LinearGradient(colors: [Color(hex: 0xFFEAD2), Color(hex: 0xFFF3E4)], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color(hex: 0xF3C58A), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
    }

    // MARK: キャラ＋俺の心の声

    private var charaZone: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(RadialGradient(colors: [Color(hex: 0xFFE3B0), Color(hex: 0xFFC98A)], center: .bottom, startRadius: 10, endRadius: 220))
            HStack(alignment: .bottom, spacing: 2) {
                Spacer()
                silhouette(color: Color(hex: 0x3B6FE0), w: 42, h: 60)
                silhouette(color: Theme.verm, w: 48, h: 68)
            }
            .padding(10)
            monoBox.padding(12)
        }
        .frame(minHeight: 120)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func silhouette(color: Color, w: CGFloat, h: CGFloat) -> some View {
        UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 14, bottomTrailingRadius: 14, topTrailingRadius: 24)
            .fill(LinearGradient(colors: [color.opacity(0.85), color], startPoint: .top, endPoint: .bottom))
            .frame(width: w, height: h)
            .overlay(alignment: .top) { Circle().fill(Color(hex: 0xFFE0C4)).frame(width: 24, height: 24).offset(y: 11) }
            .shadow(color: .black.opacity(0.22), radius: 4, y: 4)
    }

    private var monoBox: some View {
        let a = mono
        return VStack(alignment: .leading, spacing: 2) {
            Text(a.name ?? "俺").font(.maru(9.5)).tracking(1).foregroundStyle(Theme.inkDim)
            Text(a.text).font(.system(size: 13)).italic().foregroundStyle(Color(hex: 0x4A4360))
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .frame(maxWidth: 250, alignment: .leading)
        .background(Color.white.opacity(0.92), in: UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 4, bottomTrailingRadius: 12, topTrailingRadius: 12))
        .overlay(alignment: .leading) { Rectangle().fill(Theme.inkDim).frame(width: 3) }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 4, bottomTrailingRadius: 12, topTrailingRadius: 12))
        .shadow(color: .black.opacity(0.12), radius: 5, y: 4)
        .id(a.text)
        .transition(.opacity)
    }

    // MARK: 能力6バー（伸び演出＋「+N」）

    private var paramsGrid: some View {
        let rows: [(String, Ability?, Double, Color)] = [
            ("センス", .センス, s.センス, Theme.cSense),
            ("発想", .発想, s.発想, Theme.cIdea),
            ("表現", .表現, s.表現, Theme.cExpr),
            ("華", .華, s.華, Theme.cChara),
            ("メンタル", .メンタル, s.メンタル, Theme.cMental),
            ("相性", nil, s.compat, Theme.cCompat),
        ]
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 5) {
            ForEach(rows, id: \.0) { row in
                abilityRow(name: row.0, ability: row.1, value: row.2, color: row.3)
            }
        }
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 4)
    }

    private func abilityRow(name: String, ability: Ability?, value: Double, color: Color) -> some View {
        let gain = ability.flatMap { a in session.lastGains.first(where: { $0.ability == a })?.amount }
        return HStack(spacing: 6) {
            Text(name).font(.maru(11)).foregroundStyle(color).frame(width: 44, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: 0xF0E9DE))
                    Capsule().fill(color)
                        .frame(width: geo.size.width * CGFloat(min(100, value) / 100))
                        .animation(.easeOut(duration: 0.55), value: value)
                }
            }
            .frame(height: 8)
            Text("\(Int(value))").font(.maru(12)).monospacedDigit().frame(width: 20, alignment: .trailing)
        }
        .overlay(alignment: .topTrailing) {
            if let gain, gain > 0, gainsVisible {
                Text("+\(Int(gain.rounded()))").font(.maru(11)).foregroundStyle(color)
                    .offset(x: -22, y: -9).transition(.opacity)
            }
        }
    }

    // MARK: 2段階コマンド

    private var commandArea: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(groups) { g in groupTile(g) }
            }
            .padding(.horizontal, 12).padding(.top, 6)

            if let openGroup, let g = groups.first(where: { $0.id == openGroup }) {
                variantPanel(g)
                    .padding(.horizontal, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            nextBar
        }
        .background(LinearGradient(colors: [.clear, Color(hex: 0xFFEFDD)], startPoint: .top, endPoint: .center))
        .animation(.easeOut(duration: 0.2), value: openGroup)
    }

    private func groupTile(_ g: CommandGroup) -> some View {
        let isOpen = openGroup == g.id
        return Button {
            openGroup = isOpen ? nil : g.id
        } label: {
            VStack(spacing: 3) {
                Image(systemName: g.glyph).font(.system(size: 17)).foregroundStyle(Theme.ink)
                Text(g.title).font(.maru(11))
                HStack(spacing: 3) { ForEach(Array(g.dotColors.enumerated()), id: \.offset) { _, c in Circle().fill(c).frame(width: 6, height: 6) } }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(isOpen ? Color(hex: 0xFFF3EF) : Theme.card, in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(isOpen ? Theme.verm : Theme.line, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private func variantPanel(_ g: CommandGroup) -> some View {
        VStack(spacing: 0) {
            Text("\(g.title) — どれにする？").font(.maru(11)).foregroundStyle(Theme.verm)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 4)
            ForEach(g.variants) { v in
                Button {
                    selected = v
                    openGroup = nil
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: v.glyph).font(.system(size: 15)).frame(width: 22).foregroundStyle(Theme.ink)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(v.name).font(.maru(12.5))
                            Text(v.desc).font(.system(size: 10)).foregroundStyle(Theme.inkDim)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(v.affordable ? v.costText : "¥不足").font(.maru(10.5))
                                .foregroundStyle(!v.affordable ? Theme.verm : (v.costIsUp ? Theme.cMoney : Theme.verm))
                            Text(v.eff).font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.inkFaint)
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
                    .opacity(v.affordable ? 1 : 0.45)
                }
                .buttonStyle(.plain)
                .disabled(!v.affordable)
            }
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.verm, lineWidth: 2))
    }

    private var nextBar: some View {
        HStack(spacing: 9) {
            Group {
                if let sel = selected {
                    HStack(spacing: 5) {
                        Text("\(sel.name)：").font(.maru(11)).foregroundStyle(Theme.ink)
                        ForEach(sel.gains) { g in
                            Text("\(g.label) \(g.amount)").font(.system(size: 10.5, weight: .bold)).foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(g.color, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                } else {
                    Text("▲ コマンドを押して選ぶ").font(.maru(11)).foregroundStyle(Theme.inkFaint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                guard let sel = selected else { return }
                selected = nil
                session.choose(sel.action)
            } label: {
                Text("つぎへ ▶").font(.maru(15)).foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(selected == nil ? Theme.inkFaint : Theme.verm, in: RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain).disabled(selected == nil)
        }
        .padding(.horizontal, 14).padding(.top, 6).padding(.bottom, 13)
        .background(Color(hex: 0xFFEFDD))
    }

    // MARK: 導出

    private var mono: Advice {
        if let sel = selected { return Advice(name: "俺", text: DialogueData.reaction(variantID: sel.id)) }
        return DialogueData.innerVoice(state: s, lossStreak: session.lossStreak, justPassed: session.justPassedStage,
                                       nextMilestone: nextMilestone(), weakAbility: weakAbility())
    }

    private func weakAbility() -> String {
        let pairs: [(String, Double)] = [("センス", s.センス), ("発想", s.発想), ("表現", s.表現), ("華", s.華), ("メンタル", s.メンタル)]
        return pairs.min(by: { $0.1 < $1.1 })?.0 ?? "表現"
    }

    private func nextMilestone() -> (name: String, weeksLeft: Int)? {
        let cal = session.config.calendar
        var ms: [(Int, String)] = []
        for (i, r) in cal.gpRounds.enumerated() { ms.append((r.week, i < cal.gpRoundNames.count ? cal.gpRoundNames[i] : "頂GP\(i + 1)回戦")) }
        ms.append((cal.gpFinalWeek, "頂GP 決勝"))
        for t in cal.tournaments { ms.append((t.week, t.name)) }
        guard let next = ms.filter({ $0.0 >= session.week }).min(by: { $0.0 < $1.0 }) else { return nil }
        return (next.1, next.0 - session.week)
    }

    private func goal() -> (String, String) {
        if let m = nextMilestone() { return ("目標：\(m.name)", m.weeksLeft <= 0 ? "今週！" : "あと\(m.weeksLeft)週") }
        let d = session.config.weeks - session.week
        return ("目標：1年目 完走", d <= 0 ? "最終週" : "あと\(d)週")
    }

    private func genki(_ st: Double) -> (String, String) {
        switch st {
        case 80...: return ("◠‿◠", "絶好調")
        case 50..<80: return ("・‿・", "好調")
        case 30..<50: return ("・_・", "普通")
        default: return (">_<", "バテ気味")
        }
    }
}
