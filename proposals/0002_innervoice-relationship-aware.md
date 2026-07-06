<!-- 夜間提案 0002 / 研究→起草→レッドチーム(A/B) 完了 / コード改変なし・提案のみ -->
<!-- ※会話の基調はドラマ主軸へ再調整予定（参考作品リサーチ後に一括re-tone）。現状サンプルはウィット寄りが残る。 -->

<!-- 提案 0002 / innerVoice関係認識 / レッドチーム(A/B)実施済み・コード改変なし・提案のみ -->

## 狙い

`DialogueData.innerVoice` は常時表示される「俺の心の声」なのに、読んでいるのは `stamina / money / lossStreak / justPassed / fame / compat(数値)` だけ。谷口との**相性帯**・ライバルの**動静**・**季節**・**キャリア年次**・**誰と組んでいるか(相方ID)** を一切見ていない。一方で `dialogue_design §2` は同じ場面を相性帯4段(0-7/8-14/15-20/21+)で書き分け「関係の変化を見せるのが相性というパラメータの感情的な正体」と定義し、`rival_scripts`・`partner_finals_reactions` は役柄・相方別の声まで作り込んでいる。**その関係の起伏が全部レアイベント側にしか届かず、moment-to-momentの手触り＝心の声は"関係ブラインド"のまま**——これが `fun_flow_review` の言う構造欠陥。

狙いは、**innerVoice を「軸を掛け算した表」から「条件付きルール束(Ruskin式)」に置き換える**こと。これで相性帯・ライバル・季節・年次・相方IDを**入力に足しても在庫が爆発しない**。「最も多くの条件を満たしたルールが勝つ／合う専用行が無ければ条件0本の汎用行へ静かに劣化する」——この一点で、関係を常時表示に流しつつ壊れない。

数値は全て【仮】。固有名は全て架空。

## 対象箇所

- `ManzaiGame/Sources/DialogueData.swift:21` の `innerVoice(state:lossStreak:justPassed:nextMilestone:weakAbility:)` の**入力設計と選択ロジック**（現状は `if` 優先度＋`pick(pool, salt)`。`pick` は**RNGを一切引かないsalt決定的関数**）。
- **呼び出し元は1箇所** `ManzaiGame/Sources/WeekMainView.swift:154`（`monoBox` という SwiftUI の computed View の中。末尾で `.id(a.text)` を張っている）。→ **入力を増やすなら、既存シグネチャに任意引数を足す（後方互換）か、View側で新コンテキストを組み立ててこの1箇所を更新する**。破壊的な引数総取り替えは避ける（他箇所は無いが、Viewが新軸を供給できる形にするだけで足りる）。
- 参照する正典: `dialogue_design_v0.md §2`(相性帯4段=トーン鍵の流用元)・`§6`(場面ID×相性帯×条件フックのテーブル選択・no-repeat)・`§7-2`(**相性21+の会話は相方ガチャ実装後の上位相方でのみ**)／`writing_craft_and_appeal_v0.md`(8技法・基調=過小申告＋温度差実況／**1テキスト=技法1つ**／天丼間隔はGameConfig)／`rival_scripts_v0.md`(貼り紙・ニュース欄で観測する"今週の事実")／`partner_finals_reactions_v0.md §4-3`(相方別声プロファイル・**差し替えは相方行のみ／地の文の三人称ナレーションは中立据え置き**・**未定義相方は八雲版=標準語中立**の作法)。
- 【一線】ボケ(オチ)は書かない。心の声は反応・観測・言い回しのウィットのみ。

## どこから学んだか(技術＋出典URL)

- **Valve / Elan Ruskin「ルールデータベース＋ファジーパターンマッチ」**(L4D/Portal2/Dota2の掛け合いの実装正典)。現在状態の"事実(facts)"を、任意個の判定条件を持つルールへマッチさせ、**最も条件の多い＝最も具体的なルールが勝つ／専用行が無ければ条件の少ない汎用行へ graceful degradation**。総在庫は軸の積でなく「書きたい具体交差の本数」に**線形加算**で増える——これが在庫爆発(N/e問題)への直接の答え。GDC2012 "AI-driven Dynamic Dialog through Fuzzy Pattern Matching" https://gdcvault.com/play/1015528/AI-driven-Dynamic-Dialog-through ／スライドPDF https://cdn.cloudflare.steamstatic.com/apps/valve/2012/GDC2012_Ruskin_Elan_DynamicDialog.pdf ／解説 https://www.blog.radiator.debacle.us/2012/07/rule-databases-for-contextual-narrative.html （※gdcvault/radiatorはプロキシCONNECTポリシーで403。周知内容＋一次スライドで構成）
- **Left 4 Dead の状態入力**は "health / stress / これまで見た特殊感染者の種類(履歴)"。moment-to-momentの体感を状態で駆動し、組み合わせ生成でメモリを増やさず10倍のバリエーション。→ 本作の「今週、貼り紙でライバルの通過/敗退を観測した」という**1個の事実**を心の声のフックにする発想の元。L4D2開発者コメンタリ https://left4dead.fandom.com/wiki/Developer_Commentary_(Left_4_Dead_2)
- **Disco Elysium** — 内声は状態と関係で発話が変わる"エージェント"。元婚約者に触れる行だけボイスディレクションを「より優しく」微調整＝**同一の内声機構が"誰について語るか"でトーンだけ変わる**(新機構ゼロで関係ブラインドを解く前例)。https://reelmind.ai/blog/disco-elysium-script-narrative-game-design
- **Setup→(subtle)reminder→Payoff / Rule of Three** — 中間のリマインドが効き目を作る／3回目で裏切る。相性帯・年次は「同じモチーフを時を変えて再登場させる」天丼装置に最適。https://nofilmschool.com/plant-and-payoff-in-screenwriting ／ https://nofilmschool.com/rule-of-the-three
- **「全ての笑いは内輪だ」／サムさの発生源** — 関係を見せると観客を輪に入れて笑いが立つが、「相性15なので〜」的な説明台詞化は最悪のサムさ。関係は**数値でなく観測の差分**で出す(`dialogue_design §1`「UIが言うことを人間に言わせない」と一致)。https://note.com/shihomo/n/n6f06d0fd6608

## 実装イメージ（設計擬似コード ※helperは新規実装が要る）

> **注意（レッドチームA反映）**: 下記は「そのまま貼れば動く」完成コードではない。`matches` / `specificity` / `decideScene` / `pool(for:)` / `saltFor` / no-repeat判定は**これから書くhelper**で、既存APIには存在しない。ここで示すのは**設計の形**。

**方針**: 現行の `if` 優先度＋`pick` を土台として残し、その上に「条件付きルール」を疎に載せる。**各stateに条件0本の汎用行を必ず1本用意**しておけば、どの新軸を足しても未カバー時に必ず着地する＝壊れない・在庫爆発しない。

### (0) 【最重要・A軸】選択は決定的に保つ — innerVoiceはView body内で毎フレーム呼ばれる

`innerVoice` は `WeekMainView.swift:154` の computed View（`monoBox`）内で、SwiftUIの再評価のたびに呼ばれ、結果を末尾で `.id(a.text)` に食わせている。現行 `pick` が **saltで決定的**だからこそテキストが安定し、遷移も暴発しない。**ここに実RNG（`randomElement()` の類）を入れると、再描画のたびに文が入れ替わり、`.id` 差替で無用なトランジションが毎回走る**。よって新選択も**既存状態から導いたsaltで決定的に引く**こと（下記 `deterministicPick`）。**新しい乱数源は足さない**（後述リスク§と一致）。

### (1) 事実(facts)の器 — 掛け算の軸ではなく"条件タグ"の供給源

```swift
// 追加案。既存の確定済み状態から詰めるだけ（RNG非消費・golden非干渉／表示分岐のみ）。
enum CompatBand { case 他人行儀, 噛み合い, ツーカー, 阿吽 }   // §2の0-7/8-14/15-20/21+
enum Season      { case 春, 夏, 秋, 年末GP }                 // 週番号→季節の写像で導く
enum RivalBeat   { case none, ライバル通過, ライバル敗退 }      // 今週の貼り紙で観測した"事実"1個

struct VoiceCtx {
    // 既存入力（そのまま）
    let state: GameState; let lossStreak: Int; let justPassed: Bool
    let nextMilestone: (name: String, weeksLeft: Int)?; let weakAbility: String
    // 追加する"条件フック"（軸ではなく、当てはまれば効く任意タグ）
    let band: CompatBand           // §2流用（compat数値→帯へ純変換。MVPで実働する唯一の追加軸）
    let rival: RivalBeat           // 既定 .none（貼り紙観測の配線＝post-MVP）
    let season: Season             // 週番号から導出（post-MVP）
    let careerYear: Int            // MVPは常に1（GameSession.year は 1 固定）＝多年はpost-MVP
    let partnerId: String          // 既定 "谷口"。ガチャ未実装のMVPでは常に谷口
}
```

> **【MVPで実働するのはband（compat由来）だけ】**（A軸）。`rival`（貼り紙観測の配線が未実装）・`season`（週→季節写像が未定義）・`careerYear`（`GameSession.year` は 1 固定）・`partnerId`（ガチャ未実装＝常に谷口）は**MVPでは全てinert**。これは欠陥ではなく実装順の問題。ゆえに**まずband軸のルールだけを載せて実機で検証**し、他軸は後追いする（実装順は末尾）。

### (2) ルール1件の形（＝dialogue_design §6 の「場面ID×状態/相性帯×条件フック×技法タグ×本文」に対応）

```swift
struct VoiceRule {
    let scene: String              // "losing" / "heijo" / "passed" など（既存プールに対応するキー）
    let craft: String              // 技法タグ＝writing_craftの8技法から【必ず1つだけ】
    let text: String
    // 条件フック（nilなら無条件＝この軸は不問）。満たした条件数=specificity。
    let band: CompatBand?; let rival: RivalBeat?
    let season: Season?
    let years: ClosedRange<Int>?   // ★A軸修正: minYearでは「1年目だけ」を表現できない
                                   //   (minYear:1 は year>=1 で全年ヒット)。上下限を持つ範囲にする。
    let partnerId: String?
}
```

> **【A軸修正・schemaのバグ】** 下書きは `minYear: Int?` だったが、`minYear:1` は「year≥1」＝**全年ヒット**で「1年目だけ」を表現できない（両端を狙う設計なのに下端が作れない）。**上下限を持つ `years: ClosedRange<Int>?`** に変更（1年目=`1...1`、9年目以降=`9...10`）。

### (3) 選択規則 — 最も具体的なルールが勝つ／無ければ既存 pick にfallback

```swift
static func innerVoice(ctx: VoiceCtx) -> Advice {
    // 既存の絶対優先（体力・金欠）は据え置き＝生活の緊急事態は関係より前に出す
    if ctx.state.stamina < 25 { return Advice(name:"俺", text: pick(lowStamina, salt: Int(ctx.state.stamina))) }
    if ctx.state.money < 30_000 { return Advice(name:"俺", text: pick(lowMoney, salt: ctx.state.money)) }

    let scene = decideScene(ctx)   // "losing"/"passed"/"milestone"/"heijo" を既存優先度で決める
    let hits  = rules.filter { $0.scene == scene && matches($0, ctx) }   // 全条件がctxに一致
    if let best = hits.max(by: { specificity($0) < specificity($1) }) {  // 最も条件が多い＝具体的
        let top   = hits.filter { specificity($0) == specificity(best) }
        // no-repeat: 審査員コメントと"同じ仕組み"だが、履歴ストアはUI側に持つ（★A軸: golden側RNGを共有しない）
        let fresh = top.filter { !recentlyUsedUI($0) }
        let cand  = fresh.isEmpty ? top : fresh
        // ★A軸: 実RNGではなく既存状態由来のsaltで決定的に引く（View body内で安定させる）
        return Advice(name:"俺", text: deterministicPick(cand, salt: saltFor(scene, ctx)).text)
    }
    // 条件付き行が無い場面は、現行の汎用プールへそのまま静かに劣化（既存挙動を保存）
    return Advice(name:"俺", text: pick(pool(for: scene), salt: saltFor(scene, ctx)))
}
// matches: 各フックが nil か、ctx と一致するかを AND（years は range.contains(ctx.careerYear)）。
// specificity: 非nilフックの本数。deterministicPick: pick と同じ salt%count の決定的選択。
```

### (4) 疎に載せる"関係の起伏"ルール群（両端・節目・ライバルビートだけ）— 追加は数十本オーダー

> **【A軸修正・compatCap=20で阿吽(21+)は谷口では出ない】**。`GameConfig.compatCap = 20.0`。谷口の相性は**20で頭打ち**なので `band:.阿吽`(21+) は**谷口には永遠に発火しない**。`dialogue_design §7-2` も「21+の会話は相方ガチャ実装後の上位相方でのみ」と明言。よって谷口の「両端」は **他人行儀(0-7) と ツーカー(15-20)**、`阿吽(21+)` は**上位ガチャ相方＝post-MVP**へ回す。

```swift
static let rules: [VoiceRule] = [

  // ─ 連敗×相性帯の両端（0-7 と、谷口の上限帯15-20）。同じ「谷口の沈黙」を"意味"で反転して回収 ─
  //   ※技法タグはそれぞれ1つ。反転は"内容の関係"であって複合技法ではない。
  VoiceRule(scene:"losing", craft:"過小申告", text:
    "谷口は何も言わない。まだ、こういう夜の言葉を持ち合わせていない距離だ。",
    band:.他人行儀, rival:nil, season:nil, years:nil, partnerId:"谷口"),
  VoiceRule(scene:"losing", craft:"擬人化", text:
    "谷口は今日も何も言わない。……その沈黙が、今は救いの側に立っている。",
    band:.ツーカー, rival:nil, season:nil, years:nil, partnerId:"谷口"),

  // ─ 連敗×ライバル観測（貼り紙で相手が上の回戦へ）。関係を"数値でなく紙の高さの差"で（rival配線=post-MVP）─
  VoiceRule(scene:"losing", craft:"過小申告", text:
    "あいつらの名前は、また一つ上の紙にあった。……こっちの紙は、まだこの高さだ。",
    band:nil, rival:.ライバル通過, season:nil, years:nil, partnerId:nil),

  // ─ 平常×キャリア年次の両端（1年目 と 9年目以降）。中間年は汎用へ劣化（多年=post-MVP・MVPでは不発）─
  VoiceRule(scene:"heijo", craft:"自虐", text:
    "一年目は、何もかもが初めてで、初めてだと気づく余裕さえなかった。",
    band:nil, rival:nil, season:nil, years:1...1, partnerId:nil),
  VoiceRule(scene:"heijo", craft:"過小申告", text:
    "『あと少し』を数えるのはやめた。数えると、動けなくなる年数になった。",
    band:nil, rival:nil, season:nil, years:9...10, partnerId:nil),

  // ─ 季節は年末GP前後だけタグ（春夏秋は汎用）。擬人化は低頻度アクセント（season配線=post-MVP）─
  VoiceRule(scene:"heijo", craft:"擬人化", text:
    "街が、やたら年末の顔をしている。……この時期の稽古場だけ、少し息が白い。",
    band:nil, rival:nil, season:.年末GP, years:nil, partnerId:nil),

  // ─ setup&payoff：去年の自分への微リマインドを常時表示のまま（"相性が上がった"とは言わない）─
  //   ※§4の「二駅」モチーフは希少な決勝敗退ビート専用なので、ここでは別の具体に振り衝突回避。
  VoiceRule(scene:"heijo", craft:"過小申告", text:
    "去年のこの時期は、稽古のあと口をきかずに別れていた。今年は、別れ際にひとことだけ増えた。",
    band:.ツーカー, rival:nil, season:nil, years:2...10, partnerId:"谷口"),
]
```

### (5) 相方IDの波及 — "俺の文体は不変、観測される相方だけ差し替わる"

`reaction("rest_相方と過ごす")` のような**相方に言及する少数場面だけ** `partnerId` で差し替える。`partner_finals_reactions §4-3` の作法どおり、**地の文(俺の一人称ナレーション)は中立据え置き**、差し替えるのは"観測される相方の癖"1個だけ。谷口の口調で俺の内声を書き換えてはいけない。

> **【A軸・配線の注記】** `reaction(variantID:)` は現状 `innerVoice` の `rules[]` とは**別の String テーブル**（`scene` を持たない）。相方IDをここへ入れるなら、**reaction()側に相方キー付きの並行テーブルを足す**か、rest系の場面を `rules[]` へ畳み込むかの二択で、rules[]機構に自動では乗らない（未解決§に記載）。

> **【B軸・既存正典との重複を回避して書き直し】** 下書きの§5例文（「壁の向こうで、まだネタを回す声がする／あいつも、まだ起きている」等）は `dialogue_design §4 大会前夜`(壁の向こうから谷口がネタを回す声…あいつも起きてる)・`§3 休む`(ネタの話を一度もしなかった)・キャラ定義(スベった夜は寝ない)の**希少レア行のほぼ複製**で、moment-to-momentに転用すると**その山場ビートを共食い**する。下記に全面差し替え。

```swift
// dialogue_design §6 表記に対応した「1行」（場面ID, 相性帯, 条件フック, 技法タグ【1つ】, 本文）:
// (rest_相方と過ごす, 相性15-20, partnerId=谷口,     過小申告,   「谷口は珍しくネタ帳を持ってこなかった。手ぶらのあいつは、なんだか少しだけ大きく見える。」)
// (rest_相方と過ごす, 相性15-20, partnerId=早乙女,   過小申告,   「早乙女の『もう一回だけ』が、さっきから五回目を数えた。……止める言葉を、俺はまだ持っていない。」) ※post-MVP(ガチャ)
// (rest_相方と過ごす, 相性15-20, partnerId=(未定義), 過小申告,   「相方はまだ起きている気配がする。詮索はしない。起きている理由は、たぶんこっちと同じだ。」) ※八雲版=標準語中立へ
```

俺の心の声＝標準語モノローグは全て不変。差し替わるのは「観測対象の相方の事実」1個だけ。早乙女は口癖「もう一回」を**観測**で効かせる（谷口の「プロとして寝る」等の他相方モチーフは借りない）。未定義相方は谷口版(関西弁)ではなく**八雲版=標準語中立**へ落とす(`partner_finals_reactions §4-3` の既定と一致)。

### 天丼(谷口「腹減ったな」)の共有カウンタ

心の声が谷口の口癖を"観測"して載せる場合も、レアイベント側と**同一の GameConfig 共有カウンタ**を参照する(登場は1年2回まで／3回目=感情最大点)。心の声が勝手に消費すると、決勝進出の山場で口癖が枯れる。**なお本改稿の(5)の例文は口癖「腹減ったな」を一切消費していない**（谷口=ネタ帳の観測に振った）ので、当面カウンタ干渉はしない。

## リスク・注意

- **サムさ(最大の禁物)**: 関係を**数値でなく観測の差分**で出す。「相性が上がった」は禁止、「口をきかずに別れていた→ひとことだけ増えた」はOK。**1内声=技法1つ**(`writing_craft §92`)を厳守し、相性帯・季節・年次・相方を**同時に全部載せない**。ルールの条件(フック)は増やしてよいが、出力テキストは薄く・技法タグは1つに保つ。
- **在庫爆発の再発**: `state × band × season × year × partner` の全セル執筆は万オーダーで破綻。**両端・節目・特定ライバルビートという疎な点にだけルールを置き**、中間は graceful degradation で汎用が埋める。目安は全軸合わせて追加数十本【仮】。**条件0本の汎用行を各sceneに必ず維持**（これが壊れない土台）。
- **正典同期(CLAUDE.md §A)**: `innerVoice` は**UI表示層**で、`WeekRunner`/`runYear` の週処理ループには乗らない＝**golden（3年ビット一致）の経路に構造的に入らない**。`compat数値→band` は**既存状態への純算術**でRNGを引かないので、これ単体では**goldenを壊しようがない**。**危険なのは唯一**、`rival`/`season`/`careerYear` を供給するために **GameCore側で新規に乱数を引く／状態読み出し順を変える**場合だけ。その時は**手を止めてオーナー相談**（消費順がgoldenを壊す）。ctxは**既存の確定済み状態を読むだけ**に留め、no-repeat履歴も**UI側の別ストア**にして審査員側のRNG履歴を共有しない。
- **決定性(A軸・再掲)**: `innerVoice` はView body内で毎再描画呼ばれ `.id(a.text)` に食う。**選択は必ず決定的**（実RNG禁止・既存状態由来のsaltで引く）。さもないと文が毎フレーム入れ替わり遷移が暴発する。
- **相方IDの越権**: 相方の口調で俺の内声を書き換えると人格が壊れる。差し替えは"観測される相方の事実"に限定し、地の文の俺ナレーションは中立。未定義相方は八雲版フォールバック。
- **MVPの扱い**: 現状の関係ブラインドは"未実装なだけ"であって設計欠陥ではない。本書は**提案**。実装順は ①各sceneの汎用fallback完備 → ②**連敗×相性帯の両端2本（他人行儀0-7／ツーカー15-20＝MVPで実働する唯一軸・効果最大コスト最小）** → ③連敗×ライバルビート1個(貼り紙配線と同時) → ④季節/年次/相方IDを節目・両端の疎な点に**post-MVPで**後追い。各段階を `swift test` green のまま、simで送って**タップして可笑しいか**を目視(`§7-B`・§10)で確認してから次へ。

## レッドチーム（A/B）

### A. 実装妥当性
- **[修正] 選択の非決定性で文が毎描画入れ替わる**: 下書きの `randomElementWeighted()` は実RNG。`innerVoice` は `WeekMainView.swift:154` の computed View 内で毎再評価され `.id(a.text)` を張るため、非決定的だと**再描画ごとに文が変わりトランジション暴発**。→ 既存 `pick` 同様、**状態由来のsaltで決定的に引く** `deterministicPick` に置換（§(0)(3)）。新RNG源も足さない。
- **[修正] `阿吽(21+)` は谷口では永久に不発**: `GameConfig.compatCap = 20.0`。下書きの `band:.阿吽, partnerId:"谷口"` は上限20を超えるので**発火不能**。`dialogue_design §7-2`(21+はガチャ上位相方のみ)とも矛盾。→ 谷口の上端を **ツーカー(15-20)** に変更、`阿吽` は post-MVP の上位相方へ予約（§(4)）。
- **[修正] `minYear:1` では「1年目だけ」を表現できない**: `minYear:1` は year≥1＝全年ヒットで、両端狙いの下端が作れないschemaバグ。→ `years: ClosedRange<Int>?`（`1...1` / `9...10`）に変更（§(2)）。
- **[修正] golden干渉の記述が過剰にアラート的**: innerVoiceはUI層でWeekRunner/goldenの経路に入らず、band変換はRNG非消費の純算術＝**単体ではgolden不変**。危険は「新軸供給のためGameCore側で新規乱数を引く」時だけ。→ "止めて相談"の発火条件をそこに限定して明記（リスク§）。
- **[修正] no-repeat履歴の帰属**: 「審査員コメント機構を共用」は、審査員側のRNG履歴（golden相関）を触ると危険。→ **仕組みは同型・ストアはUI側**に分離（§(3)）。
- **[注記] "そのまま貼れる"は過大申告**: `matches`/`specificity`/`decideScene`/`pool`/`saltFor`/no-repeat は**未実装helper**。→ 見出しを「設計擬似コード」に改め、helperは新規実装が要ると明示。
- **[注記] 呼び出し口とシグネチャ**: 実呼び出しは `WeekMainView.swift:154` の1箇所のみ。→ 破壊的な引数総取替を避け、**任意引数の追加 or View側でctx組み立て**を推奨（対象箇所§）。
- **[注記] §5はrules[]に自動で乗らない**: `reaction(variantID:)` は `scene` を持たない別テーブル。相方IDは並行テーブル追加かrest場面のrules[]畳み込みが要る（未解決§）。
- **[注記] MVP inert軸**: rival/season/careerYear(=1固定)/partnerId(=谷口固定)はMVPで不発。未実装を欠陥視せず、band軸のみ先行検証（§(1)注記・実装順）。

### B. 会話の中身
- **[修正] 1テキスト＝技法1つ違反**: 下書きは「過小申告＋温度反転」「過小申告＋温度差実況」「温度差実況(時間差)」等の**複合タグ**＋**非正典タグ「温度反転」**を付け、`writing_craft §92`(1テキスト1技法)に反していた。→ 全行を**8技法から1つだけ**に再タグ（過小申告／擬人化／自虐 等）。「反転」は技法でなく"内容の関係"と注記。
- **[修正] 既存正典レア行の共食い（§5）**: 「壁の向こうで…ネタを回す声」は `dialogue_design §4 大会前夜`、「あいつも、まだ起きている」も §4、「ネタの話を一度もしなかった」は §3、「スベった夜は寝ない」はキャラ定義——いずれも希少ビートの複製で、常時表示に流すと山場を薄める。→ §5の谷口/早乙女/未定義の3行を**全面書き直し**（谷口=ネタ帳を持ってこない観測／早乙女=口癖「もう一回」を観測／未定義=中立の気配）。
- **[修正] setup&payoffの「二駅」衝突**: 下書きの「去年は二駅／今年は一駅」は `dialogue_design §4` の決勝敗退専用モチーフ「黙って二駅」の流用で、希少ビートを希釈。→ 別の具体(「口をきかずに別れる→ひとことだけ増えた」)に差し替え、駅モチーフは §4 に温存。
- **[修正] 早乙女に谷口モチーフ混入**: 下書きの「プロとして寝ろ」は谷口の §3「プロとして寝る」の借用。→ 早乙女固有の口癖「もう一回」を観測する行に置換（相方の声帰属を守る）。
- **[確認OK] 口調ブレ無し**: 全サンプルは**俺の標準語モノローグ**で、谷口の関西弁台詞を直接引かない（"観測"に徹する）＝俺=標準語／谷口=関西弁の分離を保持。
- **[確認OK] ノーボケ・架空・非コピペ**: 各行はオチ/ネタ本文を書かず反応・観測のみ。固有名は架空、数値は【仮】。既存作品(火花/べしゃり/M-1実ネタ)の想起・酷似は無し。サムい/キザな盛りも回避（過小申告基調）。
- **[残注意] 天丼カウンタ**: 谷口口癖の観測を将来足す場合は GameConfig 共有カウンタを必ず参照（本改稿は口癖未消費）。