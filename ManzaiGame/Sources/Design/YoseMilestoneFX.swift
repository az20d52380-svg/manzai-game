// YoseMilestoneFX.swift  節目演出の作り直し（予選通過・練習の大成功）
// 設計: docs/effects_redo_argon_v1.md §4-1 / §4-3。本編未接続（DEBUG の MZ_FX=pass / burst だけで単独再生）。
import SwiftUI
import UIKit

/// 白金→山吹金→濃金の金属グラデーション袋文字（墨の太縁＋ソリッド下影）
struct YoseGoldText: View {
    let text: String
    var size: CGFloat = 40
    var tracking: CGFloat = 0
    var body: some View {
        ZStack {
            ForEach([-1, 0, 1], id: \.self) { dx in
                ForEach([-1, 0, 1], id: \.self) { dy in
                    if dx != 0 || dy != 0 {
                        Text(text).font(YoseFont.mincho(size)).tracking(tracking).foregroundStyle(Color.black)
                            .offset(x: CGFloat(dx) * size * 0.04, y: CGFloat(dy) * size * 0.04 + size * 0.05)
                    }
                }
            }
            Text(text).font(YoseFont.mincho(size)).tracking(tracking)
                .foregroundStyle(LinearGradient(stops: [
                    .init(color: Color(hex: 0xFFFBE6), location: 0), .init(color: YoseColor.kinBright, location: 0.45),
                    .init(color: Color(hex: 0xB8861B), location: 0.85), .init(color: YoseColor.kinBright, location: 1)],
                    startPoint: .top, endPoint: .bottom))
        }
    }
}

/// 加算発光する局所の光芯（中心は白金、外へ減衰。放射線は描かない）
private struct YoseCoreGlow: View {
    var radius: CGFloat = 200
    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [Color(hex: 0xFFF2C4).opacity(0.65), YoseColor.kinBright.opacity(0.28), YoseColor.shu.opacity(0.08), .clear],
                                 center: .center, startRadius: 4, endRadius: radius))
            .frame(width: radius * 2, height: radius * 2)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }
}

/// 正円の朱の丸判子（二重輪＋太い2文字）
struct YoseRoundHanko: View {
    let text: String
    var size: CGFloat = 70
    var body: some View {
        Text(text)
            .font(YoseFont.mincho(size * 0.34)).tracking(1)
            .foregroundStyle(YoseColor.shu)
            .frame(width: size, height: size)
            .background(Circle().fill(YoseColor.washi.opacity(0.92)))
            .overlay(Circle().stroke(YoseColor.shu, lineWidth: 3))
            .overlay(Circle().stroke(YoseColor.shu, lineWidth: 1).padding(5))
            .rotationEffect(.degrees(-10))
    }
}

// MARK: - 予選通過（合否判定『突破』）

struct YosePassCelebrationView: View {
    var duoName: String = "満月ロケット"
    var roundName: String = "頂グランプリ 二回戦"
    var judgeName: String = "審査員・天堂寺"
    var nextStep: String = "次戦 準々決勝へ"
    var fameGain: Int = 3
    var threshold: Int = 30
    var power: Int = 134
    var judgeComment: String = "ツッコミの間が良い。後半の畳みかけもきれいに通った。"
    var onFinish: () -> Void = {}

    @State private var cardIn = false
    @State private var shownPower = 0
    @State private var revealed = false      // 数字確定→突破
    @State private var hankoIn = false
    @State private var hidemarkIn = false
    @State private var shimmerX: CGFloat = -1.2
    @State private var flash: Double = 0
    @State private var shakeY: CGFloat = 0
    @State private var burst = 0
    @State private var finished = false
    @State private var done = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // 夜の寄席舞台（暗転）
            LinearGradient(colors: [Color(hex: 0x0B0807), YoseColor.kuroUrushi, Color(hex: 0x0B0807)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            HStack(spacing: 0) {
                ForEach(0..<15, id: \.self) { i in
                    Rectangle().fill(i % 3 == 0 ? Color.black.opacity(0.35) : (i % 3 == 1 ? YoseColor.enji.opacity(0.10) : YoseColor.tokiwa.opacity(0.07)))
                }
            }.ignoresSafeArea()

            Color.clear.overlay { YoseCoreGlow(radius: 260).offset(y: -170).opacity(revealed ? 1 : 0) }.ignoresSafeArea()

            // 天井から落ちる2本のピンスポット（突破で点灯）
            Color.clear.overlay(alignment: .top) {
                HStack(spacing: 150) {
                    ForEach(0..<2, id: \.self) { _ in
                        Path { p in p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: 8, y: 0)); p.addLine(to: CGPoint(x: 70, y: 520)); p.addLine(to: CGPoint(x: -62, y: 520)); p.closeSubpath() }
                            .fill(LinearGradient(colors: [Color(hex: 0xFFF2C4).opacity(0.32), .clear], startPoint: .top, endPoint: .bottom))
                            .frame(width: 8, height: 520)
                    }
                }
                .blendMode(.plusLighter).opacity(revealed ? 1 : 0)
            }.ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 0) {
                // 上部：大会・ラウンドの黒漆冠バー
                HStack(spacing: 8) {
                    Rectangle().fill(YoseColor.shu).frame(width: 6, height: 6)
                    Text(roundName).font(YoseFont.gothic(14, weight: .heavy)).tracking(1.5).foregroundStyle(YoseColor.kinBright)
                    Spacer()
                    Text("合否判定").font(YoseFont.gothic(11, weight: .heavy)).foregroundStyle(YoseColor.kinari)
                        .padding(.horizontal, 7).padding(.vertical, 3).background(YoseColor.enji)
                        .overlay(Rectangle().stroke(YoseColor.kinBright, lineWidth: 1))
                }
                .padding(.horizontal, 16).frame(height: 40)
                .background(Color.black)
                .overlay(alignment: .bottom) { Rectangle().fill(YoseColor.kin).frame(height: 1.5) }

                Spacer(minLength: 16)
                VStack(spacing: 26) {
                    signboard
                    resultCard
                    reviewCard
                    bonusPlate
                }
                .padding(.horizontal, 22)
                .offset(y: shakeY)
                Spacer(minLength: 10)
                Text("画面をタップして進む ▶")
                    .font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.kinari.opacity(0.7))
                    .opacity(finished ? 1 : 0).padding(.bottom, 26)
            }
            .opacity(cardIn ? 1 : 0)

            if revealed { YoseConfettiView(isActive: true, pieceCount: 36).allowsHitTesting(false).ignoresSafeArea() }

            Color(hex: 0xFFF2C4).opacity(flash).blendMode(.plusLighter).ignoresSafeArea().allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { if finished { onFinish() } else { snapToFinal() } }
        .task { await run() }
    }

    // 上：黒漆の合否看板（最初は空枠 → 点灯して金文字）
    private var signboard: some View {
        ZStack {
            Rectangle().fill(YoseColor.kuroUrushi)
            // 地紋（臙脂の斜め格子）
            Canvas { ctx, size in
                var p = Path()
                var x: CGFloat = -size.height
                while x < size.width { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x + size.height, y: size.height)); x += 18 }
                ctx.stroke(p, with: .color(YoseColor.enji.opacity(0.35)), lineWidth: 1)
            }
            VStack(spacing: 2) {
                Text("◆ 漫 才 の 頂 、 こ こ に 決 ま る ◆").font(YoseFont.gothic(10, weight: .heavy)).tracking(1.5)
                    .foregroundStyle(YoseColor.kin.opacity(revealed ? 1 : 0.25))
                ZStack {
                    Text("判 定 中").font(YoseFont.mincho(30)).tracking(10).foregroundStyle(YoseColor.kin.opacity(0.35))
                        .opacity(revealed ? 0 : 1)
                        .transaction { $0.animation = nil }
                    YoseGoldText(text: "予 選 通 過", size: 54, tracking: 4)
                        .scaleEffect(revealed ? 1 : 1.5).opacity(revealed ? 1 : 0)
                }
            }
            // 金の斜光（シマー）
            GeometryReader { g in
                LinearGradient(colors: [.clear, Color.white.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 70).rotationEffect(.degrees(18)).blendMode(.plusLighter)
                    .offset(x: shimmerX * g.size.width, y: -10)
            }.clipped().allowsHitTesting(false)
        }
        .frame(height: 118)
        .overlay(Rectangle().stroke(revealed ? YoseColor.kinBright : YoseColor.kin.opacity(0.4), lineWidth: 3))
        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).padding(5))
        .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1).padding(8))
        .background(Rectangle().fill(Color.black).offset(y: 6))
        .overlay { YoseBurstParticles(trigger: burst, count: 30, colors: [YoseColor.kinBright, .white, YoseColor.shu, YoseColor.kin], radius: 150, duration: 0.7)
            .frame(width: 320, height: 320).allowsHitTesting(false) }
    }

    // 中：結果カード（通過基準 ▶ 発揮実力）
    private var resultCard: some View {
        ZStack(alignment: .trailing) {
            VStack(spacing: 10) {
                Text(duoName).font(YoseFont.mincho(20)).foregroundStyle(YoseColor.sumi)
                HStack(alignment: .lastTextBaseline, spacing: 12) {
                    VStack(spacing: 2) {
                        Text("通過基準").font(YoseFont.gothic(11, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
                        Text("\(threshold)").font(YoseFont.number(34, weight: .black)).foregroundStyle(YoseColor.haiSumi)
                    }
                    Image(systemName: "play.fill").font(.system(size: Font.mzScaled(16), weight: .black)).foregroundStyle(revealed ? YoseColor.shu : YoseColor.kin)
                    VStack(spacing: 2) {
                        Text("発揮実力").font(YoseFont.gothic(11, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
                        Text("\(shownPower)").font(YoseFont.number(58, weight: .black))
                            .foregroundStyle(revealed ? YoseColor.shu : YoseColor.sumi)
                            .contentTransition(.numericText(value: Double(shownPower)))
                            .scaleEffect(revealed ? 1.0 : 0.96)
                    }
                }
            }
            .padding(.vertical, 16).padding(.leading, 20).padding(.trailing, 92)
            .frame(maxWidth: .infinity)
            .background(YoseColor.washi)
            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 3))
            .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1.2).padding(5))
            .background(Rectangle().fill(Color.black).offset(y: 5))

            YoseRoundHanko(text: "突破")
                .scaleEffect(hankoIn ? 1.0 : 2.6).opacity(hankoIn ? 1 : 0)
                .padding(.trailing, 14)
        }
    }

    // 下：審査員講評カード（角印『秀』）
    private var reviewCard: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("審査員講評").font(YoseFont.gothic(11, weight: .black)).foregroundStyle(YoseColor.kinari)
                        .padding(.horizontal, 6).padding(.vertical, 2).background(YoseColor.enji)
                    Text(judgeName.replacingOccurrences(of: "審査員・", with: "")).font(YoseFont.gothic(14, weight: .black)).foregroundStyle(YoseColor.sumi)
                }
                Text(judgeComment).font(YoseFont.gothic(14, weight: .medium)).foregroundStyle(YoseColor.sumi)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(YoseColor.kinari)
            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
            .background(Rectangle().fill(Color.black).offset(y: 4))
            YoseHankoStamp(text: "秀", isSquare: true, angle: 6)
                .scaleEffect(hidemarkIn ? 1.5 : 2.8, anchor: .topTrailing).opacity(hidemarkIn ? 1 : 0)
                .offset(x: -6, y: -18)
        }
        .opacity(hidemarkIn ? 1 : 0.0)
        .offset(y: hidemarkIn ? 0 : 14)
    }

    private var bonusPlate: some View {
        HStack(spacing: 10) {
            Text("通過").font(YoseFont.gothic(11, weight: .black)).foregroundStyle(YoseColor.kinari)
                .padding(.horizontal, 6).padding(.vertical, 2).background(YoseColor.shu)
            Text("知名度 +\(fameGain)").font(YoseFont.gothic(14, weight: .heavy)).foregroundStyle(YoseColor.kinBright)
            Spacer()
            Text(nextStep).font(YoseFont.gothic(14, weight: .heavy)).foregroundStyle(YoseColor.kinari)
            Image(systemName: "play.fill").font(.system(size: Font.mzScaled(11), weight: .black)).foregroundStyle(YoseColor.kinBright)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(YoseColor.kuroUrushi)
        .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1.5))
        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1).padding(3))
        .opacity(hidemarkIn ? 1 : 0).offset(y: hidemarkIn ? 0 : 12)
    }

    private func snapToFinal() {
        done = true
        shownPower = power; cardIn = true; revealed = true; hankoIn = true; hidemarkIn = true; finished = true; shimmerX = 1.4
    }

    private func run() async {
        if reduceMotion { snapToFinal(); return }
        withAnimation(.easeOut(duration: 0.14)) { cardIn = true }
        // 0.00〜0.45s 太鼓のドラムロール：数字が高速に駆け上がる（看板はまだ空枠）
        let steps = 14
        for i in 1...steps {
            try? await Task.sleep(nanoseconds: 32_000_000)
            if done { return }
            if i % 4 == 0 { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
            let v = Int(Double(power) * pow(Double(i) / Double(steps), 1.6)) + (i == steps ? 0 : Int.random(in: 0...6))
            withAnimation(.linear(duration: 0.03)) { shownPower = min(v, power) }
        }
        withAnimation(.linear(duration: 0.03)) { shownPower = power }
        // 0.45〜0.57s 無音の停止
        try? await Task.sleep(nanoseconds: 120_000_000)
        if done { return }
        // 0.57s 突破：看板点灯・朱印・フラッシュ・揺れ・斜光
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        flash = 0.24; withAnimation(.easeOut(duration: 0.3)) { flash = 0 }
        withAnimation(.spring(response: 0.26, dampingFraction: 0.6)) { revealed = true }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.55).delay(0.06)) { hankoIn = true }
        burst += 1
        shimmerX = -1.2; withAnimation(.easeInOut(duration: 0.55).delay(0.12)) { shimmerX = 1.4 }
        withAnimation(.linear(duration: 0.04)) { shakeY = 5 }
        try? await Task.sleep(nanoseconds: 50_000_000)
        withAnimation(.linear(duration: 0.05)) { shakeY = -3 }
        try? await Task.sleep(nanoseconds: 55_000_000)
        withAnimation(.linear(duration: 0.05)) { shakeY = 0 }
        // 0.78s 角印『秀』
        try? await Task.sleep(nanoseconds: 220_000_000)
        if done { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) { hidemarkIn = true }
        try? await Task.sleep(nanoseconds: 300_000_000)
        withAnimation(.easeOut(duration: 0.2)) { finished = true }
    }
}

// MARK: - 練習の大成功（週画面の上を貫通する斜めカットイン帯）

struct YoseBigSuccessCutIn: View {
    var title: String = "手応え抜群！ハマった！！"
    var gains: [(String, Int)] = [("閃", 6), ("語", 4), ("間", 5), ("存", 3), ("胆", 2)]
    var onFinish: () -> Void = {}

    @State private var lines = false
    @State private var bandIn = false
    @State private var bandOut = false
    @State private var stamped = false
    @State private var popped = false
    @State private var shakeY: CGFloat = 0
    @State private var burst = 0
    @State private var flash: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 外周だけに出る劇画集中線（中央の可読領域は空洞・外へ向かって減衰）
                // 周辺減光（黒漆）：中央を明るく残し外周を落として明度差を作る
                RadialGradient(colors: [Color.black.opacity(0.10), Color.black.opacity(0.62)], center: .center, startRadius: 80, endRadius: 520)
                    .opacity(lines && !bandOut ? 1 : 0).ignoresSafeArea()
                BigSuccessRays()
                    .opacity(lines && !bandOut ? 1 : 0)
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    band(sw: geo.size.width)
                    gainsRow
                }
                .frame(width: geo.size.width)
                .offset(y: shakeY)
                .offset(x: bandOut ? geo.size.width * 1.3 : (bandIn ? 0 : -geo.size.width * 1.3))

                Color(hex: 0xFFF2C4).opacity(flash).blendMode(.plusLighter).ignoresSafeArea()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
        .task { await run() }
    }

    private func band(sw: CGFloat) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text("練 習 大 成 功").font(YoseFont.gothic(12, weight: .heavy)).tracking(3).foregroundStyle(YoseColor.kin)
                YoseGoldText(text: title, size: 29)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 24).padding(.trailing, 130).padding(.vertical, 18)
        .frame(width: sw)
        .frame(width: sw * 1.25)
        .background(
            ZStack {
                YoseColor.kuroUrushi
                // 臙脂の斜めストライプ（太細の抑揚つき）
                HStack(spacing: 0) {
                    ForEach(0..<14, id: \.self) { i in
                        Rectangle().fill(YoseColor.enji.opacity(i % 3 == 0 ? 0.7 : 0.35)).frame(width: i % 3 == 0 ? 22 : 8)
                            .rotationEffect(.degrees(20)).padding(.trailing, 14)
                    }
                }.clipped()
            }
        )
        .overlay(alignment: .top) { VStack(spacing: 2) { Rectangle().fill(YoseColor.kinBright).frame(height: 3); Rectangle().fill(YoseColor.kin).frame(height: 1) } }
        .overlay(alignment: .bottom) { VStack(spacing: 2) { Rectangle().fill(YoseColor.kin).frame(height: 1); Rectangle().fill(YoseColor.kinBright).frame(height: 3) } }
        .overlay(alignment: .trailing) {
            YoseHankoStamp(text: "大成功", isSquare: false, angle: -8)
                .scaleEffect(stamped ? 1.5 : 3.0).opacity(stamped ? 1 : 0)
                .padding(.trailing, sw * 0.125 + 18)
        }
        .background(alignment: .trailing) {
            YoseBurstParticles(trigger: burst, count: 44, colors: [YoseColor.kinBright, .white, YoseColor.shu, YoseColor.kin], radius: 230, duration: 0.8, streaks: true)
                .frame(width: 460, height: 420).allowsHitTesting(false)
                .padding(.trailing, sw * 0.125 + 53 - 230)
        }
        .rotationEffect(.degrees(-5))
        .background(Rectangle().fill(Color.black).rotationEffect(.degrees(-5)).offset(y: 6))
    }

    private var gainsRow: some View {
        VStack(spacing: 10) {
            Text("獲得 1.35倍！").font(YoseFont.gothic(13, weight: .black)).tracking(2)
                .foregroundStyle(YoseColor.kuroUrushi)
                .padding(.horizontal, 14).padding(.vertical, 4)
                .background(LinearGradient(colors: [Color(hex: 0xFFF8D6), YoseColor.kinBright], startPoint: .top, endPoint: .bottom))
                .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                .background(Rectangle().fill(Color.black).offset(y: 3))
                .opacity(popped ? 1 : 0)
            HStack(spacing: 8) {
                ForEach(Array(gains.enumerated()), id: \.offset) { i, g in
                    VStack(spacing: 1) {
                        Text(g.0).font(YoseFont.gothic(11, weight: .black)).foregroundStyle(YoseColor.sumi.opacity(0.7))
                        Text("+\(g.1)").font(YoseFont.number(21, weight: .black)).foregroundStyle(YoseColor.shu)
                    }
                    .frame(width: 54, height: 50)
                    .background(LinearGradient(colors: [Color(hex: 0xFFF8D6), Color(hex: 0xF2D27A)], startPoint: .top, endPoint: .bottom))
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    .overlay(Rectangle().stroke(YoseColor.kinBright, lineWidth: 1.5).padding(3))
                    .background(Rectangle().fill(Color.black).offset(y: 4))
                    .scaleEffect(popped ? 1.0 : 1.35)
                    .opacity(popped ? 1 : 0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.5).delay(Double(i) * 0.03), value: popped)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func run() async {
        if reduceMotion { lines = true; bandIn = true; stamped = true; popped = true; return }
        // 0.00s 白金フラッシュ＋外周集中線
        flash = 0.22; withAnimation(.easeOut(duration: 0.2)) { flash = 0 }
        withAnimation(.easeOut(duration: 0.08)) { lines = true }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        // 0.10s 黒漆の斜め帯がスパーンと突入
        try? await Task.sleep(nanoseconds: 100_000_000)
        withAnimation(.spring(response: 0.18, dampingFraction: 0.82)) { bandIn = true }
        // 0.22s 朱印『大成功』＋揺れ＋火花
        try? await Task.sleep(nanoseconds: 120_000_000)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        flash = 0.32; withAnimation(.easeOut(duration: 0.28)) { flash = 0 }
        withAnimation(.spring(response: 0.2, dampingFraction: 0.55)) { stamped = true }
        burst += 1
        withAnimation(.linear(duration: 0.04)) { shakeY = 4 }
        try? await Task.sleep(nanoseconds: 50_000_000)
        withAnimation(.linear(duration: 0.05)) { shakeY = -3 }
        try? await Task.sleep(nanoseconds: 55_000_000)
        withAnimation(.linear(duration: 0.05)) { shakeY = 0 }
        // 0.30s 経験点木札が跳ねる（通常の1.35倍で弾けて収まる）
        try? await Task.sleep(nanoseconds: 60_000_000)
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { popped = true }
        // 0.95s 右へ抜けて退場（タップ不要）
        try? await Task.sleep(nanoseconds: 700_000_000)
        withAnimation(.easeIn(duration: 0.16)) { bandOut = true }
        try? await Task.sleep(nanoseconds: 180_000_000)
        onFinish()
    }
}


/// 大成功の劇画集中線：太細・長短が不規則、外周から中心へ向かうほど消える、中央は空洞。金と白の混在。
private struct BigSuccessRays: View {
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = hypot(size.width, size.height) * 0.62
            let n = 58
            for i in 0..<n {
                let h1 = abs(sin(Double(i) * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
                let h2 = abs(sin(Double(i) * 78.233) * 12345.678).truncatingRemainder(dividingBy: 1)
                let a = (Double(i) + h1 * 0.8) / Double(n) * 2 * .pi
                let half = 0.004 + h2 * h2 * 0.03
                let rx = size.width * 0.40, ry = size.height * 0.30
                let er = 1.0 / sqrt(pow(cos(a) / rx, 2) + pow(sin(a) / ry, 2))
                let r0 = CGFloat(er) + CGFloat(h1) * 110 + 10
                var p = Path()
                p.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * r0, y: c.y + CGFloat(sin(a)) * r0))
                p.addLine(to: CGPoint(x: c.x + CGFloat(cos(a - half)) * outer, y: c.y + CGFloat(sin(a - half)) * outer))
                p.addLine(to: CGPoint(x: c.x + CGFloat(cos(a + half)) * outer, y: c.y + CGFloat(sin(a + half)) * outer))
                p.closeSubpath()
                let col: Color = (i % 4 == 0) ? .white : YoseColor.kinBright
                ctx.fill(p, with: .radialGradient(Gradient(colors: [col.opacity(0.0), col.opacity(0.85)]),
                                                  center: c, startRadius: r0, endRadius: outer * 0.8))
            }
        }
        .allowsHitTesting(false)
    }
}
