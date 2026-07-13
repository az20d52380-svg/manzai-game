// TournamentResultView.swift
// SCREEN 02→03: 笑い波形メーター → 通過/敗退スタンプ → 半紙の紙講評（審査員1行＋星）。
// finals_direction の順序（波形→通過/敗退→講評）。判定は GameCore のまま・ここは表示のみ。

import SwiftUI
import GameCore

struct TournamentResultView: View {
    let session: GameSession
    let summary: WeekSummary

    @State private var revealed = false        // 判（押印）
    @State private var revealedReview = false  // 講評（判の0.4s後）
    @State private var revealedRest = false    // 星・賞金・次へ（さらに0.6s後）＝段階的な情報開示（§2-3）

    private var result: StageResult { summary.results.last ?? summary.results.first! }
    /// この本番が道中大会（単発6種）か。道中週とGP週は重ならないので週で判別（名前ヒューリスティックを避ける）。
    private var isMidTournament: Bool { session.config.calendar.tournament(inWeek: summary.week) != nil }
    /// 結果スタンプの語。道中は単発コンテスト（入賞/敗退）、GPは回戦（通過/敗退）。判定は不変・語だけの演出的合成（⑬）。
    private func stampLabel(passed: Bool) -> String {
        if isMidTournament { return passed ? "入賞" : "敗退" }
        return passed ? "通過" : "敗退"
    }

    var body: some View {
        let r = result
        let review = JudgeData.review(passed: r.passed, state: summary.state, salt: summary.week)
        let stars = JudgeData.stars(summary.state)

        ScrollView {
            VStack(spacing: 14) {
                // ヘッダ（道中大会は「頂グランプリ」帯を出さない＝大会名 r.name が主題。GP系のみ帯を出す＝⑫）
                if !isMidTournament {
                    Text("頂 グランプリ").font(.maru(12)).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 3)
                        .background(Theme.verm, in: Capsule())
                }
                Text(r.name).font(.maru(22))
                Text("第\(summary.week)週 ・ 本番").font(.maru(12, weight: .bold)).foregroundStyle(Theme.inkDim)

                // 笑い波形（結果連動）
                WaveformView(passed: r.passed)

                Text(r.passed ? "——どっと沸いた！" : "——固い空気…")
                    .font(.maru(15)).foregroundStyle(r.passed ? Theme.verm : Theme.inkDim)
                    .frame(minHeight: 20)

                if revealed {
                    stamp(passed: r.passed)
                }
                if revealedReview {
                    washi(text: review.text, judge: review.judge, passed: r.passed)
                        .transition(.opacity)
                }
                if revealedRest {
                    starsRow(stars).transition(.opacity)
                    if r.prize > 0 {
                        Text("賞金 +\(r.prize / 10000)万 ↗").font(.maru(15)).monospacedDigit()
                            .foregroundStyle(Theme.cMental).transition(.opacity)
                    }
                    Button {
                        session.acknowledgeResult()
                    } label: {
                        Text("次へ ▶").font(.maru(15)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Theme.verm, in: RoundedRectangle(cornerRadius: Theme.Rad.btn))
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.horizontal, 40).padding(.top, 4)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [Color(hex: 0xFFEAD8), Color(hex: 0xFFF3E4)],
                                   startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .onAppear {
            Task {
                // 波形の余韻＋開示前の静止0.3s（溜め→開示の最小単位・§4-2a）を含む1.6s
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                withAnimation(.easeOut(duration: 0.2)) { revealed = true }   // 判の押印（§3-5: 1.3→1.0）
                Haptics.confirm()                                            // 合否押印=hConfirm
                try? await Task.sleep(nanoseconds: 400_000_000)
                withAnimation(.easeOut(duration: 0.25)) { revealedReview = true }
                try? await Task.sleep(nanoseconds: 600_000_000)
                withAnimation(.easeOut(duration: 0.25)) { revealedRest = true }
            }
        }
    }

    /// 判（§3-5）: 角判rStamp・縁2pt。通過=verm／敗退=ink——色でなく重さの差（負けにも勝ちと同じ物量）。
    private func stamp(passed: Bool) -> some View {
        let c = passed ? Theme.verm : Theme.ink
        return Text(stampLabel(passed: passed))
            .font(.maru(30)).foregroundStyle(.white)
            .frame(width: 108, height: 108)
            .background(RadialGradient(colors: [c.opacity(0.88), c], center: .topLeading, startRadius: 5, endRadius: 120),
                       in: RoundedRectangle(cornerRadius: Theme.Rad.stamp))
            .overlay(RoundedRectangle(cornerRadius: Theme.Rad.stamp).stroke(.white.opacity(0.55), lineWidth: 2).padding(5))
            .rotationEffect(.degrees(-4))
            .shadow(color: c.opacity(0.4), radius: 12, y: 8)
            .scaleEffect(revealed ? 1 : 1.3)
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
            // 講評フッタ: 審査員名は左・スタンプは右で被らせない（mvp §8）
            HStack(alignment: .bottom) {
                Text("審査員　\(judge)").font(.maru(12.5, weight: .bold)).foregroundStyle(Color(hex: 0xA98B52))
                Spacer(minLength: 8)
                Text(stampLabel(passed: passed)).font(.maru(12)).foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(passed ? Theme.verm : Theme.ink, in: RoundedRectangle(cornerRadius: Theme.Rad.stamp))
                    .rotationEffect(.degrees(-4))
            }
            .padding(.top, 16)
        }
        .padding(22)
        .background(LinearGradient(colors: [Color(hex: 0xFDFBF4), Color(hex: 0xF6EEDC)],
                                   startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0xE6D9BE), lineWidth: 1))
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
