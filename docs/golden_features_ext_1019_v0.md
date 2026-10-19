# golden_features 拡張（10/19）

保存先: tools/gen_golden_features.py の `ext_main()`（JSON の `ext`）／GameCore/Tests/GameCoreTests/FeatureGoldenTests.swift の4テスト。
式・乱数・GameConfig・sim 既定値は不変（生成器の中だけで `C.NETA_V2` を立て、終わったら戻す）。

## 足した台本（Python の関数をそのまま呼ぶ・乱数なし）
1. **ネタ補正** `neta_bonus`（39件）: `sim_career._neta_bonus` ⇔ `GameEngine.netaScoreBonus`。完成度×手応え8組×飽き0〜3段（±5の頭打ち・飽き1段-1）／決勝は `_neta_line_adj(final=True)`（1本目＝補正最大、2本目＝残りの完成度最大。無し・59.9は-3、60ちょうどは付かない、ネタ0本は0）。1本目/2本目の添字は生成器が記録。
2. **ネタ書き・ライブの伸び** `neta_grow`（2台本）: `_neta_on_train` ⇔ `applyNetaCreate/Revise(gain)/Live`。家・喫茶店・ファミレスの伸び（+8/+10/+12）、新規2本→最低完成度に上乗せ、100頭打ち、ネタ見せ会+12／フリーライブ+6と手応え移動平均（実力が既定／高めの2通り）。
3. **追加の札** `offers.extra`（240件）: `extra_offers` ⇔ `extraOffers`。1枚目4種×知名度（0/29.9/30/54.9/55/99＝30・55の境目）×シード5種（2^63超含む・文字列で受渡し）×(年,週)2通り。名前・収入・知名度・体力を比較。
4. **テレビ慣れ** `offers.fatigue`（24台本）: `B.do_offer` ⇔ `applyOffer(atWeek:)`。直近6週に4回の境目（密／窓の端／疎）×知名度0・50×4種。所持金・知名度・体力・センス・表現・受けた週の履歴を比較。

結果: swift test 331 tests 0 failures／check_golden_sync 3つとも ✅。本物の食い違いは無し。

## 足せなかった物と理由
- **年初の飽き進行**（tiredYears +1）: Python は `run_career` の中の直書きループ（関数が無い）。意味も違う＝Python は印 `used_y` と `V2_TIRED_REST*` 系の戻し、Swift は `lastUsedTaikaiYear == year-1` の判定（WeekRunner 初期化）。同じ式を生成器に写すと「Python から作る」にならないので見送り。関数化（Python 側の小さな切り出し）なら足せる。
- **ネタの保管庫（archivedNetas）の飽き**: Python に保管庫が無い。
- **extra_offers の「所持金」境目**: 追加の札は知名度だけで決まり、所持金は入らない。所持金はテレビ慣れ台本の money 加算で見ている。
- **ネタ選択（どれを掛けるか）**: Python は補正最大を自動選択、Swift はプレイヤー選択＝比べる対象ではない（補正値と2本目判定だけ比較）。
- 敗者復活・王者シード・ライン上書き・GPシード・選択肢イベント・療養週の回数券（F3）は今回の範囲外（未着手のまま §5 に残る）。
- 追記：年初の飽き進行は Python（手応えも下げる・休ませて戻す旗あり）と Swift（tiredYears を1段・保管庫も）で中身が違う＝どちらを正にするかの判断が要る（golden の守りはその後）。
- 訂正（同日）：既定値（V2_YEAR_STALE=0・V2_TIRED_REST=False・REST_YEARS=0・上限2）では Python も Swift も「前の年に大会で掛けたネタの飽きを1段・上限2」で同じ。違うのは Python に保管庫が無い点だけ＝今の帯には効かない。旗を入れる時に揃える。
