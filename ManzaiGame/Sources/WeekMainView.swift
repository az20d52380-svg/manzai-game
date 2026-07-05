// WeekMainView.swift
// SCREEN 01 育成メイン（mockup準拠）。年月週・やる気・体力・目標／キャラ＋谷口の掛け合い／
// 能力6色バー+ランク常時表示／練習タイル（色ドット+コスト）→選択で獲得プレビュー→つぎへ。
// 数値は「出す派」。会話は谷口（相方）の反応＝ご褒美。

import SwiftUI
import GameCore

struct WeekMainView: View {
    @Bindable var session: GameSession
    let offer: OfferSpec?
    @State private var selected: CommandTile?

    private var s: GameState { session.state }
    private var advice: Advice { DialogueData.advice(for: session.lastAction, state: s, salt: session.week) }
    private var tiles: [CommandTile] { CommandCatalog.tiles(config: session.config, offer: offer) }

    var body: some View {
        VStack(spacing: 0) {
            topbar
            goalBanner.padding(.horizontal, 14).padding(.top, 2)
            charaZone.padding(.horizontal, 14).padding(.top, 10)
            paramsGrid
            commandArea
        }
        .background(Theme.bgGradient.ignoresSafeArea())
    }

    // MARK: トップバー（年月週・やる気・体力）

    private var topbar: some View {
        HStack(spacing: 10) {
            VStack(spacing: 0) {
                Text("\(session.year)年目").font(.maru(12)).foregroundStyle(Theme.verm)
                Text("\(session.week)週").font(.maru(22))
            }
            genkiPill
            Spacer()
            hpMeter
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 8)
    }

    private var genkiPill: some View {
        let (face, label) = genki(s.stamina)
        return HStack(spacing: 6) {
            Text(face).font(.system(size: 12)).frame(width: 22, height: 22)
                .background(Theme.gold, in: Circle())
            Text(label).font(.maru(12)).foregroundStyle(Theme.goldD)
        }
        .padding(.leading, 7).padding(.trailing, 10).padding(.vertical, 4)
        .background(Color(hex: 0xFFF6D6), in: Capsule())
        .overlay(Capsule().stroke(Theme.gold, lineWidth: 1.5))
    }

    private var hpMeter: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("体力").font(.maru(10)).foregroundStyle(Theme.inkDim)
                Spacer()
                Text("\(Int(s.stamina))").font(.maru(10)).foregroundStyle(Theme.cMental)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: 0xEAF6EF))
                    Capsule().fill(LinearGradient(colors: [Color(hex: 0x3FCE93), Theme.cMental],
                                                  startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(max(0, min(100, s.stamina)) / 100))
                }
            }
            .frame(width: 96, height: 9)
            .overlay(Capsule().stroke(Color(hex: 0xCDEBDB), lineWidth: 1.5))
        }
    }

    // MARK: 目標

    private var goalBanner: some View {
        HStack(spacing: 8) {
            Text("🎯").font(.system(size: 14))
            VStack(alignment: .leading, spacing: 1) {
                Text(goal().0).font(.maru(12.5))
                Text(goal().1).font(.maru(10.5, weight: .bold)).foregroundStyle(Theme.inkDim)
            }
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(LinearGradient(colors: [Color(hex: 0xFFEAD2), Color(hex: 0xFFF3E4)],
                                   startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0xF3C58A), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
    }

    // MARK: キャラ＋谷口の掛け合い

    private var charaZone: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 16)
                .fill(RadialGradient(colors: [Color(hex: 0xFFE3B0), Color(hex: 0xFFC98A)],
                                     center: .bottom, startRadius: 10, endRadius: 220))
            // 相方シルエット（仮・TODO: 立ち絵差し替え）
            HStack(alignment: .bottom, spacing: 2) {
                silhouette(color: Color(hex: 0x3B6FE0), w: 46, h: 64)
                silhouette(color: Theme.verm, w: 52, h: 74)
            }
            .padding(10)

            // 谷口の吹き出し
            adviceBubble
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(minHeight: 150)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func silhouette(color: Color, w: CGFloat, h: CGFloat) -> some View {
        UnevenRoundedRectangle(topLeadingRadius: 26, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 26)
            .fill(LinearGradient(colors: [color.opacity(0.85), color], startPoint: .top, endPoint: .bottom))
            .frame(width: w, height: h)
            .overlay(alignment: .top) {
                Circle().fill(Color(hex: 0xFFE0C4)).frame(width: 26, height: 26).offset(y: 12)
            }
            .shadow(color: .black.opacity(0.25), radius: 5, y: 5)
    }

    private var adviceBubble: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let name = advice.name {
                Text(name).font(.maru(10.5)).foregroundStyle(Theme.verm)
                Text(advice.text).font(.system(size: 12.5)).foregroundStyle(Theme.ink)
            } else {
                Text(advice.text).font(.system(size: 12.5)).italic().foregroundStyle(Theme.inkDim)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .frame(maxWidth: 230, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.verm, lineWidth: 2))
        .shadow(color: .black.opacity(0.18), radius: 7, y: 6)
        .id(advice.text)   // テキスト変化で再描画（ポップ）
        .transition(.opacity)
    }

    // MARK: 能力6種（色ドット＋ランク＋バー＋数値）

    private var paramsGrid: some View {
        let rows: [(String, Double, Color, Bool)] = [
            ("センス", s.センス, Theme.cSense, true),
            ("発想", s.発想, Theme.cIdea, true),
            ("表現", s.表現, Theme.cExpr, true),
            ("華", s.華, Theme.cChara, true),
            ("メンタル", s.メンタル, Theme.cMental, true),
            ("相性", s.compat, Theme.cCompat, false),   // 相性はランク無し
        ]
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())],
                         spacing: 5) {
            ForEach(rows, id: \.0) { row in
                abilityRow(name: row.0, value: row.1, color: row.2, ranked: row.3)
            }
        }
        .padding(.horizontal, 16).padding(.top, 11).padding(.bottom, 6)
    }

    private func abilityRow(name: String, value: Double, color: Color, ranked: Bool) -> some View {
        HStack(spacing: 7) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(name).font(.maru(11)).frame(width: 40, alignment: .leading)
            Text(ranked ? Theme.rank(value) : "–").font(.maru(13)).foregroundStyle(color).frame(width: 16)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: 0xF0E9DE))
                    Capsule().fill(color)
                        .frame(width: geo.size.width * CGFloat(min(100, value) / 100))
                }
            }
            .frame(height: 7)
            Text("\(Int(value))").font(.maru(12)).monospacedDigit().frame(width: 22, alignment: .trailing)
        }
    }

    // MARK: 練習コマンド＋つぎへ

    private var commandArea: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(tiles) { tile in
                    tileButton(tile)
                }
            }
            .padding(.horizontal, 12).padding(.top, 8)

            nextBar
        }
        .background(LinearGradient(colors: [.clear, Color(hex: 0xFFEFDD)], startPoint: .top, endPoint: .center))
    }

    private func tileButton(_ tile: CommandTile) -> some View {
        let disabled = isUnaffordable(tile)
        let isSel = selected?.id == tile.id
        return Button {
            selected = tile
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tile.glyph).font(.system(size: 17)).foregroundStyle(Theme.ink)
                Text(tile.title).font(.maru(10.5)).lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: 3) {
                    ForEach(Array(tile.dotColors.enumerated()), id: \.offset) { _, c in
                        Circle().fill(c).frame(width: 7, height: 7)
                    }
                }
                Text(disabled ? "¥不足" : tile.costText)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(disabled ? Theme.verm : (tile.costIsUp ? Theme.cMental : Theme.inkDim))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 8).padding(.horizontal, 3)
            .background(isSel ? Color(hex: 0xFFF3EF) : Theme.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSel ? Theme.verm : Theme.line, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }

    private var nextBar: some View {
        HStack(spacing: 9) {
            // 獲得プレビュー
            Group {
                if let sel = selected {
                    HStack(spacing: 5) {
                        Text("獲得 →").font(.maru(11)).foregroundStyle(Theme.inkDim)
                        ForEach(sel.gains) { g in
                            Text("\(g.label) \(g.amount)")
                                .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(g.color, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                } else {
                    Text("▲ コマンドを選ぶと獲得プレビュー")
                        .font(.maru(11, weight: .bold)).foregroundStyle(Theme.inkFaint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                guard let sel = selected else { return }
                selected = nil
                session.choose(sel.action)
            } label: {
                Text("つぎへ ▶").font(.maru(15)).foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 11)
                    .background(selected == nil ? Theme.inkFaint : Theme.verm,
                               in: RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
            .disabled(selected == nil)
        }
        .padding(.horizontal, 14).padding(.top, 6).padding(.bottom, 14)
        .background(Color(hex: 0xFFEFDD))
    }

    // MARK: 導出（表示用）

    private func isUnaffordable(_ tile: CommandTile) -> Bool {
        if case .train(let t) = tile.action, let spec = session.config.trainings[t] {
            return spec.cost > s.money
        }
        return false
    }

    private func genki(_ st: Double) -> (String, String) {
        switch st {
        case 80...: return ("◠‿◠", "絶好調")
        case 50..<80: return ("・‿・", "好調")
        case 30..<50: return ("・_・", "普通")
        default: return (">_<", "バテ気味")
        }
    }

    /// 次のマイルストーン（目標）を calendar から算出
    private func goal() -> (String, String) {
        let cal = session.config.calendar
        var milestones: [(week: Int, name: String)] = []
        for (i, r) in cal.gpRounds.enumerated() {
            let nm = i < cal.gpRoundNames.count ? cal.gpRoundNames[i] : "頂GP\(i + 1)回戦"
            milestones.append((r.week, nm))
        }
        milestones.append((cal.gpFinalWeek, "頂GP 決勝"))
        for t in cal.tournaments { milestones.append((t.week, t.name)) }
        let future = milestones.filter { $0.week >= session.week }.sorted { $0.week < $1.week }
        if let next = future.first {
            let d = next.week - session.week
            return ("目標：\(next.name)", d == 0 ? "今週が本番！" : "あと \(d)週")
        }
        let d = session.config.weeks - session.week
        return ("目標：1年目 完走", d <= 0 ? "今週で最終週" : "あと \(d)週で年末")
    }
}
