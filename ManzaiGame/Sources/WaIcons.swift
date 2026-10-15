// WaIcons.swift
// 週メインのコマンド札の和風アイコン（SwiftUI の図形のみ・単色の朱）。小判（バイト）／座布団（休む）／扇子（能力アップ）／暖簾（お店）。

import SwiftUI

struct WaIcon: View {
    enum Kind { case koban, zabuton, sensu, noren }
    let kind: Kind
    var color: Color = Color(hex: 0xA62B1E)
    var body: some View {
        Group {
            switch kind {
            case .koban:   // 小判：楕円＋内側の縁＋横の筋
                ZStack {
                    Ellipse().fill(color)
                    Ellipse().stroke(.white.opacity(0.85), lineWidth: 1).padding(3)
                    VStack(spacing: 3) { ForEach(0..<2, id: \.self) { _ in Rectangle().fill(.white.opacity(0.85)).frame(width: 10, height: 1.2) } }
                }
                .frame(width: 26, height: 20)
            case .zabuton:   // 座布団：角の立った四角＋四隅の房＋中央の綴じ
                ZStack {
                    RoundedRectangle(cornerRadius: 4).fill(color)
                    RoundedRectangle(cornerRadius: 2).stroke(.white.opacity(0.8), lineWidth: 1).padding(3)
                    Circle().fill(.white.opacity(0.9)).frame(width: 4, height: 4)
                }
                .frame(width: 26, height: 20)
            case .sensu:   // 扇子：要を下にした扇形＋骨
                SensuShape().fill(color).frame(width: 26, height: 22)
                    .overlay(SensuRibs().stroke(.white.opacity(0.85), lineWidth: 1))
            case .noren:   // 暖簾：横木＋3枚の垂れ
                VStack(spacing: 0) {
                    Rectangle().fill(Color(hex: 0x2C2C2C)).frame(width: 26, height: 3)
                    HStack(spacing: 1.5) { ForEach(0..<3, id: \.self) { _ in Rectangle().fill(color).frame(width: 7.5, height: 17) } }
                }
            }
        }
        .frame(width: 28, height: 26)
    }
}

private struct SensuShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.maxY)
        p.move(to: c)
        p.addArc(center: c, radius: r.height * 1.0, startAngle: .degrees(-150), endAngle: .degrees(-30), clockwise: false)
        p.closeSubpath()
        return p
    }
}

private struct SensuRibs: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.maxY)
        for d in stride(from: -135.0, through: -45.0, by: 22.5) {
            p.move(to: c)
            let a = d * .pi / 180
            p.addLine(to: CGPoint(x: c.x + cos(a) * r.height * 0.95, y: c.y + sin(a) * r.height * 0.95))
        }
        return p
    }
}
