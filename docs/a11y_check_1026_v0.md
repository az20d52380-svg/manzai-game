# a11y 点検 a11y_check_1026_v0（2026-10-26・読み取りのみ・コードは未変更）

**件数：全7件（重 0／中 3／低 4）。** 対象＝753937d..HEAD で変わった Sources（45ファイル）。前回「未対応」にした物（#12 高さ・selfLabel の fixedSize・自動進行の全面停止・spring・全面 onTapGesture・Color.clear タップ）は重ねていない。
大筋：10/19 以降の追加分は、飾り記号に `accessibilityHidden(true)`・`mzScaled`・選択状態（ComboKindPicker の `.isSelected`、YoseGameParts のタブ/`.isModal`）が既に入っており、重い穴は無い。残りは下の7件。
節：§1 中／§2 低／§3 確認して問題なしだった所

## §1 中
1. **[中]** YearResultView.swift:45 — `Text("▼ 下にも続きます")` が hidden でも label 付きでもなく、「黒下向き三角、下にも続きます」と読まれる。しかも `.allowsHitTesting(false)` の見た目の合図で、VoiceOver はスクロール領域全体を順に読むので不要。→ `.accessibilityHidden(true)`（上の `VStack` に1行）。
2. **[中]** WeekMainView.swift:920-932 `practiceExpPanel` — 経験点5種が「札（`c.displayName`）」と「数字」の別要素になり、「閃き」「12」「語彙」「8」…と10回に割れて読まれる（札だけ label 済み・組になっていない）。→ 各 `VStack` に `.accessibilityElement(children: .combine)`（札の label は残すか、`.accessibilityLabel("\(c.displayName) \(ExpDisplay.value(s[currency: c]))")`）。
3. **[中]** ChoiceEventOverlay.swift:159-166, 206, 323 — 選択後に出る効果チップ（「◯◯ ↑」と、今回足した `hiddenEffectNote`「来週のネタ合わせが捗りそう」等）は `allowsHitTesting(false)` の overlay に動的に現れるだけで、フォーカスも Announcement も無い＝VoiceOver 利用者は結果（何が上がった／その週は稽古に出られない）に気づきにくい。特に `hiddenEffectNote` は数字に出ない効果の唯一の知らせ。→ `showEffects` の末尾に `UIAccessibility.post(notification: .announcement, argument: all.map(\.0).joined(separator: "、"))`（↑↓は eventChip の label と同じ置換を通す）。

## §2 低
4. **[低]** WeekMainView.swift:1582-1596 `yearEndTile` — 二度押しの「武装」状態（`yearEndArmed`）が、見出しが「年末へ」→「もう一度」に変わるだけ。label「もう一度」は単独では意味不明（トースト「もう一度押すと…」は YoseGameParts:202 で読まれるが、3秒で武装が黙って解除される＝状態の変化は読まれない）。→ `.accessibilityLabel(yearEndArmed ? "もう一度押すと年末の結果へ進む" : "年末へ")` ＋ `.accessibilityHint("二度押しで、残りの週を休んで年末の結果へ進む")`。
5. **[低]** IntroFlow.swift:641-655 `meetingMenu` — `Menu` の label は「出会い方、◯◯」と値入りで良いが、押すと選べることが hint に無い（chevron は label で上書きされ読まれない＝問題なし）。→ `.accessibilityHint("押すと出会い方を選べる")`。
6. **[低]** ComboKindPickerView.swift:34-40 — カードを選ぶと 0.3 秒で自動的に次の画面へ進む。`.isSelected` を付けても VoiceOver が「選択済み」を読む前に画面が替わる（確定の読み上げが無い）。前回の「自動進行」方針の延長。→ VoiceOver 稼働中（`UIAccessibility.isVoiceOverRunning`）は遅延を 1.2 秒以上にするか、`UIAccessibility.post(.announcement, "\(kind.cardTitle)に決めた")` を `onSelect` の前に。IntroFlow.swift:669（結成印の 0.45 秒）も同形。
7. **[低]** TournamentResultView.swift:169, 246-247 — 最終行を出してから 0.8 秒は `nextArmed=false` で「次へ」のタップが無言で無視される。VoiceOver のダブルタップは遅れるので、最初の1回が効かず「壊れている」ように聞こえる。→ VoiceOver 稼働中は待ちを 0 に（`nextArmed = UIAccessibility.isVoiceOverRunning`）。

## §3 確認して問題なし（重ねない）
- ComboKindPickerView：カードは Button＋合成 label＋`.isSelected`、顔の絵は label が上書き。
- Design/YoseGameParts：タブ `.isSelected`・モーダル `.isModal`・トースト Announcement 済み。YoseYearTurnCurtain：`.contain`＋`.isModal`・前年の札 hidden。
- EndingViews：「タイトルへ ▶」は label で「▶」を除去、成績ブロックは `.combine`。
- 12pt 未満の記号（play.fill／arrowtriangle／flag.fill／forward.end.fill／arrow.up/right）はすべて hidden＋mzScaled。IntroFlow の chevron は Menu label が上書き。
- ManzaiFigure の髪（long/bun）は Shape のみで読まれない。EventBackgrounds の看板「◀ 大国町　心斎橋 ▶」は絵ごと hidden（:750）。
- SettingsView「コンビを解散する」は YoseModal（isModal）＋確認1段。文言変更のみ。
- 多くは DialogueData/FanReportData/MeetingKind の文言追加で a11y 影響なし。
未確認：実機の VoiceOver 通し確認はしていない（静的読みのみ）。
