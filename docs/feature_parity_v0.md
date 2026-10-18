# 部屋・特技・品の Python⇄Swift 一致確認 v0（2026-10-19）

- 要点1：既存 golden はボットが部屋・特技・品を使わず未検証だった。乱数なしの17台本（192手・Swift側2496値）を新設して照合した。
- 要点2：結果は **全件一致**（Double は 1e-9）。`swift test` は 238 件 green（新規1件 FeatureGoldenTests を含む）。
- 要点3：既存の式・既定値・golden・gen_golden.py は無変更（`check_golden_sync.py` も OK）。

## 節構成
§1 台本一覧／§2 結果／§3 限界／§4 再生成の手順

## §1 台本一覧（tools/gen_golden_features.py）
| 台本 | 内容 |
|---|---|
| room0/1/2_home_rests | 部屋ごと×完全休養・気分転換・相方と過ごす の体力/メンタルの戻り |
| living_room0/1/2_yarikuri | 月末の支払い額と所持金（部屋×やりくり上手の習得前後・4週の周期） |
| injury_mult_skill_throat | 体調ダウン確率（体が資本×喉のケア用品×年明けリセット・体力別） |
| fame_base / fame_aisare | 知名度の伸び（愛され芸人あり/なし・知名度3/30/60・負の増分は不変） |
| rift_base / rift_aitaomoi | すれ違いの増え（相方思い・相性上昇週・二人の週・1年目の99上限） |
| items_drinks | 栄養ドリンク/回復ドリンク大：体力・回数上限・年明けリセット |
| items_sento_room0/2 | 銭湯の回数券：4回+10・再購入不可・部屋との重ね掛け |
| items_shinkansen_throat | 新幹線回数券・喉のケア用品・非売品の拒否・年明けリセット |
| items_no_money | 所持金不足で買えない |
| skills_learn | 特技の費用・不足・重複 |

## §2 結果
| 項目 | 本数 | 一致 | 不一致 |
|---|---|---|---|
| 台本 | 17 | 17 | 0 |
| 比較した値 | 2496（＋スキル集合・回数辞書・各手の戻り値） | 全部 | 0 |

## §3 限界
- 体調ダウン確率は WeekRunner.resolveAction の式と**同じ部品**（閾値・1点あたり・喉係数・体が資本）をテスト内で組み直して比較（WeekRunner 自体は駆動していない）。
- 新幹線回数券の「遠征費0」・ICレコーダー等の稽古側の効果は対象外（購入後フラグのみ）。
- JSON の読み込みは `#filePath` 基準（Package.swift は変更していない）。

## §4 再生成の手順
`cd tools && python3 gen_golden_features.py` → `cd GameCore && swift test`。
式を変えたら Python を直して JSON を再生成し、Swift を合わせる（規律A）。
