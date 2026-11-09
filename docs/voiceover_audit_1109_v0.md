# 読み上げ（VoiceOver）点検 voiceover_audit_1109_v0（2026-11-09・読み取りのみ・コード未変更）

見方：grep→該当行だけ読んだ。実機の VoiceOver は未確認＝コードを読んだ推測。a11y_check_1026_voiceover_v0／a11y_check_1107_v0 で直し済み（Gacha 札・WeekMain 札の iconBox・banterBox・QualifierNotice／FinalsPresentation／RentStatement の action・YoseVitalMoneyBar の3札 label・Stage*/Juice/StageScene の hidden）は繰り返さない。

## §1 要点3行
- 種類別：①画像だけボタンで label 無し＝0件（歯車・サイコロは label 済み）／②onTapGesture で進むのに isButton・action 無し＝**13件**（うち表に載せるのは画面単位で 12 行）／③装飾の hidden 抜け＝1件（CharacterFace・低）／④数字札＝0件（体力・知名度・所持金・札の枚数・仕上がりは label 済み）。
- 一番大きい：**全画面タップで次へ進む画面（IntroFlow 結成カード・S6b 記録・TournamentResult 締めの余韻・ChoiceEvent・FinalistAnnounce・FinalsBroadcastIntro）に「次へ」の action が無い**。1026 の指摘 #1 のまま未対応。
- 1026 から直った所は多い。残りは「進む」系の action 足しが中心で、1コミットにまとまる。

## §2 指摘の表（重要順）
| # | ファイル:行 | 種類 | 読まれる／読まれない | 直し方の案 |
|---|---|---|---|---|
| 1 | IntroFlow.swift:84 | 2 | カードの文字は読まれるが「押すと次」が伝わらない | 同じ処理を `.accessibilityAction(named: "次へ")` |
| 2 | ChoiceEventOverlay.swift:107 | 2 | announcement はあるが次へ進む手がかり無し（選択肢が出る前の台詞送り） | `.accessibilityAction(named: "次へ") { advance() }` |
| 3 | TournamentResultView.swift:643 | 2 | 締めの余韻の送り（最後は acknowledgeResult）が無言 | action 足し（最後の1枚は「閉じる」） |
| 4 | S6bView.swift:207 | 2 | 「タップで進む」の文字は読まれるが操作として出ない | `.accessibilityAction(named: "次へ") { advance(.wall) }` |
| 5 | FinalistAnnounceView.swift:108 | 2 | 「飛ばす」ボタンはある。1組ずつ送る操作が無言（announcement は済み） | action 足し（tapAdvance） |
| 6 | FinalsBroadcastIntro.swift:57 | 2 | 同ファイルの :600 は action 済み＝ここだけ不揃い | action 足し（advanceStage） |
| 7 | Design/YoseChampionCelebrationView.swift:172 | 2 | 優勝演出の送りが無言（自動でも進む） | action 足し（handleScreenTap） |
| 8 | Design/YoseRankUpOverlay.swift:113 | 2 | 同上（自動で閉じる） | action 足し（dismissImmediately） |
| 9 | Design/YoseMilestoneFX.swift:146 | 2 | 同上。VoiceOver 中も自動で閉じるかは実機で確認 | action 足し（finished なら onFinish） |
| 10 | Design/YoseYearTurnCurtain.swift:134 | 2 | isModal は済み。「新年へ進む」操作が無言 | action 足し（triggerStart） |
| 11 | StageFrame.swift:291 | 2 | 幕の演出を飛ばす操作（自動で進む） | action 足し（finish） |
| 12 | AbilityUpView.swift:85 | 2 | 余韻中の背景タップ閉じ（透明の面）。待てば自動で閉じる | 低。action 足すか、透明面を hidden |
| 13 | TournamentResultView.swift:214, 249 | 2 | 透明面は hidden 済み。ただし送る手段が他に無いなら判断が要る | 判断が要る（別に「次へ」ボタン／action があるか実機で確認） |
| 14 | CharacterAvatars.swift:30（CharacterFace。TalkParts:77・ComboKindPicker:43,44・FinalsBroadcastIntro:185 で使用） | 3 | 図形だけなので読まれない見込み（推測）。読まれても雑音 | 低。body に `.accessibilityHidden(true)`（名札が別に読まれる所のみ。ComboKindPicker は呼び側の label 次第で判断が要る） |

観点1：Image だけの Button は IntroFlow:389（歯車）に「設定」、WeekMainView:814（候補サイコロ）に「題名の候補」の label があり抜け無し。
観点3：WeekMain・TournamentResult・YearResult・Shop・Gacha の Juice／Stage*／ParticleBurst は hidden 済み（Juice:40,128・StageFrame・StageScene）。ShopView・GachaView に Avatar 使用は無し。
観点4：YoseVitalMoneyBar（YoseGameParts:31〜）は体力「◯のうち◯」・知名度・所持金（借金対応）に label あり。NetaStageBadge は「仕上がり ◯」。数字だけで読まれる所は見つからず。

## §3 直す場合の見積もり
- #1〜#11 は各 1 行の `.accessibilityAction(named: "次へ")` 足し。11 ファイル・約 12 行・ロジック変更なし＝**1コミット**で済む（ビルド確認のみ。見た目は変わらない）。#12・#14 も同コミットに入れてよい（各 1 行）。
- 判断が要る所：action 名の文言（「次へ」で足りるか。最後の1枚だけ「閉じる」にするか）／#13 の送り手段の有無／#9 の自動で閉じる挙動（実機確認）。
