import SwiftUI
import UIKit

// MARK: - 1. データモデル（1個〜複数の能力ランク昇格を保持）

struct RankUpItem: Identifiable, Equatable {
    let id = UUID()
    let abilityName: String   // "センス", "発想", "表現", "華", "メンタル"
    let abilityShort: String  // "セ", "発", "表", "華", "メ"
    let abilityColor: Color
    let fromRank: String      // "G" 〜 "A"
    let toRank: String        // "F" 〜 "S"
    let beforeValue: Int
    let afterValue: Int

    init(
        abilityName: String,
        abilityShort: String,
        abilityColor: Color,
        fromRank: String,
        toRank: String,
        beforeValue: Int,
        afterValue: Int
    ) {
        self.abilityName = abilityName
        self.abilityShort = abilityShort
        self.abilityColor = abilityColor
        self.fromRank = fromRank
        self.toRank = toRank
        self.beforeValue = beforeValue
        self.afterValue = afterValue
    }
}

// MARK: - 2. ランクアップ演出オーバーレイ本体

struct YoseRankUpOverlay: View {
    let items: [RankUpItem]
    let totalPower: Int
    let powerDelta: Int
    let onDismiss: () -> Void

    @State private var cardAppeared = false
    @State private var badgeLanded = false
    @State private var stamped = false
    @State private var shakeOffset: CGFloat = 0
    @State private var shownValue: Int = 0
    @State private var isDismissed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var primary: RankUpItem? { items.first }
    private var subItems: ArraySlice<RankUpItem> { items.dropFirst() }

    init(
        items: [RankUpItem],
        totalPower: Int,
        powerDelta: Int,
        onDismiss: @escaping () -> Void
    ) {
        self.items = items
        self.totalPower = totalPower
        self.powerDelta = powerDelta
        self.onDismiss = onDismiss
    }

    @State private var flash: Double = 0
    @State private var burstTrigger = 0
    private var isTopRank: Bool { primary?.toRank == "S" }

    var body: some View {
        if let main = primary {
            ZStack {
                // 暗転（夜の舞台）。どこをタップしても1回で閉じる
                Color(hex: 0x0B0807).opacity(cardAppeared ? 0.88 : 0.0)
                    .ignoresSafeArea()

                // 新ランク着地で点る加算発光の後光（Sランクは大きく強く＋紙吹雪）
                RankUpHalo(strong: isTopRank)
                    .opacity(badgeLanded ? 1 : 0)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    VStack(spacing: 0) {
                        headerStrip
                        joshikimakuStripe
                        mainContent(for: main)
                    }
                    .background(YoseColor.washi)
                    .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1.5).padding(4))
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 3))
                    .background(Rectangle().fill(Color.black).offset(y: 5))
                    .offset(y: shakeOffset)
                    .scaleEffect(cardAppeared ? 1.0 : 0.86)
                    .opacity(cardAppeared ? 1.0 : 0.0)
                    .padding(.horizontal, 22)

                    Text("画面をタップして閉じる ▶")
                        .font(YoseFont.gothic(12, weight: .bold))
                        .foregroundStyle(YoseColor.kinari.opacity(0.75))
                        .opacity(stamped && cardAppeared ? 1.0 : 0.0)
                }

                if isTopRank && badgeLanded {
                    YoseConfettiView(isActive: true, pieceCount: 70).allowsHitTesting(false).ignoresSafeArea()
                }

                Color(hex: 0xFFF2C4).opacity(flash).blendMode(.plusLighter)
                    .ignoresSafeArea().allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture { dismissImmediately() }
            .task { await runSequence(for: main) }
        }
    }

    // MARK: - 上部見出し（黒漆ヘッダー＋定式幕ストリップ）

    private var headerStrip: some View {
        HStack(spacing: 8) {
            Rectangle().fill(YoseColor.kin.opacity(0.7)).frame(width: 24, height: 1.5)
            Rectangle().fill(YoseColor.kinBright).frame(width: 6, height: 6).rotationEffect(.degrees(45))
            Text("番 付 昇 格")
                .font(YoseFont.mincho(22))
                .tracking(4)
                .foregroundStyle(
                    LinearGradient(colors: [Color(hex: 0xFFF8D6), YoseColor.kinBright, Color(hex: 0xB8861B)], startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: .black, radius: 0, x: 0, y: 2)
            Rectangle().fill(YoseColor.kinBright).frame(width: 6, height: 6).rotationEffect(.degrees(45))
            Rectangle().fill(YoseColor.kin.opacity(0.7)).frame(width: 24, height: 1.5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background(Color.black)
        .overlay(alignment: .bottom) { Rectangle().fill(YoseColor.kin).frame(height: 1.5) }
    }

    private var joshikimakuStripe: some View {
        HStack(spacing: 0) {
            ForEach(0..<18, id: \.self) { i in
                Rectangle().fill([YoseColor.kuroUrushi, YoseColor.shu, YoseColor.tokiwa][i % 3])
            }
        }
        .frame(height: 8)
        .overlay(alignment: .bottom) { Rectangle().fill(YoseColor.sumi).frame(height: 1.5) }
    }

    // MARK: - 主役ランク昇格エリア

    private func rankTablet(_ rank: String, size: CGFloat, glyph: CGFloat, bright: Bool) -> some View {
        Text(rank)
            .font(YoseFont.mincho(glyph))
            .foregroundStyle(bright
                ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFFBE6), YoseColor.kinBright, Color(hex: 0xB8861B)], startPoint: .top, endPoint: .bottom))
                : AnyShapeStyle(YoseColor.haiSumi))
            .shadow(color: .black, radius: 0, x: 0, y: bright ? 4 : 2)
            .frame(width: size, height: size)
            .background(ZStack { bright ? Color(hex: 0x1A1210) : YoseColor.kinari; if bright { Self.rankColor(rank).opacity(0.38) } })
            .overlay(Rectangle().stroke(bright ? YoseColor.kinBright : YoseColor.sumi.opacity(0.5), lineWidth: bright ? 3 : 1.5).padding(bright ? 0 : 0))
            .overlay(Rectangle().stroke(bright ? YoseColor.kin : YoseColor.sumi, lineWidth: 1).padding(5))
            .background(Rectangle().fill(bright ? Color.black : YoseColor.sumi.opacity(0.35)).offset(y: bright ? 5 : 2))
    }

    private func mainContent(for item: RankUpItem) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Text(item.abilityShort)
                    .font(YoseFont.gothic(13, weight: .black))
                    .foregroundStyle(YoseColor.kinari)
                    .frame(width: 26, height: 26)
                    .background(item.abilityColor)
                    
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                Text("\(item.abilityName)のランクが上がった！")
                    .font(YoseFont.gothic(17, weight: .heavy))
                    .foregroundStyle(YoseColor.sumi)
            }
            .padding(.top, 8)

            ZStack(alignment: .topTrailing) {
                HStack(spacing: 8) {
                    VStack(spacing: 4) {
                        Text("旧").font(YoseFont.gothic(10, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
                        rankTablet(item.fromRank, size: 50, glyph: 28, bright: false)
                    }
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: "play.fill")
                                .font(.system(size: i == 2 ? 20 : 14, weight: .black))
                                .foregroundStyle(i == 2 ? YoseColor.shu : YoseColor.kin)
                                .opacity(badgeLanded ? 1 : 0.25)
                        }
                    }
                    .padding(.top, 16)
                    VStack(spacing: 4) {
                        Text("新ランク").font(YoseFont.gothic(11, weight: .heavy)).foregroundStyle(YoseColor.shu)
                        ZStack {
                            Rectangle().fill(YoseColor.kinari).overlay(Rectangle().stroke(YoseColor.sumi.opacity(0.35), lineWidth: 1.5))
                                .frame(width: 100, height: 100)
                                .opacity(badgeLanded ? 0 : 1)
                            Text("？").font(YoseFont.mincho(44)).foregroundStyle(YoseColor.sumi.opacity(0.25))
                                .opacity(badgeLanded ? 0 : 1)
                            rankTablet(item.toRank, size: 100, glyph: 68, bright: true)
                                .scaleEffect(badgeLanded ? 1.0 : 2.3)
                                .opacity(badgeLanded ? 1.0 : 0.0)
                        }
                        .overlay {
                            YoseBurstParticles(trigger: burstTrigger, count: 28,
                                               colors: [YoseColor.kinBright, Color.white, YoseColor.shu, YoseColor.kin],
                                               radius: 120, duration: 0.7)
                                .frame(width: 240, height: 240).allowsHitTesting(false)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                YoseHankoStamp(text: "昇格", isSquare: false, angle: -8)
                    .modifier(YoseStampImpactModifier(isStamped: stamped))
                    .scaleEffect(1.1).offset(x: 6, y: 18)
            }

            // 能力値と実力（白和紙の木札で暗い地から浮かせる）
            HStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.abilityName).font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.haiSumi)
                    Text("\(item.beforeValue)").font(YoseFont.number(18, weight: .heavy)).foregroundStyle(YoseColor.haiSumi)
                    Image(systemName: "arrow.right").font(.system(size: 11, weight: .black)).foregroundStyle(YoseColor.shu)
                    Text(stamped ? "\(shownValue)" : "？？").font(YoseFont.number(26, weight: .black)).foregroundStyle(YoseColor.sumi)
                        .contentTransition(.numericText(value: Double(shownValue)))
                }
                .frame(maxWidth: .infinity)
                Rectangle().fill(YoseColor.kiDark).frame(width: 1.5, height: 28)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("実力").font(YoseFont.gothic(11, weight: .heavy)).foregroundStyle(YoseColor.enji)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .overlay(Rectangle().stroke(YoseColor.enji, lineWidth: 1))
                    Text(stamped ? "\(totalPower)" : "\(totalPower - powerDelta)").font(YoseFont.number(22, weight: .black)).foregroundStyle(YoseColor.sumi)
                        .contentTransition(.numericText(value: Double(stamped ? totalPower : totalPower - powerDelta)))
                    if powerDelta > 0 && stamped {
                        Text("+\(powerDelta)").font(YoseFont.number(13, weight: .heavy)).foregroundStyle(YoseColor.shu)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 9).padding(.horizontal, 10)
            .background(YoseColor.kinari)
            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
            .background(Rectangle().fill(YoseColor.sumi).offset(y: 3))

            if !subItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("同時昇格").font(YoseFont.gothic(11, weight: .heavy)).foregroundStyle(YoseColor.haiSumi)
                    HStack(spacing: 6) {
                        ForEach(subItems) { sub in
                            HStack(spacing: 4) {
                                Text(sub.abilityShort).font(YoseFont.gothic(10, weight: .black)).foregroundStyle(YoseColor.kinari)
                                    .frame(width: 18, height: 18).background(sub.abilityColor)
                                Text("\(sub.fromRank)▶\(sub.toRank)").font(YoseFont.gothic(13, weight: .black)).foregroundStyle(YoseColor.shu)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(YoseColor.kinari)
                            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                        }
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(stamped ? 1 : 0).offset(y: stamped ? 0 : 8)
            }
        }
        .padding(16)
    }

    // MARK: - 演出タイムライン制御（1.45秒で自動消去・1タップ即スキップ）

    private func runSequence(for item: RankUpItem) async {
        shownValue = item.beforeValue
        if reduceMotion {
            cardAppeared = true
            badgeLanded = true
            stamped = true
            shownValue = item.afterValue
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            dismissImmediately()
            return
        }

        // 0.00s: 暗転＋カード出現（新ランクはまだ「？」＝溜め）
        withAnimation(.easeOut(duration: 0.14)) { cardAppeared = true }

        // 0.34s: 白金フラッシュ＋新ランク木札の叩きつけ＋火花
        try? await Task.sleep(nanoseconds: 340_000_000)
        guard !isDismissed else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        flash = 0.26
        withAnimation(.easeOut(duration: 0.3)) { flash = 0 }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) { badgeLanded = true }
        burstTrigger += 1
        withAnimation(.linear(duration: 0.04)) { shakeOffset = 6 }
        try? await Task.sleep(nanoseconds: 45_000_000)
        withAnimation(.linear(duration: 0.05)) { shakeOffset = -4 }
        try? await Task.sleep(nanoseconds: 50_000_000)
        withAnimation(.linear(duration: 0.05)) { shakeOffset = 0 }

        // 0.55s: 朱印『昇格』＋数値更新
        try? await Task.sleep(nanoseconds: 120_000_000)
        guard !isDismissed else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) { stamped = true }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) { shownValue = item.afterValue }
        withAnimation(.linear(duration: 0.04)) { shakeOffset = 3 }
        try? await Task.sleep(nanoseconds: 45_000_000)
        withAnimation(.linear(duration: 0.05)) { shakeOffset = 0 }

        // 余韻のあと自動クローズ（タップで即閉じ）
        try? await Task.sleep(nanoseconds: 1_300_000_000)
        guard !isDismissed else { return }
        dismissImmediately()
    }

    private func dismissImmediately() {
        guard !isDismissed else { return }
        isDismissed = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut(duration: 0.12)) {
            cardAppeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            onDismiss()
        }
    }

    /// デザインシステム準拠の等級カラー（高コントラスト版）
    static func rankColor(_ rank: String) -> Color {
        switch rank {
        case "S": return YoseColor.kinBright
        case "A": return YoseColor.shu
        case "B": return YoseColor.tokiwa
        case "C": return Color(hex: 0x6B8E23)
        case "D": return Color(hex: 0xC86428)
        case "E": return YoseColor.expTan
        case "F": return Color(hex: 0x5A6B7C)
        default:  return YoseColor.haiSumi
        }
    }
}


/// ランクアップ着地の後光：黒地に加算合成する黄金ラジアル＋不均一な光条（外周ほど消える・中央は空洞）
private struct RankUpHalo: View {
    let strong: Bool
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height * 0.46)
                let maxR = max(size.width, size.height) * (strong ? 0.8 : 0.42)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - maxR, y: c.y - maxR, width: maxR * 2, height: maxR * 2)),
                         with: .radialGradient(Gradient(colors: [YoseColor.kinBright.opacity(strong ? 0.55 : 0.30), YoseColor.shu.opacity(0.12), .clear]),
                                               center: c, startRadius: 10, endRadius: maxR))
                guard strong else { return }
                let n = 26
                for i in 0..<n {
                    let a = Double(i) / Double(n) * 2 * .pi + t * 0.05
                    let half = (i % 3 == 0) ? 0.05 : 0.016
                    let len = maxR * ((i % 3 == 0) ? 1.0 : 0.7)
                    var p = Path()
                    p.move(to: c)
                    p.addLine(to: CGPoint(x: c.x + cos(a - half) * len, y: c.y + sin(a - half) * len))
                    p.addLine(to: CGPoint(x: c.x + cos(a + half) * len, y: c.y + sin(a + half) * len))
                    p.closeSubpath()
                    ctx.fill(p, with: .radialGradient(Gradient(colors: [.clear, YoseColor.kinBright.opacity(0.28), .clear]),
                                                      center: c, startRadius: maxR * 0.2, endRadius: len))
                }
            }
        }
    }
}
