# コード点検 StageFrame／FinalsBroadcastIntro（読むだけ）2026-11-19

## 要点3行
- 対象は StageFrame.swift（舞台・開演の儀・看板類）と FinalsBroadcastIntro.swift（決勝導入・LIVE帯・扉・エンディング）。落ちる穴（添字外れ・NaN・ゼロ除算・強制アンラップ）は0件。待ちは全部「はやい」設定（MZSpeed.sleep）経由、視差を減らす設定も全アニメで尊重されている。
- 件数：高0／中2／低6／要確認2。規律Aに触る直しは0件（全部表示のみ）。
- 一番大きいのは #1（舞台の飾りの名札「俺」「谷口」が、本番・決勝・初舞台の3画面で VoiceOver に読まれる。StageFrame に `.accessibilityHidden(true)` を1行足すだけ）。

## 節構成
§1 指摘（#1〜#8）／§2 既出（重ねない）／§3 見て問題なしの所

## §1 指摘

### #1 【中】舞台の飾り（足元の名札「俺」「谷口」など）が VoiceOver で読まれる
- 場所：StageFrame.swift:25-51（body）の `duo()`→ StageFootTag（StageScene.swift:144-158 の `Text(name)`）。呼び元は FirstStageView:31・TournamentResultView:111・FinalsPresentationView:116。
- 何が起きるか：`.allowsHitTesting(false)` は「タップを通さない」だけで、読み上げからは外れない。Canvas・DustField は個別に hidden 済みだが、StageFootTag の Text は hidden でない。VoiceOver で送ると、本番画面ごとに「俺」「谷口」という意味のない2語で止まる（人形・マイクも要素として拾われうる）。
- 直し案（StageFrame.swift:50 の `.allowsHitTesting(false)` の次の行に追加）：
```swift
        .allowsHitTesting(false)
        .accessibilityHidden(true)   // 舞台は飾り＝読み上げ対象外（足元の名札「俺」「谷口」が読まれる）
```
- 表示のみ：はい。

### #2 【中】決勝導入のヘッダーが大きい文字で切れる（場面名が「…」・スキップが2行で潰れる）
- 場所：FinalsBroadcastIntro.swift:72-89（header）。フォントは最大1.35倍まで拡大する（Theme.swift:259）。
- 何が起きるか：横一列に「LIVE 生放送」札＋場面名（13pt、行制限1・縮小なし）＋「スキップ ▶▶」（12pt、高さ30固定）が並ぶ。最大拡大では合計が約410ptで、幅（約350pt）を超える。場面名「ファイナリスト集結」が「ファイナ…」に切れ、スキップや LIVE 札の字が2行に折れて高さ30の枠からはみ出す。同じ作りが FinalsLiveBar（:444-470）の `scene`／`trailing` にもある（こちらは高さ26固定・行制限1なので折れず、切れるだけ）。
- 直し案：
```swift
Text("LIVE 生放送")....fixedSize()                                   // :76 末尾に追加
Text(sceneTitle)....lineLimit(1).minimumScaleFactor(0.6)            // :81 に minimumScaleFactor を追加
Text("スキップ ▶▶")....lineLimit(1).fixedSize()                      // :84 に追加
```
- 表示のみ：はい。

### #3 【低】導入の見出し無し＋審査員席が「名字」「名前」と別々に読まれる
- 場所：FinalsBroadcastIntro.swift:90-97（sceneTitle に `.isHeader` なし）・:205-218（デスク名札は `parts[0]` と `parts[1]` を別 Text）・:230-240（木札）・:287（テロップ）。
- 何が起きるか：VoiceOver で場面名が見出しとして飛べない。審査員席では、7人分の名札が「音羽」「ルリ」と2語ずつ、さらに木札・テロップで同じ名前が重ねて読まれる（点灯前の席も全部読まれる点は既出＝§2 の finalists と同根）。
- 直し案：
```swift
Text(sceneTitle)....accessibilityAddTraits(.isHeader)                // :81 に追加
// デスク名札の VStack（:209-212）の後ろに
.accessibilityElement(children: .ignore).accessibilityLabel(on ? judges[i] : "未紹介の審査員")
```
  審査員席の木札（:230）は `.accessibilityHidden(true)`（テロップと重複するため）。
- 表示のみ：はい。

### #4 【低】審査員の木札の名前が、大きい文字・狭い端末で2行になり下にはみ出す
- 場所：FinalsBroadcastIntro.swift:234（`Text(judges[cur]).font(mincho(34))...tracking(2)`）と :246（枠の高さ110固定）。
- 何が起きるか：「神楽坂 とんぼ」「天堂寺 銀郎」は7字で、34pt×1.35＝約46pt/字＋字間2＝約330ptが要る。幅が約350pt以下の端末（SE 等）や最大拡大で2行に折れ、110ptの枠（上の「審査員」ラベル＋余白で実質70pt）を超えて下の要素に重なる。審査員席の全体高さ（100+140+12+66+26＋木札110）も固定で、小さい端末では余裕が薄い。
- 直し案（:234）：
```swift
Text(judges[cur]).font(YoseFont.mincho(34)).foregroundStyle(YoseColor.kinari).tracking(2).lineLimit(1).minimumScaleFactor(0.5)
```
- 表示のみ：はい。

### #5 【低】導入を素早く2回タップすると、場面を2つ飛ばす
- 場所：FinalsBroadcastIntro.swift:57（`onTapGesture { advanceStage() }`）・:360-368（advanceStage）。
- 何が起きるか：1回タップで stage が次へ変わり、2回目のタップ（ダブルタップ・連打）が直ちにその次へ進める。タイトルコール（ファンファーレの触覚＋「頂グランプリ」の看板）が一度も見えないまま審査員席まで行くことがある。1回で飛ばすのが仕様なので「連打すれば飛ぶ」自体は意図通り。ただし誤タップの二度押しでタイトルコールを見損なう。二重呼び出しによる壊れ（done 二重・finish 二重）は無い（既出の guard で止まる）。
- 直し案（任意）：場面が替わってから0.4秒はタップを受けない。
```swift
@State private var lastAdvance = Date.distantPast
private func advanceStage() {
    guard !done, Date().timeIntervalSince(lastAdvance) > 0.4 else { return }
    lastAdvance = Date()
    ...  // 以降は今のまま
}
```
  ただし自動進行（`advanceStage(from:)`）も同じ関数を通るので、`from:` 側は時間ガードを通さない形に分ける必要がある（`advanceStage()` のタップ専用ラッパーを足す）。
- 表示のみ：はい。

### #6 【低】エンディングの下三分テロップが折れる・点灯前の文字が読まれる
- 場所：FinalsBroadcastIntro.swift:589-592（`Text("「以上、頂グランプリ決勝でした。」")` に行制限・縮小なし、高さ44固定）・:565-580（step が進むまで opacity 0 の行）。
- 何が起きるか：(a) 16字・14ptは標準サイズでもテロップ幅（約230pt）ぎりぎりで、拡大すると3行になり高さ44の帯から出る（導入側の同じ帯 :294 は `lineLimit(1).minimumScaleFactor(0.6)` 済みで、ここだけ漏れ）。(b) 「今夜の頂 〇〇」「最終決戦…」「出場…」は透明なだけで読み上げ対象のままなので、VoiceOver だと開始直後に全部読まれる（VoiceOver 中は自動で閉じない作りなので支障は小さい）。
- 直し案：
```swift
Text("「以上、頂グランプリ決勝でした。」").font(YoseFont.mincho(14)).foregroundStyle(YoseColor.sumi).lineLimit(1).minimumScaleFactor(0.6)   // :590
```
- 表示のみ：はい。

### #7 【低】スキップボタンの押せる範囲が小さい（高さ28〜30pt）
- 場所：FinalsBroadcastIntro.swift:83-87（高さ30）・:596-599（高さ28）。
- 何が起きるか：Apple の目安44ptを下回り、押し損ねて背面のタップ（＝場面飛ばし・#5）に当たることがある。見た目の枠は変えずに押せる範囲だけ広げられる。
- 直し案：`.overlay(...)` の後ろに `.contentShape(Rectangle().inset(by: -8))` を追加（`.frame(minHeight: 44)` は見た目を変えるので避ける）。
- 表示のみ：はい。

### #8 【低】使われていない部品
- 場所：StageFrame.swift:380-391（`YoseAdvanceCue`・呼び出し0件）・:254-266（旧 `Telop`・呼び出し0件、`YTelop` に置き換え済み）。
- 何が起きるか：実害なし。残っていると、後で誰かが「視差を減らす設定」の確認対象として読む手間が増えるだけ。DEBUG 側の呼び出しは grep で見えなかったが、Xcode のプレビュー等での利用は未確認＝**要確認**。
- 直し案：消す前に、他の対象（テスト・プレビュー）で使われていないことを確認して削除。
- 表示のみ：はい。

## §2 既出（重ねない）
- 導入に `accessibilityAction` が無い・点灯前の10組と「あなた」が読まれる（code_review_misc3_1116 低-2）。
- finalistsView の最初の1フレームで7組が「on」（misc3 低-1＝済・advanceStage で step を同じ描画で戻す形が入っている）。
- 二重進行・キャンセル後の1回だけの処理（1108d・1108g＝済）。
- `.task(id:)` と `.onAppear` の実行順（2回目以降の vtr が短縮されるか）（misc3 要確認-1）。
- StageCeremony の seenKey を finish で立てる件・abandon／duck(1)（code_review_views_1116 #3・1116_night・10-19g＝済）。
- StageMakuri が1字ずつ読まれる件（views_1116 要確認A＝済・`.accessibilityElement(children: .ignore)` が入っている）。
- 縁取り Text 9枚の読み上げ（code_review_yose_store_1118）。
- accessibilityAction が onTapGesture と同じ関数を通るか（2026-10-27b＝候補ブランチ。StageFrame の StageCeremony はタップ専用のまま。1.5秒で自動終了するので支障は小さい）。

## §3 見て問題なしの所
- 添字：`judges[i]`（0..<7 固定）・`judges[min(step,7)-1]`（step≥1 を先に確認）・`parts[0]`（"名字 名前" の split で必ず1つ以上）・`finalists[i]`（0..<count）・`cols[i % 3]`／`[-30,...][i]`（i は 0..<4）。空の finalists・空の combiName でも落ちない。
- NaN／ゼロ除算：sparks の `truncatingRemainder(dividingBy: size.height + 20)` は常に正。audience の `size.width / CGFloat(row.n)` は n が定数。GeometryReader が0サイズでも while ループ（pleat 幅は正）は終わる。強制アンラップ・`!` は両ファイルに無い。
- 「はやい」設定：両ファイルの待ちは `pause`／`MZSpeed.sleep` のみ（Task.sleep・asyncAfter は0件）。
- 視差を減らす設定：StageCeremony（短縮・Theme.Motion.r）、導入の `.animation(reduceMotion ? nil : ...)`／`withAnimation(reduceMotion ? nil : ...)`、sparks の `paused: reduceMotion`、blink の繰り返しを止める、FinalsEntranceDoors・FinalsStudioLights・Ending すべて尊重済み。
- 二度呼び出し：StageCeremony の `finish`・導入の `finish`・Ending の `finish` は `done` ガード。導入の自動進行は `advanceStage(from:)` が `stage == s` を確認。
- 使われない状態：両ファイルの @State（stage／step／blink／slam／titleIn／lit／done／short）はいずれも読まれている。
- 文字サイズ：YoseFont は最大1.35倍で止まる（Theme.swift:259）。判断名札・finalists セル・テロップ（導入側）は行制限＋縮小済みで、#2・#4・#6 以外は崩れない見込み。
