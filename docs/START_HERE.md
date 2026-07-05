# START HERE — CLI/新セッション向けの引き継ぎ（2026-07-05時点）

このリポジトリはWeb/アプリ側の長いセッションで設計・検証してきた漫才師育成SLG。
CLI（Mac上）で作業を引き継ぐときは、まずこの1枚を読む。詳細は各ドキュメントへ。

> **⚠️ セッション運用ルール（共通・2026-07-05確定）**: 同一ブランチをアクティブに編集・pushするセッションは常に1つだけ。
> 作業前 `git pull --rebase`／区切りごと `git push`／**切替前に必ずpushして手を離す**／並行は別ブランチ。
> ルール正本は `CLAUDE.md`、分担と経緯の詳細は `docs/session_log_v0.md`。
> 運用の全体像・これまでの流れ・Fableの使い方・2つのClaude(Mac CLI↔クラウド)の分担は `docs/session_log_v0.md` に集約（2026-07-05）。

## いまの状態

- **設計完成・Swift実機検証も完了**（2026-07-04・Macの Swift 6.3.3 で `cd GameCore && swift test` が
  **17件すべてgreen**＝Python⇔Swiftの乱数列ビット一致を実機で証明。正典v2大改修の検証が完結した。
  ※CLT単体にXCTestが無い場合は `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` を一度実行）。
- バランスは「正典v2」に移行済み（`docs/canonical_v2_spec.md` が正本）。旧ドキュメントの数値は
  「正典v2移行」バナーつきの履歴。設計結論は有効、数値だけ読み替える。
- 直近でレッドチーム3視点レビュー実施（`docs/red_team_v0.md`）。指摘された「壊れていた旧テスト2本」は
  v2仕様に書き直し済み、シード制のテスト配線・golden出力の自動化も対応済み。

## ✅ 完了（P0）: swift test【2026-07-04 green】

```
cd GameCore && swift test
```

- **結果: 17件すべてgreen**（CareerGolden 1・CareerLogic 4・Engine 9・Golden 1・WeekRunnerGolden 2）。
  Python⇔Swiftの数式・乱数同期（12週・3年Career・WeekRunnerの3本）が実機で証明された＝この大改修全体の検証完了。
- **次のP0は「裏天井の設計＋sim較正」**（下記トリアージ順の2番）。
- golden再生成が必要になったら: `cd tools && python3 gen_golden.py`（出力は `CareerGoldenTests.swift` の
  `year1`/`yearEnds` にそのまま貼れる形）。正典順序は `gen_golden.py` の docstring。

## 次にやること（red_team_v0.md §4 のトリアージ順）

1. ✅ swift test 緑化（2026-07-04 green）
2. **裏天井の設計＋sim較正**（初回の保証弁。決勝未到達のまま晩年でハマ率累積。`tools/exp_v2_anchor.py`の枠で帯維持を確認）← **Fable待ちの本命**
3. ✅ 決勝敗北時の「優勝者指名」演出＝**設計完了**（`finals_direction_v0.md §4-D`。名鑑接続・判定は絶対ラインのまま表示だけ相対化）※コード実装は後
4. ✅ 成長上限の可視化＝**設計完了**（`ui_design_v0.md §2-B`。谷口の台詞化＋メンタル/相性/知名度の別出口設計）※コード実装は後
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
- 決勝敗北時の優勝者・ライバル: `champion_selection_v1.md`（正典・選出ロジック）/ `relationship_champions_v0.md`（絆＋優勝時セリフ）/ `name_generator_v0.md`（コンビ名生成）/ `rival_design_v0.md`（4組の役柄テンプレ）/ `partner_finals_reactions_v0.md`（相方別の袖反応・非谷口は関西弁にしない）
- キャラ: `partner_characters_v0.md`（相方R/SR/SSR）/ `judge_design_v0.md`（審査員7名）
- 収益: `monetization_decision_v0.md` / `pricing_proposal_v0.md`
- オーナー判断材料: `owner_decision_brief_v0.md`（決定記録①〜④含む）/ `concerns_register_v0.md`
- 検証機: `tools/` の `sim_career.py`（本体）`gen_golden.py`（正典順序）`exp_v2_*.py`（v2実測）
