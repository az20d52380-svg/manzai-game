# コード点検 2026-10-25（今日の自走で入ったアプリの変更）

対象: f4d99ae（審査員の点と票）／f5afa22（解散の別れ）／77be01a（型の非表示＋JudgeTalk）／b451949・8182ccf・d73f81f（コンビの形）／df28f67・e2aba5c（語尾）／d282004（writeNetaID）／36f196a（観戦札）／9773ebe（出会い方）。
コードは直していない。`swift test`（GameCore）は 351件 0失敗・FeatureGolden 一致＝GameCore の乱数・golden に影響する変更は紛れていない（GameCore の差分は JudgeTalk.swift の文言と `kata: nil` のみ・乱数非消費）。アプリ側のテスト（xcodebuild）は走らせていない。

## 所見

### §1 【中】最終決戦で「勝者が過半数（4票）に届かない」ことがある＝演出が決着の札を出せない
- ファイル: FinalsPresentationView.swift:1299-1345（票の生成）／:372-373・:399-402・:505-510（「4票目で決着」を前提にした演出）
- 何が起きるか: 新しい票は審査員ごとに個人点の最高の組へ入れる。補正が効くのは「自組が絡む時」だけ（優勝＝自組4票以上／負け＝自組3票以下かつ首位でない）。
  - 負けの年: 自組が 1〜2 票まで下げられた後、残りの票が他の2組に 3-3 や 3-2（自組2）のように割れても補正は何もしない。勝者 `winnerIndex` は「最多票（同数なら添字の小さい方）」なので、勝者が 3 票・または 3-3 の同数で勝ち、という結果になる。
  - 観客版（自組が決勝にいない）: 補正が一切無い。3組の個人点は `その組のS/7＋seed固定のノイズ±1.5` で、合計の差が小さい組が並ぶと 3-2-2 や 3-3-1 が普通に出る。
  - 演出は `winCount == 4` で太鼓・大歓声・揺れを1回だけ鳴らし（:399）、早送りも `before < 4` で判定（:507）、「王手の次が決着」も 3票→4票目前提（:372）。勝者が 4 票に届かないと決着の一打が一度も鳴らず、残りの札が自動で開かれないまま止まって見える可能性がある（`revealVotes` が 7 になるまでは手動めくり）。
- 旧実装は勝者に 4〜7 票を必ず配っていた（`w` は 4...6 など）ので、この前提は今日のコミットで崩れた。
- テスト: testFinalsJudgeVotesAbilityBased は自組が絡む場合の「自組≥4／≤3」しか見ていない。「勝者の票 ≥ 4」と観客版（spectator: true）を見ていない。
- 直し方の案: 票を作った後に「勝者の票が4未満なら、勝者以外の組の票のうち個人点の差が最も小さい審査員から勝者へ移す」を足す（自組を勝者にしない／自組を首位にしない制約を保ったまま）。観客版にも同じ補正を適用。テストに全 year×（自組なし／負け／優勝）で `counts[winner] >= 4` を追加。
- 確かさ: 票の算術からは確実に起こり得る。実機での頻度と演出の見え方は 要確認（MZ_UI=finals で MZ_FMARGIN=-2 を何年か回すと見つかるはず）。

### §2 【中】最初に書いたネタが勝負ネタ（selectedNetaID）に入らなくなった＝入口を通らない経路で効果が落ちる
- ファイル: GameSession.swift:796-803（旧 `runner.applyNetaSelect(id:)` を削除）／GameSession.swift:837-841（ensureStageNetaDefault は nil の時だけ補う）／StageViews.swift:192・:314（呼び出しは大会の入口の onAppear のみ）／GameCore GameEngine.swift:264（selectedNetaID が無ければ netaScoreBonus=0）
- 何が起きるか: 新規キャリアで最初のネタを書いても `selectedNetaID` は nil のまま。大会の入口画面（StageViews 2か所）が開けば補われるが、入口を経由しない結果の出し方があれば（週送りの自動解決・準決勝後の決勝の発表・決勝の `FinalsData` の `selectedNeta?.polish ?? 60` など）、ネタ補正が 0 のまま評価・表示される。決勝の審査員の点でも polish が 60 の既定になる。
- 同じ原因で ネタ見せ会／フリーライブ（GameSession.swift:807-809）は `selectedNetaID` が nil だと `netas.last` を磨く＝複数本あるとき「書いたネタ」ではなく最後のネタが披露される。
- 直し方の案: 書いて新ネタができた時、`selectedNetaID == nil` の時だけ `applyNetaSelect` する（勝負ネタが既にある時は触らない＝今日の分離の目的は保てる）。または大会を解決する前に必ず ensureStageNetaDefault を通す。入口の経路網羅は 要確認。

### §3 【中】「この周の最高成績」が進行中の年で「敗退」と出る
- ファイル: GameSession.swift:990-997（bestRunLine）／YearResultView.swift:167（reachLabel）
- 手順: 1年目の途中で GP2回戦まで通過した状態（`gpRoundsPassed = 2`・決勝には未到達）で設定→解散。進行中の年として `roundsPassed: 2` の記録を作り、reachLabel が `names[2]` の「…敗退」と表示する＝まだ負けていないのに「GP3回戦敗退」等になる。他の年が無いとこの行がそのまま別れの場面に出る。
- 直し方の案: 進行中の年は「GP○回戦通過」（通過した最後の段の名前）として別のラベルで出す、または「敗退」を付けない。
- 補足（問題なし）: 同点の年は最も早い年（`$0.year > $1.year` を小さい扱い）。優勝は rank 100 で最優先。優勝の年は yearHistory に champion 付きで積まれる（:1264 が winFinale の前）ので進行中の記録と二重でも順位は変わらない。

### §4 【低】解散の別れの場面の途中でアプリを閉じると「解散していない」状態で戻る
- ファイル: WeekMainView.swift:187-196（onQuitRun は showFarewell を立てるだけ）／GameSession.swift:979（セーブを消すのは abandonRun＝「タイトルへ」を押した時だけ）／RootView.swift:300-304
- 手順: 設定→解散→確認→別れの場面→（成績の行で）アプリを終了。セーブは残っているので再起動で解散前の週に戻る。意図どおり（解散は「タイトルへ」で確定）なら問題ないが、オーナー決定なら文書に残すこと。設計判断なので 要確認。
- 二度押し: `onFinish` が連打されても abandonRun は removeObject と `abandoned = true` のみで冪等。問題なし。
- `abandoned` で `session = GameSession()` に替わると Names.kind が男コンビに戻り、0.3秒のフェード中だけ旧画面の「私」が「俺」に変わって見えることがある（見た目のみ）。

### §5 【低】Names.show が二重に掛かる経路（相方の名前に「谷口」を含む時）
- ファイル: FinalsPresentationView.swift:1125 `Text(Names.show("谷口が、そっと耳打ちした。"))`（`Text(String)` が更にもう一度 `Names.show` を掛ける）／Names.swift:36-46
- 手順: 相方の名前を「谷口ケン」にして決勝の耳打ちの行を見ると「谷口ケンケンが…」。他の経路（IntroFlow:127・TalkParts:86 のアクセシビリティ）は `Text(verbatim:)`／文字列で受けているため一重。
- {me} の置換自体は二重にならない。
- 直し方の案: 1125 を `Text("谷口が、そっと耳打ちした。")`（拡張に任せる）にする。

### §6 【低】Names.show の「私ら→私たち」は `{` を含む文全体に掛かる
- ファイル: Names.swift:40-42
- `{` を含む文に「私らしい」などが含まれると「私たちしい」になる。今のデータには該当する文は見つかっていない（grep では {me}/{partner1} を含む39行に無し）。{me}ら→{me}たち と書くデータ側で揃える方が安全。

### §7 【低】writeNewNeta の持続と書く対象の取り残し
- ファイル: GameSession.swift:53・:796-805・:826-833
- (a) 「新しく書く」を選んだ後、枠が満杯でも `writeNewNeta` が true のまま残る。満杯の週は `netas.last` を磨く分岐に落ちるが、フラグは下ろされない。後で枠が空いた最初の書く週に、意図しない新ネタが作られる。
- (b) `writeNewNeta` はセーブしない（コメントどおり）。選んだ後に再起動すると、書く対象が勝負ネタに戻る（表示も戻るので害は小さい）。
- (c) 書く対象のネタを保管庫へしまう（retireNeta）と `writeNetaID` が消えたネタを指したまま残る。`writeTargetID` は `state.netas.contains` で守っているので落ちないが、後でそのネタを呼び戻す（recallNeta）と、書く対象が黙ってそのネタに戻る。retireNeta で `writeNetaID` を nil にするのが簡単。
- 周回の頭: 新しいキャリアは新しい GameSession なので writeNetaID・writeNewNeta は初期化される。startNextYear でのリセットは不要（キャリア内の持ち越しは意図どおり）。
- 擦り切れ: ネタは擦り切れても消えず（polish などの値の変化のみ）、削除は retire/archive 経由だけなので (c) 以外の取り残しは見つからなかった。

### §8 【低】コンビの形・出会い方の読み込みと保存（問題なしの確認）
- comboKind／meetingKind／writeNetaID／watchedFinal はすべて Optional で、旧セーブは nil→男コンビ／高校の同級生／勝負ネタを磨く／札なし。テストも往復と旧セーブを見ている（ManzaiGameTests 65-90・497-503行）。SaveData の項目一覧を固定するテストは存在しない（食い違いの対象なし）。
- 出会い方の「とばす」: `finish()` に統一され、`markIntroSeen` は最後まで観た時だけ。とばしても `meeting` は名前決めで選んだ値のまま渡る。名前決めから戻る導線は無い（問題なし）。
- 回想は名前決めの後に変わったので、2周目以降の「とばす」は名前決めの後に出る＝初見の回想前の名前決めは必須。仕様どおり。
- 観戦札: watchedFinal は年末に1回だけ積まれ（`yearHistory.last?.year != runner.year` の保護）、startNextYear（:1047）で didWatchFinal が戻る。決勝に残った年は札を出さない（`!r.reachedFinal`）。問題なし。

### §9 【低】{me}／{partner1} が生のまま出る可能性のある経路（要確認）
- 通っている経路: `Text(String)`（拡張）／TalkParts:86・IntroFlow:127,134 のアクセシビリティ・ラベル。
- 通らない恐れ: `Text("…\(変数)…")`（LocalizedStringKey 経路）や AttributedString・通知文・ログに、会話データの文字列をそのまま渡す箇所があれば `{me}` が生で出る。grep では Text("\(…)") で会話文を渡す箇所は見つからなかった。ChoiceEventOverlay:206 の選択肢ラベルは記号を含まない。通知機能は未実装。今は問題なしと見るが、Endings の caption（`{me}のアパート`）の描画経路が Text(String) か 要確認。
- 旧セーブ＝男コンビ（nil→.maleMale）で、台詞は「俺」＝従来どおり。

### §10 【低】型の非表示（77be01a）の取りこぼし
- NotebookView から型ピッカーを消したが、`GameSession.changeNetaKata` と GameCore の applyNetaChangeKata は残っている（未使用）。大改稿で型を変える仕様の記述が docs に残っていれば食い違う。FinalsPresentationView と JudgeTalk は `kata: nil`＝型別の語彙表が使われなくなる（乱数非消費・golden 不変を `swift test` で確認済み）。

## 観点別の結論
- セーブ互換: 問題なし（§8）。
- 状態の食い違い: §2・§7。
- 解散の流れ: §3・§4（二度押しは冪等）。sheet が閉じる途中の overlay は同時に `showSettings=false` と `showFarewell=true` を立てるだけで表示は崩れない見込み（実機は 要確認）。
- 審査員の点と票: §1（過半数に届かない勝者）。Σ=S 補正は 50〜99 の範囲で必ず収束し（最大 700 回）、優勝＝自組4票以上／負け＝自組3票以下かつ首位でない、は補正ループが保証する（pick<0 の break は自組の票が 0 か全員自組に入った時だけ）。margin 0 付近・3組同点は添字の小さい方に入るので決定的。
- コンビの形: §5・§6・§9。
- 出会い方: 問題なし（§8）。
- 乱数・golden: GameCore の乱数消費に触れる変更なし。FinalsData の UI 専用乱数の消費順は変わったが、GameCore の乱数列とは別（seed は能力と年から決まる）。

## 要約
1. 件数: 高 0／中 3（§1・§2・§3）／低 7。
2. 一番重いのは §1: 最終決戦で勝者が 3票（または 3-3 の同数）になり得て、「4票目で決着」の演出が出ない。観客版には補正が無い。
3. GameCore の golden・乱数は無事（351テスト 0失敗）。セーブ互換は問題なし。

## §直した所
- §1（7b011b3）: FinalsPresentationView の最終決戦の票。勝者を先に決め（自組優勝＝自組／負け＝自組以外の最多票／観客版＝最多票）、勝者が4票未満なら「勝者との個人点の差が小さい審査員から1人ずつ勝者へ倒す」最後の補正を全ケースに適用。他組から動かすだけなので「自組は3票以下・首位でない」は保たれる。テスト: testFinalsJudgeVotesAbilityBased に「勝者4票以上・7票の合計7」（負け/優勝の各年）と観客版 60年分を追加。
- §2: 方式＝「勝負ネタが nil の時だけ、新しく書いたネタを勝負ネタにも入れる」（GameSession.applyNetaWork の ネタ作り系）。手で選んだ勝負ネタは動かさない。経路の洗い出し（grep）: アプリ内でネタが新規に生まれる所は applyNetaWork の `runner.applyNetaCreate` の1か所のみ（他は debug 用 state の直接代入＝GameSession.debugNetaState / RootView の MZ_ 系フック）。ここで nil を埋めれば、入口画面（StageViews:192・:314 の ensureStageNetaDefault）を通らない経路（GPの回戦・決勝・敗者復活・advanceAuto の自動進行・決勝の FinalsData の selectedNeta?.polish）でも補正0／既定60にならない。ネタ見せ会／フリーライブの「nil なら netas.last」も、最初のネタが勝負ネタになるので「書いたネタ」が披露される。テスト: testFirstWrittenNetaBecomesStageNetaOnlyWhenEmpty（新規キャリアで ネタ作り → selectedNetaID が入る）。手で選んだ勝負ネタが動かない点は既存の testWriteTargetIsSeparateFromStageNeta・testStageNetaDefaultOnlyFillsEmptyChoice が担保。

## §直した所（親・10/25）
- §3 進行中の年は通過した段で言う（10bf180）／§6 「{me}ら」だけを「私たち」に＋テスト／§7a 枠が満杯の週に「新しく書く」を下ろす／§7c しまったネタを書く対象から外す／§5 耳打ちの行を Text(verbatim:) で一重に。アプリのテスト 69 本 green。
- 残り：§4（別れの場面の途中で閉じると解散していない状態で戻る＝やり直せるので害は小さい・そのまま）・§9（要確認のみ）・§10（未使用の関数が残るだけ）。
