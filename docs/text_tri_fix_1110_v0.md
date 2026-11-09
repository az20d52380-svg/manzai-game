# 今日の採点の△の直し（判断の要らない物）v0

候補ブランチ claude/text-tri-1110-cand。文字列だけ・ロジック/数値は不変。アプリ402テスト失敗0。

## 直した行（10か所・9件）
- WeekMainView:472 「…能力アップで使おう」→「…使おう。」（weekmain B）
- WeekMainView:1035・SettingsView:252 「未振分あり」→「未振り分け」（weekmain B）
- QualifierNoticeView:129 読み上げ「あなたたち」→「あなた」（qualifier_shop_calendar_intro §3）
- TournamentResultView:84 「——固い空気…」→「——固い空気。」（tournament_result §3-3）
- NotebookView:387 入力欄「題材名」→「題名」（notebook_abilityup §3-3）
- GachaView:64 「天井ポイント40と交換」→「40ポイントと交換」、:170 読み上げ「回」→「ポイント」（gacha B）
- CommandData:89 サウナ「家よりよく休める」→「しっかり休める（有料）」（session_command B）
- CommandData:44・62 相方と合わせる「二人で合わせる」→「二人で何度もやってみる」（同上）

## 入れなかった△（理由）
- weekmain 1026/907/987/1514/723/781/1587/969：論点／設計
- weekmain 1505：台詞（谷口）
- settings 235・261・255・236・275：既に直し済み／新情報／論点
- settings 249・260：論点
- gacha 109-111：不明確・116：別候補待ち・136：【仮】
- notebook 持ち分：論点・客の反応：用語集と連動・戻る→閉じる：文脈不明
- finals・scene_ending・small_text：論点のみ／なし
- qualifier 週・部屋の長文：論点／既に分割済み
- session ネタ名・ボイトレ：判断
- tournament 判子・662：論点／新台詞
