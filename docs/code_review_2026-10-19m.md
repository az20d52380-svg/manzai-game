# コード点検 2026-10-19m（読み取り専用・コード変更なし）

対象：`ManzaiGame/Sources/Theme.swift`（446行）／`ManzaiGame/Sources/Design/EventBackgrounds.swift`（1750行）。呼び手は `RootView.swift:40`（MZ_BG 目視フック）・`IntroFlow.swift:167`・`ChoiceEventOverlay.swift:130`・割り当て表 `Design/EventBackdropTable.swift`・`Endings.swift`。

総評：EventBackgrounds は**アニメーション・TimelineView・Canvas・repeatForever・Timer を一切使わない静的な View 木**。毎フレーム描き続ける無駄・reduceMotion 無視は構造上起きない。重大な事故は見つからず、直すべきは「看板文字の切れ」「死にコード」程度。

## §1 直すべき（重い順）

1. **店先の看板文字が Dynamic Type で切れる/折り返す**
   - 場所：EventBackgrounds.swift:1461-1467（`Text(sign)` を `.frame(width: 112, height: 30)` に固定。`lineLimit`/`minimumScaleFactor` なし）。フォントは `YoseFont.gothic(18)`＝`Font.mzScaled` で最大1.35倍＝約24pt（YoseTokens.swift:36）。
   - 起きる場面：`sign: "ファミレス"`（Endings.swift:160）など5文字の看板。24pt×5字≒120pt＞112pt で2行に折り返し、高さ30を超えて上下が切れる（文字を大きくした設定のとき）。他の固定枠のTextも同型：:1394「寄　席」22pt、:1552「出口」18pt、:1612「受付」22pt、:481/:482 駅名標（9pt が拡大）。
   - 直し案：背景内のTextに `.lineLimit(1).minimumScaleFactor(0.6)` を付ける、または背景の飾り文字だけ `Font.system(size:)` の固定にする（背景は accessibilityHidden の飾りなので拡大の恩恵がない）。
   - 判断：不要（飾りの文字を拡大に追従させるか固定にするかだけ。固定を推奨）。

2. **背景が高さ220ptを前提に絶対座標で組まれ、高さを縮める箇所で重なる**
   - 場所：固定pt配置が多数（例 :350-352 の窓、:381 `w/2 - 159`、:1007/:1368 の固定幅340、:1594 以降の `position(x: 80, y: 80)` など）。呼び手は高さ可変：ChoiceEventOverlay.swift:114-117（130〜320）、RootView.swift:40（220）、IntroFlow.swift:167（可変）。
   - 起きる場面：文字拡大（accessibility サイズ）で高さが130に縮むとき、h比例の床線と固定yの小物（暖簾 y=15、木札 y=80 など）の位置関係が崩れて重なる。幅が狭い端末（SE系・幅320前後）でも固定x/幅の小物が見切れる。`.clipped()`（:263）があるので落ちはしない。
   - 直し案：目視の確認だけ先に（高さ130・幅320で全16種×4時間帯を MZ_BG で撮る）。崩れが大きい背景だけ `scaledToFill` 等で220固定サイズに描いて縮小する案（`.frame(height:220)` ＋ `scaleEffect` か `Canvas` でなく `GeometryReader` 外側で固定描画）も可。
   - 判断：要（見た目の許容範囲はオーナー判断。目視は sonnet に渡せる）。

3. **`.train` と `.sento` が実イベントから一度も使われていない（描画コードだけ重い）**
   - 場所：TrainBackdrop :826-887、SentoBackdrop :1050-1133＋SentoBucketShape :1134・FujiShape/FujiCapShape :1031-1049。呼び手：割り当て表（EventBackdropTable.swift）・Endings.swift に `.train`/`.sento` の割り当て0件。RootView.swift:40 の MZ_BG 目視でのみ到達。
   - 起きる場面：実害なし（使われないだけ）。ただし1画面あたりの描画コストは銭湯に `blur(radius:7)` が3つ（:1123-1126）あり、将来使うとき一番重い部類。
   - 直し案：イベント割り当てを足す予定があるなら残す。無いなら §3 の表の通り削除候補。
   - 判断：要（将来イベントを足す予定があるか）。

4. **blur と blendMode を重ねた層が多く、古い端末でスクロールと同時だと重くなりうる**
   - 場所：blur は :1125 の1箇所のみ（湯気3つ・銭湯）。`blendMode` は9箇所（EventGlowLayer の halo :302-305、:340 など）。`EventGlowLayer` は夜と夕だけ RadialGradient を `.blendMode(.screen)` で複数重ねる（:296-460）。`drawingGroup`/`compositingGroup` は未使用。
   - 起きる場面：ChoiceEventOverlay 表示中に文章が流れる（ScrollView が背景と同居）とき、背景が毎回再合成される可能性。実測はしていない（推測のため確定ではない）。
   - 直し案：背景ビュー全体に `.drawingGroup()` を付けて1枚の画像にする（blendMode を含むので見た目が変わらないか要確認）か、`EventStageBackdropView` を `Equatable` にして再描画を減らす。まず Instruments で実機計測してから。
   - 判断：不要（計測して数字が悪ければ対応）。

## §2 軽微

- **コメントと実値の食い違い**：Theme.swift:159 `Rad` のコメントは「card=16／btn=12／board=12／sheet=24」だが実値は 3/3/3/4/4（Theme.swift:161-165）。意図的に角を立てた変更ならコメントだけ直す。
- **TypeStep のコメント古い**：Theme.swift:318 付近「第1便は固定 pt（Dynamic Type 追従は第2便）」だが `Font.maru` は `mzScaled` で既に追従する（Theme.swift:244-257）。コメントのみ修正。
- **同値の色が3つ**：`bg1`/`bg2`/`bgTop` は全て 0xF5F0E1（Theme.swift:16-18）、`inkDim`/`inkFaint` は全て 0x9E9E9E、`kinari`/`bgTop` も同色。`bg1` は他から参照0。
- **`Rad` の `card` と `Sp.s4` 等**：`Rad.board`/`Rad.sheet`/`Motion.quick`/`Motion.hold` は Theme 外の参照が0または語としての一致のみ（Theme 内定義だけ）。
- **Dynamic Type の上限**：`Font.mzScaled`（Theme.swift:230-233）は `UIFontMetrics(.body)` の倍率を最大1.35倍で打ち切る。accessibility サイズ（約2〜3倍）では止まるため、弱視の人には拡大不足。ChoiceEventOverlay.swift:116 は accessibility サイズを別扱いしているが、他画面は上限1.35のまま。設計判断（崩れ防止とのトレードオフ）。
- **`mzScaled` は SwiftUI の環境値でなく UIKit の現在値を読む**：設定アプリで文字サイズを変えたとき、既に描画済みのビューは再評価されるまで古いサイズのまま（`@Environment(\.dynamicTypeSize)` を購読していないため）。実害は小（再表示で直る）。
- **ダークモード**：Info.plist/project.yml に `UIUserInterfaceStyle` の固定なし。`preferredColorScheme(.light)` は YoseCatalog.swift:122 のプレビューだけ。背景・Theme の色は全て固定 hex で（Asset Catalog の動的色なし）沈みはしないが、**色を明示せず `.primary`/`.secondary` を使う Text が他ファイルにあればダークで白字がクリーム地に乗る**（本点検の範囲外・別途 grep 推奨）。背景自体（EventBackgrounds）はダーク設定の影響を受けない（固定色の描画）。
- **`ForEach(..., id: \.self)` に Float 配列**：`[w * 0.24, w * 0.76]`（:368 ほか）、`[0.16, 0.84]`（:437）等。値が重複しない限り安全。w が0（初回レイアウト）のとき `[0, 0]` になる配列は無い（`w*0.24` と `w*0.76` は w=0 で両方0＝**重複IDになる**）。該当：:368 `[w*0.24, w*0.76]`、:569 `[w*0.34, w*0.66]`、:610 `[w*0.30, w*0.84]`、:993 `[w*0.18, w*0.82]`、:1112 `[w*0.16, w*0.84]`、:1166 `[w*0.24, w*0.76]`、:1721 `[w/2-112, w/2+112]`（これは差があるので安全）。GeometryReader の初回 size が0になる場面は通常ない（親が高さ指定）が、重複ID警告は出うる。直すなら `id: \.offset` 付きの enumerated にする。落ちはしない。

## §3 死にコード表

| 対象 | 場所 | 根拠（Theme/Sources 外の参照数） | 備考 |
|---|---|---|---|
| `EventPlace.train` の背景 `TrainBackdrop` | EventBackgrounds.swift:7 / :826-887 | 割り当て0（Table・Endings とも）。MZ_BG のみ | §1-3 |
| `EventPlace.sento` の背景 `SentoBackdrop`・`SentoBucketShape`・`FujiShape`・`FujiCapShape` | :8 / :1031-1143 | 同上0 | §1-3。`nightStrength` の `.sento` 分岐(:50)も連動 |
| `Theme.bg1` | Theme.swift:16 | 0 | bg2/bgTop と同値 |
| `Theme.inkFaint` | Theme.swift:31 | inkDim と同値（参照は要確認） | 注：inkDim は使用あり |
| `Theme.cCompat` | Theme.swift:50 | 0 | verm と同値 |
| `Theme.goldD` | Theme.swift:36（`kataColor` 内 :168付近でのみ） | 外部0 | kataColor 経由の間接のみ |
| `Theme.staminaWarn` | Theme.swift:68 | 0 | staminaCrit は別（使用あり？未確認） |
| `Theme.pillDark` | Theme.swift:65 | 0 | |
| `Theme.botbarDark` | Theme.swift:67 | 0 | |
| `Theme.cOre` / `Theme.cTaniguchi` | Theme.swift:~254-255 | 0（cOreDeep は使用1） | |
| `Theme.onGold` | Theme.swift:~257 | 0 | |
| `Theme.sealName` | Theme.swift:~249 | 0 | |
| `Theme.goldLeafLo` / `goldLeafHi` | Theme.swift:~300 | 0（goldLeafMid は1） | |
| `Theme.houseLight` | Theme.swift:~302 | 0 | |
| `Theme.boardsDark` | Theme.swift:~298 | 0（boardsLit は1） | |
| `Theme.rimGold` | Theme.swift:~284 | 0 | |
| `Theme.abilityChar(_:)` | Theme.swift:~84 | 0（呼び手は `AbilityBadge` のみ） | 色弱対応の文字ラベルが実画面で効いているか要確認（AbilityBadge も0） |
| `AbilityBadge` | Theme.swift:~294 | 0 | 上と同じ。色弱指示(2026-08-02)の実装が未配線の可能性＝§1扱いの確認事項 |
| `CurrencyBadge` | Theme.swift:~306 | 0 | 同上（currencyChar 経由） |
| `View.e2()` | Theme.swift:~220 | 0（e1/e3 は各1） | |
| `View.hardShadow(_:)` | Theme.swift:~345 | 0 | |
| `Theme.Sp.s4`・`Motion.quick`・`Motion.hold`・`Rad.board`・`Rad.sheet` | Theme.swift:~175-205 | 語としての一致のみ（実参照の確認は目視grepで） | トークン表として残す選択もあり |

（行番号「~」付きは grep の定義位置からの概数。削除前に再 grep すること。参照数は `grep -rnw --include='*.swift' ManzaiGame GameCore`（Theme.swift 除外）での数。）

## §4 問題なしと確認した所

- **毎フレーム描画**：`TimelineView`/`Canvas`/`repeatForever`/`Timer`/`withAnimation` が EventBackgrounds.swift に0件。reduceMotion の無視は起きない（動かない背景）。
- **VoiceOver**：`EventStageBackdropView` の末尾で `.accessibilityHidden(true)`（:264）、`EventGlowLayer` も個別に付与（:307）。背景内の Text（駅名標・看板）も含め全体が読み上げ対象外。呼び手 IntroFlow/ChoiceEventOverlay の場所ラベルは別の木札で読まれる（ChoiceEventOverlay.swift:131-）。
- **ゼロ除算・添字**：`/` は定数分母のみ（`w / 2` など）、`hs[i]` は i が `0..<6`・配列長6で範囲内（:372-387）。`h - floorY` の floorY は `h * 0.66-0.76` なので h>0 で正。h-固定値の形（:880, :977, :1175, :1322, :1722）は h が小さいと負になりうるが、:1006/:1368 は `max(0, …)` で保護、他は SwiftUI が負のframeを0扱いにするだけで落ちない（コンソール警告のみ）。
- **GeometryReader size 0**：NaN を生む除算なし。
- **Path/Shape の再計算**：全て軽量（台形・三角・富士の数点）。`Path` は body 内で毎回組まれるが点数が少なく、静的なので再評価も View の再生成時のみ。
- **全16種が `EventStageBackdropView` の switch で網羅**（:236-257・default なし）。呼び手：`.train`/`.sento` 以外は実イベントから使用（keikoba 9, theaterOutside 7, theater 6, office 6, street 6, apartment 5, gakuya 5, famires 3, station 2, stationGate 2, park/kissaten/yakiniku/uketsuke 各1）。
- **夜の暗転で沈まない設計**：`nightStrength`（:46-60）で営業中の屋内は弱め、EventGlowLayer が暗転の上に光源を再描画。
- **Theme の `rank`/`rankProgress`**：`guard` と `min/max` で 0..1 に収まり、`hi - lo` は常に正（lo+1 の保険あり）。ゼロ除算なし。`Yen.man` も安全。
