# フック画面の目視監査 v0（2026-10-26・既定の文字サイズ／ライト）

iPhone 17・MZ_UI フック直行。20画面（直近3監査で未見）を1枚ずつ確認。スクショ: feedback_shots/hooks_audit_1026/（コミットしない・23枚中20枚を精査）。debugChip（優勝/無双）は所見にしない。コードは未変更。

見た画面: settings / glossary / shop / endingbook / allocate / calendar / notebook / neta_list / weeknetas / cards / debt / rent / weekhint / wintercup / injury / prelude / gpresult / gploss / pass / result_done
崩れなし: settings・glossary・shop・endingbook・allocate・calendar・notebook・neta_list・weeknetas・injury・wintercup・gpresult/gploss（下記低を除く）

## 所見
| 重さ | 画面 | 所見 | 推定の場所 | 直し方の案（表示だけ） |
|---|---|---|---|---|
| 中 | weekhint / rent | 「ネタが無い」が3か所で重複（上の帯「まずはネタを書こう」・その下の一言「まだネタが無い。まずはネタを書こう。」・ボタン副題「まだネタがない。まず一本」）。語尾・表記（無い／ない）も不揃い | WeekHint.swift:47（MZ_DEDUP=top の仕組みが既にある）／WeekMainView.swift:960／WeekMainView.swift:1565 付近の帯 | 一言（WeekHint:47）をネタ0件では出さない＝帯とボタン副題の2つだけ残す。副題は「まだネタがない」で止め「まず一本」を削る |
| 中 | result_done | 優勝カード（賞金 +50万・知名度 9 ↑+6）の下端が「次へ進む」ボタンに接して枠の下辺が隠れる。講評カードと合わせて縦が詰まっている | TournamentResultView.swift（結果の積み段） | 下端に余白（safeArea＋ボタンの上に8〜12pt）／講評カードを1行短く |
| 低 | cards | 稽古・ネタを書くの「出張中」テープがタイトル文字に重なり、「ネタを書く」が読みにくい（意図的なテープだが文字の中央に被る） | WeekMainView.swift:1013 | テープをカード右上へ寄せ、タイトル文字と重ねない |
| 低 | cards | 理由が2か所（上の帯「ネタは来週から」・一言「今週は撮影の仕事で、稽古には出られない。」）＋テープ。帯の「ネタは来週から」は稽古の話と混ざる | WeekMainView.swift:1565／WeekHint.swift:45 | 帯は「大会まで間がある」だけにする |
| 低 | prelude | 小札が「頂GP 回戦」で回戦の数が無い（看板は「頂GP 1回戦」）。余分な半角空白も | StageViews.swift:306（stageTag）／:277（key.dropFirst(2)） | 看板の回戦名と同じ語（頂GP 1回戦）を渡す |
| 低 | wintercup / prelude | 体力 0/100 のまま「出場する／本番へ」が押せる（見本は debug 状態）。注意帯は wintercup だけ、prelude には無い | StageViews.swift（本番前カード） | prelude にも同じ「体力が尽きた状態」帯を出す案 |
| 低 | debt | 所持金が「¥-100,000」。符号の位置が不自然（「借金」札とも二重） | 下部バー（WeekMainView／YoseTheme の金額整形・grep "¥-" 不一致のため整形関数を確認） | 「-¥100,000」または「¥100,000」＋借金札のみ |
| 低 | pass | 客席アンケートの引用に「あなたのコンビ」（既定コンビ名）が文中に出る。実コンビ名なら自然だが見本では不自然 | FanReportData.swift | 見本のコンビ名だけの問題。本番確認のみ |
| 低 | settings | 下部の権利表記カードの上に「•」が1つ浮く | SettingsView.swift:72 付近 | 飾りなら位置を整える／不要なら削除 |
| 低 | allocate | 持ち分の5色の丸（種・帳・間・見・場）が1字で、初見は何か分かりにくい（？ヘルプはあり） | AbilityUpView（持ち分ヘッダ） | 丸の下に「ことば」等の短い名を添える（用語集と揃える） |
| 低 | gploss | gpresult と同じロック画面通知の1枚で、落選の画面が別に確認できなかった（フックが同じ見た目を出す） | RootView.swift:241-249 | フック側の確認のみ。表示の直しなし |

## 件数
重 0／中 2／低 9（計11）。

## 未確認（今回の枠外）
prestage / finals / qual_notice（撮影済み・未精査）／stage / juice / ending / event / qual_line / finalist_announce / notif / frame / catalog。

## 追記（10/26 未明・親の対応）
- 済：中2 結果の精算札の下に余白 53ab959 の前のコミット／低 prelude 小札「頂GP 1回戦」b0b153e の次／低 借金の表記「-¥100,000」（いずれも iPhone 17 で目視）。
- 据え置き：中1「ネタが無い」の重複＝キュー111 の判断待ち（DEBUG 見本 MZ_DEDUP=top あり）。低 settings の「•」＝木札の釘の飾り（yoseKifuda showNail）で意図どおり。低 pass のコンビ名＝見本の既定名だけの問題。低 gploss＝フックの確認のみ。
- 残り（表示だけ・次の回）：cards の「出張中」テープが題字に重なる／cards の帯「ネタは来週から」／wintercup・prelude の体力0注意帯の不揃い／allocate の5色丸に短い名。
