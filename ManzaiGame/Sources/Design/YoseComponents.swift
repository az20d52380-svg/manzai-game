// YoseComponents.swift  §5 部品カタログ（ヘッダー・ボタン・カード・タグ・判子・ゲージ・吹き出し）
// ％表示は出さない。外部画像なし。

import SwiftUI

// MARK: ① ヘッダー帯
struct YoseHeaderBar: View {
    let title: String
    var subtitle: String? = nil
    var closeTitle: String = "とじる"
    var closeAction: (() -> Void)? = nil

    var body: some View {
        ZStack {
            YoseColor.enji.ignoresSafeArea(edges: .top)
            HStack(spacing: 8) {
                if closeAction != nil { Spacer().frame(width: 64) }
                Spacer(minLength: 4)
                HStack(spacing: 4) {
                    Rectangle().fill(YoseColor.kin.opacity(0.7)).frame(width: 28, height: 1.5)
                    Rectangle().fill(YoseColor.kin).frame(width: 5, height: 5).rotationEffect(.degrees(45))
                }
                VStack(spacing: 1) {
                    Text(title)
                        .font(YoseFont.gothic(19, weight: .heavy)).tracking(1)
                        .lineLimit(1).minimumScaleFactor(0.5)   // 長い題（エンディング図鑑）が途中で折れない
                        .foregroundStyle(YoseColor.kin)
                        .shadow(color: YoseColor.kuroUrushi, radius: 0, x: 0, y: 1.5)
                    if let subtitle {
                        Text(subtitle).font(YoseFont.gothic(11, weight: .bold))
                            .foregroundStyle(YoseColor.kinari.opacity(0.85))
                    }
                }
                HStack(spacing: 4) {
                    Rectangle().fill(YoseColor.kin).frame(width: 5, height: 5).rotationEffect(.degrees(45))
                    Rectangle().fill(YoseColor.kin.opacity(0.7)).frame(width: 28, height: 1.5)
                }
                Spacer(minLength: 4)
                if let closeAction {
                    Button(closeTitle, action: closeAction)
                        .font(YoseFont.gothic(12, weight: .heavy))
                        .foregroundStyle(YoseColor.kinari)
                        .frame(width: 64, height: 28)
                        .background(YoseColor.kuroUrushi.opacity(0.6))
                        .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1.5))
                        .padding(.vertical, 8).contentShape(Rectangle()).padding(.vertical, -8)   // 見た目は28pt・押せる範囲は44pt（19l §2-3）
                }
            }
            .padding(.horizontal, YoseMetrics.screenMargin).padding(.vertical, 3)
        }
        .frame(minHeight: 48)
        .fixedSize(horizontal: false, vertical: true)   // 背景色が縦に伸びて画面を食うのを防ぐ
        // 標準サイズは従来どおり48。大きい文字では題と副題が収まる高さまで伸びる
        .overlay(alignment: .bottom) {
            VStack(spacing: 0) {
                Rectangle().fill(YoseColor.kin).frame(height: 2)
                Rectangle().fill(YoseColor.sumi).frame(height: 2)
            }
        }
    }
}

// MARK: ② ボタン
enum YoseButtonRole { case primary, secondary, command, kifuda }   // kifuda=フッタータブ用の木札色

struct YoseButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let role: YoseButtonRole
    var badgeText: String? = nil
    /// 注意を促す強調（朱の太枠＋山吹の薄塗り）。押せる状態の時だけ
    var highlight = false

    init(_ role: YoseButtonRole = .secondary, badgeText: String? = nil, highlight: Bool = false) {
        self.role = role
        self.badgeText = badgeText
        self.highlight = highlight
    }

    private var depth: CGFloat {
        guard isEnabled else { return 0 }
        return role == .command ? YoseMetrics.shadowCommand : YoseMetrics.shadowCard
    }
    private var fillColor: Color {
        guard isEnabled else { return YoseColor.ginNezu }
        if role == .kifuda { return YoseColor.ki }
        return role == .primary ? YoseColor.shu : YoseColor.washi
    }
    private var textColor: Color {
        guard isEnabled else { return YoseColor.disabledText }
        return role == .primary ? YoseColor.kinari : YoseColor.sumi
    }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = isEnabled && configuration.isPressed
        configuration.label
            .font(YoseFont.gothic(role == .command ? 18 : 15, weight: .heavy))
            .foregroundStyle(textColor)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: role == .command ? 68 : 44)   // 幅は外側の .frame いっぱい・高さは最低タップ領域（文字幅に縮まない／縦には伸びない）
            .background {
                ZStack {
                    fillColor
                    if highlight && isEnabled { YoseColor.kinBright.opacity(0.18) }
                    if !isEnabled {
                        YoseDiagonalStripes().stroke(YoseColor.sumi.opacity(0.07), lineWidth: 4)
                    } else if role == .primary {
                        VStack { Rectangle().fill(Color.white.opacity(0.22)).frame(height: 2); Spacer() }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: YoseMetrics.radius))
            .overlay {
                if role == .kifuda && isEnabled { RoundedRectangle(cornerRadius: 1).stroke(YoseColor.kiDark, lineWidth: 1).padding(3) }
            }
            .overlay(RoundedRectangle(cornerRadius: YoseMetrics.radius)
                .stroke(!isEnabled ? YoseColor.haiSumi : (highlight ? YoseColor.shu : YoseColor.sumi), lineWidth: !isEnabled ? 1.5 : (highlight ? 2.5 : 2)))
            .overlay(alignment: .bottomTrailing) {
                if let badgeText {
                    Text(badgeText)
                        .font(YoseFont.gothic(11, weight: .heavy))
                        .foregroundStyle(role == .primary ? YoseColor.kuroUrushi : YoseColor.kinari)   // 朱の主ボタン上では山吹金の札（保護色を避ける）
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(role == .primary ? YoseColor.kinBright : YoseColor.shu)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                        .rotationEffect(.degrees(-8))
                        .offset(x: -6, y: -4)
                }
            }
            .offset(y: pressed ? depth : 0)
            .background(
                RoundedRectangle(cornerRadius: YoseMetrics.radius).fill(YoseColor.sumi)
                    .offset(y: depth).opacity(isEnabled ? 1 : 0)
            )
            .padding(.bottom, depth)   // 影ぶんの高さを確保（押下時の沈みで隣が動かない）
            .animation(.easeOut(duration: 0.06), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, p in if p && isEnabled { YoseHaptic.press() } }
    }
}

struct YoseDiagonalStripes: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        var x = -rect.height
        while x < rect.width {
            p.move(to: CGPoint(x: x, y: rect.height))
            p.addLine(to: CGPoint(x: x + rect.height, y: 0))
            x += 12
        }
        return p
    }
}

// MARK: ③④ 木札・貼り紙
struct YoseKifudaModifier: ViewModifier {
    var showNail: Bool = false
    func body(content: Content) -> some View {
        content
            .background(YoseColor.ki)
            .clipShape(RoundedRectangle(cornerRadius: YoseMetrics.radius))
            .overlay(RoundedRectangle(cornerRadius: 1).stroke(YoseColor.kiDark, lineWidth: 1).padding(3))
            .overlay(RoundedRectangle(cornerRadius: YoseMetrics.radius).stroke(YoseColor.sumi, lineWidth: 2))
            .overlay(alignment: .top) {
                if showNail { Circle().fill(YoseColor.sumi).frame(width: 4, height: 4).padding(.top, 4) }
            }
            .background(RoundedRectangle(cornerRadius: YoseMetrics.radius).fill(YoseColor.sumi).offset(y: 2))
    }
}

struct YoseHarigamiModifier: ViewModifier {
    var isFeatured: Bool = false
    func body(content: Content) -> some View {
        content
            .padding(.leading, isFeatured ? 6 : 0)
            .background(isFeatured ? YoseColor.washiFeatured : YoseColor.washi)
            .overlay(alignment: .leading) {
                if isFeatured { Rectangle().fill(YoseColor.enji).frame(width: 6) }
            }
            .clipShape(RoundedRectangle(cornerRadius: YoseMetrics.radius))
            .overlay(RoundedRectangle(cornerRadius: 1)
                .stroke(isFeatured ? YoseColor.kin : Color.clear, lineWidth: 1).padding(2.5))
            .overlay(RoundedRectangle(cornerRadius: YoseMetrics.radius)
                .stroke(isFeatured ? YoseColor.shu : YoseColor.sumi, lineWidth: isFeatured ? 2.5 : 2))
            .background(RoundedRectangle(cornerRadius: YoseMetrics.radius).fill(YoseColor.sumi).offset(y: 2))
    }
}

extension View {
    func yoseKifuda(showNail: Bool = false) -> some View { modifier(YoseKifudaModifier(showNail: showNail)) }
    func yoseHarigami(isFeatured: Bool = false) -> some View { modifier(YoseHarigamiModifier(isFeatured: isFeatured)) }
}

/// 木札カード（コンテナ版）
struct YoseKifudaCard<Content: View>: View {
    var showNail = false
    @ViewBuilder var content: () -> Content
    var body: some View {
        content().padding(.horizontal, YoseMetrics.padH).padding(.vertical, YoseMetrics.padV)
            .frame(maxWidth: .infinity, alignment: .leading).yoseKifuda(showNail: showNail)
    }
}

/// 貼り紙カード（コンテナ版）
struct YoseHarigamiCard<Content: View>: View {
    var isFeatured = false
    @ViewBuilder var content: () -> Content
    var body: some View {
        content().padding(.horizontal, YoseMetrics.padH).padding(.vertical, YoseMetrics.padV)
            .frame(maxWidth: .infinity, alignment: .leading).yoseHarigami(isFeatured: isFeatured)
    }
}

// MARK: ⑤⑥ タグ・判子
enum YoseTagStyle { case solidEnji, outlineShu, outlineKin, outlineSumi }

struct YoseTag: View {
    let text: String
    var style: YoseTagStyle = .outlineSumi
    var body: some View {
        let c: (Color, Color, Color) = {
            switch style {
            case .solidEnji: return (YoseColor.kinari, YoseColor.enji, YoseColor.sumi)
            case .outlineShu: return (YoseColor.shu, YoseColor.shu.opacity(0.12), YoseColor.shu)
            case .outlineKin: return (YoseColor.kinText, YoseColor.kin.opacity(0.18), YoseColor.kin)
            case .outlineSumi: return (YoseColor.sumi, YoseColor.ki.opacity(0.45), YoseColor.sumi)
            }
        }()
        Text(text)
            .font(YoseFont.gothic(11, weight: .heavy)).foregroundStyle(c.0)
            .padding(.horizontal, 6).padding(.vertical, 2.5)
            .background(c.1)
            .overlay(Rectangle().stroke(c.2, lineWidth: 1.5))
    }
}

struct YoseHankoStamp: View {
    let text: String
    var isSquare = false
    var angle: Double = -6
    var body: some View {
        Text(text)
            .font(YoseFont.gothic(isSquare ? 20 : 12, weight: .black))
            .tracking(isSquare ? 0 : 1)
            .foregroundStyle(YoseColor.shu)
            .padding(.horizontal, isSquare ? 8 : 7).padding(.vertical, isSquare ? 6 : 3)
            .background(YoseColor.washi.opacity(0.92))
            .overlay(Rectangle().stroke(YoseColor.shu, lineWidth: 1).padding(2.5))
            .overlay(Rectangle().stroke(YoseColor.shu, lineWidth: 2))
            .rotationEffect(.degrees(angle))
            .accessibilityLabel(Self.spoken(text))
    }
    /// 判子の読み上げ（点数・順位・勝敗の判を日本語で意味が通る形に）
    static func spoken(_ t: String) -> String {
        if t == "封" { return "封の判" }
        if t == "秀" { return "秀の判、通過" }
        if t == "惜" { return "惜の判、惜しくも敗退" }
        if Int(t) != nil { return "\(t)点の判" }
        if t.hasPrefix("暫定") { return "\(t)の判" }
        return "\(t)の判子"
    }
}

// MARK: ⑧ ゲージ（％表示なし）
struct YoseGauge: View {
    let value: Double
    let total: Double
    var fill: Color = YoseColor.shu
    var height: CGFloat = 12
    var showTicks = true

    var body: some View {
        let ratio = total > 0 ? min(max(value / total, 0), 1) : 0
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(YoseColor.ginNezu)
                Rectangle().fill(fill)
                    .frame(width: geo.size.width * ratio)
                    .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.28)).frame(height: 2) }
                    .animation(.spring(response: 0.35, dampingFraction: 0.78), value: ratio)
                if showTicks {
                    ForEach(1..<4, id: \.self) { i in
                        Rectangle().fill(YoseColor.sumi.opacity(0.35)).frame(width: 1)
                            .offset(x: geo.size.width * CGFloat(i) / 4)
                    }
                }
            }
            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
        }
        .frame(height: height)
        .accessibilityHidden(true)   // 数字が隣にある。ゲージの形だけでは読み上げに意味がない
    }
}

// MARK: ⑨ 吹き出し
struct YoseSpeechBox: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let speaker: String
    let text: String
    var roleLabel: String? = nil
    var showCue = true
    @State private var blink = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(spacing: 2) {
                if let roleLabel {
                    Text(roleLabel).font(.system(size: Font.mzScaled(9, cap: 1.1), weight: .heavy)).foregroundStyle(YoseColor.kin)
                        .padding(.horizontal, 4).padding(.vertical, 1).background(YoseColor.kuroUrushi)
                }
                Text(speaker).font(.custom("HiraMinProN-W6", fixedSize: Font.mzScaled(15, cap: 1.1))).foregroundStyle(YoseColor.kinari)
                    .padding(.horizontal, 8).padding(.vertical, 6).frame(minWidth: 58)
                    .background(YoseColor.shu)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
            }
            .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))

            HStack(alignment: .bottom, spacing: 6) {
                Text(text).font(.custom("HiraMinProN-W6", fixedSize: Font.mzScaled(15, cap: 1.1))).lineSpacing(5).foregroundStyle(YoseColor.sumi)   // 吹き出しは舞台に重なるので拡大は1.1倍まで（長い行が3行になって名札に被らない）
                    .frame(maxWidth: .infinity, alignment: .leading)
                if showCue {
                    Image(systemName: "arrowtriangle.down.fill").font(.system(size: Font.mzScaled(10))).accessibilityHidden(true)
                        .foregroundStyle(YoseColor.shu).opacity(blink ? 0.25 : 1)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .yoseHarigami()
        }
        .onAppear { guard !reduceMotion else { return }; withAnimation(.easeOut(duration: 0.5).repeatForever(autoreverses: true)) { blink = true } }
    }
}
