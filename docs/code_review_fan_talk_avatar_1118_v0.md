# コード点検：FanReportData / TalkParts / CharacterAvatars / ComboKindPickerView（2026-11-18・読み取り専用）
結論：落ちる穴・乱数消費・男性語の固定は見つからず。残るのは「観客の声が予選前提の文言のまま決勝・道中大会・最終年にも出る」状況ずれ（表示だけで直せる）。
対象：ManzaiGame/Sources の上記4ファイル＋呼び出し側 TournamentResultView.swift:53-64,337 / GameSession.swift:138-145。過去点検（curtain_fan_1117・minor5_1117・endings_meta_1117・store4_1116・cands4_1109）を先に確認。

| # | 重さ | 場所 | 状態→結果 | 直し方の案 | 既知? |
|---|---|---|---|---|---|
| 1 | 中（要確認） | FanReportData.swift:114,152,154,171,195,211,248,329,367,370（＋72「今年の予選」）／呼び出し TournamentResultView:337 | 声は準決勝（needsAnnounce）と HANA1回戦以外の全結果で流れる＝GP決勝・HANA決勝・道中の単発大会でも「今日の予選で…」「予選なのに決勝みたいな熱」「次の予選での伸び」と出る。決勝の結果なのに予選と言う食い違い | 「予選」を含む文を `prelimOnly` 集合にして、決勝（GP決勝・HANA決勝）と道中単発では除外（knownOnly と同じ事前フィルタ方式）。または「予選」→「今日の舞台」等の言い換え | 新規 |
| 2 | 中（要確認） | FanReportData.swift:142「来年も予選に通おうと決めた」・:248「次の予選での伸び」 | voices は最終年（session.year >= config.careerYears）を知らない。最終年の通過後に「来年も」が出る。無名プールにも入っている | voices に `finalYear: Bool` を渡し、「来年」「次の」を含む文を最終年は除外。または「来年も」→「また」 | 新規 |
| 3 | 低（要確認） | FanReportData.swift:67,72「4分」 | 1回戦などの短尺（NetaCatalog:60 では1回戦2分・準々〜決勝4分）でも「4分」と出る | 「4分」→「あの数分」等。または 2 と同じ除外集合に入れる | 新規 |
| 4 | 低 | GameSession.swift:138-145 ＋ FanReportData.voices | 結果画面で声を出した後に中断セーブ→再開すると、cache は保存されず usedFanLines に今の声が入っている＝再開後は別の声になる（表示のみ） | 実害小。直すなら cache を SaveData へ | 既知（curtain_fan_1117 低） |
| 5 | 低 | FanReportData.swift:55-58 burst の n==0 | guard 済みで0除算なし | 不要 | 既知（修正済み） |
| 6 | 低 | CharacterAvatars.swift:79 CharacterFace 自体に読み上げ指定なし | TalkBubble は combine＋label、Picker のカードは label で包む＝問題なし。FinalsBroadcastIntro:186 は呼び出し側で扱い済み（cands4 #5）。他に単独使用なし | 不要 | 既知 |
| 7 | 低 | ComboKindPickerView.swift:39 | 読み上げ「女にした」問題は修正済み（コメント）。0.3秒の asyncAfter は取り消し不可だが、picked ガードで onSelect は1回のみ | 不要 | 既知（minor5 #5） |

## 確認済み（問題なし）
- ①落ちる穴：FanReportData は全て `((x % n)+n)%n` ＋ `guard n>0`。`lines.count>=2`・`.first ??` で添字／空配列安全。強制アンラップ・Int 変換なし。TalkParts・CharacterAvatars・Picker は配列添字なし（Picker は order 固定4）。TournamentResultView:56 の `results.last!` は pump の guard で保証（既知）。
- ②乱数：FanReportData は salt（year*131+week）の剰余だけ＝GameCore の RNG 非消費。fanVoices は key で cache し、再描画で変わらない。同じ key は同週1結果のみ。
- ③男性語：声の文に「俺・僕・男」は無し（grep 0件）。TalkBubble/NameTag の「俺」は Text(String)→Names.show 経由で女性形へ置換。顔は FaceCatalog.speaker が Names.kind で女性版を引く（4種すべて対応）。無名プールは「去年・いつも・前に見た」を knownOnly で除外済み（孤児なし・テストあり）。ただし misPass/misFail は knownOnly の対象外で、「去年・いつも」を含む文は無し（確認済み）。
- ④セーブ：声の cache 以外に再開で消える表示なし（#4 のみ）。
- ⑤動き：AdvanceCue は reduceMotion で止まり Theme.Motion.r も通る。Picker は二度押しを picked でガード。runFanVoices は Task.isCancelled・skipRequested を毎50msで見る。
- ⑥VoiceOver：▼は accessibilityHidden、TalkBubble は combine＋label、Picker は見出し trait・選択 trait・ラベル付き。
- ⑦実名：実在の大会名・芸人名なし（架空SNS「ヒトコエ」・審査員は架空）。
