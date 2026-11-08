# コード点検 1108h

## 対象
`git diff c3282822..HEAD -- ManzaiGame/Sources GameCore/Sources`（22コミット・18ファイル・+96/−38）
- GameCore：GameConfig.swift（コメントのみ）／Skill.swift（中断セーブの特技を寛容に復号）
- ManzaiGame：GameSession.swift（SaveData の寛容復号・injuryNoticeText）／FinalsBroadcastIntro.swift（1108g の直し）／YoseChampionCelebrationView.swift（isGone）／YoseYearTurnCurtain.swift（compactYen）／Theme.swift（Yen.man）／IntroFlow.swift（縦の名札・MZ_NAMES）／WeekHint・WeekMainView・YearResultView・NotebookView・S6bView・StageViews・MeetingKind・Endings・CalendarView・RootView（表示・文言・背景）

## 指摘一覧
| 番号 | 重さ | 内容 | file:line | 起きる場面 |
|---|---|---|---|---|
| 1 | 低 | 縦の名札の字の大きさ式が、コメント（「4字までは今のまま26pt」）と合わない。札の高さ150 の時、4字の名前は 22.3pt に縮む（(150−26)/4−2)/1.3）。高さ176 なら 27→26pt で一致 | IntroFlow.swift:248-251（呼び出し :196,:209 の height=min(150,h×0.46)） | 自分の名前が4字（例：4字の「たかし君」）で、画面高が約326pt 以上（height が150に張り付く）の回想①の「俺」札。表示が少し小さくなるだけでクリップはしない |
| 2 | 低 | `Yen.man` の丸めで 10,000〜10,049 円が「1万」と出て 1〜49円が見えなくなる（旧式は「1.0万」と小数付きで出ていた）。表示の切り捨てで、数字は実値とずれない | Theme.swift:464 | 賞金・生活費・行動後の金額が 10,000 台の端数を持つ時。現行の設定値（賞金・生活費・メタ加算）はすべて万単位の倍数なので、実際には出ない |

DEBUG の漏れ：なし（MZ_NAMES は IntroFlow.swift の `#if DEBUG` 内、:803 付近。RootView の MZ_HANAIDX も DEBUG 内）。

## 各指摘と直し案
1. コメントを「3字まで26pt」に直すか、式の分母から 1.3 を外して 4字=26pt に合わせる。見た目のみ。
2. 現行値では起きない。賞金に端数（例 12,345）を入れる時だけ「1.2万」と丸めて出る＝仕様として問題なし。気になるなら、1万円台の端数を持つ値は円表記へ。

## 確認して問題なし
- **規律A**：GameCore の差分は GameConfig.swift（コメントのみ）と Skill.swift（`decodeIfPresent([Skill].self)` の追加）だけ。数式・乱数の消費順は無変更＝golden・Python 正典（sim_career.py YEARS=15）と一致。careerYears=15 の値も Python と同じ。
- **セーブ互換**：`GameState.skills` は `[Skill]?`（GameState.swift:78）なので合成 Codable は `decodeIfPresent` を呼び、新しい多重定義が選ばれる（非 Optional なら効かない所だった）。SaveData の `firedWeeklyEvents`（Set）は `decode`、`pendingChoiceEvent`（Optional）は `decodeIfPresent`、`categoryLog`（[Int:BandCategory]）は `decode` の多重定義が選ばれる。書き出しは Int キー辞書＝JSON のオブジェクト（文字列キー）、Set＝文字列配列で、以前と同形。旧セーブの読み込みは互換。
- **決勝導入の二重進行**（1108g の直し）：`advanceStage(from: s)` は `stage == s` で守られ、`.title` と `.finalists` の待ちの直後にも `Task.isCancelled` を確かめている。取りこぼしの経路は見つからず。最後の場面（.finalists）で `stage.next == nil` → finish() は `done` で二重呼びも防がれる。
- **優勝演出の isGone**：呼び出し元（FinalsPresentationView:215・TournamentResultView:294）は `if showChamp {…}` の overlay で、出るたび新しい View ＝ @State が初期化される。onDisappear で true になった後に同じ実体が再表示される経路は無く、onAppear の再実行で演出が出なくなる心配は無い。
- **compactYen / Yen.man**：99,999→「¥10万」、25,000→「¥2.5万」、9,999→「¥9,999」、−150,000→「−¥15万」、−3,000→「−¥3,000」がテスト（ManzaiGameTests.swift:883-887）と一致。借金は再帰で符号を前に出す（Int.min 以外は安全）。
- **万円表記の置き換え**：WeekHint・生活費カードの `Yen.man(livingCost)` は端数あり（13.3万）でも切り捨てず出る。残る `/ 10_000` の万円表示（Meta.swift:219・TournamentResultView:524・SettingsView・ログ）の対象値は全て 10,000 の倍数（metaStartMoneyPerPoint=30,000・賞金 100,000/250,000/500,000/2,500,000/5,000,000）で切り捨ては出ない。
- **行動後の金額帯**：`moneyDelta != 0` の中だけで描かれ（WeekMainView:1133）、1万円未満は整数円。「-¥0」は出ない。
- **offerPicker**：`ForEach(Array(offers.enumerated()), id: \.offset)` で `offers[i]` の添字引きをやめた。札が減った週の範囲外は解消。`offerPick`（選択位置）が札の減少後に範囲外のままになるかは `on = i == offerPick` の比較だけで、配列の添字としては使われていない。
- **YearResultView**：`Int(s.fame.isFinite ? s.fame : 0)` の追加でクラッシュ回避。salt は状態から決定的（乱数非消費）で変わらない。
- **背景・文言・DEBUG フック**：EventBackdrop `.famires`（Endings・MeetingKind）は既存の種別。MZ_HANAIDX は `max(0, min(…))` で負数・大きすぎる値とも範囲内。injuryNoticeText は2か所とも同一文。
- 参考（指摘にしない）：NotebookView:91・TournamentResultView:531・RootView:376 ほかの `Int(fame.rounded())` は isFinite の守りが無いが、fame が非有限になる経路は今回の差分では見つからず。
