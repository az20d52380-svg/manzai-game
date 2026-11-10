# 候補3本の点検（正しさのバグ観点・1110c）

基準: origin/claude/manzai-slg-foundation-wprqlu。コード変更・ビルド・テストはしていない（差分の読みだけ）。

## 1. broken-save-notice-cand（中断セーブの退避2枠＋タイトルのアラート）
結論: 重い問題なし。低2・補足1。

- 目視フック経由の誤表示: 問題なし。RootView.init は MZ_SMOKE/MZ_UI/MZ_ENDING で早期 return し、`showLoadFailedNotice` は既定 false のまま（`GameSession.lastLoadFailed` を読まない）。MZ_BG/MZ_FX は loadedOrNew を通る既存経路で、壊れたセーブが無ければ立たない。
- 毎回の起動で誤表示: 起きない。失敗時に本キーを removeObject するので次回起動は「無い」扱い。`loadedOrNew` 冒頭で false に戻すのでリセット漏れなし（テスト testFlagClearsOnCleanStart が固定）。
- 退避の順: 問題なし。prev != data の時だけ prev を .broken2 へ、新しいのを .broken へ。同一バイト列の連続は2枠目が汚れない。3回続けば最古は落ちる（アラート文「データは消さずに残してあります」は3回目以降は最古分だけ不正確・低）。
- 低（RootView.swift:27-30 init）: 静的フラグを init で読む作り。SwiftUI が RootView の init を2回走らせる場合（親の再評価）、1回目で true・2回目で false になり、採用された State 側が2回目の false だとアラートが出ない可能性。確実にしたいなら ManzaiGameApp 側で一度だけ読んで渡す／読んだら消費する形。実機で未確認。
- 低（GameSession.swift:約1908 の MZ_ALLOWSAVE 自己点検）: oldsave の後始末が .broken だけで .broken2 を消さない（DEBUG のみ・実害なし）。
- テスト: 退避2枠・フラグ立ち下がり・正常セーブで立たないを固定していて妥当。アラート表示自体（RootView）と早期 return 経路は未固定（スクショ docs/shots_1110_broken_save_notice.png のみ）。
- iCloud: セーブは UserDefaults のみで該当なし。

## 2. gacha-broken-backup-cand（gacha_state_v1.broken への1度だけの退避）
結論: 高なし。中1・低2。

- 中（GachaStore.swift init の `defaults.data(forKey: brokenKey) == nil` 条件）: 退避が「1度だけ」で、最初に退避したのが無関係なゴミだと、後で壊れた本物の台帳（購入記録）は退避されず次の persist で上書きされて消える。テストは「先に壊れた方を残す」ことを意図として固定しているが、先の退避が空/ゴミだった場合の救済策なし。2枠（セーブ側と同じ）か、デコード可能になった時点で .broken を消す等の検討余地。
- 低（iCloud）: 端末側が壊れ・iCloud 側が正常の時、state は iCloud から復元され退避も取られる＝良い。逆に iCloud 側だけ壊れ・端末が正常の時は退避されず、次の persist（mutate）で iCloud の値が上書きされる（端末が正常なので実害小）。両方壊れの時は iCloud 分は退避されない。
- 低（テスト）: `testUnreadableDataIsKeptAsideBeforeOverwrite` は退避が init 時点で取られることまでは見ておらず（mutate 後に見ているだけ）、順序（上書き前）は実質固定されていない。iCloud 経路（useCloud: true）のテストなし。
- 誤作動: 本キーが無い（新規インストール）では退避しない＝問題なし。判定は Self.decode と同じ GachaState デコードで食い違いなし。MZ_UI=gacha 等の目視フックも `.standard` の実データが壊れている時だけ退避が動く（想定どおり）。

## 3. meta-lenient-load-cand（最新コミット 75c8a10f）
重要な食い違い: 依頼の「EndingBook.record の書き戻しを JSONSerialization で1件だけ差し替える形」のコミットは、この枝の先端に無い（fetch 後も先端は 75c8a10f「1件・1鍵ずつ読む」。JSONSerialization の検索でも他に無し）。以下は先端の実コードへの指摘。

- 中（Endings.swift record、変更なし）: load が壊れた件を捨てて読み、record は load 結果の辞書を丸ごとエンコードして本キーへ書き戻す。結果、壊れた1件は次の record で盤面から消える（正しい件は残る）。「1件だけ差し替える」形（元の JSON の辞書を保ったまま該当キーだけ置換）には、まだなっていない。壊れた件が「新しい版で読める形」だった場合は救出不能。意図が「壊れた1件を保つ」なら未達、「他の件を守る」なら達成。
- Date の往復: 先端のコードは JSONEncoder→JSONDecoder の往復のみで、既定の Date 戦略（参照日からの秒数）同士なので load() は読める。JSONSerialization 差し替え形にする場合は、Date を Double（timeIntervalSinceReferenceDate）のまま扱わないと load() が読めない（ISO 文字列等にすると `JSONDecoder` 既定が失敗する）点に注意。
- LenientRecord（Endings.swift）: `try? EndingRecord(from: decoder)` は失敗しても throw しないので辞書全体は読める＝正しい。
- CareerRecords の独自 init(from:)（Meta.swift）: `try? decodeIfPresent ?? nil` は Swift5 の try? 平坦化で Int? に収まり問題なし。合成 init の置き換えは extension でも有効で、encode は合成のまま＝往復可。低: bestStreak/totalWins が型違いで 0 に戻る＝通算が静かに 0 から再計上される（欠落時の既定値としては許容）。
- テスト: 図鑑は「壊れた2件を捨て正しい1件が残る・record 後も残る」を固定。ただし壊れた1件が record 後に消えること（上記・中）は固定されていない。EndingID の rawValue（breakup/gaveUp/keptGoing/championPair）が実在するかは未確認（実在しないと assert が赤）。MZ_BOOKSEEN/MZ_RECORDS は XCTSkip で DEBUG フックと衝突しない。
