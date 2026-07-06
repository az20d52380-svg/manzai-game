<!-- 夜間提案 0005 / 研究→起草→レッドチーム(A/B) 完了 / コード改変なし・提案のみ -->
<!-- ※会話の基調はドラマ主軸へ再調整予定（参考作品リサーチ後に一括re-tone）。現状サンプルはウィット寄りが残る。 -->

<!-- 夜間提案 0005 / 研究→起草→レッドチームA/B反映 完了 / コード改変なし・提案のみ -->

# 天丼・伏線回収の中央管理機構 v0 — CallbackLedger 提案（2026-07-05起草・2026-07-06 レッドチームA/B反映）

対象: manzai-game（漫才コンビ育成SLG・iOS/SwiftUI・本編10年・MVPは1年完結・週送り・数値は全て【仮】）。位置づけ: `writing_craft_and_appeal_v0.md §7`（同一ギャグ最短再登場間隔=GameConfig【仮】）・`dialogue_design_v0.md §6`（「腹減ったな」1年2回制・感情最大点への配置）・`dialogue_batch3_v0.md §2`（人物帳＝熊井/布施/雨宿り/オリオン）・同 `§9未決2`（MVP1年版で回収がほぼ発火しない自認）を**束ねる1枚**。これは提案であり、既存ファイルは編集しない。正典順序（`tools/*.py`→GameCore→golden再生成）は崩さない。

---

## 狙い

天丼と伏線回収の設計が各docに散らばり、**台帳（誰の・どの語を・いつ・何回目か）が無いため間隔保証も乱用検知も効かない**。この機構で3つを一括で成立させる。

1. **乱用検知**: 最短再登場間隔違反・段数超過・同一variant連続を単一データ構造が弾く（＝`writing_craft §7`「口癖天丼は状況を変えて回す」の機構的実装）。
2. **段数管理**: 「1回目は効かない／3回目が最大」（Rule of Three）を状態として持つ。ただし効かせる先は**大会の笑い波形ではなく、その口癖を「どう見せるか」（演出強度・間・文字の強調）だけ**。笑い波形＝ネタの抽象出力に会話の口癖天丼を結線すると層が混ざり、かつ判定/RNGに触れて golden（3年ビット一致）を割る恐れがあるため、**波形とは分離**する（ボケ本文は書かない）。
3. **回収保証**: 伏線を張るときに回収予定週を必須化し、1年内に回収できないものは**機構的に張らせない/前倒す**。`§9未決2` の「回収が発火しない」を、確率差込から**固定セクション枠＋接触フラグ解放（コンボ型）**へ寄せて潰す。

## 対象箇所

- `writing_craft_and_appeal_v0.md §7`（項99・118）: `minReappearGap`【仮】の実体化。
- `dialogue_design_v0.md §6`: 「腹減ったな」1年2回制・希釈禁止・直近使用ID回避の仕組みを台帳へ統合（審査員コメントの直近回避と同一機構を共用＝§6実装メモ）。
- `dialogue_batch3_v0.md §2`: 人物帳4件の初出→再登場→最終回収を「固定枠＋接触フラグ」で保証。
- `dialogue_batch3_v0.md §9未決2`: MVP1年版の回収前倒し可否をこの台帳の `payoffScheduledSlot` で判定。

## どこから学んだか（技術＋出典URL）

- **3段エスカレーション（1回目は笑いなし→3回目が最大）／「1場面1〜2回」が乱用境界**: https://www.choge-blog.com/japanese/tendon/ , https://owa-rai.com/tendon/ , https://e-kae-library.com/tendon/
- **時間差天丼＝忘却が効く最適間隔帯（短すぎしつこい・長すぎ気づかれない）／状況(variant)を変えると延命**: https://detail.chiebukuro.yahoo.co.jp/qa/question_detail/q1015229150 , https://note.com/dreamy_peony4904/n/n9b06f27aa9f4
- **Rule of Three＝2つでパターン→3つ目で裏切り／SAP(Setup-Anticipation-Punchline)**: https://en.wikipedia.org/wiki/Rule_of_three_(writing) , https://punchlinecopy.com/funnier-copy-rule-of-3/ , https://nofilmschool.com/rule-of-the-three
- **「回収されて初めて伏線」＝未回収はノイズ／回収は意外性(twist)を1つ足す**: https://strobofactory.net/blogs/film/the-perfect-balance-of-foreshadowing-and-payoff-scene-composition-techniques-learned-from-masterpieces , https://note.com/shinypinkchina/n/nb2e8f5c9128a
- **仕込みはさりげなく（回収まで普通の会話に溶かす）**: https://note.com/ponk77/n/nc4624c0e8664 , https://www.kazz-spot.com/gekisaku/3-4/
- **回収は後半に密度を寄せる／setup×payoffの相乗**: https://data-everyday.com/stat_ml/post-3093/ , https://note.com/bunri_106/n/n0a30a05d5b72
- **固定セクション枠と乱数枠の分離／週×前後スロット／接触フラグ→後続解放のコンボ型（回収の確実性）**: https://xn--odkm0eg.gamewith.jp/article/show/46318 , https://game8.jp/pawapuro2026-2027/791406 , https://shinumae.oops.jp/wordpress/scp-p2022/

## 実装イメージ（そのまま貼れる提案スニペット）

> **層の明示**: この台帳は **UI/GameSession 層に置き、GameCore（GameState/WeekRunner）には入れない**。GameSession には既に「RNG非消費の純getter」の前例がある（`previewState`／`previewGains`＝乱数を触らず golden 不変）。台帳もこの流儀に載せ、`state` を読むだけ・`rng` を一切触らない。GameState（Codable）にフィールドを足すと CodableTests/golden の比較面に乗るため**足さない**。

**A. 台帳エントリ（状態と抽象波形のみ・ボケ本文/既存作品セリフは一切載せない）**

```
// GameConfig【仮】— 頻度で解く（規律B-5）。simの gap ヒストグラムで詰める
minReappearGap   = 6【仮】   // これ未満の再登場は「しつこい」でブロック（§7項99を週換算）
maxReappearGap   = 16【仮】  // これ超で「忘れ帯」。発火抑止ではなく、前倒し/差し替えの“観測トリガ”に使う
maxStages        = 3【仮】   // Rule of Three。3段で封印。※口癖ごとに上限を上書き可（例: 腹減った=2）
stageAmp = [0.0, 0.6, 1.0]【仮】 // 1段=効かない/2段=中/3段=最大。“演出強度（間・文字強調）”係数。笑い波形には結線しない

GagLedgerEntry {
  gagID:              String   // 例 "taniguchi_harahetta" / "callback_amayadori"
  lastAppearedSlot:   Int?     // 最終登場を「週×前後スロット」で（UI側の単調カウンタ＝週×2＋前後0/1。GameCoreに該当概念は無い）
  timesUsed:          Int      // 通算段数（3段管理の現在値）
  maxStagesOverride:  Int?     // nilなら共通 maxStages。口癖の個別上限（腹減った=2 など§6優先）
  lastContextVariant: String   // 直前の文脈(場所/相手/温度)。同一variantの連続を禁止
  isForeshadow:       Bool     // 伏線として張ったか＝回収義務を負う
  payoffScheduledSlot:Int?     // nil＝未計画。張る前に弾く（未回収を機構的に禁止）
  isPayoffDone:       Bool
  section:            Fixed | Random // 回収=Fixed（確定発火）・味付け=Random（差込）
  unlockedBy:         String?  // 先行接触フラグID（コンボ解放。人物帳はこれで漏れ防止）
}

// 差込可否の一括判定（＝乱用検知の本体）。全て state 読み取りのみ・RNG非消費
canPlay(g, nowSlot) =
     (g.lastAppearedSlot == nil || nowSlot - g.lastAppearedSlot >= minReappearGap)     // 近すぎ禁止
  && (g.timesUsed < (g.maxStagesOverride ?? maxStages))                                 // 段数封印（口癖別上限を優先）
  && (variantOf(nowSlot) != g.lastContextVariant)                                       // 素リピ禁止
  && (!g.isForeshadow || g.payoffScheduledSlot != nil)                                 // 張り禁止条件
// maxReappearGap は canPlay では使わない（枯れ帯の“警告”専用）。前倒し/差し替えの判断材料に回す
```

**B. 人物帳4件を「固定枠＋接触フラグ解放」で持つ（`batch3 §2` を機構化・確率差込を廃止）**

```
// (gagID, unlockedBy=接触フラグ, section, payoffScheduledSlot【仮】, 技法タグ, MVP可否)
("callback_kumai",     "met_kumai_K1",    Fixed, 決勝週スロット,     過小申告,   MVP候補※決勝到達時のみ)
("callback_amayadori", "met_amayadori_C4",Fixed, 後半同回戦スロット, 温度差実況, MVP要検証※前倒し可否をsim判定)
("callback_fuse",      "met_fuse_ev1",    Fixed, 優勝翌週スロット,   過小申告,   本編専用※下記【設計上の懸念】)
("callback_orion",     "met_orion_C13",   Fixed, 引退間際スロット,   擬人化/静けさ, 本編専用※10年終盤のみ)
// 接触フラグが立った人物帳だけが回収枠を持つ＝発火漏れゼロ。未接触なら枠を作らない
//
// 【設計上の懸念・MVPでの不発】WeekRunner は優勝＝即 yearDone（週末処理を走らせずその年を閉じる）。
//   ゆえに「優勝翌週」は1年MVPに“存在しない週”＝callback_fuse は MVPでは構造的に発火不能（本編で翌年初週に回す）。
//   callback_orion の「引退間際」も10年終盤専用。＝MVPで実際に発火し得るのは熊井（決勝客席）と雨宿り（前倒し要検証）の2件のみ。
//   何件をMVPで保証するかは §9未決2＝オーナー判断待ちに触れる。セッションで確定しない。
```

**C. 声の見本（俺=標準語・計算屋／谷口=関西弁・楽観。口癖は状況を変えて・最大点に最強を置く。本文はボケない）**

```
// gagID="taniguchi_harahetta"：§6の「1年2回まで」を最優先＝maxStagesOverride=2（3段は張らない）
//   段1=効かない下ごしらえ／段2=感情最大点（決勝進出/優勝）。dialogue_design §6の配置ルールに従う

// 段1（平場・variant=稽古終わり・効かない前提。ここは“温めるだけ”）
谷口「腹、減ったな」／俺「まだ昼だぞ。ネタ、あと二回通してからだ」        [温度差実況]

// 段2（最大・variant=決勝の袖＝§6の「感情最大点」に確定配置。§4決勝進出の系列）
谷口「……なあ、腹減ったな」／俺「この期に及んで、通常運転か。……そこは、いい」  [温度差実況(最大点)]

// 台帳が近間隔をブロックした時の心の声（俺のモノローグ・“台帳”という語は出さない＝説明台詞禁止§原則4）
俺「同じ手を、間を置かずにもう一回は寒い。こういうのは、忘れた頃に出すから効く。今日はしまっておこう」  [ズレた冷静さ]

// 回収時に twist を足す（予告どおりに回収しない・意外性の無い回収は減点）
俺「熊井班長が、作業着のまま客席の端にいた。トラックは貸してくれたが、まさか本人まで来るとは」        [過小申告]
```

## リスク・注意

- **【設計上の懸念】乱数消費順**: 段数×振幅を数式（判定・波形）に入れる場合、`runYear/WeekRunner` の消費順と揃えないと golden（3年ビット一致）が壊れる。数式化するなら **止めて相談** のうえ、`tools/*.py` 正典→GameCore→`gen_golden.py` 再生成→`swift test` green を1コミットで揃える（CLAUDE.md §A）。**当面は台帳を表示分岐（好感フラグと同格・数値パラメータにしない）に留め、RNG非消費で入れるのが安全**（`batch3 §2`「表示分岐のみ・数値パラメータにしない」／GameSessionの純getter前例と同じ思想）。
- **【設計上の懸念】セーブ・ロード整合**: 台帳の状態（`timesUsed`／`lastAppearedSlot`）は進行で変わる。GameState（Codable）には入れない（golden/CodableTestsの比較面に乗る）。よって GameSession 側に持つが、MVPが年途中セーブを持つなら**台帳も別途永続化が要る**（さもないとロードで天丼のgap管理がリセット）。MVPが1年使い切り・途中セーブ無しなら不要。実装時に save 有無を確認して分岐する。
- **GameConfig値は全て【仮】**: `minReappearGap=6 / maxReappearGap=16 / maxStages=3 / stageAmp` は根拠未確定。詰め方は `sim_career.py` でシード固定し「同一gagIDの登場スロット列」を全キャリア出力→gap ヒストグラムで**しつこい帯／枯れ帯を目視で刈る**（体感は数値でなく頻度・間隔で先に解く＝規律B-5）。
- **MVP1年版の前倒しは未検証**: 雨宿り(C4)の「3年後」を同年後半に詰めると setup→payoff スパンが短くなり「さりげない仕込み」が効かず伏線が透ける恐れ。**前倒し可否はsim（発火率）＋実機目視で判定**し、回収不能なら `payoffScheduledSlot=nil`＝**張らない**を選ぶ（未回収はノイズ）。ここはオーナー判断待ち（1年版で人物帳を何件保証するか）に触れるので、セッション側で確定しない。
- **台帳に本文を持たせない**: 状態と抽象波形のみ。ボケ本文・既存作品セリフを載せると①（ボケを書かない一線）に抵触。テキストはUI層リソースのまま、台帳は場面ID/gagIDと状態だけを渡す（`dialogue_design §6` と同一分離）。
- **口癖の希釈死**: 「腹減ったな」は1年2回制（§6）を上限として台帳の `maxStages/minReappearGap` と二重化しない——**より厳しい方（§6の2回＝`maxStagesOverride=2`）を優先**。緩めると口癖が死ぬ。声の見本Cも2回制に合わせ、段1/段2のみ（段3は張らない）。

---

## レッドチーム（A/B）

自己検証で見つけた問題と、本文への反映。

**A. 実装妥当性**

1. **「優勝翌週」がMVPに存在しない**（発火不能）: `WeekRunner.resolveAuto` の決勝優勝は即 `yearDone` を返し、その週の週末処理を走らせずに年を閉じる（同ファイル・優勝の即時リターン）。よって `callback_fuse`（布施＝優勝翌週）は1年MVPでは構造的に発火しない。→ 本文B/リスクに【設計上の懸念】を追記し、MVPで発火し得るのは熊井・雨宿りの2件のみと明示。件数保証はオーナー判断（§9未決2）へ差し戻し。
2. **stageAmp の結線先が過大**: 初稿は段数振幅を「笑い波形」に効かせると書いていたが、笑い波形＝ネタの抽象出力であり、会話の口癖天丼を結線すると層が混ざる・判定/RNGに触れて golden を割る。→ 狙い2を「演出強度（間・文字強調）係数」に限定し、波形とは分離と明記。
3. **層とセーブの未記載**: 台帳をどの層に置くか・save/load整合が無かった。→ GameState（Codable）に入れずGameSession層（RNG非消費の純getter前例に倣う）に置く旨と、途中セーブ時の別途永続化の注意を追記。
4. **maxReappearGap がロジック上デッドだった**: `canPlay` で未使用のまま「未回収リスク帯」と説明。→ 「枯れ帯の観測トリガ（前倒し/差し替え判断用）」と役割を明記し、canPlayでは使わないと注記。
5. **週×前後スロットはGameCore非実在**: `WeekRunner` は `week: Int` のみで前後スロットの概念を持たない。→ 「UI側の単調カウンタ（週×2＋前後0/1）」と実体を明示し、GameCore依存でないことを注記。
6. **引用ミス**: 初稿は `dialogue_design §10` を参照したが同ファイルに§10は無い（2回制・感情最大点は§6実装メモ／決勝進出の場面は§4）。→ 全て `§6`（必要箇所は§4）へ訂正。

**B. 会話の中身**

7. **口癖の段数が自己矛盾**（内部不整合）: リスク節が「腹減った＝§6の2回優先」と言いながら、声の見本Cは `taniguchi_harahetta` を段2・段3で提示＝3回使用。→ `maxStagesOverride=2` を導入し、見本を段1/段2のみに修正。段2を感情最大点（決勝の袖）に確定配置。
8. **“台帳”という語がメタ/説明台詞**: 初稿モノローグ「台帳がそう言っている」は、俺がシステム名を口にする説明台詞（`dialogue_design §原則4`違反）でサムい。→ 台帳の語を削り、俺＝計算屋が“間”を意識する craft として書き直し（[ズレた冷静さ]）。
9. **技法タグの多重/不一致**（1本1技法違反）: 「三段オチ」「自虐まじりの肯定」等、実際の文と合わないタグや二重タグがあった。→ カタログ（過小申告/誇張/意外な直喩/三段オチ/バソス/ズレた冷静さ/擬人化/温度差実況）の**単一タグ**に付け替え、文と一致させた。
10. **熊井回収がボケ寄りに滑る恐れ**: 初稿「まさか自分まで運ばれて来るとは」は運ぶ屋の地口（ボケ側）に寄りかけ。→ 「まさか本人まで来るとは」に締め、親方の来場を淡々と受ける[過小申告]に。俺の観測に留め、ネタ本体は書かない一線を維持。
11. **口調・トーン点検**: 俺は全て標準語・計算屋、谷口は口癖のみ（関西寄りだが口癖は共通語形で可）で口調ブレ無し。既存作品（火花/べしゃり/M-1実在ネタ）のコピペ・酷似は無し（「腹減ったな」は本作固有の谷口口癖＝天丼の対象そのもので流用可）。各見本はボケなし・架空・【仮】。

（提案のみ。docへ採用時は `docs/START_HERE.md` 索引に1行追加し、`dialogue_batch3_v0.md §9未決2` の解決策として相互参照を張ることを推奨。MVPで保証する回収件数はオーナー判断待ち。）