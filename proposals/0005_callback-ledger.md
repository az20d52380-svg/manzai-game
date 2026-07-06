<!-- 夜間提案 0005 / 研究→起草 完了・レッドチーム中断 / コード改変なし・提案のみ -->

> ⚠️ **レッドチーム未実施（下書き段階）**。夜間セッションが上限に達し、検証工程A(実装妥当性)/B(会話の中身)が中断しました。
> 研究→起草までは完了。朝の判断材料として保存。採用検討時は、既存作品コピペ有無・口調ブレ・実装の分岐破綻を最終確認してください。

# 天丼・伏線回収の中央管理機構 v0 — CallbackLedger 提案（2026-07-05）

対象: manzai-game（漫才コンビ育成SLG・iOS/SwiftUI・本編10年・週送り・数値は全て【仮】）。位置づけ: `writing_craft_and_appeal_v0.md §7`（同一ギャグ最短再登場間隔=GameConfig【仮】）・`dialogue_design_v0.md §6/§10`（「腹減ったな」1年2回制）・`dialogue_batch3_v0.md §2`（人物帳＝熊井/布施/雨宿り/オリオン）・同 `§9未決2`（MVP1年版で回収がほぼ発火しない自認）を**束ねる1枚**。これは提案であり、既存ファイルは編集しない。正典順序（`tools/*.py`→GameCore→golden再生成）は崩さない。

---

## 狙い

天丼と伏線回収の設計が各docに散らばり、**台帳（誰の・どの語を・いつ・何回目か）が無いため間隔保証も乱用検知も効かない**。この機構で3つを一括で成立させる。

1. **乱用検知**: 最短再登場間隔違反・段数超過・同一variant連続を単一データ構造が弾く（＝`writing_craft §7`「口癖天丼は状況を変えて回す」の機構的実装）。
2. **段数管理**: 「1回目は効かない／3回目が最大」（Rule of Three）を状態として持ち、笑い波形の**振幅係数にだけ**効かせる（ボケ本文は書かない）。
3. **回収保証**: 伏線を張るときに回収予定週を必須化し、1年内に回収できないものは**機構的に張らせない/前倒す**。`§9未決2` の「回収が発火しない」を、確率差込から**固定セクション枠＋接触フラグ解放（コンボ型）**へ寄せて潰す。

## 対象箇所

- `writing_craft_and_appeal_v0.md §7`（項99・118）: `minReappearGap`【仮】の実体化。
- `dialogue_design_v0.md §6/§10`: 「腹減ったな」1年2回制・希釈禁止・直近使用ID回避の仕組みを台帳へ統合（審査員コメントの直近回避と同一機構を共用）。
- `dialogue_batch3_v0.md §2`: 人物帳4件の初出→再登場→最終回収を「固定枠＋接触フラグ」で保証。
- `dialogue_batch3_v0.md §9未決2`: MVP1年版の回収前倒し可否をこの台帳の `payoffScheduledWeek` で判定。

## どこから学んだか（技術＋出典URL）

- **3段エスカレーション（1回目は笑いなし→3回目が最大）／「1場面1〜2回」が乱用境界**: https://www.choge-blog.com/japanese/tendon/ , https://owa-rai.com/tendon/ , https://e-kae-library.com/tendon/
- **時間差天丼＝忘却が効く最適間隔帯（短すぎしつこい・長すぎ気づかれない）／状況(variant)を変えると延命**: https://detail.chiebukuro.yahoo.co.jp/qa/question_detail/q1015229150 , https://note.com/dreamy_peony4904/n/n9b06f27aa9f4
- **Rule of Three＝2つでパターン→3つ目で裏切り／SAP(Setup-Anticipation-Punchline)**: https://en.wikipedia.org/wiki/Rule_of_three_(writing) , https://punchlinecopy.com/funnier-copy-rule-of-3/ , https://nofilmschool.com/rule-of-the-three
- **「回収されて初めて伏線」＝未回収はノイズ／回収は意外性(twist)を1つ足す**: https://strobofactory.net/blogs/film/the-perfect-balance-of-foreshadowing-and-payoff-scene-composition-techniques-learned-from-masterpieces , https://note.com/shinypinkchina/n/nb2e8f5c9128a
- **仕込みはさりげなく（回収まで普通の会話に溶かす）**: https://note.com/ponk77/n/nc4624c0e8664 , https://www.kazz-spot.com/gekisaku/3-4/
- **回収は後半に密度を寄せる／setup×payoffの相乗**: https://data-everyday.com/stat_ml/post-3093/ , https://note.com/bunri_106/n/n0a30a05d5b72
- **固定セクション枠と乱数枠の分離／週×前後スロット／接触フラグ→後続解放のコンボ型（回収の確実性）**: https://xn--odkm0eg.gamewith.jp/article/show/46318 , https://game8.jp/pawapuro2026-2027/791406 , https://shinumae.oops.jp/wordpress/scp-p2022/

## 実装イメージ（そのまま貼れる提案スニペット）

**A. 台帳エントリ（状態と抽象波形のみ・ボケ本文/既存作品セリフは一切載せない）**

```
// GameConfig【仮】— 頻度で解く（規律B-5）。simの gap ヒストグラムで詰める
minReappearGap   = 6【仮】   // これ未満の再登場は「しつこい」でブロック（§7項99を週換算）
maxReappearGap   = 16【仮】  // これ超で「忘れられ意外性消失＝未回収リスク」帯へ
maxStages        = 3【仮】   // Rule of Three。3段で封印（4段目以降は振幅が落ちる前に止める）
stageAmp = [0.0, 0.6, 1.0]【仮】 // 1段=効かない/2段=中/3段=最大。笑い波形の振幅係数にだけ効かせる

GagLedgerEntry {
  gagID:              String   // 例 "taniguchi_harahetta" / "callback_amayadori"
  lastAppearedSlot:   Int?     // 最終登場を「週×前後スロット」で（週×2＋前後0/1）
  timesUsed:          Int      // 通算段数（3段管理の現在値）
  lastContextVariant: String   // 直前の文脈(場所/相手/温度)。同一variantの連続を禁止
  isForeshadow:       Bool     // 伏線として張ったか＝回収義務を負う
  payoffScheduledSlot:Int?     // nil＝未計画。張る前に弾く（未回収を機構的に禁止）
  isPayoffDone:       Bool
  section:            Fixed | Random // 回収=Fixed（確定発火）・味付け=Random（差込）
  unlockedBy:         String?  // 先行接触フラグID（コンボ解放。人物帳はこれで漏れ防止）
}

// 差込可否の一括判定（＝乱用検知の本体）
canPlay(g, nowSlot) =
     (g.lastAppearedSlot == nil || nowSlot - g.lastAppearedSlot >= minReappearGap)  // 近すぎ禁止
  && (g.timesUsed < maxStages)                                                       // 3段で封印
  && (variantOf(nowSlot) != g.lastContextVariant)                                    // 素リピ禁止
  && (!g.isForeshadow || g.payoffScheduledSlot != nil)                              // 張り禁止条件
```

**B. 人物帳4件を「固定枠＋接触フラグ解放」で持つ（`batch3 §2` を機構化・確率差込を廃止）**

```
// (gagID, unlockedBy=接触フラグ, section, payoffScheduledSlot【仮・1年内前倒し版】, 技法タグ)
("callback_kumai",     "met_kumai_K1",   Fixed, 決勝週スロット,   三段オチ/温度差)
("callback_fuse",      "met_fuse_ev1",   Fixed, 優勝翌週スロット, 過小申告)
("callback_amayadori", "met_amayadori_C4", Fixed, 後半同回戦スロット, 温度差実況)  // 10年版の3年後→1年版は同年後半へ前倒し可否をsimで判定
("callback_orion",     "met_orion_C13",  Fixed, 最終盤スロット,   擬人化/静けさ)
// 接触フラグが立った人物帳だけが回収枠を持つ＝発火漏れゼロ。未接触なら枠を作らない
```

**C. 声の見本（俺=標準語・計算屋／谷口=関西弁・楽観。口癖は状況を変えて・3回目が最大。本文はボケない）**

```
// gagID="taniguchi_harahetta" 段数=2（中・variant=移動中）
谷口「腹、減ったな」／俺「移動中に言うのは減点だ。ネタ合わせの途中だぞ」   [過小申告/温度差実況]

// 同 gagID 段数=3（最大・variant=決勝の袖＝§10の感情最大点に確定配置）
谷口「……なあ、腹減ったな」／俺「この期に及んで、通常運転か。……そこは、いい」  [三段オチ/自虐まじりの肯定]

// 台帳が近間隔をブロックした時の心の声（俺のモノローグ・乱用検知の可視化）
俺「同じ手をもう一回は、たぶん寒い。忘れた頃まで温めておく——台帳がそう言っている」  [ズレた冷静さ/擬人化(低頻度)]

// 回収時に twist を足す（予告どおりに回収しない・§B「意外性が無い回収は減点」）
俺「熊井班長が、作業着で客席にいた。トラックは貸してくれたが、まさか自分まで運ばれて来るとは」  [誇張/温度差実況]
```

## リスク・注意

- **【設計上の懸念】乱数消費順**: 段数×振幅を笑い波形に入れる場合、`runYear/WeekRunner` の消費順と揃えないと golden（3年ビット一致）が壊れる。数式化するなら `tools/*.py` 正典→GameCore→`gen_golden.py` 再生成→`swift test` green を1コミットで揃える（CLAUDE.md §A）。**当面は台帳を表示分岐（好感フラグと同格・数値パラメータにしない）に留め、RNG非消費で入れるのが安全**（`ui_redesign §正直getter` の思想と同じ）。
- **GameConfig値は全て【仮】**: `minReappearGap=6 / maxReappearGap=16 / maxStages=3 / stageAmp` は根拠未確定。詰め方は `sim_career.py` でシード固定し「同一gagIDの登場スロット列」を全キャリア出力→gap ヒストグラムで**しつこい帯／枯れ帯を目視で刈る**（体感は数値でなく頻度・間隔で先に解く＝規律B-5）。
- **MVP1年版の前倒しは未検証**: 雨宿り(C4)の「3年後」を同年後半に詰めると setup→payoff スパンが短くなり「さりげない仕込み」が効かず伏線が透ける恐れ。**前倒し可否はsim（発火率）＋実機目視で判定**し、回収不能なら `payoffScheduledSlot=nil`＝**張らない**を選ぶ（未回収はノイズ）。ここはオーナー判断待ち（1年版で人物帳を何件保証するか）に触れるので、セッション側で確定しない。
- **台帳に本文を持たせない**: 状態と抽象波形のみ。ボケ本文・既存作品セリフを載せると①（ボケを書かない一線）に抵触。テキストはUI層リソースのまま、台帳は場面ID/gagIDと状態だけを渡す（`dialogue_design §6` と同一分離）。
- **口癖の希釈死**: 「腹減ったな」は1年2回制（§10）を上限として台帳の `maxStages/minReappearGap` と二重化しない——**より厳しい方（§10の2回）を優先**。緩めると口癖が死ぬ。

---
（提案のみ。docへ採用時は `docs/START_HERE.md` 索引に1行追加し、`dialogue_batch3_v0.md §9未決2` の解決策として相互参照を張ることを推奨。）