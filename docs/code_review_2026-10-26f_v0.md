# 今日のアプリ変更の点検（code_review_2026-10-26f）

## §1 まとめ
- 見た範囲：655edd4~1..HEAD の Sources 9ファイル（8コミット・差分342行）。コードは変更していない。
- 指摘は3件：高0・中1・低2。落ちる／進めない／データが壊れる不具合は見つからず。
- 読み上げの修飾子（.accessibilityElement(children: .ignore)・空の hint）は意図どおり。DEBUG 専用コードの漏れなし。
- 一番重いのは中1件：S6bView の演出ひかえめで「元の残金を一拍見せる」間が消える。

## §2 指摘
| # | 重さ | 場所 | 何が | 直し方の案 |
|---|---|---|---|---|
| 1 | 中（推測：実機未確認） | S6bView.swift:132（kougyou の onAppear） | 演出ひかえめ時は withAnimation(nil) で counted=true が表示直後に入り、残金が最初から0円で出る。直前のコメントが避けた「0円なのにドーム」の見え方に戻る（元の額が読めない） | reduceMotion の時は counted を onAppear で動かさず、残金を元の額のまま見せて「最後の舞台へ」で進む／または 1.0秒の待ちだけ残して数字を即時にする（DispatchQueue/Task で遅延） |
| 2 | 低 | WeekMainView.swift:614 banterBox の onTapGesture | withAnimation(.easeOut(duration: 0.18)) が reduceMotion の分岐を通っていない（今回の「演出ひかえめ」対応から漏れ）。0.18秒の淡い切替で影響は小さい | reduceMotion を読み、true の時は withAnimation(nil) |
| 3 | 低（推測） | WeekMainView.swift:615-617 | .isButton と hint を YoseSpeechBox の外側（.id・contentShape 後）に付けている。中の要素が個別に読まれる作りだと、ボタン扱いが外枠だけになり hint が読まれない可能性。実機の VoiceOver で未確認。最終行は hint が空文字で問題なし | 実機で確認。ずれるなら .accessibilityElement(children: .combine) を先に付ける |

## 問題なしと確認した点
- RadarChart：中身は Canvas 1枚でボタン無し＝children: .ignore で押せなくなる物は無い。onAppear の分岐（animate && !reduceMotion、else progress=1）は取り違えなし。
- ActionBreakdownBand／S6bView 画面切替・焼き付き：reduceMotion ? nil の向きは正しい（ひかえめで即時）。
- .accessibilityHidden(true) の4か所：横の Text が残るので読み上げは欠けない。
- GameSession：観戦ログの週を gpFinalWeek に固定。観戦は week == gpFinalWeek の時だけ入れる（987行）ので、通常経路は不変。二度押しは watchingFinal で守られている。
- debugSeedKirokuLog は #if DEBUG（1373-1665）内、呼び出し側 RootView も DEBUG 内。本番への漏れなし。
- DialogueData の「しばらく本番なし」：.lull は次の山まで6週以上（GameSession:637）。文と条件が合う。
- YearResultView／WeekMainView の static 切り出し：中身は同じ式でそのまま移されている（比較演算・文言の食い違いなし）。

## §3 見たコミット
0452997 観戦の決勝の出来事の行を決勝の週で記録／f6dea94 週頭の掛け合い lull の文言／c9c6e7e 決勝の週の食い違い（見本の週）／60f4bd2 掛け合いの読み上げ／8f9e489 年末の能力の図の読み上げ／149a4d1 ボタンの飾り記号を読み上げから外す／d889403 演出ひかえめ（年末の最終興行・図・帯）／655edd4 アプリのテスト追加（Sources は static 切り出しのみ）
