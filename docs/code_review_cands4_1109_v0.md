# 候補4本の点検（2026-11-09・読み取りのみ・ビルド/実機は未実施）

**要約**：落ちる所・セーブ非互換・乱数/golden への影響は4本とも無し（GameCore は触っていない。ガチャの抽選乱数は SystemRandomNumberGenerator のまま・消費順も不変）。
重い所は「寄席の音」＝優勝演出の画面は音を鳴らさない決まり（TournamentResultView:178 のコメント）なのに親が鳴らす fanfare に、新しい太鼓・金の音が重なる点（中）。他は低。
件数：高 0／中 2／低 5。

## 候補ごとの結論
- a11y-tap-next-cand（3コミット・12ファイル）：ロジック不変。#1 の抜け＝二度押しで進む操作。
- burst-cost-scaled-cand（1コミット）：表示位置のみ。
- gacha-paid-first-cand（1コミット）：セーブの形式は不変（paidOpened の数え方だけ）。テスト1本あり。
- yose-sound-wire-cand（1コミット）：音の口を既存 SE に当てただけ。

## 指摘表
| # | 候補 | ファイル:行 | 何が起きるか（入力→結果） | 重さ | 直す案 |
|---|---|---|---|---|---|
| 1 | yose-sound-wire | Design/YoseEffects.swift:48（map）／TournamentResultView:178・FinalsPresentationView:1144 | 優勝演出の画面が出ると、親の Sound.play(.fanfare)+.cheerBig に、演出側 championImpact→taiko（開始）・prizeGet→money（1.15s 後）が重なる。TournamentResultView:178 のコメント「優勝演出の画面は音を鳴らさない」と食い違う。耳での確認は未（キュー158 も「耳で未」） | 中 | 実機で聞いて、重なりが濁るなら championImpact だけ外す／コメントを更新。ファンファーレ側を外す案もあるが親の決定が先 |
| 2 | yose-sound-wire | Design/YoseEffects.swift:494（YoseStampImpactModifier）・YoseYearTurnCurtain:241・RentStatement:107・YoseRankUpOverlay:218 | stampHeavy→don は優勝演出以外の押印にも効く。年越しの幕・ランクアップの判は今まで無音だったが don が鳴る（意図は未確認）。家賃の精算は直前に Sound.play(.money) があり（RentStatement:135）、続けて settled の判で don＝音が連続する（0.5s 後・未確認） | 中 | 優勝演出限定でよいなら、map ではなく YoseChampionCelebrationView 側で直接 Sound.play（口は未接続のまま）。全押印で良いかをオーナーに |
| 3 | yose-sound-wire | YoseEffects.swift:46-47 | onPlaySound の既定値を入れたので、他で nil 代入/上書きした所があると効かない（grep では他に代入なし）。map は呼ぶたび辞書を作る（軽微）。単体テスト無し。.prizeGet→money は金額が無い（0円）画面でも鳴る可能性（未確認） | 低 | map を static let に。口→SE の対応表のテストを1本 |
| 4 | a11y-tap-next | 各ビュー（FinalistAnnounceView:111 他・11画面） | 監査 #1 の案は `.accessibilityAction(named: "次へ")`、候補は名前なしの既定アクション。VoiceOver が全体を1要素に束ねていない画面（子の Text が個別に読まれる所）では、既定アクションが空の容器に付いて二度押しで効かない恐れ（FinalsBroadcastIntro など。実機未確認＝コミット文にも「実機で確かめてから」とある）。名前なしだと回転子にも出ない | 中 | 実機 VoiceOver で、全画面を「二度押しで進むか」確認。効かない画面は `.accessibilityElement(children: .combine)` を足すか named: "次へ" に。最後の1枚だけ「閉じる」にするかは監査の判断待ち |
| 5 | a11y-tap-next | CharacterAvatars.swift:79 | CharacterFace 全体を読み上げから外した。FinalsBroadcastIntro:185 の審査員の席札（点灯/消灯で明暗が変わる）は顔だけが状態を示すなら情報が消える（隣に名前の札があるかは未確認）。ComboKindPickerView・TalkParts は文字の札が別にあり問題なし | 低 | FinalsBroadcastIntro の審査員席に点灯状態の label があるか確認（無ければ足す） |
| 6 | a11y-tap-next | TournamentResultView.swift:652（climaxNext）ほか | タップと accessibilityAction が同じ関数を呼ぶので、最後の1枚で acknowledgeResult を二重に呼ぶ経路は無い（別々の入力）。ただし isLast/i をクロージャに値で持つため、i が進んだ後の古いクロージャは出ない（transition 中の再入は未確認） | 低 | 実機確認のみ |
| 7 | burst-cost-scaled | WeekMainView.swift:1378 | 札を botbar の高さ0の目印の overlay に移した。zIndex(1) は botbar 内だけなので、botbar より後ろに描かれる兄弟（週のメインの上に重なる札・吹き出し）に札が隠れる可能性（未確認）。以前は全体の overlay で RentStatement 等の上にも出た（今は下になる＝出ない方が良い）。札に accessibilityLabel 無し（体力の減りは読まれない。キュー137 の範囲外） | 低 | 大きい文字と通常の両方で目視（visual_largetext の再撮影）。必要なら札に label |
| 8 | gacha-paid-first | GachaView.swift:152（.free）／GachaState.swift:106 | 無料で回す（.free）は preferPaid 無しなので、無料券 0 かつ未開封あり、の時は未開封から開く（ボタンは freeTickets==0 で disabled なので UI からは出ない）。買った後の pull(count:) は availableTickets>0 判定のまま＝購入が失敗してもエラーにならず無料券分が回る経路は元からのもの（変更なし） | 低 | 現状で可。テストは「無料券1+購入10→購入から10回、無料券1残る」と既定の1本のみ＝preferPaid で paidPending が足りない境界（購入1回＋古い未開封で count が上回る）が未テスト |

## 抜けのまとめ
- テスト：a11y・burst・yose は表示/音のためテスト無し（妥当）。ガチャは上の境界1本が未。
- セーブ：どの候補も Codable の鍵は不変。
- 乱数・golden：GameCore 差分なし。ガチャの draw 呼び順も不変（preferPaid は消費する券の種類を変えるだけ）。
- 背景：AUTOPILOT 229（ガチャ案②）・137（体力の札）・158（音②）・voiceover_audit_1109_v0 #1〜#14。

## 親の照合（11/09 定期）
- #1 確認：TournamentResultView:178 のコメント「優勝演出の画面は音を鳴らさない」と、候補が演出の画面に足す音が重なる＝キュー158（寄席の音をつなぐか）の判断と一緒に決める。つなぐ場合は親の fanfare+cheerBig を外すか、演出側の優勝の3音を外すかの2択。
- #6 取り下げ：acknowledgeResult は `guard pendingResult != nil`（GameSession:972）で二度目を捨てる＝二重に呼ばれても週は進まない。
- #7 の読み上げの部分は取り下げ：札は Text「体力 -12」で accessibilityHidden も無い＝そのまま読まれる。重なりの部分は大きい文字の目視（visual_largetext_1109b）で崩れなしを確認済み。
- #8 の境界のテストは候補に 9cc48386 で足した（購入3＋無料券1で preferPaid を5回＝購入3→無料券1→nil）。
