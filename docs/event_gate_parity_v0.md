# 選択肢イベント 発火条件の一致点検（アプリ ↔ tools/sim_career.py） v0

要点
- 36種のうち ○=13（相方以外の人・第2束のうち条件と効果が両方一致）／×=23（うち軽い違い2・条件違い1・sim に無い20）。
- 一番効くのは構造の違い：sim の抽選プールは「汎用18種（EVENT_TABLE の代表値）＋16種」の34種一様。アプリは「週次25種」（固有9＋相方以外16）で、固有9種は sim に存在せず、汎用18種はアプリに存在しない。加えて sim は行動「後」の状態で引き、アプリは週頭（行動前）の状態で引く。
- 直し案は §3（どちらに合わせるかは決めない）。

節構成：§1 一致表 / §2 ×の詳細 / §3 直し案

## §1 一致表（○=一致、×=違う）
参照：アプリ＝GameCore/Sources/GameCore/ChoiceEvent.swift（weeklyBandFireable 約374〜430行・choices 約78〜370行）＋ManzaiGame/Sources/GameSession.swift（evaluateChoiceEventFire 509〜550行・rollWeeklyRandomEvent 566〜580行・weeklyExtraGate 602〜640行）／sim＝tools/sim_career.py（_others_fireable 173〜194行・_others_apply 196〜245行・抽選 800〜840行）。

### 1-A 相方以外の人＋第2束（simに対応あり・16種）
| イベント | アプリの条件 | simの条件 | 効果(A/B) | 判定 |
|---|---|---|---|---|
| kouhaiInvite | 所持金2万+・(2年目以降 or 週24+) | 同じ | A:-8000/華+1/メ+1　B:華-1/メ-1/体+5　simはボット方針(金5万+でA) | ○ |
| senpaiAllNight | 体力40+・次の本番まで2週以上 | 体力40+・honban_ahead>=2 | A:セ+1/メ+1/体-15　B:なし　一致 | ×軽(本番の数え方、§2-3) |
| stageCrewChairs | 週8+ | 同じ | A:知+1/体-10　B:体+5 | ○ |
| writerPostcards | 知10+・金<20万 | 同じ | A:+15000/発+1/体-10　B:相+1 | ○ |
| doukiJointLive | 週16+・知<40・金2万+ | 同じ | A:知+2/-10000/体-10　B:相+1 | ○ |
| baitoInventory | 金<15万・バイト3回以上(jobCount) | 同じ(_jobs) | A:+20000/体-15　B:表+1 | ○(ただし数えるタイミング差、§2-2) |
| homecomingCall | 週38+・次の本番まで4週以上(>3) | 週38+・honban_ahead>=3 | A:体+15/メ+1/-12000　B:表+1/メ-1　一致 | × (§2-4) |
| regularFanOranges | 知15+ | 同じ | A:華+1/知+1/-5000　B:なし | ○ |
| officeTicketQuota | 知<30 | 同じ | A:知+1/体-10　B:-6000/表+1 | ○ |
| summerFestivalGig | 週14〜20・体力40+・次の本番まで2週以上 | 同じ(honban_ahead>=2) | A:+12000/知+1/体-15　B:体+10/メ+1 | ×軽(§2-3) |
| doukiOnTV | 週20+・知<30 | 同じ | A:セ+1/メ-1　B:体+10/メ+1/-1000 | ○ |
| theaterRenovation | 週12+・知<40 | 同じ | A:知+2/-8000/体-10　B:表+1/体-5 | ○ |
| classmateInAudience | 週10+・知5+ | 同じ | A:知+1/メ+1/体-10　B:相+1/体+5 | ○ |
| partnerFever | 週6+・体力<50 | 同じ | A:相+2/-2000/体-5　B:表+1 | ○ |
| lostNotebook | 週10+・持ちネタあり | 同じ(s.netas・NETA_ON=False だと常に空＝不発) | A:メ+1/体-10/-1500　B:発+1/メ-1 | ○(NETA_ON 依存) |
| yearEndLive | 週33〜36（＋全イベント共通の「選べる選択肢がある」＝金1500+） | 週33〜36・金1500+ | A:セ+1/知+1/-5000/体-10　B:相+1/メ+1/-1500 | ○ |

### 1-B 固有の週次9種（simに無い）
| イベント | アプリの条件 | sim | 判定 |
|---|---|---|---|
| brokeDrinkingInvite | 金<5万・相性<上限 | 無し | × |
| senpaiMeishi | 金<20万・知<50 | 無し | × |
| peerFoldedChair | 週20+ | 無し | × |
| lineupTop | 知<20(フレーバー・効果なし) | 無し | × |
| greenroomSilentTen | 相性8〜14(フレーバー) | 無し | × |
| lastTrainReview | 知<20 | 無し | × |
| luckyThirdLine | 体力80+・連敗0・本番2〜4週前(フレーバー) | 無し | × |
| wroteOneTonight | 持ちネタあり | 無し | × |
| photoShootOffer | 知20〜50 | 無し | × |

### 1-C 確定発火10種＋廃止1種
| イベント | アプリ | sim | 判定 |
|---|---|---|---|
| riftWarning | riftWarned が立った次の週頭・1回 | RIFT_ON の rift_weekend で別実装（RIFT_RESPOND で「向き合う」ボット） | ×(別実装・既定は応えない) |
| weekendInvite | 週末の誘い(runner.pendingInvite) | invite_weekend 4%/週・別乱数 | ×(別実装。確率の一致は未確認) |
| justLostRehearsal | 負けた翌週・1回 | 無し | × |
| styleTalk | 連敗3+・一発 | 無し | × |
| justPassedFork | 通過直後・本番3週以上先・体力15+ | 無し | × |
| preTournamentEve | 本番1週前(格が高い)・1回 | 無し | × |
| earlyFormality | 1年目・週3〜14・相性<=7 | 無し | × |
| tsuukaBreak | 相性15+・1回 | 無し | × |
| namelessReservationSlip | 相性8+・本番2〜5週前(効果なし) | 無し | × |
| taniguchiShortJob | 金<10万・相性8+・3週内に本番なし(A:+15万/体-15) | 無し | × |
| regularEmployment | 廃止(抽選外) | 無し | ×(対象外・数えない扱いでも可) |

### 1-D simにあってアプリに無いもの
EVENT_TABLE の汎用18種（廃棄弁当・百円パスタ・先輩の焼肉・流行り風邪・出待ち・楽屋の神様・バズ・深夜ラジオ・シフトの恩人・同期の解散・対バン・財布・占い師・古着屋・先輩の飲み・谷口の誕生日・照明さん・おばあちゃん）は代表値であって、アプリの選択肢イベントとしては存在しない。SEASONAL（週1に+10体力、週26にメンタル+2）もアプリ側の選択肢イベントではない（別の仕組みの有無は未確認）。

## §2 ×の詳細
1. 【最大】プールの構成違い（sim_career.py 147〜165行・815〜840行 ↔ ChoiceEvent.swift isWeeklyRandom）
   - sim：汎用18＋相方以外/第2束16＝34種から一様に引く（EVENT_DRAW_FILTER=False の既定は「34種一様→発火帯外・発火済みは不発」で実効の発火率が下がる。True なら Swift 同様「発火帯の未発火候補から一様」）。
   - アプリ：週次25種（固有9＋16）から発火帯の未発火だけで一様。
   - 影響：汎用18種は帯の条件がなく常に出る・効果は小さな代表値。アプリは帯があり、固有9種はお金/体力/相性を動かす（例 senpaiMeishi 知+2、lastTrainReview、photoShootOffer 華+2・知+1・+1万、wroteOneTonight）。総発火数・各ステータスへの上乗せがずれる。DRAW_FILTER=False だと発火数が過小になりやすい（exp_event_cap_v0.py は True を指定済み＝そちらは近い）。
2. 引く時点の違い（sim_career.py 795行以降 ↔ GameSession.swift 509行・1222行）
   - sim：その週の行動(稽古・バイト・休み)を済ませ、粒の注ぎ(pour_all)後の状態で判定・適用。_jobs もその週のバイトを含む。
   - アプリ：週頭（行動前）の状態で判定、適用後に行動を選ぶ。jobCount は前週までの回数。
   - 影響：体力・お金の帯（体力40+、<50、金2万+等）で境界を跨ぐ週がずれる。体力ゲート系（senpai/festival/fever）が特に敏感。イベントの効果が行動の前か後かで成長・体力ゲート（稽古の体力20未満）への効き方も変わる。
3. 次の本番までの週の数え方（sim_career.py 248〜251行 _honban_ahead ↔ GameSession upcomingStages 約640行）
   - sim：TOURNAMENTS と GP_ROUNDS の全週（資格・GP生存・年を見ない。GP決勝週と敗者復活も含めない）から最小差。
   - アプリ：その年に出られる本番だけ（資格あり大会・GP生存中の回戦・決勝/敗者復活は資格がある時のみ）。
   - 影響：sim は出られない大会の前でも「本番が近い」と判定して senpai/festival を止める、決勝(週47)の前は止めない、等。差は小さめだが、homecoming（週38+）は週46〜47付近の本番が効く。
4. homecomingCall の閾値（sim_career.py 183行 ↔ GameSession.swift noTournamentWithin3Weeks 約688行）
   - sim：honban_ahead>=3（本番が3週先でも可）。アプリ：m.week-week>3（4週以上先）。1週ぶんの窓がずれる。週38〜の本番(38・46・47)が近い期間で発火機会が増減。影響は小〜中。
5. 週次抽選の前提（sim ↔ アプリ）
   - 確定発火との競合：アプリは確定発火(justLost・styleTalk・passFork・前夜・earlyFormality・tsuuka・nameless・taniguchi・rift・invite)が立つ週は週次抽選を引かない（evaluateChoiceEventFire の else 側だけで rollWeeklyRandomEvent）。sim は確定発火が存在しないため全自由週で引く。
   - 上限：アプリ weeklyEventCap=15（GameConfig.swift 369行）。sim は EVENT_FIRE_CAP の既定が None（無制限）。exp_event_cap_v0 だけが cap を指定。
   - 抽選率：どちらも 0.12（GameConfig 367行 ↔ EVENT_RATE）で一致。1回制・1週1回も一致。
   - 年の上限：アプリ側の週次抽選に年の上限は無い（kouhai の「2年目以降」のみ）。sim も同じ。
6. 確定発火10種の効果が sim に無い：justLost(最弱技能+2 等)・styleTalk・passFork(知+3 等)・tsuuka・earlyFormality・taniguchi(+15万)など。能力・お金に効くものがあり、その分アプリの成長/所持金が sim より多い/少ない。
7. 効果の数値：1-A の16種は GameCore の choices と sim の _others_apply が一致（ボット方針による A/B の選び方のみ差）。固有9種・確定10種は sim に適用が無いため比較不能。

## §3 直し案（見立て。決めない）
- 案A（simをアプリに寄せる、推奨寄り）：固有9種を _others_fireable / _others_apply に追加（OTHERS_EVENTS に足す）し、EVENT_DRAW_FILTER=True・EVENT_FIRE_CAP=15 を既定のイベント実測に揃える。汎用18種は「アプリに無い」ので EVENT_TABLE を空にするか、比較用フラグで外す。実測の数字がアプリと合う側に最も寄与するのはこれ（§2-1）。
- 案B：発火判定を「週頭（行動前）」に移す。sim のループ構造上の変更が大きい＝まず影響の大きさだけ測る（同じ乱数で前/後を入れ替えて分布差を見る）案も可。
- 案C：_honban_ahead をアプリの upcomingStages 相当（資格・GP生存を見る）にし、homecoming を >3 に直す。小改修（§2-3・§2-4）。
- 案D：確定発火10種のうち効果が大きいもの（taniguchi・passFork・justLost・tsuuka・earlyFormality）を sim に入れる。発火条件（連敗・通過直後等）は sim に状態があるので実装可能。
- 順序の見立て：C（小）→A（最大効果）→B（測ってから）→D。アプリ側を sim に合わせる方向（例：固有9種を消す、行動後判定にする）は仕様変更になるのでオーナー判断。
