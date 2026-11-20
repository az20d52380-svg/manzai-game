# コード点検：StageScene／QualifierNoticeView／S6bView（11/19・読み取りのみ・コード不変）

## 要点3行
- 落ちる穴（添字外れ・ゼロ除算・強制アンラップ・NaN）は3ファイルとも無し。規律A（数式・乱数・GameConfig）に触る直しも無し。
- 一番大きいのは StageScene の読み上げ：壁のポスター「寄」「席」と足元の名札「俺」「谷口」が、飾りなのに VoiceOver に1字ずつ読まれる（呼び出し側3か所とも隠していない）。
- 他は、予選トークの新着が大きい文字で画面外に出る／最終興行画面がスクロールできない（要確認）／「▶」が読まれる、など。新規10件（高0・中2・要確認2・低6）。

節構成：§新規の指摘 #1〜#10／§既出として省いたもの／§問題なしと確認

## 新規の指摘

### #1 【中】StageScene の飾りが VoiceOver に読まれる
- 場所：StageScene.swift:92-96（posterCard の「寄」「席」）、:79-82（StageFootTag「俺」「谷口」）、:143-158。呼び出し：WeekMainView.swift:546、ChoiceEventOverlay.swift:359、StageViews.swift:129（どれも accessibilityHidden なし）。
- 何が起きるか：稽古場の背景なのに、「寄」「席」「俺」「谷口」が別々の読み上げ対象になる。画面の本題（ボタン・文）の前後に意味のない1字が混ざる。Canvas と DustField は隠してあるが、Text は隠れていない。
- 直し案：StageScene の body 全体に `.accessibilityHidden(true)`（または posterCard と StageFootTag の中だけ）。
- 表示のみ：はい。

### #2 【要確認】ManzaiFigure の呼吸が周期0で呼ばれる所
- 場所：StageScene.swift:230-235（`duration: breathe` の repeatForever）。呼び出し：GachaView.swift:201-202,249-250 が `breathe: 0`。
- 何が起きるか：周期0秒の繰り返しアニメ。止まるのか、毎フレーム回って電池を食うのか、実機で未確認。視差を減らす設定がオンなら開始しないので問題なし。
- 直し案：`guard !reduceMotion, breathe > 0 else { return }`。
- 表示のみ：はい。

### #3 【中】予選トークの新着が大きい文字で画面外に出る
- 場所：QualifierNoticeView.swift:167-177（chatScreen の ScrollView）。
- 何が起きるか：吹き出しは最大6個＋既読が下へ足されるだけで、最新へ送る処理が無い。文字を大きくした小さい画面では、結果の吹き出し（あった！等）が画面の下に隠れ、見えないまま「つづける」だけ出る。VoiceOver は読み上げで補える（:81-83）が、目で見る人は気づけない。
- 直し案：ScrollViewReader で `msgs`／`chosen` の変化時に最後の吹き出しへ `scrollTo`（reduceMotion なら動き無し）。
- 表示のみ：はい。

### #4 【低】見出しの印が無い
- 場所：QualifierNoticeView.swift:117-118（一覧の題「◯回戦 通過者」）、:166（トークの相方名）。S6bView.swift:70（千秋楽）、:192（年表）。
- 何が起きるか：VoiceOver の見出しジャンプで拾われない。
- 直し案：該当 Text に `.accessibilityAddTraits(.isHeader)`。
- 表示のみ：はい。

### #5 【低】予選通知の待ち時間だけ「はやい」設定が効かない
- 場所：QualifierNoticeView.swift:237,240,255,260（`Task.sleep`）。:223 だけ `MZSpeed.sleep`。
- 何が起きるか：最初の通知待ちは速くなるが、一覧の探す間（3.2秒）・トークの間は設定を無視して普通の速さ。
- 直し案：4か所を `MZSpeed.sleep` に揃える（意図的に固定なら理由をコメントに）。
- 表示のみ：はい（判定・乱数に無関係）。

### #6 【低】rowNames を何度も作り直している
- 場所：QualifierNoticeView.swift:34-41、使用 :123,:141。
- 何が起きるか：計算プロパティなので、画面が更新されるたびに名簿づくり＋並べ替えをやり直す。9組では無害。DEBUG の長い一覧（45組）でだけ少し重い。
- 直し案：`@State`／`let` に1回だけ作って持つ。
- 表示のみ：はい。

### #7 【要確認】最終興行の画面がスクロールできない
- 場所：S6bView.swift:56-138（kougyou が VStack＋Spacer のみ。ScrollView なし）。
- 何が起きるか：文字拡大の上限は1.35倍（mzScaled）だが、ビラ＋会場4段のタグ列（:84-90）＋所持金の枠＋ボタンを重ねるので、小さい画面（SE 級）では縦に収まらず、下の「最後の舞台へ上がる」が押せない、またはタグ列が横にはみ出す恐れ。実機で未確認。
- 直し案：年表（:195-198）と同じ `ViewThatFits(in: .vertical) { 本体; ScrollView { 本体 } }`。
- 表示のみ：はい。

### #8 【低】「▶」が読み上げられる
- 場所：S6bView.swift:86（会場タグの間の「▶」×3）、:128,13（ボタン文字の「▶」）。
- 何が起きるか：飾りの記号が「黒い右向き三角」と読まれる。
- 直し案：:86 は `.accessibilityHidden(true)`。ボタンは `.accessibilityLabel("最後の舞台へ上がる")`、finishLabel は表示用と読み用を分ける。
- 表示のみ：はい。

### #9 【低】「千 秋 楽」が1字ずつ読まれうる
- 場所：S6bView.swift:70。
- 何が起きるか：字の間に空白が入っているので、「せん」「あき」「らく」と切れて読まれる可能性。
- 直し案：`.accessibilityLabel("千秋楽")`。
- 表示のみ：はい。

### #10 【低】モンタージュの transition がコメントの中に入っている
- 場所：S6bView.swift:42（`// …合わない.transition(.opacity)`）。
- 何が起きるか：27b #5 と同じ型の書き損じ。ただし既定の切替がもともと不透明度なので、見た目は変わらない。
- 直し案：コメントを別行にして `.transition(.opacity)` を生かすか、削る。
- 表示のみ：はい。

## 既出として省いたもの
- QualifierNotice の `finish()` に二度押しの防止なし（1108c #3。呼び先の qualDone は同じ値代入で無害と判断済み・shopviews_1116）。
- 一覧をタップで進めた後にも3.2秒のタイマーで成功音が遅れて鳴る（shopviews_1116 :159/:240-243）。
- 一覧の「次へ」操作が要素でない container に付いている（shopviews_1116 確認-3）。
- S6b 年表の「タップで進む」の読み上げ・透明ボタン（note_end_1117）。S6b の kougyouOnly の二度押しは go() が同じ値で無害（19i）。
- 演出ひかえめ時の残金の間（26f #1）、「タップで進む」の余白（27b #5）は直り済み。

## 問題なしと確認
- 添字・割り算：StageScene の `period`＝高さ+40÷速度（9以上）で正、`size.height` は GeometryReader 由来。QualifierNotice の `resultLines[n-3]` は範囲チェックあり、`ForEach(0..<max(0, msgs-2))` も `i < count` あり。S6b の `venueNames[venueTier]` は 0〜3 に収まる。強制アンラップ無し。
- 視差を減らす：3ファイルとも withAnimation／DustField／呼吸は reduceMotion を見ている（#2 の周期0を除く）。
- 使われない状態：無し（`counted`・`burned`・`finished`・`scanned`・`chosenText` はすべて使用）。
- 規律A：該当する提案なし（venueTier は GameConfig を読むだけ）。
