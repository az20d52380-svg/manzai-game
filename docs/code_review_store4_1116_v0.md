# コードレビュー store4（2026-11-16）読み取りのみ

## 要点3行
- 対象4ファイル（StageOutfit / StoreIDs / YoseComponents / CharacterAvatars）で 高・中 の実バグは見つからず。
- 低1件・要確認0件：StageOutfit.current の `MainActor.assumeIsolated` はメインスレッド以外から呼ぶと落ちる（今の呼び出し元は全部メイン）。
- 商品ID・4種のコンビの顔・保存IDの読み戻しは問題なし。

## §1 件数
高 0 / 中 0 / 低 1 / 要確認 0

## §2 指摘
### 低-1 StageOutfit.swift:63 `MainActor.assumeIsolated`
- 場面：`current` は非 MainActor の static var。メイン以外のスレッド（Task.detached 等）から呼ぶと実行時に trap する。
- 今の呼び出し元：StageFrame.swift:135・GachaView.swift:15/18（SwiftUI の body／@State＝メイン）のみ＝今は起きない。
- 直し：`@MainActor static var current` にして呼び出し側で検査する。または未所有の判定だけ別に切る。いま直す必要はない。

## §3 問題なしと確かめた所
- StoreIDs：4つの商品ID（adfree/agency/ticket1/ticket10）は ManzaiGame/Configuration.storekit の productID と完全一致。重複なし。使用側（GachaView.swift:112,113,155／StoreManager.swift:33,38,59,95／AdProvider）も StoreIDs 経由で直書きの食い違いなし。agency は UI 未使用（仕様どおり）。
- StageOutfit の保存読み戻し：`StageOutfit(rawValue:)` は失敗で standard に戻す＝未知・削除済みIDでも落ちない。所有は GachaState の `Set<String>` で、未知の文字列が混じっても復号は通る（decodeIfPresent＋既定値あり）。kuromontsuki は GachaStore.swift:62 で広告カット所有に連動。
- 衣装旧ID（costume.hakama／leopard）の削除は docs/code_review_1116 系で判断済み（出荷前なら無関係）につき再掲しない。
- コンビ4種：`ore(for:)`／`taniguchi(for:)`／`StageOutfit.ore/taniguchi` は meIsFemale・partnerIsFemale で引く。maleMale＝男男、femaleFemale＝長髪＋シニヨン、maleFemale＝俺男＋谷口女、femaleMale＝俺女＋谷口男。取り違えなし。ComboKind.from は未知値を maleMale にする。`speaker(nil/"俺")` も正しい。
- YoseComponents：`!`・添字アクセスなし。とじるボタンは文字付きで読み上げ可・タップ範囲44pt確保。フォントは mzScaled（上限1.35倍）で12pt→最大約16pt、「とじる」3文字は幅64pt内に収まる。タイトルは minimumScaleFactor あり。サブタイトル（12pt）は折り返し可で切れない。判子は accessibilityLabel あり。
- CharacterAvatars：配列アクセスなし。審査員名の未知は汎用 FaceSpec。顔の読み上げ除外は既存レビュー（2026-10-19b #5）の判断済み。
