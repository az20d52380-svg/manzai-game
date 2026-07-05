// StageViews.swift
// 大会まわりの入口・本番前カード・笑い波形メーター（mockup SCREEN 02）。
// 判定ロジックは GameCore のまま（絶対評価ライン）。ここは表示・演出だけ。

import SwiftUI
import GameCore

// MARK: 笑い波形メーター（mockupのcanvasをCanvasで再現）

struct WaveformView: View {
    /// 結果連動: 通過=暖色で大きく育ちオチで跳ねる／敗退=寒色でフラット・疎ら（mvp §7）
    var passed: Bool = true

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let W = size.width, H = size.height, mid = H / 2
                // 中心線
                var base = Path()
                base.move(to: CGPoint(x: 0, y: mid)); base.addLine(to: CGPoint(x: W, y: mid))
                ctx.stroke(base, with: .color(Color(hex: 0x2C2740, alpha: 0.08)), lineWidth: 1)

                let warm = [Theme.gold, Theme.cExpr, Theme.verm]
                let cold = [Color(hex: 0x9AA0AE), Color(hex: 0x7C8394)]
                let grad = GraphicsContext.Shading.linearGradient(
                    Gradient(colors: passed ? warm : cold),
                    startPoint: .zero, endPoint: CGPoint(x: W, y: 0))

                func env(_ x: Double) -> Double {
                    if !passed { return 0.10 + 0.06 * sin(x * 8) }   // 敗退: フラットで疎ら
                    let b = 0.16 + 0.5 * x
                    let punch = exp(-pow((x - 0.83) / 0.06, 2)) * 0.95
                    return min(1, b + punch)
                }
                var top = Path()
                var i: CGFloat = 0
                while i <= W {
                    let x = Double(i / W)
                    let a = env(x)
                    let jit = sin(Double(i) * 0.5 + t * 6) * a * 3
                    let y = Double(mid) - (a * Double(mid - 10)) * (0.5 + 0.5 * abs(sin(Double(i) * 0.4 + t * 5))) - jit
                    let p = CGPoint(x: i, y: y)
                    if i == 0 { top.move(to: p) } else { top.addLine(to: p) }
                    i += 3
                }
                ctx.stroke(top, with: grad, style: StrokeStyle(lineWidth: 3, lineJoin: .round))

                var bottom = Path()
                i = 0
                while i <= W {
                    let x = Double(i / W)
                    let a = env(x)
                    let y = Double(mid) + (a * Double(mid - 10)) * (0.5 + 0.5 * abs(sin(Double(i) * 0.4 + t * 5)))
                    let p = CGPoint(x: i, y: y)
                    if i == 0 { bottom.move(to: p) } else { bottom.addLine(to: p) }
                    i += 3
                }
                ctx.opacity = 0.4
                ctx.stroke(bottom, with: grad, style: StrokeStyle(lineWidth: 3, lineJoin: .round))
            }
        }
        .frame(height: 104)
        .overlay(alignment: .bottom) {
            HStack {
                Text("ツカミ"); Spacer(); Text("中盤"); Spacer(); Text("オチ")
            }
            .font(.maru(10)).foregroundStyle(Theme.inkFaint).offset(y: 14)
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 2))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 8)
    }
}

// MARK: 大会入口（遠征選択・道中大会）

struct TournamentEntryView: View {
    @Bindable var session: GameSession
    let spec: TournamentSpec

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Text(spec.osaka ? "大阪遠征" : "エントリー").font(.maru(12)).foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 3)
                .background(Theme.verm, in: Capsule())
            Text(spec.name).font(.maru(24))
            Text("第\(spec.week)週 ・ 通過ライン \(Int(spec.line)) ・ 賞金 \(spec.prize / 10000)万")
                .font(.maru(12, weight: .bold)).foregroundStyle(Theme.inkDim)

            Spacer()
            VStack(spacing: 10) {
                if spec.osaka {
                    entryButton("🚌 夜行バスで出場", sub: "安い・体力を使う") { session.decideTournament(.夜行バス) }
                    entryButton("🚄 新幹線で出場", sub: "高い・体力温存") { session.decideTournament(.新幹線) }
                } else {
                    entryButton("出場する", sub: "東京開催") { session.decideTournament(.夜行バス) }
                }
                Button("見送る") { session.decideTournament(nil) }
                    .font(.maru(13)).foregroundStyle(Theme.inkDim).padding(.top, 2)
            }
            .padding(.horizontal, 28)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [Color(hex: 0xFFE0D6), Color(hex: 0xFFF3E4)],
                                   startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }

    private func entryButton(_ title: String, sub: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title).font(.maru(15)).foregroundStyle(.white)
                Text(sub).font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(Theme.verm, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: Theme.vermD.opacity(0.5), radius: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: GP本番前カード（回戦・敗者復活・決勝の「本番へ」）

struct StagePreludeView: View {
    @Bindable var session: GameSession
    let title: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("頂 グランプリ").font(.maru(12)).foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 3)
                .background(Theme.verm, in: Capsule())
            Text(title).font(.maru(26))
            Text("本番").font(.maru(13, weight: .bold)).foregroundStyle(Theme.inkDim)
            Spacer()
            Button {
                session.advanceAuto()
            } label: {
                Text("本番へ ▶").font(.maru(16)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(Theme.verm, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain).padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [Color(hex: 0xFFE0D6), Color(hex: 0xFFF3E4)],
                                   startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }
}
