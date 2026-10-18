# 不具合調査: 「バイトを押したのに日常イベントが先に出て実行されない」(onboarding_audit_v1 #5)

## 結論
**押した行動は捨てられていない。** バイトは先に実行され、出ていたのは「次の週の頭」のイベントだった。GameCore の変更は不要・golden/乱数順は不変。

## 原因（読み取り＋実測）
- 順番: `WeekMainView.perform` → `GameSession.choose` → `runner.resolveAction`（行動を適用）→ `proceed` → `pump()` →（次の週の .freeAction に着いた時点で）`evaluateChoiceEventFire()` がイベントを立てる。つまりイベントは行動の「後」、新しい週の頭に立つ。
- 画面側は Beat2（獲得バースト）が終わるまでイベントの cover を待たせる。見た目は「バイトを押す→イベントが出る」ので、押した週にイベントが割り込んだように見える（実際は週が1つ進んでいる）。
- 実測（iPhone 17・MZ_SMOKE=actiontrace・毎週バイト）: w1→w2 所持金 300000→364000、w2→w3 364000→428000（体力 80→60）で、w2 のバイトは実行済み。イベント earlyFormality はその直後（第3週の頭）に立った。
- 本物の取りこぼしが1点: 保留イベントが立っているのに cover がまだ出ていない短い間（Beat2 直後・0.3秒の同期待ち）に行動カードを押すと、`guard ... pendingChoiceEvent == nil` で黙って無視される。これが「押したのに無視された」感の正体の可能性。

## 直し
- `WeekMainView.swift` の行動カード2か所（actionCard・もう一方のカード）のガードで、弾く時に `syncEventPresentation()` を呼ぶ（UIのみ・保留があれば即 cover を出す。GameCore・乱数・golden 無関係）。
- 調査用に DEBUG の `MZ_SMOKE=actiontrace`（RootView/GameSession.debugActionTrace）を追加。
- 検証: GameCore swift test green・xcodebuild error なし。
## 残る案（要相談）
- イベント cover に「今週のバイトは済んでいる／新しい週の話」を一言出す、または週スタンプを先に見せる。
