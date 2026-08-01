// StageScene.swift
// 育成メインの「舞台」シーン（View層のみ・golden非干渉）。
// 従来のベタ塗りグラデ＋カプセル人形を、劇場の空気に置き換える:
//   暗幕（緞帳の襞）→ 板張りの床（消失点パース）→ スポットライトの光柱と光溜まり →
//   センターマイク → 漫才師2人の逆光シルエット（呼吸・揺れ）→ 光の中を舞う塵 → ビネット。
// 立ち絵イラストが入るまでの「絵が無くても舞台に見える」到達点。数値は全て【仮】。
// パフォーマンス: 塵は TimelineView(1/20s)＋Canvas の16粒のみ・他は静的レイヤ＝再描画コスト極小。

import SwiftUI

struct StageScene: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let horizon = h * 0.56            // 暗幕と床の境
            let micX = w * 0.62               // センターマイクの立ち位置（左下は台詞の席なので右寄り）
            let footY = h - h * 0.055         // 二人の足元（下端から少し浮かせて床の広がりを見せる）
            let figH = max(150, h * 0.30)     // 人物は画面比で決める（小さいと舞台が空く）

            ZStack {
                // 1) 客席の闇（上ほど深い夜）
                LinearGradient(colors: [Color(hex: 0x120D22), Color(hex: 0x241633), Color(hex: 0x3A2138)],
                               startPoint: .top, endPoint: .bottom)

                // 2) 緞帳（襞のある幕・深い臙脂）
                curtain(width: w, height: horizon)
                    .frame(height: horizon)
                    .position(x: w / 2, y: horizon / 2)

                // 3) 板張りの床（消失点パース）
                floorBoards(width: w, height: h - horizon, vanishX: micX)
                    .frame(height: h - horizon)
                    .position(x: w / 2, y: horizon + (h - horizon) / 2)

                // 4) スポットライトの光柱（主役。ハッキリ見える一本＋淡い副灯）
                lightCone(from: CGPoint(x: micX + w * 0.02, y: -h * 0.06),
                          to: CGPoint(x: micX, y: footY - h * 0.05), spread: w * 0.21)
                    .fill(LinearGradient(colors: [Color(hex: 0xFFEDCB).opacity(0.42),
                                                  Color(hex: 0xFFE3B4).opacity(0.18),
                                                  Color(hex: 0xFFE3B4).opacity(0.05)],
                                         startPoint: .top, endPoint: .bottom))
                    .blur(radius: 10)
                lightCone(from: CGPoint(x: micX - w * 0.20, y: -h * 0.08),
                          to: CGPoint(x: micX - 20, y: footY - h * 0.06), spread: w * 0.12)
                    .fill(LinearGradient(colors: [Color(hex: 0xFFDFAF).opacity(0.14), .clear],
                                         startPoint: .top, endPoint: .bottom))
                    .blur(radius: 16)

                // 4.5) 舞台奥の際（幕と床の境の影＝空間の折り目）
                Rectangle()
                    .fill(Color(hex: 0x140A0E).opacity(0.55))
                    .frame(height: h * 0.025)
                    .blur(radius: 4)
                    .position(x: w / 2, y: horizon)

                // 5) 床の光溜まり（楕円・二人とマイクの足元。暗い床とのコントラストが「当たってる」感の芯）
                Ellipse()
                    .fill(RadialGradient(colors: [Color(hex: 0xFFEDCB).opacity(0.46),
                                                  Color(hex: 0xFFCF8E).opacity(0.14), .clear],
                                         center: .center, startRadius: 8, endRadius: w * 0.32))
                    .frame(width: w * 0.64, height: h * 0.16)
                    .position(x: micX, y: footY - 4)

                // 5.5) 床の両袖を沈める（光の一点集中＝舞台の暗がり）
                HStack(spacing: 0) {
                    LinearGradient(colors: [Color(hex: 0x0D0918).opacity(0.72), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: w * 0.30)
                    Spacer(minLength: 0)
                    LinearGradient(colors: [.clear, Color(hex: 0x0D0918).opacity(0.62)],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: w * 0.22)
                }
                .frame(height: h - horizon)
                .position(x: w / 2, y: horizon + (h - horizon) / 2)

                // 6) 塵（光の柱の中をゆっくり舞う・16粒）
                DustField(centerX: micX, spread: w * 0.30)
                    .allowsHitTesting(false)

                // 7) 逆光の暖ハロー（二人の背にまわる光）
                Ellipse()
                    .fill(Color(hex: 0xFFC98A).opacity(0.26))
                    .frame(width: figH * 2.3, height: figH * 1.7)
                    .blur(radius: 30)
                    .position(x: micX, y: footY - figH * 0.62)

                // 8) センターマイク＋漫才師2人（シルエット・呼吸）。大きさは画面比＝空間を支配する主役
                CenterMic(height: figH * 0.78)
                    .position(x: micX, y: footY - figH * 0.39)
                ManzaiFigure(height: figH * 0.90, tilt: 2.2, accent: Color(hex: 0x3B6FE0),
                             breathe: 3.1)
                    .position(x: micX - figH * 0.52, y: footY - figH * 0.45)
                ManzaiFigure(height: figH, tilt: -2.6, accent: Color(hex: 0xE8402C),
                             breathe: 2.4)
                    .position(x: micX + figH * 0.54, y: footY - figH * 0.50)

                // 9) ビネット（四隅をしっかり落として視線を光へ）
                RadialGradient(colors: [.clear, .clear, Color(hex: 0x0D0918).opacity(0.85)],
                               center: UnitPoint(x: 0.58, y: 0.72),
                               startRadius: w * 0.20, endRadius: w * 0.90)

                // 10) 舞台の縁（最下端の細い金トリム＝下の手元ゾーンとの境）
                VStack { Spacer()
                    Rectangle().fill(LinearGradient(colors: [Theme.gold.opacity(0.0), Theme.gold.opacity(0.55), Theme.gold.opacity(0.0)],
                                                    startPoint: .leading, endPoint: .trailing))
                        .frame(height: 2)
                }
            }
        }
    }

    /// 緞帳: 襞（垂直ストライプの明暗）＋上端の影。深紅は Theme.verm 系に寄せず臙脂で沈める（主役は光）。
    private func curtain(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Color(hex: 0x421A29)
            HStack(spacing: 0) {
                ForEach(0..<14, id: \.self) { i in
                    LinearGradient(colors: [Color(hex: 0x4E2030), Color(hex: 0x35141F)],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: width / 14)
                        .opacity(i.isMultiple(of: 2) ? 1 : 0.65)
                }
            }
            // 幕の上端は暗く（照明が届かない）
            LinearGradient(colors: [Color(hex: 0x0D0918).opacity(0.8), .clear],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: height * 0.5)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .clipped()
    }

    /// 板張りの床: 縦グラデ＋消失点へ収束する目地。
    private func floorBoards(width: CGFloat, height: CGFloat, vanishX: CGFloat) -> some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x332014), Color(hex: 0x1E120C), Color(hex: 0x120A06)],
                           startPoint: .top, endPoint: .bottom)
            Canvas { ctx, size in
                let vanish = CGPoint(x: vanishX, y: -size.height * 0.6)   // 消失点は幕の奥
                // 縦目地（奥へ収束）
                for i in 0...10 {
                    let bx = size.width * CGFloat(i) / 10
                    var p = Path()
                    p.move(to: CGPoint(x: bx, y: size.height))
                    p.addLine(to: vanish)
                    ctx.stroke(p, with: .color(.black.opacity(0.13)), lineWidth: 1)
                }
                // 横目地（奥ほど詰まる）
                for j in 1...4 {
                    let t = CGFloat(j) / 4.5
                    let y = size.height * (1 - t * t)
                    var p = Path()
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(p, with: .color(.black.opacity(0.09)), lineWidth: 1)
                }
            }
        }
        .clipped()
    }

    /// スポットライトの光柱（台形パス）。
    private func lightCone(from top: CGPoint, to bottom: CGPoint, spread: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: top.x - 16, y: top.y))
        p.addLine(to: CGPoint(x: top.x + 16, y: top.y))
        p.addLine(to: CGPoint(x: bottom.x + spread, y: bottom.y))
        p.addLine(to: CGPoint(x: bottom.x - spread, y: bottom.y))
        p.closeSubpath()
        return p
    }
}

// MARK: 漫才師のシルエット（逆光・呼吸・揺れ）

/// 頭＋外套気味の胴＋（片方だけ）ツッコミの腕。塗りは夜のインク＝逆光の影。
/// accent は首元の細いマフラー1本だけ（俺=青/谷口=朱の記号を最小で残す）。
struct ManzaiFigure: View {
    let height: CGFloat
    let tilt: Double            // 相方へ僅かに傾く（度）
    let accent: Color
    let breathe: Double         // 呼吸周期（秒・二人で別＝機械感を消す）
    @State private var inhale = false

    var body: some View {
        let bodyW = height * 0.48
        let bodyH = height * 0.72
        let headR = height * 0.30
        ZStack(alignment: .bottom) {
            // 足元の影
            Ellipse().fill(.black.opacity(0.32))
                .frame(width: bodyW * 1.35, height: 10)
                .offset(y: 6)
                .blur(radius: 3)
            figureShape(bodyW: bodyW, bodyH: bodyH, headR: headR)
                .overlay(alignment: .top) {
                    // 首元のマフラー（コンビ色の最小記号）
                    Capsule().fill(accent.opacity(0.85))
                        .frame(width: bodyW * 0.62, height: 5.5)
                        .offset(y: headR * 0.72)
                }
                // 逆光のリム（輪郭の片側だけ暖色が乗る）
                .background {
                    figureShape(bodyW: bodyW, bodyH: bodyH, headR: headR, plain: true)
                        .foregroundStyle(Color(hex: 0xFFCF8E))
                        .blur(radius: 5)
                        .opacity(0.35)
                        .offset(x: 2.5, y: -1)
                }
                .scaleEffect(y: inhale ? 1.015 : 0.988, anchor: .bottom)
                .rotationEffect(.degrees(tilt), anchor: .bottom)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: breathe).repeatForever(autoreverses: true)) {
                inhale = true
            }
        }
    }

    /// 頭と胴を深めに重ねる（首の隙間があると頭が浮いて見える）。
    private func figureShape(bodyW: CGFloat, bodyH: CGFloat, headR: CGFloat, plain: Bool = false) -> some View {
        VStack(spacing: -headR * 0.34) {
            Circle()
                .fill(plain ? AnyShapeStyle(.foreground) : AnyShapeStyle(inkFill))
                .frame(width: headR, height: headR)
            UnevenRoundedRectangle(topLeadingRadius: bodyW * 0.42, bottomLeadingRadius: 9,
                                   bottomTrailingRadius: 9, topTrailingRadius: bodyW * 0.42)
                .fill(plain ? AnyShapeStyle(.foreground) : AnyShapeStyle(inkFill))
                .frame(width: bodyW, height: bodyH)
        }
    }

    private var inkFill: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x241B36), Color(hex: 0x120D20)],
                       startPoint: .top, endPoint: .bottom)
    }
}

// MARK: センターマイク（漫才の記号そのもの）

struct CenterMic: View {
    var height: CGFloat = 100
    var body: some View {
        let headR = height * 0.16
        VStack(spacing: 0) {
            // マイクヘッド（球・上面に照明の照り）
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xA6A2B8), Color(hex: 0x2A2438)],
                                     center: UnitPoint(x: 0.35, y: 0.25),
                                     startRadius: 1, endRadius: headR))
                .frame(width: headR, height: headR)
            // シャフト
            RoundedRectangle(cornerRadius: 1.5)
                .fill(LinearGradient(colors: [Color(hex: 0x565068), Color(hex: 0x1E1930)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: max(3, height * 0.032), height: height * 0.74)
            // ベース
            Ellipse()
                .fill(Color(hex: 0x17121F))
                .frame(width: height * 0.30, height: height * 0.09)
                .overlay(Ellipse().stroke(Color(hex: 0xFFCF8E).opacity(0.3), lineWidth: 0.8))
        }
        .shadow(color: .black.opacity(0.4), radius: 3, x: 3, y: 2)
    }
}

// MARK: 塵（光の柱を舞う微粒子）

/// 16粒がゆっくり上昇しながら横に揺れる。粒ごとの位相は index から決める（乱数不使用＝描画のみ）。
struct DustField: View {
    let centerX: CGFloat
    let spread: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<16 {
                    let fi = Double(i)
                    let speed = 9.0 + fi.truncatingRemainder(dividingBy: 5) * 3.5      // 上昇速度 pt/s
                    let period = Double(size.height + 40) / speed
                    let phase = (t + fi * 7.31).truncatingRemainder(dividingBy: period) / period
                    let y = size.height * (1 - phase) - 20
                    let wobble = sin(t * 0.7 + fi * 1.9) * (10 + fi.truncatingRemainder(dividingBy: 4) * 6)
                    let x = centerX + (fi / 15 - 0.5) * spread * 1.6 + wobble
                    // 光柱の内側ほど明るく・端で消える
                    let dist = abs(x - centerX) / (spread * 0.9)
                    let alpha = max(0, 0.30 - dist * 0.22) * (0.5 + 0.5 * sin(phase * .pi))
                    let r = 1.0 + fi.truncatingRemainder(dividingBy: 3) * 0.6
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                             with: .color(Color(hex: 0xFFE9C4).opacity(alpha)))
                }
            }
        }
    }
}
