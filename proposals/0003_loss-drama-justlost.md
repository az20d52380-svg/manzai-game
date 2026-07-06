<!-- 夜間提案 0003 / 研究→起草 完了・レッドチーム中断 / コード改変なし・提案のみ -->

> ⚠️ **レッドチーム未実施（下書き段階）**。夜間セッションが上限に達し、検証工程A(実装妥当性)/B(会話の中身)が中断しました。
> 研究→起草までは完了。朝の判断材料として保存。採用検討時は、既存作品コピペ有無・口調ブレ・実装の分岐破綻を最終確認してください。

## 狙い

`fun_flow_review` が最弱点と断じた「同じ壁への連敗＝最も回数の多い感情イベントが、最も語彙の薄い瞬間」を塞ぐ。具体的には二つ。

1. **温度事故の停止**。現状 `innerVoice` は `低体力 > 金欠 > 連敗(≥2) > 直近通過 > 大会前 > 平常` の優先順（`DialogueData.swift:20-38`）で、**敗退直後でも `lossStreak==1` の週は平常プールに落ちる**。負けた翌週に「今週も、一歩だけ前に。」が出る。これは励ましの押し売り＝感動ポルノの縮小版で、万人に外す。`justLost` を `justPassed` の対として独立させ、**必ず出る節目**として確定発火させる。
2. **反復を天丼に変える**。`losing` の2行 salt 回しは「変化なしの反復」＝退屈側。同一壁の連敗数を軸に、2連＝フリ／3連＝反復の重さ／4連以降＝変化（壁の事件化）と段を上げる。熱と執念は「俺」でなく谷口・支配人の年1枠に寄せ、声を崩さない。

## 対象箇所

- `ManzaiGame/Sources/DialogueData.swift:20-38`（`innerVoice` 優先順）、`:50-53`（`losing`）、`:54-57`（`passedLines` ＝対にすべき既存プール）。
- `ManzaiGame/Sources/GameSession.swift:28-31`（`lossStreak` / `justPassedStage`）、`:149-152`（結果処理の更新点＝`justLost` と同一壁カウンタを**同じトランザクションで**足すべき場所）。
- `docs/dialogue_design_v0.md` §4「同回戦3年連続」（＝3連の既存実装／天丼3回目）、§5「9年目（未優勝）」（＝年次ラダーの前例）、§6 の `(場面ID, 相性帯, 条件フック, 重み)` テーブル形式。
- `docs/fun_flow_review_v0.md` §2-3（年次一言ラダー・3軸）。

いずれも**未実装なだけ**で欠陥ではない。以下は提案（数値は全て【仮】）。既存ファイルは読むだけ。

## どこから学んだか（技術＋出典URL）

- **確定発火の二層構造**（セクションイベント＝必ず起きる／ランダム＝彩り）。敗退直後の一言は前者に置くべき節目。パワプロ「サクセス」。https://ja.wikipedia.org/wiki/実況パワフルプロ野球_サクセスモード ／ https://xn--odkm0eg.gamewith.jp/article/show/57017
- **失敗を必ず承認する（acknowledge）／進行を勝利数でなく試行回数に紐づける**。Hades のヒュプノスが死因を毎回拾う。https://www.davideaversa.it/blog/hades-case-study-storytelling-roguelike-games/ ／ https://natalia-nazeem.medium.com/failure-is-death-and-death-is-progress-the-use-of-repetition-replayability-and-narrative-673cfa4e2e8
- **声の固定トーン分離**。失敗は各「人格」の色で実況され、熱を1つの声に混ぜない。Disco Elysium のスキル。https://gameplayreflections.wordpress.com/disco-elysium-and-the-meaning-of-failure/
- **天丼＝3段エスカレーション**（1フリ／2反復／3変化・3回目が最大・間隔管理）。https://owa-rai.com/tendon/ ／ https://humorsense.s-teem.com/2012/03/post_78.html
- **反復失敗は"別種でより重い"失敗へ**（単純反復は退屈／All Is Lost への布石）。https://stormwritingschool.com/escalating-complications/
- **カウンタ＝乾いた事実がドラマを語る**（"○年連続"というメーターそのものが物語）。無冠の帝王の構造。https://ja.wikipedia.org/wiki/笑い飯 ／ https://toyokeizai.net/articles/-/717910
- **感動を宣言しない**（感動ポルノ回避＝事実と温度差で置く）。https://ameblo.jp/isawo-t1307/entry-12689913076.html

学んだのは構造・型のみ。既存作品のセリフは一切引かない。

## 実装イメージ（そのまま貼れるスニペット・既存構造に載る形）

### (1) `justLost` 帯を新設し、`justPassed` の対として確定発火

優先順は **`低体力 > 金欠 > justLost(敗退直後) > 連敗(≥2) > 直近通過 > 大会前 > 平常`**。`justLost` は行動で失効（`justPassedStage` と対称）。低体力・金欠より下に置くのは「負けた上に困窮」の二重苦を先に語らせる判断。ここは温度判断なので要目視（CLAUDE §10）。

```swift
// 【提案・DialogueData.swift 追記イメージ／未適用】敗退直後専用プール。励まさない・事実と温度差だけ。
private static let justLostSingle = [   // streak==1：単発敗退直後
    "結果は見た。二度見した。二度とも、同じ順位だった。",           // [過小申告][温度差実況]
    "悔しい、の一歩手前で止めておく。ここで言葉にすると、癖になる。", // [ズレた冷静さ]
    "来年がある。その言葉の軽さについては、今週は考えないことにする。", // [温度差実況]
]
private static let justLostRepeat = [   // streak>=2：連敗直後。まだ壁を名指ししない（＝天丼のフリ）
    "また同じ段だ。何段目かは、もう暗算できる。",                   // [過小申告][擬人化の前振り]
    "負け方に既視感がある。それが順位より、少し腹立たしい。",        // [ズレた冷静さ]
]
```

`GameSession` 側は結果処理（`:149-152`）と同トランザクションで `justLost: Bool` を立て、`innerVoice` へ `justPassed` と並べて渡すだけ。乱数は触らない＝golden不変（正典同期の対象外）。

### (2) 同一壁連敗数カウンタ（`GameSession` 側・提案）

`lossStreak`（総連敗）とは別に `lastLostStage: StageID?` と `sameWallStreak: Int` を持つ。敗退時、前回と同じ stage なら +1／別 stage なら 1 にリセット／通過で 0。これが `fun_flow` §3 の第3軸。

### (3) 年次1行ラダー（他者声・`dialogue_design` §6 テーブル形式）

熱・執念・壁の事件化は「俺」でなく谷口／支配人へ。既存の谷口台詞トリガ・支配人年1枠を流用。§4「3年連続」が既にこの3回目に当たるので接続する。

`(場面ID, 話者, 条件フック, 技法タグ, 本文)`：

| 場面ID | 話者 | 条件フック | 技法 | 本文 |
|---|---|---|---|---|
| `wall.ladder2` | 谷口 | `sameWallStreak==2` | 擬人化・フリ | 谷口「同じ壁、二回目やな。……二回目からは、名前で呼んでええやろ」 |
| `wall.ladder3` | 谷口 | `sameWallStreak==3` | 天丼3回目・反復の重さ | 谷口「三年、同じ番号で落ちとる。壁のほう、そろそろ俺らの顔、覚えたんちゃうか」／俺「なら、覚えられてるうちに越える」 |
| `wall.ladder4` | 谷口 | `sameWallStreak>=4` | 変化・転調 | 谷口「高さはもう知っとる。今年は測りに行くんやない。……崩しに行くだけや」 |
| `wall.year8` | 支配人 | `year>=8`（連敗数不問・閾値確定） | 事件化 | 支配人「晩年に一度、事件が起きるものです。……起こす側に、回ってみませんか」 |
| `wall.year10`| 支配人 | `year==10`（両プレイ型で確定） | 過小・接続 | 支配人「今年で最後。妙な言い方ですが、人はラストイヤーに、いちばん伸びます」 |

谷口の本音は「壁を名前で呼ぶ」「顔を覚えた」の**事実1つ**で置き、悔しさは言語化しない（声の規律）。3回目（`ladder3`）に最大の筆。`year8/10` は `lastyear_calibration` §6 の二種の奇跡と接続。

### 必要量（MVP現実解）

フルマトリクス250行は過剰。`justLost`（俺）＝ `single 4-6行 + repeat 4-6行 ≒ 10-12行`（`passedLines` が2行なので対として最低同格以上）、年次ラダー（他者声）＝ `5段 × 話者流用 ≒ 5-8行`。**合計20行前後で温度事故は消える**。フルラダーは増産フェーズへ。

## リスク・注意

- **【設計上の懸念】`justLost` の優先順位置**。低体力・金欠の切迫を上に残す現案 vs 敗退直後を先頭級に上げる案は温度判断。simでは測れないので simulator 目視で決める（CLAUDE §10・§D）。
- **口癖の天丼制御**。谷口「腹減ったな」は `dialogue_design` §6 で年2回・感情最大点用。ここの `wall.ladder*` に流用しない（希釈すると死ぬ）。壁の擬人化も `ladder2→3→4` で1回ずつ、間隔は `writing_craft` §99 の GameConfig【仮】管理に載せ、近すぎ（くどい）・遠すぎ（忘れる）を避ける。
- **声を混ぜない**。「俺」に執念・鼓舞を持たせると自己陶酔＝寒い。熱は他者声へ。`justLost*` は過小申告と温度差のみに保つ。
- **正典同期の対象外だが発火順は注意**。テキスト／発火条件レイヤーで数式・乱数消費順に触れないが、`justLost` と `sameWallStreak` の更新は `GameSession.swift:149-152` の `lossStreak`/`justPassedStage` 更新と**同一トランザクション**で足すこと（結果処理順のズレは表示バグの温床）。
- **MVPは1年完結**（`GameSession.swift:36` `year=1`）。`year8/10` 段は本編（多年）到達後にしか発火しないので、MVP検証では `sameWallStreak` と `justLost` 帯のみが動作対象。未発火＝欠陥ではない。