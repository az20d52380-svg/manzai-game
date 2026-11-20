# コード点検 年変わり幕間・ファンレポ・レーダー・会話部品・出会い方（2026-11-17・読み取りのみ）

対象：Design/YoseYearTurnCurtain.swift・FanReportData.swift・RadarChart.swift・TalkParts.swift・MeetingKind.swift（ManzaiGame/Sources）。呼び出し側は RootView:381/401・YearResultView:222/240・TournamentResultView:55-63・GameSession:138・IntroFlow:696。
結論：高 0・中 0・低 3・要確認 2。落ちる穴・年週の前提ずれ・女性形の男性語・ゲーム乱数の消費はいずれも見つからず。

## 指摘

| 重さ | 場所 | 何が起きるか | 直し案 | 既知 |
|---|---|---|---|---|
| 要確認 | RadarChart.swift:100-104, 120-121 | `progress` を `withAnimation` で 0→1 にしているが、Canvas の中身は SwiftUI が補間しない（Canvas は Animatable ではない）。年初→現在へ0.8秒でモーフするはずが、実機では最初から最終形が一瞬で出る可能性。表示のみ・落ちない。 | 実機で目視。補間されないなら `Animatable` な Shape（animatableData=progress）に切り出す、または TimelineView で描く。 | 新規（設計 uiux_vision_reply_part2 は「モーフ」を意図） |
| 要確認 | YoseYearTurnCurtain.swift:139-141 | `.task` は同じ View が出入りで再入すると演出を頭から再実行する（幕は開いたまま・触覚と火花が二重に鳴る）。今の呼び出しは `if let s = yearTurn` で毎回新規生成＝再入しない。YoseFXPreview も同様。将来 overlay を常駐にした場合だけ。 | 変更不要。常駐化するなら `.task` 冒頭で `guard curtainClosed`。 | 近い既知：code_review_1107e（二重タップ）・19l §1-3（取り消し） |
| 低 | FanReportData.swift:55-58 | `burst()` の `pool.count` が 0 だと `% n` で0除算。`burstLinesUnknown` は burstLines を絞った物で、今は絞り後も残る。将来 knownOnly を増やして全部が該当すると落ちる。`voices()` 側は `guard n>0`（:422）で安全。 | `guard n > 0 else { return "" }` を足す。 | 新規 |
| 低 | GameSession.swift:138-145 ＋ FanReportData.voices | 結果画面で声を出した後に中断セーブ→再開すると、`usedFanLines` には今の声が入っているが `fanVoiceCache` は保存されない。再開後は「使い済み」扱いで別の声が選ばれ、見ていた声と変わる。表示のみ。 | 実害小。直すなら cache の key と lines も SaveData へ。 | 新規（usedFanLines の上限600は code_review_1107g で既知） |
| 低 | RadarChart.swift:96,101-102,110-111 | 割合は上を `min(1,…)` で止めるが下は止めない。能力がマイナスなら多角形が中心を越えて反対側へ。今の仕様では能力は0以上のため起きない。`/ cap` は cap≥30 で0割なし。 | `max(0, …)` を足すと堅い。 | 0割の件は既知（1108c・19k・25d） |
| 低 | YoseYearTurnCurtain.swift:431 | `compactYen` の `-yen` は Int.min で桁あふれ。所持金は現実の範囲では届かない。 | 不要。 | 新規（実害なし） |

## 確認して問題なしだった所（観点別）

1. 落ちる穴：幕間の `ForEach(0..<18/5/14)` は定数長＋`colors[idx % colors.count]`（空でない定数配列）。`kanjiNumber` は n<0→max(0)・20以上は桁ごと＋`?? 0`。`RadarChart` は `guard n >= 3`・`1...max(1, weeks)`。TalkParts・MeetingKind に添字・強制アンラップなし。`debugForced` は `indices.contains(n-1)` で守り済み。`FanReportData` の剰余は全て `((x % n)+n)%n` で負数も可。
2. 年・週：キャリア15年。幕間が出るのは最終年以外（RootView:431 `careerOver ? nil : beginYearTurn`）なので newYear の最大は15＝「十五」（フォント76pt・幅196に収まる）。「4月・第1週」は1年48週（12か月×4週）と合う。ActionBreakdownBand は `session.config.weeks`＝48で10年前提なし。`isKnown` は year>=2（2年目以降）で15年まで通る。`salt = year*131+week` は week≤48 なので年またぎの衝突なし。
3. 後始末：幕間は Task.sleep の各段を `guard await pause(...)` で取り消し検知（閉じたら触覚・揺れを止める）。`hasTriggeredStart` で二重発火なし。`AdvanceCue` の `repeatForever` は `reduceMotion` で止まり、画面が消えれば View ごと破棄される。`ActionBreakdownBand` は onAppear の再入で `grow=1` を再代入するだけで無害。
4. 性別・乱数：`TalkBubble`・`NameTag`・`SpeakerStyle` の「俺」は `Text(String)` が `Names.show` を通る（Names.swift:52）ため、女性形では「私」に置換される。MeetingKind の台詞は語尾が男女どちらでも通る形で、一人称は `{me}`（:82）か話者札のみ。FanReportData の一人称は「私」だけ（女性形でも通る）。乱数：`FanReportData`・`MeetingKind` は salt 剰余のみで RNG 非消費（`usedFanLines`/`fanVoiceCache` は `@ObservationIgnored`）。IntroFlow:696 の `randomElement()` はシステム乱数で GameSession の RNG 外（結成前・表示専用）。
