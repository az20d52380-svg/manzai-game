# GameSession.swift 変更点検（11/12〜11/18・約23コミット）v0

読むだけの点検（編集・コミット・ビルドなし）。行番号は 11/18 時点の `ManzaiGame/Sources/GameSession.swift`。
結論：高 0／中 1／低 4／要確認 2（計 7）。乱数の消費順が golden に響く変更は無し（唯一 #7 が UI 乱数のみ）。式・GameConfig に触る直しは無し。

## 指摘

### 1. 【中】結果画面の「知名度 +n」札の値が、別経路で出た結果では前の大会の値のままセーブ・復元される（要確認）
- 場所：lastResultFameDelta の更新は :382（decideTournament）と :1005（resolveAuto）だけ。保存 :1382-1383、復元 :346-351（e6f02bb36）。
- 何が起きるか：pendingResult は pump（:1435 付近）が weekDone の大会結果から作る。acknowledgeResult（:1011-1016）→ `runner.begin()` → pump の経路や choose → pump の経路で結果が出ると、lastResultFameDelta は更新されず前の大会の値が残る。e6f02bb36 以降はこの古い値が resultFameDelta としてセーブに載り、再開後の結果画面に別大会の「+n」が出る（以前はメモリ上だけの古さだった）。具体例：第12週で +10 → 結果を閉じる → 次の結果が decideTournament を通らず出た週に中断 → 再開で +10 が出る。
- 直し案：pump で pendingResult を作る箇所（:1435 付近）で `lastResultFameDelta = summary.state.fame - fameBefore` に相当する値を必ず更新する、または pendingResult を作る時にいったん 0 に戻して decideTournament/resolveAuto 側で上書きする。
- 表示のみで直せる／規律A：触らない。
- 要確認の理由：decideTournament・resolveAuto を通らずに stage 結果が出る週が実際にあるか（女性コンビの HANA 自動段など）は GameCore 側で未確認。

### 2. 【低】旧セーブ（11/15 以前）で年初の知らせが 1 回だけ再表示される
- 場所：:352-353（`save.youthNoticeYear ?? 0`）、WeekMainView.swift:1535 / :1547。
- 何が起きるか：年初（week<=1）に知らせを出した後で中断した旧セーブは nil→0 になり、再開時に同じ年の知らせがもう一度出る。以後は保存される。
- 直し案：許容（1 回限り・害なし）。直すなら復元時に「week>1 なら year を入れる」。
- 表示のみ／規律A：触らない。

### 3. 【要確認】夜逃げ・解散・優勝の年末で onStage に渡す state が「週末処理後」で、体力・借金の称号 t15/t16 が甘くなる
- 場所：:1478 付近（6c137f431）と :1485-1491（626b01d16）。onStage の仕様は Meta.swift:162「state は週末処理後」。
- 何が起きるか：weekDone 経由は summary.state（その結果の時点）を渡すが、ここは runner.state（週の最後）を渡す。夜逃げの週は money<0 が必ず成り立つので、同じ週に GP を通過していれば t16（借金で通過）が付く。優勝の週は敗者復活の通過の判定に決勝後の体力が使われ、t15（体力<30 で通過）が付きやすい。
- 直し案：どちらを意図とするか決める。意図が「その時点」なら、WeekResults と一緒に通過直後の state を持たせる（GameCore 変更が要る）。意図が今のままなら、コメントにその旨を書くだけ。
- 称号の判定のみ（メタ）／規律A：触らない。

### 4. 【低】上の onStage 追加呼びで smallEntered/smallWon が増えず、しかも onYearEnd が先に走る
- 場所：:1425-1429（onYearEnd→smallEntered リセット）と :1478・:1487。
- 何が起きるか：weekDone 経由なら smallTournamentCount で数えるが、yearDone 経由の追加呼びは数えない。夜逃げ・解散の週に出た道中大会（HANA 以外）は六冠の数に入らない。優勝年は最終週が GP のみなので影響なし。
- 直し案：夜逃げ・解散の年は六冠にならないので放置で足りる。直すなら onYearEnd の前に集計する。
- 表示・称号のみ／規律A：触らない。

### 5. 【低】「体調ダウン」の文字列比較が増えた（バイト回数の判定）
- 場所：:410-413 付近（81995776e）、pump :1423、:1419。
- 何が起きるか：結果の名前が変わると jobCount が再び倒れた週を数える。現状は正しく動く。
- 直し案：StageResult か WeekSummary に「倒れた」フラグを持たせる（GameCore 変更）か、定数化。
- 規律A：触らない（式・乱数ではない）。

### 6. 【要確認】拘束週の判子「仕」が稽古以外の行動（バイト・休み）にも付く
- 場所：:403（07a628ffe）。稽古だけ休みに差し替える :395 とは条件が違う。
- 何が起きるか：撮影・出張で拘束中にバイトや休みを選んでも日程表は「仕」になる。意図が「拘束された週」ならそのままで良いが、「稽古が潰された週」なら稽古を選んだ時だけが正しい。
- 直し案：意図確認。稽古のみなら `if state.preoccupiedWeeks > 0, case .train = originalAction`。
- 表示のみ／規律A：触らない。

### 7. 【低】復元時の weekDone フォールバックで pump() を init の中から呼び、UI 乱数を消費する
- 場所：:355-359（4b8e8f72d）。
- 何が起きるか：pump の既定分岐が evaluateChoiceEventFire を呼び、uiEventRng が進む。復元経路の一部（結果が空で捨てられた weekDone）だけ。UI 乱数列なので golden は動かない。再開後のイベント抽選がずれるが、壊れたセーブの救済経路のみで実害なし。
- 直し案：許容。
- 規律A：触らない（UI 乱数のみ）。

## 点検して問題なしと判断したもの
- 792a8c027：`netaWork(for:)` は旧分岐と同じ対応（書く＝ネタ作り・喫茶店・ファミレス／披露＝ネタ見せ会 hard・フリーライブ）。placeGain も同じ。
- 6e8a8df04：年末の t14 は award が冪等で、pump 再入でも二重に付かない。
- 35c0b93fc→d35d69f34：差し引き 0（Names.set は元の形に戻っている）。
- 07afdcda7・67de2f056・f3240e4ad・e6f02bb36：SaveData の新規項目はすべて Optional＋`?? 既定`。SaveDataConventionTests の規約どおり。旧セーブは読める。
- 2d28e31e7：startNextYear で inviteWaiting を落とす。inviteIdea は残るが、保存は pendingChoiceEvent==.weekendInvite か inviteWaiting の時だけなので無害。
- 4f0ea4e7d：eve 除外は hanaTournaments.first の週（32）で、他の大会の週と重ならない（Calendar.swift で確認）。
- 16a3b95f3／4a5aef29f：押した週の末の state（summary.state）を使うのは能力・通貨・金・体力・知名度、ネタだけ現 state。applyNetaWork は netas のみを変えるので整合。
- 結成15年（careerYears）・最終年の境界：今回の diff で触っていない。既知 230（10 年目で中断した旧セーブが 11 年目へ続く）はそのまま。
- DEBUG フック（c22b0e54b・652719e1d・a684ef8de）は DEBUG のみ。早送りは年が進まなければ return する。

## 既知（重複させない）
- docs/AUTOPILOT.md 230（結成 15 年に延びた旧セーブの扱い）。
- docs/save_compat_audit_1108_v0.md の「保存 enum の未知 case でセーブ全体が失敗」「.broken の戻し処理なし」。今回の diff で悪化した点はなし。
- AUTOPILOT 653 は該当行の内容と照合できず（grep で見つからず）。
