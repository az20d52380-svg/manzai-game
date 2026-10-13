# Swift 直近変更レビュー（2026-10-14）

対象：2026-10-13 以降の Swift 変更 38コミット（31ファイル）。コードは触っていない。確認は差分読みのみ（ビルド・実機は未実施）。

## §0 要点
- 致命的なもの（クラッシュ・golden 破壊・旧セーブ非互換）は見つからなかった。
- 実害候補は3件（中）：「客席から」観た決勝が記録で「休」の判になる／ネタを書く画面の「替える・新しく書く」を押しただけで勝負ネタが外れる／ICレコーダー所持者の効果が喫茶店・ファミレスで消える。
- 低は3件。

## §1 指摘の表

| # | ファイル:行 | 何が | どう壊れるか | 確度 |
|---|---|---|---|---|
| 1 | ManzaiGame/Sources/NotebookView.swift（kirokuPage の `let mark =`、約188行） | 優勝行の判定が `contains("優勝") && !contains("客席")`。客席版の行 `第N週: 頂GP決勝 優勝「組名」（客席から）` は「優勝」を含むが「客席」も含むので除外され、次の通過／敗退も含まないため最終的に「休」になる | 自分が決勝に出なかった年（観客版決勝を観た年）の「大会の記録」に、他組の優勝が灰色の「休」判で並ぶ。コメントは「従来どおり」だが、休（体調ダウン）の判と見分けがつかない。「客席」行は専用表示（例：判なし／「観戦」）にするのが筋 | 中 |
| 2 | ManzaiGame/Sources/WeekMainView.swift（netaPicker 内 `session.selectNeta(n.id)`／「新しく書く」の `session.selectNeta(nil)`、約540〜575行） | 「書くネタ」を替えるだけの操作が、本番にかける「勝負ネタ」（selectedNetaID）を即座に書き換える。「新しく書く」は nil にする | 「新しく書く」を押して「もどる」で出ると、何も書かないまま勝負ネタが未選択になる（週は進まない）。本番の netaScoreBonus に使うネタが外れる。別ネタに「替える」だけでも勝負ネタが入れ替わる。旧UIは書く実行の時にだけ選択を変えていた | 中 |
| 3 | GameCore/Sources/GameCore/GameEngine.swift:92 | ICレコーダーの加算が `t == .ネタ作り` のみ。新設の `.喫茶店で書く`／`.ファミレスで書く` は対象外 | 販売停止の方針は「持っている人の効果は残す」だが、所持者が喫茶店・ファミレスで書くと、レコーダー分（閃き+）が付かず家で書くより主効果が下がる場合がある（家 3+bonus ／ 喫茶店 4.5 ／ ファミレス 4）。`GameConfig.netaWriteTrainings.contains(t)` にするかは設計判断（golden は hasRecorder=nil なので不変） | 中 |
| 4 | ManzaiGame/Sources/GameSession.swift:212 `applyNetaWork(for: action)` | 後段フックに渡すのは choose 入口の action。resolveAction 内で体調ダウン（injury）・体力ゲートで休養に差し替わった週や、お金不足で `applyTraining` が false になって休養に落ちた週でも、ネタの完成度が上がる／新ネタが作られる | 体調ダウンの週に「喫茶店で書く」を選ぶと、代金は払われず（休養扱い）なのにネタ完成度 +10 が付く。お金不足は UI が弾くので実害は主に injury 抽選。既存挙動だが、場所ごとに +10〜12 になって差が目立つ | 低 |
| 5 | ManzaiGame/Sources/TournamentResultView.swift（`r.burst == true` のファンレポ） | ハマった夜の一言は通過・敗退を問わず出る。文言は「神回」「客席と完全に噛み合ってた」等 | ハマっても点が足りず敗退した回で、判・紙講評が敗退なのに観客が「神回」と言う。見える運の意図どおりなら問題なし（要判断） | 低 |
| 6 | ManzaiGame/Sources/WeekMainView.swift（cardTint、約776行） | 紫（cIdea）の色分けが `.train(.ネタ作り)` だけ | 喫茶店・ファミレスで書くカードだけ別色（cExpr）になり、ネタを書く系の色が揃わない。表示のみ | 低 |

## §2 問題なしと確認した主な所
- 乱数・golden：`GameEngine.perform` の戻り値に `burst` を足しただけ。draw は従来どおり 2 回（roll→burst 判定）で順序不変。`burst` は表示専用。`StageResult.burst` は Optional で、旧セーブは復号できる。
- 旧セーブ：`StageResult.burst`・`YearRecord.enteredGP` は Optional（nil＝旧データ）。`Training`／`Rest` は associated value なしの enum なので、case を足しても既存値は復号できる。
- 剰余の安全性：FanReportData／DialogueData／FinalsTalk／JudgeData の salt 選択はすべて `((salt % n) + n) % n` で、空プールのガードもある。`year &* 131 &+ week` は正で、溢れも `&*`／`&+` で安全（TournamentResultView の `summary.year * 131 + summary.week` も範囲内）。
- 有料の休み：`applyRest` は代金を払えなければ完全休養に落とし、払えた時だけ引く。`previewState` も同じ関数を通る。CommandCatalog の `affordable` と整合。
- 有料の稽古：`applyTraining` は cost > money で false を返し、`resolveAction` が休養にフォールバックする（UI でも「お金が足りない」で弾く）。
- お店：`canBuy` が `shopLineup` を見て、ShopView も同じ配列で並べる。能力に効く4品は買えないが、所持者の効果は残る。
- 不出場の判定：YearRecord.enteredGP は「roundsPassed>0／決勝／優勝／ログに GP1回戦の行あり」。1回戦で負けた年は `summarize` が「GP1回戦 敗退」を出すので誤判定しない。YearResultView.notEnteredGP も同じ根拠（ログは年ごとにリセット）。
- ノートの優勝行の判：「第N週: 頂GP決勝 優勝 +100万」は優勝判（朱）になる。
- ファミレス・喫茶店の `netaPlaceGain`：`applyNetaRevise(id:gain:)` の clamp 0...100 は維持。
- 審査員の講評：`lowOnly` の除外は `high` の時のみ。最高点側が空プールになる帯はない。`pickups` の辞書キーは本文と一致。
- 影を `.background(shape.fill.shadow)` に付け替えた変更：レイアウト影響なし。
- イベント題名の変更：題名は表示専用で、ID・セーブのキーには使っていない。
- 未確認（目視要）：IntroFlow の回想カードで吹き出し3つを縦積みした時に、小さい端末で収まるか。
