# オファー（札）の流れのコード点検（2026-11-15・読むだけ）

- 要点1：新規は5件（高0・中2・低3）。札の効果の二重適用・乱数のずれ・拘束の取りこぼしは見つからなかった（GameCore と Python の乱数消費順は rollOffer／extraOffers／do_offer とも一致）。
- 要点2：いちばん重いのは「高い知名度の帯（札が2〜3枚になる帯）で、説明文の『顔が売れて』と実際の知名度の伸び（+0.1〜+0.7）が食い違う」件（#1）と、Python 計測の「変な仕事」がアプリに無い件（#2）。
- 要点3：既出と照合済み＝112（テレビ慣れの表示）・137（大きい文字）・167（体力0）・444（押し直し）・double_tap #4・lifecycle #5・save_restore（offerPick）。

節構成：§1 新規の指摘 ／ §2 既出の照合 ／ §3 問題なしの確認（観点1〜5）

---

## §1 新規の指摘

### #1 札の説明と知名度の伸びの食い違い（重さ：中）
- 場所：GameEngine.swift:197-199（applyOffer が `add(.知名度, o.fame)`）／GameConfig.swift:346-347（fameOtherMult 0.6・fameOtherCap 80）／CommandData.swift:126-131（offerBlurb）／WeekMainView.swift:904（offerPickCard）
- 起きる手順：知名度55以上（札が3枚）でひな壇を見る。説明は「顔が売れて、喋りも磨かれる」。実際の知名度は +3 × 0.6 × (1−55/80)² ≒ +0.18（知名度30でも ≒ +0.7、60で ≒ +0.11）。上の札の下の「知名度 +N」のピルは丸めて0になると出ない＝カードの数字は正しいが、文だけが売れると言う。
- 直し方の案：①ひな壇の文を知名度に触れない形にする（例「ひな壇に座って喋る。喋りが磨かれる」）。②知名度が一定以上（例 50以上）の時だけ文を差し替える。表示のみ・golden 不変。判断はオーナー（文の正典は manzai-drama-voice 側）。

### #2 Python の計測にある「変な仕事」（知名度<20 でオファーが小銭仕事に化ける）がアプリに無い（重さ：中・規律A の観点）
- 場所：tools/sim_career.py:1040-1047（`EVENTS_ON and offer is not None and s.fame < 20` で offer=None・所持金+25,000・体力−15・能力+1・rng.choice で乱数を1回余計に消費）／tools/canon_v2.py:26（正典v2の計測条件が EVENTS_ON=True）。Swift 側は GameCore・ManzaiGame とも該当処理なし（「変な仕事」「25_000」を grep して0件）。
- 起きること：知名度10〜20の帯（発生率5〜15%）で、計測は 2.5万の小銭仕事＋体力−15、アプリは本物のオファー（10〜28万・知名度+1〜3）が出る。序盤の所持金・知名度はアプリの方が甘くなる＝計測のバランスがアプリを表していない。golden（EVENTS_ON=False）には影響しない。
- 既出との関係：docs/events_app_parity_v0.md:36・68 に「アプリ側に同じ仕組みがあるかは未確認」とある。この点検で「アプリには無い」と確認できた。
- 直し方の案：①アプリ側にも同じ置換を入れる（体験が変わる・判断が要る）。②計測側を `EVENTS_ON` から切り離して置換を外す（正典v2 の数字が動く＝再計測）。③差を許容して文書に明記。

### #3 計測のボットは追加の札（2枚目以降）を一度も使わない（重さ：低・バランス）
- 場所：tools/sim_career.py:845（extra_offers の定義のみ。呼び出しは tools/gen_golden_features.py:129 のテストだけ）。run_year（:1040）は B.roll_offer の1枚だけをボットに渡す。
- 起きること：アプリでは知名度30以上で2枚・55以上で3枚から選べる（収入が高い営業・ロケを選べば所持金が増える）が、計測は常に最初の1枚。収入・知名度の見積もりがアプリより低め（札の選びで稼げる分が計測に出ない）。乱数は別系統なので本編の golden は不変。
- 直し方の案：①ボットに「所持金が足りない時は収入の高い札・足りている時は知名度の高い札」を選ばせる（Policy.choose の拡張・再計測が要る）。②据え置いて文書に「計測は1枚目だけ」と書く。

### #4 受けられない週・療養の扱いが Python の2本で違う（重さ：低・今は影響なし）
- 場所：tools/gen_golden.py:143-150（療養週は `B.do_rest(s, "完全休養")`＝use_ticket 既定）／sim_career.py:1048-1051（`use_ticket=False`）／WeekRunner.swift:439-441（`useTicket: false`）。
- 起きること：golden 生成器だけ療養週に回数券を使う書き方。golden の経路には回数券（Item）が無いので今は数字が同じ。回数券を golden に入れた時に初めて食い違う。
- 直し方の案：gen_golden.py の療養週を `use_ticket=False` に揃える（1語・golden の数字は動かない）。

### #5 「オファーが無いのに受ける」の動き（重さ：低・到達しない）
- 場所：WeekRunner.swift:349-354（offer が無い週の .acceptOffer は完全休養）／sim_career.py:1090（`act == "offer" and offer` で偽なら何もしない）。
- 起きること：アプリは札の無い週に .acceptOffer のボタンが出ない（CommandData.swift:138 が offer 有りの時だけ作る）ので到達しない。CodableTests:145 が休養に落ちる側を固定している。Python は何もせず行動なしの週になる。実害なし・メモのみ。

---

## §2 既出との照合（新規に数えない）

- 112：テレビ慣れの表示が本編に無い（WeekMainView.swift:378-383 は DEBUG の MZ_TVTIRED だけ）。今回の確認：`CommandCatalog.extraCards` は `fatigued` を受け取るが使っていない（CommandData.swift:136）。cardEffects（WeekMainView.swift:1561）は上がった分だけ出すため、ロケ・営業（能力なし）では −0.5 の下がりがどこにも出ない。ひな壇・ラジオは表現 +2 が +1.5 になるだけで「実力 ↑」のまま。112 の範囲内。
- 137：大きい文字で札が舞台を覆う（WeekMainView.swift:373-395 の帯）。
- 167：体力が足りない週でもオファーが押せる（resolveAction の .acceptOffer に体力の門なし・WeekRunner.swift:349）。
- 444／stale_timer／double_tap #4：offerArmed の3秒の時計・0.4秒未満の2回目の無視（WeekMainView.swift:928-938）は修正済みの記述どおり。
- lifecycle_audit #5／save_restore：chooseOffer は保存しない（GameSession.swift:463）・offerPick は @State で再開時に0へ戻る（WeekMainView.swift:150）。再開直後に選んでいた札が先頭に戻るだけで、効果は実際に押した札（`chooseOffer(index:)` が押下時に呼ばれる）が入る＝二重適用なし。
- 数字の表記：Yen.man（number_display_audit）。オファーの income は全て1万の倍数なので出ない。

## §3 問題なしの確認（観点別）

観点1（札の文と効果）
- 数値は GameConfig.swift:329-334 と tools/balance_sim.py:86-91 が4種とも同値（ひな壇 12万・知3・表現+2・体−15／ラジオ 10万・知2・表現+2・体−10／ロケ 22万・知2・体−25／営業 28万・知1・体−20）。
- 文（CommandData.swift:126-131）は数字を持たない。ロケ「くたびれる」（体−25＝最大）・営業「一番お金になる」（28万＝最大）・ラジオ「軽い」（体−10＝最小）は値と合う。食い違いは #1 の知名度の「顔が売れて」だけ。
- 札のピル・収入・体力の見積もりは previewState→applyOffer（GameSession.swift:476-479）で実際の受諾（WeekRunner.swift:349-352）と同じ関数・同じ atWeek を通る＝表示と確定が構造的に一致。

観点2（選び直し・見送り・復元）
- chooseOffer は `pendingOffer != nil` かつ添字が範囲内の時だけ pendingOffer を差し替え、乱数を触らない（WeekRunner.swift:482-485）。resolveAction が pendingOffer・offerChoices を空にする（:326-329）＝別の札が二重に入る経路なし。見送り（他の行動）でも空になり、次の週頭にも空（:197-198）。
- 週頭の `offerPick = 0`（WeekMainView.swift:336）・`indices.contains` の守り（:152）・`enumerated()` の描画（:890）で添字外なし。
- 復元：pendingOffer・offerChoices は名前で config から取り直す（WeekRunner.swift:696-707）。先頭札＝pendingOffer の関係は壊れない。extraOffers は (seed, 年, 週) だけで決まる別系統＝復元しても同じ札。
- 乱数：rollOffer は freeAction の前に1〜3回（1回→当たれば+2回）。療養週は引いてから捨てる（WeekRunner.swift:436-441）で Python（sim_career.py:1040→1049）と同じ順。chooseOffer・extraOffers・applyOffer は乱数を引かない。

観点3（拘束）
- 撮影の A は preoccupyNextWeek(1)（ChoiceEvent.swift:229・max で長い方を残す）。発火は週頭の freeAction だけ（GameSession.swift:589-653）＝大会週には立たない。解除は choose の末尾で毎回1減る（GameSession.swift:440）＝その週だけ。fastForwardToYearEnd も choose を通るので年をまたいで残らない。
- 稽古は三重に守られている：カード（WeekMainView.swift:917-918）・4ボタンの「出張中」判子（:986・:1048）・GameSession.choose の自動休養化（:385）。自動休養化は action を差し替えてから日程表・相方カウント・ネタの後段フックに渡すので、休みとして記録される。体調ダウンの抽選も `.train` でなくなるため引かれない＝Python（sim_career.py:1056-1057）と同じ順。
- 表示の言葉は「撮影」で一貫（トースト :925・:1009／カードの赤字 :1096／一言 WeekHint.swift:45／帯 :1618）。保存：イベント確定時に saveNow（GameSession.swift:817）・choiceApplied の間は保留イベントを保存しない（:1344）＝再開で二重に選べない。
- 設計メモ（問題ではない）：撮影の週でもオファー（営業など）は受けられる。意図かどうかは文書に無い。

観点4（テレビ慣れ）
- 判定は applyOffer 内で今週を数える前に行う（GameEngine.swift:204-208）＝Python do_offer（balance_sim.py:471-476）と同じ。窓は「今週−受けた週 < 6」・K=4・D=0.5（GameConfig.swift:340-342＝balance_sim.py:92-94）。表示用の `session.offerFatigued`（GameSession.swift:456）は同じ式・同じ通算週（(年−1)×48＋週）。「続けて受けると」の文（WeekMainView.swift:382）と判定は一致（ただし本編には出ない＝112）。offerWeeks は古いセーブでは nil→空扱い（GameEngine.swift:214）。

観点5（Python 正典との照合）
- roll_offer：発生率の帯・種類50/50（Python は rng.choice＝gen_golden.py:48 の min(int(r×2),1)＝u<0.5 が1つ目）・名前の追加1回・添字 (EXP:0/MONEY:2)+sub が Swift と一致（GameEngine.swift:218-227）。
- extraOffers：塩・年×1000+週・SplitMix64 の n 番目・`floor(u×残り数)` が Python と同式（sim_career.py:845-860）。FeatureGoldenTests.testExtraOffersGolden と gen_golden_features.py:129 が突き合わせ済み。
- 規律A 違反（式・乱数消費順の食い違い）は golden の経路には無し。計測条件の差は #2・#3・#4。
- テスト：オファー系は GameCore/Tests に多数（testRollOfferRateBandsAndKinds・testExtraOffersGolden・testChooseOfferSecondCardChangesAcceptedIncome・testOfferFatigue…）。今回 `swift test --filter` は実行したが、フィルタの書き方が合わず0件（回していない）。
