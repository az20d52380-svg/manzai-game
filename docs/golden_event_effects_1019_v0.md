# 選択イベントの効果 golden（2026-10-19）

**結果：29イベント×開始状態3通り＝85件。Python（EVENTS_APP=True の `_app_apply`/`_others_apply`）とアプリ（`ChoiceEventTable` の effects を `applyEventEffect`）が全値一致。不一致なし。** 式・乱数・GameConfig・sim 既定・アプリ Sources は変えていない。

## 仕組み
- 期待値：`tools/gen_golden_features.py` の `event_effect_cases()`（`golden_features.json` の `ext.event_effects`）。乱数なし。
- 検証：`FeatureGoldenTests.testEventEffectsGolden`。同じ開始状態に、sim の方針が選ぶ側の effects を順に当て、能力4種・メンタル・体力・所持金・相性・知名度、加えて netaBoostWeeks（wrote B）と preoccupiedWeeks（photo A）を 1e-9 で比較。側のゲートが閉じていないことも確認。
- 側（A/B/C）のラベルは生成器内に sim の分岐条件（体力・所持金）を写したもの。取り違えれば状態が食い違って赤になる。

## 開始状態
| 名前 | 内容 |
|---|---|
| hi | 体力90・所持金50万・相性5・知名度40・メンタル60・センス40/発想30/表現35/華25（ほぼ全て A 側） |
| lo | 体力20・所持金800・相性3・知名度5・メンタル20・能力10/10/12/8（センス=発想の同値・ほぼ B 側。tv は所持金<1000 で A） |
| edge | 体力55・所持金6万・相性19.5・知名度98・メンタル99・能力119/118/117.5/119（上限 clamp・festival A／eve B／senpai B の境目） |

## 守ったイベント（29）
確定発火7：justLostRehearsal・styleTalk・justPassedFork・preTournamentEve・tsuukaBreak・earlyFormality・taniguchiShortJob
週次抽選22：brokeDrinkingInvite・senpaiMeishi・peerFoldedChair・lastTrainReview・wroteOneTonight・photoShootOffer・kouhaiInvite・senpaiAllNight・stageCrewChairs・writerPostcards・doukiJointLive・baitoInventory・homecomingCall・regularFanOranges・officeTicketQuota・summerFestivalGig・doukiOnTV・theaterRenovation・classmateInAudience・partnerFever・lostNotebook・yearEndLive

## 対象外
- 効果なし（フレーバー／選択肢なし）：namelessReservationSlip・lineupTop・greenroomSilentTen・luckyThirdLine。
- sim に無い／別実装：riftWarning・weekendInvite（events_parity_check の「片方だけ」）。regularEmployment は抽選外。
- sim が選ばない側：各イベントのもう片方。justLostRehearsal の C（体力<50かつ所持金1500+）は今回の3状態では当たらず未検証。
- 方針が何も起こさない状態：ticket（体力<50かつ所持金<6000＝lo）・yearend（所持金<1500＝lo）は件数に入れていない。

## 確認
`gen_golden_features.py` 再生成 → `swift test` 334件 green → `check_golden_sync.py` 3つとも ✅。
