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
    @State private var burstTrigger: Int = 0
    @State private var shakeY: CGFloat = 0
    @State private var spotOn: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(summary: YearTurnSummary, onStartNewYear: @escaping () -> Void) {
        self.summary = summary
        self.onStartNewYear = onStartNewYear
    }

    var body: some View {
        ZStack {
            // 夜の寄席舞台：黒漆の闇＋天井から落ちるピンスポット＋床の照り返し
            YearTurnStageBackdrop(lit: spotOn)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // ① 上部：定式幕の垂れ幕（舞台の上手）＋コンビ名の木札
                joshikimakuHeader
                HStack(spacing: 8) {
                    Rectangle().fill(YoseColor.kin).frame(width: 20, height: 1.5)
                    Text("新 シ ー ズ ン 開 幕")
                        .font(YoseFont.gothic(13, weight: .heavy)).tracking(1.5)
                        .foregroundStyle(YoseColor.kinBright)
                    Rectangle().fill(YoseColor.kin).frame(width: 20, height: 1.5)
                }
                .padding(.top, 14)

                // メインコンテンツ領域
                VStack(spacing: 16) {
                    // ③ 黒漆・寄席めくり看板（1年目 → 2年目 反転演出）
                    mekuriStageBoard
                        .offset(y: shakeY)

                    // ④ 前年からの引き継ぎ資産カード（3連木札＋引き継ぎ明示タグ）
                    carryOverCard

                    Spacer(minLength: 0)

                    // ⑥ 主ボタン（YoseButtonStyle(.primary) 完全準拠・高さ54pt）
                    Button(action: triggerStart) {
                        HStack(spacing: 8) {
                            Text("\(summary.newYear)年目を始める")
                                .font(YoseFont.gothic(18, weight: .heavy))
                            Image(systemName: "play.fill").accessibilityHidden(true)
                                .font(.system(size: Font.mzScaled(13), weight: .black))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                    }
                    .buttonStyle(YoseButtonStyle(.primary))
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 14)
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
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
                    curtainPanel.accessibilityHidden(true)
                        .frame(width: geo.size.width / 2)
                        .overlay(alignment: .trailing) { curtainSeam(leading: false) }
                        .offset(x: curtainClosed ? 0 : -geo.size.width / 2 - 10)

                    curtainPanel.accessibilityHidden(true)
                        .frame(width: geo.size.width / 2)
                        .overlay(alignment: .leading) { curtainSeam(leading: true) }
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
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)   // 背面の年末リザルトを読ませない（19l §1-4）
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

    private func mekuriCard(year: Int, caption: String) -> some View {
        VStack(spacing: 0) {
            // 上部の留め木（朱＋金の鋲）
            Rectangle().fill(YoseColor.shu).frame(height: 10)
                .overlay(Rectangle().fill(YoseColor.kinBright).frame(width: 30, height: 3))
                .overlay(alignment: .bottom) { Rectangle().fill(YoseColor.sumi).frame(height: 2) }
            VStack(spacing: 0) {
                Text("結成").font(YoseFont.mincho(20)).tracking(6).foregroundStyle(YoseColor.sumi)
                Text(Self.kanjiNumber(year))
                    .font(YoseFont.mincho(year >= 10 ? 76 : 112))
                    .foregroundStyle(YoseColor.sumi)
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .padding(.vertical, -4)
                Text("年目").font(YoseFont.mincho(30)).tracking(8).foregroundStyle(YoseColor.shu)
            }
            .padding(.top, 8).padding(.bottom, 8)
            Rectangle().fill(YoseColor.sumi.opacity(0.2)).frame(height: 1).padding(.horizontal, 22)
            Text(caption)
                .font(YoseFont.gothic(13, weight: .heavy)).tracking(2)
                .foregroundStyle(YoseColor.haiSumi)
                .padding(.vertical, 9)
        }
        .frame(width: 196)
        .background(YoseColor.washi)
        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 3))
        .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1).padding(6))
        .background(Rectangle().fill(Color.black).offset(y: 6))
    }

    private var mekuriStageBoard: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // 黒漆のめくり台（太い木桟＋真鍮の留め具2つ＋コンビ名）
                HStack {
                    Circle().fill(YoseColor.kinBright).frame(width: 9, height: 9).overlay(Circle().stroke(Color.black, lineWidth: 1))
                    Spacer()
                    Text(summary.combiName)
                        .font(YoseFont.mincho(15)).tracking(3)
                        .foregroundStyle(YoseColor.kinBright)
                    Spacer()
                    Circle().fill(YoseColor.kinBright).frame(width: 9, height: 9).overlay(Circle().stroke(Color.black, lineWidth: 1))
                }
                .padding(.horizontal, 12)
                .frame(width: 290, height: 30)
                .background(YoseColor.kuroUrushi)
                .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1.5))
                .background(Rectangle().fill(Color.black).offset(y: 4))
                .zIndex(2)

                ZStack(alignment: .top) {
                    // 下層：新年のめくり札（完全不透明・固定）
                    mekuriCard(year: summary.newYear, caption: "4月 ・ 第1週")
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("結成\(summary.newYear)年目　4月 第1週")
                    // 上層：前年の札。上辺を軸に奥へ跳ね上がって消える（半透明では重ねない）
                    mekuriCard(year: summary.previousYear, caption: "全日程 終了")
                        .accessibilityHidden(true)   // めくれて消える前年の札は読ませない（19l §1-4）
                        .rotation3DEffect(.degrees(mekuriFlipped ? 90 : 0), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.35)
                        .opacity(mekuriFlipped ? 0 : 1)
                        .animation(Theme.Motion.r(.linear(duration: 0.01).delay(mekuriFlipped ? 0.2 : 0)), value: mekuriFlipped)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .overlay {
                YoseBurstParticles(trigger: burstTrigger, count: 26,
                                   colors: [YoseColor.kinBright, Color.white, YoseColor.shu],
                                   radius: 150, duration: 0.7)
                    .frame(width: 300, height: 300).allowsHitTesting(false)
            }

            YoseHankoStamp(text: "開幕", isSquare: false, angle: -8)
                .modifier(YoseStampImpactModifier(isStamped: stamped))
                .scaleEffect(1.15)
                .offset(x: -26, y: 40)
        }
    }

    // MARK: - ④ 引き継ぎ資産3連木札カード

    private var carryOverCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 見出し行＋引き継ぎ明示タグ
            HStack {
                HStack(spacing: 6) {
                    Rectangle().fill(YoseColor.shu).frame(width: 4, height: 16)
                    Text("\(summary.previousYear)年目のおわり")
                        .font(YoseFont.gothic(15, weight: .heavy))
                        .foregroundStyle(YoseColor.sumi)
                }
                Spacer()
            }

            // 3連独立木札（実力 / 知名度 / 所持金）
            HStack(spacing: 8) {
                metricKifuda(
                    label: "実力",
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
                .font(YoseFont.gothic(12, weight: .bold))
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

    // 左右の幕が中央でぶつかる合わせ目（黒い重なり影＋縦の金縁）
    private func curtainSeam(leading: Bool) -> some View {
        HStack(spacing: 0) {
            if !leading { Spacer(minLength: 0) }
            if leading { Rectangle().fill(YoseColor.kinBright).frame(width: 2) }
            LinearGradient(colors: [.black.opacity(leading ? 0.85 : 0), .black.opacity(leading ? 0 : 0.85)], startPoint: .leading, endPoint: .trailing)
                .frame(width: 8)
            if !leading { Rectangle().fill(YoseColor.kinBright).frame(width: 2) }
            if leading { Spacer(minLength: 0) }
        }
        .allowsHitTesting(false)
    }

    // MARK: - 引き幕（定式幕）パネル

    private var curtainPanel: some View {
        let colors: [Color] = [YoseColor.kuroUrushi, YoseColor.shu, YoseColor.tokiwa, YoseColor.kuroUrushi, YoseColor.shu]
        return HStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { i in
                Rectangle()
                    .fill(colors[i % colors.count])
                    // 布のヒダ：縦ストライプ内に左右の明暗を重ねる
                    .overlay(
                        LinearGradient(stops: [.init(color: .black.opacity(0.45), location: 0),
                                               .init(color: .white.opacity(0.10), location: 0.35),
                                               .init(color: .black.opacity(0.30), location: 0.7),
                                               .init(color: .black.opacity(0.55), location: 1)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .overlay(alignment: .trailing) { Rectangle().fill(Color.black.opacity(0.5)).frame(width: 1.5) }
            }
        }
        // 上部の幕押さえ（黒漆の幕板＋金線）
        .overlay(alignment: .top) {
            Rectangle().fill(YoseColor.kuroUrushi).frame(height: 26)
                .overlay(alignment: .bottom) { Rectangle().fill(YoseColor.kinBright).frame(height: 3) }
        }
        // 裾の房飾り
        .overlay(alignment: .bottom) {
            HStack(spacing: 0) {
                ForEach(0..<14, id: \.self) { _ in Rectangle().fill(YoseColor.kin).frame(maxWidth: .infinity).frame(height: 14).padding(.horizontal, 1.5) }
            }
            .overlay(alignment: .top) { Rectangle().fill(YoseColor.kinBright).frame(height: 3) }
        }
    }

    // MARK: - タイムライン制御（0.65秒・1タップ即開始）

    private func playTransitionSequence() async {
        if reduceMotion {
            curtainClosed = false
            spotOn = true
            mekuriFlipped = true
            contentAppeared = true
            stamped = true
            return
        }

        UIImpactFeedbackGenerator(style: .soft).impactOccurred()

        // 0.00〜0.32s: 幕が閉じたまま静止（溜め）→ ピンスポットが点る
        guard await pause(320_000_000) else { return }
        withAnimation(Theme.Motion.r(.easeOut(duration: 0.3))) { spotOn = true }

        // 0.32s: 定式幕が左右へ引き開けられる
        withAnimation(Theme.Motion.r(.easeInOut(duration: 0.30))) { curtainClosed = false }

        // 0.78s: めくり札が上辺を軸にパタン！＋金火花＋揺れ
        guard await pause(460_000_000) else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(Theme.Motion.r(.spring(response: 0.26, dampingFraction: 0.62))) { mekuriFlipped = true }
        burstTrigger += 1
        withAnimation(Theme.Motion.r(.linear(duration: 0.04))) { shakeY = 5 }
        guard await pause(50_000_000) else { return }
        withAnimation(Theme.Motion.r(.linear(duration: 0.05))) { shakeY = -3 }
        guard await pause(55_000_000) else { return }
        withAnimation(Theme.Motion.r(.linear(duration: 0.05))) { shakeY = 0 }

        // 1.0s: 朱印『開幕』
        guard await pause(110_000_000) else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(Theme.Motion.r(.spring(response: 0.22, dampingFraction: 0.55))) { stamped = true }
        burstTrigger += 1
        withAnimation(Theme.Motion.r(.linear(duration: 0.04))) { shakeY = 3 }
        guard await pause(50_000_000) else { return }
        withAnimation(Theme.Motion.r(.linear(duration: 0.05))) { shakeY = 0 }
        guard await pause(100_000_000) else { return }
        withAnimation(Theme.Motion.r(.spring(response: 0.3, dampingFraction: 0.8))) { contentAppeared = true }
    }

    /// 待つ。閉じられて Task が取り消されたら false（残りの触覚・揺れを鳴らさない＝code_review_2026-10-19l §1-3）
    private func pause(_ ns: UInt64) async -> Bool {
        do { try await Task.sleep(nanoseconds: ns); return true } catch { return false }
    }

    private func triggerStart() {
        guard !hasTriggeredStart else { return }
        hasTriggeredStart = true
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        onStartNewYear()
    }

    static func kanjiNumber(_ n: Int) -> String {
        let d = ["〇","一","二","三","四","五","六","七","八","九"]
        if n < 10 { return d[max(0, n)] }
        if n == 10 { return "十" }
        if n < 20 { return "十" + d[n - 10] }
        return String(n).map { d[Int(String($0)) ?? 0] }.joined()
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


/// 年の幕間の舞台背景：黒漆の闇＋中央へ落ちる細いピンスポット＋檜舞台の照り返し
private struct YearTurnStageBackdrop: View {
    let lit: Bool
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(Gradient(colors: [Color(hex: 0x0B0807), Color(hex: 0x1E1916), Color(hex: 0x0B0807)]),
                                           startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            // 背景の定式幕（暗がりに沈む縦縞）
            let n = 15, w = size.width / CGFloat(n)
            for i in 0..<n {
                let c: Color = i % 3 == 0 ? .black.opacity(0.35) : (i % 3 == 1 ? YoseColor.enji.opacity(0.09) : YoseColor.tokiwa.opacity(0.06))
                ctx.fill(Path(CGRect(x: CGFloat(i) * w, y: 0, width: w, height: size.height)), with: .color(c))
            }
            guard lit else { return }
            let cx = size.width / 2, fy = size.height * 0.40
            var beam = Path()
            beam.move(to: CGPoint(x: cx - 6, y: 0)); beam.addLine(to: CGPoint(x: cx + 6, y: 0))
            beam.addLine(to: CGPoint(x: cx + 190, y: fy + 90)); beam.addLine(to: CGPoint(x: cx - 190, y: fy + 90))
            beam.closeSubpath()
            ctx.fill(beam, with: .linearGradient(Gradient(colors: [Color(hex: 0xFFF2C4).opacity(0.06), Color(hex: 0xFFF2C4).opacity(0.22), .clear]),
                                                 startPoint: CGPoint(x: cx, y: 0), endPoint: CGPoint(x: cx, y: fy + 90)))
            ctx.fill(Path(ellipseIn: CGRect(x: cx - 200, y: fy + 60, width: 400, height: 60)),
                     with: .radialGradient(Gradient(colors: [YoseColor.kinBright.opacity(0.35), .clear]),
                                           center: CGPoint(x: cx, y: fy + 90), startRadius: 0, endRadius: 200))
        }
    }
}
