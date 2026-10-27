import SwiftUI
import UIKit

// ============================================================================
// MARK: - 優勝全画面演出（YoseChampionCelebrationView）
// 393×852pt 基準 / 外部画像ゼロ / 7層レイヤー＋時間軸シーケンス＋1タップ即確定対応
// ============================================================================

/// 優勝演出の余韻の長さ（秒）。これ以降は光・幕の更新を止め、紙吹雪は新しい粒を出さず落ちきったら止める（CPU 節約）
let championHoldSeconds: Double = 6.5
let championSettleSeconds: Double = 13.0

public struct YoseChampionCelebrationView: View {
    public let tournamentName: String      // 例：「頂グランプリ 第4回 大会」
    public let generationText: String      // 例：「第4代 王者」
    public let duoName: String             // 例：「満月ロケット」
    public let prizeAmountYen: Int         // 例：10_000_000
    public let partnerName: String         // 例：「谷口」
    public let partnerLine: String         // 例：「……なあ、腹減ったな。焼肉、特上頼んでいいか？」
    public let mcName: String              // 例：「司会・鳴海」
    public let mcComment: String           // 例：「見事4票獲得！今年の漫才日本一は『満月ロケット』です！！」
    public let onFinish: () -> Void

    // アニメーション時間軸ステート
    @State private var startTime: Date = .now
    @State private var phase: Int = 0
    // phase 0: 0.00s 暗転溜め
    // phase 1: 0.28s フラッシュ＆キャノン砲発射＆看板枠出現
    // phase 2: 0.42s 『優』着地
    // phase 3: 0.50s 『勝』着地＋画面大揺れ＋放射火花
    // phase 4: 0.78s コンビ名＆朱印『日本一』叩きつけ＋斜光シマー
    // phase 5: 1.10s 賞金ボード＆下部セリフ帯出現（2.0sで完全完了状態）

    @State private var flashOpacity: Double = 0.0
    @State private var shakeTrigger: Int = 0
    @State private var burstTrigger: Int = 0
    @State private var shimmerTrigger: Int = 0
    @State private var displayedPrize: Int = 0
    @State private var isCompleted: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        tournamentName: String = "頂グランプリ 決勝戦",
        generationText: String = "第4代 王者",
        duoName: String = "あなたのコンビ",
        prizeAmountYen: Int = 10_000_000,
        partnerName: String = "相方",
        partnerLine: String = "「やったね。ここまで、本当によく頑張った」",
        mcName: String = "司会・鳴海",
        mcComment: String = "「決まりました！！今夜、幾千組の頂点に立ったのは——この2人です！」",
        onFinish: @escaping () -> Void = {}
    ) {
        self.tournamentName = tournamentName
        self.generationText = generationText
        self.duoName = duoName
        self.prizeAmountYen = prizeAmountYen
        self.partnerName = partnerName
        self.partnerLine = partnerLine
        self.mcName = mcName
        self.mcComment = mcComment
        self.onFinish = onFinish
    }

    public var body: some View {
        ZStack {
            // ----------------------------------------------------------------
            // Layer 1 & 2: 夜の特番スタジオ暗転背景＋定式幕＋サーチライト6本＋床スモーク
            // ----------------------------------------------------------------
            ChampionStageBackdropCanvas(isLit: phase >= 1, startTime: startTime)
                .ignoresSafeArea()

            // ----------------------------------------------------------------
            // Layer 3: 中景奥・回転する二重黄金後光＋不規則な劇画集中線（加算合成）
            // ----------------------------------------------------------------
            if phase >= 1 {
                ChampionGoldenHaloCanvas(startTime: startTime)
                    .mask(LinearGradient(stops: [.init(color: .white, location: 0), .init(color: .white, location: 0.62), .init(color: .clear, location: 0.74), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
                    .blendMode(.plusLighter)
                    .transition(.opacity)
                    .ignoresSafeArea()
            }

            // ----------------------------------------------------------------
            // Layer 4: 特効キャノン砲（金テープ40本＋奥層の和紙吹雪120枚）
            // ----------------------------------------------------------------
            if phase >= 1 {
                ChampionCannonAndConfettiCanvas(
                    startTime: startTime,
                    foregroundLayer: false
                )
                .ignoresSafeArea()
            }

            // ----------------------------------------------------------------
            // Layer 5: 主役UI（黒漆二重金枠の大看板・『優 勝』・コンビ名・賞金木札）
            // ----------------------------------------------------------------
            VStack(spacing: 0) {
                // 上部：生放送 LIVE ヘッダー帯
                championLiveTopBar
                    .opacity(phase >= 1 ? 1.0 : 0.4)

                Spacer(minLength: 8)

                // 中央主役：優勝大看板＋コンビ名額縁＋放射火花
                ZStack {
                    // 着地瞬間の金箔・朱肉バースト火花
                    YoseBurstParticles(
                        trigger: burstTrigger,
                        count: 32,
                        colors: [YoseColor.kinBright, Color.white, YoseColor.shu, YoseColor.kin],
                        radius: 175,
                        duration: 0.75
                    )
                    .frame(width: 360, height: 320)

                    if phase >= 1 {
                        championMainSignboard
                            .transition(.scale(scale: 0.72).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 14)

                // 優勝賞金ボード木札
                // 位置固定：最初から場所を確保し、透明度とオフセットだけで出す（大看板をジャンプさせない）
                championPrizePlaque
                    .padding(.top, 12)
                    .padding(.horizontal, 20)
                    .opacity(phase >= 5 ? 1 : 0)
                    .offset(y: phase >= 5 ? 0 : 18)
                    .animation(Theme.Motion.r(.easeOut(duration: 0.3)), value: phase >= 5)

                Spacer(minLength: 10)

                // 下部：相方の耳打ちセリフ箱 ＋ 番組下三分テロップ ＋ 次へボタン
                VStack(spacing: 8) {
                    partnerEmotionBox
                    broadcastLowerThirdBar
                    proceedActionBar
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
                .opacity(phase >= 5 ? 1 : 0)
                .offset(y: phase >= 5 ? 0 : 18)
                .allowsHitTesting(phase >= 5)
                .animation(Theme.Motion.r(.easeOut(duration: 0.3)), value: phase >= 5)
            }
            .yoseShake(trigger: shakeTrigger, intensity: .heavy, axis: .vertical)

            // ----------------------------------------------------------------
            // Layer 6: 最前景（看板の手前を横切る大粒の金箔吹雪＋白金露出フラッシュ）
            // ----------------------------------------------------------------
            if phase >= 1 {
                ChampionCannonAndConfettiCanvas(
                    startTime: startTime,
                    foregroundLayer: true
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            // 決定瞬間の白金フラッシュ（露出オーバー → 減衰）
            Color(hex: 0xFFF7D6)
                .opacity(flashOpacity)
                .blendMode(.plusLighter)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            handleScreenTap()
        }
        .onAppear {
            runCelebrationTimeline()
        }
    }

    // ========================================================================
    // MARK: - 主役コンポーネント群（Layer 5 & 7）
    // ========================================================================

    /// 上部：生放送 LIVE 帯
    private var championLiveTopBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                Text("LIVE 生放送")
                    .font(YoseFont.gothic(12, weight: .black))
                    .foregroundStyle(YoseColor.kinari)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(YoseColor.shu)
            .overlay(Rectangle().stroke(YoseColor.kinBright, lineWidth: 1.5))

            Text(tournamentName)
                .font(YoseFont.gothic(13, weight: .heavy))
                .foregroundStyle(YoseColor.kinBright)
                .lineLimit(1)

            Spacer()

            Text(isCompleted ? "タップで進む ▶" : "スキップ ▶▶")
                .font(YoseFont.gothic(12, weight: .heavy))
                .foregroundStyle(YoseColor.sumi)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(YoseColor.ki)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(YoseColor.sumi, lineWidth: 1.5))
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(YoseColor.kuroUrushi.opacity(0.95))
        .overlay(alignment: .bottom) {
            Rectangle().fill(YoseColor.kinBright).frame(height: 1.5)
        }
    }

    /// 中央主役：黒漆×二重金枠の特大『優勝』番付看板＋コンビ名札＋朱印『日本一』
    private var championMainSignboard: some View {
        VStack(spacing: 0) {
            // 1. 看板最上部の金冠リボンバー
            HStack(spacing: 8) {
                OrnamentDiamond()
                Text("漫 才 の 頂 、 こ こ に 決 ま る")
                    .font(YoseFont.gothic(12, weight: .black))
                    .tracking(3)
                    .foregroundStyle(YoseColor.kuroUrushi)
                OrnamentDiamond()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 26)
            .background(
                LinearGradient(
                    colors: [YoseColor.kin, YoseColor.kinBright, Color(hex: 0xFFF0B8), YoseColor.kinBright, YoseColor.kin],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(alignment: .bottom) {
                Rectangle().fill(YoseColor.sumi).frame(height: 2)
            }

            // 2. 黒漆のメイン舞台面（『優 勝』特大金袋文字＋コンビ名めくり札）
            ZStack {
                // 背後の黒漆＋臙脂の市松/斜め格子地紋
                SignboardInnerPatternView()

                VStack(spacing: 14) {
                    // 大会名・第N代王者ラベル
                    HStack(spacing: 8) {
                        Rectangle().fill(YoseColor.kin).frame(width: 24, height: 1.5)
                        Text("\(tournamentName) ・ \(generationText)")
                            .font(YoseFont.gothic(13, weight: .heavy))
                            .tracking(1.0)
                            .foregroundStyle(YoseColor.kinBright)
                        Rectangle().fill(YoseColor.kin).frame(width: 24, height: 1.5)
                    }
                    .padding(.top, 14)

                    // 『優 勝』特大金属グラデーション袋文字（1文字ずつ時間差で叩きつける）
                    HStack(spacing: 14) {
                        ChampionKanjiSeal(
                            kanji: "優",
                            isLanded: phase >= 2
                        )
                        ChampionKanjiSeal(
                            kanji: "勝",
                            isLanded: phase >= 3
                        )
                    }
                    .padding(.vertical, 2)

                    // 主役コンビ名の白和紙・二重枠めくり額縁
                    if phase >= 4 {
                        VStack(spacing: 4) {
                            Text("CHAMPION DUO")
                                .font(YoseFont.gothic(12, weight: .black))
                                .tracking(2.0)
                                .foregroundStyle(YoseColor.shu)

                            Text(duoName)
                                .font(YoseFont.mincho(30))
                                .foregroundStyle(YoseColor.sumi)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(YoseColor.washi)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                        .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1.5).padding(3))
                        .background(Rectangle().fill(YoseColor.sumi).offset(x: 0, y: 3))
                        .padding(.horizontal, 18)
                        .padding(.bottom, 16)
                        .transition(.scale(scale: 1.25).combined(with: .opacity))
                    } else {
                        Spacer().frame(height: 92)
                    }
                }

                // 四隅の金飾り金具（L字の彫金コーナー）
                SignboardCornerBrackets()

                // 右肩に叩きつけられる特大朱印『日本一』
                VStack {
                    HStack {
                        Spacer()
                        YoseAnimatedHanko(
                            text: "日本一",
                            isStamped: phase >= 4,
                            isSquare: true,
                            angle: -8,
                            playHapticsAndSound: false
                        )
                        .scaleEffect(0.92)
                        .padding(.top, 34)
                        .padding(.trailing, -4)
                    }
                    Spacer()
                }
            }
            .frame(height: 256)
        }
        .clipShape(RoundedRectangle(cornerRadius: 2))
        // 三重額縁（墨2pt → 山吹金3.5pt → 黒漆1.5pt）
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(YoseColor.kinBright, lineWidth: 3.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(YoseColor.sumi, lineWidth: 2)
                .padding(-2)
        )
        // ハードシャドウ（Blur 0・物質の厚み）
        .background(
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.black)
                .offset(x: 0, y: 6)
        )
        .yoseLightStreak(trigger: shimmerTrigger, color: YoseColor.kinBright)
    }

    /// 優勝賞金の小判・木札ボード
    private var championPrizePlaque: some View {
        HStack(spacing: 12) {
            // 左：賞金角印タグ
            Text("優勝賞金")
                .font(YoseFont.gothic(13, weight: .black))
                .lineLimit(1).fixedSize()
                .foregroundStyle(YoseColor.kuroUrushi)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(YoseColor.kinBright)
                .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))

            Spacer()

            // 右：等幅カウントアップ金額
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("¥")
                    .font(YoseFont.number(20, weight: .black))
                    .foregroundStyle(YoseColor.kinBright)
                Text("\(displayedPrize.formatted())")
                    .font(YoseFont.number(28, weight: .black))
                    .foregroundStyle(Color(hex: 0xFFF7D6))
                    .contentTransition(.numericText(value: Double(displayedPrize)))
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .lineLimit(1)
            .yoseNumberPop(value: displayedPrize, highlightColor: YoseColor.kinBright, scalePeak: 1.18)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(YoseColor.kuroUrushi)
        .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 2))
        .background(Rectangle().fill(YoseColor.sumi).offset(y: 3))
    }

    /// 相方の感極まった一言セリフ箱（白和紙×明朝体）
    private var partnerEmotionBox: some View {
        HStack(alignment: .top, spacing: 10) {
            // 相方名縦札風ラベル
            Text(partnerName)
                .font(YoseFont.gothic(13, weight: .heavy))
                .foregroundStyle(YoseColor.kinari)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(YoseColor.shu)
                .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))

            Text(partnerLine)
                .font(YoseFont.mincho(15))
                .lineSpacing(5)
                .foregroundStyle(YoseColor.sumi)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(YoseColor.washi)
        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
        .background(Rectangle().fill(YoseColor.sumi).offset(y: 3))
    }

    /// 生放送の番組テロップ帯（Lower Third）
    private var broadcastLowerThirdBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Rectangle().fill(YoseColor.shu).frame(width: 80, height: 3)
                Rectangle().fill(YoseColor.kinBright).frame(height: 3)
            }
            HStack(spacing: 10) {
                Text(mcName)
                    .font(YoseFont.gothic(12, weight: .heavy))
                    .foregroundStyle(YoseColor.kinBright)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(YoseColor.enji)
                    .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1))

                Text(mcComment)
                    .font(YoseFont.mincho(14))
                    .lineSpacing(3)
                    .foregroundStyle(YoseColor.kinari)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(YoseColor.kuroUrushi.opacity(0.95))
            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
        }
    }

    /// 最下部の進行ボタン
    private var proceedActionBar: some View {
        Button(action: onFinish) {
            HStack(spacing: 8) {
                Text("表彰式・エンディングへ進む")
                    .font(YoseFont.gothic(16, weight: .heavy))
                Image(systemName: "arrowtriangle.right.fill").accessibilityHidden(true)
                    .font(.system(size: Font.mzScaled(12), weight: .black))
            }
            .foregroundStyle(YoseColor.kinari)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(YoseColor.shu)
            .overlay(Rectangle().stroke(YoseColor.kinBright, lineWidth: 2))
            .background(Rectangle().fill(YoseColor.sumi).offset(y: 3))
        }
        .buttonStyle(.plain)
    }

    // ========================================================================
    // MARK: - 時間軸シーケンス制御＆1タップ即完了（Fast-Forward）
    // ========================================================================

    private func runCelebrationTimeline() {
        startTime = .now
        if reduceMotion {
            completeImmediately()
            return
        }

        // 0.00s: Phase 0（暗転と溜め）
        phase = 0
        displayedPrize = 0
        YoseFX.impact(.soft, intensity: 0.8)

        // 0.28s: Phase 1（白金フラッシュ＋キャノン砲発射＋大看板出現）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            guard !isCompleted else { return }
            flashOpacity = 0.92
            withAnimation(Theme.Motion.r(.easeOut(duration: 0.35))) {
                flashOpacity = 0.0
            }
            withAnimation(Theme.Motion.r(.spring(response: 0.28, dampingFraction: 0.72))) {
                phase = 1
            }
            YoseFX.notify(.success)
            YoseFX.sound(.championImpact)
        }

        // 0.42s: Phase 2（『優』叩きつけ）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            guard !isCompleted else { return }
            withAnimation(Theme.Motion.r(.spring(response: 0.22, dampingFraction: 0.56))) {
                phase = 2
            }
            YoseFX.impact(.heavy, intensity: 1.0)
        }

        // 0.50s: Phase 3（『勝』叩きつけ＋画面縦大揺れ＋金火花バースト）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) {
            guard !isCompleted else { return }
            withAnimation(Theme.Motion.r(.spring(response: 0.22, dampingFraction: 0.54))) {
                phase = 3
            }
            shakeTrigger += 1
            burstTrigger += 1
            YoseFX.impact(.heavy, intensity: 1.0)
        }

        // 0.78s: Phase 4（コンビ名めくり＋朱印『日本一』＋斜光シマー）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.78) {
            guard !isCompleted else { return }
            withAnimation(Theme.Motion.r(.spring(response: 0.26, dampingFraction: 0.68))) {
                phase = 4
            }
            shimmerTrigger += 1
            YoseFX.impact(.rigid, intensity: 0.95)
            YoseFX.sound(.stampHeavy)
        }

        // 1.15s: Phase 5（賞金木札カウントアップ＋相方セリフ＋完了状態）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            guard !isCompleted else { return }
            withAnimation(Theme.Motion.r(.spring(response: 0.32, dampingFraction: 0.78))) {
                phase = 5
                displayedPrize = prizeAmountYen
            }
            isCompleted = true
            YoseFX.impact(.medium, intensity: 0.8)
            YoseFX.sound(.prizeGet)
        }
    }

    private func handleScreenTap() {
        if !isCompleted {
            // 演出途中のタップ：0.06秒で最終完成フレームへ即スキップ
            completeImmediately()
        } else {
            // 完成後のタップ：次画面へ進む
            YoseFX.impact(.rigid, intensity: 0.75)
            onFinish()
        }
    }

    private func completeImmediately() {
        withAnimation(Theme.Motion.r(.easeOut(duration: 0.08))) {
            flashOpacity = 0.0
            phase = 5
            displayedPrize = prizeAmountYen
            isCompleted = true
        }
        shimmerTrigger += 1
    }
}

// ============================================================================
// MARK: - 部品A：『優』『勝』の金属グラデーション袋文字シール
// ============================================================================

private struct ChampionKanjiSeal: View {
    let kanji: String
    let isLanded: Bool

    var body: some View {
        ZStack {
            // 墨の極太8方向アウトライン＋下影
            ForEach([-1, 0, 1], id: \.self) { dx in
                ForEach([-1, 0, 1], id: \.self) { dy in
                    if dx != 0 || dy != 0 {
                        Text(kanji)
                            .font(YoseFont.mincho(92))
                            .foregroundStyle(Color.black)
                            .offset(x: CGFloat(dx) * 3.5, y: CGFloat(dy) * 3.5 + 5.0)
                    }
                }
            }

            // 本体：白金 → 山吹金 → 琥珀金の金属光沢グラデーション塗り
            Text(kanji)
                .font(YoseFont.mincho(92))
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: 0xFFFBE6), location: 0.0),
                            .init(color: YoseColor.kinBright, location: 0.45),
                            .init(color: Color(hex: 0xB8861B), location: 0.85),
                            .init(color: YoseColor.kinBright, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .scaleEffect(isLanded ? 1.0 : 2.55)
        .opacity(isLanded ? 1.0 : 0.0)
    }
}

// ============================================================================
// MARK: - 部品B：看板内部の伝統地紋＆四隅の彫金金具
// ============================================================================

private struct SignboardInnerPatternView: View {
    var body: some View {
        Canvas { context, size in
            // 黒漆のベースに中央の臙脂グロー
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(rect), with: .color(YoseColor.kuroUrushi))
            context.fill(
                Path(rect),
                with: .radialGradient(
                    Gradient(colors: [YoseColor.enji.opacity(0.65), YoseColor.kuroUrushi]),
                    center: CGPoint(x: size.width / 2, y: size.height / 2),
                    startRadius: 10,
                    endRadius: size.width * 0.6
                )
            )

            // 斜めの金網目地紋（うっすらと高級感を出す）
            let step: CGFloat = 28
            for x in stride(from: -size.height, through: size.width + size.height, by: step) {
                var p1 = Path()
                p1.move(to: CGPoint(x: x, y: 0))
                p1.addLine(to: CGPoint(x: x + size.height, y: size.height))
                context.stroke(p1, with: .color(YoseColor.kin.opacity(0.10)), lineWidth: 1)

                var p2 = Path()
                p2.move(to: CGPoint(x: x + size.height, y: 0))
                p2.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(p2, with: .color(YoseColor.kin.opacity(0.10)), lineWidth: 1)
            }
        }.accessibilityHidden(true)
    }
}

private struct SignboardCornerBrackets: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let len: CGFloat = 18
            let inset: CGFloat = 6

            Canvas { context, _ in
                let corners: [(CGPoint, CGFloat, CGFloat)] = [
                    (CGPoint(x: inset, y: inset), 1, 1),
                    (CGPoint(x: w - inset, y: inset), -1, 1),
                    (CGPoint(x: inset, y: h - inset), 1, -1),
                    (CGPoint(x: w - inset, y: h - inset), -1, -1)
                ]
                for (pt, dx, dy) in corners {
                    var path = Path()
                    path.move(to: CGPoint(x: pt.x, y: pt.y + dy * len))
                    path.addLine(to: pt)
                    path.addLine(to: CGPoint(x: pt.x + dx * len, y: pt.y))
                    context.stroke(path, with: .color(YoseColor.kinBright), lineWidth: 3)
                }
            }.accessibilityHidden(true)
        }
        .allowsHitTesting(false)
    }
}

private struct OrnamentDiamond: View {
    var body: some View {
        Rectangle()
            .fill(YoseColor.kuroUrushi)
            .frame(width: 6, height: 6)
            .rotationEffect(.degrees(45))
    }
}

// ============================================================================
// MARK: - 部品C（Layer 1 & 2）：夜の特番スタジオ・定式幕・6本サーチライト・床スモーク
// ============================================================================

private struct ChampionStageBackdropCanvas: View {
    let isLit: Bool
    let startTime: Date

    @State private var frozen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: frozen || reduceMotion)) { timeline in
            let t = reduceMotion ? championHoldSeconds : min(timeline.date.timeIntervalSince(startTime), championHoldSeconds)
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)

                // 1. 深夜スタジオの漆黒〜臙脂グラデーション（明るい生成りベタ塗りを全廃）
                let topColor = isLit ? Color(hex: 0x2B110E) : Color(hex: 0x090707)
                let midColor = isLit ? YoseColor.kuroUrushi : Color(hex: 0x0D0A09)
                context.fill(
                    Path(rect),
                    with: .linearGradient(
                        Gradient(colors: [topColor, midColor, Color(hex: 0x080605)]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )

                // 2. 背景の定式幕（黒・柿・萌黄の縦縞が暗がりに重厚に浮かぶ）
                let stripeCount = 15
                let stripeW = size.width / CGFloat(stripeCount)
                for i in 0..<stripeCount {
                    let stripeRect = CGRect(x: CGFloat(i) * stripeW, y: 0, width: stripeW, height: size.height * 0.74)
                    let stripeColor: Color
                    if i % 3 == 0 {
                        stripeColor = Color.black.opacity(0.35)
                    } else if i % 3 == 1 {
                        stripeColor = YoseColor.enji.opacity(isLit ? 0.22 : 0.08)
                    } else {
                        stripeColor = YoseColor.tokiwa.opacity(isLit ? 0.16 : 0.05)
                    }
                    context.fill(Path(stripeRect), with: .color(stripeColor))
                }

                guard isLit else {
                    // 溜め：中央へ落ちる細いピンスポットと、中心へ吸い込まれる金粉
                    let cx = size.width / 2, focusY = size.height * 0.40, floorY = size.height * 0.72
                    let grow = min(1.0, max(0.0, t / 0.28))
                    var spot = Path()
                    spot.move(to: CGPoint(x: cx - 3, y: 0)); spot.addLine(to: CGPoint(x: cx + 3, y: 0))
                    spot.addLine(to: CGPoint(x: cx + 58, y: floorY)); spot.addLine(to: CGPoint(x: cx - 58, y: floorY))
                    spot.closeSubpath()
                    context.fill(spot, with: .linearGradient(
                        Gradient(colors: [Color(hex: 0xFFF2C4).opacity(0.05), Color(hex: 0xFFF2C4).opacity(0.30 + 0.25 * grow), Color(hex: 0xFFF2C4).opacity(0.0)]),
                        startPoint: CGPoint(x: cx, y: 0), endPoint: CGPoint(x: cx, y: floorY)))
                    context.fill(Path(ellipseIn: CGRect(x: cx - 90, y: floorY - 12, width: 180, height: 26)),
                                 with: .radialGradient(Gradient(colors: [YoseColor.kinBright.opacity(0.45), .clear]),
                                                       center: CGPoint(x: cx, y: floorY + 1), startRadius: 0, endRadius: 90))
                    for k in 0..<16 {
                        let jit = abs(sin(Double(k) * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
                        let ang = Double(k) / 16.0 * 2 * .pi + (jit - 0.5) * 0.9
                        let r0 = 60.0 + jit * 120.0
                        let r = r0 * (1.0 - 0.9 * grow)
                        let pt = CGPoint(x: cx + CGFloat(cos(ang) * r), y: focusY + CGFloat(sin(ang) * r * 0.8))
                        let sz: CGFloat = 2.0 + CGFloat(k % 3)
                        context.fill(Path(CGRect(x: pt.x - sz / 2, y: pt.y - sz / 2, width: sz, height: sz)),
                                     with: .color(YoseColor.kinBright.opacity(0.35 + 0.5 * grow)))
                    }
                    return
                }

                // 3. 下方・天井から交差する6本の黄金サーチライト（加算合成風グラデーション）
                let beamCount = 6
                for i in 0..<beamCount {
                    let ratio = Double(i) / Double(beamCount - 1)
                    let topX = size.width * (0.08 + 0.84 * ratio)
                    let sway = sin(t * 1.4 + Double(i) * 1.1) * 36.0
                    let bottomX = size.width * (0.18 + 0.64 * ratio) + sway

                    var beam = Path()
                    beam.move(to: CGPoint(x: topX - 10, y: 0))
                    beam.addLine(to: CGPoint(x: topX + 10, y: 0))
                    beam.addLine(to: CGPoint(x: bottomX + 85, y: size.height * 0.82))
                    beam.addLine(to: CGPoint(x: bottomX - 85, y: size.height * 0.82))
                    beam.closeSubpath()

                    let beamColor = (i % 2 == 0) ? YoseColor.kinBright : YoseColor.shu
                    context.fill(
                        beam,
                        with: .linearGradient(
                            Gradient(colors: [
                                beamColor.opacity(0.34),
                                beamColor.opacity(0.10),
                                .clear
                            ]),
                            startPoint: CGPoint(x: topX, y: 0),
                            endPoint: CGPoint(x: bottomX, y: size.height * 0.82)
                        )
                    )
                }

                // 4. 檜舞台の黒漆床と金ライトの照り返し
                let floorY = size.height * 0.72
                let floorRect = CGRect(x: 0, y: floorY, width: size.width, height: size.height - floorY)
                context.fill(
                    Path(floorRect),
                    with: .linearGradient(
                        Gradient(colors: [Color(hex: 0x3A2414), Color(hex: 0x140E0A)]),
                        startPoint: CGPoint(x: 0, y: floorY),
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )
                context.fill(
                    Path(CGRect(x: 0, y: floorY, width: size.width, height: 2)),
                    with: .color(YoseColor.kin.opacity(0.55))
                )
            }.accessibilityHidden(true)
        }
        .task {
            let rest = championHoldSeconds - Date().timeIntervalSince(startTime)
            try? await Task.sleep(nanoseconds: UInt64(max(0, rest) * 1_000_000_000))
            frozen = true
        }
    }
}

// ============================================================================
// MARK: - 部品D（Layer 3）：二重回転する黄金後光＋不規則集中線（AIサンバーストの完全代替）
// ============================================================================

private struct ChampionGoldenHaloCanvas: View {
    let startTime: Date

    @State private var frozen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: frozen || reduceMotion)) { timeline in
            let t = reduceMotion ? championHoldSeconds : min(timeline.date.timeIntervalSince(startTime), championHoldSeconds)
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height * 0.36)
                let maxR = hypot(size.width, size.height) * 0.62

                // 1. 中心の白金〜山吹金コアグロー（光源の核を作る）
                let glowRect = CGRect(x: center.x - maxR, y: center.y - maxR, width: maxR * 2, height: maxR * 2)
                context.fill(
                    Path(ellipseIn: glowRect),
                    with: .radialGradient(
                        Gradient(stops: [
                            .init(color: Color.white.opacity(0.55), location: 0.0),
                            .init(color: YoseColor.kinBright.opacity(0.38), location: 0.24),
                            .init(color: YoseColor.shu.opacity(0.16), location: 0.52),
                            .init(color: .clear, location: 0.85)
                        ]),
                        center: center,
                        startRadius: 4,
                        endRadius: maxR
                    )
                )

                // 2. 第1層：時計回りにゆっくり回る太細ミックスの後光（外側へ減衰）
                let rayCount = 24
                for i in 0..<rayCount {
                    let baseAngle = (Double(i) / Double(rayCount)) * (.pi * 2.0) + t * 0.18
                    // 均一にせず、太い光条と細い光条を交互に配置
                    let halfSpread = (i % 2 == 0) ? 0.048 : 0.018
                    let rayLength = maxR * ((i % 3 == 0) ? 1.0 : 0.76)

                    var wedge = Path()
                    wedge.move(to: center)
                    wedge.addLine(to: CGPoint(
                        x: center.x + CGFloat(cos(baseAngle - halfSpread)) * rayLength,
                        y: center.y + CGFloat(sin(baseAngle - halfSpread)) * rayLength
                    ))
                    wedge.addLine(to: CGPoint(
                        x: center.x + CGFloat(cos(baseAngle + halfSpread)) * rayLength,
                        y: center.y + CGFloat(sin(baseAngle + halfSpread)) * rayLength
                    ))
                    wedge.closeSubpath()

                    context.fill(
                        wedge,
                        with: .radialGradient(
                            Gradient(colors: [
                                YoseColor.kinBright.opacity(0.32),
                                YoseColor.kin.opacity(0.10),
                                .clear
                            ]),
                            center: center,
                            startRadius: 30,
                            endRadius: rayLength
                        )
                    )
                }

                // 3. 第2層：外周の不規則な劇画集中線（中央の看板領域を空ける）
                let speedLineCount = 44
                let innerBase = min(size.width, size.height) * 0.40
                for i in 0..<speedLineCount {
                    let angle = (Double(i) / Double(speedLineCount)) * (.pi * 2.0) - t * 0.05
                    let jitter = CGFloat(sin(Double(i) * 2.7 + t * 6.0) * 16.0)
                    let r1 = innerBase + jitter
                    let spread = 0.004 + abs(cos(Double(i) * 1.9)) * 0.008

                    var spike = Path()
                    spike.move(to: CGPoint(
                        x: center.x + CGFloat(cos(angle)) * r1,
                        y: center.y + CGFloat(sin(angle)) * r1
                    ))
                    spike.addLine(to: CGPoint(
                        x: center.x + CGFloat(cos(angle - spread)) * maxR,
                        y: center.y + CGFloat(sin(angle - spread)) * maxR
                    ))
                    spike.addLine(to: CGPoint(
                        x: center.x + CGFloat(cos(angle + spread)) * maxR,
                        y: center.y + CGFloat(sin(angle + spread)) * maxR
                    ))
                    spike.closeSubpath()

                    context.fill(spike, with: .color(YoseColor.kinBright.opacity(0.22)))
                }
            }.accessibilityHidden(true)
        }
        .task {
            let rest = championHoldSeconds - Date().timeIntervalSince(startTime)
            try? await Task.sleep(nanoseconds: UInt64(max(0, rest) * 1_000_000_000))
            frozen = true
        }
    }
}

// ============================================================================
// MARK: - 部品E（Layer 4 & 6）：特効キャノン砲の金テープ40本＋奥・手前2層の和紙吹雪
// ============================================================================

private struct ChampionCannonAndConfettiCanvas: View {
    let startTime: Date
    let foregroundLayer: Bool // false: 看板の奥を舞う120枚＋金テープ / true: 看板の手前を横切る大粒40枚

    @State private var frozen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: frozen || reduceMotion)) { timeline in
            let elapsed = max(0, min(timeline.date.timeIntervalSince(startTime), championHoldSeconds + championSettleSeconds) - 0.28)
            Canvas { context, size in
                guard elapsed > 0, !reduceMotion else { return }

                // A. 奥レイヤーのみ：左右下方のキャノン砲から噴き上がる金・朱の放物線テープ（36本）
                if !foregroundLayer {
                    let tapeCount = 36
                    for i in 0..<tapeCount {
                        let seed = Double(i) * 1.618
                        let fromLeft = (i % 2 == 0)
                        let originX: CGFloat = fromLeft ? 16 : size.width - 16
                        let originY: CGFloat = size.height * 0.76

                        let delay = Double(i % 6) * 0.035
                        let localT = max(0, min(elapsed - delay, 2.2))
                        guard localT > 0 else { continue }

                        let dirX: CGFloat = fromLeft ? 1.0 : -1.0
                        let vx = CGFloat(130.0 + fmod(seed * 103.0, 210.0)) * dirX
                        let vy = CGFloat(-580.0 - fmod(seed * 149.0, 280.0))
                        let gravity: CGFloat = 390.0

                        var ribbon = Path()
                        let tailT = max(0, localT - 0.55)
                        let steps = 14
                        for s in 0...steps {
                            let sampleT = CGFloat(tailT + (localT - tailT) * (Double(s) / Double(steps)))
                            let wave = sin(sampleT * 8.0 + CGFloat(seed)) * 12.0
                            let px = originX + vx * sampleT + wave
                            let py = originY + vy * sampleT + 0.5 * gravity * sampleT * sampleT
                            if s == 0 {
                                ribbon.move(to: CGPoint(x: px, y: py))
                            } else {
                                ribbon.addLine(to: CGPoint(x: px, y: py))
                            }
                        }

                        let color: Color = (i % 3 == 0) ? YoseColor.kinBright : ((i % 3 == 1) ? YoseColor.kin : YoseColor.shu)
                        context.stroke(
                            ribbon,
                            with: .color(color.opacity(0.90)),
                            lineWidth: (i % 4 == 0) ? 5.0 : 3.5
                        )
                    }
                }

                // B. 金・朱・白和紙の紙吹雪（奥120枚 / 手前36枚）
                let count = foregroundLayer ? 36 : 120
                let palette: [Color] = [
                    YoseColor.kinBright,
                    Color(hex: 0xFFF4C2),
                    YoseColor.shu,
                    YoseColor.washi,
                    YoseColor.kin
                ]

                for i in 0..<count {
                    let seed = Double(i + (foregroundLayer ? 500 : 0)) * 2.71828
                    let speedY = (foregroundLayer ? 135.0 : 80.0) + fmod(seed * 53.0, 95.0)
                    let startY = -fmod(seed * 113.0, Double(size.height))
                    let totalH = Double(size.height + 80)
                    // 余韻の後は新しい周回に入った粒を出さない（残りが落ちきれば何も描かれない）
                    let endCycle = floor((startY + (championHoldSeconds - 0.28) * speedY + Double(size.height)) / totalH)
                    let nowCycle = floor((startY + elapsed * speedY + Double(size.height)) / totalH)
                    if nowCycle > endCycle { continue }
                    let y = CGFloat(fmod(startY + elapsed * speedY + Double(size.height), totalH)) - 40

                    let baseX = fmod(seed * 211.0, Double(size.width))
                    let swayX = sin(elapsed * 2.6 + seed) * (foregroundLayer ? 28.0 : 16.0)
                    let x = CGFloat(baseX + swayX)

                    let baseW: CGFloat = foregroundLayer ? 14.0 : 8.5
                    let baseH: CGFloat = foregroundLayer ? 8.5 : 5.0
                    let flip = CGFloat(max(0.18, abs(cos(elapsed * 4.5 + seed))))

                    var c = context
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .degrees(sin(elapsed * 2.1 + seed) * 35.0 + seed * 40.0))
                    c.scaleBy(x: 1.0, y: flip)

                    let pieceRect = CGRect(x: -baseW / 2, y: -baseH / 2, width: baseW, height: baseH)
                    let fill = palette[i % palette.count]
                    c.fill(Path(pieceRect), with: .color(fill))
                    c.stroke(Path(pieceRect), with: .color(YoseColor.sumi.opacity(0.55)), lineWidth: 0.7)
                }
            }.accessibilityHidden(true)
        }
        .task {
            let rest = championHoldSeconds + championSettleSeconds - Date().timeIntervalSince(startTime)
            try? await Task.sleep(nanoseconds: UInt64(max(0, rest) * 1_000_000_000))
            frozen = true
        }
    }
}
