# コード点検：ComboKindPickerView / MeetingKind / WeekHint / NetaSelectionView / RentStatement（2026-11-17・読み取り専用）
対象: ManzaiGame/Sources/ComboKindPickerView.swift, MeetingKind.swift, WeekHint.swift, NetaSelectionView.swift, RentStatement.swift ＋ 呼び出し側（IntroFlow.swift:506-845・RootView.swift:72/394/503・WeekMainView.swift:512-540/1282-1292・StageViews.swift:191/330-338・GameSession.swift:395-448/1223・Names.swift・GameEngine.applyWeekEnd）。
結論: 落ちる穴・乱数消費・女性形の男性語の生出しは見つからず（§確認済み）。状況と画面のずれが中1（決勝2本目の行）、低7（言葉のずれ・VoiceOver・死んだ入力・既知1）。高なし。

## 指摘
| # | 重さ | 場所 | 状態 → 結果 | 直し方の案 | 既知? |
|---|---|---|---|---|---|
| 1 | 中 | NetaSelectionView.swift:71-76（changeLabel の `unset`）／StageViews.swift:335-338 | 決勝でネタが1本だけの時：1本目の行がそのネタを選択、2本目の行は `selected==nil` かつ `activeNetas` 非空 → `unset=true` で**朱ベタの目立つ「ネタを選ぶ ▼」**が出る。押して開くと候補は `excludeID` で0件＝「——ほかにかけるネタが無い。」（:35）。押せる物があるように見えて、中身は空 | `unset` に `candidates` が空でないことを足す（空なら「選べるネタなし」の灰色の札＋ラベルは「変更 ▼」を出さない／ボタンを無効に）。表示のみ | 新規（nss_1116 #3・review_today_fixes_1019 §1 は「空の無言」を直しただけで、目立つ CTA は未対応） |
| 2 | 低 | WeekHint.swift:45 ／ WeekMainView.swift:1048 | `preoccupiedWeeks>0` の行は「今週は撮影の仕事で、稽古には出られない。」固定。一方、同じ状態の札の判子は「出張中」、トーストは「今週は撮影。」。現状 `preoccupyNextWeek` を出すのは 0022（撮影）だけなので今は一致するが、出張系の拘束イベントを足すと文が合わなくなる | 要確認：拘束の種類を持たない（preoccupiedWeeks は Int のみ）。足す時に「今週は仕事で稽古に出られない」へ寄せる／種類を State に持つ | 新規（code_review_2026-10-25b §2-1 は並び順のみ） |
| 3 | 低 | WeekHint.swift:13-17・:33（stageWeeksLeft / stageLength / netaFitsStage / stageNearWeeks）／ WeekMainView.swift:511-529 | `line()` はこれらを読まない（使うのは netaCount・preoccupied・money・livingCost・stamina・living系・weeksWithoutPartner・plusAvailable・expBannerShown）。呼び出し側は毎回 `nextMilestone()`・`session.nextStage`・`n.fits(...)` を計算して渡す＝無駄＋「尺が合わない」警告が一行ヒントに無いことが分かりにくい | 入力と定数を消す、または尺不一致の行を足す（足すなら％は出さない）。cands の「plusAvailable は使われない」は現コードでは :53 で使われており古い | 一部既知（code_review_1116_cands.md:25 は plusAvailable/expBannerShown の件・現状と食い違い） |
| 4 | 低 | RentStatement.swift:120-123 | `.accessibilityElement(children: .combine)` に `.accessibilityLabel` を付けているため、読み上げは「月末の支払い。合計N円。今月も払えた／N円足りない」だけ。内訳（家賃・食費など）と支払い後の所持金は読まれない。VoiceOver 中は自動で閉じない（:142）が、閉じ方（ダブルタップ）の案内が無い（`.isButton` も hint も無い） | ラベルに「所持金は支払い後N円」を足し、`.accessibilityHint("ダブルタップで閉じる")`・`.isButton` を付ける | 新規（a11y_check_1019 は「自動で閉じない」のみ） |
| 5 | 低 | ComboKindPickerView.swift:38 | 読み上げ「男女コンビ、自分が男・相方が女にした」＝「女にした」と聞こえて語が不自然（「男コンビ、二人とも男にした」も同様）。また見出し「どんなコンビにする？」に `.isHeader` が無い | 「〜を選んだ」/「〜にします」にし、見出しに `.accessibilityAddTraits(.isHeader)` | 新規（a11y_check_1026 低6 は「先に伝える」追加の件） |
| 6 | 低 | MeetingKind.swift:88-102（afterBreakup） | ラベルは「前のコンビの解散後」。台詞は俺「前のコンビのこと、聞いてるよ」（谷口に言う＝谷口の前のコンビの話に読める）／谷口「前の相方、客席に来てるらしいんだ」。**誰の前のコンビか**が曖昧で、ラベル（主人公側の解散後とも読める）とずれうる。以後の本編に主人公の前の相方の話は無い（grep 済み）ので、実害は読み違いのみ | 要確認：オーナーに「谷口の前のコンビ」か「自分の前のコンビ」か。自分側なら 俺「前のコンビのこと、聞いてるよ」→谷口「紹介で来た谷口です。前のコンビ、解散したって聞いたよ」等 | 新規・要確認 |
| 7 | 低 | NetaSelectionView.swift:25-29・:118-145 | 行を開く／とじるは「変更 ▼」「とじる ▲」の見た目だけ。VoiceOver ではボタンの状態（開いている）を伝える `.accessibilityValue`/hint が無く、▼▲は記号として読まれる。候補行も `.isSelected` を付けない（「選択中」タグの文字は読まれる） | ボタンに `accessibilityValue(expanded ? "開いています" : "閉じています")`、候補行に `.accessibilityAddTraits(isThis ? .isSelected : [])` | 新規 |
| 8 | 低 | RentStatement.swift:122-123（再開） | セーブ→再開で、払った週の支払い画面は出ない（`lastLivingPaid`・`lastDeltaWeek` は復元しない）。払った事実は所持金に反映済み＝食い違いなし | 現状どおりで可 | 既知（save_restore_audit_1115_v0 §4） |

## 確認済み（問題なし）
- 落ちる穴：
  - ComboKindPickerView は `order` 固定4要素・配列添字なし。
  - MeetingKind：`debugForced` は `allCases.indices.contains(n-1)` の後に添字（DEBUG のみ）。`from(_:)` は未知の raw を .highSchool に。IntroFlow.swift:665 の `allCases[i]` は Picker の tag（0..<4）由来で範囲内。:696 の `randomElement() ?? .highSchool` も安全。
  - WeekHint：除算・添字なし。`Yen.man`（Theme.swift:463）は `Int(m)` の前に丸め済みで、livingCost は小さい整数。
  - NetaSelectionView：`Int(neta.polish.rounded())` は polish が WeekRunner.swift:537/546 で 0..100 に丸められ、JSON は NaN を持てない＝トラップしない。強制アンラップ無し。
  - RentStatement：`breakdown` は除数 sum=14（定数）。`lines.isEmpty` を見てから `lines[0]`。`Int(money)` は Int 由来の Double。`abs(Int.min)` は現実に届かない。`ShopView.roomNames[min(max(room,0),count-1)]` で範囲補正済み。
- 乱数：5ファイルとも GameCore の RNG を呼ばない。MeetingKind を決める `randomElement()`（IntroFlow.swift:696）はシステム乱数でゲーム内 RNG・golden 無関係（結果はセーブへ入る）。NetaPickRow は `selectNeta/2`（乱数なし・冪等）を呼ぶだけ。
- 女性形（女女・男女）：
  - MeetingKind の12文は男女どちらでも通る語尾。「俺」は話者名（Names.show が名前／私へ）か `{me}`（:82「{me}も代わってもらった」→ 私も）。
  - WeekHint の「谷口：…」は Text(String) 経由で相方の名前に替わる。
  - ComboKindPickerView の見出し・カードに「俺」「谷口」の生出しなし（「俺」「私」は説明文として両方並べている）。
- 状況と文：
  - WeekHint の優先順は 借金→撮影→ネタ無し→生活費不足→体力≤30→体力<50→再来週の支払い→相方→経験点。`injuryThreshold=50`・`staminaLow=30` で枝が死なない。
  - 生活費は `week % livingInterval(4)`、再来週は `(week+2)%4`（年は48週で年またぎの誤判定なし）。金額は `livingCostDue`（部屋上乗せ・やりくり込み）で RentStatement と一致。
  - RentStatement の `moneyBefore = moneyAfter + livingCost` は `applyWeekEnd`（money -= livingCostDue → 負なら体力・メンタル減）と整合。「今月も払えた」は `shortfall==0` の時だけ。
  - 回想は出会い方で閉じており、本編側に「高校の同級生」を前提にする文は無い（DialogueData:521/585 は谷口の中学・部活の話、ChoiceEventData:1139 は別人の小野寺、YearResultView:448 は別の同級生の話）。
- セーブ→再開：meetingKind は SaveData に保存（GameSession.swift:1291/1372・復号は :276 で nil→高校の同級生）。回想は導入でしか流れない。Names.setKind は新規（:252）・復元（:278）の両方で呼ばれる。
- 動き：
  - RentStatement の `.task` は各 sleep の後に `Task.isCancelled` を見る（タップで閉じた後に音・振動・onDone が走らない）。
  - reduceMotion は step=0・アニメ nil。
  - 「−0」「0円が赤」は直し済み（1116_night #1）。
  - ComboKindPicker は `picked` ガードで二重タップを弾き、0.3秒後の `onSelect` は1回。
  - 同じ処理内で値を立てて戻す書き方は無し。
- アクセシビリティ：ComboKindPicker のカードは `accessibilityLabel`（種類＋内訳）＋`.isSelected`、顔の絵はラベルで包まれる。NetaPickRow の行は文字を持つ Button。
