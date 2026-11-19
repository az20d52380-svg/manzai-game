# 11/16 の直し約20本のコード点検（90768d5d2..8ef19b873・読むだけ）

## 要点3行
- 高0・中0・低2・要確認1。壊れる所は見つからなかった。
- inviteWaiting は旧セーブ（キー無し）で false に落ち、表示時に必ず落とす＝二重には出ない。ただし「年が替わる時に落とさない」のは残る（低-1）。
- 試し版3本は 98fa0dc09（views-a11y-1116 の merge）で入れた記録が AUTOPILOT 624・625・629 にある＝意図どおり。デバッグフックは全部 #if DEBUG の中。

## §1 件数
高0／中0／低2／要確認1（未確認の項目は「未確認」と明記）

## §2 指摘
### 低-1 年末週の誘いが翌年に持ち越される（GameSession.swift:110・1411・1225付近）
- 場面：最終週の週末に runner.pendingInvite が立つと 1411 行で inviteWaiting=true。続く begin() が yearDone を返し、新年の初期化（1215〜1232 行の一連のリセット）には inviteWaiting の初期化が無い。翌年の最初の自由週で「先輩の誘い」が出る。f3240e4ad でセーブにも載るようになったので、中断→再開をまたいでも持ち越す。
- 確認済：WeekRunner.swift:473-475 の誘いの抽選は週の締め（weekDone）で毎週走り、最終週も除外なし。年の終わりは次の begin()（WeekRunner:183 の week>weeks）で出るので、最終週の分は持ち越しうる（要確認＝最終週に誘いの札が出ない設計か。出ないなら inviteWaiting を落とす1行で足りる）。
- 直し案：新年の初期化（`lastEventRollWeek = -1` の近く）に `inviteWaiting = false` を足す。表示のみ・golden 非干渉。

### 低-2 字間 U+2060 を入れた文字列の読み上げ（NotebookView.swift breakAtSpaces・YearResultView.swift:293）
- breakAtSpaces は空文字・空白だけの文字列でも落ちない（split で [""] か ["",""] になり、結合して元に戻る。index 計算は無い）。
- ただし 8字以下のかたまりの全字間に U+2060 を入れるので、VoiceOver が1字ずつ区切って読む恐れ（1366c752a と同じ種類の問題）。**未確認**（実機が要る）。確かめるなら Text に .accessibilityLabel(元の文字列) を付ける。
- 同じ型の読み上げ名が無い見出しが残っている：S6bView.swift:70「千 秋 楽」、YoseChampionCelebrationView.swift:234「漫 才 の 頂 、…」（親側で付けていれば問題なし・未確認）。

### 問題なし（確認済）StageCeremony の「見た印」（StageFrame.swift:297・317）
- b8e4c5689 で見た印を finish() に移した。run() は取り消されると abandon() で戻る＝印を立てず次回も長い版。意図どおり。
- タップで飛ばす経路（StageFrame.swift:291）も finish() を通る＝確認済・問題なし。

### 要確認-1 能力アップの値札 a11y（AbilityUpView.swift:359）
- 「ネタ種 4」「、足りない」を読み上げ名に付けた。見える文字は数字だけ（色で区別）なので、見た目と食い違いはない。通貨名が見える文字に出ているかは未確認。

## §3 問題なしと確かめた所
1. f3240e4ad：旧セーブ＝`save.inviteWaiting ?? false`（GameSession:342）。保存は true の時だけ（nil で書く）。表示する分岐（632〜636）で必ず false に落としてから札を出す＝二重発火なし。再開時は runner が作り直されて pendingInvite は nil だが、効果は `applyInviteGo(idea: inviteIdea)`（789）で inviteIdea から直接かけるので、再開後に「行く」が空振りしない。inviteIdea も（札が出ている時か待ち中だけ）保存される。次の週の weekDone で上書きされるのは新しい誘いが来た時だけ。
2. 折り返し修正：breakAtSpaces は index 計算なし・空文字/空白のみでクラッシュなし。「「」だけの残りを切らない条件あり。breakAtLastDot は「・」が無ければ元の文字を返す。末尾が「・」の時だけ末尾に改行が付くが害なし。fc6d69cca の修飾子の戻しも差分で確認（foregroundStyle・lineSpacing が復活）。
3. e668ea821：`Int(money) < 0` と表示の `Int(money)` が同じ丸め＝一致。
4. 1366c752a：ラベル4つは見える文字から空白と ◆ を除いたもので一致（装飾の ◆ は読まない）。
5. 試し版 deb1cb84f / 8b5793820 / b8e4c5689：`git log` で 98fa0dc09（merge: 試し版 views-a11y-1116）経由。AUTOPILOT 624（点検と試し版の記録）・625（green 確認後に本体へ入れた）・629（低-1 を足した）に記載あり。記録なしで main に入った試し版は無し。8b5793820 の presenting 形は対象を引数で受けるので nil 化が先でも覚えられる。deb1cb84f は stage 替えと同時に step/slam/titleIn を戻すだけ。
6. DEBUG フック：MZ_KIROKU＝GameSession.debugSeedKirokuLog（#if DEBUG 1513〜1828 の中）、MZ_UI=stage_result/final_entry＝RootView（#if DEBUG 33〜87）、MZ_UI/MZ_CLIMAX/MZ_PASSFX＝TournamentResultView（270〜277）、MZ_SCROLL＝ShopView（#if DEBUG で包んである）。本番へ漏れていない。
7. `try? await` の握りつぶし：この範囲で足された Task.sleep／MZSpeed.sleep は無し（StageCeremony の既存分は `Task.isCancelled` を見て abandon へ戻る）。
