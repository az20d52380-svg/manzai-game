// FinalsBroadcastIntro.swift
// 決勝の「番組が始まった」導入（docs/finals_broadcast_argon_v1.md §1 場面1〜3・§4 優先順1/6）。
// 煽りV → タイトルコール＋司会 → 審査員席の紹介（7人を左から点灯）→ 進出10組の顔見せ。
// 見せ方だけ（GameCore・点数・順位・乱数に非接触）。初回はしっかり・2回目以降は短縮（UserDefaults）。
// タップ＝今の場面を飛ばして次の場面へ／「スキップ」＝導入を全部飛ばして決勝本編へ。
// 効果音は鳴らさない（コメントに名前と瞬間のみ）。外部画像なし・％表示なし・実在の番組/人名なし。

import SwiftUI
import UIKit

enum FinalsIntroStage: Int, CaseIterable {
    case vtr, title, judges, finalists
    var next: FinalsIntroStage? { FinalsIntroStage(rawValue: rawValue + 1) }
    /// MZ_FIN 用の名前
    static func debug(_ s: String) -> FinalsIntroStage? {
        switch s { case "vtr": return .vtr; case "title": return .title; case "judges": return .judges; case "finalists": return .finalists; default: return nil }
    }
}

struct FinalsBroadcastIntro: View {
    let combiName: String
    let year: Int
    let spectator: Bool
    /// 出順どおりの10組（名前・自組か）
    let finalists: [(name: String, isSelf: Bool)]
    var startStage: FinalsIntroStage = .vtr
    var onDone: () -> Void

    @State private var stage: FinalsIntroStage = .vtr
    @State private var step = 0            // 場面内の進み具合（行・席・組の数）
    @State private var blink = false
    @State private var slam = false        // 決めコピーの叩きつけ
    @State private var titleIn = false
    @State private var lit = false         // 光芒
    @State private var done = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let seenKey = "finals_broadcast_intro_seen"
    @State private var short = false

    private let judges = ["音羽 ルリ", "白波 剛", "卯月 走太", "花園 千代", "目白 慧", "神楽坂 とんぼ", "天堂寺 銀郎"]

    var body: some View {
        ZStack {
            Color(hex: 0x0D0A09).ignoresSafeArea()
            sparks
            if stage != .vtr { searchlights }
            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                content
                Spacer(minLength: 0)
                telop
            }
            .padding(.horizontal, YoseMetrics.screenMargin).padding(.top, 8).padding(.bottom, 26)
        }
        .contentShape(Rectangle())
        .onTapGesture { advanceStage() }
        .task(id: stage) { await run(stage) }
        .onAppear {
            let first = !UserDefaults.standard.bool(forKey: Self.seenKey)
            short = !first || reduceMotion
            #if DEBUG
            if !(ProcessInfo.processInfo.environment["MZ_FIN"] ?? "").isEmpty { short = false }   // 目視用: MZ_FIN 指定中は常にフル
            #endif
            stage = startStage
            if reduceMotion { blink = true } else { withAnimation(Theme.Motion.r(.easeInOut(duration: 0.8).repeatForever(autoreverses: true))) { blink = true } }
        }
    }

    // MARK: 常時表示（LIVE ・スキップ）
    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                Rectangle().fill(Color.white).frame(width: 6, height: 6).opacity(blink ? 1 : 0.25)
                Text("LIVE 生放送").font(YoseFont.gothic(12, weight: .black)).tracking(0.5).foregroundStyle(YoseColor.kinari)
            }
            .padding(.horizontal, 7).padding(.vertical, 4)
            .background(YoseColor.shu)
            .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1.5))
            Text(sceneTitle).font(YoseFont.gothic(13, weight: .heavy)).foregroundStyle(YoseColor.kin).lineLimit(1)
            Spacer()
            Button { finish() } label: {
                Text("スキップ ▶▶").accessibilityLabel("スキップ").font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.kinari)
                    .padding(.horizontal, 10).frame(height: 30)
                    .overlay(Rectangle().stroke(YoseColor.kinari.opacity(0.7), lineWidth: 1.5))
            }
        }
    }
    private var sceneTitle: String {
        switch stage {
        case .vtr: return "頂グランプリ 決勝"
        case .title: return "頂グランプリ 決勝"
        case .judges: return "審査員席"
        case .finalists: return "ファイナリスト集結"
        }
    }

    // MARK: 場面ごとの中身
    @ViewBuilder private var content: some View {
        switch stage {
        case .vtr: vtrView
        case .title: titleView
        case .judges: judgesView
        case .finalists: finalistsView
        }
    }

    private var vtrLines: [String] {
        [short ? "" : "全国 幾千の漫才師の頂点に立つのは",
         short ? "" : (spectator ? "その頂を、今夜 客席から見届ける" : "結成\(year)年目 —— \(combiName)"),
         "今夜、ひと組だけ、日本一。"].filter { !$0.isEmpty }
    }
    /// 煽りV（場面1前半）。行ごとに 拍子木 se_shaku_wooden_clap、決めコピーで 大太鼓 se_taiko_grand_hit。
    private var vtrView: some View {
        VStack(spacing: 26) {
            Rectangle().fill(YoseColor.kin.opacity(0.7)).frame(width: 70, height: 1).opacity(step > 0 ? 1 : 0)
            ForEach(Array(vtrLines.enumerated()), id: \.offset) { i, line in
                let last = i == vtrLines.count - 1
                Text(line)
                    .font(YoseFont.mincho(last ? 26 : 20))
                    .foregroundStyle(last ? YoseColor.kinBright : YoseColor.washi)
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
                    .opacity(step > i ? 1 : 0)
                    .scaleEffect(last && step > i ? (slam ? 1.0 : 1.35) : 1)
                    .offset(y: last && step > i ? (slam ? 0 : 4) : 0)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: step)
                    .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.55), value: slam)
            }
            Rectangle().fill(YoseColor.kin.opacity(0.7)).frame(width: 70, height: 1).opacity(step > 0 ? 1 : 0)
        }
    }

    /// タイトルコール（場面1後半）。暗転明けに金管ファンファーレ se_Title_fanfare_brass。
    private var titleView: some View {
        VStack(spacing: 10) {
            YoseTag(text: "決勝", style: .solidEnji)
            YoseOutlinedText(text: "頂グランプリ", font: YoseFont.gothic(34, weight: .black), fill: YoseColor.kinBright,
                             outlineColor: YoseColor.kuroUrushi, outlineWidth: 2, dropShadowY: 3).tracking(3)
            Text("〜 漫才の頂、ここに決まる 〜").font(YoseFont.mincho(15)).foregroundStyle(YoseColor.washi)
        }
        .padding(.vertical, 22).padding(.horizontal, 18).frame(maxWidth: .infinity)
        .background(YoseColor.kuroUrushi)
        .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 2.5))
        .overlay(Rectangle().stroke(YoseColor.kin.opacity(0.6), lineWidth: 1).padding(6))
        .scaleEffect(titleIn ? 1.0 : 0.85)
        .opacity(titleIn ? 1 : 0)
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.6), value: titleIn)
    }

    /// 審査員席（場面2）。並びは採点開票・票めくりの7枠と同じ＝右端が天堂寺。点灯ごとに se_spot_light_on。
    /// 設計 §1 場面2 の絵：席札7連＋頭上のピンスポット＋金縁の審査員デスク（名札）＋紹介中の木札クローズアップ。
    private var judgesView: some View {
        let cur = min(step, 7) - 1
        return VStack(spacing: 0) {
            Text("審査員席  7名・1人100点満点").font(YoseFont.gothic(13, weight: .heavy)).foregroundStyle(YoseColor.kin)
                .padding(.bottom, 14)
            ZStack(alignment: .top) {
                // 背景の幕（席の後ろ）
                LinearGradient(colors: [Color(hex: 0x2A1612), Color(hex: 0x120D0B)], startPoint: .top, endPoint: .bottom)
                    .overlay(alignment: .top) { Rectangle().fill(YoseColor.kin).frame(height: 2) }
                    .overlay(alignment: .top) {   // 幕の縁飾り
                        HStack(spacing: 0) { ForEach(0..<14, id: \.self) { _ in
                            Circle().fill(YoseColor.kin.opacity(0.7)).frame(width: 5, height: 5).frame(maxWidth: .infinity) } }
                            .padding(.top, 6)
                    }
                    .overlay(Rectangle().stroke(YoseColor.kin.opacity(0.5), lineWidth: 1))
                VStack(spacing: 0) {
                    HStack(alignment: .bottom, spacing: 5) {
                        ForEach(0..<7, id: \.self) { i in
                            let on = step > i
                            let isCur = i == cur
                            VStack(spacing: 0) {
                                // 頭上のピンスポット
                                ZStack(alignment: .top) {
                                    Capsule().fill(on ? YoseColor.kinBright : YoseColor.haiSumi.opacity(0.5)).frame(width: 14, height: 6)
                                    if isCur {
                                        JudgeSpotCone()
                                            .fill(LinearGradient(colors: [YoseColor.kinBright.opacity(0.75), YoseColor.kinBright.opacity(0.05)],
                                                                 startPoint: .top, endPoint: .bottom))
                                            .padding(.top, 5).blendMode(.screen)
                                    }
                                }
                                .frame(height: 100)
                                // 席札（顔）
                                CharacterFace(spec: FaceCatalog.judge(judges[i]), size: 42)
                                    .brightness(on ? 0 : -0.75).opacity(on ? 1 : 0.55)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 140)
                                    .background(on ? YoseColor.washi : YoseColor.kuroUrushi.opacity(0.85))
                                    .overlay(Rectangle().stroke(on ? YoseColor.kin : YoseColor.haiSumi.opacity(0.4), lineWidth: on ? 2 : 1))
                                    .shadow(color: isCur ? YoseColor.kinBright.opacity(0.8) : .clear, radius: 10)
                                    .scaleEffect(isCur ? 1.12 : 1, anchor: .bottom)
                                    .zIndex(isCur ? 1 : 0)
                            }
                            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: step)
                        }
                    }
                    .padding(.horizontal, 6)
                    // 審査員デスク（天板＋前面の名札）
                    VStack(spacing: 0) {
                        Rectangle().fill(LinearGradient(colors: [Color(hex: 0x5A3A22), Color(hex: 0x3A2414)], startPoint: .top, endPoint: .bottom))
                            .frame(height: 12)
                            .overlay(alignment: .top) { Rectangle().fill(YoseColor.kinBright).frame(height: 2) }
                        HStack(spacing: 5) {
                            ForEach(0..<7, id: \.self) { i in
                                let on = step > i
                                let parts = judges[i].split(separator: " ").map(String.init)
                                VStack(spacing: 1) {
                                    Text(parts[0]).font(YoseFont.mincho(13)).lineLimit(1).minimumScaleFactor(0.7)
                                    Text(parts.count > 1 ? parts[1] : "").font(YoseFont.mincho(12)).lineLimit(1).minimumScaleFactor(0.7)
                                }
                                .foregroundStyle(on ? YoseColor.sumi : YoseColor.haiSumi)
                                .frame(maxWidth: .infinity).frame(height: 46)
                                .background(on ? YoseColor.kinari : YoseColor.kuroUrushi.opacity(0.7))
                                .overlay(Rectangle().stroke(on ? YoseColor.kin : YoseColor.haiSumi.opacity(0.35), lineWidth: 1))
                            }
                        }
                        .padding(.horizontal, 6).padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(LinearGradient(colors: [Color(hex: 0x3A2414), Color(hex: 0x1C110A)], startPoint: .top, endPoint: .bottom))
                        .overlay(alignment: .bottom) { Rectangle().fill(YoseColor.kin).frame(height: 2) }
                    }
                    .padding(.top, -2)
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 100 + 140 + 12 + 66 + 26)
            // 紹介中の審査員の木札
            Group {
                if cur >= 0 {
                    VStack(spacing: 4) {
                        Text("審査員").font(YoseFont.gothic(12, weight: .black)).foregroundStyle(YoseColor.kin)
                        Text(judges[cur]).font(YoseFont.mincho(34)).foregroundStyle(YoseColor.kinari).tracking(2)
                    }
                    .padding(.vertical, 14).frame(maxWidth: .infinity)
                    .background(YoseColor.kuroUrushi)
                    .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 2))
                    .overlay(Rectangle().stroke(YoseColor.kin.opacity(0.5), lineWidth: 1).padding(5))
                    .id(cur)
                    .transition(.asymmetric(insertion: .opacity, removal: .identity))   // 前の名前と重ならない
                } else {
                    Color.clear
                }
            }
            .frame(height: 110).padding(.top, 26)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: step)
    }

    /// 進出10組（場面3）。めくり札が順に返る se_mekuri_flip_fast、自組の着地で重低音。
    private var finalistsView: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)
        return VStack(spacing: 18) {
            Text("決勝進出 \(finalists.count)組").font(YoseFont.gothic(17, weight: .heavy)).foregroundStyle(YoseColor.kin)
                .padding(.horizontal, 18).padding(.vertical, 6)
                .overlay(alignment: .top) { Rectangle().fill(YoseColor.kin).frame(height: 1) }
                .overlay(alignment: .bottom) { Rectangle().fill(YoseColor.kin).frame(height: 1) }
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(Array(finalists.enumerated()), id: \.offset) { i, f in
                    let on = step > i
                    Text(f.name).font(YoseFont.mincho(f.name.count > 4 ? 12 : 16)).lineLimit(2).minimumScaleFactor(0.5)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(f.isSelf ? YoseColor.shu : YoseColor.sumi)
                        .frame(maxWidth: .infinity).frame(height: 128)
                        .background(f.isSelf ? YoseColor.washiFeatured : YoseColor.washi)
                        .overlay(Rectangle().stroke(f.isSelf ? YoseColor.shu : YoseColor.kin, lineWidth: f.isSelf ? 3 : 1.5))
                        .overlay(alignment: .bottom) {
                            if f.isSelf { Text("あなた").font(YoseFont.gothic(12, weight: .black)).foregroundStyle(YoseColor.kinari)
                                .frame(maxWidth: .infinity).background(YoseColor.shu) }
                        }
                        .shadow(color: f.isSelf && on ? YoseColor.kinBright.opacity(0.9) : .clear, radius: 10)
                        .opacity(on ? 1 : 0.0)
                        .scaleEffect(on ? 1 : (f.isSelf ? 1.8 : 0.9))
                        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.65), value: step)
                }
            }
        }
    }

    // MARK: 下三分テロップ
    private var telop: some View {
        let (tag, text): (String, String) = {
            switch stage {
            case .vtr: return ("全国生放送", "頂スタジオ")
            case .title: return ("司会 鳴海", "「ついにこの夜がやって参りました。」")
            case .judges: return ("審査員", step >= 1 ? judges[min(step, 7) - 1] : "今夜の7人")
            case .finalists: return ("決勝進出", "1本目の上位3組が最終決戦へ")
            }
        }()
        return HStack(spacing: 0) {
            Text(tag).font(YoseFont.gothic(12, weight: .black)).foregroundStyle(YoseColor.kinari)
                .padding(.horizontal, 10).frame(height: 44).background(YoseColor.enji)
            Text(text).font(YoseFont.mincho(14)).foregroundStyle(YoseColor.sumi).lineLimit(1).minimumScaleFactor(0.6)
                .padding(.horizontal, 10).frame(maxWidth: .infinity, alignment: .leading).frame(height: 44).background(YoseColor.washi)
        }
        .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1.5))
        .transaction { $0.animation = nil }   // 名前の入れ替わりで前後の文字が重なって「?」に見えるのを防ぐ
    }

    // MARK: 背景（金粉・サーチライト）
    private var sparks: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { ctx in
            Canvas { g, size in
                let t = ctx.date.timeIntervalSinceReferenceDate
                for i in 0..<36 {
                    let seed = Double(i) * 12.9898
                    let x = (sin(seed) * 0.5 + 0.5) * size.width
                    let speed = 14 + (cos(seed * 1.7) * 0.5 + 0.5) * 26
                    let y = size.height - (t * speed + Double(i) * 53).truncatingRemainder(dividingBy: size.height + 20)
                    g.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)), with: .color(YoseColor.kinBright.opacity(0.55)))
                }
            }
        }
        .ignoresSafeArea().allowsHitTesting(false)
    }
    /// 下から天井へ扇状に開く4本の金サーチライト
    private var searchlights: some View {
        GeometryReader { geo in
            ForEach(0..<4, id: \.self) { i in
                let base: Double = [-34, -12, 12, 34][i]
                Rectangle()
                    .fill(LinearGradient(colors: [YoseColor.kinBright.opacity(0.34), .clear], startPoint: .bottom, endPoint: .top))
                    .frame(width: 46, height: geo.size.height * 1.1)
                    .rotationEffect(.degrees(lit ? base : base / 6), anchor: .bottom)
                    .position(x: geo.size.width * (0.16 + 0.22 * CGFloat(i)), y: geo.size.height * 0.55)
                    .blendMode(.screen)
            }
        }
        .ignoresSafeArea().allowsHitTesting(false)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.9), value: lit)
    }

    // MARK: 進行
    private func pause(_ sec: Double) async { try? await Task.sleep(nanoseconds: UInt64(sec * 1_000_000_000)) }

    private func run(_ s: FinalsIntroStage) async {
        step = 0; slam = false; titleIn = false
        switch s {
        case .vtr:
            Sound.duck(0.3, over: 0.2)   // se_taiko_low_roll（0.0s 地鳴り）
            await pause(short ? 0.3 : 0.6)
            let n = vtrLines.count
            for i in 0..<n {
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? nil : .default) { step = i + 1 }
                if i == n - 1 {
                    Haptics.rare()       // se_taiko_grand_hit（決め太鼓）
                    withAnimation(reduceMotion ? nil : .default) { slam = true }
                } else { Haptics.confirm() }   // se_shaku_wooden_clap（拍子木）
                await pause(short ? 1.3 : 2.1)
            }
            advanceStage()
        case .title:
            lit = false
            await pause(0.15)            // 暗転→0.15秒の白フラッシュ相当
            guard !Task.isCancelled else { return }
            lit = true; titleIn = true
            UINotificationFeedbackGenerator().notificationOccurred(.warning)   // se_Title_fanfare_brass
            await pause(0.2); Haptics.rare()
            await pause(short ? 1.6 : 4.2)
            advanceStage()
        case .judges:
            for i in 0..<7 {
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? nil : .default) { step = i + 1 }
                if i == 6 { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() } else { Haptics.tick() }   // se_spot_light_on
                await pause(short ? 0.15 : 1.1)
            }
            await pause(short ? 0.8 : 1.6)
            advanceStage()
        case .finalists:
            for i in 0..<finalists.count {
                guard !Task.isCancelled else { return }
                let isSelf = finalists[i].isSelf
                if isSelf { await pause(short ? 0.1 : 0.4) }
                withAnimation(reduceMotion ? nil : .default) { step = i + 1 }
                if isSelf { Haptics.rare() } else { UISelectionFeedbackGenerator().selectionChanged() }   // se_mekuri_flip_fast
                await pause(short ? 0.1 : 0.22)
            }
            await pause(short ? 0.9 : 2.0)
            advanceStage()
        }
    }

    private func advanceStage() {
        guard !done else { return }
        if let n = stage.next { stage = n } else { finish() }
    }

    private func finish() {
        guard !done else { return }
        done = true
        UserDefaults.standard.set(true, forKey: Self.seenKey)
        Sound.duck(1, over: 0.4)
        onDone()
    }
}

// MARK: - 本編の番組部品（docs/finals_broadcast_argon_v1.md §2・§4 優先順2/7/8/9/12・§3 予選）
// 見せ方だけ。点数・順位・勝敗・乱数・結果の順は FinalsData のまま変えない。効果音は鳴らさない（名前はコメント）。

/// 場面ごとの「初回はフル／2回目以降は短縮」。キーごとに1回だけ true を返す（DEBUG の MZ_FIN 指定中は常にフル＝目視用）。
enum FinalsSeen {
    static func first(_ key: String) -> Bool {
        #if DEBUG
        if !(ProcessInfo.processInfo.environment["MZ_FIN"] ?? "").isEmpty { return true }
        #endif
        let k = "finals_bc_seen_\(key)"
        let f = !UserDefaults.standard.bool(forKey: k)
        UserDefaults.standard.set(true, forKey: k)
        return f
    }
}

/// 全場面に常設する「LIVE 生放送」ヘッダー（§4-7）。左＝LIVE札、中＝いまの場面名、右＝出番。
/// 審査員席のピンスポット（上が細く下が広い台形）
struct JudgeSpotCone: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX - r.width * 0.12, y: r.minY)); p.addLine(to: CGPoint(x: r.midX + r.width * 0.12, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX + 4, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX - 4, y: r.maxY)); p.closeSubpath()
        return p
    }
}

struct FinalsLiveBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let scene: String
    var trailing: String? = nil
    @State private var blink = false
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Rectangle().fill(Color.white).frame(width: 6, height: 6).opacity(blink ? 1 : 0.25)
                Text("LIVE 生放送").font(YoseFont.gothic(12, weight: .black)).tracking(0.5).foregroundStyle(YoseColor.kinari)
            }
            .padding(.horizontal, 6).frame(height: 20)
            .background(YoseColor.shu)
            .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1.2))
            Text(scene).font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.kinBright).lineLimit(1)
            Spacer(minLength: 4)
            if let trailing {
                Text(trailing).font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.kinari).lineLimit(1)
            }
        }
        .padding(.horizontal, 8).frame(height: 26)
        .background(YoseColor.kuroUrushi.opacity(0.88))
        .overlay(alignment: .bottom) { Rectangle().fill(YoseColor.kin).frame(height: 1) }
        .onAppear { if reduceMotion { blink = true } else { withAnimation(Theme.Motion.r(.easeInOut(duration: 0.8).repeatForever(autoreverses: true))) { blink = true } } }
    }
}

/// スタジオ照明（§4-2）。舞台の上に重ねる：金サーチライト4本。最終決戦は真紅×群青に替わる（§4-9）。
struct FinalsStudioLights: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var duel: Bool
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<4, id: \.self) { i in
                    let base: Double = [-30, -10, 10, 30][i]
                    let col: Color = duel ? (i < 2 ? Color(hex: 0xC4262E) : Color(hex: 0x3047B8)) : YoseColor.kinBright
                    Rectangle()
                        .fill(LinearGradient(colors: [col.opacity(duel ? 0.34 : 0.20), .clear], startPoint: .bottom, endPoint: .top))
                        .frame(width: 44, height: geo.size.height * 0.95)
                        .rotationEffect(.degrees(base), anchor: .bottom)
                        .position(x: geo.size.width * (0.16 + 0.22 * CGFloat(i)), y: geo.size.height * 0.52)
                        .blendMode(.screen)
                }
                if duel {   // 最終決戦＝天井から赤と青の薄い被り
                    LinearGradient(colors: [Color(hex: 0x7A1020).opacity(0.30), .clear, Color(hex: 0x14246E).opacity(0.30)],
                                   startPoint: .leading, endPoint: .trailing).blendMode(.multiply)
                }
            }
        }
        .ignoresSafeArea().allowsHitTesting(false)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: duel)
    }
}

/// 登場の扉（§4-8）。閉じた2枚の扉が割れて逆光が差し、紹介テロップが出る。open が true で割れる。
struct FinalsEntranceDoors: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let open: Bool
    let order: Int
    let name: String
    let year: Int
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 逆光（扉の隙間）
                RadialGradient(colors: [YoseColor.kinBright.opacity(open ? 0.85 : 0), .clear],
                               center: .center, startRadius: 4, endRadius: geo.size.width * 0.8)
                HStack(spacing: 0) {
                    door.offset(x: open ? -geo.size.width * 0.52 : 0)
                    door.offset(x: open ? geo.size.width * 0.52 : 0)
                }
                .opacity(open ? 0 : 1)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.9), value: open)
            }
            .overlay(alignment: .top) {
                VStack(spacing: 4) {   // 紹介テロップ（肩書・連続出場の元データは無いので、出番と結成年数だけ）
                    Text("第\(order)番手").font(YoseFont.gothic(12, weight: .black)).foregroundStyle(YoseColor.kinari)
                        .padding(.horizontal, 10).frame(height: 22).background(YoseColor.enji)
                    Text(name).font(YoseFont.mincho(26)).foregroundStyle(YoseColor.kinBright).lineLimit(1).minimumScaleFactor(0.5)
                    Text("結成\(year)年目").font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.kinari)
                }
                .padding(.vertical, 8).padding(.horizontal, 18)
                .background(YoseColor.kuroUrushi.opacity(0.9))
                .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1.5))
                .padding(.top, 70)
                .opacity(open ? 1 : 0.0).offset(y: open ? 0 : 14)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.4).delay(0.5), value: open)
            }
        }
        .ignoresSafeArea().allowsHitTesting(false)
    }
    private var door: some View {
        Rectangle().fill(LinearGradient(colors: [YoseColor.kuroUrushi, Color(hex: 0x2A1210)], startPoint: .top, endPoint: .bottom))
            .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 2))
            .overlay(Rectangle().stroke(YoseColor.kin.opacity(0.5), lineWidth: 1).padding(10))
    }
}

/// 番組のエンディング（§1 場面12）。優勝組・最終決戦の3組・本日の出場組を見せて「放送はここまで」。タップ／スキップで即閉じる。
struct FinalsBroadcastEnding: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    let winnerName: String
    let champion: Bool
    let spectator: Bool
    let duelNames: [String]
    let allNames: [String]
    let short: Bool
    var onDone: () -> Void
    @State private var step = 0
    @State private var done = false
    var body: some View {
        ZStack {
            Color(hex: 0x0D0A09).ignoresSafeArea()
            VStack(spacing: 0) {
                FinalsLiveBar(scene: "エンディング")
                Spacer(minLength: 0)
                VStack(spacing: 14) {
                    Text("頂グランプリ 決勝").font(YoseFont.gothic(13, weight: .heavy)).tracking(2).foregroundStyle(YoseColor.kin)
                        .opacity(step >= 1 ? 1 : 0)
                    VStack(spacing: 4) {
                        Text("今夜の頂").font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.kinari)
                        Text(winnerName).font(YoseFont.mincho(32)).foregroundStyle(champion ? YoseColor.kinBright : YoseColor.washi)
                            .lineLimit(1).minimumScaleFactor(0.5)
                    }
                    .opacity(step >= 2 ? 1 : 0).scaleEffect(step >= 2 ? 1 : 1.2)
                    if !duelNames.isEmpty {
                        Text("最終決戦  " + duelNames.joined(separator: " ／ "))
                            .font(YoseFont.mincho(13)).foregroundStyle(YoseColor.washi).multilineTextAlignment(.center)
                            .opacity(step >= 3 ? 1 : 0)
                    }
                    if !allNames.isEmpty {   // 本日の出場組（クレジット）
                        Text("出場  " + allNames.joined(separator: "・"))
                            .font(YoseFont.mincho(12)).foregroundStyle(YoseColor.ginNezu).multilineTextAlignment(.center)
                            .padding(.horizontal, 20).opacity(step >= 4 ? 1 : 0)
                    }
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: step)
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    Text("司会 鳴海").font(YoseFont.gothic(12, weight: .black)).foregroundStyle(YoseColor.kinari)
                        .padding(.horizontal, 10).frame(height: 44).background(YoseColor.enji)
                    Text("「以上、頂グランプリ決勝でした。」").font(YoseFont.mincho(14)).foregroundStyle(YoseColor.sumi)
                        .padding(.horizontal, 10).frame(maxWidth: .infinity, alignment: .leading).frame(height: 44).background(YoseColor.washi)
                }
                .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1.5))
                .opacity(step >= 3 ? 1 : 0).animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: step)
                .padding(.horizontal, YoseMetrics.screenMargin).padding(.bottom, 26)
            }
            VStack { HStack { Spacer()
                Button { finish() } label: {
                    Text("スキップ ▶▶").accessibilityLabel("スキップ").font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.kinari)
                        .padding(.horizontal, 10).frame(height: 28)
                        .overlay(Rectangle().stroke(YoseColor.kinari.opacity(0.7), lineWidth: 1.5))
                }.padding(.trailing, 8).padding(.top, 34)
            }; Spacer() }
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .task {
            for i in 1...4 {
                try? await Task.sleep(nanoseconds: UInt64((short ? 0.3 : 0.9) * 1_000_000_000))
                if Task.isCancelled || done { return }
                step = i   // se_applause_hall（余韻の拍手・最初の1回）
            }
            try? await Task.sleep(nanoseconds: UInt64((short ? 0.7 : 1.8) * 1_000_000_000))
            if Task.isCancelled || voiceOver { return }   // VoiceOver 中は自動で閉じない（スキップ／タップで閉じる・a11y_check_1019）
            finish()
        }
        .accessibilityAction { finish() }
    }
    private func finish() { guard !done else { return }; done = true; onDone() }
}
