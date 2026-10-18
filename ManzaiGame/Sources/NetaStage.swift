// ネタの仕上がりの4段（表示専用・閾値【仮】）。数字は出さず、段の札で客観的に見せる。
import SwiftUI
import GameCore

enum NetaStage {
    static let names = ["書きかけ", "形になってきた", "仕上がってきた", "仕上がった"]
    /// 完成度 → 段 0...3（<35／<60／<85／≥85）【仮】
    static func index(_ polish: Double) -> Int {
        polish < 35 ? 0 : polish < 60 ? 1 : polish < 85 ? 2 : 3
    }
    static func name(_ polish: Double) -> String { names[index(polish)] }
    /// 画面に出していた最後の段（ネタ id ごと・メモリ内）。上がった時だけ札が光る
    @MainActor static var lastSeen: [Int: Int] = [:]
}

/// 4段の目盛り＋段の名前。段が上がったのを見た時だけ一瞬光る（文字は出さない）
struct NetaStageBadge: View {
    let netaID: Int
    let polish: Double
    @State private var glow = false

    var body: some View {
        let idx = NetaStage.index(polish)
        HStack(spacing: 5) {
            HStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { i in
                    Rectangle().fill(i <= idx ? YoseColor.shu : YoseColor.ginNezu)
                        .frame(width: 8, height: 8)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1))
                }
            }
            Text(NetaStage.names[idx]).font(YoseFont.captionBold).foregroundStyle(YoseColor.sumi).lineLimit(1)
        }
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(YoseColor.kinBright.opacity(glow ? 0.9 : 0))
        .overlay(Rectangle().stroke(glow ? YoseColor.kinBright : YoseColor.kiDark, lineWidth: glow ? 2.5 : 1))
        .fixedSize()
        .accessibilityLabel("仕上がり \(NetaStage.names[idx])")
        .onAppear { check(idx) }
        .onChange(of: idx) { _, n in check(n) }
    }

    private func check(_ idx: Int) {
        let prev = NetaStage.lastSeen[netaID]
        NetaStage.lastSeen[netaID] = idx
        guard let prev, idx > prev else { return }
        withAnimation(.easeOut(duration: 0.2)) { glow = true }
        Task { try? await Task.sleep(nanoseconds: 900_000_000); withAnimation(.easeIn(duration: 0.5)) { glow = false } }
    }
}
