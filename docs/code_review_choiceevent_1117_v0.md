# コード点検 ChoiceEventData.swift ほか 11/17 v0（読み取りのみ）

## 要点（3行）
- 件数：高0／中3／低4／要確認3（うち既知＝中2・低1・要確認1）。女性の形での男性語の生出しは見つからず（観点4は問題なし）。
- 一番重い新規：**styleTalk の4案が週番号で回るだけで、状況（所持金・体力）と結びつかない**（中）。残り中2件は既知（飲みの誘いの gate なし／母からの電話の季節）。
- 落ちる穴（配列範囲外・負の剰余・強制アンラップ・空プール）は見つからず。ラベル・会話の id の抜けも無し（機械で突き合わせ済み）。

## 節構成
§1 重さ別の指摘表／§2 問題なしを確認した所

## §1 指摘

| # | 重さ | ファイル:行 | 具体的な状態 → 結果 | 直し方の案 | 既知？ |
|---|---|---|---|---|---|
| 1 | 中 | ChoiceEventData.swift:47-55・156-158／styleTalkMoney 186-205・styleTalkTired 165-184 | `text(for:year:week:)` は `(year*48+week) % 4` で4案を回すだけ。所持金が潤沢な連敗中でも「出場料三回分で財布がだいぶ軽い／お金、きつくない？／バイトを夜も入れた」が出る。体力満タンでも「朝起きても体が重い／顔、疲れてるよ」が出る → 状況と台詞が食い違う（Money と Tired は中身が状態の主張） | 発火時の state（money<5万→Money、stamina<50→Tired、それ以外→元／Quiet）で選ぶ。または Money・Tired の台詞を状態の主張でない言い方にする。数値は不変（表示のみ） | 新規。style_talk_variants_1026_v0 は言い換えとして採点のみで連動は未検討 |
| 2 | 中 | GameCore GameCore ChoiceEvent.swift:364（weekendInvite の choices：A に gate なし）／ChoiceEventData.swift:341・363 | 所持金<5,000でも「先輩と飲みに行く（5,000円）」が押せて、`applyInviteGo` は床なしで `money -= inviteMoney` → 借金が増える。ラベルの「5,000円」も config.inviteMoney の直書き写し（値を変えるとずれる） | A の gate を `{ $0.money >= config.inviteMoney }`。ラベルは config 参照にする（表示専用なので text 側に金額を渡す） | **既知**：choice_gate_audit_1115_v0 #1／decision_brief_2026-11-08 B-9／AUTOPILOT 224 |
| 3 | 中 | ChoiceEvent.swift:421（週38以降）／ChoiceEventData.swift:952-953・959・969-971 | 暦は第1週＝4月なので第38〜47週は1〜3月。文は「年末の夕方」「お正月は帰ってくるの？」「正月は実家に帰る」「正月も稽古だね」。画面の暦と食い違う | 週を33〜36（12月）に寄せる、または文を春の帰省に書き直す。1月始まりに戻す案②（claude/calendar-jan-candidate）なら gate 側が `week>=41` になり別の問題（下の既知）あり | **既知**：calendar_words_1107_v0 §2-B／code_review_allbundles_1109_v0 #1 |
| 4 | 低 | ChoiceEventOverlay.swift:322（`.prefix(3)`）／photoShootOffer A（華・知名度・所持金の3枚で体力-5が落ち、4枚目に note）・justLost C・yearEndLive A | 4効果以上の選択で、減る側（所持金・体力）の札が出ない。選んだ結果が画面より重くなる | 上限を広げる、または減る側を先頭にする | **既知**：choice_effect_audit_1115_v0 #1・choice_event_inventory_v0 #6 |
| 5 | 低 | ChoiceEventData.swift:36-44・ChoiceEventOverlay.swift:324 | 数字に出ない効果の一言札はすべて `up:false`（和紙＝減る側の札）で出る。「二人の空気が少しほどけた」（rift-30＝良い効果）・「来週のネタ合わせが捗りそう」（良い効果）が、減る側の見た目で並ぶ。riftWarning A は体力↓と同じ見た目になり、良い効果に見えにくい | note の戻り値に up を持たせ、良い効果は伸びの札（濃色）にする（表示だけ） | 新規 |
| 6 | 低 | ChoiceEventData.swift:1213（yearEndLive の野々村「来年の話も…」）・969（母「春には一回帰る」） | 第15年（careerYears=15・最後の年）に出ると「来年」が無い。1回制でキャリア通算なので、未発火のまま15年目の第33〜36週に当たると起こりうる | 15年目は除外するか、文を「来年」でなくする。出る確率は低い | 新規（text_repeat_15y_yearend_1108 は独白側のみ） |
| 7 | 低 | ChoiceEvent.swift:424-431（theaterRenovation: `week>=12`・上限なし）／ChoiceEventData.swift:1098-1114 | 第45〜47週に「来月から二か月、改装で劇場を閉める」が出ると、第47週決勝（本番）と食い違う。同じく上限の無い doukiOnTV・classmateInAudience・partnerFever・lostNotebook は文面に時期語が無く問題なし | theaterRenovation だけ `12...40` 程度に区切る（gate 変更＝抽選プールの母数が変わるため判断） | 新規（choice_gate_audit_1115 は所持金 gate のみ見ている） |
| 8 | 要確認 | ChoiceEventData.swift:904・ChoiceEvent.swift:424（doukiJointLive 発火は所持金2万+） | B のラベル「お金が厳しいので、今回は断る」。発火時に所持金は必ず2万以上＝「厳しい」とは読めない場合がある（A は1万が要る） | ラベルを「今回は断る」程度に | 新規 |
| 9 | 要確認 | GameSession.swift:98-100・652-671 | firedWeeklyEvents／weeklyEventFiredCount は年をまたいでリセットされない（1キャリア1回制・上限15）。15年・25種で、後半の年は抽選プールがほぼ空になり、週次ランダムは起きなくなる。設計意図（各1回制）どおりなら問題なし | 意図の確認のみ | 既知寄り：choice_event_inventory_v0 の「1回制」・AUTOPILOT |
| 10 | 要確認 | ChoiceEvent.swift:425（コメント「週14-20」）・:431 | 夏祭り `14...20`：4月始まりの7月は第13〜16週、8月は第17〜20週。第13週（7月第1週）が漏れる（コメントは「7〜8月」）。12月 `33...36` は合っている | 13...20 に（意図が「第2週から」なら現状でよい） | 新規（calendar_words_1107 は「夏祭り（週14〜20＝7〜8月）は合っている」と判断） |

## §2 確認して問題なしだった所
- **効果と札**：チップは選択前後の state の差から組む（ChoiceEventOverlay 312-327）＝実効果そのもの。ラベルに書かれる金額は飲みの誘い（5,000円）だけで、実際の効果と一致（#2 のハードコードを除く）。ラベルの意味と効果の向き（A/B の体力・相性）は全イベント照合して食い違い無し。
- **穴**：`text(for:year:week:)` の `((x % n)+n)%n` は負にならず、`v` は常に非空。`choiceLabels[id] ?? id`／`afterChoice[id] ?? []` は安全（labels・afterChoice の id と ChoiceEventTable の id を機械照合：全一致、選択肢なし4種は両方空）。週次抽選は `min(.., count-1)` で範囲内、`candidates` 空は guard で返る。強制アンラップは無し。
- **gate**：全 gate 付き選択肢は weeklyFireable が「少なくとも1つ押せる」時だけ発火させる（空の選択肢カードは出ない）。
- **年・週前提**：earlyFormality は `year==1, week 3..14`、kouhaiInvite は `year>=2 || week>=24`、yearEndLive 33-36＝12月は4月始まりの暦と合う、preTournamentEve は HANA1回戦（動画審査）だけ除外。careerYears=15 に依存する数字は ChoiceEvent 系に無い。
- **女性の形の男性語**：地の文（name:nil 41行）に一人称・男性語尾なし。「俺」の話し手札は Names.show 経由（Text(String) 拡張）で私／名前に替わる。本文の `{me}`/`{partner1}` は Names.show を通る（「たち」「ら」の複数形も）。生の「俺」は堀口(824)・野々村(1223)のセリフ中のみ＝男性の先輩の台詞で問題なし。「お前ら」「～だろ／～ぞ」は先輩・堀口・真鍋（他者）の台詞のみ。
