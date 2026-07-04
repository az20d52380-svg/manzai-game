// WeekMainView.swift
// S2 週メイン画面（ui_design §2）のプレースホルダ。状態ヘッダ＋Phase別の行動ボタン。
// 効果量は事前表示しない（§2「考える楽しみ」）。数値・文言は全て仮。

import SwiftUI
import GameCore

struct WeekMainView: View {
    @Bindable var session: GameSession

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            eventArea
            Divider()
            ScrollView { actionArea.padding() }
            Divider()
            logArea
        }
    }

    // MARK: ヘッダ（週・季節／所持金・体力・知名度・相性）

    private var header: some View {
        let s = session.state
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("第\(session.week)週 / \(seasonLabel(session.week))")
                    .font(.headline.monospacedDigit())
                Spacer()
                Text("\(session.year)年目").foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                Label("\(yen(s.money))", systemImage: "yensign.circle")
                    .foregroundStyle(s.money < 0 ? .red : .primary)
                staminaBar(s.stamina)
            }
            .font(.subheadline.monospacedDigit())
            HStack(spacing: 16) {
                Text("★ 知名度 \(Int(s.fame))")
                Text("♥ 相性 \(Int(s.compat))")
            }
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func staminaBar(_ v: Double) -> some View {
        // 体力の色: 緑→黄(50)→赤(30)（§6・本番ペナルティ閾値と一致）
        let color: Color = v < 30 ? .red : (v < 50 ? .yellow : .green)
        return HStack(spacing: 6) {
            Image(systemName: "bolt.fill").foregroundStyle(color)
            ProgressView(value: max(0, min(100, v)), total: 100)
                .tint(color)
                .frame(width: 90)
            Text("\(Int(v))")
        }
    }

    // MARK: イベント領域（オファーやGP回戦名など）

    @ViewBuilder private var eventArea: some View {
        switch session.phase {
        case .freeAction(let offer?):
            banner("📩 オファー: \(offer.name)", .blue)
        case .tournamentDecision(let spec):
            banner("🏆 \(spec.name)（第\(spec.week)週）", .orange)
        case .gpRound(_, let name):
            banner("🎤 \(name)", .purple)
        case .gpRevival:
            banner("🎤 敗者復活", .purple)
        case .gpFinal:
            banner("🎤 GP決勝", .pink)
        default:
            Color.clear.frame(height: 0)
        }
    }

    private func banner(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal).padding(.vertical, 10)
            .background(color.opacity(0.12))
    }

    // MARK: 行動領域（Phase別）

    @ViewBuilder private var actionArea: some View {
        switch session.phase {
        case .freeAction(let offer):
            freeActions(offer: offer)
        case .tournamentDecision(let spec):
            tournamentActions(spec)
        case .gpRound, .gpRevival, .gpFinal:
            Button {
                session.advanceAuto()
            } label: {
                Text("続ける ▶").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        default:
            ProgressView()
        }
    }

    private func freeActions(offer: OfferSpec?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let offer {
                Button {
                    session.choose(.acceptOffer)
                } label: {
                    Text("仕事を受ける（\(offer.name)）").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            actionGroup("稽古", Training.allCases.map { t in
                let cost = session.config.trainings[t]?.cost ?? 0
                return (label: "\(t)\(cost > 0 ? " ¥\(cost / 10000)万" : "")",
                        disabled: cost > 0 && session.state.money < cost,
                        action: { session.choose(.train(t)) })
            })
            actionGroup("バイト", Job.allCases.map { j in
                (label: "\(j)", disabled: false, action: { session.choose(.job(j)) })
            })
            actionGroup("休む", Rest.allCases.map { r in
                (label: "\(r)", disabled: false, action: { session.choose(.rest(r)) })
            })
        }
    }

    private func tournamentActions(_ spec: TournamentSpec) -> some View {
        VStack(spacing: 12) {
            if spec.osaka {
                // 大阪遠征: お金で安全を買う唯一の瞬間（§3）
                bigButton("🚌 夜行バスで出場") { session.decideTournament(.夜行バス) }
                bigButton("🚄 新幹線で出場") { session.decideTournament(.新幹線) }
            } else {
                bigButton("出場する") { session.decideTournament(.夜行バス) } // 東京開催は交通手段無視
            }
            Button("見送る") { session.decideTournament(nil) }
                .controlSize(.large)
        }
    }

    private func actionGroup(_ title: String,
                             _ items: [(label: String, disabled: Bool, action: () -> Void)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.bold)).foregroundStyle(.secondary)
            FlowButtons(items: items)
        }
    }

    private func bigButton(_ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(label).frame(maxWidth: .infinity) }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
    }

    // MARK: ログ（直近の週結果）

    private var logArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(session.log.suffix(4).enumerated()), id: \.offset) { _, line in
                    Text(line).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
        }
        .frame(height: 74)
    }

    // MARK: 表示ヘルパ

    private func yen(_ money: Int) -> String {
        let man = Double(money) / 10000
        return String(format: "%.1f万", man)
    }

    private func seasonLabel(_ week: Int) -> String {
        // 第1週=4月。4週で1ヶ月（48週=12ヶ月）
        let monthIndex = max(0, week - 1) / 4          // 0...11
        let month = (3 + monthIndex) % 12 + 1          // 4月始まり
        let season: String
        switch month {
        case 3...5: season = "春"
        case 6...8: season = "夏"
        case 9...11: season = "秋"
        default: season = "冬"
        }
        return "\(month)月・\(season)"
    }
}

/// ボタンを横に流し込む簡易フロー（プレースホルダ用）
private struct FlowButtons: View {
    let items: [(label: String, disabled: Bool, action: () -> Void)]

    var body: some View {
        let cols = [GridItem(.adaptive(minimum: 110), spacing: 8)]
        LazyVGrid(columns: cols, alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Button(action: item.action) {
                    Text(item.label).frame(maxWidth: .infinity).lineLimit(1)
                }
                .buttonStyle(.bordered)
                .disabled(item.disabled)
            }
        }
    }
}
