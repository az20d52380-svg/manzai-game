<!-- 夜間提案 0002 / 研究→起草 完了・レッドチーム中断 / コード改変なし・提案のみ -->

> ⚠️ **レッドチーム未実施（下書き段階）**。夜間セッションが上限に達し、検証工程A(実装妥当性)/B(会話の中身)が中断しました。
> 研究→起草までは完了。朝の判断材料として保存。採用検討時は、既存作品コピペ有無・口調ブレ・実装の分岐破綻を最終確認してください。

## 狙い

`DialogueData.innerVoice` は常時表示される「俺の心の声」なのに、読んでいるのは `stamina / money / lossStreak / justPassed / fame / compat(数値)` だけ。谷口との**相性帯**・ライバルの**動静**・**季節**・**キャリア年次**・**誰と組んでいるか(相方ID)** を一切見ていない。一方で `dialogue_design §2` は同じ場面を相性帯4段(0-7/8-14/15-20/21+)で書き分け「関係の変化を見せるのが相性というパラメータの感情的な正体」と定義し、`rival_scripts`・`partner_finals_reactions` は役柄・相方別の声まで作り込んでいる。**その関係の起伏が全部レアイベント側にしか届かず、moment-to-momentの手触り＝心の声は"関係ブラインド"のまま**——これが `fun_flow_review` の言う構造欠陥。

狙いは、**innerVoice を「軸を掛け算した表」から「条件付きルール束(Ruskin式)」に置き換える**こと。これで相性帯・ライバル・季節・年次・相方IDを**入力に足しても在庫が爆発しない**。「最も多くの条件を満たしたルールが勝つ／合う専用行が無ければ条件0本の汎用行へ静かに劣化する」——この一点で、関係を常時表示に流しつつ壊れない。

数値は全て【仮】。固有名は全て架空。

## 対象箇所

- `ManzaiGame/Sources/DialogueData.swift` の `innerVoice(state:lossStreak:justPassed:nextMilestone:weakAbility:)` の**入力設計と選択ロジック**（現状は `if` 優先度＋`pick(pool, salt)`）。
- 参照する正典: `dialogue_design_v0.md §2`(相性帯4段=トーン鍵の流用元)・`§6`(場面ID×相性帯×条件フックのテーブル選択・no-repeat)／`writing_craft_and_appeal_v0.md`(8技法・基調=過小申告＋温度差実況／1テキスト=技法1つ／天丼間隔はGameConfig)／`rival_scripts_v0.md`(貼り紙・ニュース欄で観測する"今週の事実")／`partner_finals_reactions_v0.md`(相方別声プロファイル・**差し替えは相方行のみ／地の文の三人称ナレーションは中立据え置き**の作法)。
- 【一線】ボケ(オチ)は書かない。心の声は反応・観測・言い回しのウィットのみ。

## どこから学んだか(技術＋出典URL)

- **Valve / Elan Ruskin「ルールデータベース＋ファジーパターンマッチ」**(L4D/Portal2/Dota2の掛け合いの実装正典)。現在状態の"事実(facts)"を、任意個の判定条件を持つルールへマッチさせ、**最も条件の多い＝最も具体的なルールが勝つ／専用行が無ければ条件の少ない汎用行へ graceful degradation**。総在庫は軸の積でなく「書きたい具体交差の本数」に**線形加算**で増える——これが在庫爆発(N/e問題)への直接の答え。GDC2012 "AI-driven Dynamic Dialog through Fuzzy Pattern Matching" https://gdcvault.com/play/1015528/AI-driven-Dynamic-Dialog-through ／スライドPDF https://cdn.cloudflare.steamstatic.com/apps/valve/2012/GDC2012_Ruskin_Elan_DynamicDialog.pdf ／解説 https://www.blog.radiator.debacle.us/2012/07/rule-databases-for-contextual-narrative.html （※gdcvault/radiatorはプロキシCONNECTポリシーで403。周知内容＋一次スライドで構成）
- **Left 4 Dead の状態入力**は "health / stress / これまで見た特殊感染者の種類(履歴)"。moment-to-momentの体感を状態で駆動し、組み合わせ生成でメモリを増やさず10倍のバリエーション。→ 本作の「今週、貼り紙でライバルの通過/敗退を観測した」という**1個の事実**を心の声のフックにする発想の元。L4D2開発者コメンタリ https://left4dead.fandom.com/wiki/Developer_Commentary_(Left_4_Dead_2)
- **Disco Elysium** — 内声は状態と関係で発話が変わる"エージェント"。元婚約者に触れる行だけボイスディレクションを「より優しく」微調整＝**同一の内声機構が"誰について語るか"でトーンだけ変わる**(新機構ゼロで関係ブラインドを解く前例)。https://reelmind.ai/blog/disco-elysium-script-narrative-game-design
- **Setup→(subtle)reminder→Payoff / Rule of Three** — 中間のリマインドが効き目を作る／3回目で裏切る。相性帯・年次は「同じモチーフを時を変えて再登場させる」天丼装置に最適。https://nofilmschool.com/plant-and-payoff-in-screenwriting ／ https://nofilmschool.com/rule-of-the-three
- **「全ての笑いは内輪だ」／サムさの発生源** — 関係を見せると観客を輪に入れて笑いが立つが、「相性15なので〜」的な説明台詞化は最悪のサムさ。関係は**数値でなく観測の差分**で出す(`dialogue_design §1`「UIが言うことを人間に言わせない」と一致)。https://note.com/shihomo/n/n6f06d0fd6608

## 実装イメージ(そのまま貼れるスニペット)

**方針**: 現行の `if` 優先度＋`pick` を土台として残し、その上に「条件付きルール」を疎に載せる。**各stateに条件0本の汎用行を必ず1本用意**しておけば、どの新軸を足しても未カバー時に必ず着地する＝壊れない・在庫爆発しない。

### (1) 事実(facts)の器 — 掛け算の軸ではなく"条件タグ"の供給源

```swift
// 追加案。GameCore側の状態から詰めるだけ（判定ロジック・golden非干渉／表示分岐のみ）。
enum CompatBand { case 他人行儀, 噛み合い, ツーカー, 阿吽 }   // §2の0-7/8-14/15-20/21+
enum Season      { case 春, 夏, 秋, 年末GP }
enum RivalBeat   { case none, ライバル通過, ライバル敗退 }      // 今週の貼り紙で観測した"事実"1個

struct VoiceCtx {
    // 既存入力（そのまま）
    let state: GameState; let lossStreak: Int; let justPassed: Bool
    let nextMilestone: (name: String, weeksLeft: Int)?; let weakAbility: String
    // 追加する"条件フック"（軸ではなく、当てはまれば効く任意タグ）
    let band: CompatBand           // §2流用（数値compatから帯へ変換するだけ）
    let rival: RivalBeat           // L4Dの「見た特殊感染者」に相当。既定 .none
    let season: Season
    let careerYear: Int            // 1〜10
    let partnerId: String          // 既定 "谷口"。未定義相方は八雲版=標準語中立へfallback
}
```

### (2) ルール1件の形（＝dialogue_design §6 の「場面ID×状態/相性帯×条件フック×技法タグ×本文」に対応）

```swift
struct VoiceRule {
    let scene: String              // "losing" / "heijo" / "passed" など（既存プールのキー）
    let craft: String              // 技法タグ（過小/温度差/擬人化/自虐/三段/誇張/直喩）
    let text: String
    // 条件フック（nilなら無条件＝この軸は不問）。満たした条件数=specificity。
    let band: CompatBand?; let rival: RivalBeat?
    let season: Season?; let minYear: Int?; let partnerId: String?
}
```

### (3) 選択規則 — 最も具体的なルールが勝つ／無ければ既存 pick にfallback

```swift
static func innerVoice(ctx: VoiceCtx) -> Advice {
    // 既存の絶対優先（体力・金欠）は据え置き＝生活の緊急事態は関係より前に出す
    if ctx.state.stamina < 25 { return Advice(name:"俺", text: pick(lowStamina, salt: Int(ctx.state.stamina))) }
    if ctx.state.money < 30_000 { return Advice(name:"俺", text: pick(lowMoney, salt: ctx.state.money)) }

    let scene = decideScene(ctx)   // "losing"/"passed"/"milestone"/"heijo" を既存優先度で決める
    let hits  = rules.filter { $0.scene == scene && matches($0, ctx) }   // 全条件がctxに一致
    if let best = hits.max(by: { specificity($0) < specificity($1) }) {  // 最も条件が多い＝具体的
        let top = hits.filter { specificity($0) == specificity(best) }
        let fresh = top.filter { !recentlyUsed($0) }                     // 審査員コメントと同じ no-repeat
        if let r = (fresh.isEmpty ? top : fresh).randomElementWeighted() {
            return Advice(name: "俺", text: r.text)
        }
    }
    // 条件付き行が無い場面は、現行の汎用プールへそのまま静かに劣化（既存挙動を保存）
    return Advice(name: "俺", text: pick(pool(for: scene), salt: saltFor(scene, ctx)))
}
// matches: 各フックが nil か、ctx と一致するかを AND。specificity: 非nilフックの本数。
```

### (4) 疎に載せる"関係の起伏"ルール群（両端・節目・ライバルビートだけ）— 追加は数十本オーダー

```swift
static let rules: [VoiceRule] = [

  // ─ 連敗×相性帯の両端だけ（0-7 と 21+）。同じ「谷口の沈黙」を温度反転で回収 ─
  VoiceRule(scene:"losing", craft:"過小申告", text:
    "谷口は何も言わない。まだ、慰め方を知らない距離だ。",
    band:.他人行儀, rival:nil, season:nil, minYear:nil, partnerId:"谷口"),
  VoiceRule(scene:"losing", craft:"過小申告＋温度反転", text:
    "谷口は今日も何も言わない。……その沈黙が、今は救いの側にいる。",
    band:.阿吽, rival:nil, season:nil, minYear:nil, partnerId:"谷口"),

  // ─ 連敗×ライバル観測（貼り紙で金字塔が上の回戦へ）。関係を"数値でなく紙の高さの差"で ─
  VoiceRule(scene:"losing", craft:"温度差実況", text:
    "あいつらの名前は、また一つ上の紙にあった。……こっちの紙は、まだこの高さだ。",
    band:nil, rival:.ライバル通過, season:nil, minYear:nil, partnerId:nil),

  // ─ 平常×キャリア年次の両端だけ（1年目 と 9年目以降）。中間年は汎用へ劣化 ─
  VoiceRule(scene:"heijo", craft:"ズレた冷静さ・自虐", text:
    "一年目の俺は、全部が初めてで、初めてだと気づく余裕もない。",
    band:nil, rival:nil, season:nil, minYear:1, partnerId:nil),        // year==1 側は matches で上限も見る
  VoiceRule(scene:"heijo", craft:"過小申告", text:
    "『あと少し』を数えるのはやめた。数えると、動けなくなる年数になった。",
    band:nil, rival:nil, season:nil, minYear:9, partnerId:nil),

  // ─ 季節は年末GP前後だけタグ（春夏秋は汎用）。擬人化は低頻度アクセント ─
  VoiceRule(scene:"heijo", craft:"擬人化(低頻度)", text:
    "街が、やたら年末の顔をしている。……この時期の稽古場だけ、少し息が白い。",
    band:nil, rival:nil, season:.年末GP, minYear:nil, partnerId:nil),

  // ─ setup&payoff：去年の自分への微リマインドを常時表示のまま（相性が上がった、とは言わない）─
  VoiceRule(scene:"heijo", craft:"温度差実況(時間差)", text:
    "去年は二駅、黙っていた帰り道を、今年は一駅で口を開いた。",
    band:.ツーカー, rival:nil, season:nil, minYear:2, partnerId:"谷口"),
]
```

### (5) 相方IDの波及 — "俺の文体は不変、観測される相方だけ差し替わる"

`reaction("rest_相方と過ごす")` のような**相方に言及する少数場面だけ** `partnerId` タグを付ける。partner_finals_reactionsの作法どおり、**地の文(俺の一人称ナレーション)は中立据え置き**、差し替えるのは"観測される相方の癖"1個だけ。谷口の口調で俺の内声を書き換えてはいけない。

```swift
// dialogue_design §6 表記に対応した「1行」（場面ID, 状態/相性帯, 条件フック, 技法タグ, 本文）:
// (rest_相方と過ごす, 相性8+,  partnerId=谷口,   温度差実況＋言外, 「壁の向こうで、まだネタを回す声がする。あいつは、スベった夜は寝ない。」)
// (rest_相方と過ごす, 相性8+,  partnerId=早乙女, 温度差実況,      「壁の向こうで、まだ発声練習の声がする。プロとして寝ろと言いたいが、俺も起きている。」)
// (rest_相方と過ごす, 相性8+,  partnerId=(未定義), 中立fallback,   「壁の向こうで、まだ声がする。あいつも、まだ起きている。」)  // ← 八雲版=標準語中立へ
```

俺の心の声＝標準語モノローグは全て不変。差し替わるのは「観測対象の相方の事実」1〜2個だけ。未定義相方は谷口版(関西弁)ではなく**八雲版=標準語中立**へ落とす(`partner_finals_reactions §4-3`の既定と一致)。

### 天丼(谷口「腹減ったな」)の共有カウンタ

心の声が谷口の口癖を"観測"して載せる場合も、レアイベント側と**同一の GameConfig 共有カウンタ**を参照する(登場は1年2回まで／3回目=感情最大点)。心の声が勝手に消費すると、決勝進出の山場で口癖が枯れる。

## リスク・注意

- **サムさ(最大の禁物)**: 関係を**数値でなく観測の差分**で出す。「相性が上がった」は禁止、「去年は二駅、今年は一駅」はOK。1内声=技法1つ(`writing_craft §92`)を厳守し、相性帯・季節・年次・相方を**同時に全部載せない**。ルールの条件は増やしてよいが、出力テキストは薄く。
- **在庫爆発の再発**: `state × band × season × year × partner` の全セル執筆は万オーダーで破綻。**両端・節目・特定ライバルビートという疎な点にだけルールを置き**、中間は graceful degradation で汎用が埋める。目安は全軸合わせて追加数十本【仮】。**条件0本の汎用行を各sceneに必ず維持**（これが壊れない土台）。
- **正典同期(CLAUDE.md §A)**: これは**表示層の分岐**でロジック非干渉なら golden に触れないが、`compat数値→band` 変換や年次・季節・rivalBeat を GameCore 側の**乱数消費・状態読み出し**に接続するなら、消費順が golden を壊す。ctxは**既存の確定済み状態を読むだけ**にとどめ、新規に乱数を引かない設計にする(no-repeat の履歴も既存の審査員コメント機構を共用し、新しい乱数源を足さない)。
- **相方IDの越権**: 相方の口調で俺の内声を書き換えると人格が壊れる。差し替えは"観測される相方の事実"に限定し、地の文の俺ナレーションは中立。未定義相方は八雲版フォールバック。
- **MVPの扱い**: 現状の関係ブラインドは"未実装なだけ"であって設計欠陥ではない。本書は**提案**。実装順は ①各sceneの汎用fallback完備 → ②連敗×相性帯の両端2本(効果最大・コスト最小) → ③連敗×ライバルビート1個 → ④季節/年次/相方IDを節目・両端の疎な点に後追い。各段階を `swift test` green のまま、simで送って**タップして可笑しいか**を目視(`§7-B`・§10)で確認してから次へ。

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>