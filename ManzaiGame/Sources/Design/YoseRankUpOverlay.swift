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

    var body: some View {
        if let main = primary {
            ZStack {
                // 背景暗転（どこをタップしても1回で即座に閉じる）
                Color.black.opacity(cardAppeared ? 0.65 : 0.0)
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    // 昇格貼り紙カード本体
                    VStack(spacing: 0) {
                        headerStrip
                        joshikimakuStripe
                        mainContent(for: main)
                    }
                    .background(YoseColor.washi)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 1)
                            .stroke(YoseColor.kin, lineWidth: 1)
                            .padding(3)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(YoseColor.sumi, lineWidth: 2.5)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(YoseColor.sumi)
                            .offset(y: 4)
                    )
                    .offset(y: shakeOffset)
                    .scaleEffect(cardAppeared ? 1.0 : 0.88)
                    .opacity(cardAppeared ? 1.0 : 0.0)
                    .padding(.horizontal, 24)

                    // タップ案内
                    Text("画面をタップして閉じる ▶")
                        .font(YoseFont.gothic(12, weight: .bold))
                        .foregroundStyle(YoseColor.kinari.opacity(0.9))
                        .opacity(cardAppeared ? 1.0 : 0.0)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                dismissImmediately()
            }
            .task {
                await runSequence(for: main)
            }
        }
    }

    // MARK: - 上部見出し＆定式幕ストリップ

    private var headerStrip: some View {
        HStack(spacing: 8) {
            Rectangle().fill(YoseColor.kin.opacity(0.7)).frame(width: 24, height: 1.5)
            Rectangle().fill(YoseColor.kin).frame(width: 5, height: 5).rotationEffect(.degrees(45))
            Text("番 付 昇 格")
                .font(YoseFont.gothic(18, weight: .heavy))
                .tracking(2)
                .foregroundStyle(YoseColor.kin)
                .shadow(color: YoseColor.kuroUrushi, radius: 0, x: 0, y: 1.5)
            Rectangle().fill(YoseColor.kin).frame(width: 5, height: 5).rotationEffect(.degrees(45))
            Rectangle().fill(YoseColor.kin.opacity(0.7)).frame(width: 24, height: 1.5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .background(YoseColor.enji)
        .overlay(alignment: .bottom) {
            Rectangle().fill(YoseColor.kin).frame(height: 1.5)
        }
    }

    private var joshikimakuStripe: some View {
        GeometryReader { geo in
            let colors: [Color] = [
                YoseColor.kuroUrushi,
                YoseColor.shu,
                YoseColor.tokiwa,
                YoseColor.kuroUrushi,
                YoseColor.shu,
                YoseColor.tokiwa
            ]
            HStack(spacing: 0) {
                ForEach(0..<18, id: \.self) { i in
                    Rectangle()
                        .fill(colors[i % colors.count])
                }
            }
        }
        .frame(height: 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(YoseColor.sumi).frame(height: 1.5)
        }
    }

    // MARK: - 主役ランク昇格エリア

    private func mainContent(for item: RankUpItem) -> some View {
        VStack(spacing: 14) {
            // 1. 能力名バッジ（色弱対応の1文字紋章＋能力名）
            HStack(spacing: 8) {
                Text(item.abilityShort)
                    .font(YoseFont.gothic(13, weight: .black))
                    .foregroundStyle(YoseColor.kinari)
                    .frame(width: 24, height: 24)
                    .background(item.abilityColor)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))

                Text("\(item.abilityName)のランクが上がった！")
                    .font(YoseFont.gothic(16, weight: .heavy))
                    .foregroundStyle(YoseColor.sumi)
            }
            .padding(.top, 4)

            // 2. 旧ランク木札 ▶ 新ランク大木札 ＋ 朱印スタンプ
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 18) {
                    // 旧ランク札 (48×48pt)
                    VStack(spacing: 2) {
                        Text("旧")
                            .font(YoseFont.gothic(10, weight: .bold))
                            .foregroundStyle(YoseColor.haiSumi)
                        Text(item.fromRank)
                            .font(YoseFont.gothic(24, weight: .black))
                            .foregroundStyle(YoseColor.kinari)
                            .frame(width: 48, height: 48)
                            .background(Self.rankColor(item.fromRank).opacity(0.75))
                            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                            .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))
                    }

                    // 昇格矢印（3連シェブロンブロック）
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: "play.fill")
                                .font(.system(size: i == 2 ? 18 : 13, weight: .black))
                                .foregroundStyle(i == 2 ? YoseColor.shu : YoseColor.kin)
                        }
                    }
                    .padding(.top, 14)

                    // 新ランク大木札 (72×72pt + 角火花エフェクト)
                    VStack(spacing: 2) {
                        Text("新ランク")
                            .font(YoseFont.gothic(11, weight: .heavy))
                            .foregroundStyle(YoseColor.shu)

                        ZStack {
                            // 四隅の金火花（外部画像なし・純粋矩形）
                            ForEach(0..<4, id: \.self) { corner in
                                let angle = Double(corner) * 90.0 + 45.0
                                Rectangle()
                                    .fill(YoseColor.kinBright)
                                    .frame(width: 6, height: 6)
                                    .offset(y: badgeLanded ? -54 : -24)
                                    .opacity(badgeLanded ? 0.0 : 1.0)
                                    .rotationEffect(.degrees(angle))
                                    .animation(.easeOut(duration: 0.32), value: badgeLanded)
                            }

                            Text(item.toRank)
                                .font(YoseFont.gothic(40, weight: .black))
                                .foregroundStyle(YoseColor.kinari)
                                .shadow(color: YoseColor.kuroUrushi, radius: 0, x: 0, y: 2)
                                .frame(width: 72, height: 72)
                                .background(Self.rankColor(item.toRank))
                                .overlay(
                                    Rectangle()
                                        .stroke(YoseColor.kinBright, lineWidth: 2)
                                        .padding(3)
                                )
                                .overlay(
                                    Rectangle()
                                        .stroke(YoseColor.sumi, lineWidth: 2.5)
                                )
                                .background(
                                    Rectangle()
                                        .fill(YoseColor.sumi)
                                        .offset(y: 3)
                                )
                                .scaleEffect(badgeLanded ? 1.0 : 1.75)
                                .opacity(badgeLanded ? 1.0 : 0.0)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)

                // 右上叩きつけ朱印『昇格』
                YoseHankoStamp(text: "昇格", isSquare: false, angle: -8)
                    .modifier(YoseStampImpactModifier(isStamped: stamped))
                    .offset(x: -6, y: -4)
            }

            // 3. 能力値と実力の計器ボックス（木札カード）
            HStack(spacing: 0) {
                // 左：能力値推移
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.abilityName)
                        .font(YoseFont.gothic(12, weight: .heavy))
                        .foregroundStyle(YoseColor.haiSumi)
                    Text("\(item.beforeValue)")
                        .font(YoseFont.number(18, weight: .heavy))
                        .foregroundStyle(YoseColor.haiSumi)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(YoseColor.shu)
                    Text("\(shownValue)")
                        .font(YoseFont.number(24, weight: .black))
                        .foregroundStyle(YoseColor.sumi)
                        .contentTransition(.numericText(value: Double(shownValue)))
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(YoseColor.kiDark)
                    .frame(width: 1.5, height: 28)

                // 右：コンビ実力合計
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("実力")
                        .font(YoseFont.gothic(11, weight: .heavy))
                        .foregroundStyle(YoseColor.enji)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(YoseColor.enji.opacity(0.12))
                        .overlay(Rectangle().stroke(YoseColor.enji, lineWidth: 1))

                    Text("\(totalPower)")
                        .font(YoseFont.number(22, weight: .black))
                        .foregroundStyle(YoseColor.sumi)

                    if powerDelta > 0 {
                        Text("+\(powerDelta)")
                            .font(YoseFont.number(13, weight: .heavy))
                            .foregroundStyle(YoseColor.shu)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .yoseKifuda()

            // 4. 連続・同時昇格ストリップ（2個以上同時に上がった時のみ1画面に統合表示）
            if !subItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("同時昇格")
                        .font(YoseFont.gothic(11, weight: .heavy))
                        .foregroundStyle(YoseColor.haiSumi)

                    HStack(spacing: 6) {
                        ForEach(subItems) { sub in
                            HStack(spacing: 4) {
                                Text(sub.abilityShort)
                                    .font(YoseFont.gothic(10, weight: .black))
                                    .foregroundStyle(YoseColor.kinari)
                                    .frame(width: 18, height: 18)
                                    .background(sub.abilityColor)
                                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1))

                                Text("\(sub.fromRank)▶\(sub.toRank)")
                                    .font(YoseFont.gothic(13, weight: .black))
                                    .foregroundStyle(YoseColor.shu)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(YoseColor.washi)
                            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                            .background(Rectangle().fill(YoseColor.sumi).offset(y: 1.5))
                        }
                        Spacer(minLength: 0)
                    }
                }
                .padding(.top, 2)
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

        // 0.00s: カード出現
        withAnimation(.easeOut(duration: 0.12)) {
            cardAppeared = true
        }

        // 0.08s: 新ランク木札の着地
        try? await Task.sleep(nanoseconds: 80_000_000)
        guard !isDismissed else { return }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.58)) {
            badgeLanded = true
        }

        // 0.18s: 朱印叩きつけ ＋ 画面微振動 ＋ Haptics ＋ 数値ジャンプ
        try? await Task.sleep(nanoseconds: 100_000_000)
        guard !isDismissed else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
            stamped = true
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
            shownValue = item.afterValue
        }

        // 叩きつけの物理シェイク (y: +3 -> -2 -> 0)
        withAnimation(.linear(duration: 0.04)) { shakeOffset = 3 }
        try? await Task.sleep(nanoseconds: 40_000_000)
        withAnimation(.linear(duration: 0.04)) { shakeOffset = -2 }
        try? await Task.sleep(nanoseconds: 40_000_000)
        withAnimation(.linear(duration: 0.04)) { shakeOffset = 0 }

        // 1.45s: 自動クローズ
        try? await Task.sleep(nanoseconds: 1_190_000_000)
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
