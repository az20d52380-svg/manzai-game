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
- **Fable最終日**: `fable_final_day_brief_v0.md`（残り1日の使い道確定＝1位「ゲームの声の金型」=文体バイブル＋技法タグ付きgold seed／候補ランキング／コピペ用キックオフ全文。合言葉「Fableは金型を彫る・4.8は鋳込む」。成果物予定 `voice_bible_v0.md`＋`voice_corpus_v0.md`）
- **育成UIリデザイン**: `ui_redesign_pawapuro_uma_v0.md`（パワプロ サクセス/ウマ娘を調査→現状gapの正体→再設計スペック＝北極星「選ぶ→ゴースト予告→大実行ボタン→段階リビール→次週」／**RNG非消費の正直getter**定義（previewGains/baseScore/nextStageLine/injuryRisk）＝素朴版は逓減無視で嘘つき注意／P0優先順＝①段階リビール②地力vs通過ラインゲージ③ゴースト予告／critiqueの構造的弱点＝友情トレ不在・やる気非機構）。**オーナー確定v8＝コマンドを画面下に集約：①下にカテゴリ(稽古/回復/バイト/データ/アイテム)のアイコン→押すとアイコンが消えて同じ場所に変種カードが出る→変種を押したら実行して次週(アイコンに戻る)＝下ゾーンがアイコン⇄カード切替②戻るは右上のみ・片手完結・アイコンの造形は維持③決定ボタン無し(画面隅"決定"はコントローラ凡例)④能力アップ/おでかけ/システム(セーブ)無し＝セーブ自動⑤データ(実績)/アイテムの器は残す⑥怪我率/稽古Lvは廃止⑦能力は左上ピル/体力・所持金・週は下の帯/通過ライン非表示/サポカ無し⑧伸びは整数表示(2.8→3・現在値の整数→後の整数の差＝バーの変化と一致)。※10年でマックスしないのは成長逓減＋年間成長予算で担保済(正典v2)**。見た目正典モック `ui_mockup_pawapuro_v8.html`（**Playwright検証済＝実際に動く**・タップ可／v3-v7は旧・履歴）。**教訓: モックは公開前に /opt/pw-browsers-1194 のchromiumでロードしconsole/pageerror無し＋押下で状態遷移まで検証する(v5は親innerHTML上書きで子要素消え全render throw→無反応だった)**。**追補⑥（2026-07-08・オーナー未確定）**: 実機プレイで「伸びわずか」の味気なさを報告→選択肢整理のみ実施（A上限表示追加[推奨]／B定性◎○△表示／C中間経験点プール復活[要反証・既2度却下済]）。決定は次回。
- **パワプロ式 経験点/能力アップ機構 Fableプロンプト（2026-07-12）**: `proposals/FABLE_PROMPT_exp-abilityup.md`（追補⑥C＝中間経験点プール復活を**オーナー採用**→Fableに構造判断を投げる設計プロンプトv3。**核心＝既存`growthBudget`が実質「見えない経験点プール」で、可視化＋手動割り振りにするのがパワプロ化**／稼ぐ層(稽古)と振る層(割り振り)の分離／三案 X=単一プール・B=色付き簡略二層[叩き台推奨]・A=多対多／§7-3「意思決定希薄化」への正面応答を要求／**golden安全＝割り振り決定論・RNG非消費なら消費順不変だが、amount生成経路が変わる＝数式変更ゆえ gen_golden 再生成必須(規律A)**。オーナー追加5点織込＝①増加量とコスト曲線を1経済に(到達率アンカー41.5/23.1/8.4%)②イベント由来exp総供給③トロフィー=能力直接アップ(**canonical_v2「上限カーブ+0.02×pt/年」を上書き**)④全員楽しめて簡単すぎない⑤能力アップ欄UI/UX(4小見出し)。**Fable投下前のオーナー未決＝軸数確定／②イベント報酬経路／③canonical_v2正典移行バナー／⑤UI/UXスコープ拡張**。作成＝research→synthesize→author→敵対査読4観点→finalizeのworkflow・接地は実コード全数照合済）。**v3追加（同日）**＝⑥稽古経験点の毎回の揺らぎ（新規乱数draw・規律A-2に触れる別次元の変更として設問10(10a)に整理）／⑦稽古Lv反復効率（`ui_redesign_pawapuro_uma_v0.md`追補④の廃止決定を上書きするオーナー決定・既存成長逓減との綱引きを設問10(10b)で裁定）
- **パワプロ経験点 Fable回答＋実装可否レビュー（2026-07-12）**: `docs/exp_abilityup_reply_v0.md`（Fable設計書v1＝上記プロンプトへの応答・**未検証の設計正本候補**。骨格3点＝①軸数=案B(5能力色の簡略二層・同色1.0/他色η=0.5/メンタル一方通行壁)②減衰会計=既存add()の2段を分離[予算キャップ→稽古発行時"鋳造ゲート"・成長逓減→割り振り時]・価格表示反転③二層目制約=η+発行ゲート+壁。⑥揺らぎ=発行量のみ1draw固定段階抽選[golden再生成必須]・⑦稽古Lv=安全設計図つきMVP見送り推奨。器→経験点残高ゲージ転生・割り振り画面「伸ばす」。オーナー未決11件を列挙）。実装可否・golden安全性・接地正確性の敵対レビュー→`proposals/0040_exp-abilityup-feasibility.md`（4観点workflow・実コード裏取り）。**0040追補（simスパイク・2026-07-12）＝発行ゲート化はNO-GO実測(5.1/0.2/0.1%)／「割り振り時予算＋η廃止＋余剰許容」はbaseline完全再現でGO(41.5/23.1/8.4)。**
- **パワプロ経験点 実装フェーズFableプロンプト（2026-07-12）**: `proposals/FABLE_PROMPT_exp-abilityup-impl_v0.md`（v1骨格の再検討を終え**実装フェーズ第2便**。確定=発行ゲート/η/価格反転/支払いチップ全破棄・会計は「割り振り時予算＋同色＋余剰許容」でバランス安全確定。Fableに求める=①経験点カテゴリ構造を選び切る[論点A照準自由度=二区画中間が既定/B貯めの決定化/C一括注入の都度evaluateガード]②`AllocationView.swift`＋器転生＋GameSession/WeekMainView/RootView差分の**ビルド可能SwiftUIコード**③GameCore/sim下書き[`expBank`宣言確定・`projectedGain`単一純関数・golden台本単一化]。golden/sim/simulatorはMac側=形はFable・水準はMac。作成=scout→design→author→敵対査読3観点→finalizeのworkflow・接地は実コード裏取り済）
- **パワプロ経験点 実装フェーズFable回答＝機構確定＋実装（2026-07-13）**: `docs/exp_abilityup_impl_reply_v0.md`（**機構確定＝二区画中間**[同色ロック75%＋共通枠25%【仮】・共通枠はネタ=センス/発想・舞台=表現/華の各2能力限定・メンタル同色のみ・予算は総量プール単一不変]／タイミング=即時既定・銀行は中立バッファ／**注入=段刻みループ正典**[`allocationStep`全経路統一＝貯め込み1点評価上振れ+3.6〜4.7ptを構造で殺す・完全ロールバック=config2値のみ]。**実ファイル納品＋実測検証済**＝`AllocationView.swift`新規・GameSession/CommandData/WeekMainView/NotebookView/RootView差分・GameCore注ぐ側正典（`GameState.exp*`7フィールド・`Allocation.swift`=ExpGroup/projectedGain/pourStep/recommendedPlan・`WeekRunner.applyAllocation`・AllocationTests7件）→ **swift test 32件green（golden不変実測）・simulatorビルドSUCCEEDED・MZ_UI=allocate起動目視済**。残り=Mac側の会計移設（発行側・稽古→粒のρ分割クレジット）＋golden台本=`recommendedPlan`3系統鏡像＋golden全面再生成＋sim較正5ゲート（おすすめ最適度/メンタル蓄積/供給再照準/ρスイープ/銀行上振れ消滅）＋操作系の実機目視8点）
- **発行側の実装＋マージ完了（2026-07-13朝）**: `docs/exp_issuance_verification_v0.md`（会計移設・golden再生成・sim較正を実装→**共有ブランチへマージ済み**(`233b8ce`)・マージ後も私が独立に`swift test`再実行しPASS確認＝32件green・3年golden一致実測。sim較正=ρ0/供給スケール0.48【仮】で5ゲート全PASS・到達率やり込み45.0%(目標41.5・微調整余地あり)/のんびり22.9%/バランス8.8%。**オーナー確定＝ρ=0（同色1:1）採用・共通枠(ExpGroup)は機構として残置するがUI上は現行較正では実質未使用**。残＝lastGainsの粒差分振替(UIスコープ)・UI/simulatorビルド確認）
- **UI/UXビジョン回答（Fable・2026-07-07）**: `uiux_vision_reply_part1_v0.md`（第1便=依頼1・3・4＝AD様式「紙・照明・幕」／追加トークン（Space/Radius/Elevation/Motion/Haptics）／決勝9ビート＋見せ札合成＋テンポ規格。§0で決勝1本目=**7人一斉オープン**確定→`finals_direction_v0.md` §2-2/§4-C改訂済み）／`uiux_vision_reply_part2_v0.md`（第2便=依頼2・6＝**S1〜S6+S6bの画面別詳細**＋実装ブリッジ。S2のみ(A)/(B)2層・共用部品3点＝紙芝居/レーダー/壁写真・末尾に第3便用コピペブロック）／`uiux_vision_reply_part3_v0.md`（第3便=**S7〜S10+S10bの周回間ライブサービス層**＝楽屋の壁ハブ／S8オーディション「廊下→SE断0.6s→ドア→色が付く」2層・木札天井・再会・朱の栞／王者編=袖視点反転・判「防衛/陥落」・殿堂入りループ／S10=事実文トーン・煽り禁止。裁定5件うち石の世界観名「お花」は**オーナー確認待ち**）／`uiux_vision_reply_part4_v0.md`（第4便=**S11アイテムショップ「綴りと貼り紙」・S12図鑑記録「棚と年表」＋依頼5アセット3段表(A)/(B)＋S13将来ビジョン6件**。S11/S12は新文法ゼロ=既存部品の再配置）。プロンプト正本=`proposals/FABLE_PROMPT_uiux-vision.md`。**全4便完結（2026-07-07）**。課金石の呼称=**「サンパチ」**（2026-07-07オーナー確定・法務表記は「石」併記）＝便を跨ぐ未決ゼロ
- **UI実装トラック（2026-07-07開始・Fable第一弾済み）**: `uiux_impl_handoff_v0.md`（**実装トラックの正本**＝済み一覧/検証コマンド/MZ_UIスモーク/残り順序/CLIキックオフ文）。実装済み=§3-0トークン+Pressable/S2(B)完了（引き抜き・横ブレ・不足色・閾値明滅・器の充填・+N規格）/S3判の§3-5規格+段階開示（コミット352d1e9〜bf39457・simulator目視済み）。**次=S6年次リザルト**（レーダーCanvasを3画面共用部品として）
- **声のSkill（2026-07-06・Fable作）**: `.claude/skills/manzai-drama-voice/`（地の文・会話を書く/採点する中核。感情→物レシピ＋○×採点ゲート＋修復手筋＋良悪例対でモデル頑健化）＋任意の `manzai-choice-events`（選択肢イベント・golden安全内蔵）/`manzai-judge-comments`（7審査員講評）。正典は `proposals/fable_kickoff_drama_allin_v1.md`＋`0009` を写した種＝数値【仮】・実機目視で確定。**共有・引き継ぎ**: `docs/skill_handoff_v0.md`（Claude Codeはmainマージ＋pullで自動発動＝作業不要／リポジトリなしチャット用の持ち出しプロンプト／他プロジェクトへの移植手順）
- 検証機: `tools/` の `sim_career.py`（本体）`gen_golden.py`（正典順序）`exp_v2_*.py`（v2実測）
- Fable関連: `fable_plan_v0.md`（いつ・何に使うか）/ `sim_scaffold_spec_v0.md`（受け皿の実装スペックT1-T6）/ **`fable_kickoff_prompt_v2.md`（現行・“最後のFable”完全版・ultrathink＋Q1ラストイヤー/Q2角/Q3面白さ俯瞰・コピペ即用）** / **`verdict_draft_v0.md`（4.8がsim反証まで済ませたQ1/Q2候補裁定＝Fableの叩き台）** / `fable_readiness_v0.md`（受け皿3台の検証状況＝地図）/ 旧: `fable_kickoff_prompt_v0/v1.md`・`fable_session_brief_v0.md` ※受け皿台 `tools/exp_lastyear.py`・`exp_corner.py`・`exp_talent_ability.py`・`exp_lastyear_gate.py`・`exp_corner_multiseed.py`・`exp_lastyear_fable.py`(層分解/CI/成分分解) は実装・検証済(golden非干渉)
- **Fable裁定（2026-07-05実施済）**: `pity_calibration_v0.md`（裏天井の効果式・実測13セル＋推奨1点）/ `fable_findings_v0.md`（Q3/Q4/Q5と申し送り）/ **`lastyear_calibration_v0.md`（Q1ラストイヤー=X=2・ゲート必須）/ `corner_arbitration_v0.md`（Q2角=必勝化せず・二重壁）/ `fun_flow_review_v0.md`（Q3中だるみ/アーク最弱点/演出解）**
- **Fable裁定の反証検証（2026-07-05・4.8）**: `verdict_verification_v0.md`（Fableが振ってない条件で3裁定を独立反証＝受理可否の回答。載荷主張B/E/F/G後半/Hはconfirmed・Aは"X=2両側一意"がrefuted＝単一シードのナイフエッジ・C/D/F/G前半は数値に但し書き。golden無傷・§3=Mac配線チェックリスト・§4=正典再測待ち）
