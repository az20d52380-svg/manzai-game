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
        case .judging, .winner:
            // 金屏風: 6扇の縦の折り目＋中央が一番明るい（光を返す金の面）
            let hi = mode == .winner
            RadialGradient(colors: hi ? [Color(hex: 0xF3D98A), Theme.goldLeafHi, Theme.goldLeafMid, Theme.goldLeafLo]
                                      : [Color(hex: 0xC49A48), Theme.goldLeafMid, Theme.goldLeafLo],
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
        let bow = mode == .loser   // 敗退は少しうつむく（傾けるだけ・暗くしない）
        return ZStack {
            CenterMic(height: figH * 0.78).position(x: w * 0.5, y: foot - figH * 0.39)
            ManzaiFigure(height: figH * 0.92, tilt: bow ? 6 : 2.2, accent: Color(hex: 0x2E55B0), breathe: 3.1,
                         bodyColors: [Color(hex: 0x4A7BE8), Color(hex: 0x2E55B0)],
                         headColor: Color(hex: 0xFFDFC2), hairColor: Color(hex: 0x40394F))
                .position(x: w * 0.5 - figH * 0.50, y: foot - figH * 0.46)
            ManzaiFigure(height: figH, tilt: bow ? -6 : -2.6, accent: Color(hex: 0xB02318), breathe: 2.4,
                         bodyColors: [Color(hex: 0xF0533E), Color(hex: 0xC22E1D)],
                         headColor: Color(hex: 0xFFDFC2), hairColor: Color(hex: 0x2E2838))
                .position(x: w * 0.5 + figH * 0.52, y: foot - figH * 0.50)
        }
    }

    // MARK: 客席の後ろ頭（逆光の影・数を数えさせない）

    private func audience(w: CGFloat, h: CGFloat) -> some View {
        let lit = mode == .winner || mode == .lit
        return Canvas { ctx, size in
            let rows: [(y: CGFloat, r: CGFloat, n: Int)] = [(size.height * 0.92, 15, 10), (size.height * 0.99, 19, 8)]
            for (ri, row) in rows.enumerated() {
                let step = size.width / CGFloat(row.n)
                for i in 0..<row.n {
                    let cx = step * (CGFloat(i) + 0.5) + (ri == 1 ? step * 0.25 : 0)
                    let head = CGRect(x: cx - row.r, y: row.y - row.r * 2.2, width: row.r * 2, height: row.r * 2)
                    let shoulders = CGRect(x: cx - row.r * 1.7, y: row.y - row.r * 0.6, width: row.r * 3.4, height: row.r * 2)
                    ctx.fill(Path(ellipseIn: head), with: .color(Color(hex: 0x241712)))
                    ctx.fill(Path(roundedRect: shoulders, cornerRadius: row.r), with: .color(Color(hex: 0x241712)))
                    // 笑った席の頭に客電の縁（決定的に半分ほど）
                    if lit, (i + ri) % 2 == 0 {
                        ctx.stroke(Path(ellipseIn: head.insetBy(dx: 1, dy: 1)), with: .color(Theme.houseLight.opacity(0.55)), lineWidth: 1.5)
                    }
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
