# コード点検 11/17（AbilityUpView・CommandData・Juice・NetaCatalog・読むだけ）

結論：落ちる穴・乱数消費・性別語・実名の問題は見つからなかった。新規の指摘は中1（ヒントが存在しない表示を説明）・低5・要確認3で、表示だけで直せる。
過去の点検（code_review_views_1116／misc5_1116／unreviewed_1115／2026-11-09）と重なる所は「既知」と書いた。

| # | 重さ | 場所 | 状態→結果 | 直し方の案 | 既知? |
|---|------|------|-----------|-----------|-------|
| 1 | 中 | AbilityUpView.swift:181（hintSpec）／:435（nextGrade） | ヒントに「『Fまで5』は、Fに上がるまでの残り」とあるが、その表示はこの画面のどこにも無い（nextGrade は定義だけで呼び出しゼロ）→初回の説明が存在しない物を指して混乱する | ヒントの「ランク」行を現状の表示に合わせて書き直す（または行にランクの残りを出す。後者は表示追加） | 新規 |
| 2 | 低 | AbilityUpView.swift:37（コメント）と :178 | コメントは「閃・語・間・存・胆」、画面の一字は種・帳・間・見・場（Theme.currencyChar）。ヒント文は「種・帳・間・見・場」で画面と合っている→コメントだけ古い | コメントを直す（動作影響なし） | 新規 |
| 3 | 低 | AbilityUpView.swift:468-469（confirm） | 視差を減らす設定でも confirmBump の1.35倍拡大は出る（plusTap は reduceMotion で bumped を止めているのに揃っていない）。:469 の easeOut も Theme.Motion.r を通していない（アニメ自体は Theme.Motion.r で消えるが :469 は消えない） | `confirmBump = !reduceMotion` 相当にし、:469 も Theme.Motion.r で包む | 新規 |
| 4 | 低 | AbilityUpView.swift:231-256（compareRow）・:259-275（matrixHeader）・:110・:261 | 見出し（「特技」「持ち分」「現在／アップ後」）に isHeader が無く、VoiceOver の見出し移動で飛べない。行の能力値（`Text("\(Int(v.rounded()))")` :310付近）は名前と別々に「12」とだけ読まれる | 「特技」に `.accessibilityAddTraits(.isHeader)`。行の値は `accessibilityLabel("\(a)の値 …")` で名前付きにする | 一部既知（views_1116 の経験点5列のみ。見出し・値は新規） |
| 5 | 低 | CommandData.swift:136（extraCards の fatigued 引数）・:125 のコメント | 「続けて受けて次に受けると腕が落ちる時は谷口の一言を足す」と書いてあるが、fatigued は使われず何も足さない→注意書きが出ない（引数だけ死んでいる） | 呼び出し側で別途出しているなら引数とコメントを消す。出していないなら desc に一言足す | 新規（要確認：呼び出し側で別表示なら問題なし） |
| 6 | 低 | CommandData.swift:126-133（offerBlurb） | オファー名が4種以外だと `default: return name` で、カードの題「オファー：X」と説明「X」が同じ文字になる | default を汎用文（「オファーを受ける」等）にする | 新規 |
| 7 | 低 | CommandData.swift:61-67 と AbilityUpView.swift:392-405（practiceLabel） | 練習の呼び名が2か所に別々に書いてある（現状は一致）。片方だけ直すと「どの練習で貯まる」の案内と実際のカード名がずれる | 呼び名を1か所の表（CommandCatalog）に寄せ、practiceLabel はそこを引く | 新規（保守のみ） |
| 8 | 低 | NetaCatalog.swift:90-101（names 50件） | 自動命名は id の周回なので、51本目以降は同じ題材名が重なる。「引っ越し」系が3件（引っ越しの日／引っ越し業者の見積もり／引っ越し先の隣人）、「免許」系が2件で偏る | 題材を足す・重複系を入れ替える（データのみ。id 周回の仕組みは unreviewed_1115 で安全確認済み） | 一部既知（周回の安全性のみ） |
| 9 | 要確認 | Juice.swift:211-218（ScreenFlash）／:106-109・:162-166（Task 取り消し）／:281-290（EdgePulse 並行） | Flash は opacity 代入と withAnimation(opacity=0) が同一トランザクションだと閃光が見えない可能性／粒と集中線の Task は未キャンセル（害は小さい）／EdgePulse の連続トリガーで2本のループが重なり明滅が乱れる | 実機の目視で確認。直すなら Flash は次のランループで 0 に戻す、EdgePulse は Task を保持して cancel | 既知（misc5_1116 低-1/低-3/要確認-1） |
| 10 | 要確認 | AbilityUpView.swift:23・ExpDisplay.value（:524 `Int(raw * 10 + 1e-6)`）・:236/:320 `Int(x.rounded())` | 値が NaN／無限大なら Int 変換で落ちる。現行の GameCore は有限値なので実際には起きない見込み | 防御するなら `raw.isFinite ? … : 0`。現状は不要かも | 新規（推測） |
| 11 | 要確認 | CommandData.swift:65・:66（「出演料を払って」「安い部屋を借りて」） | 説明文が費用を匂わせるが、config 側で cost=0 の練習だと「払う」と画面が食い違う。config を読んでいない | TrainingSpec.cost と説明文の突き合わせ（0の練習に「払って」が無いか） | 新規（推測） |
| 12 | 要確認 | NetaCatalog.swift:81-87（審査員7名）・:99「交番のお巡りさん」等 | 審査員名・題材とも架空の一般名詞に見えるが、7名の姓名が実在の芸人と重なるかは確認していない | 名前を検索で確認（重なれば変更） | 既知（unreviewed_1115 で名前の一致は確認済み・実在照合は未） |

## 確認済み（問題なし）
- 落ち：CommandData の `config.trainings[t]`／jobs／rests は guard＋compactMap、`restCosts[r] ?? 0`。NetaCatalog の autoKata/autoName は負 id でも `((id%n)+n)%n`、affinity は欠けると「○」。AbilityUpView の ForEach は固定列挙・`enumerated` の id は offset で添字外なし。nextPlusOne の `0..<n` は n≧1 想定（costOfNextStep が非 nil の時のみ）。
- 乱数：4ファイルとも GameCore の RandomSource を触らない（Juice は sin ハッシュの決定論、確定は session.allocate＝RNG 非消費）。
- 文と状況：「来年」「今年」等の時期語、「俺・僕」等の男性語は4ファイルに無し（comboKind 非依存の文言のみ）。
- セーブ→再開：能力アップの押した段 `taps` は画面内の @State で、保存・再開の対象ではない（閉じれば破棄＝「確定」まで決まらないとヒントにも明記）。ネタ名・型は id 由来の決定論で再開してもずれない。
- 動き：Juice の ParticleBurst／SpeedLines／Punch／Shake／Flash は reduceMotion を見ている（Flash は弱く短く、EdgePulse は逆に reduceMotion 時のみ）。Punch・plusTap は世代番号で連打の巻き込みを防止。確定は confirmFinished で反映1回（二度押し・自動閉じの重なりも対策済み）。
- VoiceOver：＋／−ボタンは「◯◯を上げる／元に戻す」＋ヒント、値札は「ネタ種 4、足りない」の形で裸の数字を読まない、飾り（Juice の Canvas・矢印）は accessibilityHidden。
- 実名：題材名は一般名詞のみ、実在大会名・実名の使用は4ファイルに無し（「GP」は一般表記）。
