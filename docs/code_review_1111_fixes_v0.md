# コードレビュー：dde0ecdc2（toast 取り消し）／4d6a62537（週替わりの後始末3か所）v0 — 2026-11-11

結論：**具体的な手順で誤動作を示せる指摘は 0 件。** 下は確認した経路と、残る低リスクの観察（指摘ではない）。

## 確認した経路（問題なし）
- RootView.swift:428-433 — WeekMainView は `session.phase` が `.freeAction` の時だけ置かれ、大会入口・GP・結果・決勝へ移ると**ビューごと破棄**（@State も消える）。大会週・年末・セーブ復元（GameSession.swift:332 は装飾を復元しない）では、戻った時に `.task(id: session.week)` が**初回起動として新規に走る**＝取り消しは起きず、後始末が走らない／走りすぎる経路はない。取り消しが起きるのは「freeAction のまま週が替わった」時だけで、そこが今回の直しの対象。
- WeekMainView.swift:326-334（toast）— 取り消されるのは (a) 別の文に替わった (b) nil にされた (c) ビュー破棄。(a) 新しい task が新しい文の時間で動く（旧は消さない＝直った）。(b) task が再起動して t==nil で何もしない。(c) 状態ごと消える。ビュー破棄後に古い toast が残って再表示される経路はない。
- YoseGameParts.swift:262-270 — `.task(id: m)` は if-let 内の同一位置なので文が替わると再起動（旧は取り消し・消さない）。nil になれば要素ごと消える。`catch {}` が握るのは CancellationError のみ（sleep は他の throw をしない）。
- WeekMainView.swift:267-271（初回説明）— `try?` の後に `guard !Task.isCancelled` なので、週が替わって取り消された旧タスクは maybeShowFirstHints を呼ばない。新週のタスクが自分で 2.2 秒後に呼ぶ＝抜けない。onAppear（:264）・pendingChoiceEvent（:250）側の呼び出しは別経路で残っている。
- :273-279（伸びの色）・:312-318（第N週の札）— 旧タスクが新週の `true` を後から `false` に落とす競合が消えた。札は新タスクが必ず自分の 0.7 秒後に false にするので残り続けない。
- メインスレッド：`.task` はビューの MainActor 上、`Task.isCancelled` は同期読みで追加の競合なし。

## 残る低リスクの観察（指摘としては出さない）
- WeekMainView.swift:278 — 週が変わって取り消された時、旧タスクが立てた `gainsVisible = true` は、新週の lastGains が空（かつ相性増分 0）だと false に戻らず true のまま残る（新週のタスクは if の外で何もしないため）。ただし statBar（:562）は `session.lastDeltaWeek == session.week` かつ gainFill>0 の時だけ朱を出し、gainFill は lastGains 由来（:587-590）なので、lastGains が空なら画面には出ない。lastGains は週送りでしか更新されない（GameSession.swift:387 / :1179 リセット）ため、次の週送りで新タスクが true→false を回すまで表示に影響しない。重大度：低（実害なし）／確信度：中。気になるなら新週側で else 節に `gainsVisible = false` を入れるだけで消える。
- toast：同じ文字列を表示中にもう一度 `toast = 同文` にすると id が変わらず task が再起動しない（延長されない）。今回の差分で生じたものではなく従来から（直しの前から同じ）。重大度：低／確信度：高。

## 指摘件数
高 0／中 0／低 0（観察 2 件は上記のみ）
