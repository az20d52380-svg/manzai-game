# 漫才コンビ育成ゲーム デザインシステム『寄席と計器（Yose & Gauge）』v2.0

パワプロ（サクセス）の「1タップごとに数字が跳ねる計器の快感」と、上方演芸・寄席の「木札・和紙・朱印・定式幕の泥臭い熱量」を融合させた、iOS（SwiftUI / 393×852pt）専用の完全デザインシステムです。
外部画像アセットに頼らず、SwiftUIの図形描画と標準フォントだけで「商業ゲームの手触り」を実現するため、すべての寸法・色・枠・動きを厳格に規定します。

---

## 1. 世界観のひと言とトーン

* **世界観のひと言**：「**楽屋の貼り紙と、舞台袖の熱気**」
* **トーン＆マナー**：
  * **「浮遊するWebカード」ではなく「打ち付けられた木札と貼り紙」**：ぼかし影（Blur）や丸いカプセル（Capsule）を全廃し、2ptの墨枠とソリッドなハードシャドウ（Blur 0）で「物質の厚みと重さ」を作る。
  * **「情緒は明朝、計器は太ゴシック」**：漫才のネタ名や相方・審査員の生きた言葉には「明朝体」の情緒を宿し、実力・お金・消費ポイントなどのゲーム数値には「太ゴシック＋等幅数字」の攻略計器としての視認性を徹底する。
  * **「高密度・高コントラスト」**：画面に無意味な余白を作らず、生成り（和紙）と墨（黒枠）と朱（強調）の強いコントラストで、触る前から「押したら気持ちよさそう」と感じさせる。

---

## 2. 色トークン（Color Tokens）

**※ダークモードは非対応（`.preferredColorScheme(.light)` で常時固定）。**
寄席の白熱電球の下で見る「生成りの和紙」と「黒漆・墨」の世界観を保つため、OSのダークモードによる色反転は行いません。

| トークン名 | 名前 | HEX | 使い所 |
| :--- | :--- | :--- | :--- |
| `yoseEnji` | **臙脂（えんじ）** | `#7D221E` | ヘッダー帯、舞台幕の主色、最重要エリアの背景 |
| `yoseShu` | **朱（しゅ）** | `#BD3C28` | 主ボタン（確定・勝負ネタにする・＋ボタン）、判子（朱印）、上昇プレビュー |
| `yoseKinari` | **生成り（きなり）** | `#F5F0E1` | 画面全体の基本背景（和紙の地色）、反転文字色 |
| `yoseWashi` | **白和紙（しろわし）** | `#FBF8F1` | 貼り紙カード・リスト行・吹き出しの面背景（生成りより一段明るい） |
| `yoseKi` | **木札（きふだ）** | `#E2D3B3` | ステータス木札、所持ポイント見出し箱、タブ背景の面色 |
| `yoseKiDark` | **古木（こぼく）** | `#C8B692` | 木札の内枠、区切り線、非選択タブの背景 |
| `yoseSumi` | **墨（すみ）** | `#2B2B2B` | すべての枠線（2pt）、ハードシャドウ、基本本文・数値の文字色 |
| `yoseKuroUrushi` | **黒漆（くろうるし）** | `#1E1916` | ステータス黒帯（体力・所持金バー）、大会看板の背景 |
| `yoseHaiSumi` | **灰墨（はいずみ）** | `#6E685F` | 補助ラベル（「通過基準」「舞台回数」など）、サブテキスト |
| `yoseKin` | **消金（けしぎん）** | `#C1A550` | 飾り罫線、Sランク、優勝額縁、ヘッダー文字、賞金テキスト |
| `yoseKinBright` | **山吹金（やまぶき）** | `#E5B842` | ゲージ発光、星・閃きポイント、最高評価のハイライト |
| `yoseTokiwa` | **常磐緑（ときわ）** | `#2E583C` | 体力ゲージ、回復テキスト、安全圏インジケーター |
| `yoseGinNezu` | **銀鼠（ぎんねず）** | `#D4CFC4` | 押せないボタンの面背景、空ゲージの背景 |
| `yoseDisabledText`| **鈍色（にびいろ）** | `#8C867B` | 押せないボタンの文字色、未解放テキスト |
| **経験点5色** | **閃 / 語 / 間 / 存 / 胆** | `#D49A2A` / `#2A6E58` / `#5A3E7A` / `#B53D2A` / `#2B547E` | 能力アップ画面の5大経験点オーブ専用色 |

### SwiftUI Color 定義コード

```swift
import SwiftUI

public enum YoseColor {
    public static let enji = Color(hex: 0x7D221E)
    public static let shu = Color(hex: 0xBD3C28)
    public static let kinari = Color(hex: 0xF5F0E1)
    public static let washi = Color(hex: 0xFBF8F1)
    public static let ki = Color(hex: 0xE2D3B3)
    public static let kiDark = Color(hex: 0xC8B692)
    public static let sumi = Color(hex: 0x2B2B2B)
    public static let kuroUrushi = Color(hex: 0x1E1916)
    public static let haiSumi = Color(hex: 0x6E685F)
    public static let kin = Color(hex: 0xC1A550)
    public static let kinBright = Color(hex: 0xE5B842)
    public static let tokiwa = Color(hex: 0x2E583C)
    public static let ginNezu = Color(hex: 0xD4CFC4)
    public static let disabledText = Color(hex: 0x8C867B)

    // 経験点5種（閃・語・間・存・胆）
    public static let expSen = Color(hex: 0xD49A2A)
    public static let expGo  = Color(hex: 0x2A6E58)
    public static let expMa  = Color(hex: 0x5A3E7A)
    public static let expSon = Color(hex: 0xB53D2A)
    public static let expTan = Color(hex: 0x2B547E)
}

public extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
```

---

## 3. 文字（Typography）

### 書体の使い分けルール（3書体制）
1. **明朝体（`Hiragino Mincho ProN` / `.serif`）**：「**演芸の情緒と肉声**」に限定して使う。
   * 使い所：ネタの題名（『商店街の福引』）、相方のセリフ、審査員の講評本文、大会の煽り文句（「どっと沸いた！！」）。
   * **禁止**：ボタンのラベルや数値、画面タイトルには絶対に使わない（線が細くゲームの手応えが消えるため）。
2. **角ゴシック体（システム標準 / `Hiragino Sans` Bold〜Heavy）**：「**ゲームの骨格と操作**」に使う。
   * 使い所：ヘッダー見出し、すべてのボタン名、能力名、タグ、判子、ラベル。
3. **計器ナンバー（`.system(..., design: .default).monospacedDigit()` Heavy/Black）**：「**攻略の数字**」に使う。
   * 使い所：実力、金額、完成度、消費ポイント、週数。必ず `.monospacedDigit()` を付け、カウントアップ時に横揺れさせない。
   * **丸ゴシック（`.rounded`）の扱い**：数値やボタンに丸ゴシックを使うと幼児向け知育アプリに見えるため**原則禁止**。唯一、相方の親しみやすい小セリフ補足にのみ許可。

### サイズ段階・行間・字間・縁取り一覧

| 役割 | トークン名 | 書体 / ウェイト | サイズ | 行間 (`lineSpacing`) | 字間 (`tracking`) | 装飾・縁取り |
| :--- | :--- | :--- | :---: | :---: | :---: | :--- |
| **大看板・番付** | `bannerTitle` | 角ゴ / `.black` | `26pt` | `2pt` | `-0.5pt` | 墨の袋文字（8方向1.5pt縁取り）＋下影2pt |
| **ヘッダー題名** | `headerTitle` | 角ゴ / `.heavy` | `20pt` | `0pt` | `1.0pt` | 色：`yoseKin`、下影 `yoseKuroUrushi` (y: 1.5pt) |
| **ネタ題名** | `netaTitle` | **明朝** (`W6`) | `20pt` | `4pt` | `0.5pt` | 色：`yoseSumi` |
| **セクション見出し** | `sectionTitle`| 角ゴ / `.heavy` | `17pt` | `2pt` | `0.5pt` | 下に2ptの墨線または左に朱の縦帯 |
| **ボタン主文字** | `buttonMain` | 角ゴ / `.heavy` | `16pt` | `0pt` | `0.5pt` | 主ボタンは白文字＋墨1pt下影 |
| **セリフ・講評** | `dialogueBody`| **明朝** (`W6`) | `15pt` | `6pt` | `0.2pt` | 最大3行。行間を広めにとり読ませる |
| **本文・項目名** | `bodyBold` | 角ゴ / `.bold` | `14pt` | `3pt` | `0pt` | 能力名、リスト項目名 |
| **ラベル・注記** | `captionBold` | 角ゴ / `.bold` | `11pt` | `1pt` | `0pt` | 「実力」「完成度」「通過基準」等の小見出し |
| **特大数値** | `numHero` | 標準数字 / `.black` | `32pt` | `0pt` | `-1.0pt` | `.monospacedDigit()`、実力合計・結果数値 |
| **大数値** | `numLarge` | 標準数字 / `.heavy` | `22pt` | `0pt` | `-0.5pt` | `.monospacedDigit()`、ネタ完成度・所持金 |
| **中数値** | `numMedium` | 標準数字 / `.heavy` | `16pt` | `0pt` | `0pt` | `.monospacedDigit()`、能力値・消費コスト |

### SwiftUI 文字＆縁取り実装コード

```swift
public enum YoseFont {
    public static func mincho(_ size: CGFloat) -> Font {
        .custom("HiraMinProN-W6", size: size)
    }
    public static func gothic(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    public static func number(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .default).monospacedDigit()
    }
}

/// パワプロ・寄席看板風の袋文字（ハード縁取り＋ソリッド下影）
public struct YoseOutlinedText: View {
    let text: String
    let font: Font
    let fill: Color
    var outlineColor: Color = YoseColor.sumi
    var outlineWidth: CGFloat = 1.5
    var dropShadowY: CGFloat = 2.0

    public var body: some View {
        ZStack {
            // 8方向オフセットによるソリッド縁取り
            ForEach([-1, 0, 1], id: \.self) { dx in
                ForEach([-1, 0, 1], id: \.self) { dy in
                    if dx != 0 || dy != 0 {
                        Text(text)
                            .font(font)
                            .foregroundStyle(outlineColor)
                            .offset(x: CGFloat(dx) * outlineWidth, y: CGFloat(dy) * outlineWidth)
                    }
                }
            }
            Text(text)
                .font(font)
                .foregroundStyle(fill)
        }
        .compositingGroup()
        .shadow(color: outlineColor, radius: 0, x: 0, y: dropShadowY)
    }
}
```

---

## 4. 形（Shapes & Layout Grid）

### 数値ルール（393×852pt 基準）
1. **画面左右マージン（外枠余白）**：**全画面 `14pt` に完全統一**（コンテンツ有効幅 `365pt`）。画面ごとに12pt/16pt/20ptとバラつくのを厳禁とする。
2. **角丸（Corner Radius）**：
   * **木札・貼り紙カード・ボタン**：すべて **`2pt`**（ほぼ直角だが、紙の角のわずかな丸みだけ残す）。
   * **小タグ・判子・ゲージ・看板**：**`0pt`（完全な直角）**。
   * **禁止**：`cornerRadius(8)` 以上および `Capsule()` は全画面で使用禁止。
3. **枠線（Border Stroke）**：
   * 基本カード・ボタン外枠：`yoseSumi`（`#2B2B2B`）の **`2.0pt`**。
   * 補助セル・内枠・区切り線：`1.5pt` または `1.0pt`。
4. **影（Hard Shadow）**：
   * **Blur（ぼかし）は常に `0pt`**。X軸オフセットは `0pt`。
   * カード・通常ボタン：`y: 2pt`（色：`yoseSumi`）。
   * 大ボタン・重要コマンド：`y: 3pt`（色：`yoseSumi`）。
   * 無効（Disabled）ボタン・押下中ボタン：`y: 0pt`（影なし＝地面に張り付いた状態）。
5. **要素間の余白（Spacing）**：
   * 2列コマンドグリッドの隙間：横 `10pt` × 縦 `10pt`。
   * リスト（ネタ帳・能力行）の縦間隔：`8pt`。
   * カード内パディング：上下 `10pt`、左右 `12pt`。

---

## 5. 部品カタログ（11種・仕様とSwiftUI完全コード）

### ① ヘッダー帯（`YoseHeaderBar`）
* **見た目の仕様**：高さ `48pt`（SafeArea上部まで臙脂を伸ばす）。背景は `yoseEnji`（`#7D221E`）、下辺に `yoseKin`（`2pt`）と `yoseSumi`（`2pt`）の二重線を引く。中央に金のタイトル文字（左右に金の飾り菱形と横線）。右端に「とじる」「戻る」を置く場合は、高さ `28pt` の金枠小木札ボタンを配置。全画面でこの1コンポーネントのみを使用する。

```swift
public struct YoseHeaderBar: View {
    let title: String
    var subtitle: String? = nil
    var closeAction: (() -> Void)? = nil

    public var body: some View {
        ZStack {
            YoseColor.enji
                .ignoresSafeArea(edges: .top)

            HStack(spacing: 8) {
                if closeAction != nil {
                    Spacer().frame(width: 64)
                }
                Spacer(minLength: 4)
                // 左飾り線
                HStack(spacing: 4) {
                    Rectangle().fill(YoseColor.kin.opacity(0.7)).frame(width: 28, height: 1.5)
                    Rectangle().fill(YoseColor.kin).frame(width: 5, height: 5).rotationEffect(.degrees(45))
                }
                VStack(spacing: 1) {
                    Text(title)
                        .font(YoseFont.gothic(19, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(YoseColor.kin)
                        .shadow(color: YoseColor.kuroUrushi, radius: 0, x: 0, y: 1.5)
                    if let subtitle {
                        Text(subtitle)
                            .font(YoseFont.gothic(10, weight: .bold))
                            .foregroundStyle(YoseColor.kinari.opacity(0.85))
                    }
                }
                // 右飾り線
                HStack(spacing: 4) {
                    Rectangle().fill(YoseColor.kin).frame(width: 5, height: 5).rotationEffect(.degrees(45))
                    Rectangle().fill(YoseColor.kin.opacity(0.7)).frame(width: 28, height: 1.5)
                }
                Spacer(minLength: 4)
                if let closeAction {
                    Button("とじる", action: closeAction)
                        .font(YoseFont.gothic(12, weight: .heavy))
                        .foregroundStyle(YoseColor.kinari)
                        .frame(width: 64, height: 28)
                        .background(YoseColor.kuroUrushi.opacity(0.6))
                        .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1.5))
                }
            }
            .padding(.horizontal, 14)
        }
        .frame(height: 48)
        .overlay(alignment: .bottom) {
            VStack(spacing: 0) {
                Rectangle().fill(YoseColor.kin).frame(height: 2)
                Rectangle().fill(YoseColor.sumi).frame(height: 2)
            }
        }
    }
}
```

### ② 主ボタン / 副ボタン / 押せないボタン（`YoseButtonStyle`）
* **見た目の仕様**：
  * **主ボタン（`.primary`）**：背景 `yoseShu`（`#BD3C28`）、上辺内側に1ptのハイライト（白25%）、外枠 `yoseSumi` 2pt、文字 `yoseKinari`。
  * **副ボタン（`.secondary`）**：背景 `yoseWashi`（`#FBF8F1`）または `yoseKi`、外枠 `yoseSumi` 2pt、文字 `yoseSumi`。
  * **押せないボタン（`isEnabled == false`）**：背景 `yoseGinNezu`（`#D4CFC4`）に黒5%の斜めストライプ（閉鎖感）、外枠 `yoseHaiSumi` 1.5pt、文字 `yoseDisabledText`、**下影 0pt**。
  * **押下時**：`y: +2pt`（コマンドは `+3pt`）沈み込み、その分ハードシャドウが消える。

```swift
public enum YoseButtonRole {
    case primary     // 朱色（確定・勝負ネタにする・次へ・＋）
    case secondary   // 和紙色（型を変える・戻る・おまかせ）
    case command     // 週コマンド用（高さ68pt・下影3pt）
}

public struct YoseButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let role: YoseButtonRole
    var badgeText: String? = nil // 「出張中」などの斜め札

    public init(_ role: YoseButtonRole = .secondary, badgeText: String? = nil) {
        self.role = role
        self.badgeText = badgeText
    }

    private var shadowDepth: CGFloat {
        guard isEnabled else { return 0 }
        return role == .command ? 3 : 2
    }

    private var backgroundFill: Color {
        guard isEnabled else { return YoseColor.ginNezu }
        switch role {
        case .primary: return YoseColor.shu
        case .secondary, .command: return YoseColor.washi
        }
    }

    private var foregroundColor: Color {
        guard isEnabled else { return YoseColor.disabledText }
        return role == .primary ? YoseColor.kinari : YoseColor.sumi
    }

    public func makeBody(configuration: Configuration) -> some View {
        let pressOffset: CGFloat = (isEnabled && configuration.isPressed) ? shadowDepth : 0

        configuration.label
            .font(YoseFont.gothic(role == .command ? 18 : 15, weight: .heavy))
            .foregroundStyle(foregroundColor)
            .background {
                ZStack {
                    backgroundFill
                    if !isEnabled {
                        DiagonalStripePattern()
                            .stroke(YoseColor.sumi.opacity(0.07), lineWidth: 4)
                    } else if role == .primary {
                        VStack {
                            Rectangle().fill(Color.white.opacity(0.22)).frame(height: 2)
                            Spacer()
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(isEnabled ? YoseColor.sumi : YoseColor.haiSumi, lineWidth: 2)
            )
            .overlay(alignment: .bottomTrailing) {
                if let badgeText {
                    Text(badgeText)
                        .font(YoseFont.gothic(11, weight: .heavy))
                        .foregroundStyle(YoseColor.kinari)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(YoseColor.shu)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                        .rotationEffect(.degrees(-8))
                        .offset(x: -6, y: -4)
                }
            }
            .offset(y: pressOffset)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(YoseColor.sumi)
                    .offset(y: shadowDepth)
                    .opacity(isEnabled ? 1 : 0)
            )
            .animation(.easeOut(duration: 0.06), value: configuration.isPressed)
    }
}

private struct DiagonalStripePattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 12
        var x: CGFloat = -rect.height
        while x < rect.width {
            path.move(to: CGPoint(x: x, y: rect.height))
            path.addLine(to: CGPoint(x: x + rect.height, y: 0))
            x += step
        }
        return path
    }
}
```

### ③ 木札カード（`YoseKifudaCard`）＆ ④ 貼り紙カード（`YoseHarigamiCard`）
* **見た目の仕様**：
  * **木札カード**：背景 `yoseKi`（`#E2D3B3`）、外枠 `yoseSumi` 2pt、内側に `2pt` インセットした `yoseKiDark` の細い内枠（1pt）、上部中央に小さな釘穴ドット（または木目の重厚感）。ステータス表示や能力ランク枠に使用。
  * **貼り紙カード**：背景 `yoseWashi`（`#FBF8F1`）、外枠 `yoseSumi` 2pt、下影 `2pt`。`isFeatured: true`（勝負ネタ等）の時は、外枠が `yoseShu`（2.5pt）＋内枠 `yoseKin`（1pt）になり、左端に幅 `6pt` の臙脂の飾り帯が入る。

```swift
/// 木札カード（ステータス枠・能力ランク枠・見出し箱）
public struct YoseKifudaModifier: ViewModifier {
    var showNail: Bool = false

    public func body(content: Content) -> some View {
        content
            .background(YoseColor.ki)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .overlay(
                RoundedRectangle(cornerRadius: 1)
                    .stroke(YoseColor.kiDark, lineWidth: 1)
                    .padding(3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(YoseColor.sumi, lineWidth: 2)
            )
            .overlay(alignment: .top) {
                if showNail {
                    Circle()
                        .fill(YoseColor.sumi)
                        .frame(width: 4, height: 4)
                        .padding(.top, 4)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(YoseColor.sumi)
                    .offset(y: 2)
            )
    }
}

/// 貼り紙カード（ネタ帳カード・講評カード・能力アップ行）
public struct YoseHarigamiModifier: ViewModifier {
    var isFeatured: Bool = false // 勝負ネタなどの特別強調

    public func body(content: Content) -> some View {
        content
            .padding(.leading, isFeatured ? 6 : 0)
            .background(isFeatured ? Color(hex: 0xFFFDF7) : YoseColor.washi)
            .overlay(alignment: .leading) {
                if isFeatured {
                    Rectangle()
                        .fill(YoseColor.enji)
                        .frame(width: 6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .overlay(
                RoundedRectangle(cornerRadius: 1)
                    .stroke(isFeatured ? YoseColor.kin : Color.clear, lineWidth: 1)
                    .padding(2.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(isFeatured ? YoseColor.shu : YoseColor.sumi, lineWidth: isFeatured ? 2.5 : 2)
            )
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(YoseColor.sumi)
                    .offset(y: 2)
            )
    }
}

public extension View {
    func yoseKifuda(showNail: Bool = false) -> some View {
        modifier(YoseKifudaModifier(showNail: showNail))
    }
    func yoseHarigami(isFeatured: Bool = false) -> some View {
        modifier(YoseHarigamiModifier(isFeatured: isFeatured))
    }
}
```

### ⑤ タグ（`YoseTag`）＆ ⑥ 判子（`YoseHankoStamp`）
* **見た目の仕様**：
  * **タグ（角札）**：丸い `Capsule` は厳禁。角丸 `0pt` の四角い紙札。流派タグ（「伏線回収」等）は臙脂塗り＋白抜き文字。状態タグ（「自信作」「見飽きられた」等）は色枠 `1.5pt` ＋同色12%透過背景。
  * **判子（朱印）**：「真剣勝負」「突破」「秀」「印」。`yoseShu` の二重枠（外枠 `2pt`、内枠 `1pt`）、背景は `yoseWashi` 90%透過、全体を `-6度` 傾ける。

```swift
public enum YoseTagStyle {
    case solidEnji   // 流派タグ（伏線回収・畳みかけ）
    case outlineShu  // 警告・注目（見飽きられた）
    case outlineKin  // 肯定（自信作）
    case outlineSumi // 補足（長め・短め・未披露）
}

public struct YoseTag: View {
    let text: String
    var style: YoseTagStyle = .outlineSumi

    public var body: some View {
        let (fg, bg, border): (Color, Color, Color) = {
            switch style {
            case .solidEnji:   return (YoseColor.kinari, YoseColor.enji, YoseColor.sumi)
            case .outlineShu:  return (YoseColor.shu, YoseColor.shu.opacity(0.10), YoseColor.shu)
            case .outlineKin:  return ( Color(hex: 0x7A6218), YoseColor.kin.opacity(0.18), YoseColor.kin)
            case .outlineSumi: return (YoseColor.sumi, YoseColor.ki.opacity(0.45), YoseColor.sumi)
            }
        }()

        Text(text)
            .font(YoseFont.gothic(11, weight: .heavy))
            .foregroundStyle(fg)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(bg)
            .overlay(Rectangle().stroke(border, lineWidth: 1.5))
    }
}

/// 朱印スタンプ（「真剣勝負」「突破」「秀」）
public struct YoseHankoStamp: View {
    let text: String
    var isSquare: Bool = false // 「秀」「印」など1文字は正方形
    var angle: Double = -6

    public var body: some View {
        Text(text)
            .font(YoseFont.gothic(isSquare ? 20 : 12, weight: .black))
            .tracking(isSquare ? 0 : 1)
            .foregroundStyle(YoseColor.shu)
            .padding(.horizontal, isSquare ? 8 : 7)
            .padding(.vertical, isSquare ? 6 : 3)
            .background(YoseColor.washi.opacity(0.92))
            .overlay(
                Rectangle()
                    .stroke(YoseColor.shu, lineWidth: 1)
                    .padding(2.5)
            )
            .overlay(
                Rectangle()
                    .stroke(YoseColor.shu, lineWidth: 2)
            )
            .rotationEffect(.degrees(angle))
    }
}
```

### ⑦ 数値表示（実力・お金・体力・知名度の4画面統一コンポーネント）
* **見た目の仕様**：画面ごとにバラバラだった「実力」「お金」「体力」「知名度」を以下の2つの専用計器ビューに統一し、どの画面でも同じ色・同じラベル・同じ数字フォントで表示する。
  * **実力バッジ（`YosePowerBadge`）**：常に「木札（`yoseKi`）」または「黒漆箱」の左上に `実力`（11pt Bold・臙脂）、右または下に `28pt Black` の等幅数字。
  * **ステータス黒帯（`YoseStatusStrip`）**：体力（筆太ゲージ＋数値）、所持金（`¥`＋山吹金数字）、知名度（差分 `↑+6` 付き）を統一表示。

```swift
/// 全画面共通「実力」木札バッジ（週メイン・能力アップ・結果画面で共通利用）
public struct YosePowerBadge: View {
    let power: Int
    var delta: Int? = nil // 結果画面や能力アップでの上昇量 (+12 など)
    var compact: Bool = false

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("実力")
                .font(YoseFont.gothic(compact ? 11 : 12, weight: .heavy))
                .foregroundStyle(YoseColor.enji)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(YoseColor.enji.opacity(0.12))
                .overlay(Rectangle().stroke(YoseColor.enji, lineWidth: 1))

            Text("\(power)")
                .font(YoseFont.number(compact ? 24 : 30, weight: .black))
                .foregroundStyle(YoseColor.sumi)
                .contentTransition(.numericText(value: Double(power)))

            if let delta, delta > 0 {
                Text("+\(delta)")
                    .font(YoseFont.number(14, weight: .heavy))
                    .foregroundStyle(YoseColor.shu)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .yoseKifuda()
    }
}

/// 体力・所持金・知名度の統一ステータスバー
public struct YoseVitalMoneyBar: View {
    let stamina: Int
    let maxStamina: Int
    let money: Int
    var fame: Int? = nil

    public var body: some View {
        HStack(spacing: 12) {
            // 1. 体力（緑の謎ブロックを廃止し、太枠ゲージ＋数字に統一）
            HStack(spacing: 6) {
                Text("体力")
                    .font(YoseFont.gothic(11, weight: .heavy))
                    .foregroundStyle(YoseColor.kin)
                YoseGauge(
                    value: Double(stamina),
                    total: Double(maxStamina),
                    fill: YoseColor.tokiwa,
                    height: 12
                )
                .frame(width: 96)
                Text("\(stamina)")
                    .font(YoseFont.number(15, weight: .heavy))
                    .foregroundStyle(YoseColor.kinari)
                + Text("/\(maxStamina)")
                    .font(YoseFont.number(11, weight: .bold))
                    .foregroundStyle(YoseColor.ginNezu)
            }

            Spacer()

            // 2. 知名度（任意）
            if let fame {
                HStack(spacing: 3) {
                    Text("知名度")
                        .font(YoseFont.gothic(10, weight: .bold))
                        .foregroundStyle(YoseColor.kinari.opacity(0.8))
                    Text("\(fame)")
                        .font(YoseFont.number(15, weight: .heavy))
                        .foregroundStyle(YoseColor.kinari)
                }
            }

            // 3. 所持金
            Text("¥\(money.formatted(.number))")
                .font(YoseFont.number(17, weight: .heavy))
                .foregroundStyle(YoseColor.kinBright)
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(YoseColor.kuroUrushi)
        .overlay(alignment: .top) {
            Rectangle().fill(YoseColor.sumi).frame(height: 2)
        }
    }
}
```

### ⑧ ゲージ（`YoseGauge`）
* **見た目の仕様**：OSの細いプログレスバーを全廃。外枠 `yoseSumi` `1.5pt`、背景 `yoseGinNezu`、内部に **25%刻みの黒い目盛り縦線（3本）** を入れ、上辺に2ptのハイライトを入れて「計器のガラス管」の質感を出す。**％記号は一切表示しない**。

```swift
public struct YoseGauge: View {
    let value: Double
    let total: Double
    var fill: Color = YoseColor.shu
    var height: CGFloat = 12
    var showTicks: Bool = true

    public var body: some View {
        let ratio = total > 0 ? min(max(value / total, 0), 1) : 0

        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(YoseColor.ginNezu)

                Rectangle()
                    .fill(fill)
                    .frame(width: geo.size.width * ratio)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Color.white.opacity(0.28))
                            .frame(height: 2)
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.78), value: ratio)

                // 25%刻みの目盛りスリット
                if showTicks {
                    HStack(spacing: 0) {
                        ForEach(0..<4, id: \.self) { idx in
                            Spacer()
                            if idx < 3 {
                                Rectangle()
                                    .fill(YoseColor.sumi.opacity(0.35))
                                    .frame(width: 1)
                            }
                        }
                    }
                }
            }
            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
        }
        .frame(height: height)
    }
}
```

### ⑨ 吹き出し（`YoseSpeechBox`）
* **見た目の仕様**：左側に話者名入りの木札・朱札を縦に配置し、右側に明朝体のセリフ箱（外枠2pt＋下影2pt）を結合。右下に次ページ送りの赤い三角（`▼`）を点滅表示。こけし風の丸顔プリミティブに頼らず、「名前札（寄席のめくり風）」だけでも絵になる骨格にする。

```swift
public struct YoseSpeechBox: View {
    let speaker: String
    let text: String
    var roleLabel: String? = nil // 「相方」「審査員」など

    public var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // 寄席の「めくり」風・話者名札（AIっぽい丸顔アイコンを不要にする）
            VStack(spacing: 2) {
                if let roleLabel {
                    Text(roleLabel)
                        .font(YoseFont.gothic(9, weight: .heavy))
                        .foregroundStyle(YoseColor.kin)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(YoseColor.kuroUrushi)
                }
                Text(speaker)
                    .font(YoseFont.mincho(15))
                    .foregroundStyle(YoseColor.kinari)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(minWidth: 58)
                    .background(YoseColor.shu)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
            }
            .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))

            // セリフ枠（明朝体）
            HStack(alignment: .bottom, spacing: 6) {
                Text(text)
                    .font(YoseFont.mincho(15))
                    .lineSpacing(5)
                    .foregroundStyle(YoseColor.sumi)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(YoseColor.shu)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .yoseHarigami()
        }
    }
}
```

### ⑩ タブ（上部切替タブ `YoseTopTabBar` ＆ 下部木札フッター `YoseFooterTabBar`）
* **見た目の仕様**：
  * **上部タブ**（能力 / 戦績 / 持ちネタ）：選択中は背景 `yoseWashi`＋下辺に `yoseShu` の `4pt` 太線。非選択は `yoseKi` で一段沈める。
  * **下部フッタータブ**（日程 / コンビ / 設定）：白い無機質なボタンを廃止。`yoseKi` の木札ボタン3枚を並べ、文字の左に臙脂色の小紋章アイコンを添える。

```swift
public struct YoseTopTabBar: View {
    let tabs: [String]
    @Binding var selectedIndex: Int

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { idx in
                let isSelected = (idx == selectedIndex)
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        selectedIndex = idx
                    }
                } label: {
                    Text(tabs[idx])
                        .font(YoseFont.gothic(15, weight: .heavy))
                        .foregroundStyle(isSelected ? YoseColor.sumi : YoseColor.haiSumi)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(isSelected ? YoseColor.washi : YoseColor.ki)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(isSelected ? YoseColor.shu : YoseColor.sumi)
                                .frame(height: isSelected ? 4 : 1.5)
                        }
                        .overlay(alignment: .trailing) {
                            if idx < tabs.count - 1 {
                                Rectangle().fill(YoseColor.sumi).frame(width: 1.5)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 42)
    }
}

public struct YoseFooterTabBar: View {
    let items: [(title: String, symbol: String, action: () -> Void)]

    public var body: some View {
        HStack(spacing: 8) {
            ForEach(items.indices, id: \.self) { idx in
                Button(action: items[idx].action) {
                    HStack(spacing: 6) {
                        Image(systemName: items[idx].symbol)
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(YoseColor.enji)
                        Text(items[idx].title)
                            .font(YoseFont.gothic(16, weight: .heavy))
                            .foregroundStyle(YoseColor.sumi)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(YoseButtonStyle(.secondary))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(YoseColor.kuroUrushi)
        .overlay(alignment: .top) {
            Rectangle().fill(YoseColor.kin).frame(height: 1.5)
        }
    }
}
```

### ⑪ モーダル（`YoseModal`）＆ ⑫ トースト（`YoseToast`）
* **見た目の仕様**：
  * **モーダル**：背景を黒65%で暗転し、中央に「臙脂のヘッダー帯＋二重金枠の貼り紙」をドンと置く。OS標準の `.alert` や丸いシートは使わない。
  * **トースト**：画面上部（ヘッダー直下）から黒漆＋金枠の横札がスライドインし、「勝負ネタを『商店街の福引』に変更！」などを1.8秒表示。

```swift
public struct YoseModal<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    let primaryTitle: String
    let primaryAction: () -> Void
    var cancelTitle: String? = "やめる"
    var cancelAction: (() -> Void)? = nil

    public var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()

            VStack(spacing: 0) {
                // モーダル見出し帯
                Text(title)
                    .font(YoseFont.gothic(17, weight: .heavy))
                    .foregroundStyle(YoseColor.kin)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(YoseColor.enji)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(YoseColor.kin).frame(height: 1.5)
                    }

                VStack(spacing: 16) {
                    content()

                    HStack(spacing: 10) {
                        if let cancelTitle, let cancelAction {
                            Button(cancelTitle, action: cancelAction)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .buttonStyle(YoseButtonStyle(.secondary))
                        }
                        Button(primaryTitle, action: primaryAction)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .buttonStyle(YoseButtonStyle(.primary))
                    }
                }
                .padding(16)
                .background(YoseColor.washi)
            }
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(YoseColor.sumi, lineWidth: 2.5))
            .background(RoundedRectangle(cornerRadius: 2).fill(YoseColor.sumi).offset(y: 4))
            .padding(.horizontal, 24)
        }
    }
}

public struct YoseToast: View {
    let message: String

    public var body: some View {
        HStack(spacing: 8) {
            Rectangle().fill(YoseColor.shu).frame(width: 4, height: 20)
            Text(message)
                .font(YoseFont.gothic(14, weight: .heavy))
                .foregroundStyle(YoseColor.kinari)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(YoseColor.kuroUrushi)
        .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1.5))
        .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))
    }
}
```

---

## 6. 動き（Motion & Haptics 規定）

すべての動きに「物理的な重さ」を持たせ、ふわふわしたイージング（長い `.easeInOut`）を禁止します。

| 対象 | 時間 / カーブ | 挙動の具体仕様 |
| :--- | :--- | :--- |
| **1. ボタン押下** | `0.06秒` / `.easeOut` | 押した瞬間に `offset(y: +2pt)`（コマンドは `+3pt`）沈み、下影の不透明度が `0` になる。離すと `0.08秒` で跳ね返る。`UIImpactFeedbackGenerator(style: .rigid)` を鳴らす。 |
| **2. 数値の増減** | `0.28秒` / `.spring(response: 0.28, dampingFraction: 0.72)` | `.contentTransition(.numericText(value:))` を必須適用。能力アップで `[+]` を押した瞬間、該当行の背景が一瞬 `yoseKinBright.opacity(0.35)` に光り、数字が `scaleEffect(1.2 -> 1.0)` で跳ねる。 |
| **3. 判子（朱印）** | `0.22秒` / `.spring(response: 0.22, dampingFraction: 0.55)` | 初期状態 `scaleEffect(2.2)` ＋ `opacity(0)` から、`scaleEffect(1.0)` へ叩きつけるように着地。着地フレームで画面全体を `offset(y: 3 -> -2 -> 0)` で微振動させ、`UINotificationFeedbackGenerator().notificationOccurred(.success)` を発火。 |
| **4. 要素の出現** | `0.18秒` / `.spring(response: 0.25, dampingFraction: 0.8)` | リスト行や講評カードは `offset(y: 10)` → `0` で下から短くせり上がる。審査講評と結果カードは `0.12秒` のディレイ差をつけて順番に出す。 |
| **5. 画面遷移** | `0.18秒` / `.easeOut` | サブ画面（ネタ帳・能力アップ）はOS標準の横プッシュではなく、下から `16pt` せり上がる高速トランジション、または定式幕（黒・柿・萌黄の縦縞または臙脂幕）が `0.25秒` で閉じて開くワイプ演出を使う。 |

### 判子叩きつけ＆数値バウンス用 ViewModifier

```swift
public struct YoseStampImpactModifier: ViewModifier {
    let isStamped: Bool

    public func body(content: Content) -> some View {
        content
            .scaleEffect(isStamped ? 1.0 : 2.2)
            .opacity(isStamped ? 1.0 : 0.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.55), value: isStamped)
    }
}
```

---

## 7. 画面の型（4大テンプレートの骨組み）

すべての画面は **幅 `393pt`・左右マージン `14pt`・背景 `yoseKinari`（`#F5F0E1`）** を厳守し、以下の4つの骨格のいずれかで組むこと。

### 型A：週メイン・会話画面（`g6_week` 型）
```text
[000-048pt] ① YoseHeaderBar ("1年目 第1週")
[048-106pt] ② 大会カウントダウン黒看板 (YoseColor.kuroUrushi + 金枠1.5pt + 残り週数24pt金数字)
[106-390pt] ③ 舞台ビュー (右上: YosePowerBadge + 相性木札 / 下部: YoseSpeechBox 明朝セリフ)
[390-756pt] ④ コマンド2列×3段グリッド (H/V spacing: 10pt, 各ボタン高さ 68pt, 右下に効果プレビュー)
[756-792pt] ⑤ YoseVitalMoneyBar (体力ゲージ + 所持金 黒漆帯)
[792-852pt] ⑥ YoseFooterTabBar (日程 / コンビ / 設定 の木札3連)
```

### 型B：決定・能力配分画面（`g6_allocate` 型）
```text
[000-048pt] ① YoseHeaderBar ("能力アップ")
[048-168pt] ② 5能力ランク木札 (HStack spacing: 6pt, 各枠に六角ランク章 + 次ランクまでの目盛りゲージ)
[168-236pt] ③ 統合ヘッダー箱 (左幅108ptの木札に「実力 42」を統合 / 右5列に「閃・語・間・存・胆」オーブと所持値)
[236-780pt] ④ 能力5行リスト (VStack spacing: 8pt, 各行高さ 68pt)
              ※各行の左に「センス 43 → 45」とミニバー、中央に[-][+]物理ボタン(36×36pt)、
                右5列(幅38pt固定Grid)に消費コスト。コスト0の列は背景透明＋「・」のみ表示！
[780-852pt] ⑤ フッター4ボタン (戻る / リセット / おまかせ / 確定[Primary朱色])
```

### 型C：一覧・管理画面（`n4_neta_list` 型）
```text
[000-048pt] ① YoseHeaderBar ("ネタ帳", subtitle: "あなたのコンビ", closeAction: あり)
[048-090pt] ② YoseTopTabBar (能力 / 戦績 / 持ちネタ)
[090-130pt] ③ セクション見出し帯 (左:「持ちネタ」18pt Heavy / 右:「3 / 4」等幅数字 + 下辺2pt墨線)
[130-852pt] ④ ScrollView (padding(.horizontal, 14), VStack spacing: 12pt)
              └ 各カードは `.yoseHarigami(isFeatured: isShobuNeta)`
                ・1段目：左に明朝体20ptでネタ名＋流派タグ(`YoseTag`)、右上に勝負ネタなら`YoseHankoStamp("真剣勝負")`（※ `>` は置かない）
                ・2段目：完成度・客の反応の2行（`YoseGauge` + 右端に22pt Heavy等幅数字）
                ・3段目：舞台回数＋角札タグ（`YoseTag`）
                ・4段目：アクションボタン行（すべて `YoseButtonStyle` 高さ34pt、枠なしボタン禁止）
```

### 型D：大会結果画面（`n4_result_done` 型）
※**制約厳守**：予選の結果では審査員の点数は出さず、講評（明朝体）と評価印（「秀」「良」等の朱印）と通過基準との実力対比のみを出す。
```text
[000-048pt] ① YoseHeaderBar (または舞台上部の定式幕ヘッダー)
[048-390pt] ② 舞台演出エリア
              ・上部：黒漆＋二重金枠の大会看板（「春新人賞A / 第12週・本番」）
              ・中央：結果額縁（「優勝」「予選通過」）
              ・下部：全幅の墨帯（高さ32pt・上下金線）に明朝体20pt『「 どっと沸いた！！ 」』
[390-540pt] ③ 審査講評カード (`.yoseHarigami()`)
              ・左上：審査員名札、右上：`YoseHankoStamp("秀", isSquare: true)`
              ・本文：明朝体15pt（行間6pt）で講評テキスト
[540-660pt] ④ 結果・報酬2段カード (`.yoseHarigami()`)
              ・上段(58pt)：中央揃えで `[通過基準 30] ▶ [発揮実力 134 (32pt朱色)] + [突破 判子]`
              ・下段(46pt・背景 `yoseKi.opacity(0.4)`)：左右2カラムで `[賞金 +50万]` / `[知名度 9 (↑+6)]`
[660-852pt] ⑤ 下部固定ボタン (`YoseButtonStyle(.primary)` 高さ52pt「次へ 進む ▶」)
              ※背景の観客シルエットを入れる場合は金枠ストロークを絶対につけず、`#181210` 単色で高低差をバラけさせる。
```

---

## 8. やってはいけない事（AIっぽくなる10の禁則事項）

1. **`Capsule()`（丸ピル型）と `cornerRadius(8以上)` の使用禁止**
   * タグやボタンを丸いカプセルにした瞬間、NotionやSaaSのWeb管理画面になります。角丸は最大 `2pt`、タグは `0pt` を死守してください。
2. **枠線なし（Borderless）のグレー/ベージュボタンの禁止**
   * 背景色だけのボタンはiOS標準のフラットUIに見えます。すべてのインタラクティブ要素には必ず `2pt` の `yoseSumi` 枠と下影をつけてください。
3. **カード右端の `>`（シェブロン `chevron.right`）の禁止**
   * カードの右上に `>` を置くと、iOSの「設定アプリ」のセルにしか見えなくなります。遷移や操作は必ずカード下部の物理ボタンで行わせてください。
4. **SwiftUIの `Circle` と `RoundedRectangle` を組み合わせた「こけし人間・丸顔アイコン」の禁止**
   * 幾何学図形で作った「点目とへの字口の丸顔」や「同じ大きさの丸が等間隔に並んだ観客席（金縁つき）」は、最も露骨なAI生成臭を出します。顔イラスト素材がない箇所は、無理に丸顔を描かず**「寄席のめくり（縦書き・横書きの名前木札）」や「家紋・紋章」**で表現してください。
5. **消費ゼロ（`-`）の空セルにまで箱背景を敷くことの禁止**
   * 能力アップ画面で、消費しない経験点の列にまでグレーの四角い箱を置くと「Excelの入力フォーム」に見えます。値がないマスは背景を透明にし、必要な数字だけを浮き立たせてください。
6. **「％」表示と、細い直線プログレスバーの禁止**
   * 数字の後ろに `%` をつけたり、高さ4〜6ptの枠なしバーを置くと「ファイルダウンロード画面」になります。ゲージは必ず太枠（12pt）＋目盛りスリット入りにし、数値は生の整数（`88`、`あと12`）で表記してください。
7. **予選結果での審査員点数表示の禁止**
   * 予選で「85点・92点」と小刻みな点数を並べると決勝の審査演出のありがたみが消えます。予選は「通過基準 vs 発揮実力」と「審査員の一言講評＋評価朱印（秀・良・可）」で見せてください。
8. **重要な数値（実力・お金）を画面ごとに違うデザインで書くことの禁止**
   * ある画面では黒い帯に白文字、別の画面では茶色い箱に黒文字、また別の画面では白地に赤文字で「実力」を書くと、プレイヤーが同じパラメータだと認識できません。必ず `YosePowerBadge` を使ってください。
9. **カードの真ん中に `Spacer()` で巨大な空白を空けることの禁止**
   * 左端に小文字、右端に大文字を置いて中央をスカスカにすると、視線が迷子になります。対比する数字（「通過基準 30 ▶ 発揮実力 134」）は中央に塊として寄せてください。
10. **ぼかし影（`shadow(radius: 8)` 等）の禁止**
    * ぼかしたドロップシャドウはマテリアルデザイン（Web/モダンアプリ）の文脈です。寄席の木札と貼り紙には、`radius: 0, x: 0, y: 2` のパキッとした黒影（ハードシャドウ）のみを使用してください。
