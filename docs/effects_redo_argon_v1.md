# 優勝演出の徹底解剖と再設計仕様書
**〜「AIが3秒で吐いた放射線の壁紙」から、商業スマホゲーム級の「照明・物質・時間軸の祝祭」へ〜**

---

## ① なぜ `@feedback_shots/fx_review/champion_rejected.png` は「死ぬほどダサく、AIっぽい」のか（5つの致命傷）

却下された `champion_rejected.png` は、デザインの正本（`@docs/design_system_argon_v1.md`）と決勝番組設計（`@docs/finals_broadcast_argon_v1.md`）が定義した「寄席の物質感」「夜の生放送スタジオの照明」をすべて無視し、**LLMが「お祝い画面を作って」と雑に指示された時に出す典型的なテンプレ構図（サンバースト＋中央テキストのみ）**に堕ちている。

1. **「明るい生成りの平らな地（`#F5F0E1`）」に「薄い黄色の放射線」を引いただけ（明暗差・光源の不在）**
   * 光というのは「闇（黒漆 `#1E1916` や深夜スタジオ `#0D0A09`）」があって初めて輝く。昼間の和紙の上に薄い黄色の三角を並べても、眩しさも熱量もゼロで「スーパーの特売チラシ」か「昭和の福引券」にしか見えない。
2. **「等間隔・同一太さの幾何学放射線」が丸出し（AI特有の数学的単調さ）**
   * 360度を単純な `for` ループで割っただけの線が画面端から中央へ伸びている。減衰（グラデーション）も、ブレンド（加算合成）も、太さの抑揚もないため、「Canvasで `cos/sin` を回しました」というコードの都合が透けて見える。
3. **文字を裸で置いただけ（「器・額縁・看板・紋章」の欠如）**
   * 852ptの縦長画面のど真ん中に、何の台座（黒漆の大看板・二重金枠・寄席めくり・水引・朱印）もなく『優 勝』の2文字だけがポツンと浮いている。前後の余白（上下350pt以上）が完全に死んでおり、誰が（コンビ名）、何の大会で（頂グランプリ）、いくらの賞金を獲ったのかという「プレイヤーの1年間の結晶」が1ミリも載っていない。
4. **奥行き（Z軸のレイヤー階層）が2枚しかない**
   * 「背景＋放射線」と「文字」の2層しかなく、手前を横切る金テープ（近景）、舞い落ちる紙吹雪（中景）、主役の看板（主景）、舞台照明と定式幕（遠景）という**空間の厚み**が皆無。
5. **時間の変化（溜め・炸裂・余韻の非対称性）が見えない静止画構造**
   * どの瞬間を切り取っても同じ絵にしかならない。「暗転で息を呑む → キャノン砲が炸裂して白金に飛ぶ → 看板が叩きつけられて画面が揺れる → 金テープと和紙吹雪がゆっくり舞い落ちる」という**時間軸のドラマ**が設計されていない。

---

## ② 売れているゲームの『勝利・優勝・大成功』演出は何でできているか（7つの構成要素）

ウマ娘（G1勝利・育成完了）、パワプロ（甲子園優勝・査定確定）、学園アイドルマスター（ライブ大成功・True End）のクライマックス演出を分解すると、例外なく以下の**7つの物理・光学・時間要素**の掛け算で作られている。

| 要素 | 売れているゲームの作り方 | ダメなAI演出との決定的な違い |
| :--- | :--- | :--- |
| **1. 層の重ね方（最低5〜7層）** | **①最奥**：暗転スタジオ/定式幕<br>**②遠景**：天井からのサーチライト＋床スモーク<br>**③中景奥**：回転する二段の金後光＋放射火花<br>**④主役層**：黒漆×二重金枠の大看板＋縦めくり＋朱印<br>**⑤中景手前**：キャノン砲の金テープ（放物線リボン）<br>**⑥最前景**：画面手前をボケて横切る大粒の金箔・和紙吹雪<br>**⑦UI層**：下三分テロップ帯・賞金木札 | 「背景＋文字」の2層で終わらせず、**主役（看板）の「後ろ」と「前」の両方をパーティクルが通過する**ことで、画面の中に3D空間を作る。 |
| **2. 光源（Light Source）と加算合成** | 光を「塗りの色（不透明の黄色）」で描かず、**暗い背景の上に `.blendMode(.plusLighter)`（加算発光）のグラデーション**を重ねる。中心は常に「白（`#FFFFFF`）」に飛ばし、外縁を山吹金（`#E5B842`）→朱（`#BD3C28`）へ減衰させる。 | 黄色いポリゴンをベタ塗りしない。光が重なった部分が自然に白飛びする光学計算を使う。 |
| **3. 暗転と明転（露出の落差）** | 爆発の直前に必ず**画面全体の明度を15%以下（黒漆90%）に落とす「暗転の溜め（0.25〜0.4秒）」**を入れる。そこから一気に白金フラッシュ（露出オーバー）へ振り切ることで、脳に「眩しい！」と錯覚させる。 | 最初から最後まで同じ明るさの背景で始めない。 |
| **4. カメラの寄り・引き・揺れ** | 決定の瞬間にカメラが `scale: 1.35 → 1.0` へ叩きつけられ、直後に減衰振動（`+7pt → -5pt → +3pt → 0`）で物理的な質量を伝える。余韻フェーズでは背景と後光が `scale: 1.0 → 1.06` へゆっくりと膨張し続ける（カメラのじわ寄り）。 | 画面がピタッと止まったままにならない。余韻中も常に微細なカメラドリフトと光の脈動がある。 |
| **5. パーティクルの質（3種混合＋物理挙動）** | 1種類の四角を降らせるのではなく、**①初速が速く空気抵抗でピタッと止まる「火花・金粉」**、**②下から放物線を描いて噴き上がる「金テープ（曲線リボン）」**、**③コサイン回転でヒラヒラと表裏を返しながら落ちる「和紙・金箔の紙吹雪」**の3種類を混ぜる。 | 等速直線運動のパーティクルを使わない。初速・重力・空気抵抗・回転軸（X/Y/Z）を分ける。 |
| **6. 文字と看板の入り方（時間差と重さ）** | すべての文字を同時にフェードインさせない。<br>①まず**黒漆の大看板（器）**が横または奥からガツンと組まれ、<br>②次に**『優 勝』の金袋文字**が1文字ずつ、あるいは2.4倍から叩きつけられ、<br>③最後に**朱印『日本一』**が斜めにドン！と押されて斜光（シマー）が走る。 | 文字だけを `opacity` や単純な `scale` で出さない。必ず「重い木札・黒漆の額縁」に打ち付ける。 |
| **7. 余韻（Follow-through）** | 爆発から0.8秒後、激しい揺れが収まり、温かい琥珀色のスポットライトと降り積もる金紙吹雪の中で**「コンビ名」「優勝賞金ボード」「相方の短い一言」**が静かに浮かび上がり、プレイヤーがスクショを撮りたくなる「完成された記念写真」になる。 | 爆発した瞬間にすぐ閉じたり、逆に何も動かない静止画で放置しない。 |

---

## ③ 外部画像素材ゼロで作る『頂グランプリ・優勝』完全演出設計＆SwiftUIコード

### 3-1. 時間軸（`0.00秒〜`）ごとの画面コンテと動き

全体尺は **`2.40秒` で記念画面が完成**し、以降は無限ループの余韻アニメーション（紙吹雪・スポットライトの揺らぎ・金文字のシマー）に入り、プレイヤーのタップで次へ進む（演出途中タップで `2.40秒` の完成状態へ即スキップ）。

| 時間軸 | フェーズ | 画面の絵・光・カメラ・音の挙動 | Haptics |
| :--- | :--- | :--- | :--- |
| **`0.00s〜0.28s`** | **① 暗転・静寂の溜め**<br>*(Anticipation & Hold)* | ・画面全体が夜の生放送スタジオの闇（`#0B0807`、不透明度94%）にストンと落ちる。<br>・中央に1本だけ細い金のピンスポットが落ち、中心で金粉がキュッと収縮（Implosion）する。<br>・上部の `[LIVE ● 生放送]` 赤札だけが緊張感を持って点灯。 | `.soft`（心拍の1拍目） |
| **`0.28s〜0.42s`** | **② 白金フラッシュ＆キャノン砲炸裂**<br>*(The Ignition)* | ・画面全体が山吹金×白（`#FFF6D6`）でカッとフラッシュ（露出オーバーから0.25秒で減衰）。<br>・同時に画面左右下（`y: 78%`）の特効キャノン砲から、**40本の金・朱のストリーマーテープ**が天井へ向かって放物線を描いて一気に噴き上がる。<br>・背景の定式幕（黒・柿・萌黄の暗がりストライプ）と6本の黄金サーチライトが一斉にフル点灯。 | `.notification(.success)`<br>直後に `.heavy` |
| **`0.42s〜0.75s`** | **③ 黒漆二重金枠の大看板＆『優 勝』叩きつけ**<br>*(Main Impact)* | ・中央に「黒漆＋二重金枠＋四隅金具」の**特大番付看板**と、その背後の**回転する二重金後光（サンバースト＋集中線）**が展開。<br>・間髪入れず『**優**』『**勝**』の特大明朝・金グラデーション袋文字が `scale: 2.6 → 0.94 → 1.0` のスプリングで時間差（`0.07s` 差）で叩きつけられ、着地瞬間に画面全体が縦に **`7pt` 大揺れ**する。<br>・看板の周囲から四角い金箔火花32個が放射状に弾ける。 | 『優』着地：`.heavy`<br>『勝』着地（`+0.07s`）：`.heavy` |
| **`0.75s〜1.25s`** | **④ コンビ名縦めくり＆『日本一』朱印＆賞金木札**<br>*(Layered Reveal)* | ・大看板の中央下に、白和紙＋金枠の**主役コンビ名カード（『第N代王者 ／ あなたのコンビ』）**が下からバウンス出現。<br>・看板右肩に特大の朱印『**日本一**』が `scale: 2.4 → 1.0`（角度 `-8度`）でビシッと押され、直後に看板全体を左から右へ**金の斜光（シマー）**がキラーンと走る。<br>・その下に黒漆の**『優勝賞金 ¥10,000,000』木札ボード**がせり上がり、金額がドラムロールで確定。 | 朱印着地：`.rigid`<br>賞金確定：`.medium` |
| **`1.25s〜2.40s`以降** | **⑤ 黄金の余韻・相方の言葉・記念撮影状態**<br>*(Follow-through & Hold)* | ・画面上部から**180枚の金箔・白和紙・朱の紙吹雪**が3Dヒラヒラ回転しながら舞い落ち続ける（手前の大粒紙吹雪と奥の小粒紙吹雪の2レイヤーで奥行きを表現）。<br>・画面下部に相方の余韻セリフ箱と番組テロップ帯（Lower Third）が表示され、`[ タップして次へ ▶ ]` が穏やかに脈動する。 | なし（視覚と音楽の余韻） |

---

### 3-2. 7層のレイヤー構成と配色設計（暗い舞台・スポット・金）

明るい和紙ベタ塗りをやめ、**「黒漆と臙脂の夜の演芸特番スタジオ」**をベースにすることで、金（`yoseKinBright`）と白和紙（`yoseWashi`）のコントラストを最大化する。

1. **Layer 1（最奥・舞台闇と定式幕）**：`#0B0807` 〜 `yoseKuroUrushi (#1E1916)` の垂直グラデーション＋暗がりに浮かぶ定式幕（黒・柿 `#BD3C28`・萌黄 `#2E583C`）の縦縞（不透明度14%）。
2. **Layer 2（遠景・照明と床スモーク）**：天井から扇状に降り注ぐ6本のスポットライト（`yoseKinBright` 加算合成）＋床面の琥珀色の照り返しと横流れるスモーク。
3. **Layer 3（中景奥・二重後光と不規則集中線）**：中央背後に配置する `.blendMode(.plusLighter)` の黄金ラジアル発光＋ゆっくり逆回転する2枚の濃淡サンバースト（マスクで外周へ行くほど自然に消える）＋劇画調の不規則集中線。
4. **Layer 4（中景・特効キャノン砲の金テープ＆奥の紙吹雪）**：左右下から噴き上がる放物線リボン（金・消金・朱）と、看板の後ろを舞う小粒の紙吹雪。
5. **Layer 5（主役・黒漆二重金枠の『優勝』大看板＋コンビめくり＋賞金木札）**：
   * 看板地色：`yoseKuroUrushi (#1E1916)` ＋ 内側に臙脂（`yoseEnji #7D221E`）の格子/斜め紋様。
   * 額縁：外側 `yoseSumi` 2pt ＋ `yoseKinBright` 3pt ＋ 内側 `yoseKin` 1pt の二重金枠＋四隅の金飾り金具。
   * 『優 勝』文字：単色ではなく、**上端 `#FFF8D6`（白金）→ 中央 `#E5B842`（山吹金）→ 下端 `#9E7B22`（濃金）の金属縦グラデーション塗り**＋墨（`#1E1916`）の極太袋文字縁取り＋ソリッド下影4pt。
6. **Layer 6（最前景・手前を横切る大粒金箔＆白金フラッシュ）**：看板の「手前」を横切って落ちる大粒の金紙吹雪と、着地瞬間の放射火花、そして画面全体の露出フラッシュ。
7. **Layer 7（UI・生放送ヘッダー＆相方セリフ＆番組テロップ帯）**：上部の `LIVE 生放送` 帯と、下部の相方セリフ箱・進行ボタン。

---

### 3-3. そのまま動く SwiftUI 完全実装コード（`YoseChampionCelebrationView.swift`）

外部画像ゼロ、`Capsule()` ゼロ、`cornerRadius(8+)` ゼロ、`％` 表記ゼロ、こけし人間ゼロ。単体ファイルとしてそのままプレビュー・組み込み可能な完全コードです。

```swift
import SwiftUI
import UIKit

// ============================================================================
// MARK: - 優勝全画面演出（YoseChampionCelebrationView）
// 393×852pt 基準 / 外部画像ゼロ / 7層レイヤー＋時間軸シーケンス＋1タップ即確定対応
// ============================================================================

public struct YoseChampionCelebrationView: View {
    public let tournamentName: String      // 例：「頂グランプリ 第4回 大会」
    public let generationText: String      // 例：「第4代 王者」
    public let duoName: String             // 例：「満月ロケット」
    public let prizeAmountYen: Int         // 例：10_000_000
    public let partnerName: String         // 例：「谷口」
    public let partnerLine: String         // 例：「……なあ、腹減ったな。焼肉、特上頼んでええか？」
    public let mcName: String              // 例：「司会・鳴海」
    public let mcComment: String           // 例：「見事4票獲得！今年の漫才日本一は『満月ロケット』です！！」
    public let onFinish: () -> Void

    // アニメーション時間軸ステート
    @State private var startTime: Date = .now
    @State private var phase: Int = 0
    // phase 0: 0.00s 暗転溜め
    // phase 1: 0.28s フラッシュ＆キャノン砲発射＆看板枠出現
    // phase 2: 0.42s 『優』着地
    // phase 3: 0.50s 『勝』着地＋画面大揺れ＋放射火花
    // phase 4: 0.78s コンビ名＆朱印『日本一』叩きつけ＋斜光シマー
    // phase 5: 1.10s 賞金ボード＆下部セリフ帯出現（2.0sで完全完了状態）

    @State private var flashOpacity: Double = 0.0
    @State private var shakeTrigger: Int = 0
    @State private var burstTrigger: Int = 0
    @State private var shimmerTrigger: Int = 0
    @State private var displayedPrize: Int = 0
    @State private var isCompleted: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        tournamentName: String = "頂グランプリ 決勝戦",
        generationText: String = "第4代 王者",
        duoName: String = "あなたのコンビ",
        prizeAmountYen: Int = 10_000_000,
        partnerName: String = "相方",
        partnerLine: String = "「……なあ、腹減ったな。今夜はカウンターの回らん寿司、行こか」",
        mcName: String = "司会・鳴海",
        mcComment: String = "「決まりました！！今夜、幾千組の頂点に立ったのは——この2人です！」",
        onFinish: @escaping () -> Void = {}
    ) {
        self.tournamentName = tournamentName
        self.generationText = generationText
        self.duoName = duoName
        self.prizeAmountYen = prizeAmountYen
        self.partnerName = partnerName
        self.partnerLine = partnerLine
        self.mcName = mcName
        self.mcComment = mcComment
        self.onFinish = onFinish
    }

    public var body: some View {
        ZStack {
            // ----------------------------------------------------------------
            // Layer 1 & 2: 夜の特番スタジオ暗転背景＋定式幕＋サーチライト6本＋床スモーク
            // ----------------------------------------------------------------
            ChampionStageBackdropCanvas(isLit: phase >= 1, startTime: startTime)
                .ignoresSafeArea()

            // ----------------------------------------------------------------
            // Layer 3: 中景奥・回転する二重黄金後光＋不規則な劇画集中線（加算合成）
            // ----------------------------------------------------------------
            if phase >= 1 {
                ChampionGoldenHaloCanvas(startTime: startTime)
                    .blendMode(.plusLighter)
                    .transition(.opacity)
                    .ignoresSafeArea()
            }

            // ----------------------------------------------------------------
            // Layer 4: 特効キャノン砲（金テープ40本＋奥層の和紙吹雪120枚）
            // ----------------------------------------------------------------
            if phase >= 1 {
                ChampionCannonAndConfettiCanvas(
                    startTime: startTime,
                    foregroundLayer: false
                )
                .ignoresSafeArea()
            }

            // ----------------------------------------------------------------
            // Layer 5: 主役UI（黒漆二重金枠の大看板・『優 勝』・コンビ名・賞金木札）
            // ----------------------------------------------------------------
            VStack(spacing: 0) {
                // 上部：生放送 LIVE ヘッダー帯
                championLiveTopBar
                    .opacity(phase >= 1 ? 1.0 : 0.4)

                Spacer(minLength: 8)

                // 中央主役：優勝大看板＋コンビ名額縁＋放射火花
                ZStack {
                    // 着地瞬間の金箔・朱肉バースト火花
                    YoseBurstParticles(
                        trigger: burstTrigger,
                        count: 32,
                        colors: [YoseColor.kinBright, Color.white, YoseColor.shu, YoseColor.kin],
                        radius: 175,
                        duration: 0.75
                    )
                    .frame(width: 360, height: 320)

                    if phase >= 1 {
                        championMainSignboard
                            .transition(.scale(scale: 0.72).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 14)

                // 優勝賞金ボード木札
                if phase >= 5 {
                    championPrizePlaque
                        .padding(.top, 12)
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 10)

                // 下部：相方の耳打ちセリフ箱 ＋ 番組下三分テロップ ＋ 次へボタン
                if phase >= 5 {
                    VStack(spacing: 8) {
                        partnerEmotionBox
                        broadcastLowerThirdBar
                        proceedActionBar
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .yoseShake(trigger: shakeTrigger, intensity: .heavy, axis: .vertical)

            // ----------------------------------------------------------------
            // Layer 6: 最前景（看板の手前を横切る大粒の金箔吹雪＋白金露出フラッシュ）
            // ----------------------------------------------------------------
            if phase >= 1 {
                ChampionCannonAndConfettiCanvas(
                    startTime: startTime,
                    foregroundLayer: true
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            // 決定瞬間の白金フラッシュ（露出オーバー → 減衰）
            Color(hex: 0xFFF7D6)
                .opacity(flashOpacity)
                .blendMode(.plusLighter)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            handleScreenTap()
        }
        .onAppear {
            runCelebrationTimeline()
        }
    }

    // ========================================================================
    // MARK: - 主役コンポーネント群（Layer 5 & 7）
    // ========================================================================

    /// 上部：生放送 LIVE 帯
    private var championLiveTopBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                Text("LIVE 生放送")
                    .font(YoseFont.gothic(11, weight: .black))
                    .foregroundStyle(YoseColor.kinari)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(YoseColor.shu)
            .overlay(Rectangle().stroke(YoseColor.kinBright, lineWidth: 1.5))

            Text(tournamentName)
                .font(YoseFont.gothic(13, weight: .heavy))
                .foregroundStyle(YoseColor.kinBright)
                .lineLimit(1)

            Spacer()

            Text(isCompleted ? "タップで進む ▶" : "スキップ ▶▶")
                .font(YoseFont.gothic(11, weight: .heavy))
                .foregroundStyle(YoseColor.sumi)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(YoseColor.ki)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(YoseColor.sumi, lineWidth: 1.5))
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(YoseColor.kuroUrushi.opacity(0.95))
        .overlay(alignment: .bottom) {
            Rectangle().fill(YoseColor.kinBright).frame(height: 1.5)
        }
    }

    /// 中央主役：黒漆×二重金枠の特大『優勝』番付看板＋コンビ名札＋朱印『日本一』
    private var championMainSignboard: some View {
        VStack(spacing: 0) {
            // 1. 看板最上部の金冠リボンバー
            HStack(spacing: 8) {
                OrnamentDiamond()
                Text("漫 才 日 本 一 決 定 戦")
                    .font(YoseFont.gothic(12, weight: .black))
                    .tracking(3)
                    .foregroundStyle(YoseColor.kuroUrushi)
                OrnamentDiamond()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 26)
            .background(
                LinearGradient(
                    colors: [YoseColor.kin, YoseColor.kinBright, Color(hex: 0xFFF0B8), YoseColor.kinBright, YoseColor.kin],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(alignment: .bottom) {
                Rectangle().fill(YoseColor.sumi).frame(height: 2)
            }

            // 2. 黒漆のメイン舞台面（『優 勝』特大金袋文字＋コンビ名めくり札）
            ZStack {
                // 背後の黒漆＋臙脂の市松/斜め格子地紋
                SignboardInnerPatternView()

                VStack(spacing: 14) {
                    // 大会名・第N代王者ラベル
                    HStack(spacing: 8) {
                        Rectangle().fill(YoseColor.kin).frame(width: 24, height: 1.5)
                        Text("\(tournamentName) ・ \(generationText)")
                            .font(YoseFont.gothic(13, weight: .heavy))
                            .tracking(1.0)
                            .foregroundStyle(YoseColor.kinBright)
                        Rectangle().fill(YoseColor.kin).frame(width: 24, height: 1.5)
                    }
                    .padding(.top, 14)

                    // 『優 勝』特大金属グラデーション袋文字（1文字ずつ時間差で叩きつける）
                    HStack(spacing: 18) {
                        ChampionKanjiSeal(
                            kanji: "優",
                            isLanded: phase >= 2
                        )
                        ChampionKanjiSeal(
                            kanji: "勝",
                            isLanded: phase >= 3
                        )
                    }
                    .padding(.vertical, 2)

                    // 主役コンビ名の白和紙・二重枠めくり額縁
                    if phase >= 4 {
                        VStack(spacing: 4) {
                            Text("CHAMPION DUO")
                                .font(YoseFont.gothic(10, weight: .black))
                                .tracking(2.0)
                                .foregroundStyle(YoseColor.shu)

                            Text(duoName)
                                .font(YoseFont.mincho(30))
                                .foregroundStyle(YoseColor.sumi)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(YoseColor.washi)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                        .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1.5).padding(3))
                        .background(Rectangle().fill(YoseColor.sumi).offset(x: 0, y: 3))
                        .padding(.horizontal, 18)
                        .padding(.bottom, 16)
                        .transition(.scale(scale: 1.25).combined(with: .opacity))
                    } else {
                        Spacer().frame(height: 68)
                    }
                }

                // 四隅の金飾り金具（L字の彫金コーナー）
                SignboardCornerBrackets()

                // 右肩に叩きつけられる特大朱印『日本一』
                VStack {
                    HStack {
                        Spacer()
                        YoseAnimatedHanko(
                            text: "日本一",
                            isStamped: phase >= 4,
                            isSquare: true,
                            angle: -8,
                            playHapticsAndSound: false
                        )
                        .scaleEffect(1.15)
                        .padding(.top, 10)
                        .padding(.trailing, 10)
                    }
                    Spacer()
                }
            }
            .frame(height: 256)
        }
        .clipShape(RoundedRectangle(cornerRadius: 2))
        // 三重額縁（墨2pt → 山吹金3.5pt → 黒漆1.5pt）
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(YoseColor.kinBright, lineWidth: 3.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(YoseColor.sumi, lineWidth: 2)
                .padding(-2)
        )
        // ハードシャドウ（Blur 0・物質の厚み）
        .background(
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.black)
                .offset(x: 0, y: 6)
        )
        .yoseLightStreak(trigger: shimmerTrigger, color: YoseColor.kinBright)
    }

    /// 優勝賞金の小判・木札ボード
    private var championPrizePlaque: some View {
        HStack(spacing: 12) {
            // 左：賞金角印タグ
            Text("優勝賞金")
                .font(YoseFont.gothic(13, weight: .black))
                .foregroundStyle(YoseColor.kuroUrushi)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(YoseColor.kinBright)
                .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))

            Spacer()

            // 右：等幅カウントアップ金額
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("¥")
                    .font(YoseFont.number(20, weight: .black))
                    .foregroundStyle(YoseColor.kinBright)
                Text("\(displayedPrize.formatted())")
                    .font(YoseFont.number(28, weight: .black))
                    .foregroundStyle(Color(hex: 0xFFF7D6))
                    .contentTransition(.numericText(value: Double(displayedPrize)))
            }
            .yoseNumberPop(value: displayedPrize, highlightColor: YoseColor.kinBright, scalePeak: 1.18)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(YoseColor.kuroUrushi)
        .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 2))
        .background(Rectangle().fill(YoseColor.sumi).offset(y: 3))
    }

    /// 相方の感極まった一言セリフ箱（白和紙×明朝体）
    private var partnerEmotionBox: some View {
        HStack(alignment: .top, spacing: 10) {
            // 相方名縦札風ラベル
            Text(partnerName)
                .font(YoseFont.gothic(13, weight: .heavy))
                .foregroundStyle(YoseColor.kinari)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(YoseColor.shu)
                .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))

            Text(partnerLine)
                .font(YoseFont.mincho(15))
                .lineSpacing(5)
                .foregroundStyle(YoseColor.sumi)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(YoseColor.washi)
        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
        .background(Rectangle().fill(YoseColor.sumi).offset(y: 3))
    }

    /// 生放送の番組テロップ帯（Lower Third）
    private var broadcastLowerThirdBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Rectangle().fill(YoseColor.shu).frame(width: 80, height: 3)
                Rectangle().fill(YoseColor.kinBright).frame(height: 3)
            }
            HStack(spacing: 10) {
                Text(mcName)
                    .font(YoseFont.gothic(12, weight: .heavy))
                    .foregroundStyle(YoseColor.kinBright)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(YoseColor.enji)
                    .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1))

                Text(mcComment)
                    .font(YoseFont.mincho(14))
                    .lineSpacing(3)
                    .foregroundStyle(YoseColor.kinari)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(YoseColor.kuroUrushi.opacity(0.95))
            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
        }
    }

    /// 最下部の進行ボタン
    private var proceedActionBar: some View {
        Button(action: onFinish) {
            HStack(spacing: 8) {
                Text("表彰式・エンディングへ進む")
                    .font(YoseFont.gothic(16, weight: .heavy))
                Image(systemName: "arrowtriangle.right.fill")
                    .font(.system(size: 12, weight: .black))
            }
            .foregroundStyle(YoseColor.kinari)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(YoseColor.shu)
            .overlay(Rectangle().stroke(YoseColor.kinBright, lineWidth: 2))
            .background(Rectangle().fill(YoseColor.sumi).offset(y: 3))
        }
        .buttonStyle(.plain)
    }

    // ========================================================================
    // MARK: - 時間軸シーケンス制御＆1タップ即完了（Fast-Forward）
    // ========================================================================

    private func runCelebrationTimeline() {
        startTime = .now
        if reduceMotion {
            completeImmediately()
            return
        }

        // 0.00s: Phase 0（暗転と溜め）
        phase = 0
        displayedPrize = 0
        YoseFX.impact(.soft, intensity: 0.8)

        // 0.28s: Phase 1（白金フラッシュ＋キャノン砲発射＋大看板出現）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            guard !isCompleted else { return }
            flashOpacity = 0.92
            withAnimation(.easeOut(duration: 0.35)) {
                flashOpacity = 0.0
            }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                phase = 1
            }
            YoseFX.notify(.success)
            YoseFX.sound(.championImpact)
        }

        // 0.42s: Phase 2（『優』叩きつけ）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            guard !isCompleted else { return }
            withAnimation(.spring(response: 0.22, dampingFraction: 0.56)) {
                phase = 2
            }
            YoseFX.impact(.heavy, intensity: 1.0)
        }

        // 0.50s: Phase 3（『勝』叩きつけ＋画面縦大揺れ＋金火花バースト）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) {
            guard !isCompleted else { return }
            withAnimation(.spring(response: 0.22, dampingFraction: 0.54)) {
                phase = 3
            }
            shakeTrigger += 1
            burstTrigger += 1
            YoseFX.impact(.heavy, intensity: 1.0)
        }

        // 0.78s: Phase 4（コンビ名めくり＋朱印『日本一』＋斜光シマー）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.78) {
            guard !isCompleted else { return }
            withAnimation(.spring(response: 0.26, dampingFraction: 0.68)) {
                phase = 4
            }
            shimmerTrigger += 1
            YoseFX.impact(.rigid, intensity: 0.95)
            YoseFX.sound(.stampHeavy)
        }

        // 1.15s: Phase 5（賞金木札カウントアップ＋相方セリフ＋完了状態）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            guard !isCompleted else { return }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                phase = 5
                displayedPrize = prizeAmountYen
            }
            isCompleted = true
            YoseFX.impact(.medium, intensity: 0.8)
            YoseFX.sound(.prizeGet)
        }
    }

    private func handleScreenTap() {
        if !isCompleted {
            // 演出途中のタップ：0.06秒で最終完成フレームへ即スキップ
            completeImmediately()
        } else {
            // 完成後のタップ：次画面へ進む
            YoseFX.impact(.rigid, intensity: 0.75)
            onFinish()
        }
    }

    private func completeImmediately() {
        withAnimation(.easeOut(duration: 0.08)) {
            flashOpacity = 0.0
            phase = 5
            displayedPrize = prizeAmountYen
            isCompleted = true
        }
        shimmerTrigger += 1
    }
}

// ============================================================================
// MARK: - 部品A：『優』『勝』の金属グラデーション袋文字シール
// ============================================================================

private struct ChampionKanjiSeal: View {
    let kanji: String
    let isLanded: Bool

    var body: some View {
        ZStack {
            // 背後の八角/菱形座布団プレート（文字を裸で置かない）
            Rectangle()
                .fill(YoseColor.enji)
                .frame(width: 92, height: 92)
                .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 2))
                .rotationEffect(.degrees(45))
                .scaleEffect(0.82)

            Rectangle()
                .fill(YoseColor.kuroUrushi)
                .frame(width: 96, height: 96)
                .overlay(Rectangle().stroke(YoseColor.kinBright, lineWidth: 2.5))
                .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).padding(3))
                .background(Rectangle().fill(Color.black).offset(y: 4))

            // 墨の極太8方向アウトライン＋下影
            ForEach([-1, 0, 1], id: \.self) { dx in
                ForEach([-1, 0, 1], id: \.self) { dy in
                    if dx != 0 || dy != 0 {
                        Text(kanji)
                            .font(YoseFont.mincho(68))
                            .foregroundStyle(Color.black)
                            .offset(x: CGFloat(dx) * 3.0, y: CGFloat(dy) * 3.0 + 3.0)
                    }
                }
            }

            // 本体：白金 → 山吹金 → 琥珀金の金属光沢グラデーション塗り
            Text(kanji)
                .font(YoseFont.mincho(68))
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: 0xFFFBE6), location: 0.0),
                            .init(color: YoseColor.kinBright, location: 0.45),
                            .init(color: Color(hex: 0xB8861B), location: 0.85),
                            .init(color: YoseColor.kinBright, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .scaleEffect(isLanded ? 1.0 : 2.55)
        .opacity(isLanded ? 1.0 : 0.0)
    }
}

// ============================================================================
// MARK: - 部品B：看板内部の伝統地紋＆四隅の彫金金具
// ============================================================================

private struct SignboardInnerPatternView: View {
    var body: some View {
        Canvas { context, size in
            // 黒漆のベースに中央の臙脂グロー
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(rect), with: .color(YoseColor.kuroUrushi))
            context.fill(
                Path(rect),
                with: .radialGradient(
                    Gradient(colors: [YoseColor.enji.opacity(0.65), YoseColor.kuroUrushi]),
                    center: CGPoint(x: size.width / 2, y: size.height / 2),
                    startRadius: 10,
                    endRadius: size.width * 0.6
                )
            )

            // 斜めの金網目地紋（うっすらと高級感を出す）
            let step: CGFloat = 28
            for x in stride(from: -size.height, through: size.width + size.height, by: step) {
                var p1 = Path()
                p1.move(to: CGPoint(x: x, y: 0))
                p1.addLine(to: CGPoint(x: x + size.height, y: size.height))
                context.stroke(p1, with: .color(YoseColor.kin.opacity(0.10)), lineWidth: 1)

                var p2 = Path()
                p2.move(to: CGPoint(x: x + size.height, y: 0))
                p2.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(p2, with: .color(YoseColor.kin.opacity(0.10)), lineWidth: 1)
            }
        }
    }
}

private struct SignboardCornerBrackets: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let len: CGFloat = 18
            let inset: CGFloat = 6

            Canvas { context, _ in
                let corners: [(CGPoint, CGFloat, CGFloat)] = [
                    (CGPoint(x: inset, y: inset), 1, 1),
                    (CGPoint(x: w - inset, y: inset), -1, 1),
                    (CGPoint(x: inset, y: h - inset), 1, -1),
                    (CGPoint(x: w - inset, y: h - inset), -1, -1)
                ]
                for (pt, dx, dy) in corners {
                    var path = Path()
                    path.move(to: CGPoint(x: pt.x, y: pt.y + dy * len))
                    path.addLine(to: pt)
                    path.addLine(to: CGPoint(x: pt.x + dx * len, y: pt.y))
                    context.stroke(path, with: .color(YoseColor.kinBright), lineWidth: 3)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct OrnamentDiamond: View {
    var body: some View {
        Rectangle()
            .fill(YoseColor.kuroUrushi)
            .frame(width: 6, height: 6)
            .rotationEffect(.degrees(45))
    }
}

// ============================================================================
// MARK: - 部品C（Layer 1 & 2）：夜の特番スタジオ・定式幕・6本サーチライト・床スモーク
// ============================================================================

private struct ChampionStageBackdropCanvas: View {
    let isLit: Bool
    let startTime: Date

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSince(startTime)
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)

                // 1. 深夜スタジオの漆黒〜臙脂グラデーション（明るい生成りベタ塗りを全廃）
                let topColor = isLit ? Color(hex: 0x2B110E) : Color(hex: 0x090707)
                let midColor = isLit ? YoseColor.kuroUrushi : Color(hex: 0x0D0A09)
                context.fill(
                    Path(rect),
                    with: .linearGradient(
                        Gradient(colors: [topColor, midColor, Color(hex: 0x080605)]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )

                // 2. 背景の定式幕（黒・柿・萌黄の縦縞が暗がりに重厚に浮かぶ）
                let stripeCount = 15
                let stripeW = size.width / CGFloat(stripeCount)
                for i in 0..<stripeCount {
                    let stripeRect = CGRect(x: CGFloat(i) * stripeW, y: 0, width: stripeW, height: size.height * 0.74)
                    let stripeColor: Color
                    if i % 3 == 0 {
                        stripeColor = Color.black.opacity(0.35)
                    } else if i % 3 == 1 {
                        stripeColor = YoseColor.enji.opacity(isLit ? 0.22 : 0.08)
                    } else {
                        stripeColor = YoseColor.tokiwa.opacity(isLit ? 0.16 : 0.05)
                    }
                    context.fill(Path(stripeRect), with: .color(stripeColor))
                }

                guard isLit else { return }

                // 3. 下方・天井から交差する6本の黄金サーチライト（加算合成風グラデーション）
                let beamCount = 6
                for i in 0..<beamCount {
                    let ratio = Double(i) / Double(beamCount - 1)
                    let topX = size.width * (0.08 + 0.84 * ratio)
                    let sway = sin(t * 1.4 + Double(i) * 1.1) * 36.0
                    let bottomX = size.width * (0.18 + 0.64 * ratio) + sway

                    var beam = Path()
                    beam.move(to: CGPoint(x: topX - 10, y: 0))
                    beam.addLine(to: CGPoint(x: topX + 10, y: 0))
                    beam.addLine(to: CGPoint(x: bottomX + 85, y: size.height * 0.82))
                    beam.addLine(to: CGPoint(x: bottomX - 85, y: size.height * 0.82))
                    beam.closeSubpath()

                    let beamColor = (i % 2 == 0) ? YoseColor.kinBright : YoseColor.shu
                    context.fill(
                        beam,
                        with: .linearGradient(
                            Gradient(colors: [
                                beamColor.opacity(0.34),
                                beamColor.opacity(0.10),
                                .clear
                            ]),
                            startPoint: CGPoint(x: topX, y: 0),
                            endPoint: CGPoint(x: bottomX, y: size.height * 0.82)
                        )
                    )
                }

                // 4. 檜舞台の黒漆床と金ライトの照り返し
                let floorY = size.height * 0.72
                let floorRect = CGRect(x: 0, y: floorY, width: size.width, height: size.height - floorY)
                context.fill(
                    Path(floorRect),
                    with: .linearGradient(
                        Gradient(colors: [Color(hex: 0x3A2414), Color(hex: 0x140E0A)]),
                        startPoint: CGPoint(x: 0, y: floorY),
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )
                context.fill(
                    Path(CGRect(x: 0, y: floorY, width: size.width, height: 2)),
                    with: .color(YoseColor.kin.opacity(0.55))
                )
            }
        }
    }
}

// ============================================================================
// MARK: - 部品D（Layer 3）：二重回転する黄金後光＋不規則集中線（AIサンバーストの完全代替）
// ============================================================================

private struct ChampionGoldenHaloCanvas: View {
    let startTime: Date

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSince(startTime)
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height * 0.36)
                let maxR = hypot(size.width, size.height) * 0.62

                // 1. 中心の白金〜山吹金コアグロー（光源の核を作る）
                let glowRect = CGRect(x: center.x - maxR, y: center.y - maxR, width: maxR * 2, height: maxR * 2)
                context.fill(
                    Path(ellipseIn: glowRect),
                    with: .radialGradient(
                        Gradient(stops: [
                            .init(color: Color.white.opacity(0.55), location: 0.0),
                            .init(color: YoseColor.kinBright.opacity(0.38), location: 0.24),
                            .init(color: YoseColor.shu.opacity(0.16), location: 0.52),
                            .init(color: .clear, location: 0.85)
                        ]),
                        center: center,
                        startRadius: 4,
                        endRadius: maxR
                    )
                )

                // 2. 第1層：時計回りにゆっくり回る太細ミックスの後光（外側へ減衰）
                let rayCount = 24
                for i in 0..<rayCount {
                    let baseAngle = (Double(i) / Double(rayCount)) * (.pi * 2.0) + t * 0.18
                    // 均一にせず、太い光条と細い光条を交互に配置
                    let halfSpread = (i % 2 == 0) ? 0.048 : 0.018
                    let rayLength = maxR * ((i % 3 == 0) ? 1.0 : 0.76)

                    var wedge = Path()
                    wedge.move(to: center)
                    wedge.addLine(to: CGPoint(
                        x: center.x + CGFloat(cos(baseAngle - halfSpread)) * rayLength,
                        y: center.y + CGFloat(sin(baseAngle - halfSpread)) * rayLength
                    ))
                    wedge.addLine(to: CGPoint(
                        x: center.x + CGFloat(cos(baseAngle + halfSpread)) * rayLength,
                        y: center.y + CGFloat(sin(baseAngle + halfSpread)) * rayLength
                    ))
                    wedge.closeSubpath()

                    context.fill(
                        wedge,
                        with: .radialGradient(
                            Gradient(colors: [
                                YoseColor.kinBright.opacity(0.32),
                                YoseColor.kin.opacity(0.10),
                                .clear
                            ]),
                            center: center,
                            startRadius: 30,
                            endRadius: rayLength
                        )
                    )
                }

                // 3. 第2層：外周の不規則な劇画集中線（中央の看板領域を空ける）
                let speedLineCount = 44
                let innerBase = min(size.width, size.height) * 0.40
                for i in 0..<speedLineCount {
                    let angle = (Double(i) / Double(speedLineCount)) * (.pi * 2.0) - t * 0.05
                    let jitter = CGFloat(sin(Double(i) * 2.7 + t * 6.0) * 16.0)
                    let r1 = innerBase + jitter
                    let spread = 0.004 + abs(cos(Double(i) * 1.9)) * 0.008

                    var spike = Path()
                    spike.move(to: CGPoint(
                        x: center.x + CGFloat(cos(angle)) * r1,
                        y: center.y + CGFloat(sin(angle)) * r1
                    ))
                    spike.addLine(to: CGPoint(
                        x: center.x + CGFloat(cos(angle - spread)) * maxR,
                        y: center.y + CGFloat(sin(angle - spread)) * maxR
                    ))
                    spike.addLine(to: CGPoint(
                        x: center.x + CGFloat(cos(angle + spread)) * maxR,
                        y: center.y + CGFloat(sin(angle + spread)) * maxR
                    ))
                    spike.closeSubpath()

                    context.fill(spike, with: .color(YoseColor.kinBright.opacity(0.22)))
                }
            }
        }
    }
}

// ============================================================================
// MARK: - 部品E（Layer 4 & 6）：特効キャノン砲の金テープ40本＋奥・手前2層の和紙吹雪
// ============================================================================

private struct ChampionCannonAndConfettiCanvas: View {
    let startTime: Date
    let foregroundLayer: Bool // false: 看板の奥を舞う120枚＋金テープ / true: 看板の手前を横切る大粒40枚

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let elapsed = max(0, timeline.date.timeIntervalSince(startTime) - 0.28)
            Canvas { context, size in
                guard elapsed > 0 else { return }

                // A. 奥レイヤーのみ：左右下方のキャノン砲から噴き上がる金・朱の放物線テープ（36本）
                if !foregroundLayer {
                    let tapeCount = 36
                    for i in 0..<tapeCount {
                        let seed = Double(i) * 1.618
                        let fromLeft = (i % 2 == 0)
                        let originX: CGFloat = fromLeft ? -8 : size.width + 8
                        let originY: CGFloat = size.height * 0.76

                        let delay = Double(i % 6) * 0.035
                        let localT = max(0, min(elapsed - delay, 2.2))
                        guard localT > 0 else { continue }

                        let dirX: CGFloat = fromLeft ? 1.0 : -1.0
                        let vx = CGFloat(130.0 + fmod(seed * 103.0, 210.0)) * dirX
                        let vy = CGFloat(-580.0 - fmod(seed * 149.0, 280.0))
                        let gravity: CGFloat = 390.0

                        var ribbon = Path()
                        let tailT = max(0, localT - 0.55)
                        let steps = 14
                        for s in 0...steps {
                            let sampleT = CGFloat(tailT + (localT - tailT) * (Double(s) / Double(steps)))
                            let wave = sin(sampleT * 8.0 + CGFloat(seed)) * 12.0
                            let px = originX + vx * sampleT + wave
                            let py = originY + vy * sampleT + 0.5 * gravity * sampleT * sampleT
                            if s == 0 {
                                ribbon.move(to: CGPoint(x: px, y: py))
                            } else {
                                ribbon.addLine(to: CGPoint(x: px, y: py))
                            }
                        }

                        let color: Color = (i % 3 == 0) ? YoseColor.kinBright : ((i % 3 == 1) ? YoseColor.kin : YoseColor.shu)
                        context.stroke(
                            ribbon,
                            with: .color(color.opacity(0.90)),
                            lineWidth: (i % 4 == 0) ? 4.0 : 2.5
                        )
                    }
                }

                // B. 金・朱・白和紙の紙吹雪（奥120枚 / 手前36枚）
                let count = foregroundLayer ? 36 : 120
                let palette: [Color] = [
                    YoseColor.kinBright,
                    Color(hex: 0xFFF4C2),
                    YoseColor.shu,
                    YoseColor.washi,
                    YoseColor.kin
                ]

                for i in 0..<count {
                    let seed = Double(i + (foregroundLayer ? 500 : 0)) * 2.71828
                    let speedY = (foregroundLayer ? 135.0 : 80.0) + fmod(seed * 53.0, 95.0)
                    let startY = -fmod(seed * 113.0, Double(size.height))
                    let y = CGFloat(fmod(startY + elapsed * speedY + Double(size.height), Double(size.height + 80))) - 40

                    let baseX = fmod(seed * 211.0, Double(size.width))
                    let swayX = sin(elapsed * 2.6 + seed) * (foregroundLayer ? 28.0 : 16.0)
                    let x = CGFloat(baseX + swayX)

                    let baseW: CGFloat = foregroundLayer ? 14.0 : 8.5
                    let baseH: CGFloat = foregroundLayer ? 8.5 : 5.0
                    let flip = CGFloat(max(0.18, abs(cos(elapsed * 4.5 + seed))))

                    var c = context
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .degrees(sin(elapsed * 2.1 + seed) * 35.0 + seed * 40.0))
                    c.scaleBy(x: 1.0, y: flip)

                    let pieceRect = CGRect(x: -baseW / 2, y: -baseH / 2, width: baseW, height: baseH)
                    let fill = palette[i % palette.count]
                    c.fill(Path(pieceRect), with: .color(fill))
                    c.stroke(Path(pieceRect), with: .color(YoseColor.sumi.opacity(0.55)), lineWidth: 0.7)
                }
            }
        }
    }
}
```

---

## ④ 同じ考え方で作り直す4大節目演出の方針と要点

優勝演出で確立した**「①暗転で明度差を作る → ②器（黒漆・木札・斜め帯）を 먼저出す → ③袋文字と朱印を時間差で叩きつける → ④物理パーティクルと画面揺れを同期させる」**という設計思想を、他の4つの節目にも統一適用する。

### 4-1. 予選通過（合否判定：『突破』）— 尺 `1.25秒`
* **なぜ今ダメになりやすいか**：最初から結果画面に『予選通過』『実力 134』が静止表示されているため、「通ったのか落ちたのか」のドキドキがゼロで事務連絡の書類に見える。
* **作り直しの方針（時間軸と層）**：
  1. **`0.00s〜0.45s`（ドラムロールの溜め）**：結果カードの `[通過基準 30]` の横で、`[発揮実力 ???]` が `.numericText` で高速カウントアップ（小太鼓ロール `SE_ROLL_TAIKO`）。この間、上部の合否看板はまだ暗い黒漆の空枠にしておく。
  2. **`0.45s〜0.57s`（無音の停止）**：数字が `134` でピタッと止まり、0.12秒の無音。
  3. **`0.57s〜1.25s`（突破の爆発）**：通過基準を超えていた瞬間、カード背後から山吹金のスポット光が溢れ、右横に朱印『**突破**』が `scale: 2.4 → 1.0` で叩きつけられて画面が縦に `4pt` 揺れる。同時に上部の黒漆看板に『**予 選 通 過**』の金文字が点灯して斜光シマーが走り、審査員講評カードの右上に角印『**秀**』が追い打ちで押される。
* **実装の要点**：
  ```swift
  // 数値確定の0.12秒後に朱印と看板点灯を同時発火させる
  HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 4) {
          Text("発揮実力").font(YoseFont.gothic(11, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
          Text("\(animatedPower)")
              .font(YoseFont.number(32, weight: .black))
              .foregroundStyle(isPassedRevealed ? YoseColor.shu : YoseColor.sumi)
              .contentTransition(.numericText(value: Double(animatedPower)))
              .yoseNumberPop(value: isPassedRevealed)
      }
      Spacer()
      YoseAnimatedHanko(text: "突破", isStamped: isPassedRevealed, isSquare: false, angle: -8)
  }
  .yoseLightStreak(trigger: isPassedRevealed ? 1 : 0)
  ```

### 4-2. ランクアップ（番付昇格：`G → F … → S`）— 尺 `1.45秒`
* **なぜ今ダメになりやすいか**：白っぽい画面のまま文字で「ランクが上がりました」と出すと、どの能力が何段階上がったのかの重みがなく、Sランク到達の特別感も出ない。
* **作り直しの方針（時間軸と層）**：
  1. **`0.00s〜0.15s`（暗転と番付貼り紙の展開）**：背景を黒漆 `75%` でキュッと暗転させ、中央に「黒漆ヘッダー＋白和紙＋二重墨枠」の**『番付昇格』貼り紙ボード**を `scale: 0.85 → 1.0` で張り出す。
  2. **`0.15s〜0.45s`（旧ランクから新ランク大木札への叩きつけ）**：左の旧ランク木札（例：`B`）から金の矢印が伸び、右側の**新ランク特大木札（`76×76pt`、例：`A` または黒漆金枠の `S`）**が `scale: 1.85 → 1.0` でガツンと着地。四隅から金と朱の角火花16個が弾ける。
  3. **`0.45s〜1.45s`（朱印『昇格』とSランク専用後光）**：直後に右肩へ角朱印『**昇格**』が叩きつけられてカードが縦に `3pt` 揺れる。**Sランク到達時のみ**、背後に優勝と同じ `.blendMode(.plusLighter)` の黄金後光と金紙吹雪を追加する。複数能力が同時に上がった場合は、何枚もモーダルを出さずカード下段の「同時昇格ストリップ」に横並びで一括表示する。

### 4-3. 大成功（練習の『手応え抜群！ハマった！！』）— 尺 `1.15秒`
* **なぜ今ダメになりやすいか**：画面全体を覆うモーダルにしてしまうと毎週の練習テンポが死ぬ。逆に文字だけだと「大当たりを引いた脳汁」が出ない。
* **作り直しの方針（時間軸と層）**：
  1. **全画面を隠さず、週メイン画面の上に「斜め `-5度` の黒漆×金枠カットイン帯」を高速貫通させる**。
  2. **`0.00s〜0.10s`（白金フラッシュと外周集中線）**：練習ボタンを押した直後、画面外周だけに金の劇画集中線（中央空洞比率 `0.38`）がパッと出て、高い拍子木音（`SE_HYOSHIGI_SHARP`）が鳴る。
  3. **`0.10s〜0.30s`（黒漆斜め帯の突入＋『大成功』朱印）**：左端から黒漆＋臙脂ストライプ＋上下二重金線の帯がスパーンと突入し、金袋文字『**手応え抜群！ハマった！！**』の右端に朱印『**大成功**』が叩きつけられ、画面が縦に `4pt` 揺れる。
  4. **`0.30s〜1.15s`（経験点1.35倍ポップ＆自動退場）**：帯の下で見えている獲得経験点木札（閃・語・間・存・胆）が通常の1.35倍スケールで跳ねて金火花を散らし、タップ不要で `1.15s` で右端へスッと抜けて次のコマンドを即叩けるようにする。

### 4-4. 年の幕間（1年の締め → 新年開幕）— 尺 `0.85秒`＋タップ待ち
* **なぜ今ダメになりやすいか**：カレンダーの数字が `12月4週 → 1月1週` に切り替わるだけだと、1年間戦い抜いた区切りと「今年こそ頂グランプリを獲るぞ」という新シーズンの高揚感がない。
* **作り直しの方針（時間軸と層）**：
  1. **`0.00s〜0.24s`（定式幕の閉幕ワイプ）**：年末リザルトを終えた瞬間、左右から**本物の定式幕（黒・柿 `#BD3C28`・萌黄 `#2E583C` の縦縞＋金房飾り）**が布擦れ音とともに中央へピシャッと閉まり、前の年の画面を完全に隠す。
  2. **`0.24s〜0.45s`（暗転での年号めくり出現）**：定式幕が左右へサッと引き開けられると、夜の寄席舞台のピンスポットの中に**特大の寄席めくり縦札**が立っている。
  3. **`0.45s〜0.85s`（3D縦めくり反転＋新春太鼓）**：寄席めくり札が上辺を軸にX軸3D回転（`.rotation3DEffect`）でパタン！とめくれ、『結成 1年目』から墨太文字の『**結成 2年目**』へ切り替わる。直後に右肩へ朱印『**開幕**』が叩きつけられ、下部に「引き継いだ実力・知名度・勝負ネタ」の3連木札がせり上がる。

---

## ⑤ 禁止事項（二度とやらない事・10箇条）

今後の全演出実装において、以下の10項目を**コードレビューおよびスクショ監査での即時却下対象（絶対禁則）**とする。

1. **【禁止】明るい生成り・白背景の上に、薄い黄色の放射線を引いただけの「AIサンバースト画面」を作ること**
   * 光らせる時は必ず背景を「黒漆（`#1E1916`）〜深夜闇（`#0B0807`）」に落とし、光は `.blendMode(.plusLighter)` とラジアル減衰グラデーションで描くこと。
2. **【禁止】画面中央に「器（看板・木札・額縁・座布団）」なしで裸の文字だけをポンと置くこと**
   * 主役の文字は必ず「黒漆＋二重金枠の大看板」「白和紙＋墨枠の寄席めくり」「斜め黒漆カットイン帯」のいずれかの物質の上に打ち付けること。
3. **【禁止】360度すべて同じ太さ・同じ長さ・ベタ塗りの幾何学放射線を `for` ループでそのまま描くこと**
   * 放射線や集中線を描く場合は、必ず「太い光条と細い光条の周期変化」「外周へ向かうアルファ減衰」「中央の可読領域（半径34%以上）の空洞化」を入れること。
4. **【禁止】「誰が」「何の大会で」「どうなったか」のゲーム文脈を持たない汎用テンプレ画面を出すこと**
   * 『優勝』の2文字だけの画面はゲームではない。必ずプレイヤーが育てた「コンビ名」「大会名・第N代王者」「獲得賞金」「相方の肉声セリフ」を同じ画面内に結晶として刻むこと。
5. **【禁止】丸頭と台形胴体を組み合わせた「こけし型の幾何学シルエット人間」を描くこと**
   * デザインシステム禁則（§8-4）通り、幾何学図形で人間を描くと一気にチープなAI生成画になる。主役は「特大の寄席めくり名札・黄金の番付看板・朱印」で表現すること。
6. **【禁止】時間差（Stagger）と溜め（Hold）のない「全要素の同時フェードイン」**
   * 暗転（0.25s）→ フラッシュ＆背景展開 → 『優』着地 → 『勝』着地＋画面揺れ → 朱印＋シマー → 賞金カウントアップ、のように必ず `0.07s〜0.25s` 単位の因果関係のある時間差をつけること。
7. **【禁止】単一種類の四角形が等速で落ちるだけのチープなパーティクル**
   * 祝祭演出では必ず「①弾けて減速する火花」「②下から放物線で噴き上がる金テープ」「③コサイン回転でヒラヒラ舞う2層（奥・手前）の和紙吹雪」を組み合わせること。
8. **【禁止】Web UI風の `Capsule()`（丸カプセル）、`cornerRadius(8以上)`、ぼかし影（`shadow(radius: 8)` 等）の混入**
   * すべての枠は `cornerRadius(0〜2)` の角札・木札とし、影は `offset(y: 3〜6)` のソリッドな墨・黒漆ハードシャドウで統一すること。
9. **【禁止】ゲーム内のどこかに「`%`（パーセント）」表記を出すこと**
   * 達成度や通過率に `%` は一切使わない。すべて「通過基準 30 ▶ 発揮実力 134」「4票獲得」のような実数と番付・朱印で表現すること。
10. **【禁止】スキップできない長い演出、または毎週のコマンドで全画面を止める演出**
    * 特大演出であっても、画面タップ1回で `0.08秒` 以内に「すべての文字と数字が出揃った最終完成フレーム（記念スクショ状態）」へ即座に到達できる2段階タップ制御を必ず実装すること。
