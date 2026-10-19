# EVENTS_APP 経路とアプリの突き合わせ（2026-10-19・読み取りのみ）

**結果：一致32件・不一致1件・片方だけ3件**（アプリ全36種＝確定発火10＋週次抽選25＋廃止1。sim 側は確定8＋週次25＝33種）。コードは変えていない。

## 不一致の一覧（直すなら sim 側の何を変えるか）
| # | 内容 | 直し方（sim 側1行） |
|---|---|---|
| 1 | **wrote「書けた一本」B**：アプリは体力+5/メンタル+1＋ネタ合わせ効果UP（netaBoostNextWeek=2週・倍率）。sim は体力+5/メンタル+1 だけ（`_app_apply` の wrote 注記どおり未モデル）＝B を選ぶボットの伸びを過小に見る | `_app_apply` の wrote B に `s._netaboost=2` を立て、`_neta_on_train` のネタ合わせ上昇に倍率（B.netaBoostMult 相当）を掛け週送りで減算 |

## 片方だけ
| イベント | 状況 | 直し方 |
|---|---|---|
| riftWarning（0050 会わない週が続いた） | アプリ＝確定発火（riftWarned が立った次の週頭・キャリア1回・A=rift-30/体力-10, B=なし）。sim は EVENTS_APP の経路に無く、別実装（RIFT_ON / RIFT_WARN=50 / RIFT_RESPOND=False が既定＝ボットは向き合わない） | 現状はボット方針が「B固定」でアプリの B と同値。A を試すなら RIFT_RESPOND=True。統合は不要 |
| weekendInvite（§102 飲みの誘い） | アプリ＝週末に別乱数で来て、次の空いた自由週頭に札（確定発火が優先・空き週まで繰り延べ）。sim は `invite_weekend` で週末に即適用（INVITE_P=0.04・行く＝−5,000/体力−10/メンタル+1/半分で発想+0.5）。効果値は一致、タイミングだけ違う（繰り延べ・確定発火に譲る分が sim に無い） | 差は小さい。厳密化するなら invite を `_app_state` に溜めて `_app_week_event` の最後（週次抽選の直前）で適用 |
| regularEmployment（0023 正社員） | アプリは抽選外（isWeeklyRandom=false・セーブ互換でケースだけ残置）。sim も無い | 対応不要（一致扱いにしない＝「両方無効」） |
| sim だけのイベント | なし | — |

## 注意（不一致ではない・読み方の補足）
- tsuuka／early のフラグ：アプリは「選んだ時」に didFire を立て、sim は「発火した時」に立てる。選ばずに閉じられない画面なので実質同じ。
- `_others_fireable` の homecoming は `honban_ahead >= 3`、アプリは `> 3`（noTournamentWithin3Weeks）。EVENTS_APP=True は `_app_band` が `> 3` に上書きするので一致。**旧経路（OTHERS_ON のみ）は 1 週ずれ**＝EVENTS_APP を使わない実測では `>= 3` を `> 3` に。
- アプリの「選べる選択肢が1つも無いイベントは出さない」（weeklyFireable）は全イベント共通。sim は yearend だけ明示（money>=1500）。現状ゲート付きで全選択肢が塞がるのは yearend だけなので結果は一致。新イベントを足す時は sim に同じ絞りを足す必要あり。
- ボットの選び方：sim は「余裕（お金5万+・体力50+等）があれば A」。アプリのゲートはもっと緩い（kouhai A は8,000、douki A は10,000、homecoming A は12,000、yearend A は5,000）。効果値は同じで、選び方はボット方針＝プレイヤーより A を選びにくい。ticket は体力<50かつ所持金<6,000だと sim は何も起こさない（アプリは A=手売りが常に選べる）。
- 乱数：sim は独立の `_app_rng`、アプリは UI 乱数（掛け合い抽選と共用）。分布は同じ（候補一様）で、並び順（sim=固有→相方以外／アプリ=allCases）は影響しない。
- EVENT_RATE は sim のグローバル（既定 0.12＝アプリ weeklyEventRate と一致）。exp_event_cap_v0.py のように上書きするスクリプトは EVENTS_APP とは別用途。

## 抽選・上限（一致）
| 項目 | アプリ | sim | 判定 |
|---|---|---|---|
| 週次率 | weeklyEventRate=0.12 | EVENT_RATE=0.12 | 一致 |
| 上限 | weeklyEventCap=15（確定は数えない・抽選成立前に判定） | APP_EVENT_CAP=15（確定は数えない・乱数を引く前に判定） | 一致 |
| 候補 | isWeeklyRandom 25種のうち未発火＆帯＆追加ゲート。一様 | APP_POOL 25種を同条件で一様 | 一致 |
| 確定発火の順 | rift > justLost > styleTalk > passFork > eve > early > tsuuka > nameless > tani > 誘い > 週次 | 同順（rift・誘いは別実装） | 一致（片方だけ参照） |
| 1週1回 | lastEventRollWeek | 週ループで1回 | 一致 |

## 確定発火 10種
| イベント | アプリ A / B / C・gate・発火条件 | sim | 判定 |
|---|---|---|---|
| justLostRehearsal | A 最弱スキル+2/メンタル-2/体力-10、B 体力+15/メンタル+2、C 相性+2/メンタル+1/体力+5/所持金-1500（gate 所持金>=1500）。負けた翌週・キャリア1回 | justlost：同値（最弱は センス,発想,表現,華 の先頭最小）。ボットは 体力50+→A／1500+→C／他→B。発火は jl&未発火 | 一致 |
| styleTalk | A 発想+2/表現-1/相性-2、B 表現+2/相性+1/メンタル-1。連敗3以上＆未実施（通過で再武装） | styletalk：B 同値（ボットは常に B）。条件 loss>=3&!style_done、通過でリセット | 一致 |
| justPassedFork | A 知名度+3/体力-15/メンタル-1、B センス発想の低い方+1/相性+1。通過直後・次の本番まで3週以上・体力15+・キャリア1回 | passfork：同値・同条件 | 一致 |
| preTournamentEve | A 表現+1、B 体力+10/メンタル+1。次の本番が1週先＆高格・キャリア1回 | eve：同値。高格＝GP最終回戦・決勝・敗者復活・大会 | 一致 |
| tsuukaBreak | A センス+2/相性-1/体力-10、B 表現+2/相性+1。相性15以上・キャリア1回 | tsuuka：同値 | 一致 |
| earlyFormality | A 相性+2/体力-15、B 体力+10/メンタル+1。1年目・週3〜14・相性<=7 | early：同値・同条件 | 一致 |
| namelessReservationSlip | 効果なし。相性8+・本番2〜5週前・キャリア1回 | nameless：同条件・効果なし | 一致 |
| taniguchiShortJob | A 所持金+150,000/体力-15、B メンタル-1/相性+1。所持金<10万・相性8+・本番まで3週超・キャリア1回 | tani：同値・同条件（ahead>3） | 一致 |
| riftWarning | 上記「片方だけ」 | 別実装 | 片方だけ |
| weekendInvite | 上記「片方だけ」 | 別実装 | 片方だけ |

## 週次抽選 25種（A / B の効果・gate・発火帯。sim は `_app_apply` / `_others_apply` / `_app_band`）
| イベント | アプリ A / B・gate・発火帯 | sim | 判定 |
|---|---|---|---|
| brokeDrinkingInvite | A 所持金-4000/相性+1/メンタル+1、B 発想+1/メンタル-1。所持金<5万＆相性<上限 | brokedrink：同値・同帯（ボットは所持金1万+で A） | 一致 |
| senpaiMeishi | A 華+1/知名度+2/メンタル-1、B 体力+15/メンタル+1/相性+1。所持金<20万＆知名度<50 | meishi：同値・同帯 | 一致 |
| peerFoldedChair | A 知名度+2/体力-10/メンタル-1、B メンタル+1/相性+1。週20+ | peerchair：同値・同帯 | 一致 |
| lineupTop | 効果なし。知名度<20 | フレーバー・同帯 | 一致 |
| greenroomSilentTen | 効果なし。相性8〜14（整数部） | 同帯 | 一致 |
| lastTrainReview | A メンタル-2/体力-5/低い方+2、B 体力+5/メンタル+1/相性+1/所持金-800。知名度<20 | lasttrain：同値・同帯 | 一致 |
| luckyThirdLine | 効果なし。体力80+・連敗なし・本番2〜4週前 | luckythird：同帯 | 一致 |
| wroteOneTonight | A 発想+2/表現+1/体力-15、B 体力+5/メンタル+1＋ネタ合わせ効果UP。持ちネタあり | wrote：A 同値、**B は効果UPなし** | **不一致（#1）** |
| photoShootOffer | A 華+2/知名度+1/所持金+10,000/体力-5＋今週の稽古不可(1週)、B 低い方+1。知名度20〜50 | photo：同値・稽古不可は `_preocc`＝1 | 一致 |
| kouhaiInvite | A 所持金-8000/華+1/メンタル+1（gate 8000）、B 華-1/メンタル-1/体力+5。所持金2万+＆(2年目以降 or 週24+) | kouhai：同値・同帯 | 一致 |
| senpaiAllNight | A センス+1/メンタル+1/体力-15、B なし。体力40+＆本番が2週以上先 | senpai：同値 | 一致 |
| stageCrewChairs | A 知名度+1/体力-10、B 体力+5。週8+ | crew：同値 | 一致 |
| writerPostcards | A 所持金+15,000/発想+1/体力-10、B 相性+1。知名度10+＆所持金<20万 | postcard：同値 | 一致 |
| doukiJointLive | A 知名度+2/所持金-10,000/体力-10（gate 10,000）、B 相性+1。週16+・知名度<40・所持金2万+ | douki：同値・同帯 | 一致 |
| baitoInventory | A 所持金+20,000/体力-15、B 表現+1。所持金<15万・バイト3回以上 | inventory：同値 | 一致 |
| homecomingCall | A 体力+15/メンタル+1/所持金-12,000（gate 12,000）、B 表現+1/メンタル-1。週38+・本番まで3週超 | homecoming：同値（EVENTS_APP では `>3`） | 一致 |
| regularFanOranges | A 華+1/知名度+1/所持金-5000、B なし。知名度15+ | fan：同値 | 一致 |
| officeTicketQuota | A 知名度+1/体力-10、B 所持金-6000/表現+1（gate 6000）。知名度<30 | ticket：同値（ボット方針は上の補足） | 一致 |
| summerFestivalGig | A 所持金+12,000/知名度+1/体力-15、B 体力+10/メンタル+1。週14〜20・体力40+・本番が2週以上先 | festival：同値 | 一致 |
| doukiOnTV | A センス+1/メンタル-1、B 体力+10/メンタル+1/所持金-1000（gate 1000）。週20+・知名度<30 | tv：同値 | 一致 |
| theaterRenovation | A 知名度+2/所持金-8000/体力-10（gate 8000）、B 表現+1/体力-5。週12+・知名度<40 | renovation：同値 | 一致 |
| classmateInAudience | A 知名度+1/メンタル+1/体力-10、B 相性+1/体力+5。週10+・知名度5+ | classmate：同値 | 一致 |
| partnerFever | A 相性+2/所持金-2000/体力-5（gate 2000）、B 表現+1。週6+・体力<50 | fever：同値 | 一致 |
| lostNotebook | A メンタル+1/体力-10/所持金-1500（gate 1500）、B 発想+1/メンタル-1。週10+・持ちネタあり | notebook：同値 | 一致 |
| yearEndLive | A センス+1/知名度+1/所持金-5000/体力-10（gate 5000）、B 相性+1/メンタル+1/所持金-1500（gate 1500）。週33〜36・どちらか選べる時だけ | yearend：同値・所持金1500未満は出さない | 一致 |

（regularEmployment は上記のとおり両方無効。）効果の加減算＋clamp（能力0〜120・メンタル0〜100・相性0〜20・体力/知名度0〜100・所持金は無制限）は `_ev_add` と `applyEventEffect` で一致。

## 直した所（10/19 自走）
- 不一致1件（wrote B のネタ合わせ効果UP）を実測機に入れた：NETA_BOOST_MULT=1.6・NETA_BOOST_WEEKS=2、自由週の頭で1減る（GameSession.tickNetaBoost と同じ並び）。EVENTS_APP=True の時だけ立つ＝既定と golden は不変（check_golden_sync 一致）。n=100 で動作確認。
