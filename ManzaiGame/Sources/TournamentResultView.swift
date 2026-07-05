// TournamentResultView.swift
// SCREEN 02→03: 笑い波形メーター → 通過/敗退スタンプ → 半紙の紙講評（審査員1行＋星）。
// finals_direction の順序（波形→通過/敗退→講評）。判定は GameCore のまま・ここは表示のみ。

import SwiftUI
import GameCore

struct TournamentResultView: View {
    let session: GameSession
    let summary: WeekSummary

    @State private var revealed = false

    private var result: StageResult { summary.results.last ?? summary.results.first! }

    var body: some View {
        let r = result
        let review = JudgeData.review(passed: r.passed, state: summary.state, salt: summary.week)
        let stars = JudgeData.stars(summary.state)

        ScrollView {
            VStack(spacing: 14) {
                // ヘッダ
                Text("頂 グランプリ").font(.maru(12)).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 3)
                    .background(Theme.verm, in: Capsule())
                Text(r.name).font(.maru(22))
                Text("第\(summary.week)週 ・ 本番").font(.maru(12, weight: .bold)).foregroundStyle(Theme.inkDim)

                // 笑い波形
                WaveformView()

                Text(r.passed ? "——どっと沸いた！" : "——固い空気…")
                    .font(.maru(15)).foregroundStyle(r.passed ? Theme.verm : Theme.inkDim)
                    .frame(minHeight: 20)

                if revealed {
                    stamp(passed: r.passed)
                    washi(text: review.text, judge: review.judge, passed: r.passed)
                    starsRow(stars)
                    if r.prize > 0 {
                        Text("賞金 +\(r.prize / 10000)万 ↗").font(.maru(15)).monospacedDigit()
                            .foregroundStyle(Theme.cMental)
                    }
                    Button {
                        session.acknowledgeResult()
                    } label: {
                        Text("次へ ▶").font(.maru(15)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Theme.verm, in: RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(.plain).padding(.horizontal, 40).padding(.top, 4)
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [Color(hex: 0xFFEAD8), Color(hex: 0xFFF3E4)],
                                   startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(1.6)) {
                revealed = true
            }
        }
    }

    private func stamp(passed: Bool) -> some View {
        let c = passed ? Theme.cMental : Theme.verm
        return Text(passed ? "通過" : "敗退")
            .font(.maru(30)).foregroundStyle(.white)
            .frame(width: 108, height: 108)
            .background(RadialGradient(colors: [c.opacity(0.9), c], center: .topLeading, startRadius: 5, endRadius: 120),
                       in: Circle())
            .rotationEffect(.degrees(-8))
            .shadow(color: c.opacity(0.5), radius: 12, y: 8)
            .scaleEffect(revealed ? 1 : 1.8)
            .opacity(revealed ? 1 : 0)
    }

    private func washi(text: String, judge: String, passed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("審 査 講 評").font(.maru(11)).tracking(6).foregroundStyle(Color(hex: 0xA98B52))
                .frame(maxWidth: .infinity).padding(.bottom, 12)
            Text(text)
                .font(.system(size: 15, design: .serif))
                .lineSpacing(7).foregroundStyle(Color(hex: 0x33301F))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("審査員　\(judge)").font(.maru(12, weight: .bold)).foregroundStyle(Color(hex: 0xA98B52))
                .frame(maxWidth: .infinity, alignment: .trailing).padding(.top, 14)
        }
        .padding(22)
        .background(LinearGradient(colors: [Color(hex: 0xFDFBF4), Color(hex: 0xF6EEDC)],
                                   startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0xE6D9BE), lineWidth: 1))
        .overlay(alignment: .bottomTrailing) {
            Text(passed ? "通過" : "敗退").font(.maru(12)).foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(passed ? Theme.cMental : Theme.verm, in: RoundedRectangle(cornerRadius: 8))
                .rotationEffect(.degrees(-6))
                .padding(14)
        }
        .shadow(color: Color(hex: 0x785014, alpha: 0.3), radius: 14, y: 8)
    }

    private func starsRow(_ stars: [(String, Int)]) -> some View {
        HStack(spacing: 6) {
            ForEach(stars, id: \.0) { s in
                HStack(spacing: 3) {
                    Text(s.0).font(.maru(11)).foregroundStyle(Theme.inkDim)
                    Text(starString(s.1)).font(.system(size: 11)).foregroundStyle(Theme.goldD)
                }
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.line, lineWidth: 1.5))
            }
        }
    }

    private func starString(_ n: Int) -> String {
        String(repeating: "★", count: n) + String(repeating: "☆", count: max(0, 5 - n))
    }
}
