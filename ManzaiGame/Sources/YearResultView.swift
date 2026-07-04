// YearResultView.swift
// S6 年次リザルト（ui_design §4）のプレースホルダ。到達段階・年末サマリ・「もう一度」。

import SwiftUI
import GameCore

struct YearResultView: View {
    let session: GameSession
    var onRestart: () -> Void

    var body: some View {
        let s = session.state
        let o = session.outcome
        VStack(spacing: 20) {
            Spacer()
            Text(headline(o)).font(.largeTitle.bold())
            Text(reachLabel(o)).font(.title3).foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                row("最終所持金", yen(s.money))
                row("知名度", "\(Int(s.fame))")
                row("相性", "\(Int(s.compat))")
                row("メンタル", String(format: "%.1f", s.メンタル))
            }
            .font(.body.monospacedDigit())
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

            Text("この続き（10年のキャリア）は本編で。")
                .font(.footnote).foregroundStyle(.secondary)

            Button(action: onRestart) {
                Text("もう一度").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            Spacer()
        }
        .padding()
    }

    private func headline(_ o: YearOutcome?) -> String {
        guard let o else { return "1年目 終了" }
        if o.champion { return "🏆 優勝！" }
        if o.bankrupt { return "💸 夜逃げ" }
        return "1年目 終了"
    }

    private func reachLabel(_ o: YearOutcome?) -> String {
        guard let o else { return "" }
        if o.bankrupt { return "所持金が尽きてキャリア終了" }
        if o.reachedFinal { return "GP決勝の舞台に到達" }
        return "GP \(o.roundsPassed)回戦まで通過"
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack { Text(k); Spacer(); Text(v).bold() }.frame(width: 220)
    }

    private func yen(_ money: Int) -> String {
        String(format: "%.1f万", Double(money) / 10000)
    }
}
