# 台詞の配列ごとの採点済み状況（2026-11-10）

## 結論
1. 次に採点すべき上位5：①banterPools（810行・最終は10/19のコードレビューのみ・その後8行増）②senpaiMeishi（28）③stageCrewChairs（28）④writerPostcards（28）⑤doukiJointLive（28）。いずれも文書に配列名が出ない（banterPools は名前のみ）。
2. 「記録なし」は29配列（うち ChoiceEventData が25）。10/27以前の記録のまま新行が増えたのは banterPools・justLostRehearsal・justPassedFork（＋記録なしの justLostRepeat・doukiOnTV）。
3. 注意：照合は配列名の文字列一致のみ。ChoiceEvent は「イベントID（#0012 等）」で採点されている場合があり、名前では拾えない（名前なしでも採点済みの可能性あり）。code_review 系の名前一致は○△×採点の証拠とは限らない。

方法：static let ごとの範囲内の文字列リテラル数を数え、docs 内の score/independent/review/sweep/voice を含む文書を配列名で grep。新行は git blame で 2026-10-28 以降の行（引用符を含む行）を数えた概数。

## 表1：記録なし（要素数の多い順）
|ファイル|配列|要素数(概数)|10/28以降の新行|
|---|---|---|---|
|ChoiceEventData|senpaiMeishi|28|-|
|ChoiceEventData|stageCrewChairs|28|-|
|ChoiceEventData|writerPostcards|28|-|
|ChoiceEventData|doukiJointLive|28|-|
|ChoiceEventData|summerFestivalGig|28|-|
|ChoiceEventData|theaterRenovation|28|-|
|ChoiceEventData|classmateInAudience|28|-|
|ChoiceEventData|yearEndLive|28|-|
|ChoiceEventData|senpaiAllNight|26|-|
|ChoiceEventData|regularFanOranges|26|-|
|ChoiceEventData|officeTicketQuota|26|-|
|ChoiceEventData|doukiOnTV|26|あり|
|ChoiceEventData|partnerFever|26|-|
|ChoiceEventData|lostNotebook|24|-|
|ChoiceEventData|tsuukaBreak|22|-|
|ChoiceEventData|earlyFormality|22|-|
|ChoiceEventData|peerFoldedChair|22|-|
|ChoiceEventData|photoShootOffer|22|-|
|ChoiceEventData|taniguchiShortJob|22|-|
|ChoiceEventData|wroteOneTonight|22|-|
|ChoiceEventData|lastTrainReview|22|-|
|ChoiceEventData|baitoInventory|22|-|
|ChoiceEventData|styleTalkTired|18|-|
|ChoiceEventData|styleTalkMoney|18|-|
|ChoiceEventData|styleTalkQuiet|18|-|
|ChoiceEventData|weekendInviteAfterShow|16|-|
|ChoiceEventData|weekendInviteRain|16|-|
|ChoiceEventData|weekendInviteCleanup|16|-|
|ChoiceEventData|weekendInviteTalk|16|-|
|ChoiceEventData|weekendInviteAfterStage|16|-|
|DialogueData|justLostSingle|5|-|
|DialogueData|justLostRepeat|5|あり|
|DialogueData|stageNearPlain|4|-|
|DialogueData|recovering|1|-|
|FanReportData|sns|1|-|

## 表2：記録が古い（10/27以前）配列
|ファイル|配列|要素数|最終文書|日付|10/28以降の新行|
|---|---|---|---|---|---|
|DialogueData|banterPools|810|code_review_2026-10-19l.md|2026-10-19|あり|
|DialogueData|losing|50|dialogue_score_1027d_v0.md|2026-10-27|-|
|FanReportData|bandC|45|dialogue_score_1027e_v0.md|2026-10-27|-|
|DialogueData|lowStamina|40|dialogue_score_1027d_v0.md|2026-10-27|-|
|DialogueData|passedLines|38|dialogue_score_1026c_v0.md|2026-10-26|-|
|ChoiceEventData|justLostRehearsal|29|code_review_2026-10-19b.md|2026-10-19|あり|
|ChoiceEventData|regularEmployment|26|code_review_2026-10-25e.md|2026-10-25|-|
|ChoiceEventData|styleTalk|22|variants_independent_score_1026_v0.md|2026-10-26|-|
|ChoiceEventData|justPassedFork|22|code_review_2026-10-19b.md|2026-10-19|あり|
|ChoiceEventData|brokeDrinkingInvite|22|dialogue_score_events_0012_0029_v0.md|2026-10-26|-|
|ChoiceEventData|riftWarning|22|code_review_2026-10-16.md|2026-10-16|-|
|DialogueData|lowMoney|10|dialogue_score_1027d_v0.md|2026-10-27|-|
|ChoiceEventData|namelessReservationSlip|10|code_review_2026-10-19l.md|2026-10-19|-|
|ChoiceEventData|lineupTop|10|code_review_2026-10-19l.md|2026-10-19|-|
|ChoiceEventData|luckyThirdLine|10|code_review_2026-10-19l.md|2026-10-19|-|
|ChoiceEventData|greenroomSilentTen|10|code_review_2026-10-19l.md|2026-10-19|-|
|DialogueData|stageNearWeak|4|dialogue_score_1027d_v0.md|2026-10-27|-|
|DialogueData|netaOroshiPool|4|dialogue_score_1027d_v0.md|2026-10-27|-|

新行ありの内訳（概数）：banterPools 8・reactionPools 6（11/10の sweep で記録済）・justLostRehearsal 3・justPassedFork 4・justLostRepeat 1・doukiOnTV 2・misFail 1・knownOnly 2（後二者は11/10記録済）。

## 表3：最近（10/28以降）の文書に名前がある配列

- DialogueData.平常（70）dialogue_plus3_independent_score_1109_v0.md 2026-11-10
- DialogueData.midseason（47）dialogue_plus3_independent_score_1109_v0.md 2026-11-10
- DialogueData.reactionPools（188）veteran_lines_main_sweep_1110_v0.md 2026-11-10
- FanReportData.burstLines（36）fanreport_plus_independent_score_1109_v0.md 2026-11-09
- FanReportData.bandA（90）veteran_lines_main_sweep_1110_v0.md 2026-11-10
- FanReportData.bandB（45）fanreport_plus_independent_score_1109_v0.md 2026-11-09
- FanReportData.bandD（70）code_review_1108c_screens.md 2026-11-08
- FanReportData.misPass（30）veteran_lines_main_sweep_1110_v0.md 2026-11-10
- FanReportData.misFail（13）veteran_lines_main_sweep_1110_v0.md 2026-11-10
- FanReportData.knownOnly（24）veteran_lines_main_sweep_1110_v0.md 2026-11-10
- ChoiceEventData.preTournamentEve（22）code_review_1107c.md 2026-11-07
- ChoiceEventData.weekendInvite（20）invite_variants_independent_score_1109_v0.md 2026-11-09
- ChoiceEventData.kouhaiInvite（28）code_review_allbundles_1109_v0.md 2026-11-09
- ChoiceEventData.homecomingCall（28）code_review_allbundles_1109_v0.md 2026-11-09
