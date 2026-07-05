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
2. ✅ 裏天井の設計＋sim較正（2026-07-05・`pity_calibration_v0.md`・BP0.30オーナー確定②）※run_year本実装＋正典再測はMac/4.8の残タスク
3. ✅ 決勝敗北時の「優勝者指名」演出＝**設計完了**（`finals_direction_v0.md §4-D`。名鑑接続・判定は絶対ラインのまま表示だけ相対化）※コード実装は後
4. ✅ 成長上限の可視化＝**設計完了**（`ui_design_v0.md §2-B`。谷口の台詞化＋メンタル/相性/知名度の別出口設計）※コード実装は後
5. runYear→WeekRunner委譲（ui_design §5。golden緑の確認後）＋ GameStateのCodable化・中断復帰
6. Xcodeプロジェクト作成→S2週メインから触れるビルド（ui_design §7）

## オーナー判断待ちの2大論点（勝手に進めない）

1. **業態**: B案F2P続行か、ハイブリッド（序盤無料＋本編980円＋コスメ/DLC）か。
   レッドチームの数字はハイブリッド優位。検証①ビルドの手応え＋事前登録の数字を見てから最終決定の方針。
2. **初回の保証弁**: 裏天井を入れるか。推奨は入れる（simで帯内を確認してから）。

## モデルの使い分け

- **Fable（2026-07-05・最終セッション実施済み）**: Q1ラストイヤー＝**X=2・停滞層ゲート必須・G2許容帯化**（`lastyear_calibration_v0.md`）／Q2角＝**60.75%<90%必勝化せず・角補正不要(本実装後再測条件)**（`corner_arbitration_v0.md`）／Q3面白さ俯瞰3点（`fun_flow_review_v0.md`）を裁定済み。残タスクは各docの「Fable後のTODO」（Mac=run_year本実装・4.8=正典再測）へ移管済み。新たなFable向き問いが出たら `fable_plan_v0.md` の基準で判断。
- **4.8**: 量産・実装・パターン踏襲・UIスキャフォールディング・ドキュメント整備・**閾値スイープ/差分測定（Fableに投げない）**。

## 主要ドキュメント索引

- 正本: `master_spec_v2.md` / `canonical_v2_spec.md`
- 検証: `human_calibration_v0.md`（借金バグ発見）/ `rule_holes_v0.md`（生活ルール）/ `red_team_v0.md`
- UI/演出: `ui_design_v0.md` / `finals_direction_v0.md` / `fan_report_design_v0.md` / `onboarding_script_v0.md`
- 決勝敗北時の優勝者・ライバル: `champion_selection_v1.md`（正典・選出ロジック）/ `relationship_champions_v0.md`（絆＋優勝時セリフ）/ `relationship_archetype_variants_v0.md`（後輩/先輩/同期を毎周別の型に）/ `name_generator_v0.md`（コンビ名生成）/ `rival_design_v0.md`（4組の役柄テンプレ）/ `partner_finals_reactions_v0.md`（相方別の袖反応・非谷口は関西弁にしない）
- キャラ: `partner_characters_v0.md`（相方・男6/女4＝得意能力6軸を網羅）/ `character_archetypes_v0.md`（22類型×口調×得意能力・後輩/先輩の量産型）/ `partner_finals_reactions_v0.md`（相方別の袖反応）/ `judge_design_v0.md`（審査員7名）
- 収益: `monetization_decision_v0.md` / `pricing_proposal_v0.md`
- オーナー判断材料: `owner_decision_brief_v0.md`（決定記録①〜④含む）/ `concerns_register_v0.md`
- 実態把握（潜りすぎ対策）: `game_reality_check_v0.md`（中立ブリーフィング＝今どんなゲームか・強み弱み・本の要否・次の1手＝実機で遊ぶ）
- 筆致・大衆性: `writing_craft_and_appeal_v0.md`（オーナー2問への回答＝条件つきyes／講評・心の声・描写の技法カタログ＝平凡→ウィット書き換え8例／ネタは書かない一線／今できること優先順／参考本リスト＝今すぐは塙のみ）
- **育成UIリデザイン**: `ui_redesign_pawapuro_uma_v0.md`（パワプロ サクセス/ウマ娘を調査→現状gapの正体→再設計スペック＝北極星「選ぶ→ゴースト予告→大実行ボタン→段階リビール→次週」／**RNG非消費の正直getter**定義（previewGains/baseScore/nextStageLine/injuryRisk）＝素朴版は逓減無視で嘘つき注意／P0優先順＝①段階リビール②地力vs通過ラインゲージ③ゴースト予告／critiqueの構造的弱点＝友情トレ不在・やる気非機構）。**オーナー確定v6＝パワプロ2022サクセス準拠：①能力は左上のダークピル＋オレンジの+増加分②稽古は中央下のカード横一列(選択で拡大＋体調ダウン率バッジ)③体力/所持金/学年週/試合まで週は"下の帯"に集約(オーナー「所持金もこう見えてる」)④右上に戻る/決定・2タップ(カード押す→選択→もう一度or決定で実行)⑤右のサポカ枠は作らない・通過ライン非表示**。見た目正典モック `ui_mockup_pawapuro_v6.html`（**Playwrightでブラウザ検証済＝実際に動く**・タップ可／v3-v5は旧・履歴）。**教訓: モックは公開前に /opt/pw-browsers のchromiumでロードしconsole/pageerror無し＋押下で状態遷移まで検証する(v5は親innerHTML上書きで子要素消え全render throw→無反応だった)**
- 検証機: `tools/` の `sim_career.py`（本体）`gen_golden.py`（正典順序）`exp_v2_*.py`（v2実測）
- Fable関連: `fable_plan_v0.md`（いつ・何に使うか）/ `sim_scaffold_spec_v0.md`（受け皿の実装スペックT1-T6）/ **`fable_kickoff_prompt_v2.md`（現行・“最後のFable”完全版・ultrathink＋Q1ラストイヤー/Q2角/Q3面白さ俯瞰・コピペ即用）** / **`verdict_draft_v0.md`（4.8がsim反証まで済ませたQ1/Q2候補裁定＝Fableの叩き台）** / `fable_readiness_v0.md`（受け皿3台の検証状況＝地図）/ 旧: `fable_kickoff_prompt_v0/v1.md`・`fable_session_brief_v0.md` ※受け皿台 `tools/exp_lastyear.py`・`exp_corner.py`・`exp_talent_ability.py`・`exp_lastyear_gate.py`・`exp_corner_multiseed.py`・`exp_lastyear_fable.py`(層分解/CI/成分分解) は実装・検証済(golden非干渉)
- **Fable裁定（2026-07-05実施済）**: `pity_calibration_v0.md`（裏天井の効果式・実測13セル＋推奨1点）/ `fable_findings_v0.md`（Q3/Q4/Q5と申し送り）/ **`lastyear_calibration_v0.md`（Q1ラストイヤー=X=2・ゲート必須）/ `corner_arbitration_v0.md`（Q2角=必勝化せず・二重壁）/ `fun_flow_review_v0.md`（Q3中だるみ/アーク最弱点/演出解）**
- **Fable裁定の反証検証（2026-07-05・4.8）**: `verdict_verification_v0.md`（Fableが振ってない条件で3裁定を独立反証＝受理可否の回答。載荷主張B/E/F/G後半/Hはconfirmed・Aは"X=2両側一意"がrefuted＝単一シードのナイフエッジ・C/D/F/G前半は数値に但し書き。golden無傷・§3=Mac配線チェックリスト・§4=正典再測待ち）
