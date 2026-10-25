# 暦の言葉の食い違い 10/26 v0

## 要点
- ゲームの1年は4月始まり（CalendarView: 第1週=4月・4週で1か月）。頂GP 決勝は第47週＝3月、年末総決算は第48週＝3月末。一方「年末のライブ」(0057) は12月＝第33〜36週。
- そのため第48週の画面・独白にある「正月」「年明け」「年の瀬」、エンディングの「十二月の終わり」が、カレンダーの月と食い違う。
- 10/26 済：年の幕間の札「新春の備え」→「新年度の備え」（4月始まりに合わせた表示だけ）。

## 該当（grep・文字列のみ）
- ManzaiGame/Sources/WeekMainView.swift:1579:                showToast("もう一度押すと、残りの週を休んで年末の結果へ進む。")
- ManzaiGame/Sources/WeekMainView.swift:1589:                Text(yearEndArmed ? "もう一度" : "年末へ").font(YoseFont.gothic(14, weight: .heavy)).foregroun
- ManzaiGame/Sources/WeekMainView.swift:1598:        .accessibilityLabel(yearEndArmed ? "もう一度押すと年末の結果へ進む" : "年末へ")
- ManzaiGame/Sources/WeekMainView.swift:1599:        .accessibilityHint("二度押しで、残りの週を休んで年末の結果へ進む")
- ManzaiGame/Sources/WeekMainView.swift:1619:        nextMilestone() ?? (name: "年末", weeksLeft: session.config.weeks - session.week)
- ManzaiGame/Sources/Endings.swift:130:                c("十二月の終わり。{me}のアパート。", bg: EventBackdrop(.apartment,.evening), [("谷口", "�
- ManzaiGame/Sources/Endings.swift:131:                c("年明け。バイト先の休憩室。", mood: .noon, bg: EventBackdrop(.office,.day), [("布施店長"
- ManzaiGame/Sources/Endings.swift:138:                c("年末。小さな劇場の楽屋。", bg: EventBackdrop(.gakuya,.evening), [("谷口", "来年のグラ
- ManzaiGame/Sources/Endings.swift:144:                c("十二月。事務所の会議室。", mood: .noon, bg: EventBackdrop(.office,.day), [("真壁", "来年
- ManzaiGame/Sources/Endings.swift:152:                c("年末。最初に二人で出た劇場。", bg: EventBackdrop(.theater,.evening), [("谷口", "ここ�
- ManzaiGame/Sources/ChoiceEventData.swift:952:            Advice(name: nil, text: "アパートの部屋。年末の夕方。"),
- ManzaiGame/Sources/ChoiceEventData.swift:953:            Advice(name: "母", text: "お正月は帰ってくるの？ お父さん、毎日カレンダーを見
- ManzaiGame/Sources/ChoiceEventData.swift:959:            "A": "正月は実家に帰る",
- ManzaiGame/Sources/ChoiceEventData.swift:971:                Advice(name: "谷口", text: "じゃあ、正月も稽古だね。お母さんには、ちゃんと
- ManzaiGame/Sources/ChoiceEventData.swift:1208:        title: "年末のライブ",
- ManzaiGame/Sources/ChoiceEventData.swift:1210:            Advice(name: nil, text: "劇場の楽屋。年末のライブが終わった夜。"),
- ManzaiGame/Sources/YearResultView.swift:26:            YoseHeaderBar(title: "\(session.year)年目 年末総決算", subtitle: session.combiName)
- ManzaiGame/Sources/YearResultView.swift:380:        "一年目が終わった。年明けは少し休んで、また動こう。",
- ManzaiGame/Sources/YearResultView.swift:383:        "今年は、負けて帰る日が多かった。正月くらいは、ゆっくり休もう。",
- ManzaiGame/Sources/YearResultView.swift:401:        "バイト先の人たちが、大会を気にかけてくれた。年明けに、何か持っていこう�
- ManzaiGame/Sources/YearResultView.swift:403:        "今年は、お客さんの前に立つ日が多かった。年明けも、体だけは大事にしよう�
- ManzaiGame/Sources/YearResultView.swift:404:        "高校の同級生から、久しぶりに連絡が来た。年明けに、会いに行こう。",
- ManzaiGame/Sources/YearResultView.swift:405:        "次の舞台を、楽しみに待てる一年だった。年明けも、この気持ちでいよう。",
- ManzaiGame/Sources/YearResultView.swift:408:        "年の瀬に、谷口と並んで帰り道を歩いた。来年も、二人で行けるところまで行�
- ManzaiGame/Sources/YearResultView.swift:420:        "今年は、負けて帰る日が多かった。正月くらいは、ゆっくり休もう。",
- ManzaiGame/Sources/YearResultView.swift:430:        "一年目が終わった。年明けは少し休んで、また動こう。",

## 案（オーナー判断）
1. 今のまま（「年末」＝その年の区切り、と読む）
2. カレンダーの月を合わせる（第1週＝1月にして決勝を12月へ寄せる）＝表示の月だけ替える。イベントの月の条件（夏祭り7〜8月・年末のライブ12月）も読み替えが要る
3. 第48週の言葉を「年度末」寄りに直す（正月・年明け・年の瀬・十二月を外す／言い換える）＝台詞の書き直し

推奨：2（漫才の大会の決勝は年末という感覚に合う・画面の「年末総決算」とも揃う）。ただし月の条件を持つイベントの読み替えを伴うので、決めてから点検する。
- 画面での確認（10/26）：10年目のカレンダー（MZ_UI=calendar MZ_YEARS=9 MZ_CARE=1 MZ_STOPWEEK=40）で頂GP 決勝が「3月 第3週」の欄にある。
- 10/26 済：0049 ライブのチケット（知名度30未満ならどの週でも出る）の谷口「寒いけど、」を外した（夏にも出るため・文は足していない）。他の季節の言葉（夏祭り0051＝7〜8月限定・母からの電話0047＝第38週以降）は出る月と合っている。
- 追記：お店の注記「回数に限りがあるものは、年が明けると戻ります」（ShopView.swift:25）も同じ論点（実際に戻るのは4月の第1週）。案3なら「新しい年（4月）になると戻ります」等。

## 材料（10/26 追記）：月に結びついた物を、今の暦（4月始まり）と案②（1月始まり）で並べる
| 物 | 週 | 今（4月始まり） | 案②（1月始まり） |
|---|---|---|---|
| 春新人賞A | 12 | 6月 | 3月 |
| 春新人賞B | 15 | 7月 | 4月 |
| 夏中堅賞 | 27 | 10月 | 7月 |
| 大阪戎コンクール | 29 | 11月 | 8月 |
| 頂GP 1回戦 | 30 | 11月 | 8月 |
| 若手限定賞 | 35 | 12月 | 9月 |
| 推薦制中堅賞 | 38 | 1月 | 10月 |
| 頂GP 2回戦 | 39 | 1月 | 10月 |
| 頂GP 準決勝 | 45 | 3月 | 12月 |
| 寒梅漫才杯 | 46 | 3月 | 12月 |
| 頂GP 決勝 | 47 | 3月 | 12月 |
| （イベント）夏祭りの営業 0051 | 14 | 7月 | 4月 |
| （イベント）夏祭りの営業 0051 の終わり | 20 | 8月 | 5月 |
| （イベント）年末のライブ 0057 | 33 | 12月 | 9月 |
| （イベント）母からの電話 0047 の始まり | 38 | 1月 | 10月 |

- 読み取り：**大会の名前は1月始まりの方が季節に合う**（春新人賞＝3〜4月・夏中堅賞＝7月・頂GP 1回戦＝8月・決勝＝12月）。今の4月始まりでは「春新人賞」が6〜7月、「夏中堅賞」が10月になり、名前と月がずれている。
- 一方、イベントの月の条件（夏祭り＝週14〜20、年末のライブ＝週33〜36、母からの電話＝週38〜）は4月始まりで書かれている。案②にするなら、この3つの週の条件を読み替える（夏祭り→週27〜32 前後・年末のライブ→週45〜48・母からの電話→週1〜4 か週45〜）。
- 画面で月を出しているのは CalendarView の monthLabel（`(3 + row) % 12 + 1`）だけ。案②は表示の式1か所＋イベントの週の条件3つ（GameCore・乱数を引かない UI 側の条件か要確認）＋お店の注記で済む見込み。
