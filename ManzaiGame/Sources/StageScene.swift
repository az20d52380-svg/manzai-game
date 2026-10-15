// StageScene.swift
// 育成メインのシーン（View層のみ・golden非干渉）。
// パワプロ・サクセスの文法＝日常パートは「明るくポップ」（オーナー確定 2026-08-01）。
// 明るい稽古場の昼: クリームの壁＋大きな窓から差す昼光＋板張りの床＋センターマイク＋
// カラーの漫才師2人（呼吸・揺れ）＋光の中の塵。暗転（劇場の闇）は本番系画面（結果/決勝）の語彙として残す。
// 立ち絵イラストが入るまでの「絵が無くても画面が明るく生きて見える」到達点。数値は全て【仮】。

import SwiftUI

struct StageScene: View {
    /// true＝下位一覧（練習/バイト/休む…）を開いている間：人物・マイク・ポスターを描かず、壁と床だけの高座帯にする（頭切れ・木札被りを構造的に無くす）
    var compact = false
    /// 大会入口・本番前は黒漆の看板が上に掛かるので、吊り札（寄席）は掛けない（看板の下から枠線が覗く事故を無くす）
    var showPoster = true
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let horizon = h * 0.55            // 壁と床の境
            let micX = w * 0.62               // センターマイクの立ち位置（左下は台詞の席なので右寄り）
            let footY = h * 0.84           // 二人の足元（下端の吹き出し・カードに隠れない高さ）
            let figH = max(130, h * 0.27)     // 人物は画面比で決める
            let showActors = !compact || h >= 260   // 下位一覧でも高さに余裕があれば（バイト等）めくり札を出す

            ZStack {
                // 1) 稽古場の壁（明るいクリーム・上ほど白）
                LinearGradient(colors: [Color(hex: 0xFFFBF0), Color(hex: 0xFFF2DC), Color(hex: 0xFFE9C8)],
                               startPoint: .top, endPoint: .bottom)

                // 2) 壁の飾り: 寄席ポスター（右壁・場所の説明を最小の小道具で）。
                //    ※窓は廃止＝左上はピル列の席・白い矩形が UI と衝突して事故る。光は画面外左上からの光帯で語る。
                //    長押（なげし）を1本通し、千社札風の縦札を紐で吊るして壁に定着させる。
                Rectangle().fill(Color(hex: 0x8D6E63)).frame(width: w, height: 8)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color(hex: 0x5D4037).opacity(0.5)).frame(height: 1.5) }
                    .position(x: w / 2, y: h * 0.19)
                if !compact && showPoster {
                VStack(spacing: 0) {
                    HStack(spacing: 18) { Rectangle().fill(Color(hex: 0x5D4037)).frame(width: 1.5, height: 10); Rectangle().fill(Color(hex: 0x5D4037)).frame(width: 1.5, height: 10) }
                    posterCard.frame(width: 28, height: 64)
                }
                .position(x: w * 0.60, y: h * 0.19 + 4 + 37)
                }

                // 4) 板張りの床（明るい木・消失点パース）
                floorBoards(width: w, height: h - horizon, vanishX: micX)
                    .frame(height: h - horizon)
                    .position(x: w / 2, y: horizon + (h - horizon) / 2)

                // 5) 画面外左上の窓から差す昼光（床へ斜めに落ちる・明るさの主役）
                lightShaft(from: CGPoint(x: w * 0.08, y: -h * 0.05),
                           to: CGPoint(x: micX - w * 0.05, y: footY), spread: w * 0.26)
                    .fill(LinearGradient(colors: [Color(hex: 0xFFF6D8).opacity(0.75),
                                                  Color(hex: 0xFFF0C6).opacity(0.30), .clear],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .blur(radius: 10)

                // 6) 床の陽だまり（二人とマイクの足元）
                Ellipse()
                    .fill(RadialGradient(colors: [Color(hex: 0xFFFBE8).opacity(0.85),
                                                  Color(hex: 0xFFF3D0).opacity(0.30), .clear],
                                         center: .center, startRadius: 8, endRadius: w * 0.36))
                    .frame(width: w * 0.72, height: h * 0.17)
                    .position(x: micX, y: footY - 4)

                // 7) 光の中の塵（昼のきらめき・16粒）
                DustField(centerX: micX - w * 0.06, spread: w * 0.30)
                    .allowsHitTesting(false)

                // 8) センターマイク＋二人のめくり札（俺＝黒帯・谷口＝朱帯）。人は図形で描かない（ぼかし影も敷かない）
                if showActors {
                    Group {
                        CenterMic(height: figH * 0.78)
                            .position(x: micX, y: footY - figH * 0.39)
                        StageNameBoard(name: "俺", band: YoseColor.kuroUrushi, height: figH * 0.86)
                            .position(x: micX - figH * 0.50, y: footY - figH * 0.43 - 3)
                        StageNameBoard(name: "谷口", band: YoseColor.shu, height: figH * 0.98)
                            .position(x: micX + figH * 0.52, y: footY - figH * 0.49 - 3)
                    }
                    .scaleEffect(1.15, anchor: UnitPoint(x: micX / w, y: footY / h))
                }
            }
        }
    }

    /// 寄席ポスター（朱地に白抜き・小道具）
    private var posterCard: some View {
        VStack(spacing: 2) {
            Text("寄").font(.system(size: 20, weight: .black)).foregroundStyle(Color(hex: 0x1C1917))
            Text("席").font(.system(size: 20, weight: .black)).foregroundStyle(Color(hex: 0x1C1917))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: 0xFFFBF0))
        .overlay(Rectangle().stroke(Color(hex: 0x1C1917), lineWidth: 2))
        .shadow(color: Theme.ink.opacity(0.15), radius: 3, y: 2)
    }

    /// 板張りの床: 明るい木＋消失点へ収束する目地。
    private func floorBoards(width: CGFloat, height: CGFloat, vanishX: CGFloat) -> some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xEED2A4), Color(hex: 0xDDB682), Color(hex: 0xC89A62)],
                           startPoint: .top, endPoint: .bottom)
            Canvas { ctx, size in
                let vanish = CGPoint(x: vanishX, y: -size.height * 0.6)   // 消失点は壁の奥
                for i in 0...10 {
                    let bx = size.width * CGFloat(i) / 10
                    var p = Path()
                    p.move(to: CGPoint(x: bx, y: size.height))
                    p.addLine(to: vanish)
                    ctx.stroke(p, with: .color(Color(hex: 0x9A7546).opacity(0.35)), lineWidth: 1)
                }
                for j in 1...4 {
                    let t = CGFloat(j) / 4.5
                    let y = size.height * (1 - t * t)
                    var p = Path()
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(p, with: .color(Color(hex: 0x9A7546).opacity(0.22)), lineWidth: 1)
                }
            }
        }
        .clipped()
    }

    /// 窓からの光帯（斜めの台形）。
    private func lightShaft(from top: CGPoint, to bottom: CGPoint, spread: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: top.x - 24, y: top.y))
        p.addLine(to: CGPoint(x: top.x + 34, y: top.y))
        p.addLine(to: CGPoint(x: bottom.x + spread, y: bottom.y))
        p.addLine(to: CGPoint(x: bottom.x - spread, y: bottom.y))
        p.closeSubpath()
        return p
    }
}

/// 舞台のめくり名札（寄席のめくり札＝二人の立ち位置。縦書きの名前・上に帯・墨枠＋ハードシャドウ）
struct StageNameBoard: View {
    let name: String
    let band: Color
    let height: CGFloat
    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(band).frame(height: 14)
                .overlay(Rectangle().fill(YoseColor.kin).frame(width: 14, height: 2))
            VStack(spacing: 2) {
                ForEach(Array(name), id: \.self) { ch in
                    Text(String(ch)).font(YoseFont.mincho(26)).foregroundStyle(YoseColor.sumi)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: 56, height: height)
        .background(YoseColor.washi)
        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
        .background(Rectangle().fill(YoseColor.sumi).offset(y: 3))
    }
}

// MARK: 漫才師（カラー・呼吸・揺れ）

/// 頭（肌＋髪）＋上着の胴。パワプロ的な「明るいマスコット」側に寄せた無貌の人形。
/// accent は首元のマフラー。呼吸周期は二人で別（機械感を消す）。
struct ManzaiFigure: View {
    let height: CGFloat
    let tilt: Double            // 相方へ僅かに傾く（度）
    let accent: Color
    let breathe: Double         // 呼吸周期（秒）
    var bodyColors: [Color] = [Color(hex: 0x241B36), Color(hex: 0x120D20)]
    var headColor: Color? = nil // nil=シルエット（頭も胴色）
    var hairColor: Color = Color(hex: 0x3A3350)
    @State private var inhale = false

    var body: some View {
        let bodyW = height * 0.48
        let bodyH = height * 0.72
        let headR = height * 0.30
        ZStack(alignment: .bottom) {
            // 足元の影
            Ellipse().fill(Theme.ink.opacity(0.20))
                .frame(width: bodyW * 1.35, height: 10)
                .offset(y: 6)
                .blur(radius: 3)
            VStack(spacing: -headR * 0.34) {
                // 頭（肌＋髪のキャップ）
                Circle()
                    .fill(headColor ?? bodyColors.last ?? Theme.ink)
                    .overlay {
                        if headColor != nil {
                            // 髪: 頭の上半分を覆うドーム（無貌でも「人」に見える最小の記号）
                            Circle().fill(hairColor)
                                .mask(alignment: .top) { Rectangle().frame(height: headR * 0.52) }
                        }
                    }
                    .frame(width: headR, height: headR)
                // 胴（上着）
                UnevenRoundedRectangle(topLeadingRadius: bodyW * 0.42, bottomLeadingRadius: 9,
                                       bottomTrailingRadius: 9, topTrailingRadius: bodyW * 0.42)
                    .fill(LinearGradient(colors: bodyColors, startPoint: .top, endPoint: .bottom))
                    .frame(width: bodyW, height: bodyH)
                    .overlay(alignment: .top) {
                        // 首元のマフラー（コンビ色の記号）
                        Capsule().fill(accent)
                            .frame(width: bodyW * 0.62, height: 6)
                            .offset(y: 5)
                    }
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
}

// MARK: センターマイク（漫才の記号そのもの）

struct CenterMic: View {
    var height: CGFloat = 100
    var body: some View {
        // 木版画風のベタ塗り（グラデ球・ぼかし影を使わない）：墨の枠＋灰墨と黒漆のソリッド、上辺に細い白ハイライト
        let headR = height * 0.17
        VStack(spacing: 0) {
            Circle().fill(YoseColor.haiSumi)
                .overlay(Circle().stroke(YoseColor.sumi, lineWidth: 2))
                .overlay(alignment: .topLeading) {
                    Capsule().fill(Color.white.opacity(0.55)).frame(width: headR * 0.34, height: 1.5)
                        .offset(x: headR * 0.22, y: headR * 0.2).rotationEffect(.degrees(-25))
                }
                .frame(width: headR, height: headR)
            Rectangle().fill(YoseColor.kuroUrushi)
                .overlay(alignment: .leading) { Rectangle().fill(Color.white.opacity(0.4)).frame(width: 1) }
                .frame(width: max(3, height * 0.034), height: height * 0.74)
            Ellipse().fill(YoseColor.kuroUrushi)
                .overlay(Ellipse().stroke(YoseColor.sumi, lineWidth: 1.5))
                .frame(width: height * 0.30, height: height * 0.09)
        }
        .shadow(color: YoseColor.sumi.opacity(0.28), radius: 0, x: 2, y: 2)   // ハードシャドウ
    }
}

// MARK: 塵（光の帯のきらめき）

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
                    let dist = abs(x - centerX) / (spread * 0.9)
                    let alpha = max(0, 0.55 - dist * 0.4) * (0.5 + 0.5 * sin(phase * .pi))
                    let r = 1.0 + fi.truncatingRemainder(dividingBy: 3) * 0.6
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                             with: .color(Color(hex: 0xFFEDB8).opacity(alpha)))
                }
            }
        }
    }
}
