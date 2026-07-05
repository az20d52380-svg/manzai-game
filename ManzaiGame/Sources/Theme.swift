// Theme.swift
// 見た目の正典 docs/ui_mockup_pawapuro_v2.html の配色・能力色・ランクをSwiftに写す。
// パワプロ サクセス風: クリーム/朱/金の暖色・丸ゴシック・ポップ。全て【仮】。

import SwiftUI
import GameCore

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

enum Theme {
    // 背景・地色
    static let bg1 = Color(hex: 0xFFF4E6)
    static let bg2 = Color(hex: 0xFFE6CF)
    static let bgTop = Color(hex: 0xFFF7EC)
    static let bgBottom = Color(hex: 0xFFDDBE)
    static let card = Color.white
    static let card2 = Color(hex: 0xFFF9F0)
    static let line = Color(hex: 0xF1E6D6)
    static let cmdShadow = Color(hex: 0xEADFCF)

    // 文字
    static let ink = Color(hex: 0x2C2740)
    static let inkDim = Color(hex: 0x8E86A0)
    static let inkFaint = Color(hex: 0xB9B2C6)

    // アクセント
    static let verm = Color(hex: 0xE8402C)     // 朱（谷口の枠・つぎへ・相性）
    static let vermD = Color(hex: 0xC22E1D)
    static let gold = Color(hex: 0xF6B301)
    static let goldD = Color(hex: 0xE09A00)

    // 能力色（mockup準拠）
    static let cSense = Color(hex: 0x3B8BFF)   // センス
    static let cIdea = Color(hex: 0x8B5CF6)    // 発想
    static let cExpr = Color(hex: 0xFF7A2F)    // 表現
    static let cChara = Color(hex: 0xFF5C93)   // 華
    static let cMental = Color(hex: 0x22B07A)  // メンタル
    static let cCompat = Color(hex: 0xE8402C)  // 相性
    static let cMoney = Color(hex: 0x77CC99)   // お金（バイト等）

    static let bgGradient = LinearGradient(
        colors: [bgTop, bg2, bgBottom],
        startPoint: .top, endPoint: .bottom)

    static func abilityColor(_ a: Ability) -> Color {
        switch a {
        case .センス: return cSense
        case .発想: return cIdea
        case .表現: return cExpr
        case .華: return cChara
        case .メンタル: return cMental
        }
    }

    /// 能力値→ランク文字（mockup: 29→D, 41→C, 52→B）
    static func rank(_ v: Double) -> String {
        switch v {
        case ..<30: return "D"
        case ..<45: return "C"
        case ..<60: return "B"
        case ..<80: return "A"
        default: return "S"
        }
    }
}

/// 丸ゴシック（見出し・数字）。無ければsystem丸フォールバック。
extension Font {
    static func maru(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
