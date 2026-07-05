// YearResultView.swift
// SCREEN 04: 1年目の年末結果。到達段階ボード＋語り＋才能の灯り＋年間サマリ。
// 1年MVPは決勝到達が稀なので、到達段階に応じて表示（champion/決勝/到達回戦/夜逃げ）。
// ライバル名・順位は表示フレーバー（架空名・rival_design準拠）。才能解放は【仮・TODO本実装】。

import SwiftUI
import GameCore

struct YearResultView: View {
    let session: GameSession
    var onRestart: () -> Void

    private var s: GameState { session.state }
    private var o: YearOutcome? { session.outcome }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("頂 グランプリ ・ 1年目").font(.maru(12)).tracking(2).foregroundStyle(Theme.gold)
                Text(headline).font(.maru(21)).foregroundStyle(.white)

                board
                Text(monolog)
                    .font(.system(size: 13.5, design: .serif)).lineSpacing(6)
                    .foregroundStyle(Color(hex: 0xD9CDEC))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(13)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

                unlockRow
                summaryStrip

                Button(action: onRestart) {
                    Text("もう一度").font(.maru(16)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Theme.verm, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain).padding(.horizontal, 30).padding(.top, 4)
            }
            .padding(.horizontal, 18).padding(.vertical, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [Color(hex: 0x2C2740), Color(hex: 0x3A2F52), Color(hex: 0x4A2F52)],
                                   startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }

    private var headline: String {
        guard let o else { return "最終結果" }
        if o.champion { return "🏆 優勝！" }
        if o.bankrupt { return "💸 夜逃げ" }
        if o.reachedFinal { return "決勝進出・惜敗" }
        return "最終結果"
    }

    // 到達段階ボード（決勝到達時は順位・そうでなければ到達回戦の階段）
    @ViewBuilder private var board: some View {
        if let o, o.reachedFinal || o.champion {
            VStack(spacing: 8) {
                if o.champion {
                    boardRow(rank: "1", name: "あなたのコンビ", role: "今年の頂点", score: "96.4", kind: .win)
                    boardRow(rank: "2", name: "静物画", role: "技巧派の先輩", score: "95.1", kind: .plain)
                    boardRow(rank: "3", name: "金字塔", role: "先に行く同期", score: "94.8", kind: .plain)
                } else {
                    boardRow(rank: "1", name: "静物画", role: "技巧派の先輩", score: "96.4", kind: .win)
                    boardRow(rank: "2", name: "金字塔", role: "先に行く同期", score: "95.1", kind: .plain)
                    boardRow(rank: "3", name: "あなたのコンビ", role: "決勝の舞台に立った", score: "94.8", kind: .me)
                }
            }
        } else {
            reachLadder
        }
    }

    // 到達回戦の階段（決勝未到達）
    private var reachLadder: some View {
        let reached = o?.roundsPassed ?? 0
        let steps = ["1回戦", "2回戦", "3回戦", "準々決勝", "準決勝", "決勝"]
        return VStack(spacing: 6) {
            ForEach(Array(steps.enumerated().reversed()), id: \.offset) { idx, name in
                let done = idx < reached
                let here = idx == reached
                HStack {
                    Text(here ? "▶ \(name)" : name)
                        .font(.maru(here ? 15 : 13))
                        .foregroundStyle(here ? Theme.gold : (done ? .white : Color(hex: 0x7A7290)))
                    Spacer()
                    Text(done ? "通過" : (here ? "ここまで" : "—"))
                        .font(.maru(11, weight: .bold))
                        .foregroundStyle(done ? Theme.cMental : (here ? Theme.verm : Color(hex: 0x5A5470)))
                }
                .padding(.horizontal, 13).padding(.vertical, 9)
                .background(here ? Color(hex: 0xE8402C, alpha: 0.18) : Color.white.opacity(done ? 0.10 : 0.03),
                           in: RoundedRectangle(cornerRadius: 11))
            }
        }
    }

    private enum RowKind { case win, me, plain }
    private func boardRow(rank: String, name: String, role: String, score: String, kind: RowKind) -> some View {
        HStack(spacing: 11) {
            Text(rank).font(.maru(17)).frame(width: 22)
                .foregroundStyle(kind == .win ? Color(hex: 0x7A5A06) : Color(hex: 0xCDBFE0))
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.maru(14)).foregroundStyle(kind == .me ? Color(hex: 0xFF9C8C) : (kind == .win ? Color(hex: 0x3A2A06) : .white))
                Text(role).font(.system(size: 10.5)).foregroundStyle(kind == .win ? Color(hex: 0x8A6A1A) : Color(hex: 0xB7A8CF))
            }
            Spacer()
            Text(score).font(.maru(15)).monospacedDigit()
                .foregroundStyle(kind == .win ? Color(hex: 0x7A5A06) : Color(hex: 0xCDBFE0))
        }
        .padding(.horizontal, 13).padding(.vertical, 11)
        .background(rowBG(kind), in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(kind == .me ? Theme.verm.opacity(0.6) : .clear, lineWidth: 1.5))
    }

    private func rowBG(_ kind: RowKind) -> some ShapeStyle {
        switch kind {
        case .win: return AnyShapeStyle(LinearGradient(colors: [Theme.gold, Theme.gold.opacity(0.5)], startPoint: .leading, endPoint: .trailing))
        case .me: return AnyShapeStyle(Theme.verm.opacity(0.18))
        case .plain: return AnyShapeStyle(Color.white.opacity(0.08))
        }
    }

    private var monolog: String {
        guard let o else { return "" }
        if o.champion { return "今年の頂点は——あなたたち。\n谷口が、はじめて言葉に詰まった。「……やったな」それだけ。" }
        if o.bankrupt { return "所持金が底をついた。\n谷口は笑って言った。「まあ、なんとかなるやろ」——今回は、ならなかった。" }
        if o.reachedFinal { return "今年の頂点は——静物画。0.3の差。\n谷口は、何も言わなかった。帰りの自販機の前で「来年な」と、それだけ。" }
        return "今年も、ここまで。\n谷口「来年の、いっちばん面白いネタの話、していい？」"
    }

    // 才能の灯り（【仮・TODO: 才能解放システム本実装】）
    private var unlockRow: some View {
        HStack(spacing: 9) {
            Text("✦").foregroundStyle(Theme.gold)
            Text("才能がひとつ灯った 〈来年の景色〉").font(.maru(13)).foregroundStyle(Theme.gold)
        }
        .frame(maxWidth: .infinity).padding(12)
        .background(LinearGradient(colors: [Theme.gold.opacity(0.22), Theme.gold.opacity(0.1)], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.gold.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
    }

    private var summaryStrip: some View {
        HStack(spacing: 0) {
            stat("所持金", "\(s.money / 10000)万")
            stat("知名度", "\(Int(s.fame))")
            stat("相性", "\(Int(s.compat))")
            stat("メンタル", "\(Int(s.メンタル))")
        }
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func stat(_ k: String, _ v: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.maru(15)).monospacedDigit().foregroundStyle(.white)
            Text(k).font(.system(size: 10)).foregroundStyle(Color(hex: 0xB7A8CF))
        }
        .frame(maxWidth: .infinity)
    }
}
