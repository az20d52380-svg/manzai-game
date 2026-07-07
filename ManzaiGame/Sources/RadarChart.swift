// RadarChart.swift
// 3画面共用部品（S5ネタ帳・S6年次リザルト・大会後リザルト）＝正本 uiux_vision_reply_part2 §依頼6。
// レーダー5角形（演技4種＋メンタル・Canvas）＋ 前回/開始との重ね。数値は等幅で別途表示（ここは形だけ）。
// ＋ S6 の48週行動内訳色帯・カテゴリ定義。全て表示層（RNG非消費・golden非対象）。

import SwiftUI
import GameCore

// MARK: 行動内訳帯のカテゴリ（GameSession が記録・plain enum＝SwiftUI非依存）

enum BandCategory {
    case keiko, baito, kaifuku, offer, taikai

    init(_ action: WeekAction) {
        switch action {
        case .train: self = .keiko
        case .job: self = .baito
        case .rest: self = .kaifuku
        case .acceptOffer: self = .offer
        }
    }

    var color: Color {
        switch self {
        case .keiko: return Theme.cIdea      // 稽古＝紫
        case .baito: return Theme.cMoney     // バイト＝緑
        case .kaifuku: return Theme.night    // 回復＝青
        case .offer: return Theme.gold       // オファー＝金
        case .taikai: return Theme.verm      // 大会＝朱
        }
    }

    var label: String {
        switch self {
        case .keiko: return "稽古"; case .baito: return "バイト"; case .kaifuku: return "回復"
        case .offer: return "仕事"; case .taikai: return "大会"
        }
    }
}

// MARK: レーダーCanvas（演技4＋メンタルの5角形。開始=inkFaint線／現在=能力色面）

struct RadarChart: View {
    /// 5軸の (名前, 現在値, 開始値, 上限, 色)
    let axes: [(name: String, value: Double, base: Double, cap: Double, color: Color)]
    var animate: Bool = true

    @State private var progress: CGFloat = 0

    static func abilityAxes(current: GameState, base: GameState, config: GameConfig) -> [(name: String, value: Double, base: Double, cap: Double, color: Color)] {
        let order: [Ability] = [.センス, .発想, .表現, .華, .メンタル]
        return order.map { a in
            let cap = (a == .メンタル) ? config.mentalCap : config.abilityCap
            return ("\(a)", current[a], base[a], cap, Theme.abilityColor(a))
        }
    }

    var body: some View {
        Canvas { ctx, size in
            let n = axes.count
            guard n >= 3 else { return }
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let R = min(size.width, size.height) / 2 - 26   // ラベル余白

            func pt(_ i: Int, _ frac: Double) -> CGPoint {
                let ang = -Double.pi / 2 + Double(i) * (2 * .pi / Double(n))
                let r = R * frac
                return CGPoint(x: c.x + r * cos(ang), y: c.y + r * sin(ang))
            }

            // グリッド（同心5角形・薄い）
            for ring in stride(from: 0.25, through: 1.0, by: 0.25) {
                var p = Path()
                for i in 0..<n { let q = pt(i, ring); i == 0 ? p.move(to: q) : p.addLine(to: q) }
                p.closeSubpath()
                ctx.stroke(p, with: .color(Theme.line), lineWidth: 1)
            }
            // 軸線
            for i in 0..<n {
                var p = Path(); p.move(to: c); p.addLine(to: pt(i, 1))
                ctx.stroke(p, with: .color(Theme.line), lineWidth: 1)
            }

            func polygon(_ frac: (Int) -> Double) -> Path {
                var p = Path()
                for i in 0..<n { let q = pt(i, frac(i)); i == 0 ? p.move(to: q) : p.addLine(to: q) }
                p.closeSubpath(); return p
            }

            // 開始（4月）＝inkFaint線
            let basePoly = polygon { i in min(1, axes[i].base / axes[i].cap) }
            ctx.stroke(basePoly, with: .color(Theme.inkFaint), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))

            // 現在＝能力色面（開始→現在へ progress でモーフ）
            let curPoly = polygon { i in
                let base = min(1, axes[i].base / axes[i].cap)
                let cur = min(1, axes[i].value / axes[i].cap)
                return base + (cur - base) * Double(progress)
            }
            ctx.fill(curPoly, with: .color(Theme.verm.opacity(0.16)))
            ctx.stroke(curPoly, with: .color(Theme.verm), lineWidth: 2)

            // 頂点の能力色ドット＋軸ラベル
            for i in 0..<n {
                let base = min(1, axes[i].base / axes[i].cap)
                let cur = min(1, axes[i].value / axes[i].cap)
                let f = base + (cur - base) * Double(progress)
                let v = pt(i, f)
                ctx.fill(Path(ellipseIn: CGRect(x: v.x - 3, y: v.y - 3, width: 6, height: 6)), with: .color(axes[i].color))
                let lp = pt(i, 1.16)
                ctx.draw(Text(axes[i].name).font(.maru(10)).foregroundStyle(axes[i].color),
                         at: lp, anchor: .center)
            }
        }
        .onAppear {
            if animate { withAnimation(.easeInOut(duration: 0.8)) { progress = 1 } }
            else { progress = 1 }
        }
    }
}

// MARK: 48週の行動内訳色帯（1週=1セグメント・左から0.6sで伸びる）

struct ActionBreakdownBand: View {
    let weeks: Int
    let categoryByWeek: [Int: BandCategory]
    @State private var grow: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(1...max(1, weeks), id: \.self) { w in
                    Rectangle()
                        .fill(categoryByWeek[w]?.color ?? Theme.line)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(width: geo.size.width, height: 14, alignment: .leading)
            .mask(alignment: .leading) {
                Rectangle().frame(width: geo.size.width * grow)
            }
        }
        .frame(height: 14)
        .clipShape(Capsule())
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { grow = 1 } }
    }
}
