# START HERE — CLI/新セッション向けの引き継ぎ（2026-07-05時点）

このリポジトリはWeb/アプリ側の長いセッションで設計・検証してきた漫才師育成SLG。
CLI（Mac上）で作業を引き継ぐときは、まずこの1枚を読む。詳細は各ドキュメントへ。

## いまの状態

- **設計はほぼ完成、Swiftは一度もコンパイルされていない**（Web側の環境にSwiftツールチェーンが無く、
  全てPythonシミュレータ＋goldenテスト〈乱数列ビット一致〉で理論検証してきた）。
- バランスは「正典v2」に移行済み（`docs/canonical_v2_spec.md` が正本）。旧ドキュメントの数値は
  「正典v2移行」バナーつきの履歴。設計結論は有効、数値だけ読み替える。
- 直近でレッドチーム3視点レビュー実施（`docs/red_team_v0.md`）。指摘された「壊れていた旧テスト2本」は
  v2仕様に書き直し済み、シード制のテスト配線・golden出力の自動化も対応済み。

## 最優先タスク（P0）: swift test

```
cd GameCore && swift test
```

- 通れば、Python⇔Swiftの数式・乱数同期（12週・3年Career・WeekRunnerの3本）が実機で証明される＝この大改修全体の検証完了。
- 落ちたら**まずコンパイルエラーか同期崩れかを切り分ける**。レッドチームの診断では、落ちる可能性が高いのは
  「本物のコンパイルエラー」の側で、テストデータのズレは対応済みのはず。
- golden再生成が必要になったら: `cd tools && python3 gen_golden.py`（出力は `CareerGoldenTests.swift` の
  `year1`/`yearEnds` にそのまま貼れる形）。正典順序は `gen_golden.py` の docstring。

## 次にやること（red_team_v0.md §4 のトリアージ順）

1. swift test 緑化（上記）
2. **裏天井の設計＋sim較正**（初回の保証弁。決勝未到達のまま晩年でハマ率累積。`tools/exp_v2_anchor.py`の枠で帯維持を確認）
3. 決勝敗北時の「優勝者指名」演出（ライバル名鑑接続。判定は絶対ラインのまま表示だけ相対化）
4. 成長上限の可視化（谷口の台詞化・`docs/ui_design_v0.md`改訂）
5. runYear→WeekRunner委譲（ui_design §5。golden緑の確認後）＋ GameStateのCodable化・中断復帰
6. Xcodeプロジェクト作成→S2週メインから触れるビルド（ui_design §7）

## オーナー判断待ちの2大論点（勝手に進めない）

1. **業態**: B案F2P続行か、ハイブリッド（序盤無料＋本編980円＋コスメ/DLC）か。
   レッドチームの数字はハイブリッド優位。検証①ビルドの手応え＋事前登録の数字を見てから最終決定の方針。
2. **初回の保証弁**: 裏天井を入れるか。推奨は入れる（simで帯内を確認してから）。

## モデルの使い分け

- **Fable（残りわずか）**: 裏天井sim較正・ネタ資産システムの設計＋検証・構造的バランス判断に温存。
- **4.8**: 量産・実装・パターン踏襲・UIスキャフォールディング・ドキュメント整備。

## 主要ドキュメント索引

- 正本: `master_spec_v2.md` / `canonical_v2_spec.md`
- 検証: `human_calibration_v0.md`（借金バグ発見）/ `rule_holes_v0.md`（生活ルール）/ `red_team_v0.md`
- UI/演出: `ui_design_v0.md` / `finals_direction_v0.md` / `fan_report_design_v0.md` / `onboarding_script_v0.md`
- 収益: `monetization_decision_v0.md` / `pricing_proposal_v0.md`
- 検証機: `tools/` の `sim_career.py`（本体）`gen_golden.py`（正典順序）`exp_v2_*.py`（v2実測）
