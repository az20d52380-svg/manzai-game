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

    // 経験点通貨5種の色（正典v3・能力色と意図的に別系統＝「同じ色じゃない」ことが一目で分かる配色。全て【仮】）
    static let curHirameki = Color(hex: 0xFFB100)    // 閃き（金・ひらめきの光）
    static let curGoi = Color(hex: 0x2BB3A3)         // 語彙（青緑・知の落ち着き）
    static let curMaai = Color(hex: 0x8B6FCE)        // 間合い（紫・間とテンポ）
    static let curSonzaikan = Color(hex: 0xE0567C)   // 存在感（マゼンタ・華やぎ）
    static let curTanryoku = Color(hex: 0x3A4F7A)    // 胆力（濃紺・肚の据わり）

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

    /// 能力の1文字ラベル（色弱アクセシビリティ対応・オーナー指示2026-08-02）。
    /// 色だけで能力を区別させない＝色付きバッジの中に必ずこの文字を置く。
    static func abilityChar(_ a: Ability) -> String {
        switch a {
        case .センス: return "セ"
        case .発想: return "発"
        case .表現: return "表"
        case .華: return "華"
        case .メンタル: return "メ"
        }
    }

    /// 経験点通貨の色（正典v3・能力名と別立て＝パワプロの「筋力/敏捷/技術…」に相当）
    static func currencyColor(_ c: ExpCurrency) -> Color {
        switch c {
        case .閃き: return curHirameki
        case .語彙: return curGoi
        case .間合い: return curMaai
        case .存在感: return curSonzaikan
        case .胆力: return curTanryoku
        }
    }

    /// 通貨の1文字ラベル（色弱アクセシビリティ対応・能力バッジと同じ文法）
    static func currencyChar(_ c: ExpCurrency) -> String {
        switch c {
        case .閃き: return "閃"
        case .語彙: return "語"
        case .間合い: return "間"
        case .存在感: return "存"
        case .胆力: return "胆"
        }
    }

    /// 能力値→ランク文字。パワプロと同じ G→S のフルラダー（オーナー指示 2026-08-02）＝
    /// 序盤は G から始まり、昇格の階段が多い（表示写像のみ・判定に無関係）。閾値は全て【仮】。
    static func rank(_ v: Double) -> String {
        switch v {
        case ..<15: return "G"
        case ..<25: return "F"
        case ..<35: return "E"
        case ..<45: return "D"
        case ..<55: return "C"
        case ..<70: return "B"
        case ..<90: return "A"
        default: return "S"
        }
    }

    /// 等級帯の境界（rank と同じ閾値。経済の abilityRankCostBands と共有＝動かさない）
    static let rankBounds: [Double] = [0, 15, 25, 35, 45, 55, 70, 90]

    /// いまの等級帯の中での進み具合 0..1（監査C-01）。1年目は能力が10→16前後で、0〜上限のバーだと
    /// 1割から動かず"伸び"が見えないため、バーは「次の等級まで」を描く。上の帯が無い S は cap までで測る。
    static func rankProgress(_ v: Double, cap: Double) -> Double {
        guard let i = rankBounds.lastIndex(where: { v >= $0 }) else { return 0 }
        let lo = rankBounds[i]
        let hi = i + 1 < rankBounds.count ? rankBounds[i + 1] : max(cap, lo + 1)
        return min(1, max(0, (v - lo) / (hi - lo)))
    }

    /// 等級バッジの色（パワプロの G..S 配色に寄せた8段【仮】: G灰/F青灰/E青/D橙/C黄緑/B緑/A赤/S金）
    static func gradeColor(_ g: String) -> Color {
        switch g {
        case "S": return gold
        case "A": return verm
        case "B": return cMental
        case "C": return Color(hex: 0x9BC53D)
        case "D": return cExpr
        case "E": return cSense
        case "F": return Color(hex: 0x7A93B8)
        default: return Color(hex: 0x9AA0AE)
        }
    }

    /// ネタの型→色（v2 §2-1・7型を視覚的に書き分けるだけの表示専用トークン。判定には無関係）
    static func kataColor(_ k: NetaKata) -> Color {
        switch k {
        case .王道しゃべくり: return cSense
        case .関係性: return cChara
        case .伏線回収: return cIdea
        case .リターン: return cMental
        case .非定型: return verm
        case .瞬発: return gainOrange
        case .華先行: return goldD
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

/// 丸ゴシック（見出し・数字）＝ゲームフォント M PLUS Rounded 1c（OFL・FontLoader が起動時登録）。
/// 未登録/失敗時は system 丸ゴにフォールバック（見た目が劣化するだけで壊れない）。
extension Font {
    static func maru(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        guard FontLoader.isAvailable else {
            return .system(size: size, weight: weight, design: .rounded)
        }
        let name: String
        switch weight {
        case .black: name = "RoundedMplus1c-Black"
        case .heavy: name = "RoundedMplus1c-ExtraBold"
        case .bold, .semibold: name = "RoundedMplus1c-Bold"
        default: name = "RoundedMplus1c-Medium"
        }
        return .custom(name, size: size)
    }
}

/// 押下共通の沈み（§3-1）: scale 0.95+明度−10%・押下tPress easeOut／復帰spring(0.25, 0.6)。
/// ⑮: 実機で「押した瞬間が弱い」の報告を受け 0.97/−6% → 0.95/−10% に強化【仮・実機で微調整可】。
/// enabled=false は「沈まない」＝押せないことを触感で言う（グレー表示＋横ブレは呼び出し側）。
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.95
    var enabled: Bool = true
    var silent: Bool = false   // 個別に大きいSEを鳴らすボタンは true（二重鳴り防止）
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && enabled
        configuration.label
            .scaleEffect(pressed ? scale : 1)
            .brightness(pressed ? -0.10 : 0)
            .animation(pressed ? .easeOut(duration: Theme.Motion.press)
                               : .spring(response: 0.25, dampingFraction: 0.6),
                       value: pressed)
            .onChange(of: pressed) { _, now in
                // 商用最低ライン「全タップに音」（sellable_basics_research §4）。押下の瞬間に軽いクリック。
                if now && !silent { Sound.play(.cursor) }
            }
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

/// 能力の色付きバッジ（色弱アクセシビリティ対応・オーナー指示2026-08-02）。
/// 色の丸ドットだけで能力を区別させない＝必ず1文字ラベル（Theme.abilityChar）を併記する。
/// パワプロのステータス表が色でなく「弾道／ミート／パワー」等の文字見出しで区別しているのに倣う。
struct AbilityBadge: View {
    let ability: Ability
    var size: CGFloat = 16
    var body: some View {
        Text(Theme.abilityChar(ability))
            .font(.maru(size * 0.56, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Theme.abilityColor(ability), in: Circle())
    }
}

/// 経験点通貨の色付きバッジ（AbilityBadge と同型・正典v3。色弱アクセシビリティ対応で文字を併記）。
struct CurrencyBadge: View {
    let currency: ExpCurrency
    var size: CGFloat = 16
    var body: some View {
        Text(Theme.currencyChar(currency))
            .font(.maru(size * 0.56, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Theme.currencyColor(currency), in: RoundedRectangle(cornerRadius: size * 0.28))
    }
}

// MARK: 見た目の作り直し v1 のトークン（正本 docs/visual_genre_overhaul_v1.md §4-1・§4-2・§4-4。全て【仮】）
// 画面は3つの照明状態のどれかに属する：楽屋（昼・紙）／夕景（回想・夜の日常）／舞台（本番）。
// 暗い側は暖色（R＞G＞B）に固定＝紫を使わない（R2-03）。文字は20pt未満を4.5:1以上（K3）。

extension Theme {
    // --- 楽屋（昼）: 週メインのクリーム3色版（bgGradient）＋白カード＋太縁＋ハード影 ---
    /// 補助文字（白 6.46:1・bg2 5.37:1）。inkDim/inkFaint は文字に使わない（罫線・無効面だけ）
    static let inkSub = Color(hex: 0x625A78)
    /// 3:1 以上が要る縁（選択肢カード・入力欄・体力減チップの縁）
    static let lineStrong = Color(hex: 0x9C8E7A)
    /// 紙（講評・地の文・めくり以外の読み物）
    static let paperTop = Color(hex: 0xFDFBF4)
    static let paperBottom = Color(hex: 0xF6EEDC)
    static let paperEdge = Color(hex: 0xE6D9BE)
    static let paperInk = Color(hex: 0x33301F)
    /// 紙の上の署名・見出し（7.2:1・旧 A98B52 2.8:1 の置き換え）
    static let sealName = Color(hex: 0x6E5020)
    /// めくり札の白紙と墨
    static let mekuri = Color(hex: 0xFFFDF6)
    static let sumi = Color(hex: 0x1E1A2B)
    /// 話者の色（俺＝青・谷口＝朱）。名前札の地は濃い版（白字 4.5:1 以上）
    static let cOre = Color(hex: 0x4A7BE8)
    static let cOreDeep = Color(hex: 0x3566D6)
    static let cTaniguchi = Color(hex: 0xF0533E)
    /// 金の面の上の字
    static let onGold = Color(hex: 0x5A3A06)

    // --- 色相ごとの濃い版（Deep）: 色付きの小さい文字・白字を載せる塗りの両方に使える（白地 5.5:1 以上） ---
    static let senseDeep = Color(hex: 0x1F63D1)
    static let ideaDeep = Color(hex: 0x6A3FD9)
    static let exprDeep = Color(hex: 0xB04400)
    static let charaDeep = Color(hex: 0xC21F5B)
    static let mentalDeep = Color(hex: 0x147650)
    static let moneyDeep = Color(hex: 0x2A7447)
    static let goldDeep = Color(hex: 0x845F00)

    static func abilityDeep(_ a: Ability) -> Color {
        switch a {
        case .センス: return senseDeep
        case .発想: return ideaDeep
        case .表現: return exprDeep
        case .華: return charaDeep
        case .メンタル: return mentalDeep
        }
    }

    // --- 夕景（回想・帰り道・夜の日常）: 明るい暖色のグラデ。黒にしない ---
    static let duskNoon = [Color(hex: 0xFFF7EC), Color(hex: 0xFFE9B8)]                       // 昼（平均L 約0.85）
    static let duskAfter = [Color(hex: 0xFFD9A8), Color(hex: 0xF7A878), Color(hex: 0xE98A6A)] // 放課後（約0.5）
    static let duskEve = [Color(hex: 0xF2A27A), Color(hex: 0xC98A9A), Color(hex: 0x8F86C0)]   // 宵（約0.35・藍へ寄せるが黒にしない）
    /// 逆光の人物の縁
    static let rimGold = gold

    // --- 舞台（本番）: 暖色の客席に光る舞台。暗いのは客席だけ ---
    /// 客席の闇（暖黒・純黒禁止）。旧 B2 案の 140D18 は紫寄りなので採らない
    static let house = Color(hex: 0x1A100C)
    /// 一文字幕・袖幕・緞帳（臙脂）
    static let curtain = Color(hex: 0x5B1A12)
    static let curtainLit = Color(hex: 0x8E2A1C)
    static let curtainShade = Color(hex: 0x3A0F0B)
    /// 光の芯（house 比 17:1）と、その外の金→朱
    static let spotCore = Color(hex: 0xFFF3D6)
    static let spotMid = gold.opacity(0.55)
    static let spotEdge = verm.opacity(0.20)
    /// 舞台板（スポットの下だけ明るい）
    static let boardsLit = Color(hex: 0xC8935A)
    static let boardsDark = Color(hex: 0x4A3020)
    /// 光を返す金の面（金屏風）。採点中は暗い2段、最明部は自組の優勝の瞬間だけ
    static let goldLeafLo = Color(hex: 0x6E5426)
    static let goldLeafMid = Color(hex: 0xA07E36)
    static let goldLeafHi = Color(hex: 0xD9B45A)
    /// 客電の粒・笑った客席の縁
    static let houseLight = Color(hex: 0xFFE3A0)
    /// 下三分テロップの地（暖黒）
    static let lowerThird = Color(hex: 0x241712)
    /// 大会の格の金属色（道中＝銅／GP予選〜準決・客席から＝銀／GP決勝＝金）
    static let bronze = Color(hex: 0xC07A43)
    static let silver = Color(hex: 0xC9CED6)
}

/// 文字の段（K2）: display 34 Black／title 20 ExtraBold／body 17／sub 13 Bold。1画面で3段まで。12pt 未満は使わない。
/// 第1便は固定 pt（Dynamic Type 追従は第2便）。body は台詞＝Bold・地の文＝Medium。
enum TypeStep {
    case display, title, body, bodyMedium, sub
    var size: CGFloat {
        switch self {
        case .display: return 34
        case .title: return 20
        case .body, .bodyMedium: return 17
        case .sub: return 13
        }
    }
    var weight: Font.Weight {
        switch self {
        case .display: return .black
        case .title: return .heavy
        case .body, .sub: return .bold
        case .bodyMedium: return .medium
        }
    }
    /// 行送りの足し分（body は約1.65倍）
    var lineSpacing: CGFloat {
        switch self {
        case .body, .bodyMedium: return 10
        case .sub: return 4
        default: return 2
        }
    }
}

extension Font {
    static func maru(_ step: TypeStep) -> Font { .maru(step.size, weight: step.weight) }
}

extension View {
    /// 週メインのチャンキーな面のハード影（真下・ぼかし0）
    func hardShadow(_ y: CGFloat = 3) -> some View { shadow(color: Theme.cmdShadow, radius: 0, y: y) }
}
