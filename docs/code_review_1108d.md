# コード点検 1108d（ほぼ未点検だったファイル群）

対象：FinalsBroadcastIntro / StageScene / RentStatement / RadarChart / ShareCard / GachaRatesView / CharacterAvatars / TalkParts / MeetingKind（ManzaiGame/Sources）、Allocation / ChoiceEventEffect / Item / Neta / Career / Skill（GameCore）、NetaCatalog（ManzaiGame/Sources にある）。

## 指摘の一覧（高0・中2・低1）
| 番号 | 重さ | 内容 | 状態 |
|---|---|---|---|
| 1 | 中 | 決勝の導入：場面の待ち時間中にタップすると、次の場面が1つ飛ぶ | 直した |
| 2 | 中 | コンビ名に「谷口」「{me}」を含むと、共有カードで相方名・一人称に置き換わる | 判断が要る（推測でなく手順は追えた） |
| 3 | 低 | 「おすすめ注ぎ」が、成長予算を使い切った後にメンタルを注がずに止まる | 判断が要る（式・golden） |

## 1. 決勝導入でタップすると場面が1つ飛ぶ（中・直した）
- 場所：FinalsBroadcastIntro.swift の `run(_:)` 末尾の `advanceStage()`（vtr／title／judges／finalists の4か所）。
- 手順（コードを追って確認。実機で秒数を合わせては撮っていない）：煽りVの最後の行の待ち（`await pause`）の途中でタップ → `advanceStage()` で stage が title へ → `.task(id: stage)` が古い task をキャンセル → `MZSpeed.sleep` は `try?` で握りつぶされて即戻る → 古い run が末尾の `advanceStage()` をもう一度呼ぶ → title が一瞬も出ず judges へ。同じ形で title 待ち中のタップは judges を、judges の最後の待ち中のタップは finalists を飛ばす。
- 直し：各 `advanceStage()` の前に `guard !Task.isCancelled else { return }`。表示だけ。
- コミット：決勝導入：タップで進めた後に…

## 2. コンビ名が相方名・一人称に置き換わる（中・判断が要る）
- 場所：Names.swift の `Text.init(_ s: String)`（アプリ内の Text(String) 全部が `Names.show` を通る）と、ShareCard.swift の `Text(combiName)`（ほかにも結果画面など、コンビ名を Text(String) で出す所すべて）。
- 手順：結成届でコンビ名に「谷口一座」、相方の名前に「ケン」と入れて結成 → 共有カード（と他の画面）のコンビ名が「ケン一座」になる。「{me}」と入れると「俺」に、名前を「俺」だけにすると自分の名前に変わる。
- 何が起きるか：入力した名前と違う名前が出る（共有画像は SNS に出る物）。
- 直し案：コンビ名の表示を `Text(verbatim:)` にする。ただしアプリ全体の表示箇所（Names は対象外のファイル）を揃えないと、画面と共有画像で名前がずれる。範囲が広いので、やる／やらないをオーナー判断に。
- 補足：ShareCard だけ直す案は、画面と画像で名前が違って見えるので推奨しない。

## 3. 「おすすめ注ぎ」がメンタルを注がずに止まる（低・判断が要る・推測）
- 場所：Allocation.swift の `recommendedPlan`。注げる能力のうち現在値が最低の物を選び、`pourStep` が 0 を返したら `break`。
- 手順（コードを追った推測。実測はしていない）：その年の成長予算（growthBudget）を使い切る → 非メンタルの能力は `projectedGain` が 0 → 最低値の能力（非メンタル）が選ばれて 0 が返り、ループ終了 → 予算の対象外のメンタルは注げるのに、おすすめでは注がれない。メンタルは他より現在値が高いことが多く、最低が選ばれ続けるため。
- 何が起きるか：おすすめを押してもメンタルだけ残る（手動の +1 なら注げる）。
- 直し案：gain が 0 の能力を候補から外して続ける。ただし golden のボット台本・Python 鏡像（balance_sim）と同じ式なので、式の変更＝オーナー判断。触っていない。

## 問題なしと確かめた点
- RentStatement：内訳は 6:4:2:2 で端数を最後の行が吸収し合計が一致。所持金が負でも「−」表示と足りない額は合っている。Task はキャンセル後に音・振動・onDone を出さない。VoiceOver 中は自動で閉じない。部屋の上乗せは「家賃」行だけに乗る。
- RadarChart：cap は 30 以上の縮尺と実際の上限の小さい方で 0 にならない。値が上限を超えても 1 で止まる。ActionBreakdownBand は weeks が 0 でも `max(1, …)` で落ちない。
- FinalsBroadcastIntro：空のコンビ名・15年目・観客モード（自組なし）でも文面が崩れない。テロップの「上位3組」「7名」は最終決戦の仕様と一致。エンディング側（FinalsBroadcastEnding）はキャンセル確認済み。
- MeetingKind：4型とも語尾は男女どちらでも通る。{me} は Names.show で「俺／私」に置き換わる（女コンビ MZ_KIND=femaleFemale でも文面は食い違わない）。
- CharacterAvatars／TalkParts：女コンビの顔は Names.kind で切り替わる。話者名札は元の名前（俺／谷口）で色と顔を引き、表示だけ置き換え。
- GachaRatesView：割合・料金・天井・ログインの枚数は GachaCatalog／GachaState の値から作られ、初回特別・天井・かけらの文面は GachaState の実装と一致。
- StageScene：Task・タイマーなし。足元の名札は Names 経由で、女コンビは「私」。
- Item：購入条件（所持金・年の回数・持ち越し）と buy の効果が一致、乱数なし。ChoiceEventEffect：全分岐が clamp 済み（所持金のみ負可は仕様どおり）。Neta／NetaCatalog：審査員名・7型×7人の表が揃い、周回の剰余は負の id でも安全。Career：夜逃げ・解散で runCareer が止まる。Skill：費用判定は 1e-9 の許容つき。

## 直したコミット
- 決勝導入：タップで進めた後に古い場面が二重に進めて1場面飛ぶのを防ぐ（FinalsBroadcastIntro.swift のみ）。
- 検証：`cd GameCore && swift test` 通過、アプリのビルドにエラーなし、アプリのテスト 448 件 0 失敗。
