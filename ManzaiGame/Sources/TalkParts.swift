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
        default: return Theme.inkSub
        }
    }
}

/// 色カプセルの名前札（白字・sub 13）
struct NameTag: View {
    let name: String
    var body: some View {
        Text(name).font(.maru(.sub)).foregroundStyle(.white)
            .padding(.horizontal, 9).padding(.vertical, 2)
            .background(SpeakerStyle.tagColor(name), in: Capsule())
            .overlay(Capsule().stroke(.white, lineWidth: 2))
            .fixedSize()
    }
}

/// 送りの合図 ▼（話者色・小さく上下に弾む。演出ひかえめでは止まる）
struct AdvanceCue: View {
    var color: Color = Theme.inkSub
    @State private var bob = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Image(systemName: "arrowtriangle.down.fill")
            .font(.system(size: 11, weight: .bold)).foregroundStyle(color)
            .offset(y: bob ? 2.5 : 0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) { bob = true }
            }
            .accessibilityHidden(true)
    }
}

// MARK: 吹き出し（物語用＝イベント・イントロ・大会）

/// 顔グラを吹き出しの左上にかぶせ、本文幅を守る（1行18〜20字・X3-04）。本文は body 17 Bold。
struct TalkBubble: View {
    let advice: Advice
    var showCue: Bool = false
    var faceSize: CGFloat = 54
    /// 決め台詞（回想の「コンビ、組まへんか」など1回きりの台詞）は title 段より大きい22pt
    var large: Bool = false

    private var name: String { advice.name ?? "俺" }

    var body: some View {
        Text(advice.text)
            .font(large ? .maru(22, weight: .heavy) : .maru(.body)).lineSpacing(TypeStep.body.lineSpacing)
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 18).padding(.trailing, 26)
            .padding(.top, faceSize * 0.5 + 6).padding(.bottom, 16)
            .background(.white, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 2.5))
            .hardShadow()
            .overlay(alignment: .bottomTrailing) {
                if showCue { AdvanceCue(color: SpeakerStyle.tagColor(advice.name)).padding(10) }
            }
            .overlay(alignment: .topLeading) {
                HStack(alignment: .bottom, spacing: 6) {
                    CharacterFace(spec: FaceCatalog.speaker(name), size: faceSize)
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                        .shadow(color: Theme.ink.opacity(0.2), radius: 0, y: 2)
                    NameTag(name: name).padding(.bottom, 4)
                }
                .offset(x: 10, y: -faceSize * 0.5)
            }
            .padding(.top, faceSize * 0.5)   // かぶせた顔の分だけ上に余白
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(name)、\(advice.text)")
    }
}

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

/// 行動カードと同じ面（白＋3pt縁＋ハード影）・高さ56pt以上・押すと沈んで鳴る（PressableStyle）。
struct ChoiceCard: View {
    let label: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).font(.maru(.body)).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 56)
                .padding(.horizontal, 14)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.verm.opacity(0.85), lineWidth: 3))
                .hardShadow()
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: 獲得チップ

/// 伸びた（gain）＝濃い版の塗りに白字／減った（loss）＝白地＋lineStrong 縁＋inkSub 字（祝わない）。
struct GainChip: View {
    enum Kind { case gain(Color), loss }
    let text: String
    let kind: Kind
    var body: some View {
        Text(text).font(.maru(17, weight: .heavy))
            .foregroundStyle(fg)
            .padding(.horizontal, 13).padding(.vertical, 6)
            .background(bg, in: Capsule())
            .overlay(Capsule().stroke(stroke, lineWidth: 2))
            .shadow(color: Theme.ink.opacity(0.22), radius: 0, y: 3)
            .fixedSize()
    }
    private var fg: Color { if case .gain = kind { return .white } else { return Theme.inkSub } }
    private var bg: Color { if case .gain(let c) = kind { return c } else { return .white } }
    private var stroke: Color { if case .gain = kind { return .white } else { return Theme.lineStrong } }
}
