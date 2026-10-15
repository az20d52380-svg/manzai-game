// StageFrame.swift
// 本番の舞台（見た目の作り直し v1・docs/visual_genre_overhaul_v1.md §4-1・§4-4）。
// 「暖色の客席に光る舞台」＝暗いのは客席だけ・舞台は明るい。紫は使わない（暗い側は暖色＝R＞G＞B）。
// 層（奥→手前）: 客席の闇 → 背景面（緞帳 or 金屏風）→ 光の芯（スポット）→ 舞台板 → 二人＋マイク → 客席の頭 → 光の粒 → 一文字幕・袖幕。
// 華やかさの3条件（R5 原理2）＝光の芯・光を返す金の面・光の粒を必ず満たす。目標: 平均L 0.18以上・点灯面積35%以上【仮】
// （after スクショを tools/measure_brightness.py で測って検収）。View層のみ・golden非干渉・乱数不使用。

import SwiftUI

struct StageFrame: View {
    enum Mode {
        case preshow     // 開演前（緞帳・弱めのスポット）
        case lit         // 明転・ネタ中／大会結果
        case judging     // 採点（金屏風の暗い2段）
        case winner      // 自組の優勝（金屏風の最明部＋光条）
        case loser       // 敗退（スポットを絞り色温度を下げる・暗くはしない）
        case spectator   // 客席から観る年（銀・頭越し）
    }
    var mode: Mode = .lit
    /// 舞台の上に二人を立たせるか（採点など札が主役の場面では外す）
    var performers: Bool = true
    /// 舞台板の上端（画面高さ比）。人物とスポットの位置もこれに合わせる
    var floorTop: CGFloat = 0.56

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let spotY = h * (floorTop - 0.08)
            ZStack {
                Theme.house
                backdrop(w: w, h: h)
                spotlight(w: w, h: h, centerY: spotY)
                if mode == .judging {
                    // 採点: 臙脂幕のまま周囲を黒漆で絞ってコンビにだけ光を残す（黄色い幕へ急に変えない）
                    RadialGradient(colors: [.clear, YoseColor.kuroUrushi.opacity(0.55)], center: UnitPoint(x: 0.5, y: floorTop - 0.12),
                                   startRadius: w * 0.25, endRadius: max(w, h) * 0.70)
                        .allowsHitTesting(false)
                }
                floor(w: w, h: h)
                if performers { duo(w: w, h: h) }
                audience(w: w, h: h)
                DustField(centerX: w * 0.5, spread: w * 0.34)
                    .opacity(mode == .loser ? 0.5 : 1)
                    .allowsHitTesting(false)
                frame(w: w, h: h)
            }
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: 背景面（緞帳／金屏風）

    @ViewBuilder private func backdrop(w: CGFloat, h: CGFloat) -> some View {
        switch mode {
        case .winner:
            // 金屏風: 6扇の縦の折り目＋中央が一番明るい（光を返す金の面・色は消金/金箔のトークン内）
            RadialGradient(colors: [YoseColor.kinBright, YoseColor.kin, Color(hex: 0x9A802F), Color(hex: 0x6E5A22)],
                           center: UnitPoint(x: 0.5, y: 0.30), startRadius: 10, endRadius: max(w, h) * 0.75)
                .overlay {
                    HStack(spacing: 0) {
                        ForEach(0..<6, id: \.self) { i in
                            Rectangle().fill(.clear)
                                .overlay(alignment: .trailing) {
                                    if i < 5 { Rectangle().fill(Color.black.opacity(0.16)).frame(width: 1.5) }
                                }
                        }
                    }
                }
                .frame(height: h * (floorTop + 0.04)).frame(maxHeight: .infinity, alignment: .top)
        default:
            // 緞帳（臙脂の縦ひだ・光の当たる中央だけ明るい）
            Canvas { ctx, size in
                let pleat: CGFloat = 26
                var x: CGFloat = 0
                var i = 0
                while x < size.width {
                    let c = i % 3 == 0 ? Theme.curtainShade : (i % 3 == 1 ? Theme.curtain : Theme.curtainLit.opacity(0.9))
                    ctx.fill(Path(CGRect(x: x, y: 0, width: pleat * (i % 3 == 2 ? 0.35 : 0.65), height: size.height)),
                             with: .color(c))
                    x += pleat * (i % 3 == 2 ? 0.35 : 0.65)
                    i += 1
                }
            }
            .frame(height: h * (floorTop + 0.04)).frame(maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: 光の芯

    private func spotlight(w: CGFloat, h: CGFloat, centerY: CGFloat) -> some View {
        let shrink: CGFloat = mode == .loser ? 0.84 : (mode == .preshow ? 0.95 : 1)
        let core: Color = mode == .loser ? Color(hex: 0xF4ECE0) : (mode == .spectator ? Color(hex: 0xEEF2F6) : Theme.spotCore)
        let mid: Color = mode == .spectator ? Theme.silver.opacity(0.45) : (mode == .loser ? Color(hex: 0xD8C8B0).opacity(0.40) : Theme.spotMid)
        return RadialGradient(colors: [core.opacity(0.95), core.opacity(0.70), mid, Theme.spotEdge, .clear],
                              center: .center, startRadius: 4, endRadius: w * 0.74 * shrink)
            .frame(width: w * 1.6, height: h * 0.92 * shrink)
            .position(x: w / 2, y: centerY)
            .blendMode(.screen)
    }

    // MARK: 舞台板

    private func floor(w: CGFloat, h: CGFloat) -> some View {
        let top = h * floorTop
        return ZStack {
            RadialGradient(colors: [Color(hex: 0xF4CF96), Color(hex: 0xE2AE72), Theme.boardsLit, Color(hex: 0x8A6440)],
                           center: UnitPoint(x: 0.5, y: 0.0), startRadius: 10, endRadius: w * 1.25)
            // 板の目地（消失点へ収束）
            Canvas { ctx, size in
                let vanish = CGPoint(x: size.width / 2, y: -size.height * 1.2)
                for i in 0...12 {
                    let bx = size.width * CGFloat(i) / 12
                    var p = Path(); p.move(to: CGPoint(x: bx, y: size.height)); p.addLine(to: vanish)
                    ctx.stroke(p, with: .color(Color.black.opacity(0.12)), lineWidth: 1)
                }
            }
            // 光の映り込み（光を返す面）
            Ellipse().fill(Theme.spotCore.opacity(mode == .loser ? 0.18 : 0.35))
                .frame(width: w * 0.55, height: (h - top) * 0.30).blur(radius: 10)
                .offset(y: -(h - top) * 0.26)
        }
        .frame(width: w, height: h - top)
        .position(x: w / 2, y: top + (h - top) / 2)
    }

    // MARK: 二人＋マイク（舞台の上・スポットの中）

    private func duo(w: CGFloat, h: CGFloat) -> some View {
        let figH = min(150, h * 0.17)
        let foot = h * floorTop + figH * 0.18
        let rival = mode == .spectator   // 客席から観る年は他組の衣装（自組の青・赤を使わない）
        let bow = mode == .loser   // 敗退は少しうつむく（傾けるだけ・暗くしない）
        return ZStack {
            CenterMic(height: figH * 0.78).position(x: w * 0.5, y: foot - figH * 0.39)
            ManzaiFigure(height: figH * 0.92, tilt: bow ? 6 : 2.2, accent: rival ? YoseColor.tokiwa : Color(hex: 0x2E55B0), breathe: 3.1,
                         bodyColors: rival ? [Color(hex: 0x3F7A55), YoseColor.tokiwa] : [Color(hex: 0x4A7BE8), Color(hex: 0x2E55B0)],
                         headColor: Color(hex: 0xFFDFC2), hairColor: Color(hex: 0x40394F))
                .position(x: w * 0.5 - figH * 0.50, y: foot - figH * 0.46)
            ManzaiFigure(height: figH, tilt: bow ? -6 : -2.6, accent: rival ? YoseColor.kuroUrushi : Color(hex: 0xB02318), breathe: 2.4,
                         bodyColors: rival ? [Color(hex: 0x5A504A), YoseColor.kuroUrushi] : [Color(hex: 0xF0533E), Color(hex: 0xC22E1D)],
                         headColor: Color(hex: 0xFFDFC2), hairColor: Color(hex: 0x2E2838))
                .position(x: w * 0.5 + figH * 0.52, y: foot - figH * 0.50)
        }
    }

    // MARK: 客席の後ろ頭（逆光の影・数を数えさせない）
    // design_system_argon_v1 §8-4・§7-型D: 金縁なし・単色 #181210・頭の大きさ/肩幅/高さ/間隔をバラす（シード固定の決定的な擬似乱数）

    private func audience(w: CGFloat, h: CGFloat) -> some View {
        let big: CGFloat = mode == .spectator ? 1.22 : 1      // 客席から観る年は手前の客を一段大きく
        return Canvas { ctx, size in
            func rnd(_ i: Int, _ k: Int) -> CGFloat {
                let v = sin(Double(i &* 131 &+ k &* 977)) * 43758.5453
                return CGFloat(v - Foundation.floor(v))
            }
            let shade = Color(hex: 0x181210)
            // (基準y比, 頭半径の最小, 最大, 人数, 行番号)
            let rows: [(y: CGFloat, r0: CGFloat, r1: CGFloat, n: Int)] = [
                (size.height * 0.915, 11, 15, 11),
                (size.height * (mode == .spectator ? 0.985 : 1.0), 17 * big, 24 * big, 7)
            ]
            for (ri, row) in rows.enumerated() {
                let step = size.width / CGFloat(row.n)
                for i in 0..<row.n {
                    let k = ri * 40 + i
                    let r = row.r0 + (row.r1 - row.r0) * rnd(k, 1)
                    let cx = step * (CGFloat(i) + 0.5) + (rnd(k, 2) - 0.5) * step * 0.7
                    let y = row.y + (rnd(k, 3) - 0.5) * 16
                    let shoulderW = r * (2.9 + 0.9 * rnd(k, 4))
                    let head = CGRect(x: cx - r, y: y - r * 2.2, width: r * 2, height: r * 2)
                    let shoulders = CGRect(x: cx - shoulderW / 2, y: y - r * 0.6, width: shoulderW, height: r * 2.2)
                    ctx.fill(Path(ellipseIn: head), with: .color(shade))
                    ctx.fill(Path(roundedRect: shoulders, cornerRadius: r * 0.9), with: .color(shade))
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: 一文字幕・袖幕（額縁＝どの本番画面も同じ枠）

    private func frame(w: CGFloat, h: CGFloat) -> some View {
        ZStack(alignment: .top) {
            // 一文字幕（上端・臙脂＋金の房）
            VStack(spacing: 0) {
                LinearGradient(colors: [Theme.curtainShade, Theme.curtain, Theme.curtainLit], startPoint: .top, endPoint: .bottom)
                    .frame(height: 104)
                Rectangle().fill(Theme.gold).frame(height: 2.5)
                // 房（半円の連なり）
                Canvas { ctx, size in
                    var x: CGFloat = 6
                    while x < size.width {
                        ctx.fill(Path(ellipseIn: CGRect(x: x - 5, y: -5, width: 10, height: 10)), with: .color(Theme.gold))
                        x += 14
                    }
                }
                .frame(height: 6)
            }
            .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
            // 袖幕（左右）
            HStack {
                sideWing
                Spacer()
                sideWing.scaleEffect(x: -1, y: 1)
            }
        }
    }

    private var sideWing: some View {
        LinearGradient(colors: [Theme.curtainShade, Theme.curtain, Theme.curtainLit.opacity(0.85)], startPoint: .leading, endPoint: .trailing)
            .frame(width: 22)
            .overlay(alignment: .trailing) { Rectangle().fill(Theme.gold.opacity(0.75)).frame(width: 1.5) }
            .shadow(color: .black.opacity(0.35), radius: 6, x: 3)
    }
}

// MARK: めくり札（表と裏を別の面で描く＝鏡文字にならない）

/// shown=false で裏、true で表。Y軸回転の途中（90°）で面を切り替えるので、裏返った文字は一度も見えない。
struct FlipCard<Front: View, Back: View>: View, Animatable {
    var angle: Double   // 0=表 180=裏
    @ViewBuilder var front: Front
    @ViewBuilder var back: Back

    init(shown: Bool, @ViewBuilder front: () -> Front, @ViewBuilder back: () -> Back) {
        self.angle = shown ? 0 : 180
        self.front = front()
        self.back = back()
    }

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        ZStack {
            front.opacity(angle < 90 ? 1 : 0)
            back.opacity(angle < 90 ? 0 : 1)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))   // 裏面はあらかじめ反転＝全体が180°の時に正しく読める
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
    }
}

// MARK: テロップ（暗い地の上に置いてよい短く太い字＝白字＋墨の縁）

struct Telop: View {
    let text: String
    var size: CGFloat = 22
    var color: Color = .white
    var body: some View {
        let edge = Theme.sumi
        Text(text).font(.maru(size, weight: .black)).foregroundStyle(color)
            .shadow(color: edge, radius: 0, x: 2, y: 0).shadow(color: edge, radius: 0, x: -2, y: 0)
            .shadow(color: edge, radius: 0, x: 0, y: 2).shadow(color: edge, radius: 0, x: 0, y: -2)
            .shadow(color: .black.opacity(0.35), radius: 4, y: 3)
            .multilineTextAlignment(.center)
    }
}

// MARK: 開演の儀（客電が落ちる→暗転→スポットイン→明転・visual_genre_overhaul_v1 §6 L11）

/// 本番画面の最初の相として重ねる。初回は約1.5秒、2回目以降は約0.6秒。タップで即終わる（K6）。
/// 暗いのはこの溜めの間だけ（§4-1「暗くしてよいのは溜めの1.5秒以内」）。演出ひかえめでは短いクロスフェード。
struct StageCeremony: View {
    var onDone: () -> Void
    @State private var spot: CGFloat = 0.1
    @State private var veil: Double = 1
    @State private var done = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let seenKey = "stage_ceremony_seen"

    var body: some View {
        ZStack {
            Theme.house
            RadialGradient(colors: [Theme.spotCore, Theme.spotMid, Theme.spotEdge, .clear],
                           center: .center, startRadius: 0, endRadius: 300)
                .scaleEffect(spot)
                .blendMode(.screen)
        }
        .opacity(veil)
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .allowsHitTesting(!done)
        .task { await run() }
    }

    private func run() async {
        let first = !UserDefaults.standard.bool(forKey: Self.seenKey)
        UserDefaults.standard.set(true, forKey: Self.seenKey)
        let short = !first || reduceMotion
        Sound.duck(0.3, over: 0.2)                                   // 客電が落ちる＝BGMを絞る
        try? await Task.sleep(nanoseconds: short ? 120_000_000 : 350_000_000)
        guard !done else { return }
        withAnimation(.easeOut(duration: short ? 0.25 : 0.6)) { spot = 1.4 }   // スポットイン
        try? await Task.sleep(nanoseconds: short ? 250_000_000 : 650_000_000)
        guard !done else { return }
        finish()
    }

    private func finish() {
        guard !done else { return }
        done = true
        Sound.duck(1, over: 0.4)
        withAnimation(.easeIn(duration: 0.3)) { veil = 0 }            // 明転
        onDone()
    }
}

// MARK: 舞台の看板類（design_system_argon_v1 §7-型D・黒漆＋消金の二重枠＋墨のハードシャドウ）

/// 大会看板（黒漆の地・消金の二重枠）。大会名／「審査中」／観戦中など、舞台の上端に掲げる。
struct StageSign: View {
    let title: String
    var subtitle: String? = nil
    var tag: String? = nil
    /// 大会の大看板（頂グランプリ等）：消金の墨袋文字26ptにする
    var outlined = false
    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 8) {
                if let tag { YoseTag(text: tag, style: .solidEnji) }
                if outlined {
                    YoseOutlinedText(text: title, font: YoseFont.gothic(26, weight: .black), fill: YoseColor.kinBright,
                                     outlineColor: YoseColor.kuroUrushi, outlineWidth: 1.5, dropShadowY: 2)
                        .tracking(2).lineLimit(1).minimumScaleFactor(0.7)
                } else {
                    Text(title).font(YoseFont.headerTitle).foregroundStyle(YoseColor.kin)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            if let subtitle {
                Text(subtitle).font(YoseFont.mincho(14)).foregroundStyle(YoseColor.kinari)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(YoseColor.kuroUrushi)
        .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: YoseMetrics.borderMain))
        .overlay(Rectangle().stroke(YoseColor.kin.opacity(0.7), lineWidth: 0.8).padding(4))
        .background(alignment: .bottom) { Rectangle().fill(YoseColor.sumi).offset(y: YoseMetrics.shadowCard) }
        .padding(.horizontal, 24)
    }
}

/// 舞台上の短い太字（墨の縁つき・暗い地にも明るい床にも置ける）。旧 Telop（丸ゴ＋ぼかし影）の置き換え。
struct YTelop: View {
    let text: String
    var size: CGFloat = 20
    var color: Color = YoseColor.kinari
    var body: some View {
        YoseOutlinedText(text: text, font: YoseFont.gothic(size, weight: .black), fill: color,
                         outlineColor: YoseColor.sumi, outlineWidth: 1.5, dropShadowY: 2)
            .multilineTextAlignment(.center)
    }
}

/// 送りの合図 ▼（朱・上下に弾む。演出ひかえめでは止まる）
struct YoseAdvanceCue: View {
    var color: Color = YoseColor.kinBright
    @State private var bob = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Image(systemName: "arrowtriangle.down.fill")
            .font(.system(size: 12, weight: .black)).foregroundStyle(color)
            .shadow(color: YoseColor.sumi, radius: 0, x: 0, y: 1)
            .offset(y: bob ? 3 : 0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) { bob = true }
            }
            .accessibilityHidden(true)
    }
}

/// 地の文の貼り紙（明朝・左に臙脂の綴じ）。旧 NarrationCard の置き換え。
struct YoseNarration: View {
    let text: String
    var body: some View {
        Text(text).font(YoseFont.mincho(15)).lineSpacing(5).foregroundStyle(YoseColor.sumi)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .yoseHarigami(isFeatured: true)
            .padding(.bottom, 2)
    }
}

/// 舞台下端の帯（黒漆・消金の上辺・左に朱の縦帯・コンビ名は明朝）。
struct StageLowerBand: View {
    let name: String
    var left: String? = nil
    var tag: String
    var body: some View {
        HStack(spacing: 10) {
            Rectangle().fill(YoseColor.shu).frame(width: 6)
            if let left { Text(left).font(YoseFont.gothic(11, weight: .heavy)).foregroundStyle(YoseColor.kin) }
            Text(name).font(YoseFont.mincho(16)).foregroundStyle(YoseColor.kinari).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 6)
            YoseTag(text: tag, style: .outlineKin)
        }
        .padding(.trailing, 14).padding(.top, 0)
        .frame(height: 50, alignment: .center)
        .background(YoseColor.kuroUrushi)
        .overlay(alignment: .top) { Rectangle().fill(YoseColor.kin).frame(height: 2) }
    }
}

/// 結果額縁（通過／敗退）。黒漆＋金＋朱の枠、または敗退は銀鼠＋墨の重い枠。
struct StageVerdictPlate: View {
    let text: String
    var lost = false
    var body: some View {
        YoseOutlinedText(text: text,
                         font: lost ? YoseFont.gothic(26, weight: .black) : YoseFont.bannerTitle,
                         fill: lost ? YoseColor.disabledText : YoseColor.kinBright,
                         outlineColor: YoseColor.sumi, outlineWidth: 2, dropShadowY: 2)
            .tracking(4)
            .padding(.horizontal, 26).padding(.vertical, 14)
            .background(lost ? YoseColor.ginNezu : YoseColor.kuroUrushi)
            .overlay(Rectangle().stroke(lost ? YoseColor.sumi : YoseColor.kin, lineWidth: lost ? 2.5 : 3))
            .overlay(Rectangle().stroke(lost ? YoseColor.haiSumi : YoseColor.shu, lineWidth: 1.5).padding(5))
            .background(alignment: .bottom) { Rectangle().fill(YoseColor.sumi).offset(y: lost ? 3 : 4) }
    }
}

/// 全幅の墨帯テロップ（客席の反応など）。
struct StageTelopBelt: View {
    let text: String
    var body: some View {
        Text(text).font(YoseFont.mincho(20)).foregroundStyle(YoseColor.kinari)
            .tracking(2)
            .frame(maxWidth: .infinity).frame(height: 38)
            .background(YoseColor.kuroUrushi)
            .overlay(alignment: .top) { Rectangle().fill(YoseColor.kin).frame(height: 1.5) }
            .overlay(alignment: .bottom) { Rectangle().fill(YoseColor.kin).frame(height: 1.5) }
    }
}

/// 舞台袖のめくり（木の台＋白和紙＋縦書きの名）。
struct StageMakuri: View {
    let name: String
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 1) {
                ForEach(Array(name.enumerated()), id: \.offset) { _, c in
                    Text(String(c)).font(YoseFont.mincho(17)).foregroundStyle(YoseColor.sumi)
                }
            }
            .padding(.vertical, 8).frame(width: 34)
            .background(YoseColor.washiFeatured)
            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
            Rectangle().fill(YoseColor.kiDark).frame(width: 6, height: 40)       // 脚
            Rectangle().fill(YoseColor.sumi).frame(width: 40, height: 5)           // 台
        }
    }
}

/// 紙吹雪（金箔・紅白の角紙＝ソリッドな長方形のみ・ぼかし無し）。シード固定で静止。
struct StageConfettiCards: View {
    var body: some View {
        Canvas { ctx, size in
            let cols: [Color] = [YoseColor.kinBright, YoseColor.shu, YoseColor.washi]
            for i in 0..<28 {
                func r(_ k: Int) -> CGFloat { let v = sin(Double(i * 53 + k * 211)) * 43758.5; return CGFloat(v - Foundation.floor(v)) }
                var c = ctx
                c.translateBy(x: size.width * r(1), y: size.height * 0.62 * r(2) + 70)
                c.rotate(by: .degrees(Double(r(3)) * 180))
                c.fill(Path(CGRect(x: -3, y: -5, width: 6, height: 10)), with: .color(cols[i % 3]))
            }
        }
        .allowsHitTesting(false)
    }
}

#if DEBUG
/// MZ_UI=frame の目視用：舞台の各状態に「看板・結果額縁・テロップ・めくり」を載せた見本（本番の演出タイミングには触れない）。
struct StageFramePreview: View {
    let mode: StageFrame.Mode
    private let combo = "そよ風ズ"
    var body: some View {
        ZStack {
            StageFrame(mode: mode)
            if mode == .preshow || mode == .loser { Color.black.opacity(mode == .loser ? 0.40 : 0.40).ignoresSafeArea().allowsHitTesting(false) }
            if mode == .winner { StageConfettiCards().ignoresSafeArea() }
            VStack(spacing: 0) {
                switch mode {
                case .lit: StageSign(title: "春新人賞A・本番", subtitle: "『商店街の福引』")
                case .preshow: StageSign(title: "春新人賞A・本番")
                case .judging: StageSign(title: "審 査 中 ・・・")
                case .winner, .loser: StageSign(title: "春新人賞A・本番")
                case .spectator: StageSign(title: "浪速タイフーン", subtitle: "『商店街の福引』", tag: "客席から観戦中")
                }
                Spacer()
            }
            .padding(.top, 66)
            centerLayer
            if mode == .lit || mode == .spectator {
                VStack { Spacer(); HStack { Spacer(); StageMakuri(name: mode == .lit ? combo : "タイフーン").padding(.trailing, 34) } .padding(.bottom, 170) }
            }
            if mode == .judging { VStack { Spacer(); StageTelopBelt(text: "「 どっと沸いた！！ 」").padding(.bottom, 150) } }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder private var centerLayer: some View {
        switch mode {
        case .preshow:
            VStack(spacing: 10) {
                Text(combo).font(YoseFont.mincho(28)).foregroundStyle(YoseColor.sumi)
                Text("『商店街の福引』").font(YoseFont.netaTitle).foregroundStyle(YoseColor.sumi)
            }
            .padding(.horizontal, 28).padding(.vertical, 18)
            .yoseHarigami(isFeatured: true)
            .overlay(alignment: .topTrailing) { YoseHankoStamp(text: "出番").offset(x: 12, y: -14) }
            .offset(y: 70)
        case .winner:
            VStack(spacing: 0) {
                StageVerdictPlate(text: "予選通過！！")
                    .overlay(alignment: .topTrailing) { YoseHankoStamp(text: "突破").offset(x: 14, y: -18) }
            }
            .offset(y: -150)
        case .loser:
            StageVerdictPlate(text: "予選敗退・・・", lost: true).offset(y: -150)
        default: EmptyView()
        }
    }
}
#endif
