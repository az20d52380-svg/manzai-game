# コードレビュー結果 1117（TournamentResultView / YearResultView）v0

## 要点3行
- クラッシュ・二重進行・取り消し後の状態変更に当たる実バグは見つからなかった（高・中は 0 件）。
- 低が3件・要確認が2件。最終年（15年目）の年末独白に「年明け」系の行が残る点が文言の矛盾として一番目立つ。
- 既出（U+2060 の読み上げ・「次へ 進む」の空白・abandon 後の再表示）は judged 済みとして除外した。

## §1 件数
高 0／中 0／低 3／要確認 2

## §2 指摘
### 低-1 最終年の年末独白に「年明け」行が残る
- 場所：YearResultView.swift:371 付近（yearEndLine の careerOver／careerYears 分岐）と yeLeap／yeStall／loseLeaning の本文
- 手順：15年目（careerYears）の年末。「来年」を含む行は外すが、「年明けに、会いに行こう」「年が明けたら、飯に誘おう」「年明けも、体だけは…」「正月くらいは」などが残り、続きが無いキャリアの終わりと食い違う。
- 直し：careerOver／最終年の時は「来年」に加えて「年明け」「年が明け」「正月」も外す（外して空なら元のまま、は現状と同じ形）。

### 低-2 THE HANA 優勝の「次へ 進む」連打で優勝音が二重に鳴る
- 場所：TournamentResultView.swift:176〜180（`r.passed && isHanaFinal` の分岐）
- 手順：ボタンを素早く2回押すと、覆い（showHanaChamp）が出る前に Sound.play(.fanfare)／.cheerBig が2回走る。進行は acknowledgeResult の `pendingResult != nil` ガードで1回のまま（週は2つ進まない）。音だけ。
- 直し：分岐の頭で `guard !showHanaChamp`。

### 低-3 アプリ再起動で結果画面を復元すると「知名度／経験点」の札が出ない
- 場所：TournamentResultView.swift settlementCard／expGainRow が読む GameSession.swift:47・49（lastResultFameDelta／lastResultExpDelta は保存されない）。復元は GameSession.swift:304。
- 手順：結果画面の最中に終了→再起動。賞金は r.prize から出るが、知名度の伸びと経験点は 0 扱いで札が消える。
- 直し：表示専用なので許容でもよい。直すなら pendingResult と一緒に保存する。判断はオーナー。

### 要確認-1 HANA の勝敗が年末独白の「勝ち越し」判定に混ざる
- 場所：YearResultView.swift:stageRecord（`part.contains(" 通過")`／" 敗退" を HANA の行も数える）
- 手順：女性コンビで HANA を勝ち上がった年は、頂GP の戦績より勝ちが増え、負けを語る独白が外れやすい。意図（大会全体の勝ち負け）なら問題なし。
- 直し：意図が「頂GP だけ」なら行頭の大会名で HANA を除く。

### 要確認-2 観客の声のキャッシュが同じ週の2結果で使い回される可能性
- 場所：GameSession.swift:138（fanVoiceCache の key は year*131+week のみ）
- 手順：同じ週に結果画面が2回出る場合（敗者復活と決勝が同日＝週47）、2回目も1回目の声（passed／margin が違う）が返る。決勝は FinalsPresentationView 側で見せるのでこの画面を通らなければ実害なし。週ごとに結果が1つであることは未確認。
- 直し：key に r.name のハッシュを混ぜる。

## §3 問題なしと確かめた所
- `summary.results.last!`（TournamentResultView:60）：pump の `!big.isEmpty` ガード済み。復元時も GameSession.swift:304 で空は nil にしている。
- 二度押し：acknowledgeResult は `pendingResult != nil` ガード（GameSession.swift:1004）。山場の最後のページの二度タップ・showPass 経由も1回だけ。advanceAuto／decideTournament／startNextYear／retireAfterWin もガードあり。
- 添字：climaxOverlay は min(i, count-1)、`for i in 1...n` は n>0 を確認、reachLabel／reachStamp の names[n] は n<count を確認、fanVoices.prefix は安全。
- 取り消し：runReveal は try? の直後に Task.isCancelled を見て戻る。finishReveal は revealTask を取り消して値を直接立てる。YearResultView の `.task` も取り消し後は return。nextArmed の Task は画面が消えた後に @State を立てるだけで無害。
- 最終年の語：onNextYear は careerOver（year >= careerYears）で nil。「N+1年目へ」は最終年に出ない。ClimaxData.pages は finalYear で「来年は」を「悔しいね」に切り替え済み。
- 名称：頂GP（GPName.display・「頂グランプリ」札）と THE HANA（isHana で札を重ねない・「THE HANA 決勝」）は混ざっていない。
- 知名度・賞金の週：lastResultFameDelta は decideTournament／advanceAuto が pump の後に毎回更新（古い大会の値は残らない）。
- VoiceOver：覆い用のタップ面は accessibilityHidden、「▼ 下にも続きます」も隠し済み。経験点行は combine。
