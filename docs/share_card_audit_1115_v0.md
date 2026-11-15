# 共有カード点検（コード読みのみ）v0 — 2026-11-15

## 要点
- 件数：問題4件（高0・中1・低3）／問題なし8件。カードの文字は state の値と一致し、共有の文に実名・URL・【仮】は無い。
- 最も重い1件（中）：共有ボタンが画像の生成後に「ぽこっと」現れ、年末画面の下の帯の高さが変わる（YearResultView の再スタートボタンが動く）。
- 本体は ManzaiGame/Sources/ShareCard.swift（61行）。出口は YearResultView.swift:63 と EndingViews.swift:92 の2か所だけ（143 は既出＝最初の通過の出口なし・材料 docs/entry_share_research_1108_v0.md §3）。

## 問題
### 1. 【中】ボタンの出現で年末の下の帯が伸び、押す先が動く
- 場所：ShareCard.swift:44-54（image が nil の間は 1×1 の Color.clear）・YearResultView.swift:63-65（.padding(.vertical,6)＋背景の帯）
- 手順：優勝／決勝進出の年末を開く → ImageRenderer（.task・720×720@2x）の完了まで帯の高さは約13pt → 完了後に「共有」が出て約40pt に伸びる → その上に固定してある再スタートボタン（:66-69・「連打の空振り防止」で位置を揃えてある）が上へずれる。
- 直し：①ボタンの枠を最初から確保（nil の間は同じ高さの Label を .hidden() か .opacity(0)＋disabled で置く）②画像を待たずに ShareLink を出す（SharePreview を画像なしの文字だけにし、item は文字列）。推奨①。
- 同系：r.uiImage が nil だと（メモリ不足等）ボタンは永久に出ない＝黙って消える（:58）。実害は小さい。

### 2. 【低】夜逃げ・解散の年に「決勝進出」カードが出うる
- 場所：YearResultView.swift:62-64（条件は o.champion || o.reachedFinal のみ。bankrupt/dissolved を見ない）／出所 WeekRunner.swift:463・468（finalist を持ったまま bankrupt/dissolved の outcome）
- 手順：決勝に出た同じ年の年末までに所持金が尽きる（または相方とのすれ違いで解散）→ 判は「夜逃げ」「解散」(:184-185・:531-532)なのに、その下に「決勝進出／結成N年目」の共有が出る。事実としては誤りでないが、画面の主役と食い違う。
- 直し：①条件に !o.bankrupt && !o.dissolved を足して出さない（終わり方はエンディング側で共有できる）②今のまま。推奨①（判断はオーナー）。

### 3. 【低】共有後の画像は常に「優勝」「決勝進出」の固定文＝連覇の表記と年は出るが、優勝年と最終年の区別が無い
- 場所：YearResultView.swift:64・GameSession.swift:1162-1167（winHeadline）
- 内容：detail は「結成\(session.year)年目」だけ。最終年（careerYears）の優勝でも他の年でも同じ形。実在の値とは一致しているので誤りではなく、情報の足りなさだけ。直さなくてよい（提案：①今のまま）。

### 4. 【低】ボタンの文字が大きい文字設定に追従しない可能性／色の指定が無い
- 場所：ShareCard.swift:48（YoseFont.gothic(14, weight:.heavy)＝YoseFont の実装次第で Dynamic Type に追従する・未確認）／YearResultView.swift:63 側に foregroundStyle が無く、ラベルはシステムの既定の強調色（生成りの帯の上）。エンディング側は .foregroundStyle(kinari) で暗い地に合わせてある（EndingViews.swift:93）。
- 直し：①年末側にも .tint(YoseColor.shu)（WeekMainView.swift:821 と同じ流儀）②今のまま。画面での実見は未確認（シミュレータ不使用）。

## 問題なし（確認したこと）
- コンビ名：combiName をそのまま Text に渡す（ShareCard.swift:19）。上限は Names.maxLength=6 文字（Names.swift:13）・IntroFlow の入力欄は12文字で切る（IntroFlow.swift:531）→ 最大でも lineLimit(2)＋minimumScaleFactor(0.4) で収まる。絵文字・記号は serif のフォールバックで描画され、切れる心配は低い。DEBUG の MZ_COMBI は DEBUG のみ（GameSession.swift:228-230）で製品に入らない。
- 見出しと値：優勝＝winHeadline（連覇は yearHistory を新しい方から数える・今年を含む／yearend_audit_1115 §優勝の年と同じ結論）、決勝進出＝o.reachedFinal の非優勝年。year は runner.year で startNextYear（GameSession.swift:1185）前＝年末画面の数字と同じ。
- エンディング：headline＝ending.title、detail＝「No.N　種別」。session が nil の読み返し（図鑑）では出さない（EndingViews.swift:91）。夜逃げ「始発の駅」・解散「右と左」のカードも作れるが、題名と種別（バッド）だけで実名・金額は無い。
- 女性の形・相方名：カードに載るのはコンビ名と固定文のみ（name_substitution_audit_1115 §ShareCard と同じ）。
- 共有の文：ShareLink の message は固定の「漫才王になろう」、SharePreview は「コンビ名　見出し」（ShareCard.swift:46-47）。実在の名前・URL・【仮】は無い。カード下のタグも固定（:28）。
- 描画：ImageRenderer は 720×720 固定（:31）・scale 2・固定色（YoseColor）・システムフォントの固定ポイント＝暗い画面設定・大きい文字設定の影響を受けない（環境の色・文字サイズを読まない）。見出しは lineLimit(1)＋0.4 まで縮む（最長題名「十五冊目のノート」9文字でも 72pt×9=648 が幅 552 に縮んで収まる）。detail（:21）は lineLimit が無いが短い固定文。
- 再生成：.task(id: コンビ名|見出し|detail)（:55）＝値が変わった時だけ作り直す。取り消しは 364 の点検で確認済み（AUTOPILOT.md 364）。
- 共有を開いて閉じた後：ShareLink はシステムのシート＝アプリの状態を持たない。二度押しはシートが1枚なので増えない。閉じた後の画面は変わらない（@State は image だけ）。
- 色：カードは地が黒漆→臙脂のグラデ＋生成りの札で自己完結。画面側の暗さに依存しない。
