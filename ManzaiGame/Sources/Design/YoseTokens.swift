// YoseTokens.swift
// デザインシステム『寄席と計器』v2.0（docs/design_system_argon_v1.md §2〜§4）の色・文字・形の数値を1か所に集約。
// Color(hex:) は Theme.swift の既存定義を使う。既存 Theme.* とは別名で併存（互換のため触らない）。

import SwiftUI

enum YoseColor {
    static let enji = Color(hex: 0x7D221E)
    static let shu = Color(hex: 0xBD3C28)
    static let kinari = Color(hex: 0xF5F0E1)
    static let washi = Color(hex: 0xFBF8F1)
    static let ki = Color(hex: 0xE2D3B3)
    static let kiDark = Color(hex: 0xC8B692)
    static let sumi = Color(hex: 0x2B2B2B)
    static let kuroUrushi = Color(hex: 0x1E1916)
    static let haiSumi = Color(hex: 0x6E685F)
    static let kin = Color(hex: 0xC1A550)
    static let kinBright = Color(hex: 0xE5B842)
    static let tokiwa = Color(hex: 0x2E583C)
    static let ginNezu = Color(hex: 0xD4CFC4)
    static let disabledText = Color(hex: 0x8C867B)
    static let washiFeatured = Color(hex: 0xFFFDF7)
    static let kinText = Color(hex: 0x7A6218)   // 「自信作」タグ等の濃い金文字

    // 経験点5色（閃・語・間・存・胆）
    static let expSen = Color(hex: 0xD49A2A)
    static let expGo = Color(hex: 0x2A6E58)
    static let expMa = Color(hex: 0x5A3E7A)
    static let expSon = Color(hex: 0xB53D2A)
    static let expTan = Color(hex: 0x2B547E)
}

enum YoseFont {
    static func mincho(_ size: CGFloat) -> Font { .custom("HiraMinProN-W6", fixedSize: Font.mzScaled(size)) }
    static func gothic(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: Font.mzScaled(size), weight: weight, design: .default)
    }
    static func number(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: Font.mzScaled(size), weight: weight, design: .default).monospacedDigit()
    }
    // 役割トークン（§3 サイズ段階）
    static let bannerTitle = gothic(26, weight: .black)
    static let headerTitle = gothic(20, weight: .heavy)
    static let netaTitle = mincho(20)
    static let sectionTitle = gothic(17, weight: .heavy)
    static let buttonMain = gothic(16, weight: .heavy)
    static let dialogueBody = mincho(15)
    static let bodyBold = gothic(14, weight: .bold)
    static let captionBold = gothic(11, weight: .bold)
    static let numHero = number(32, weight: .black)
    static let numLarge = number(22, weight: .heavy)
    static let numMedium = number(16, weight: .heavy)
}

/// §4 形の数値（393×852pt 基準）
enum YoseMetrics {
    static let screenMargin: CGFloat = 14
    static let radius: CGFloat = 2          // 木札・貼り紙・ボタン
    static let borderMain: CGFloat = 2      // 基本枠
    static let borderSub: CGFloat = 1.5
    static let borderHair: CGFloat = 1
    static let shadowCard: CGFloat = 2      // y:2 ブラー0
    static let shadowCommand: CGFloat = 3
    static let gridGap: CGFloat = 10
    static let listGap: CGFloat = 8
    static let padV: CGFloat = 10
    static let padH: CGFloat = 12
}

/// 袋文字（ハード縁取り＋ソリッド下影）
struct YoseOutlinedText: View {
    let text: String
    var font: Font = YoseFont.bannerTitle
    var fill: Color = YoseColor.kinari
    var outlineColor: Color = YoseColor.sumi
    var outlineWidth: CGFloat = 1.5
    var dropShadowY: CGFloat = 2

    var body: some View {
        ZStack {
            ForEach([-1, 0, 1], id: \.self) { dx in
                ForEach([-1, 0, 1], id: \.self) { dy in
                    if dx != 0 || dy != 0 {
                        Text(text).font(font).foregroundStyle(outlineColor)
                            .offset(x: CGFloat(dx) * outlineWidth, y: CGFloat(dy) * outlineWidth)
                    }
                }
            }
            Text(text).font(font).foregroundStyle(fill)
        }
        .compositingGroup()
        .shadow(color: outlineColor, radius: 0, x: 0, y: dropShadowY)
    }
}
