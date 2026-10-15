デザインシステムの正本（`design_system_argon_v1.md`）および実機UI監査（`design_audit_argon_r3_g4_v0.md`）の基準に基づき、**外部画像なし・顔なし・％表示なし・ゲームルール不変・最小タップ（1タップ即閉じ／自動消去）**を厳守した2つの演出設計と、そのまま組み込んで動くSwiftUIコードを提示します。

---

# 1) 能力のランクが上がった時の演出（`YoseRankUpOverlay`）

### ■ 入れることで何が良くなるか（1行）
**週メインの小さな文字チップで流れていた「G→F→E…」の節目に、木札と朱印が叩きつけられるパワプロ級の物理的な快感が生まれ、練習や能力アップの1タップごとに「強くなった手応え」が脳に刺さるようになる。**

---

### ■ 発火の瞬間・閉じ方・連続昇格のルール
1. **どの瞬間に出るか**：
   * **能力アップ画面（`AbilityUpView`）**で「確定（とじる）」を押してランク境界（`15 / 25 / 35 / 45 / 55 / 70 / 90`）を跨いだ瞬間、または**週行動（練習・イベント）**の結果でランクが上がった瞬間。
2. **どう閉じるか（最小の手間）**：
   * **自動消去**：表示から **`1.45秒`** で自動的にスッと消える（放置していても進行を止めない）。
   * **1タップ即閉じ**：画面のどこをタップしても **`0.12秒`** で即座に閉じ、すぐ次の週コマンドを押せる。
3. **複数・連続で上がった時の処理（1回にまとめる）**：
   * 「おまかせ」等で2つ以上の能力が同時にランクアップした時や、`G → E` と2段階跳ねた時は、**モーダルを何回も連発しない（テンポ阻害の防止）**。
   * 主役カードには「最も高く上がった能力」を特大表示し、カード下段の**「同時昇格木札ストリップ」**に他の昇格能力（例：`発想 G▶F` `表現 F▶E`）を横並びで一括刻印し、**必ず1回の演出（1タップ）で完結**させる。

---

### ■ 画面の絵（配置図：393 × 852pt）
背景の週メイン画面（または能力アップ画面）を黒漆 `65%` で暗転し、画面中央（`y: 230〜590pt`）に「寄席の番付昇格貼り紙」をドンと打ち付けます。

```text
+---------------------------------------------------+ 0pt
| (背景画面の上に Color.black.opacity(0.65) 暗転)    |
|                                                   |
|   +===========================================+   | 236pt (左右マージン24pt / 幅345pt)
|   | [臙脂ヘッダー帯 42pt] ◆ 番 付 昇 格 ◆      |   |
|   +-------------------------------------------+   |
|   | [定式幕飾り帯 10pt: 黒・柿・萌黄・黒・柿]  |   |
|   +-------------------------------------------+   |
|   |              【 能力木札タグ 】            |   |
|   |            [表] 表現 (18pt Heavy)          |   |
|   |                                           |   |
|   |     +-------+               +=========+   |   |
|   |     |   F   |   ======▶     ‖    E    ‖   |   |
|   |     +-------+   (朱太矢印)   +=========+   |   |
|   |    (旧ランク札)            (新ランク大木札) |   |
|   |      44×44pt                 68×68pt      |   |
|   |                                     [昇格] |   | <- 朱印スタンプ(-8度叩きつけ)
|   |   -------------------------------------   |   |
|   |   [ 表現 22 ▶ 26 ]     [ 実力 115 (+4) ]  |   | <- 等幅計器ナンバー
|   |                                           |   |
|   |   +-----------------------------------+   |   |
|   |   | 同時昇格: [セ G▶F]  [華 F▶E]      |   |   | <- ※複数昇格時のみ表示
|   |   +-----------------------------------+   |   |
|   +===========================================+   | 560pt (墨2.5pt枠 + 下影4pt)
|                                                   |
|            画面をタップして閉じる ▶               | 590pt (12pt Bold 生成り)
+---------------------------------------------------+ 852pt
```

---

### ■ 部品と動きの秒数（タイムライン：計 `1.45秒`）

| 秒数 | 部品 | 動き・Haptics・SE |
| :--- | :--- | :--- |
| **`0.00s`** | **暗転＋昇格貼り紙本体** | 背景が `0.12s`（`.easeOut`）で暗転。同時に貼り紙カードが `scale(0.88 -> 1.0)` で出現。`Sound.play(.rankup)` 再生。 |
| **`0.08s`** | **新ランク大木札（`E`〜`S`）** | 右側の新ランク角木札（`68×68pt`・二重金枠）が `scale(1.8 -> 1.0)`、`.spring(response: 0.24, dampingFraction: 0.58)` で着地。同時に金色コーナー火花（矩形4片）が外側へ `14pt` 弾ける。 |
| **`0.18s`** | **朱印スタンプ『昇格』＋数値** | 右上に `YoseHankoStamp("昇格", angle: -8)` が `scale(2.2 -> 1.0)`（`0.22s` spring）で叩きつけられる。着地フレームでカード全体が `offset(y: 3 -> -2 -> 0)` と微振動し、`UINotificationFeedbackGenerator().notificationOccurred(.success)` が発火。能力値・実力が `.numericText()` でカウントアップ。 |
| **`0.26s`** | **同時昇格ストリップ** | （複数ある場合のみ）下段の小木札が `offset(y: 8 -> 0)` でせり上がる。 |
| **`1.45s`** | **自動クローズ（または1タップ）** | 放置時は `1.45s` 後に `0.15s` フェードアウトして完了。演出中のどこでタップしても即座に `onDismiss()` を呼んで閉じる。 |

---

### ■ SwiftUI コード（そのまま動く粒度：`RankUpOverlayView.swift`）

```swift
import SwiftUI
import UIKit

// MARK: - 1. データモデル（1個〜複数の能力ランク昇格を保持）

public struct RankUpItem: Identifiable, Equatable {
    public let id = UUID()
    public let abilityName: String   // "センス", "発想", "表現", "華", "メンタル"
    public let abilityShort: String  // "セ", "発", "表", "華", "メ"
    public let abilityColor: Color
    public let fromRank: String      // "G" 〜 "A"
    public let toRank: String        // "F" 〜 "S"
    public let beforeValue: Int
    public let afterValue: Int

    public init(
        abilityName: String,
        abilityShort: String,
        abilityColor: Color,
        fromRank: String,
        toRank: String,
        beforeValue: Int,
        afterValue: Int
    ) {
        self.abilityName = abilityName
        self.abilityShort = abilityShort
        self.abilityColor = abilityColor
        self.fromRank = fromRank
        self.toRank = toRank
        self.beforeValue = beforeValue
        self.afterValue = afterValue
    }
}

// MARK: - 2. ランクアップ演出オーバーレイ本体

public struct YoseRankUpOverlay: View {
    let items: [RankUpItem]
    let totalPower: Int
    let powerDelta: Int
    let onDismiss: () -> Void

    @State private var cardAppeared = false
    @State private var badgeLanded = false
    @State private var stamped = false
    @State private var shakeOffset: CGFloat = 0
    @State private var shownValue: Int = 0
    @State private var isDismissed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var primary: RankUpItem? { items.first }
    private var subItems: ArraySlice<RankUpItem> { items.dropFirst() }

    public init(
        items: [RankUpItem],
        totalPower: Int,
        powerDelta: Int,
        onDismiss: @escaping () -> Void
    ) {
        self.items = items
        self.totalPower = totalPower
        self.powerDelta = powerDelta
        self.onDismiss = onDismiss
    }

    public var body: some View {
        if let main = primary {
            ZStack {
                // 背景暗転（どこをタップしても1回で即座に閉じる）
                Color.black.opacity(cardAppeared ? 0.65 : 0.0)
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    // 昇格貼り紙カード本体
                    VStack(spacing: 0) {
                        headerStrip
                        joshikimakuStripe
                        mainContent(for: main)
                    }
                    .background(YoseColor.washi)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 1)
                            .stroke(YoseColor.kin, lineWidth: 1)
                            .padding(3)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(YoseColor.sumi, lineWidth: 2.5)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(YoseColor.sumi)
                            .offset(y: 4)
                    )
                    .offset(y: shakeOffset)
                    .scaleEffect(cardAppeared ? 1.0 : 0.88)
                    .opacity(cardAppeared ? 1.0 : 0.0)
                    .padding(.horizontal, 24)

                    // タップ案内
                    Text("画面をタップして閉じる ▶")
                        .font(YoseFont.gothic(12, weight: .bold))
                        .foregroundStyle(YoseColor.kinari.opacity(0.9))
                        .opacity(cardAppeared ? 1.0 : 0.0)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                dismissImmediately()
            }
            .task {
                await runSequence(for: main)
            }
        }
    }

    // MARK: - 上部見出し＆定式幕ストリップ

    private var headerStrip: some View {
        HStack(spacing: 8) {
            Rectangle().fill(YoseColor.kin.opacity(0.7)).frame(width: 24, height: 1.5)
            Rectangle().fill(YoseColor.kin).frame(width: 5, height: 5).rotationEffect(.degrees(45))
            Text("番 付 昇 格")
                .font(YoseFont.gothic(18, weight: .heavy))
                .tracking(2)
                .foregroundStyle(YoseColor.kin)
                .shadow(color: YoseColor.kuroUrushi, radius: 0, x: 0, y: 1.5)
            Rectangle().fill(YoseColor.kin).frame(width: 5, height: 5).rotationEffect(.degrees(45))
            Rectangle().fill(YoseColor.kin.opacity(0.7)).frame(width: 24, height: 1.5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .background(YoseColor.enji)
        .overlay(alignment: .bottom) {
            Rectangle().fill(YoseColor.kin).frame(height: 1.5)
        }
    }

    private var joshikimakuStripe: some View {
        GeometryReader { geo in
            let colors: [Color] = [
                YoseColor.kuroUrushi,
                YoseColor.shu,
                YoseColor.tokiwa,
                YoseColor.kuroUrushi,
                YoseColor.shu,
                YoseColor.tokiwa
            ]
            HStack(spacing: 0) {
                ForEach(0..<18, id: \.self) { i in
                    Rectangle()
                        .fill(colors[i % colors.count])
                }
            }
        }
        .frame(height: 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(YoseColor.sumi).frame(height: 1.5)
        }
    }

    // MARK: - 主役ランク昇格エリア

    private func mainContent(for item: RankUpItem) -> some View {
        VStack(spacing: 14) {
            // 1. 能力名バッジ（色弱対応の1文字紋章＋能力名）
            HStack(spacing: 8) {
                Text(item.abilityShort)
                    .font(YoseFont.gothic(13, weight: .black))
                    .foregroundStyle(YoseColor.kinari)
                    .frame(width: 24, height: 24)
                    .background(item.abilityColor)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))

                Text("\(item.abilityName)のランクが上がった！")
                    .font(YoseFont.gothic(16, weight: .heavy))
                    .foregroundStyle(YoseColor.sumi)
            }
            .padding(.top, 4)

            // 2. 旧ランク木札 ▶ 新ランク大木札 ＋ 朱印スタンプ
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 18) {
                    // 旧ランク札 (48×48pt)
                    VStack(spacing: 2) {
                        Text("旧")
                            .font(YoseFont.gothic(10, weight: .bold))
                            .foregroundStyle(YoseColor.haiSumi)
                        Text(item.fromRank)
                            .font(YoseFont.gothic(24, weight: .black))
                            .foregroundStyle(YoseColor.kinari)
                            .frame(width: 48, height: 48)
                            .background(Self.rankColor(item.fromRank).opacity(0.75))
                            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                            .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))
                    }

                    // 昇格矢印（3連シェブロンブロック）
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: "play.fill")
                                .font(.system(size: i == 2 ? 18 : 13, weight: .black))
                                .foregroundStyle(i == 2 ? YoseColor.shu : YoseColor.kin)
                        }
                    }
                    .padding(.top, 14)

                    // 新ランク大木札 (72×72pt + 角火花エフェクト)
                    VStack(spacing: 2) {
                        Text("新ランク")
                            .font(YoseFont.gothic(11, weight: .heavy))
                            .foregroundStyle(YoseColor.shu)

                        ZStack {
                            // 四隅の金火花（外部画像なし・純粋矩形）
                            ForEach(0..<4, id: \.self) { corner in
                                let angle = Double(corner) * 90.0 + 45.0
                                Rectangle()
                                    .fill(YoseColor.kinBright)
                                    .frame(width: 6, height: 6)
                                    .offset(y: badgeLanded ? -54 : -24)
                                    .opacity(badgeLanded ? 0.0 : 1.0)
                                    .rotationEffect(.degrees(angle))
                                    .animation(.easeOut(duration: 0.32), value: badgeLanded)
                            }

                            Text(item.toRank)
                                .font(YoseFont.gothic(40, weight: .black))
                                .foregroundStyle(YoseColor.kinari)
                                .shadow(color: YoseColor.kuroUrushi, radius: 0, x: 0, y: 2)
                                .frame(width: 72, height: 72)
                                .background(Self.rankColor(item.toRank))
                                .overlay(
                                    Rectangle()
                                        .stroke(YoseColor.kinBright, lineWidth: 2)
                                        .padding(3)
                                )
                                .overlay(
                                    Rectangle()
                                        .stroke(YoseColor.sumi, lineWidth: 2.5)
                                )
                                .background(
                                    Rectangle()
                                        .fill(YoseColor.sumi)
                                        .offset(y: 3)
                                )
                                .scaleEffect(badgeLanded ? 1.0 : 1.75)
                                .opacity(badgeLanded ? 1.0 : 0.0)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)

                // 右上叩きつけ朱印『昇格』
                YoseHankoStamp(text: "昇格", isSquare: false, angle: -8)
                    .modifier(YoseStampImpactModifier(isStamped: stamped))
                    .offset(x: -6, y: -4)
            }

            // 3. 能力値と実力の計器ボックス（木札カード）
            HStack(spacing: 0) {
                // 左：能力値推移
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.abilityName)
                        .font(YoseFont.gothic(12, weight: .heavy))
                        .foregroundStyle(YoseColor.haiSumi)
                    Text("\(item.beforeValue)")
                        .font(YoseFont.number(18, weight: .heavy))
                        .foregroundStyle(YoseColor.haiSumi)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(YoseColor.shu)
                    Text("\(shownValue)")
                        .font(YoseFont.number(24, weight: .black))
                        .foregroundStyle(YoseColor.sumi)
                        .contentTransition(.numericText(value: Double(shownValue)))
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(YoseColor.kiDark)
                    .frame(width: 1.5, height: 28)

                // 右：コンビ実力合計
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("実力")
                        .font(YoseFont.gothic(11, weight: .heavy))
                        .foregroundStyle(YoseColor.enji)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(YoseColor.enji.opacity(0.12))
                        .overlay(Rectangle().stroke(YoseColor.enji, lineWidth: 1))

                    Text("\(totalPower)")
                        .font(YoseFont.number(22, weight: .black))
                        .foregroundStyle(YoseColor.sumi)

                    if powerDelta > 0 {
                        Text("+\(powerDelta)")
                            .font(YoseFont.number(13, weight: .heavy))
                            .foregroundStyle(YoseColor.shu)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .yoseKifuda()

            // 4. 連続・同時昇格ストリップ（2個以上同時に上がった時のみ1画面に統合表示）
            if !subItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("同時昇格")
                        .font(YoseFont.gothic(11, weight: .heavy))
                        .foregroundStyle(YoseColor.haiSumi)

                    HStack(spacing: 6) {
                        ForEach(subItems) { sub in
                            HStack(spacing: 4) {
                                Text(sub.abilityShort)
                                    .font(YoseFont.gothic(10, weight: .black))
                                    .foregroundStyle(YoseColor.kinari)
                                    .frame(width: 18, height: 18)
                                    .background(sub.abilityColor)
                                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1))

                                Text("\(sub.fromRank)▶\(sub.toRank)")
                                    .font(YoseFont.gothic(13, weight: .black))
                                    .foregroundStyle(YoseColor.shu)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(YoseColor.washi)
                            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                            .background(Rectangle().fill(YoseColor.sumi).offset(y: 1.5))
                        }
                        Spacer(minLength: 0)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
    }

    // MARK: - 演出タイムライン制御（1.45秒で自動消去・1タップ即スキップ）

    private func runSequence(for item: RankUpItem) async {
        shownValue = item.beforeValue
        if reduceMotion {
            cardAppeared = true
            badgeLanded = true
            stamped = true
            shownValue = item.afterValue
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            dismissImmediately()
            return
        }

        // 0.00s: カード出現
        withAnimation(.easeOut(duration: 0.12)) {
            cardAppeared = true
        }

        // 0.08s: 新ランク木札の着地
        try? await Task.sleep(nanoseconds: 80_000_000)
        guard !isDismissed else { return }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.58)) {
            badgeLanded = true
        }

        // 0.18s: 朱印叩きつけ ＋ 画面微振動 ＋ Haptics ＋ 数値ジャンプ
        try? await Task.sleep(nanoseconds: 100_000_000)
        guard !isDismissed else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
            stamped = true
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
            shownValue = item.afterValue
        }

        // 叩きつけの物理シェイク (y: +3 -> -2 -> 0)
        withAnimation(.linear(duration: 0.04)) { shakeOffset = 3 }
        try? await Task.sleep(nanoseconds: 40_000_000)
        withAnimation(.linear(duration: 0.04)) { shakeOffset = -2 }
        try? await Task.sleep(nanoseconds: 40_000_000)
        withAnimation(.linear(duration: 0.04)) { shakeOffset = 0 }

        // 1.45s: 自動クローズ
        try? await Task.sleep(nanoseconds: 1_190_000_000)
        guard !isDismissed else { return }
        dismissImmediately()
    }

    private func dismissImmediately() {
        guard !isDismissed else { return }
        isDismissed = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut(duration: 0.12)) {
            cardAppeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            onDismiss()
        }
    }

    /// デザインシステム準拠の等級カラー（高コントラスト版）
    public static func rankColor(_ rank: String) -> Color {
        switch rank {
        case "S": return YoseColor.kinBright
        case "A": return YoseColor.shu
        case "B": return YoseColor.tokiwa
        case "C": return Color(hex: 0x6B8E23)
        case "D": return Color(hex: 0xC86428)
        case "E": return YoseColor.expTan
        case "F": return Color(hex: 0x5A6B7C)
        default:  return YoseColor.haiSumi
        }
    }
}
```

---
---

# 2) 年が変わる時の幕間（1年の締め → 新年の始まり：`YoseYearTurnCurtainView`）

### ■ 入れることで何が良くなるか（1行）
**年末リザルトから翌年第1週へパッと切り替わっていた味気ない遷移が、「定式幕の引き締め」と「年号めくり札の反転」によって『実力・資金・ネタをすべて背負って新しい年の寄席に上がる』熱い開幕体験に変わる。**

---

### ■ 監査（`49_複数年_2年目.png`）の減点解消ポイント
1. **上部 `YoseHeaderBar` と定式幕の常設**：画面上部の無意味な暗褐色空白（`170pt`）を全廃し、`YoseHeaderBar(title: "新シーズン開幕")` と定式幕（高さ `18pt`）で舞台の額縁として締める。
2. **「1年目の到達」3指標の3連木札化**：小さく横並びだった「実力・知名度・所持金」を3分割の独立木札（`22pt Heavy` 等幅数字）に拡大する。
3. **「何が引き継がれるか」の明示**：初見プレイヤーが迷わないよう、中央に `YoseTag(text: "実力・知名度・資金・持ちネタをすべて引き継いで開幕", style: .solidEnji)` と「体力全回復（100/100）」「1回戦シード権（前年準々決勝以上時）」の開幕ボーナスを明記する。
4. **下部ボタンの `YoseButtonStyle(.primary)` 完全準拠**：浮いていた金細枠を廃止し、墨 `2pt` 枠＋下影 `3pt`＋上辺白ハイライト `2pt` の物理主ボタンに統一。**画面のどこでも（または主ボタンを）1回タップするだけで即座に新年の第1週へ進める**。

---

### ■ 画面の絵（配置図：393 × 852pt）
年末リザルト画面（`44_年末リザルト.png`）で「2年目へ ▶」を押した直後に挟まる全画面幕間です。

```text
+---------------------------------------------------+ 0pt
| [000-048pt] ① YoseHeaderBar ("新シーズン開幕")     |
+---------------------------------------------------+ 48pt
| [048-066pt] ② 定式幕ヘッダー (黒・柿・萌黄 18pt)   |
+---------------------------------------------------+ 66pt
|                                                   |
|   +===========================================+   | 82pt (左右14pt / 幅365pt)
|   | [黒漆看板 172pt]     ◆ 寄席・年次改め ◆    |   |
|   |                                           |   |
|   |          +---------------------+          |   |
|   |          |  結 成  2  年 目    |          |   | <- 寄席の「めくり大札」
|   |          |     春 ・ 開 幕     |          |   |    (1年目→2年目へパタンと反転)
|   |          +---------------------+          |   |    右上に朱印 [開幕]
|   |       あなたのコンビ / 第1週 稽古始め      |   |
|   +===========================================+   | 254pt
|                                                   |
|   +-------------------------------------------+   | 270pt
|   | ■ 前年からの引き継ぎ資産 (YoseHarigami)    |   |
|   |  [実力・知名度・資金・持ちネタをすべて継承] |   | <- YoseTag(.solidEnji)
|   |  +-----------+ +-----------+ +----------+ |   |
|   |  | 最高実力  | |  知名度   | |  所持金  | |   | <- 3連木札 (yoseKifuda)
|   |  |   104     | |    32     | |  ¥15万   | |   |    22pt Heavy 等幅数字
|   |  +-----------+ +-----------+ +----------+ |   |
|   |  +--------------------------------------+ |   |
|   |  | [新春の備え] 体力全回復 100 / 持ちネタ 4本 | |   | <- 4月年初処理の可視化
|   |  +--------------------------------------+ |   |
|   +-------------------------------------------+   | 520pt
|                                                   |
|   +-------------------------------------------+   | 536pt
|   | [相方][谷口] (YoseSpeechBox 最小高さ88pt)  |   | <- 顔なし・めくり名札＋明朝体
|   | 「二年目の春やな。去年の悔しさ、           |   |
|   |   今年の舞台で全部ひっくり返したろやないか」|   |
|   +-------------------------------------------+   | 632pt
|                                                   |
|   +===========================================+   | 726pt
|   |           2年目を始める ▶ (54pt)           |   | <- YoseButtonStyle(.primary)
|   +===========================================+   | 780pt
+---------------------------------------------------+ 792pt
| [792-852pt] ⑥ YoseVitalMoneyBar (体力100/所持金)   |
+---------------------------------------------------+ 852pt
```

---

### ■ 部品と動きの秒数（タイムライン：入場 `0.65秒` → タップ1回で開始）

| 秒数 | 部品 | 動き・Haptics・SE |
| :--- | :--- | :--- |
| **`0.00s〜0.22s`** | **定式幕の引き締め（黒・柿・萌黄）** | 年末リザルトでボタンを押した瞬間、左右から定式幕が `0.22s`（`.easeIn`）で中央へ閉まり、「1年の締め」を物理的に区切る。`UIImpactFeedbackGenerator(style: .rigid)` 発火。 |
| **`0.22s〜0.44s`** | **幕開き ＋ めくり大札の反転** | 定式幕が左右へサッと開き（`0.22s` `.easeOut`）、中央の寄席めくり札が3D回転（`rotation3DEffect` X軸 `-90度 -> 0度`、`0.24s` spring）して『結成 1年目』から『結成 2年目』へパタンとめくれる。 |
| **`0.48s`** | **朱印『開幕』叩きつけ ＋ 3連木札出現** | めくり札の右上に `YoseHankoStamp("開幕", angle: -6)` が `scale(2.2 -> 1.0)` で叩きつけられ、引き継ぎ3連木札と相方の明朝体セリフ箱が揃う。`UINotificationFeedbackGenerator().notificationOccurred(.success)` 発火。 |
| **いつでも（`0.15s〜`）** | **1タップで新年開始（スキップ兼用）** | 幕が開き始めた後、**下部ボタン「2年目を始める ▶」または画面のどこをタップしても即座に（1タップで）**幕間を閉じ、新年の第1週メイン画面へ遷移する。 |

---

### ■ SwiftUI コード（そのまま動く粒度：`YearTurnCurtainView.swift`）

```swift
import SwiftUI
import UIKit

// MARK: - 年変わり幕間データモデル

public struct YearTurnSummary {
    public let combiName: String
    public let previousYear: Int
    public let newYear: Int
    public let power: Int
    public let fame: Int
    public let money: Int
    public let netaCount: Int
    public let maxStamina: Int
    public let isSeeded: Bool        // 前年準々決勝以上で1回戦シード権獲得か
    public let partnerName: String   // "谷口" など
    public let partnerLine: String   // 新年の抱負セリフ

    public init(
        combiName: String,
        previousYear: Int,
        newYear: Int,
        power: Int,
        fame: Int,
        money: Int,
        netaCount: Int,
        maxStamina: Int = 100,
        isSeeded: Bool = false,
        partnerName: String = "谷口",
        partnerLine: String = "新しい年の幕開けや。去年蓄えたもん全部ぶつけて、今年こそ頂点獲りに行くで。"
    ) {
        self.combiName = combiName
        self.previousYear = previousYear
        self.newYear = newYear
        self.power = power
        self.fame = fame
        self.money = money
        self.netaCount = netaCount
        self.maxStamina = maxStamina
        self.isSeeded = isSeeded
        self.partnerName = partnerName
        self.partnerLine = partnerLine
    }
}

// MARK: - 年が変わる時の幕間ビュー（49_複数年_2年目 完全改修版）

public struct YoseYearTurnCurtainView: View {
    let summary: YearTurnSummary
    let onStartNewYear: () -> Void

    @State private var curtainClosed: Bool = true
    @State private var mekuriFlipped: Bool = false
    @State private var contentAppeared: Bool = false
    @State private var stamped: Bool = false
    @State private var hasTriggeredStart: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(summary: YearTurnSummary, onStartNewYear: @escaping () -> Void) {
        self.summary = summary
        self.onStartNewYear = onStartNewYear
    }

    public var body: some View {
        ZStack {
            // 基本背景（生成り和紙）
            YoseColor.kinari.ignoresSafeArea()

            VStack(spacing: 0) {
                // ① 最上部ヘッダー帯 (48pt)
                YoseHeaderBar(title: "新シーズン開幕", subtitle: "\(summary.combiName)")

                // ② 定式幕ヘッダー (18pt)
                joshikimakuHeader

                // メインコンテンツ領域
                VStack(spacing: 14) {
                    // ③ 黒漆・寄席めくり看板（1年目 → 2年目 反転演出）
                    mekuriStageBoard

                    // ④ 前年からの引き継ぎ資産カード（3連木札＋引き継ぎ明示タグ）
                    carryOverCard

                    // ⑤ 相方の新春セリフ枠（顔なし・めくり名札＋明朝体・最小高さ88pt固定）
                    partnerResolutionBox

                    Spacer(minLength: 0)

                    // ⑥ 主ボタン（YoseButtonStyle(.primary) 完全準拠・高さ54pt）
                    Button(action: triggerStart) {
                        HStack(spacing: 8) {
                            Text("\(summary.newYear)年目を始める")
                                .font(YoseFont.gothic(18, weight: .heavy))
                            Image(systemName: "play.fill")
                                .font(.system(size: 13, weight: .black))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                    }
                    .buttonStyle(YoseButtonStyle(.primary))
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 12)

                // ⑦ 最下部ステータス黒帯（体力100/100全回復と所持金を常時表示）
                YoseVitalMoneyBar(
                    stamina: summary.maxStamina,
                    maxStamina: summary.maxStamina,
                    money: summary.money,
                    fame: summary.fame
                )
            }

            // 開幕時の左右引き幕（定式幕ワイプ：0.22sで閉じて0.22sで開く）
            GeometryReader { geo in
                HStack(spacing: 0) {
                    curtainPanel
                        .frame(width: geo.size.width / 2)
                        .offset(x: curtainClosed ? 0 : -geo.size.width / 2 - 10)

                    curtainPanel
                        .frame(width: geo.size.width / 2)
                        .offset(x: curtainClosed ? 0 : geo.size.width / 2 + 10)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        // 画面のどこをタップしても1回で即座に新年の第1週へ進める（最小の手間）
        .contentShape(Rectangle())
        .onTapGesture {
            triggerStart()
        }
        .task {
            await playTransitionSequence()
        }
    }

    // MARK: - ② 定式幕ヘッダー (18pt)

    private var joshikimakuHeader: some View {
        let colors: [Color] = [
            YoseColor.kuroUrushi,
            YoseColor.shu,
            YoseColor.tokiwa,
            YoseColor.kuroUrushi,
            YoseColor.shu,
            YoseColor.tokiwa
        ]
        return HStack(spacing: 0) {
            ForEach(0..<18, id: \.self) { idx in
                Rectangle().fill(colors[idx % colors.count])
            }
        }
        .frame(height: 18)
        .overlay(alignment: .bottom) {
            Rectangle().fill(YoseColor.sumi).frame(height: 2)
        }
    }

    // MARK: - ③ 黒漆・年次めくり大看板

    private var mekuriStageBoard: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Rectangle().fill(YoseColor.kin).frame(width: 18, height: 1.5)
                    Text("寄席・年次改め")
                        .font(YoseFont.gothic(12, weight: .heavy))
                        .tracking(1.5)
                        .foregroundStyle(YoseColor.kin)
                    Rectangle().fill(YoseColor.kin).frame(width: 18, height: 1.5)
                }

                // めくり札本体（前年 → 新年へパタンと縦反転）
                ZStack {
                    VStack(spacing: 4) {
                        // めくり上部の黒漆留め木
                        Rectangle()
                            .fill(YoseColor.shu)
                            .frame(height: 8)
                            .overlay(
                                Rectangle()
                                    .fill(YoseColor.kin)
                                    .frame(width: 24, height: 2)
                            )
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(YoseColor.sumi).frame(height: 1.5)
                            }

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("結成")
                                .font(YoseFont.mincho(18))
                                .foregroundStyle(YoseColor.sumi)
                            Text("\(mekuriFlipped ? summary.newYear : summary.previousYear)")
                                .font(YoseFont.number(38, weight: .black))
                                .foregroundStyle(YoseColor.shu)
                                .contentTransition(.numericText(value: Double(mekuriFlipped ? summary.newYear : summary.previousYear)))
                            Text("年目")
                                .font(YoseFont.mincho(20))
                                .foregroundStyle(YoseColor.sumi)
                        }
                        .padding(.top, 2)

                        Text(mekuriFlipped ? "春 ・ 第1週 開幕" : "全日程 終了")
                            .font(YoseFont.gothic(12, weight: .heavy))
                            .foregroundStyle(YoseColor.haiSumi)
                            .padding(.bottom, 8)
                    }
                    .frame(width: 210)
                    .background(YoseColor.washi)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    .background(Rectangle().fill(YoseColor.sumi).offset(y: 3))
                    .rotation3DEffect(
                        .degrees(mekuriFlipped ? 0 : -85),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .top,
                        perspective: 0.4
                    )
                }

                Text("舞台の幕が上がり、新しい1年の興行が始まります")
                    .font(YoseFont.gothic(11, weight: .bold))
                    .foregroundStyle(YoseColor.kinari.opacity(0.85))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background(YoseColor.kuroUrushi)
            .overlay(
                Rectangle()
                    .stroke(YoseColor.kin, lineWidth: 1.5)
                    .padding(4)
            )
            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
            .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))

            // 右上朱印『開幕』
            YoseHankoStamp(text: "開幕", isSquare: false, angle: -6)
                .modifier(YoseStampImpactModifier(isStamped: stamped))
                .offset(x: -12, y: 10)
        }
    }

    // MARK: - ④ 引き継ぎ資産3連木札カード

    private var carryOverCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 見出し行＋引き継ぎ明示タグ
            HStack {
                HStack(spacing: 6) {
                    Rectangle().fill(YoseColor.shu).frame(width: 4, height: 16)
                    Text("\(summary.previousYear)年目の到達と引き継ぎ")
                        .font(YoseFont.gothic(15, weight: .heavy))
                        .foregroundStyle(YoseColor.sumi)
                }
                Spacer()
                YoseTag(text: "実力・資金・ネタを継承", style: .solidEnji)
            }

            // 3連独立木札（実力 / 知名度 / 所持金）
            HStack(spacing: 8) {
                metricKifuda(
                    label: "引き継ぎ実力",
                    valueText: "\(summary.power)",
                    accent: YoseColor.enji
                )
                metricKifuda(
                    label: "知名度",
                    valueText: "\(summary.fame)",
                    accent: YoseColor.sumi
                )
                metricKifuda(
                    label: "所持金",
                    valueText: Self.compactYen(summary.money),
                    accent: YoseColor.sumi
                )
            }

            // 新春の備え（年初処理の明示：体力全回復・持ちネタ数・シード権）
            HStack(spacing: 8) {
                YoseTag(text: "新春の備え", style: .outlineSumi)
                Text("体力 \(summary.maxStamina)/\(summary.maxStamina) 全回復 ・ 持ちネタ \(summary.netaCount)本")
                    .font(YoseFont.gothic(12, weight: .bold))
                    .foregroundStyle(YoseColor.sumi)
                Spacer(minLength: 0)
                if summary.isSeeded {
                    YoseTag(text: "GP1回戦シード", style: .outlineShu)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(YoseColor.ki.opacity(0.45))
            .overlay(Rectangle().stroke(YoseColor.kiDark, lineWidth: 1))
        }
        .padding(12)
        .yoseHarigami(isFeatured: true)
        .opacity(contentAppeared ? 1.0 : 0.0)
        .offset(y: contentAppeared ? 0 : 10)
    }

    private func metricKifuda(label: String, valueText: String, accent: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(YoseFont.gothic(11, weight: .bold))
                .foregroundStyle(YoseColor.haiSumi)
                .lineLimit(1)

            Text(valueText)
                .font(YoseFont.number(22, weight: .black))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .yoseKifuda(showNail: true)
    }

    // MARK: - ⑤ 相方の新年の抱負セリフ（最小高さ88pt固定・顔なしめくり札）

    private var partnerResolutionBox: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // 相方めくり名札
            VStack(spacing: 2) {
                Text("相方")
                    .font(YoseFont.gothic(9, weight: .heavy))
                    .foregroundStyle(YoseColor.kin)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(YoseColor.kuroUrushi)

                Text(summary.partnerName)
                    .font(YoseFont.mincho(15))
                    .foregroundStyle(YoseColor.kinari)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .frame(minWidth: 58)
                    .background(YoseColor.shu)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
            }
            .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))

            // セリフ枠（最小高さ88pt固定・ハードシャドウ2pt）
            HStack(alignment: .bottom, spacing: 6) {
                Text(summary.partnerLine)
                    .font(YoseFont.mincho(15))
                    .lineSpacing(6)
                    .foregroundStyle(YoseColor.sumi)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(YoseColor.shu)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 88, alignment: .topLeading)
            .yoseHarigami()
        }
        .opacity(contentAppeared ? 1.0 : 0.0)
        .offset(y: contentAppeared ? 0 : 10)
    }

    // MARK: - 引き幕（定式幕）パネル

    private var curtainPanel: some View {
        let colors: [Color] = [
            YoseColor.kuroUrushi,
            YoseColor.shu,
            YoseColor.tokiwa,
            YoseColor.kuroUrushi,
            YoseColor.shu
        ]
        return HStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { i in
                Rectangle()
                    .fill(colors[i % colors.count])
                    .overlay(alignment: .trailing) {
                        Rectangle().fill(YoseColor.sumi.opacity(0.5)).frame(width: 2)
                    }
            }
        }
        .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 2))
    }

    // MARK: - タイムライン制御（0.65秒・1タップ即開始）

    private func playTransitionSequence() async {
        if reduceMotion {
            curtainClosed = false
            mekuriFlipped = true
            contentAppeared = true
            stamped = true
            return
        }

        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()

        // 0.18s: 閉じた定式幕が左右へ開く
        try? await Task.sleep(nanoseconds: 180_000_000)
        withAnimation(.easeOut(duration: 0.22)) {
            curtainClosed = false
        }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            contentAppeared = true
        }

        // 0.30s: めくり札が「1年目」→「2年目」へパタンと反転
        try? await Task.sleep(nanoseconds: 120_000_000)
        withAnimation(.spring(response: 0.24, dampingFraction: 0.65)) {
            mekuriFlipped = true
        }

        // 0.48s: 『開幕』朱印スタンプ叩きつけ
        try? await Task.sleep(nanoseconds: 180_000_000)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
            stamped = true
        }
    }

    private func triggerStart() {
        guard !hasTriggeredStart else { return }
        hasTriggeredStart = true
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        onStartNewYear()
    }

    private static func compactYen(_ yen: Int) -> String {
        if abs(yen) >= 10_000 {
            let man = Double(yen) / 10_000.0
            if man == man.rounded() {
                return "¥\(Int(man))万"
            }
            return String(format: "¥%.1f万", man)
        }
        return "¥\(yen.formatted(.number))"
    }
}
```

---

# 3) 既存画面（`RootView` / `WeekMainView`）への接続箇所（最小差分）

ゲームの決まり（乱数・数値・行動）に一切触れず、UI層だけで上記2画面を差し込む接続コードです。

```swift
// 1. RootView.swift：年末リザルトの「2年目へ ▶」から幕間を挟んで startNextYear() を呼ぶ
@State private var pendingYearTurn: YearTurnSummary? = nil

// YearResultView の onNextYear クロージャ内：
onNextYear: session.careerOver ? nil : {
    let s = session.state
    let o = session.outcome
    let currentPower = Int(GameEngine.jitsuryoku(s, config: session.config).rounded())
    pendingYearTurn = YearTurnSummary(
        combiName: session.combiName,
        previousYear: session.year,
        newYear: session.year + 1,
        power: currentPower,
        fame: Int(s.fame.rounded()),
        money: s.money,
        netaCount: s.netas.count,
        maxStamina: session.config.maxStamina,
        isSeeded: (o?.roundsPassed ?? 0) >= 3
    )
    session.startNextYear() // ゲームエンジン側の年初処理を確定（ルール不変）
}

// RootView の .overlay で pendingYearTurn がある間だけ幕間を表示：
.overlay {
    if let summary = pendingYearTurn {
        YoseYearTurnCurtainView(summary: summary) {
            pendingYearTurn = nil
        }
    }
}
```

```swift
// 2. AbilityUpView.swift / WeekMainView.swift：ランクアップ検知時に YoseRankUpOverlay を重ねる
@State private var rankUpItems: [RankUpItem] = []

// 能力変化の確定時に全5能力の before / after を比較し、一括配列を作る（連続昇格も1回に統合）：
let items: [RankUpItem] = Ability.allCases.compactMap { a in
    let from = Theme.rank(beforeState[a])
    let to = Theme.rank(afterState[a])
    guard from != to else { return nil }
    return RankUpItem(
        abilityName: "\(a)",
        abilityShort: Theme.abilityChar(a),
        abilityColor: Theme.abilityColor(a),
        fromRank: from,
        toRank: to,
        beforeValue: Int(beforeState[a].rounded()),
        afterValue: Int(afterState[a].rounded())
    )
}
if !items.isEmpty {
    rankUpItems = items
}
```
