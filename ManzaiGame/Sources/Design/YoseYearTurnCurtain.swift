import SwiftUI
import UIKit

// MARK: - 年変わり幕間データモデル

struct YearTurnSummary {
    let combiName: String
    let previousYear: Int
    let newYear: Int
    let power: Int
    let fame: Int
    let money: Int
    let netaCount: Int
    let maxStamina: Int

    init(
        combiName: String,
        previousYear: Int,
        newYear: Int,
        power: Int,
        fame: Int,
        money: Int,
        netaCount: Int,
        maxStamina: Int = 100
    ) {
        self.combiName = combiName
        self.previousYear = previousYear
        self.newYear = newYear
        self.power = power
        self.fame = fame
        self.money = money
        self.netaCount = netaCount
        self.maxStamina = maxStamina
    }
}

// MARK: - 年が変わる時の幕間ビュー（49_複数年_2年目 完全改修版）

struct YoseYearTurnCurtainView: View {
    let summary: YearTurnSummary
    let onStartNewYear: () -> Void

    @State private var curtainClosed: Bool = true
    @State private var mekuriFlipped: Bool = false
    @State private var contentAppeared: Bool = false
    @State private var stamped: Bool = false
    @State private var hasTriggeredStart: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(summary: YearTurnSummary, onStartNewYear: @escaping () -> Void) {
        self.summary = summary
        self.onStartNewYear = onStartNewYear
    }

    var body: some View {
        ZStack {
            // 基本背景（生成り和紙）
            YoseColor.kinari.ignoresSafeArea()

            VStack(spacing: 0) {
                // ① 最上部ヘッダー帯 (48pt)
                YoseHeaderBar(title: "新シーズン開幕", subtitle: "\(summary.combiName)")

                // ② 定式幕ヘッダー (18pt)
                joshikimakuHeader

                // メインコンテンツ領域
                VStack(spacing: 14) {
                    // ③ 黒漆・寄席めくり看板（1年目 → 2年目 反転演出）
                    mekuriStageBoard

                    // ④ 前年からの引き継ぎ資産カード（3連木札＋引き継ぎ明示タグ）
                    carryOverCard

                    Spacer(minLength: 0)

                    // ⑥ 主ボタン（YoseButtonStyle(.primary) 完全準拠・高さ54pt）
                    Button(action: triggerStart) {
                        HStack(spacing: 8) {
                            Text("\(summary.newYear)年目を始める")
                                .font(YoseFont.gothic(18, weight: .heavy))
                            Image(systemName: "play.fill")
                                .font(.system(size: 13, weight: .black))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                    }
                    .buttonStyle(YoseButtonStyle(.primary))
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 12)

                // ⑦ 最下部ステータス黒帯（体力100/100全回復と所持金を常時表示）
                YoseVitalMoneyBar(
                    stamina: summary.maxStamina,
                    maxStamina: summary.maxStamina,
                    money: summary.money,
                    fame: summary.fame
                )
            }

            // 開幕時の左右引き幕（定式幕ワイプ：0.22sで閉じて0.22sで開く）
            GeometryReader { geo in
                HStack(spacing: 0) {
                    curtainPanel
                        .frame(width: geo.size.width / 2)
                        .offset(x: curtainClosed ? 0 : -geo.size.width / 2 - 10)

                    curtainPanel
                        .frame(width: geo.size.width / 2)
                        .offset(x: curtainClosed ? 0 : geo.size.width / 2 + 10)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        // 画面のどこをタップしても1回で即座に新年の第1週へ進める（最小の手間）
        .contentShape(Rectangle())
        .onTapGesture {
            triggerStart()
        }
        .task {
            await playTransitionSequence()
        }
    }

    // MARK: - ② 定式幕ヘッダー (18pt)

    private var joshikimakuHeader: some View {
        let colors: [Color] = [
            YoseColor.kuroUrushi,
            YoseColor.shu,
            YoseColor.tokiwa,
            YoseColor.kuroUrushi,
            YoseColor.shu,
            YoseColor.tokiwa
        ]
        return HStack(spacing: 0) {
            ForEach(0..<18, id: \.self) { idx in
                Rectangle().fill(colors[idx % colors.count])
            }
        }
        .frame(height: 18)
        .overlay(alignment: .bottom) {
            Rectangle().fill(YoseColor.sumi).frame(height: 2)
        }
    }

    // MARK: - ③ 黒漆・年次めくり大看板

    private var mekuriStageBoard: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Rectangle().fill(YoseColor.kin).frame(width: 18, height: 1.5)
                    Text("寄席・年次改め")
                        .font(YoseFont.gothic(12, weight: .heavy))
                        .tracking(1.5)
                        .foregroundStyle(YoseColor.kin)
                    Rectangle().fill(YoseColor.kin).frame(width: 18, height: 1.5)
                }

                // めくり札本体（前年 → 新年へパタンと縦反転）
                ZStack {
                    VStack(spacing: 4) {
                        // めくり上部の黒漆留め木
                        Rectangle()
                            .fill(YoseColor.shu)
                            .frame(height: 8)
                            .overlay(
                                Rectangle()
                                    .fill(YoseColor.kin)
                                    .frame(width: 24, height: 2)
                            )
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(YoseColor.sumi).frame(height: 1.5)
                            }

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("結成")
                                .font(YoseFont.mincho(18))
                                .foregroundStyle(YoseColor.sumi)
                            Text("\(mekuriFlipped ? summary.newYear : summary.previousYear)")
                                .font(YoseFont.number(38, weight: .black))
                                .foregroundStyle(YoseColor.shu)
                                .contentTransition(.numericText(value: Double(mekuriFlipped ? summary.newYear : summary.previousYear)))
                            Text("年目")
                                .font(YoseFont.mincho(20))
                                .foregroundStyle(YoseColor.sumi)
                        }
                        .padding(.top, 2)

                        Text(mekuriFlipped ? "春 ・ 第1週 開幕" : "全日程 終了")
                            .font(YoseFont.gothic(12, weight: .heavy))
                            .foregroundStyle(YoseColor.haiSumi)
                            .padding(.bottom, 8)
                    }
                    .frame(width: 210)
                    .background(YoseColor.washi)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    .background(Rectangle().fill(YoseColor.sumi).offset(y: 3))
                    .rotation3DEffect(
                        .degrees(mekuriFlipped ? 0 : -85),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .top,
                        perspective: 0.4
                    )
                }

            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background(YoseColor.kuroUrushi)
            .overlay(
                Rectangle()
                    .stroke(YoseColor.kin, lineWidth: 1.5)
                    .padding(4)
            )
            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
            .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))

            // 右上朱印『開幕』
            YoseHankoStamp(text: "開幕", isSquare: false, angle: -6)
                .modifier(YoseStampImpactModifier(isStamped: stamped))
                .offset(x: -12, y: 10)
        }
    }

    // MARK: - ④ 引き継ぎ資産3連木札カード

    private var carryOverCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 見出し行＋引き継ぎ明示タグ
            HStack {
                HStack(spacing: 6) {
                    Rectangle().fill(YoseColor.shu).frame(width: 4, height: 16)
                    Text("\(summary.previousYear)年目の到達と引き継ぎ")
                        .font(YoseFont.gothic(15, weight: .heavy))
                        .foregroundStyle(YoseColor.sumi)
                }
                Spacer()
                YoseTag(text: "実力・資金・ネタを継承", style: .solidEnji)
            }

            // 3連独立木札（実力 / 知名度 / 所持金）
            HStack(spacing: 8) {
                metricKifuda(
                    label: "引き継ぎ実力",
                    valueText: "\(summary.power)",
                    accent: YoseColor.enji
                )
                metricKifuda(
                    label: "知名度",
                    valueText: "\(summary.fame)",
                    accent: YoseColor.sumi
                )
                metricKifuda(
                    label: "所持金",
                    valueText: Self.compactYen(summary.money),
                    accent: YoseColor.sumi
                )
            }

            // 新春の備え（年初処理の明示：体力全回復・持ちネタ数・シード権）
            HStack(spacing: 8) {
                YoseTag(text: "新春の備え", style: .outlineSumi)
                Text("体力 \(summary.maxStamina)/\(summary.maxStamina) 全回復 ・ 持ちネタ \(summary.netaCount)本")
                    .font(YoseFont.gothic(12, weight: .bold))
                    .foregroundStyle(YoseColor.sumi)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(YoseColor.ki.opacity(0.45))
            .overlay(Rectangle().stroke(YoseColor.kiDark, lineWidth: 1))
        }
        .padding(12)
        .yoseHarigami(isFeatured: true)
        .opacity(contentAppeared ? 1.0 : 0.0)
        .offset(y: contentAppeared ? 0 : 10)
    }

    private func metricKifuda(label: String, valueText: String, accent: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(YoseFont.gothic(11, weight: .bold))
                .foregroundStyle(YoseColor.haiSumi)
                .lineLimit(1)

            Text(valueText)
                .font(YoseFont.number(22, weight: .black))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .yoseKifuda(showNail: true)
    }

    // MARK: - 引き幕（定式幕）パネル

    private var curtainPanel: some View {
        let colors: [Color] = [
            YoseColor.kuroUrushi,
            YoseColor.shu,
            YoseColor.tokiwa,
            YoseColor.kuroUrushi,
            YoseColor.shu
        ]
        return HStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { i in
                Rectangle()
                    .fill(colors[i % colors.count])
                    .overlay(alignment: .trailing) {
                        Rectangle().fill(YoseColor.sumi.opacity(0.5)).frame(width: 2)
                    }
            }
        }
        .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 2))
    }

    // MARK: - タイムライン制御（0.65秒・1タップ即開始）

    private func playTransitionSequence() async {
        if reduceMotion {
            curtainClosed = false
            mekuriFlipped = true
            contentAppeared = true
            stamped = true
            return
        }

        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()

        // 0.18s: 閉じた定式幕が左右へ開く
        try? await Task.sleep(nanoseconds: 180_000_000)
        withAnimation(.easeOut(duration: 0.22)) {
            curtainClosed = false
        }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            contentAppeared = true
        }

        // 0.30s: めくり札が「1年目」→「2年目」へパタンと反転
        try? await Task.sleep(nanoseconds: 120_000_000)
        withAnimation(.spring(response: 0.24, dampingFraction: 0.65)) {
            mekuriFlipped = true
        }

        // 0.48s: 『開幕』朱印スタンプ叩きつけ
        try? await Task.sleep(nanoseconds: 180_000_000)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
            stamped = true
        }
    }

    private func triggerStart() {
        guard !hasTriggeredStart else { return }
        hasTriggeredStart = true
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        onStartNewYear()
    }

    private static func compactYen(_ yen: Int) -> String {
        if abs(yen) >= 10_000 {
            let man = Double(yen) / 10_000.0
            if man == man.rounded() {
                return "¥\(Int(man))万"
            }
            return String(format: "¥%.1f万", man)
        }
        return "¥\(yen.formatted(.number))"
    }
}
