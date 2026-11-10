# 候補ブランチ4本のコードレビュー（読むだけ・2026-11-10夜）v0

対象：final-year-notice-cand / gate-stamina-mono-cand / gate-stamina-strong-cand / yearstart-notice-after-event-cand（本体 origin/claude/manzai-slg-foundation-wprqlu との差分）。
行番号は本体側（候補の差分適用前）のもの。コードは直していない。

## §0 総評
- 致命的（セーブ破損・判定変更・DEBUG漏れ）は無し。判定・数式は触っていない。
- 4（after-event）は MZ_EVCLOSE が `#if DEBUG` 〜 `#endif` の内側＝DEBUG 以外への漏れ無し。
- 重いのは「1 を単独で入れると、年初にイベントが出る年は最終年の一言が一度も見えない」点。4 と一緒に入れて、1 にも同じ待ちを付ければ解消。

## §1 final-year-notice-cand
### 1-1 【中】年初にイベントが立つ年は、一言が出ずに「出した扱い」になる
- WeekMainView.swift 差分の maybeShowFinalYearNotice（本体 1507 付近に追加）、onAppear 行(266)・onChange(of: session.year) 行(319)
- 選択イベントは fullScreenCover（175–176 行）。toast は下の週メイン側＝覆いの下で出て消える。ガードに pendingChoiceEvent / showEvent が無いまま finalYearNoticeYear = year を先に立てるので、その年は二度と出ない。onChange(of: pendingChoiceEvent) の nil 側からも呼ばれない。
- 直し案：4 と同じ `session.pendingChoiceEvent == nil, !showEvent` を guard に足し、4 の nil 側（264 行）に maybeShowFinalYearNotice() を追加。

### 1-2 【中】4 と同時に入れると onChange(of: session.year) の行で衝突
- 1 は `maybeShowTiredNotice(); maybeShowLastYouthNotice(); maybeShowFinalYearNotice()`、4 は Task＋0.7秒待ちに書き換え＝同じ 1 行を両方が変更。機械的マージでは衝突する。
- 直し案：4 の `Task { sleep 0.7; tired; youth; final }` に1を合流。マージ順は 4 → 1 が楽。

### 1-3 【低】待っている間の再確認が無い
- 1507 付近 `if toast != nil { sleep 4.5s }` の後に showToast。待ち中にイベントが開く／別の toast（vessel 満了など）が入ると、上書きされるか覆いの下で出る。既存の youth と同じ作り（新規の悪化ではない）。
- 直し案：待った後にもう一度イベント有無を見る。

### 1-4 【低】表示時間が境界ぎりぎり
- 文は「谷口「結成して10年目か。今年の年末で、ひと区切りだね」」＝30字。.task(id: toast)（325 行）は `count > 30` で 4.5 秒、30 以下は 2.6 秒。careerYears が1桁なら29字。読むのに2.6秒は短め（推測：体感の話）。
- 直し案：句読点を1字足して31字にするか、閾値を >= 30 に。

### 1-5 【低】View 作り直しで再表示（推測）
- finalYearNoticeYear は @State。WeekMainView が第1週に作り直されれば再び出る（tired/youth も同じ性質で既存どおり）。

## §2 gate-stamina-mono-cand
### 2-1 【中】閾値が session.config ではなく GameConfig() の既定値
- DialogueData.swift 差分の `state.stamina < GameConfig().staminaGate`（本体 47 行付近）。WeekMainView（899・964 行）は session.config.staminaGate。config を変える設定（難易度・テスト用）があると、グレー表示と独白が食い違う。現在 staminaGate=20（GameCore/GameConfig.swift:260）で、既定のままなら実害なし。
- 直し案：innerVoice に gate を引数で渡す（既定値つき）。

### 2-2 【低】直近避けの記録と表示がずれる
- pick は元の番号を usedPicks に記録するが、画面に出すのは「次の行」。次の週に記録外の「次の行」が選ばれると近い週に同じ文が2回出うる。「階段を上がるだけで…」の確率が約2倍（2/37）。
- 直し案：置換でなく、稽古の行を除いた配列から picker で選ぶ（3 の方式に近い）。

### 2-3 【低】`line.contains("稽古")` と1つ先の行
- 将来 lowStamina に「稽古」を含む行が並んで増えると、次の行も稽古の行になりうる（cascade 未対応）。現状は稽古の行は1本だけ（100 行）で問題なし。
- 直し案：ループで稽古を含まない行まで進める。

### 2-4 【低】体力 20 以上でも練習が押せない週がある
- 899・964 行は `stamina < gate || preoccupiedWeeks > 0` でグレー。2 は体力だけを見るので、preoccupiedWeeks>0 かつ体力20〜24 の週は稽古の行が残る（独白は変わらない＝今まで通り）。
- 境界：体力ちょうど 20 は not gated（WeekRunner.swift:332 も `<`）で一致。20〜24 は稽古の行が残る＝練習が押せるので問題なし。体力は Double：19.6 は帯の表示（四捨五入）が 20 でも gated。推測：見た目と1ずれる程度。

## §3 gate-stamina-strong-cand（2 の上）
### 3-1 【中】2 と 3 は排他（同じ箇所を直す）
- 3 は 2 を含む（DialogueData.swift・テスト・pbxproj が両方に載る）。両方をマージすると衝突する。3 だけを取れば足りる。

### 3-2 【低】3 を入れると 2 の置換ロジックは到達不能
- 先に `stamina < staminaGate` で return するので、続く `<25` 内の `if state.stamina < GameConfig().staminaGate, line.contains("稽古")…` は死んだコード。2-1（GameConfig()）は gated 側の判定1箇所に残る。
- 直し案：3 を採るなら 25 内の置換は消す。

### 3-3 【低】10 行は重複と偏り
- lowStaminaGated は lowStamina から手でコピーした10行（同じ文のまま2か所にある＝片方を直すと食い違う）。休演の週は 37 行→10 行で、長いキャリアほど同じ行が戻りやすい（直近避けは scene 別 "mono.lowStaminaGated" で動くので連続は避けられる）。
- 直し案：lowStamina 内で印を付けて filter する／別配列の行は lowStamina から外す。
- 注意：10行のうち「疲れが抜けてない。稽古は軽めに…」は含まれず、休む文だけ＝意図通り。「今日は家にいよう」「早く帰ろう」など1日の話も混じるが本体にも既にある文。

### 3-4 【低】古いセーブの usedPicks
- scene 名が新規（mono.lowStaminaGated）。旧セーブでは未使用で始まる＝問題なし。lowStamina 側の記録は gated の週に進まなくなる（意図通り）。

## §4 yearstart-notice-after-event-cand
### 4-1 【中】満了 toast が、年初と無関係な event 閉じ後にも出うる（推測）
- 264 行の nil 側に maybeShowVesselFullToast(vesselIsFull) を追加。本体では onChange(of: vesselIsFull)（331 行）の変化時だけだった。vesselFullToastShown は @State で、本体の grep では true にする箇所（1520）以外にリセットが無い（コメントの「この年1回」と異なり、View 寿命に1回）。
- WeekMainView が作り直されて（大会系画面から戻った等）その flag が false に戻り、器が満了のままなら、年の途中のイベントを閉じるたびに「今年の実力の伸びは、ここまで。」が再び出うる。View が作り直されるかは未確認（推測）。
- 直し案：nil 側の呼び出しを `session.week <= 1` 限定にする／flag を年ごとに持つ（vesselToastYear）。

### 4-2 【低】nil 側で toast を3本同時に出し、上書きで消える
- 264 行：tired → youth → vessel を同じ瞬間に呼ぶ。showToast は代入のみ（1428）＝vessel が成立すると tired の toast は同フレームで上書きされ見えない（tired は「出した扱い」）。youth は4.5秒待つ Task なので無事。年初に vessel が満了なのは稀（成長予算は年で戻る）なので低。
- 直し案：youth と同じく、toast != nil なら待つ。

### 4-3 【低】maybeShowFirstHints との順番
- 同じ nil 側で toast を出した直後に maybeShowFirstHints()。その guard に `toast == nil`（1483）があり、初年度の生活費ヒントが見送られる（再試行無し）。tired は year>=2 なので影響は youth の cap が1年目の時と vessel のみ。実害は小。

### 4-4 【低】イベント以外の覆い（rent / burstHold / pulledID）は未対策
- 追加した guard は pendingChoiceEvent と showEvent のみ。rent（生活費の覆い）等の下で出る経路は本体のまま。本体の他の知らせは `rent == nil, !burstHold` も見ている（1445）。

### 4-5 【低】0.7秒待ち
- onChange(of: year) 側を Task＋0.7秒にした。待っている間に View が消えても Task は走る（結果は guard でほぼ無害）。年初のイベントが 0.7 秒後までに立つ前提（推測：獲得の一拍 burstHold が長いと立つのが遅れる→ guard の !showEvent では burstHold 中は showEvent=false のまま・pendingChoiceEvent != nil で弾けるので OK）。week<=1 は、イベントを閉じても週は進まない（dismissChoiceEvent は pendingChoiceEvent=nil＋保存のみ・790 行）ので満たされ続ける。
- 中断セーブ復帰：pending 付きで復帰→ onAppear は skip → 閉じた時の nil 側で出る。二重出し無し（tired/youth はフラグを先に立てる）。イベントが2つ続く場合も、2つ目が立てば1つ目の nil 側は guard で skip、最後の nil 側で出る。

### 4-6 【低】MZ_EVCLOSE
- ChoiceEventOverlay.swift 差分は `#if DEBUG`（112）〜`#endif`（118）の内側＝漏れ無し。ただし Task は取り消されず、手でイベントを先に閉じた後に秒数が来ると、次に立ったイベントを dismissChoiceEvent() で消す。onClose() とも二重。DEBUG のみ。

## §5 4本一緒に入れた時
- 衝突：1×4（onChange(of: year) 行）、2×3（DialogueData.swift 等）、2・3 のテストファイルと pbxproj（同名ファイル追加）。
- 推奨の組み合わせ：3（2 は入れない）＋ 4 ＋ 1（1 に 4 と同じ guard と nil 側呼び出しを足す）。4-1 は week<=1 限定にして入れる。
- 直近避け（usedPicks）：1 と 4 は文を選ばないので無関係。2 は §2-2、3 は別 scene で安全。
- debtNotice：toast は debt の覆い（213 行）より後ろで描かれる（235 行）ので重なって見える可能性。4 の nil 側で toast が出た直後に debt の覆いが立つと重なる（推測）。
