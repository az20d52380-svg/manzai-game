// Theme.swift
// 見た目の正典 docs/ui_mockup_pawapuro_v2.html の配色・能力色・ランクをSwiftに写す。
// パワプロ サクセス風: クリーム/朱/金の暖色・丸ゴシック・ポップ。全て【仮】。

import SwiftUI
import UIKit
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

    // v8育成メイン用パレット（全て【仮】）
    static let gainOrange = Color(hex: 0xFF8A1E)              // 実行時の「+N」オレンジ
    static let night = Color(hex: 0x3D5A80)                   // 回復カードのドット地色
    static let pillDark = Color(hex: 0x241C33, alpha: 0.82)   // 立ち絵上のダークピル/戻る/トースト地色
    static let botbarDark = Color(hex: 0x2A2440)              // 最下部の帯（年週/大会まで/体力/所持金）
    static let staminaWarn = Color(hex: 0xF2A93B)             // 体力ゲージ 警告（<50・黄）
    static let staminaCrit = Color(hex: 0xE8402C)             // 体力ゲージ 危険（<20・赤＝staminaGate可視化）

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

// MARK: §3-0 追加デザイントークン（正典: docs/uiux_vision_reply_part1_v0.md §3-0。全て【仮】）

extension Theme {
    /// Space: 4pt格子
    enum Sp {
        static let s4: CGFloat = 4
        static let s8: CGFloat = 8
        static let s12: CGFloat = 12
        static let s16: CGFloat = 16
        static let s24: CGFloat = 24
        static let s32: CGFloat = 32
    }

    /// Radius: rPill=カプセル（Capsuleで表現）／card=16／btn=12／board=12／sheet=24／stamp=4（角判）
    enum Rad {
        static let card: CGFloat = 16
        static let btn: CGFloat = 12
        static let board: CGFloat = 12
        static let sheet: CGFloat = 24
        static let stamp: CGFloat = 4
    }

    /// Motion 5段。方向規則: 出現=キツ入り緩抜け(easeOut)／退場=緩入りキツ抜け(easeIn)／強調=spring
    enum Motion {
        static let press: Double = 0.08
        static let quick: Double = 0.18
        static let std: Double = 0.25
        static let emph: Double = 0.40
        static let hold: Double = 0.60
        static var appear: Animation { .easeOut(duration: std) }
        static var appearQuick: Animation { .easeOut(duration: quick) }
        static var exit: Animation { .easeIn(duration: quick) }
        static var emphSpring: Animation { .spring(response: 0.4, dampingFraction: 0.75) }
    }
}

/// Elevation e1〜e3。影は常にink系（純黒禁止＝紙の温かみ）。
struct InkShadow: ViewModifier {
    let level: Int
    func body(content: Content) -> some View {
        switch level {
        case 1: content.shadow(color: Theme.ink.opacity(0.08), radius: 3, y: 1)   // 浮き紙・吹き出し
        case 2: content.shadow(color: Theme.ink.opacity(0.10), radius: 10, y: 3)  // カード・ボタン
        default: content.shadow(color: Theme.ink.opacity(0.16), radius: 24, y: 8) // シート・決勝ボード
        }
    }
}

extension View {
    func e1() -> some View { modifier(InkShadow(level: 1)) }
    func e2() -> some View { modifier(InkShadow(level: 2)) }
    func e3() -> some View { modifier(InkShadow(level: 3)) }
}

/// Haptics 3段（閲覧操作は常に無振動＝カテゴリ開閉・戻る・スクロールには付けない）。
enum Haptics {
    /// 実行（=週送り）のみ
    static func tick() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    /// 合否押印・籤の自組コール
    static func confirm() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    /// 優勝確定・SSR級のみ
    static func rare() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
}

/// 丸ゴシック（見出し・数字）。無ければsystem丸フォールバック。
extension Font {
    static func maru(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// 押下共通の沈み（§3-1）: scale 0.97+明度−6%・押下tPress easeOut／復帰spring(0.25, 0.6)。
/// enabled=false は「沈まない」＝押せないことを触感で言う（グレー表示＋横ブレは呼び出し側）。
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    var enabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && enabled
        configuration.label
            .scaleEffect(pressed ? scale : 1)
            .brightness(pressed ? -0.06 : 0)
            .animation(pressed ? .easeOut(duration: Theme.Motion.press)
                               : .spring(response: 0.25, dampingFraction: 0.6),
                       value: pressed)
    }
}

/// 実行不可タップの横ブレ（§3-1）: ±3ptを2往復・0.15s。trigger を +1 すると1回震える。
struct ShakeEffect: GeometryEffect {
    var travel: CGFloat = 3
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: travel * sin(animatableData * .pi * 4), y: 0))
    }
}
