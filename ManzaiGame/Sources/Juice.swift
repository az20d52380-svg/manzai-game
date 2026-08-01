// Juice.swift
// 手応え（ジュース）の共通部品。View層のみ・golden非干渉。
// パーティクルの散らばりは UI 専用の決定論ハッシュ（sinフラクタル）＝GameCore の RandomSource は一切触らない。
// 使い方: .punch(on:) 値が変わった瞬間に跳ねる／ParticleBurst(trigger:) +1で一回爆ぜる／
//        .screenFlash(trigger:) 一瞬白む／.screenShake(trigger:) 画面が揺れる。
// 電池: バースト終了後は TimelineView を破棄（アイドル時の再描画コストゼロ）。

import SwiftUI

// MARK: 決定論ハッシュ（乱数の代わり・0..<1）

@inline(__always) private func jhash(_ n: Double) -> Double {
    let s = sin(n) * 43758.5453123
    return s - s.rounded(.down)
}

// MARK: パーティクルバースト

enum JuiceStyle {
    case spark      // 火花: 上方向に散って重力で落ちる（獲得の一拍）
    case confetti   // 紙吹雪: ゆっくり舞い落ちる（合格・優勝）
}

/// trigger を +1 すると一回爆ぜるエミッタ。親フレームの origin（UnitPoint）から放射。
/// 触れない（allowsHitTesting false）・終了後は TimelineView を自動破棄。
struct ParticleBurst: View {
    var trigger: Int
    var colors: [Color]
    var style: JuiceStyle = .spark
    var count: Int = 22
    var origin: UnitPoint = UnitPoint(x: 0.5, y: 0.72)

    @State private var burstStart: Date?
    @State private var burstSeq = 0

    private var life: Double { style == .spark ? 0.9 : 1.7 }

    var body: some View {
        GeometryReader { geo in
            if let start = burstStart, !colors.isEmpty {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
                    Canvas { ctx, size in
                        let t = tl.date.timeIntervalSince(start)
                        guard t >= 0, t < life else { return }
                        let ox = size.width * origin.x
                        let oy = size.height * origin.y
                        for i in 0..<count {
                            let seed = Double(i * 7919 + burstSeq * 104729)
                            let r1 = jhash(seed + 0.1), r2 = jhash(seed + 0.2)
                            let r3 = jhash(seed + 0.3), r4 = jhash(seed + 0.4)
                            let color = colors[i % colors.count]
                            switch style {
                            case .spark:
                                // 上向き±70°に射出→重力落下。後半で縮みつつ消える。
                                let ang = (-90.0 + (r1 - 0.5) * 140) * .pi / 180
                                let speed = 150 + r2 * 190
                                let x = ox + cos(ang) * speed * t
                                let y = oy + sin(ang) * speed * t + 0.5 * 520 * t * t
                                let p = t / life
                                let alpha = p < 0.55 ? 1.0 : max(0, 1 - (p - 0.55) / 0.45)
                                let rr = (2.2 + r3 * 2.6) * (1 - p * 0.45)
                                var rc = ctx
                                rc.opacity = alpha
                                if r4 < 0.30 {   // 3割は小さな回転する紙片（火花に混ざる賑やかし）
                                    rc.translateBy(x: x, y: y)
                                    rc.rotate(by: .radians(t * (2 + r4 * 8)))
                                    rc.fill(Path(CGRect(x: -rr, y: -rr * 0.6, width: rr * 2, height: rr * 1.2)),
                                            with: .color(color))
                                } else {
                                    rc.fill(Path(ellipseIn: CGRect(x: x - rr, y: y - rr, width: rr * 2, height: rr * 2)),
                                            with: .color(color))
                                }
                            case .confetti:
                                // 上に撒かれて→ヒラヒラ落ちる（横に揺れ・回転）。
                                let ang = (-90.0 + (r1 - 0.5) * 120) * .pi / 180
                                let speed = 90 + r2 * 150
                                let sway = sin(t * (3 + r3 * 4) + seed) * (14 + r4 * 18)
                                let x = ox + cos(ang) * speed * min(t, 0.35) + sway
                                let y = oy + sin(ang) * speed * min(t, 0.35) + 0.5 * 260 * t * t
                                let p = t / life
                                let alpha = p < 0.7 ? 1.0 : max(0, 1 - (p - 0.7) / 0.3)
                                let cw = 4.0 + r3 * 4
                                var rc = ctx
                                rc.opacity = alpha
                                rc.translateBy(x: x, y: y)
                                rc.rotate(by: .radians(t * (3 + r1 * 6) + seed))
                                // ヒラ感: 高さを sin で潰す（面の向きが変わって見える）
                                let ch = cw * 0.65 * abs(sin(t * (5 + r2 * 5) + seed))
                                rc.fill(Path(CGRect(x: -cw / 2, y: -ch / 2, width: cw, height: max(1.2, ch))),
                                        with: .color(color))
                            }
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            burstSeq += 1
            burstStart = Date()
            let seq = burstSeq
            Task {   // 終了後に TimelineView を破棄（新しいバーストが来ていたら触らない）
                try? await Task.sleep(nanoseconds: UInt64((life + 0.1) * 1_000_000_000))
                if burstSeq == seq { burstStart = nil }
            }
        }
    }
}

// MARK: 集中線（漫画の「ドン！」・獲得や決定的瞬間の一拍）

/// trigger を +1 すると 0.32s だけ放射状の集中線が走る。中心は UnitPoint 指定。
/// 線の角度・長さは決定論ハッシュ＝毎回同じ見え方（乱数不使用）。
struct SpeedLinesBurst: View {
    var trigger: Int
    var color: Color = Color(hex: 0x2C2740)
    var center: UnitPoint = .center

    @State private var start: Date?
    @State private var seq = 0
    private let life = 0.32

    var body: some View {
        GeometryReader { geo in
            if let s = start {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
                    Canvas { ctx, size in
                        let t = tl.date.timeIntervalSince(s)
                        guard t >= 0, t < life else { return }
                        let p = t / life
                        let alpha = (1 - p) * 0.5
                        let cx = size.width * center.x
                        let cy = size.height * center.y
                        let rMax = sqrt(size.width * size.width + size.height * size.height) * 0.62
                        for i in 0..<24 {
                            let fi = Double(i)
                            let a = fi / 24 * 2 * .pi + jhash(fi + 3.7) * 0.24
                            let r1 = rMax * (0.52 + 0.34 * jhash(fi + 0.5)) + p * 60   // 外側から内へ走り込む
                            let len = rMax * (0.10 + 0.10 * jhash(fi + 1.5)) * (1 - p)
                            var path = Path()
                            path.move(to: CGPoint(x: cx + cos(a) * r1, y: cy + sin(a) * r1))
                            path.addLine(to: CGPoint(x: cx + cos(a) * (r1 - len), y: cy + sin(a) * (r1 - len)))
                            ctx.stroke(path, with: .color(color.opacity(alpha)),
                                       style: StrokeStyle(lineWidth: (2.6 * (1 - p)) + 0.6, lineCap: .round))
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            seq += 1
            start = Date()
            let s = seq
            Task {
                try? await Task.sleep(nanoseconds: UInt64((life + 0.05) * 1_000_000_000))
                if seq == s { start = nil }
            }
        }
    }
}

// MARK: 値が変わった瞬間の跳ね（パンチ）

/// 監視値が変わった瞬間、scale 1→peak→1 のバネ。数字ピル・ゲージ・バッジの「効いた」の一拍。
private struct PunchModifier<T: Equatable>: ViewModifier {
    let value: T
    var peak: CGFloat = 1.22
    @State private var punched = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(punched ? peak : 1)
            .onChange(of: value) { _, _ in
                withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) { punched = true }
                Task {
                    try? await Task.sleep(nanoseconds: 140_000_000)
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.65)) { punched = false }
                }
            }
    }
}

extension View {
    /// 値が変わった瞬間に跳ねる（+Nの「効いた」を形にする）。
    func punch<T: Equatable>(on value: T, peak: CGFloat = 1.22) -> some View {
        modifier(PunchModifier(value: value, peak: peak))
    }
}

// MARK: 画面フラッシュ（決定的瞬間の白・押印の朱）

private struct ScreenFlashModifier: ViewModifier {
    let trigger: Int
    var color: Color = .white
    var strength: Double = 0.45
    @State private var opacity = 0.0
    func body(content: Content) -> some View {
        content.overlay {
            color.opacity(opacity).ignoresSafeArea().allowsHitTesting(false)
        }
        .onChange(of: trigger) { _, _ in
            opacity = strength
            withAnimation(.easeOut(duration: 0.32)) { opacity = 0 }
        }
    }
}

extension View {
    /// trigger +1 で一瞬白む（優勝=白・押印=朱など color 指定可）。
    func screenFlash(trigger: Int, color: Color = .white, strength: Double = 0.45) -> some View {
        modifier(ScreenFlashModifier(trigger: trigger, color: color, strength: strength))
    }
}

// MARK: 画面シェイク（判が叩きつけられる衝撃）

private struct ScreenShakeEffect: GeometryEffect {
    var intensity: CGFloat
    var animatableData: CGFloat   // trigger ごとに +1（整数間を補間して減衰揺れ）
    func effectValue(size: CGSize) -> ProjectionTransform {
        let p = animatableData - animatableData.rounded(.down)   // 0→1 の進行
        guard p > 0.001, p < 0.999 else { return ProjectionTransform(.identity) }
        let decay = (1 - p)
        let x = sin(p * .pi * 7) * intensity * decay
        let y = cos(p * .pi * 9) * intensity * 0.6 * decay
        return ProjectionTransform(CGAffineTransform(translationX: x, y: y))
    }
}

private struct ScreenShakeModifier: ViewModifier {
    let trigger: Int
    var intensity: CGFloat = 9
    @State private var phase: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .modifier(ScreenShakeEffect(intensity: intensity, animatableData: phase))
            .onChange(of: trigger) { _, _ in
                withAnimation(.linear(duration: 0.38)) { phase += 1 }
            }
    }
}

extension View {
    /// trigger +1 で減衰揺れ（合否押印・体調ダウンなど「衝撃」の瞬間だけ。多用しない）。
    func screenShake(trigger: Int, intensity: CGFloat = 9) -> some View {
        modifier(ScreenShakeModifier(trigger: trigger, intensity: intensity))
    }
}
