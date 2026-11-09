// TalkParts.swift
// 会話・読み物・選択の共通部品（見た目の作り直し v1・docs/visual_genre_overhaul_v1.md §4-4）。
// 週メインの語彙（白地＋太縁＋ハード影・顔グラ＋色カプセルの名前札・▼）を、イベント・イントロ・大会など全画面へ広げる。
// View層のみ・golden非干渉。文字は TypeStep の段（K2）、色は Theme の v1 トークン（K3: 20pt未満は4.5:1以上）。

import SwiftUI

// MARK: 話者（名前→顔・名前札の色）

enum SpeakerStyle {
    /// 名前札の地（白字が4.5:1以上になる濃い版）。俺＝青・谷口＝朱・その他＝補助色
    static func tagColor(_ name: String?) -> Color {
        switch name {
        case "谷口": return Theme.vermD
        case nil, "俺": return Theme.cOreDeep
        case FinalsMC.name: return Color(hex: 0x23202B)   // 司会＝黒（白字 16:1）
        default: return Theme.inkSub
        }
    }
}

/// 送りの合図 ▼（話者色・小さく上下に弾む。演出ひかえめでは止まる）
struct AdvanceCue: View {
    var color: Color = Theme.inkSub
    @State private var bob = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Image(systemName: "arrowtriangle.down.fill").accessibilityHidden(true)
            .font(.system(size: Font.mzScaled(11), weight: .bold)).foregroundStyle(color)   // 12pt 未満の例外：三角アイコン（文字ではない）
            .offset(y: bob ? 2.5 : 0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(Theme.Motion.r(.easeInOut(duration: 0.55).repeatForever(autoreverses: true))) { bob = true }
            }
            .accessibilityHidden(true)
    }
}

// MARK: 吹き出し（物語用＝イベント・イントロ・大会）

// MARK: 地の文の紙

/// 地の文を載せる紙。段落の \n は保持して1枚に出す（文の途中で差し替えない・X2-25/X3-05）。本文は body 17 Medium。
struct NarrationCard: View {
    let text: String
    var showCue: Bool = false
    var body: some View {
        Text(text)
            .font(.maru(.bodyMedium)).lineSpacing(TypeStep.bodyMedium.lineSpacing)
            .foregroundStyle(Theme.paperInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 22).padding(.trailing, 20).padding(.vertical, 16)
            .background(LinearGradient(colors: [Theme.paperTop, Theme.paperBottom], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .leading) {
                // 紙の左の金の綴じ（読み物の印）
                RoundedRectangle(cornerRadius: 2).fill(Theme.gold).frame(width: 4).padding(.vertical, 12)
            }
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.paperEdge, lineWidth: 1))
            .shadow(color: Theme.ink.opacity(0.08), radius: 3, y: 1)
            .overlay(alignment: .bottomTrailing) {
                if showCue { AdvanceCue(color: Theme.goldDeep).padding(10) }
            }
    }
}

// MARK: 選択肢カード

// MARK: 獲得チップ
