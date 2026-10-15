import SwiftUI
import UIKit

// ============================================================================
// MARK: - 0. 演出マネージャ（Haptics & 効果音フックの一元管理）
// ============================================================================

enum YoseSoundEffect: String {
    case kifudaTap       = "SE_KIFUDA_TAP"
    case drumDon         = "SE_DRUM_DON"
    case expTick         = "SE_EXP_TICK"
    case hyoshigiSharp   = "SE_HYOSHIGI_SHARP"
    case greatSuccess    = "SE_GREAT_SUCCESS"
    case abilityPlus     = "SE_ABILITY_PLUS"
    case abilityCommit   = "SE_ABILITY_COMMIT"
    case rankupFanfare   = "SE_RANKUP_FANFARE"
    case stampHeavy      = "SE_STAMP_HEAVY"
    case coinChari       = "SE_COIN_CHARI"
    case registerPay     = "SE_REGISTER_PAY"
    case staminaHeal     = "SE_STAMINA_HEAL"
    case fameUp          = "SE_FAME_UP"
    case eventSelect     = "SE_EVENT_SELECT"
    case eventGood       = "SE_EVENT_GOOD"
    case eventBad        = "SE_EVENT_BAD"
    case entryStamp      = "SE_ENTRY_STAMP"
    case debayashiOpen   = "SE_DEBAYASHI_OPEN"
    case laughSmall      = "SE_LAUGH_SMALL"
    case laughMid        = "SE_LAUGH_MID"
    case laughRoar       = "SE_LAUGH_ROAR"
    case rollTaiko       = "SE_ROLL_TAIKO"
    case judgePass       = "SE_JUDGE_PASS"
    case judgeFail       = "SE_JUDGE_FAIL"
    case prizeGet        = "SE_PRIZE_GET"
    case voteFlip        = "SE_VOTE_FLIP"
    case voteHit         = "SE_VOTE_HIT"
    case voteReach       = "SE_VOTE_REACH"
    case championImpact  = "SE_CHAMPION_IMPACT"
    case yearCurtain     = "SE_YEAR_CURTAIN"
    case newYearStamp    = "SE_NEWYEAR_STAMP"
    case debtWarning     = "SE_DEBT_WARNING"
}

enum YoseFX {
    /// 効果音再生フック（後から AVAudioPlayer / AudioServices を1箇所に繋ぐだけで全画面鳴る）
    static var onPlaySound: ((YoseSoundEffect) -> Void)?

    static func sound(_ se: YoseSoundEffect) {
        onPlaySound?(se)
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat = 1.0) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.impactOccurred(intensity: intensity)
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(type)
    }
}

// ============================================================================
// MARK: - 1. 放射パーティクル（YoseBurstParticles）
// 用途：練習結果・能力アップ確定・大成功・判子着地時に四角い金箔/木片/火花が弾ける
// ============================================================================

struct YoseBurstParticles: View {
    let trigger: Int          // 値が増えるたびに1回バースト発火
    var count: Int = 18       // 粒の数（小:8 / 中:14 / 大:24）
    var colors: [Color] = [YoseColor.kinBright, YoseColor.shu, YoseColor.kin]
    var radius: CGFloat = 90  // 飛び散る最大距離
    var duration: Double = 0.55

    @State private var burstStart: Date? = nil
    @State private var seeds: [ParticleSeed] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct ParticleSeed {
        let angle: Double
        let speedScale: CGFloat
        let size: CGFloat
        let spinSpeed: Double
        let colorIndex: Int
        let isDiamond: Bool
    }

    init(
        trigger: Int,
        count: Int = 18,
        colors: [Color] = [YoseColor.kinBright, YoseColor.shu, YoseColor.kin],
        radius: CGFloat = 90,
        duration: Double = 0.55
    ) {
        self.trigger = trigger
        self.count = count
        self.colors = colors
        self.radius = radius
        self.duration = duration
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: burstStart == nil)) { timeline in
            Canvas { context, size in
                guard let start = burstStart else { return }
                let elapsed = timeline.date.timeIntervalSince(start)
                guard elapsed >= 0, elapsed < duration else { return }

                let progress = elapsed / duration
                // 初速が速く、後半ピタッと減速するイージング (1 - (1-t)^3)
                let eased = 1.0 - pow(1.0 - progress, 3.0)
                let alpha = max(0, 1.0 - pow(progress, 1.8))
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                for seed in seeds {
                    let dist = radius * seed.speedScale * CGFloat(eased)
                    let gravityY = CGFloat(progress * progress) * 24.0 // わずかな重力落下
                    let x = center.x + CGFloat(cos(seed.angle)) * dist
                    let y = center.y + CGFloat(sin(seed.angle)) * dist + gravityY

                    var pContext = context
                    pContext.opacity = alpha
                    pContext.translateBy(x: x, y: y)
                    pContext.rotate(by: .degrees(seed.spinSpeed * elapsed))

                    let rect = CGRect(
                        x: -seed.size / 2,
                        y: -seed.size / 2,
                        width: seed.size,
                        height: seed.isDiamond ? seed.size : seed.size * 0.65
                    )
                    let color = colors[seed.colorIndex % max(1, colors.count)]
                    pContext.fill(Path(rect), with: .color(color))
                    pContext.stroke(Path(rect), with: .color(YoseColor.sumi), lineWidth: 1)
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            guard !reduceMotion else { return }
            regenerateSeeds()
            burstStart = Date()
        }
    }

    private func regenerateSeeds() {
        seeds = (0..<count).map { i in
            let baseAngle = (Double(i) / Double(max(1, count))) * (.pi * 2.0)
            let jitter = Double.random(in: -0.22...0.22)
            return ParticleSeed(
                angle: baseAngle + jitter,
                speedScale: CGFloat.random(in: 0.45...1.05),
                size: CGFloat.random(in: 6...11),
                spinSpeed: Double.random(in: -360...360),
                colorIndex: i,
                isDiamond: i.isMultiple(of: 2)
            )
        }
    }
}

// ============================================================================
// MARK: - 2. 数値の跳ね＋発光（YoseNumberPopModifier）
// 用途：実力・能力値・所持金・得票数が変わった瞬間に跳ねて光る計器モディファイア
// ============================================================================

struct YoseNumberPopModifier<V: Equatable>: ViewModifier {
    let value: V
    var highlightColor: Color = YoseColor.kinBright
    var scalePeak: CGFloat = 1.24

    @State private var isPopping: Bool = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPopping ? scalePeak : 1.0)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(highlightColor.opacity(isPopping ? 0.38 : 0.0))
                    .padding(.horizontal, -4)
                    .padding(.vertical, -2)
            )
            .animation(.spring(response: 0.24, dampingFraction: 0.62), value: isPopping)
            .onChange(of: value) { _, _ in
                isPopping = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                    isPopping = false
                }
            }
    }
}

extension View {
    func yoseNumberPop<V: Equatable>(
        value: V,
        highlightColor: Color = YoseColor.kinBright,
        scalePeak: CGFloat = 1.24
    ) -> some View {
        modifier(YoseNumberPopModifier(value: value, highlightColor: highlightColor, scalePeak: scalePeak))
    }
}

// ============================================================================
// MARK: - 3. 画面揺れ（YoseScreenShakeModifier）
// 用途：判子着地・大ウケ・開票・優勝時に物理的な減衰振動（縦揺れ／横揺れ）を与える
// ============================================================================

enum YoseShakeIntensity {
    case small   // 2pt（中イベント・小判子）
    case medium  // 4pt（突破判子・大成功・開票）
    case heavy   // 6pt（優勝決定・特大衝撃）

    var amplitude: CGFloat {
        switch self {
        case .small:  return 2.0
        case .medium: return 4.0
        case .heavy:  return 6.5
        }
    }
}

struct YoseScreenShakeModifier: ViewModifier {
    let trigger: Int
    var intensity: YoseShakeIntensity = .medium
    var axis: Axis = .vertical

    @State private var offset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(
                x: axis == .horizontal ? offset : 0,
                y: axis == .vertical ? offset : 0
            )
            .onChange(of: trigger) { _, _ in
                guard !reduceMotion else { return }
                let amp = intensity.amplitude
                Task { @MainActor in
                    let steps: [CGFloat] = [amp, -amp * 0.75, amp * 0.45, -amp * 0.2, 0]
                    for step in steps {
                        withAnimation(.linear(duration: 0.038)) {
                            offset = step
                        }
                        try? await Task.sleep(nanoseconds: 38_000_000)
                    }
                }
            }
    }
}

extension View {
    func yoseShake(trigger: Int, intensity: YoseShakeIntensity = .medium, axis: Axis = .vertical) -> some View {
        modifier(YoseScreenShakeModifier(trigger: trigger, intensity: intensity, axis: axis))
    }
}

// ============================================================================
// MARK: - 4. 光の筋・斜光シマー（YoseLightStreakModifier）
// 用途：能力アップ確定時・勝負ネタ登録時・開票カードに「キラーン」と走る金の斜め光
// ============================================================================

struct YoseLightStreakModifier: ViewModifier {
    let trigger: Int
    var streakColor: Color = YoseColor.kinBright
    var duration: Double = 0.36

    @State private var phase: CGFloat = -1.2
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    Rectangle()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: streakColor.opacity(0.65), location: 0.42),
                                    .init(color: Color.white.opacity(0.90), location: 0.50),
                                    .init(color: streakColor.opacity(0.65), location: 0.58),
                                    .init(color: .clear, location: 1.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(60, w * 0.45), height: h * 2.2)
                        .rotationEffect(.degrees(24))
                        .offset(x: phase * (w + 140), y: -h * 0.5)
                }
                .clipped()
                .allowsHitTesting(false)
            }
            .onChange(of: trigger) { _, _ in
                guard !reduceMotion else { return }
                phase = -0.8
                withAnimation(.easeOut(duration: duration)) {
                    phase = 1.35
                }
            }
    }
}

extension View {
    func yoseLightStreak(trigger: Int, color: Color = YoseColor.kinBright) -> some View {
        modifier(YoseLightStreakModifier(trigger: trigger, streakColor: color))
    }
}

// ============================================================================
// MARK: - 5. 金・朱・白和紙の紙吹雪（YoseConfettiView）
// 用途：優勝・Sランク到達時に画面上部から舞い落ちる和紙吹雪（Canvas 60fps 描画）
// ============================================================================

struct YoseConfettiView: View {
    var isActive: Bool = true
    var pieceCount: Int = 56

    @State private var startDate = Date()
    @State private var pieces: [ConfettiPiece] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct ConfettiPiece {
        let initialXRatio: CGFloat
        let initialYOffset: CGFloat
        let fallSpeed: CGFloat
        let swayAmp: CGFloat
        let swayFreq: Double
        let spinSpeed: Double
        let width: CGFloat
        let height: CGFloat
        let color: Color
    }

    init(isActive: Bool = true, pieceCount: Int = 56) {
        self.isActive = isActive
        self.pieceCount = pieceCount
    }

    var body: some View {
        Group {
            if isActive && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    Canvas { context, size in
                        let elapsed = timeline.date.timeIntervalSince(startDate)
                        let totalH = size.height + 80

                        for piece in pieces {
                            let rawY = piece.initialYOffset + CGFloat(elapsed) * piece.fallSpeed
                            let y = rawY.truncatingRemainder(dividingBy: totalH) - 40
                            let sway = sin(elapsed * piece.swayFreq + Double(piece.initialXRatio * 10)) * Double(piece.swayAmp)
                            let x = piece.initialXRatio * size.width + CGFloat(sway)

                            // 3Dヒラヒラ回転を cos スケールで擬似表現
                            let flipScale = max(0.2, abs(cos(elapsed * piece.spinSpeed)))

                            var c = context
                            c.translateBy(x: x, y: y)
                            c.rotate(by: .degrees(sin(elapsed * 2.0) * 25))
                            c.scaleBy(x: 1.0, y: CGFloat(flipScale))

                            let rect = CGRect(
                                x: -piece.width / 2,
                                y: -piece.height / 2,
                                width: piece.width,
                                height: piece.height
                            )
                            c.fill(Path(rect), with: .color(piece.color))
                            c.stroke(Path(rect), with: .color(YoseColor.sumi.opacity(0.65)), lineWidth: 0.8)
                        }
                    }
                }
                .onAppear {
                    startDate = Date()
                    if pieces.isEmpty {
                        let palette: [Color] = [
                            YoseColor.kinBright,
                            YoseColor.kin,
                            YoseColor.shu,
                            YoseColor.washi
                        ]
                        pieces = (0..<pieceCount).map { i in
                            ConfettiPiece(
                                initialXRatio: CGFloat.random(in: 0.02...0.98),
                                initialYOffset: CGFloat.random(in: 0...850),
                                fallSpeed: CGFloat.random(in: 110...210),
                                swayAmp: CGFloat.random(in: 14...34),
                                swayFreq: Double.random(in: 1.8...3.6),
                                spinSpeed: Double.random(in: 3.0...6.5),
                                width: CGFloat.random(in: 8...14),
                                height: CGFloat.random(in: 5...9),
                                color: palette[i % palette.count]
                            )
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// ============================================================================
// MARK: - 6. 判子叩きつけ＋朱肉しぶき（YoseAnimatedHanko）
// 用途：「突破」「秀」「昇格」「真剣勝負」を溜めから一気に叩きつける演出付き朱印
// ============================================================================

struct YoseAnimatedHanko: View {
    let text: String
    let isStamped: Bool
    var isSquare: Bool = false
    var angle: Double = -6
    var playHapticsAndSound: Bool = true

    @State private var burstTrigger: Int = 0

    init(
        text: String,
        isStamped: Bool,
        isSquare: Bool = false,
        angle: Double = -6,
        playHapticsAndSound: Bool = true
    ) {
        self.text = text
        self.isStamped = isStamped
        self.isSquare = isSquare
        self.angle = angle
        self.playHapticsAndSound = playHapticsAndSound
    }

    var body: some View {
        ZStack {
            // 着地瞬間の朱肉・金粉しぶき
            YoseBurstParticles(
                trigger: burstTrigger,
                count: 10,
                colors: [YoseColor.shu, YoseColor.kinBright],
                radius: 44,
                duration: 0.38
            )
            .frame(width: 90, height: 90)

            YoseHankoStamp(text: text, isSquare: isSquare, angle: angle)
                .scaleEffect(isStamped ? 1.0 : 2.35)
                .opacity(isStamped ? 1.0 : 0.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.54), value: isStamped)
        }
        .onChange(of: isStamped) { _, stamped in
            if stamped {
                burstTrigger += 1
                if playHapticsAndSound {
                    YoseFX.notify(.success)
                    YoseFX.sound(.stampHeavy)
                }
            }
        }
    }
}

// ============================================================================
// MARK: - 7. 斜めカットイン帯（YoseCutInBanner）
// 用途：『手応え抜群！ハマった！！』『どっと沸いた！！』『4票獲得・優勝決定！』
// ============================================================================

struct YoseCutInBanner: View {
    let title: String
    var subtitle: String? = nil
    var stampText: String? = "大成功"
    let isPresented: Bool

    @State private var stampReady: Bool = false

    init(
        title: String,
        subtitle: String? = nil,
        stampText: String? = "大成功",
        isPresented: Bool
    ) {
        self.title = title
        self.subtitle = subtitle
        self.stampText = stampText
        self.isPresented = isPresented
    }

    var body: some View {
        ZStack {
            if isPresented {
                // 黒漆＋上下二重金線の斜め帯
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        if let subtitle {
                            Text(subtitle)
                                .font(YoseFont.gothic(12, weight: .heavy))
                                .foregroundStyle(YoseColor.kin)
                        }
                        YoseOutlinedText(
                            text: title,
                            font: YoseFont.mincho(24),
                            fill: YoseColor.kinari,
                            outlineColor: YoseColor.kuroUrushi,
                            outlineWidth: 1.5,
                            dropShadowY: 2
                        )
                        .lineLimit(1).minimumScaleFactor(0.6)
                    }
                    Spacer(minLength: 4)
                    if let stampText {
                        YoseAnimatedHanko(
                            text: stampText,
                            isStamped: stampReady,
                            isSquare: false,
                            angle: -8
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    ZStack {
                        YoseColor.kuroUrushi
                        // 背後の朱斜めストライプ
                        HStack(spacing: 18) {
                            ForEach(0..<8, id: \.self) { _ in
                                Rectangle()
                                    .fill(YoseColor.enji.opacity(0.55))
                                    .frame(width: 14)
                                    .rotationEffect(.degrees(20))
                            }
                        }
                    }
                )
                .overlay(alignment: .top) {
                    VStack(spacing: 1.5) {
                        Rectangle().fill(YoseColor.sumi).frame(height: 2)
                        Rectangle().fill(YoseColor.kinBright).frame(height: 2)
                    }
                }
                .overlay(alignment: .bottom) {
                    VStack(spacing: 1.5) {
                        Rectangle().fill(YoseColor.kinBright).frame(height: 2)
                        Rectangle().fill(YoseColor.sumi).frame(height: 2)
                    }
                }
                .rotationEffect(.degrees(-4))
                .shadow(color: YoseColor.sumi, radius: 0, x: 0, y: 4)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    )
                )
                .onAppear {
                    stampReady = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                        stampReady = true
                    }
                }
            }
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.76), value: isPresented)
        .allowsHitTesting(false)
    }
}

// ============================================================================
// MARK: - 8. 集中線（YoseSpeedLinesView）
// 用途：大成功・大ウケ・突破・優勝決定の瞬間に画面外周へ出る劇画調の集中線
// ============================================================================

struct YoseSpeedLinesView: View {
    var lineCount: Int = 36
    var color: Color = YoseColor.kinBright.opacity(0.45)
    var innerClearRadiusRatio: CGFloat = 0.34 // 中央の文字・キャラを邪魔しない空洞比率

    init(
        lineCount: Int = 36,
        color: Color = YoseColor.kinBright.opacity(0.45),
        innerClearRadiusRatio: CGFloat = 0.34
    ) {
        self.lineCount = lineCount
        self.color = color
        self.innerClearRadiusRatio = innerClearRadiusRatio
    }

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outerR = hypot(size.width, size.height) * 0.65
            let baseInnerR = min(size.width, size.height) * innerClearRadiusRatio

            for i in 0..<lineCount {
                let angle = (Double(i) / Double(lineCount)) * (.pi * 2.0)
                // 規則的すぎないよう周期関数で内径と太さに抑揚をつける
                let innerJitter = CGFloat(sin(Double(i) * 1.7) * 18.0 + cos(Double(i) * 3.1) * 10.0)
                let r1 = baseInnerR + innerJitter
                let halfSpread = 0.008 + abs(sin(Double(i) * 2.3)) * 0.012

                var wedge = Path()
                wedge.move(to: CGPoint(
                    x: center.x + CGFloat(cos(angle)) * r1,
                    y: center.y + CGFloat(sin(angle)) * r1
                ))
                wedge.addLine(to: CGPoint(
                    x: center.x + CGFloat(cos(angle - halfSpread)) * outerR,
                    y: center.y + CGFloat(sin(angle - halfSpread)) * outerR
                ))
                wedge.addLine(to: CGPoint(
                    x: center.x + CGFloat(cos(angle + halfSpread)) * outerR,
                    y: center.y + CGFloat(sin(angle + halfSpread)) * outerR
                ))
                wedge.closeSubpath()

                context.fill(wedge, with: .color(color))
            }
        }
        .allowsHitTesting(false)
    }
}
