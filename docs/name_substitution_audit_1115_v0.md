# 名前差し替え漏れ監査（2026-11-15 v0）

対象：ManzaiGame/Sources 全体（読み取りのみ・コード変更なし）。
結論：データ由来の文（DialogueData／ChoiceEventData／Endings／MeetingKind／GameSession 等）が Names.show を通らずに出る所は **見つからなかった**。指摘は「入力した名前を Names.show に通してしまう」逆向きの低リスク3件と、潜在1件。確認は静的な読みのみ（実機未確認）。

## §1 指摘（3件・すべて重さ＝低）

### 1. 自分が入力した名前（コンビ名・自分・相方）が Names.show を通ってしまう（確信度 中）
- 場所：Text(String) 全般。例：Design/YoseChampionCelebrationView.swift:392 `Text(partnerName)`、QualifierNoticeView.swift:93,161 `Text(partnerName)`、StageFrame.swift:473 `Text(String(c))`（コンビ名の縦書き）、FinalsPresentationView.swift:1063（票札）、IntroFlow.swift:260。
- 流れてくる値の例：コンビ名「谷口ブラザーズ」「俺たち」、自分の名前「谷口」。
- 誤り：相方を「田中」にすると、コンビ名の「谷口」が「田中ブラザーズ」に化ける。縦書きは1字ずつ Text(String(c)) にするため、コンビ名に「俺」の字があると「俺」1字が自分の名前／「私」に置き換わる（女女なら「私たち」が縦書きで「私」に化ける等）。
- 直し：ユーザー入力値（session.combiName／Names.me／Names.partner）を出す Text だけ `Text(verbatim:)` にする。縦書きの1字Textも同様（ただし固定文言と混在する StageMakuri は呼び出し側で名前の種別を分けるか、`Text(verbatim: String(c))`）。重さ：コンビ名に谷口／俺を入れる人は稀。

### 2. 二重に Names.show がかかる箇所（確信度 高・実害ほぼ無し）
- IntroFlow.swift:74 `YoseSpeechBox(speaker: Names.show(…), text: Names.show(…))` → YoseSpeechBox 内の Text がもう一度 show。
- 誤り：自分の名前を「谷口」にすると、1回目で「谷口」→2回目で相方名（田中）に変わる。自分の名前を「俺」にした女女では「俺」→「私」。
- 直し：IntroFlow.swift:74 は show を外して生の値を渡す（YoseSpeechBox 側で1回かかる）。

### 3. VoiceOver 読み上げに生の文が流れる潜在穴（確信度 高・現状は名前を含む文が流れていない）
- Design/YoseGameParts.swift:252 `UIAccessibility.post(.announcement, argument: message)`（YoseToast）。
- 現状の呼び元は CalendarView.swift:36（週の種別ラベル）と YoseCatalog（デバッグ）だけで、谷口を含む文は来ない。将来「谷口「…」」型のトーストを YoseToast に流すと、画面は田中・読み上げは谷口になる。
- 直し：`argument: Names.show(message)`。同型の a11y 文字列（accessibilityLabel/announcement に文を直接補間する所）は新規追加時に Names.show を通す規約にする。

## §2 問題なしと確かめた主な所
- Names.swift:52 `extension Text { init(_ s: String) }`：アプリ内の Text(String)・文字列補間付き Text・RadarChart の ctx.draw(Text(...)) はすべてここ経由。`Text(AttributedString)`／`Text(LocalizedStringKey)`／`StringProtocol` 版（Substring）は名前を含む文には使われていない（Substring 系は CalendarView の種別頭文字・審査員の姓のみ＝対象外）。
- Text(verbatim:) は2箇所のみ：IntroFlow.swift:131（name・text とも Names.show 済み）、FinalsPresentationView.swift:1120（Names.show 済み）。IntroFlow.swift:648 のプレースホルダ「谷口」は既定名の見本なので意図どおり。
- `Text(a)+Text(b)` は YoseGameParts.swift:55 の数字のみ。
- accessibilityLabel：TalkParts.swift:86／IntroFlow.swift:138 は Names.show 済み。QualifierNoticeView（相方名は Names.partner 渡し・返信文は名前なし）、ChoiceEventOverlay.swift:206,331（効果チップ・隠し効果の一言に名前なし）、FirstStageView.swift:128（固定の地の文）、FinalistAnnounceView（組名）、WeekMainView.swift:635（固定）は名前を含まない。
- 話者札・role 判定：WeekMainView.swift:640-641、ChoiceEventOverlay.swift:226、TalkParts は生の「谷口」「俺」で判定し、表示は Text 経由で差し替え。YoseSpeechBox の speaker／text／roleLabel も Text(String)。
- 週頭の台詞・独白・Endings の cut・ReminiscenceCard・EndingViews の caption／title・ClimaxPage（TournamentResultView）・MeetingKind・WeekHint・トースト（WeekMainView.swift:1537→toastBar の Text）：すべて Text(String) 経由。
- ShareCard：ShareCardView の Text は Text(String) 経由。ending.title／kind.label／winHeadline に名前なし。SharePreview／ShareLink の message は combiName と固定文のみ。
- 通知（UNNotification）・読み上げ（AVSpeech）・UIKit 描画（NSAttributedString／draw）・Button("…")／Label／Picker／confirmationDialog／navigationTitle／alert の文言：名前を含みうる文は無い（固定UI文言・スキル名・衣装名のみ）。TextField の placeholder は「例：なんば亭」「谷口」（既定名の見本）。
- CharacterAvatars／StageScene の StageFootTag(name:"谷口") は Text(String) 経由で差し替わる。
