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
- **審査員の"好み"研究（2026-07-17）**: `judge_preference_research_v0.md`（`judge_design_v0.md`の背景研究＝実在賞レースの採点作法だけをWeb調査で分解し架空7審査員へ翻案。**核心の誤解を正す＝審査トレンドは年で変わらない・各審査員が年をまたいで一貫した固有の物差しを持つ・年で変わるのは"パネルの配合"だけ**［用語を"審査トレンド"→"審査パネルの配合"に締める］。§1=採点作法の実測個人差［点差の大小/加点減点/甘辛/尺厳密/情の肩入れが年をまたいで安定］／§2=好みの7類型T1-T7＝既存7軸と1対1・**T5変わり者好きは独立枠を置かず卯月[新規性◎]と神楽坂[型破り◎/×]に内包**／§3=多軸で割れるからパネルが豊か＝"一番ウケた組が負ける"はドラマの燃料／§5=**ネタ型×好みの相性表**［◎○△×・王道しゃべくり/関係性/伏線回収/リターン型/非定型実験/瞬発/華先行×T1-T7・どの型にも◎が1つ＝勝ち筋担保］／§7=judge_design全審査員への接地確認表。**全て研究材料であり判定式に相性を乗せる提案ではない＝相性をスコアに乗せるかは judge_design §0 のオーナー決定・`replayability_research_v0.md` §7 の未決に属す（規律C-8）。実名/実在言い回し借用ゼロ・golden非干渉・数値は全て【仮】**）
- 収益: `monetization_decision_v0.md` / `pricing_proposal_v0.md`
- オーナー判断材料: `owner_decision_brief_v0.md`（決定記録①〜④含む）/ `concerns_register_v0.md`
- 実態把握（潜りすぎ対策）: `game_reality_check_v0.md`（中立ブリーフィング＝今どんなゲームか・強み弱み・本の要否・次の1手＝実機で遊ぶ）
- **多年リプレイ性 研究＋翻案（2026-07-17）**: `replayability_research_v0.md`（`genre_research_v0.md`の深掘り続編＝野球育成サクセス/競走馬育成/物語型ローグライトの機構をWeb調査で分解→"多年の楽しさの部品"10件を抽出。核心＝深みの伸びしろはほぼ全て**語り・入り口・目標の多様化**の側で**力インフレ不要**（本作の「金は強さに変換できない」原則の必然帰結）。目玉3件＝①年始の"今年の作戦"盤[相方芸風×ネタ型×審査トレンドの3すくみ・読みで回す]②前周の痕跡が次周に戻る縦糸[敗北の墓碑銘→後輩が型を継ぐ・物語のみ]③周回状態に反応する会話[膨大な軽口でなく少数を深く]。§5優先度4波／§6**禁輸リスト**[確率継承・数値ステ上げ・グラインドゲート・power creep等＝初回体験と世界観を壊す]／§7オーナー未決4件[審査員相性をスコアに乗せるか(judge§0格上げ)・前周キャラの固有名整合・第1波着手可否・目標宣言の毛色]。全提案は既存doc §に接地・golden非干渉・数値は全て【仮】）
- **多年キャリア＋7審査員 固定嗜好 統合設計（2026-07-17）**: `multiyear_and_judge_preference_integration_v0.md`（上記2研究docを**現行正典で裏取りし誤りを正した**設計統合＝2部構成。**第1部 多年キャリアの正しいモデル**＝(1)資格喪失≠引退だが**本編は結成10年完結で資格喪失に到達しない**＝切迫は"資格"でなく"10年目の壁"に接地・資格喪失は将来枠[ベテラン大会16年+]／(2)解散＝終わり方の語彙で**キャリアの境目に置く**[キャリア中は解散させない設計を動かさない]／(3)組み直し＝周回の縦糸＝**捨てるのはコンビ名と生の状態だけ・続くのはトロフィー/名鑑/知識/通算芸歴**／(4)先輩後輩＝**通算芸歴で関係役柄の出現配合を傾ける**[新システム不要・表示分岐]／(5)研究doc§1-C/§3-Cの**訂正**＝前周キャラを審査席や固有名で戻す案は削除[王者編廃止＋コンビ名毎周ランダム＝方針5と衝突]。**第2部 7審査員の固定嗜好**＝T1-T7を既存7審査員に固定割当・ネタ型×好みの相性表＝"読み"の正本・doc03能力軸モデルは**置き換えず"好みの類型"を足す3層化**・4.8作 FinalsPresentationView の見せ札tiltは既に萌芽[寄せるなら神楽坂の振れ幅個体化が費用対効果大・neta実装まで型ベースは先走らない]。各部末に**[オーナー判断待ち]1論点**＝1-α解散エンド追加可否／2-α相性をスコアに乗せる格上げ可否[規律A発動＝golden全再測の代償]。全て設計markdownのみ・golden非干渉・数値【仮】）
- **遊べるデモ 批評監査＋磨き込み（2026-07-13）**: `playable_demo_audit_v0.md`（Fable監査＝通しは成立・欠けは"言葉と受け皿"・次の一手=声の最小配線パック。P0〜P3＋設計⇔実装対照表）／実装記録=`demo_polish_batch_v0.md`（17件トリアージ＋オーナー確定Q1-3＝声パック優先/⑪準決置換/①整理だけ＋実装済みコミット＋後ろ倒し理由）
- 筆致・大衆性: `writing_craft_and_appeal_v0.md`（オーナー2問への回答＝条件つきyes／講評・心の声・描写の技法カタログ＝平凡→ウィット書き換え8例／ネタは書かない一線／今できること優先順／参考本リスト＝今すぐは塙のみ）
- **Fable最終日**: `fable_final_day_brief_v0.md`（残り1日の使い道確定＝1位「ゲームの声の金型」=文体バイブル＋技法タグ付きgold seed／候補ランキング／コピペ用キックオフ全文。合言葉「Fableは金型を彫る・4.8は鋳込む」。成果物予定 `voice_bible_v0.md`＋`voice_corpus_v0.md`）。**実現形は下記「声のSkill」＝`.claude/skills/manzai-drama-voice/references/voice-bible.md`ほか（ファイル名はSkill構成に合わせて変更・中身は本ブリーフの狙い通り）**
- **育成UIリデザイン**: `ui_redesign_pawapuro_uma_v0.md`（パワプロ サクセス/ウマ娘を調査→現状gapの正体→再設計スペック＝北極星「選ぶ→ゴースト予告→大実行ボタン→段階リビール→次週」／**RNG非消費の正直getter**定義（previewGains/baseScore/nextStageLine/injuryRisk）＝素朴版は逓減無視で嘘つき注意／P0優先順＝①段階リビール②地力vs通過ラインゲージ③ゴースト予告／critiqueの構造的弱点＝友情トレ不在・やる気非機構）。**オーナー確定v8＝コマンドを画面下に集約：①下にカテゴリ(稽古/回復/バイト/データ/アイテム)のアイコン→押すとアイコンが消えて同じ場所に変種カードが出る→変種を押したら実行して次週(アイコンに戻る)＝下ゾーンがアイコン⇄カード切替②戻るは右上のみ・片手完結・アイコンの造形は維持③決定ボタン無し(画面隅"決定"はコントローラ凡例)④能力アップ/おでかけ/システム(セーブ)無し＝セーブ自動⑤データ(実績)/アイテムの器は残す⑥怪我率/稽古Lvは廃止⑦能力は左上ピル/体力・所持金・週は下の帯/通過ライン非表示/サポカ無し⑧伸びは整数表示(2.8→3・現在値の整数→後の整数の差＝バーの変化と一致)。※10年でマックスしないのは成長逓減＋年間成長予算で担保済(正典v2)**。見た目正典モック `ui_mockup_pawapuro_v8.html`（**Playwright検証済＝実際に動く**・タップ可／v3-v7は旧・履歴）。**教訓: モックは公開前に /opt/pw-browsers-1194 のchromiumでロードしconsole/pageerror無し＋押下で状態遷移まで検証する(v5は親innerHTML上書きで子要素消え全render throw→無反応だった)**。**追補⑥（2026-07-08・オーナー未確定）**: 実機プレイで「伸びわずか」の味気なさを報告→選択肢整理のみ実施（A上限表示追加[推奨]／B定性◎○△表示／C中間経験点プール復活[要反証・既2度却下済]）。決定は次回。
- **パワプロ式 経験点/能力アップ機構 Fableプロンプト（2026-07-12）**: `proposals/FABLE_PROMPT_exp-abilityup.md`（追補⑥C＝中間経験点プール復活を**オーナー採用**→Fableに構造判断を投げる設計プロンプトv3。**核心＝既存`growthBudget`が実質「見えない経験点プール」で、可視化＋手動割り振りにするのがパワプロ化**／稼ぐ層(稽古)と振る層(割り振り)の分離／三案 X=単一プール・B=色付き簡略二層[叩き台推奨]・A=多対多／§7-3「意思決定希薄化」への正面応答を要求／**golden安全＝割り振り決定論・RNG非消費なら消費順不変だが、amount生成経路が変わる＝数式変更ゆえ gen_golden 再生成必須(規律A)**。オーナー追加5点織込＝①増加量とコスト曲線を1経済に(到達率アンカー41.5/23.1/8.4%)②イベント由来exp総供給③トロフィー=能力直接アップ(**canonical_v2「上限カーブ+0.02×pt/年」を上書き**)④全員楽しめて簡単すぎない⑤能力アップ欄UI/UX(4小見出し)。**Fable投下前のオーナー未決＝軸数確定／②イベント報酬経路／③canonical_v2正典移行バナー／⑤UI/UXスコープ拡張**。作成＝research→synthesize→author→敵対査読4観点→finalizeのworkflow・接地は実コード全数照合済）。**v3追加（同日）**＝⑥稽古経験点の毎回の揺らぎ（新規乱数draw・規律A-2に触れる別次元の変更として設問10(10a)に整理）／⑦稽古Lv反復効率（`ui_redesign_pawapuro_uma_v0.md`追補④の廃止決定を上書きするオーナー決定・既存成長逓減との綱引きを設問10(10b)で裁定）
- **パワプロ経験点 Fable回答＋実装可否レビュー（2026-07-12）**: `docs/exp_abilityup_reply_v0.md`（Fable設計書v1＝上記プロンプトへの応答・**未検証の設計正本候補**。骨格3点＝①軸数=案B(5能力色の簡略二層・同色1.0/他色η=0.5/メンタル一方通行壁)②減衰会計=既存add()の2段を分離[予算キャップ→稽古発行時"鋳造ゲート"・成長逓減→割り振り時]・価格表示反転③二層目制約=η+発行ゲート+壁。⑥揺らぎ=発行量のみ1draw固定段階抽選[golden再生成必須]・⑦稽古Lv=安全設計図つきMVP見送り推奨。器→経験点残高ゲージ転生・割り振り画面「伸ばす」。オーナー未決11件を列挙）。実装可否・golden安全性・接地正確性の敵対レビュー→`proposals/0040_exp-abilityup-feasibility.md`（4観点workflow・実コード裏取り）。**0040追補（simスパイク・2026-07-12）＝発行ゲート化はNO-GO実測(5.1/0.2/0.1%)／「割り振り時予算＋η廃止＋余剰許容」はbaseline完全再現でGO(41.5/23.1/8.4)。**
- **パワプロ経験点 実装フェーズFableプロンプト（2026-07-12）**: `proposals/FABLE_PROMPT_exp-abilityup-impl_v0.md`（v1骨格の再検討を終え**実装フェーズ第2便**。確定=発行ゲート/η/価格反転/支払いチップ全破棄・会計は「割り振り時予算＋同色＋余剰許容」でバランス安全確定。Fableに求める=①経験点カテゴリ構造を選び切る[論点A照準自由度=二区画中間が既定/B貯めの決定化/C一括注入の都度evaluateガード]②`AllocationView.swift`＋器転生＋GameSession/WeekMainView/RootView差分の**ビルド可能SwiftUIコード**③GameCore/sim下書き[`expBank`宣言確定・`projectedGain`単一純関数・golden台本単一化]。golden/sim/simulatorはMac側=形はFable・水準はMac。作成=scout→design→author→敵対査読3観点→finalizeのworkflow・接地は実コード裏取り済）
- **パワプロ経験点 実装フェーズFable回答＝機構確定＋実装（2026-07-13）**: `docs/exp_abilityup_impl_reply_v0.md`（**機構確定＝二区画中間**[同色ロック75%＋共通枠25%【仮】・共通枠はネタ=センス/発想・舞台=表現/華の各2能力限定・メンタル同色のみ・予算は総量プール単一不変]／タイミング=即時既定・銀行は中立バッファ／**注入=段刻みループ正典**[`allocationStep`全経路統一＝貯め込み1点評価上振れ+3.6〜4.7ptを構造で殺す・完全ロールバック=config2値のみ]。**実ファイル納品＋実測検証済**＝`AllocationView.swift`新規・GameSession/CommandData/WeekMainView/NotebookView/RootView差分・GameCore注ぐ側正典（`GameState.exp*`7フィールド・`Allocation.swift`=ExpGroup/projectedGain/pourStep/recommendedPlan・`WeekRunner.applyAllocation`・AllocationTests7件）→ **swift test 32件green（golden不変実測）・simulatorビルドSUCCEEDED・MZ_UI=allocate起動目視済**。残り=Mac側の会計移設（発行側・稽古→粒のρ分割クレジット）＋golden台本=`recommendedPlan`3系統鏡像＋golden全面再生成＋sim較正5ゲート（おすすめ最適度/メンタル蓄積/供給再照準/ρスイープ/銀行上振れ消滅）＋操作系の実機目視8点）
- **発行側の実装＋マージ完了（2026-07-13朝）**: `docs/exp_issuance_verification_v0.md`（会計移設・golden再生成・sim較正を実装→**共有ブランチへマージ済み**(`233b8ce`)・マージ後も私が独立に`swift test`再実行しPASS確認＝32件green・3年golden一致実測。sim較正=ρ0/供給スケール0.48【仮】で5ゲート全PASS・到達率やり込み45.0%(目標41.5・微調整余地あり)/のんびり22.9%/バランス8.8%。**オーナー確定＝ρ=0（同色1:1）採用・共通枠(ExpGroup)は機構として残置するがUI上は現行較正では実質未使用**。残＝lastGainsの粒差分振替(UIスコープ)・UI/simulatorビルド確認）
- **★発行側の重大な要是正（2026-07-13・Fable体験設計が発覚させた）**: `WeekRunner.proceed`(:313)が毎週`pourRecommended`で粒を**自動注ぎ**し切るため、**プレイヤーは割り振り決定ができず`AllocationView`が空＝経験点機構が実質プレイヤー無効**（ゲームは機構導入前と同じ挙動＋較正0.48のみ）。原因＝golden台本(sim/goldenの決定論的おすすめ注ぎ)を`WeekRunner`本体に入れてしまい実ゲーム経路へ漏れた。**是正案＝config.autoPourAllocation(既定true=golden/sim不変)を新設し`WeekRunner`のpourをガード、`GameSession`はfalseに設定→実ゲームは粒が貯まりプレイヤーが手動注ぎ。goldenはデフォルトtrueのまま不変＝再生成不要・golden安全**。
- **経験点ループの体験設計（Fable・2026-07-13）**: `docs/exp_earning_loop_ux_reply_v0.md`（Fable納品・制約遵守=コード/git不触・設計doc1枚・drama-voice採点済）。稼ぐ瞬間=「+N能力」を粒チップ(塗り=同色/輪郭=共通)へ／受け取り=入力を止めない1.7秒一拍／★バッジ意味論=粒総数→`recommendedPlan.count`(注げる段数=空振りゼロ)／満了=「この年の器は、満ちた。」を三面共有＋金の「満」判／新規ハプティクスゼロ・新規文言5つ。**照合2点=①ρ>0前提で書かれ共通粒部分は現状(ρ=0)休眠②上記の自動注ぎ是正が実装の前提**。実装はMac側(上記是正→§1カード置換→§2バッジ→§3誘導文→§4満了)
- **UI/UXビジョン回答（Fable・2026-07-07）**: `uiux_vision_reply_part1_v0.md`（第1便=依頼1・3・4＝AD様式「紙・照明・幕」／追加トークン（Space/Radius/Elevation/Motion/Haptics）／決勝9ビート＋見せ札合成＋テンポ規格。§0で決勝1本目=**7人一斉オープン**確定→`finals_direction_v0.md` §2-2/§4-C改訂済み）／`uiux_vision_reply_part2_v0.md`（第2便=依頼2・6＝**S1〜S6+S6bの画面別詳細**＋実装ブリッジ。S2のみ(A)/(B)2層・共用部品3点＝紙芝居/レーダー/壁写真・末尾に第3便用コピペブロック）／`uiux_vision_reply_part3_v0.md`（第3便=**S7〜S10+S10bの周回間ライブサービス層**＝楽屋の壁ハブ／S8オーディション「廊下→SE断0.6s→ドア→色が付く」2層・木札天井・再会・朱の栞／王者編=袖視点反転・判「防衛/陥落」・殿堂入りループ／S10=事実文トーン・煽り禁止。裁定5件うち石の世界観名「お花」は**オーナー確認待ち**）／`uiux_vision_reply_part4_v0.md`（第4便=**S11アイテムショップ「綴りと貼り紙」・S12図鑑記録「棚と年表」＋依頼5アセット3段表(A)/(B)＋S13将来ビジョン6件**。S11/S12は新文法ゼロ=既存部品の再配置）。プロンプト正本=`proposals/FABLE_PROMPT_uiux-vision.md`。**全4便完結（2026-07-07）**。課金石の呼称=**「サンパチ」**（2026-07-07オーナー確定・法務表記は「石」併記）＝便を跨ぐ未決ゼロ
- **UI実装トラック（2026-07-07開始・Fable第一弾済み）**: `uiux_impl_handoff_v0.md`（**実装トラックの正本**＝済み一覧/検証コマンド/MZ_UIスモーク/残り順序/CLIキックオフ文）。実装済み=§3-0トークン+Pressable/S2(B)完了（引き抜き・横ブレ・不足色・閾値明滅・器の充填・+N規格）/S3判の§3-5規格+段階開示（コミット352d1e9〜bf39457・simulator目視済み）。**次=S6年次リザルト**（レーダーCanvasを3画面共用部品として）
- **声のSkill（2026-07-06・Fable作）**: `.claude/skills/manzai-drama-voice/`（地の文・会話を書く/採点する中核。感情→物レシピ＋○×採点ゲート＋修復手筋＋良悪例対でモデル頑健化）＋任意の `manzai-choice-events`（選択肢イベント・golden安全内蔵）/`manzai-judge-comments`（7審査員講評）。正典は `proposals/fable_kickoff_drama_allin_v1.md`＋`0009` を写した種＝数値【仮】・実機目視で確定。**共有・引き継ぎ**: `docs/skill_handoff_v0.md`（Claude Codeはmainマージ＋pullで自動発動＝作業不要／リポジトリなしチャット用の持ち出しプロンプト／他プロジェクトへの移植手順）
- **パワプロ・サクセス化 第1弾（2026-07-24・実装済み）**: `powerpro_feel_v0.md`（オーナー評「ゲームっぽくない」への応答＝週の二拍リアクション（発話→週送り→獲得バースト）・週頭の掛け合い（俺⇄谷口・中だるみ帯は頻度UP）・常時目標バナー・週送りスタンプ・谷口評ランク・**中断セーブ/復帰（proposals/0039実装）**・衛生修正（WinFinaleView死にコード/通知許諾/固定シード/療養の判/準備中タイル）。全てgolden不変・§7-Bの演出レバーのみ。Mac検証チェックリスト付き）
- 検証機: `tools/` の `sim_career.py`（本体）`gen_golden.py`（正典順序）`exp_v2_*.py`（v2実測）
- Fable関連: `fable_plan_v0.md`（いつ・何に使うか）/ `sim_scaffold_spec_v0.md`（受け皿の実装スペックT1-T6）/ **`fable_kickoff_prompt_v2.md`（現行・“最後のFable”完全版・ultrathink＋Q1ラストイヤー/Q2角/Q3面白さ俯瞰・コピペ即用）** / **`verdict_draft_v0.md`（4.8がsim反証まで済ませたQ1/Q2候補裁定＝Fableの叩き台）** / `fable_readiness_v0.md`（受け皿3台の検証状況＝地図）/ 旧: `fable_kickoff_prompt_v0/v1.md`・`fable_session_brief_v0.md` ※受け皿台 `tools/exp_lastyear.py`・`exp_corner.py`・`exp_talent_ability.py`・`exp_lastyear_gate.py`・`exp_corner_multiseed.py`・`exp_lastyear_fable.py`(層分解/CI/成分分解) は実装・検証済(golden非干渉)
- **Fable裁定（2026-07-05実施済）**: `pity_calibration_v0.md`（裏天井の効果式・実測13セル＋推奨1点）/ `fable_findings_v0.md`（Q3/Q4/Q5と申し送り）/ **`lastyear_calibration_v0.md`（Q1ラストイヤー=X=2・ゲート必須）/ `corner_arbitration_v0.md`（Q2角=必勝化せず・二重壁）/ `fun_flow_review_v0.md`（Q3中だるみ/アーク最弱点/演出解）**
- **Fable裁定の反証検証（2026-07-05・4.8）**: `verdict_verification_v0.md`（Fableが振ってない条件で3裁定を独立反証＝受理可否の回答。載荷主張B/E/F/G後半/Hはconfirmed・Aは"X=2両側一意"がrefuted＝単一シードのナイフエッジ・C/D/F/G前半は数値に但し書き。golden無傷・§3=Mac配線チェックリスト・§4=正典再測待ち）
- **ネタ・システム Phase 0 実装完了（2026-07-18・4.8）**: `neta_system_redesign_v2.md`（正本・旧Fable案「年始に型を選ぶ」をオーナーが却下→調査で裏取りした正しいモデル「ネタ作り→ライブ(ネタ見せ会/フリーライブ)で磨く→持ちネタ帳(アクティブ枠+保管庫の二層)に貯まる→大会でどれを出すか選ぶ」に全面刷新。型は年単位の選択でなくネタ1本が持つ属性）。**実装済み**＝`GameCore/Neta.swift`(型7種・尺・完成度・手応え・おろし)／`GameSession`のapplyNetaWork(3秒動線を壊さず自動生成/改稿/ライブ反映)／`NotebookView`第3タブ「ネタ」(型ピッカー・改名・退避/呼び戻し)／大会入口・GP各段の「今かけるネタ」選択カード(尺マッチ表示・決勝2枠)／決勝見せ札の型ラベル(7審査員固定嗜好・`multiyear`§2-3の写し・純表示でFinalsData計算に非干渉)／ネタおろし一言(manzai-drama-voice採点済)。**golden完全不変**（perform式にネタ不参入・全てRNG非消費）＝swift test 41→53件green（順次追加）。"反応で磨く(当たり外れ)"「選択が勝敗に効く」はモデルの核だがスコア/乱数を要する＝Phase 1(規律A)は将来枠・当面やらない。
- **選択肢イベント MVP実装完了（2026-07-18・4.8）**: `proposals/0024_choice-event-mvp-framework.md`（実装ブリーフ・オーナー確定2026-07-06「確定発火＋確定効果の薄い土台」）に従い6本を実プレイに配線＝**0017負けた日の稽古場(justLost・3択+所持金ゲート)／0019型を捨てる相談(lossStreak≥3・一発化)／0018通った日の分かれ道(justPassedStage・weeksLeft≥3+体力ガード)／0010前夜の一本(weeksLeft==1・格の高い大会のみ・A内部ロールは0024でMVP対象外に降格)／0020まだ敬語の残る間(結成初期week<15×他人行儀帯・一発化)／0021慣れの外し方(相性初到達15・一発化)**。実装＝`GameCore/ChoiceEvent.swift`(純データ・EventEffect配列のみ)／`GameSession`のevaluateChoiceEventFire(週頭.freeAction確定直後・優先順位固定)+applyEventChoice／`ChoiceEventOverlay.swift`(新規・セットアップ→会話送り→選択肢→選択後会話→閉じる)／`ChoiceEventData.swift`(谷口版本文・各proposalsのレッドチーム済確定テキストを転記)。**golden完全不変**（確定発火=抽選なし・効果=決定的delta=RandomSource非消費）＝swift test 55件green。**0022(撮られる仕事)は見送り**＝既存`rollOffer`がRNGを2回消費する正典関数(Python鏡像あり)と判明し変更に規律A手順が必要なため。0011-0016/0023は週次12%ランダム抽選が前提で新規RNG消費＝止めて相談の対象、今回は未着手。
- **「全部実装」ビルドアウト 第1弾（2026-07-19・4.8）**: `full_buildout_plan_v0.md`（オーナー「全部実装して。試したい」を受けた全体地図＝未実装分をgolden影響で3群に仕分け）。**第1弾完了・全てgolden不変を実測**＝①**ネタ Phase 1-a**（選択が勝敗に効く）＝`GameEngine.netaScoreBonus`(完成度polish×0.04+手応えbuzz×0.02・±5クランプ・決勝2本制ペナ)を perform 実効ラインから引く・**selectedNetaID ゲートで golden 経路恒等0**・sim `NETA_COEF_COMP=0.04`【優勝率±0年較正済】が正典・gen_golden再生成でyear-end期待値バイト一致・swift test 59件green②**週次ランダムイベント基盤**＝`GameSession`が UI専用`SplitMix64`を runner と別インスタンス保持（独立乱数列＝golden非干渉）・`evaluateChoiceEventFire`を確定発火6本＋週次12%抽選(1週1回・総量`weeklyEventCap=15`・1回制`firedWeeklyEvents`)に拡張＝**「週次抽選=golden破壊」の従来前提を覆した**（sim/golden別系統を裏取り）③**0011行けない飲み会**(所持金<5万)/**0013先輩の名刺**(所持金<20万・知名度<50・第三者「先輩」登場)/**0015畳んだコンビの椅子**(week≥20)を週次プールに④**フレーバー会話イベント基盤**(選択肢なし=会話送り→閉じる・`ChoiceEventOverlay`拡張)＋**0028名前の無い予約票**(確定発火・compat≥8・大会2-5週前・効果なし)。目視=`MZ_UI=event MZ_EV=00XX`(DEBUG導線・`debugForceEvent`)。**C群1-b(型×審査員相性スコア)/1-c(buzz客層依存乱数)はオーナー確定で見送り**(試遊後に判断)。**残り**=フリーライブ直後フック系(0014/0025/0027/0029)＋0023段階1はgolden安全で追加可／0012(compatFreezeWeeks)・0022(rollOffer)は規律A(golden全再測)でオーナー確認要。数値は全て【仮】。
- **将来枠（Phase2）実装（2026-07-20・4.8）**: `future_slot_impl_v0.md`（`full_buildout_plan` の「将来枠」を解凍）。**実装済＝**①**0016 翌週バフ**(`netaBoostWeeks`+`EventEffect.netaBoostNextWeek`+`applyNetaRevise`乗算+`tickNetaBoost`・commit ccb4d93)②**0023 成長天井減算**(`EventEffect.growthCeiling`＝`growthBudget`減算・commit be9bcc6)③**0022 稽古ロック**(`preoccupiedWeeks`+`EventEffect.preoccupyNextWeek`+`tickPreoccupied`＝撮影を受けた週は稽古5枚グレー「撮影で埋まる」・enforcementはUI層でresolveAction非経路)＝**3本とも0012相性凍結と同型のinertフィールド＝golden完全不変を実測**(gen_golden再生成バイト一致・swift test 72件green・iOS BUILD SUCCEEDED＋目視)。**オーナー確定(2026-07-20)＝**0022=乙(稽古ロック)/**1-b=試遊後判断**(golden全再測ゆえ据置・1-aと違いgoldenキャリアにも常時効く)/**1-c=やらない**(消費順再設計ゆえ)。数値は全て【仮】。
