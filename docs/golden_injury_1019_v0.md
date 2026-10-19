# golden 拡張：体調ダウンの抽選と、喉のケア用品・特技「体が資本」（2026-10-19）

## 何を足したか
- `tools/gen_golden_features.py` に `injury_scripts()` を追加（出力は `golden_features.json` の `ext.injury`）。`gen_golden.run_year`（乱数込みの1年＝大会・GP・オファー・誘い込み）を、体力が低くなる台本（稽古とキツいバイト中心・9週周期）で回し、**48週ぶんの全状態＋体調ダウン回数**を記録する。
- 種 52 と 54 × {用品なし・用品あり・特技あり・両方} の 8 台本。種52は同じ乱数列で 用品なし3回 → 用品1回／特技2回／両方1回、と抽選の当たり外れが変わる（種54は 3/2/2/1）。
- Swift：`FeatureGoldenTests.testInjuryDrawGolden`。WeekRunner を同じ台本で回し、週ごとの全状態と「体調ダウン」の回数を JSON と突き合わせる（用品は年初リセットの後・1週目の前に購入）。
- `check_golden_sync.py` の3つ目（golden_features）が自動でこの台本も対象にする（再生成忘れも拾う）。

## 生成器の食い違いを1つ直した（式の変更ではない）
`tools/gen_golden.py` の体調ダウン抽選だけが、喉のケア用品・特技の係数を掛けていなかった（sim_career.py と Swift は掛けている）。既存 golden は用品も特技も無いので影響なし（係数＝×1）。生成器を sim_career/Swift と同じ式にそろえた。既存の check_golden_sync 3つとも変化なし。
その他の追加：`run_year` に `pattern`（既定は従来の PATTERN）と、`trace` への体調ダウン回数の記録（乱数非消費）。

## 結果
swift test 335件 green／check_golden_sync 3つとも ✅。Python と Swift の食い違いは無かった。
