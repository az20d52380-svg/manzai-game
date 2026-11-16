# 11/15 13:23〜21:28 の直し約11コミットの見直し（2026-11-16・読むだけ・コード未変更）

- 要点1：**重さ「高」「中」の回帰は見つからず**。前回（1115b）の高（ネタの伸びが消える）は 4a5aef29f で直っており、再発なし。指摘は低2件のみ。
- 要点2：最重要は低-1＝撮影・出張で拘束された週を一律「仕」にした 07a628ffe が、年末の行動内訳帯（S6）と日程表のトースト「仕事」にも波及する（拘束中にバイト／休養を選んでも仕事扱い）。表示のみ・セーブ互換は問題なし。
- 要点3：GameCore に触る 2f506d9cc（injuryProbability）・792a8c027（netaWork）は式・掛ける順・乱数消費とも従来どおりで、Python 正典（tools/gen_golden_features.py:59）とも一致。

節構成：§1 指摘（低-1／低-2）／§2 問題なしと確かめた点

## §1 指摘

### 低-1 拘束週を .offer に上書き＝年末の内訳帯と日程トーストも「仕事」になる
- コミット：07a628ffe（97718b6eb は目視フックのみ）
- 場所：ManzaiGame/Sources/GameSession.swift:393（`if state.preoccupiedWeeks > 0 { categoryLog[week] = .offer }`）。categoryLog の読み手は CalendarView.swift:103/118、YearResultView.swift:240（ActionBreakdownBand）、RadarChart.swift:147（色＝オファー金）。
- 手順：撮影のオファーを受ける → 拘束中の週にバイト（または休養・相方と過ごす）を選ぶ → 日程表は「仕」、第N週タップのトースト「第N週 仕事。」、年末の行動内訳帯もその週が金（オファー）になる。実際はバイト・休養をした週。
- 補足：稽古を選んだ週は choose 冒頭（:385）で休養へ差し替わるので、そこは「仕」でも筋が通る。ずれるのは拘束中に稽古以外を選んだ週だけ。体調ダウン週は pump 側（:1407）が .kaifuku で上書きするので正しい。
- 直し方の案：`if state.preoccupiedWeeks > 0, case .train = originalAction`（差し替え前の行動が稽古の時だけ .offer）にする。または拘束中でも行動どおりのカテゴリを残し、日程表の判子だけで拘束を出す。表示のみ・golden非対象。

### 低-2 共有ボタンの枠取りが、画像を作れなかった場合も残る
- コミット：2417d5fd2
- 場所：ManzaiGame/Sources/ShareCard.swift:49 付近（else 側に `Label("共有"…).hidden()`）。
- 手順：画像生成に失敗した／できない間は、共有が出ない代わりにボタン1つ分の空白が下に残る（以前は 1x1）。年末の下のボタンは動かない＝狙いどおりだが、失敗が続くと空白が出っぱなし。
- 直し方の案：生成に失敗した時（task が画像 nil のまま終わる場合）だけ枠を畳む。実害は小さいので直さなくてもよい。

## §2 問題なしと確かめた点

- 4a5aef29f（ネタの伸び）：lastNetaGain は pump 後の state で取る。pump の default 分岐（GameSession.swift:1497）が state = runner.state を入れるので applyNetaWork の結果を含む。大会週（pendingResult で break する weekDone）は choose の経路ではないので影響なし。
- 3f215eaa1（GP の知名度差）：advanceAuto は decideTournament（:372）と同じ形で pump 後に差を取る。guard で gpRound/gpRevival/gpFinal 以外は return するので前の大会の値を上書きしない。
- 95b99be7d：「この年をやめて」経路にも NetaStage.lastSeen のリセットを足しただけ。returnToTitle と同じ。
- 2f506d9cc：injuryProbability は `(閾値-体力)*毎点*喉ケア倍率*体が資本` の同じ順（Double の掛け算順も同じ）。WeekRunner.swift:341 の呼び出しの前後で nextUniform の呼び順は不変。Python（gen_golden_features.py:59）と同式。golden への影響なし。
- 792a8c027：netaWork は write（書く3種）／live（ネタ見せ会=hard・フリーライブ）／その他 nil。旧 applyNetaWork の guard・switch と対応が一致。`runner.lastTrainingDone == t` の guard は残っている。sim_career.py:683 の V2_WRITE_GAIN と netaPlaceGain は同値の系統（check_config_sync の対象内）。
- d465f1cbf：wornNow は StageOutfit.current を毎回引くだけ。所有・ガチャ状態の変化で再描画され、払い戻しで標準へ戻った時も札が追いつく。
- 6e8a8df04：年末の t14 判定は award が冪等で、解散・夜逃げの年末でも害なし。復元では yearHistory の guard とは別に走るが冪等。
- 81995776e：jobCount は「キツい」バイトで体調ダウンが付いた週だけ数えない（risky は .キツい のみ・WeekRunner.swift:337）。夜逃げで yearDone が先に来る週はこの判定が false になり数える（影響は極小）。引っ越し文言は canMoveRoom（roomRents[target] を持っているか）・「あと ¥n」の表示と一致。
- 7f2773b56：pulledID 中は知らせを止めるだけで、週が変わった後の `.onChange(of: session.week)`（WeekMainView.swift:338）の 2 秒後の呼び出しで出る。injuryNoticeWeeks は消費されるまで残るので、年末をまたいでも onAppear（:274）で拾える。
- 626b01d16：t21 の追加は champion の年だけ。優勝以外の年は GP決勝の敗退でも weekDone を経る（WeekRunner.swift:378/465/470 の yearDone は優勝・夜逃げ・解散）ので二重にならない。再入は `yearHistory.last?.year != runner.year` の guard の中で1回だけ。復元でも yearHistory に当年が入っているので再実行しない。決勝を除く点は判断待ち（trophy_meta #4）どおり。
- 旧セーブ互換：categoryLog は [Int: BandCategory]（.offer は既存の case）で Codable 変更なし。新しい保存項目なし。
- 表示のみの直し（e90447250 rosterSeed・42cc4291e/90768d5d2 S6b・2c01f5fd4 決勝の文言と無効・b5819050d ForEach の id・d7878b45f/aa7fa10ac 凡例・e2c16b1f0 名前確定）：rosterSeed は年が31離れない限り衝突せず、準決勝後の発表（year のみ）と別画面なので一致の要請もない。名前確定は値を押下時に取り、おまかせ・結成ボタンを decided で無効化。holdingSeventh は本番の溜め（:363〜419）で必ず false に戻る（"hold" の固定は DEBUG のフック専用）。

## §3 親の確認（11/16 定期）
- 低-1：直さない。07a628ffe は calendar_audit_1115 低-3 ②（週メインが「出張中」「今週は撮影」の週は日程表も「仕」）の意図どおりで、CalendarPreoccupied1115Tests が「拘束中はバイトを選んでも『仕』」をテストで固定している。直し案（稽古の週だけ「仕」）はその判断を覆すので入れない（試しに入れて戻した）。
- 低-2：直さない。ImageRenderer は固定の 720×720 の画面なので作れない場面がほぼ無く、空白が残るのは失敗が続いた時だけ。
