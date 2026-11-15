# 選択肢イベントの「押せる選択肢が0」点検（11/15・読むだけ）

結論：**詰む（ボタンが1つも出ない）状態は起きない**。0件になりうる種類は無く、万一0になってもアプリは「閉じる」だけを出す作り。指摘は中2・低2。
調べた所：GameCore `ChoiceEvent.swift`（choices・weeklyFireable）／`GameSession.swift`（evaluateChoiceEventFire・rollWeeklyRandomEvent・applyEventChoice・availableEventChoices）／アプリ `ChoiceEventOverlay.swift`・`ChoiceEventData.swift`。
既出の照合：`docs/decision_brief_2026-11-08.md` B-9（飲みの誘いだけお金が足りなくても押せて借金）／`docs/AUTOPILOT.md` 224行（お金が足りない選択肢は消える・推奨A＝灰色）／候補 `origin/claude/money-short-choice-candidate`（アプリ3ファイル・+41行）。

## §1 指摘

| # | イベント | 状態 | アプリで見えること | 重さ | 確信度 | 最小の直し | 既出か |
|---|---|---|---|---|---|---|---|
| 1 | weekendInvite（§102 飲みの誘い） | gate なし。所持金が5,000未満・負でも「行く」が押せる。`applyInviteGo` は `money -= inviteMoney` で床なし（GameEngine.swift:325） | 「行く」が普通に出て借金が増える。他の金欠 gate 付き選択肢（0041 など）は消えるのに、これだけ押せる | 中 | 高 | A の gate を `{ $0.money >= config.inviteMoney }` にする（config が要る＝choices は config を持つので可）。候補 money-short-choice を入れれば灰色＋「お金が足りない」になる | **既出**（B-9・AUTOPILOT 224）。ただし候補ブランチの差分は GameSession/Overlay のみで ChoiceEvent.swift に gate を足していない＝候補だけでは飲みの誘いは直らない（灰色にする土台は入るが gate が無いので灰色にならない）。要確認 |
| 2 | yearEndLive（0057） | A（5,000未満で非活性）と B（1,500未満で非活性）の**両方**が gate 付き。所持金1,500未満だと0個 | 発火時は `weeklyFireable` が「1つも選べないなら出さない」で弾くので出ない（週16〜の抽選候補から外れるだけ）。所持金1,500〜4,999 のときは B だけが出る＝選択肢が1つ（「選ばされる」感）。さらに B を選んで所持金が1,500未満になると、選択後に `availableEventChoices()` が空になり `isFlavor` が true に反転＝絵の高さが262→320に跳ね、行の薄め表示がすべて濃くなる（選択後の描画が一瞬ずれる） | 低 | 中（コード読みのみ・実機未確認） | `isFlavor` を「発火時に選択肢が0」ではなく「`choices(for:)` 自体が空」で判定する（`ChoiceEventTable.choices(for:config:)` の空判定へ）。選択後の再評価で反転しなくなる | 未出（AUTOPILOT 224 の「0057 で選択肢が1つだけ」は既出だが、選択後に isFlavor が反転する点は未出） |
| 3 | ChoiceEventOverlay の0個時の見せ方（全イベント共通） | `availableEventChoices()` が空 → `isFlavor`＝選択肢なしフレーバー扱い。会話を全部並べて「とじる」1つ | 詰まない。ただし、選択肢があるはずのイベントが「選択肢なしフレーバー」に化ける（効果なしで閉じる）。現行の発火条件では起こらない（#4 参照）が、**古いセーブの保留中イベント**（保存時と所持金が違うことはない＝同じ state）では起こらないので実害は仮定のみ | 低 | 高 | 対応不要（保険として存在）。直すなら #2 と同じ | 未出 |
| 4 | 発火後〜表示までに状態が変わる経路 | 抽選時の `weeklyFireable` は週頭の state。表示は同じ週頭で state が動かない（`pendingChoiceEvent` はセーブに載るが state も同時に載る） | ずれは見つからず。debugForceEvent（DEBUGのみ）は gate を見ないので、金欠で yearEndLive を強制すると0個→「とじる」だけになる | 低（DEBUGのみ） | 高 | 対応不要 | 未出 |

補足（重さ「中」の根拠）：#1 は借金の積み増しで、夜逃げライン（`applyWeekEnd`）が近い状態では誘いに「行く」を押すと詰みに近づく。ただし B（断る）が常に押せるので画面は詰まらない。

## §2 問題なしと確かめた主な所（イベントごと・発火条件の下で押せる選択肢が残るか）

「gate 付き」は金額の下限で消える選択肢。「常時」は gate なし。週次抽選は `weeklyFireable` の共通ガード（選択肢があるのに全部 gate 落ちなら発火も上限消費もしない）が効く。

| イベント | 選択肢と gate | 0個になる？ |
|---|---|---|
| justLostRehearsal | A・B 常時／C 所持金1,500+ | ならない（A・B 常時） |
| styleTalk | A・B 常時 | ならない |
| justPassedFork | A・B 常時（体力15+は発火側の別ガード） | ならない |
| preTournamentEve | A・B 常時 | ならない |
| tsuukaBreak | A・B 常時 | ならない |
| earlyFormality | A・B 常時 | ならない |
| namelessReservationSlip | 選択肢なし（フレーバー） | 仕様どおり「とじる」 |
| taniguchiShortJob | A・B 常時（金欠が発火条件だが gate なし） | ならない（A の +15万は所持金に無関係） |
| riftWarning | A・B 常時 | ならない |
| weekendInvite | A・B 常時（#1） | ならない（ただし金欠でも押せる） |
| brokeDrinkingInvite | A（-4,000）・B 常時。発火帯が所持金<5万 | ならない（A は gate なしで負債化＝#1 と同型だが指摘外：B-9 の「飲み」は §102 側と解釈、**要確認**） |
| senpaiMeishi | A・B 常時 | ならない |
| peerFoldedChair | A・B 常時 | ならない |
| lineupTop / greenroomSilentTen / luckyThirdLine | 選択肢なし | 仕様どおり |
| lastTrainReview | A・B 常時（B は -800 だが gate なし＝負債化しうる） | ならない |
| regularEmployment | 抽選外（廃止）。A・B 常時 | ならない |
| wroteOneTonight | A・B 常時 | ならない |
| photoShootOffer | A・B 常時 | ならない |
| kouhaiInvite | A 所持金8,000+／B 常時（発火側も所持金2万+） | ならない |
| senpaiAllNight / stageCrewChairs / writerPostcards / baitoInventory / regularFanOranges | 常時のみ（regularFanOranges の A は -5,000 だが gate なし） | ならない |
| doukiJointLive | A 1万+／B 常時（発火側も2万+） | ならない |
| homecomingCall | A 1.2万+／B 常時 | ならない |
| officeTicketQuota | A 常時／B 6,000+ | ならない |
| summerFestivalGig | A・B 常時 | ならない |
| doukiOnTV | A 常時／B 1,000+ | ならない |
| theaterRenovation | A 8,000+／B 常時 | ならない |
| classmateInAudience | A・B 常時 | ならない |
| partnerFever | A 2,000+／B 常時 | ならない |
| lostNotebook | A 1,500+／B 常時 | ならない |
| yearEndLive | A 5,000+／B 1,500+（両方 gate） | 発火時は弾かれて0個にならない。1,500〜4,999 では B だけ（#2） |

文の表（ChoiceEventData）のずれ：機械で突き合わせた（`choices(for:)` の id と `choiceLabels`・`afterChoice` の id）。全イベント一致（A/B、justLost は A/B/C）。選択肢なしの4種は両方空で一致。styleTalk 4案・weekendInvite 6案の共有ラベル（styleTalkLabels・weekendInviteLabels）も A/B で一致。**会話の無い選択肢・余分な会話はゼロ**。

## 補足（既出との関係）
- 「お金が足りない選択肢は消える」（0053・0057 等）は仕様どおりの動作で、灰色化は候補 money-short-choice-candidate（既出・判断待ち B-9）。この候補は `moneyBlockedEventChoices()` で「お金だけが理由の gate 落ち」を灰色で出すだけ。gate 自体を持たない飲みの誘い・brokeDrinkingInvite・lastTrainReview・regularFanOranges の A は、候補を入れても灰色にならない（gate が無いため）。この点は B-9 の議論に1行足す価値あり。
