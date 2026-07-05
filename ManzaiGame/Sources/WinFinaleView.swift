// WinFinaleView.swift
// 「勝ち版」決勝演出（既存の負け版＝YearResultViewの惜敗の対）。
// finals_direction §2-3 の優勝段: 笑い波形が大きく跳ねる→優勝スタンプ（紙吹雪）→谷口の耳打ち→才能解放の祝い→S4ボード。
// 設計原則: ゲームは一切ボケない／笑いは波形で見せる／誰に勝ったかは次のS4順位ボードで出す。

import SwiftUI
import GameCore

struct WinFinaleView: View {
    let session: GameSession
    @State private var revealed = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x2C2740), Color(hex: 0x4A2F52), Color(hex: 0x5A3A1A)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            if revealed { ConfettiView().ignoresSafeArea().allowsHitTesting(false) }

            ScrollView {
                VStack(spacing: 16) {
                    Text("頂 グランプリ ・ 決勝").font(.maru(12)).tracking(2).foregroundStyle(Theme.gold)

                    // 笑い波形（大きく跳ねる）
                    WaveformView().padding(.top, 4)
                    Text("——満場、どっと沸いた！！")
                        .font(.maru(16)).foregroundStyle(Theme.gold).frame(minHeight: 22)

                    if revealed {
                        // 優勝スタンプ
                        Text("優勝")
                            .font(.maru(34)).foregroundStyle(Color(hex: 0x5A3A06))
                            .frame(width: 128, height: 128)
                            .background(RadialGradient(colors: [Color(hex: 0xFFE07A), Theme.gold], center: .topLeading, startRadius: 5, endRadius: 140), in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 3))
                            .rotationEffect(.degrees(-8))
                            .shadow(color: Theme.gold.opacity(0.7), radius: 20, y: 8)
                            .scaleEffect(revealed ? 1 : 1.8)

                        // 谷口の一瞬（口癖はここに温存＝dialogue_design §6・年1回の感情最大点）
                        Text("谷口が、そっと耳打ちした。\n「……なあ、腹減ったな」")
                            .font(.system(size: 14, design: .serif)).lineSpacing(6)
                            .foregroundStyle(Color(hex: 0xEDE3FF))
                            .multilineTextAlignment(.center)
                            .padding(14)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))

                        // 才能解放の祝い
                        HStack(spacing: 9) {
                            Text("✦").foregroundStyle(Theme.gold)
                            Text("才能が解放された 〈十年目の景色〉").font(.maru(13)).foregroundStyle(Theme.gold)
                        }
                        .frame(maxWidth: .infinity).padding(13)
                        .background(LinearGradient(colors: [Theme.gold.opacity(0.28), Theme.gold.opacity(0.12)], startPoint: .leading, endPoint: .trailing),
                                    in: RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.gold.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))

                        Button {
                            session.acknowledgeWin()
                        } label: {
                            Text("結果を見る ▶").font(.maru(16)).foregroundStyle(Color(hex: 0x5A3A06))
                                .frame(maxWidth: .infinity).padding(.vertical, 13)
                                .background(Theme.gold, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain).padding(.horizontal, 30).padding(.top, 4)
                    }
                }
                .padding(.horizontal, 18).padding(.vertical, 26)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55).delay(1.3)) {
                revealed = true
            }
        }
    }
}

/// 軽量な紙吹雪（決定的な位置・prefers-reduced-motionは静止）
private struct ConfettiView: View {
    private let pieces = 26
    private let palette: [Color] = [Theme.gold, Theme.verm, Theme.cSense, Theme.cChara, Theme.cMental, Theme.cIdea]

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                for i in 0..<pieces {
                    let seed = Double(i)
                    let x = (sin(seed * 12.9898) * 0.5 + 0.5) * size.width
                    let speed = 40 + (i % 5) * 14
                    let y = (Double(speed) * t + seed * 47).truncatingRemainder(dividingBy: Double(size.height + 40)) - 20
                    let rot = t * 2 + seed
                    let c = palette[i % palette.count]
                    var rect = Path(CGRect(x: -4, y: -6, width: 8, height: 12))
                    rect = rect.applying(CGAffineTransform(rotationAngle: rot))
                        .applying(CGAffineTransform(translationX: x, y: y))
                    ctx.fill(rect, with: .color(c.opacity(0.9)))
                }
            }
        }
    }
}
