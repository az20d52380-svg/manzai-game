// TournamentResultView.swift
// S3 大会画面の「結果」パート（ui_design §3-3）。通過/敗退スタンプ→紙講評1行→賞金増分。
// 紙講評テキストは judge_design §8/§9 に従い UI層（本ファイル）が持つ（GameCoreは判定のみ）。数値・文言は全て仮。

import SwiftUI
import GameCore

struct TournamentResultView: View {
    let session: GameSession
    let summary: WeekSummary

    @State private var revealed = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("第\(summary.week)週").font(.subheadline).foregroundStyle(.secondary)

            ForEach(Array(summary.results.enumerated()), id: \.offset) { _, r in
                resultCard(r)
            }

            Spacer()
            Button {
                session.acknowledgeResult()
            } label: {
                Text("次へ ▶").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            Spacer().frame(height: 20)
        }
        .padding()
        .onAppear {
            // 溜め（§3-3）: スタンプを一拍おいて出す
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.4)) {
                revealed = true
            }
        }
    }

    private func resultCard(_ r: StageResult) -> some View {
        VStack(spacing: 16) {
            Text(r.name).font(.title3.weight(.semibold))

            // 通過/敗退スタンプ（溜めてから拡大表示）
            Text(r.passed ? "通過" : "敗退")
                .font(.system(size: 56, weight: .heavy))
                .foregroundStyle(r.passed ? .green : .red)
                .padding(.horizontal, 28).padding(.vertical, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(r.passed ? .green : .red, lineWidth: 4)
                )
                .rotationEffect(.degrees(revealed ? -8 : -30))
                .scaleEffect(revealed ? 1 : 1.8)
                .opacity(revealed ? 1 : 0)

            // 紙講評1行（必ず「直せる一点」を含む・judge_design §8/10-A）
            Text(comment(for: r))
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .opacity(revealed ? 1 : 0)

            if r.prize > 0 {
                Text("賞金 +\(r.prize / 10000)万 ↗")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.green)
                    .opacity(revealed ? 1 : 0)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
    }

    /// 紙講評プール（judge_design §8）。体力低の敗退にはフックを優先適用。
    private func comment(for r: StageResult) -> String {
        if r.passed {
            return Self.passComments[summary.week % Self.passComments.count]
        }
        if session.state.stamina < 20 {
            return "後半の失速が惜しい。コンディション管理も芸のうち。"
        }
        return Self.failComments[summary.week % Self.failComments.count]
    }

    private static let passComments = [
        "つかみ良し。次はネタの後半に山をもう一つ。",
        "声が会場に合っていた。この調子で。",
        "設定の発明あり。磨けば武器になる。",
    ]
    private static let failComments = [
        "4分の配分に難。前半に詰め込みすぎ。",
        "ボケの手数不足。テンポは良い。",
        "二人の関係がネタに乗っていない。",
    ]
}
