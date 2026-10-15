# コードレビュー 2026-10-16（preview-all の 10/15 18:00 以降・138コミットの新規コード）

対象: Endings / EndingViews / Names / FinalsBroadcastIntro / FinalsPresentationView / ChoiceEvent(0041〜0050・EventEffect.rift) / GameSession / WeekMainView / SettingsView / GameCore の rift（applyRiftWeekEnd・WeekRunner・YearOutcome Codable）。
検証: `swift test --package-path GameCore` 137件 green、`xcodebuild test`（iPhone 17）green（修正後）。GameCore の式・乱数・golden は未変更。

## §1 直した不具合（確実）
1. **名前の差し替え漏れ**（修正 d8f60a3）
   - `IntroFlow.swift:125` RecallScriptRow が `Text("\(name)「\(advice.text)」")`（文字列補間リテラル＝LocalizedStringKey 版）で、Names を通らない。ReminiscencePlayer は S6b とエンディング #2〜#8 の場面でも使うので、相方の名前を変えても過去の台詞行（直前の行）が「谷口」のまま出る（最後の1行だけ吹き出しで置換される＝同じ場面で名前が混ざる）。
   - `FinalsPresentationView.swift:1106` `Text("谷口が、そっと耳打ちした。")` はリテラルなので未置換。優勝後のト書き。
   - `TalkParts.swift:86`・`IntroFlow.swift:132` の `accessibilityLabel` が元の名前を読み上げる。
   - 再現: 設定でなく S1 で相方名を「ミツル」にして優勝 or エンディング #2 を見る。直し: `Names.show` を通す（`Text(verbatim:)`）。

## §2 直していない指摘（重い順）
1. **予告 0050 が「年末へ」で消える**（`GameSession.swift:800` fastForwardToYearEnd・`:893` startNextYear の `pendingChoiceEvent = nil`）。`didFireRiftWarn` は発火時に true になるので、保留中の予告を見送ると二度と出ず `riftWarnChoice` も nil のまま解散まで進みうる。直し案: 見送り経路で `.riftWarning` だけは捨てずに残す／または見送り時に didFireRiftWarn を戻す。発生は稀（予告が出た週に「年末へ」を押す）。
2. **GameEngine.swift:219-221**: `@discardableResult` と applyWeekEnd の説明コメントが、新設の `applyRiftWeekEnd` の直前に付いたまま（applyWeekEnd 側から外れた）。動作は同じだが、applyWeekEnd の戻り値を捨てる呼び出しに警告が出うる。属性とコメントを applyWeekEnd へ戻す（式は触らない）。
3. **WeekRunner(restoring:) の finalLine を config から取り直す**（A-4）ため、`finalLineOverride` 付きで作った runner の中断復元で上書きが失われる。アプリは override を使っていないので実害なし（テスト/シムのみ）。
4. **RootView.init が GameSession を毎回作る**（`RootView.swift:19,25`）。View の init が再実行されると、その副作用で `Names.set` が走る（セーブ無し＝既定名に戻る）。通常は1回だけなので実害は見えていない。直し案: Names.set を init から外し、adopt する側（RootView の started 切替）で一度だけ呼ぶ。
5. **WeekMainView `resultName`**（`:228` 付近）: `lastDeltaWeek != week` で早期 return する経路では resultName が消されず、次の行動以外で Beat2 が走ると古い行動名が結果札に出うる。直し: guard の else で `resultName = nil`。
6. **EndingFlowView**: `stage` の初期値が `.cards` で、S6b を通る #5/#8 は最初の1描画で ReminiscencePlayer が一瞬作られてから `.s6b` に替わる（見た目は1フレーム）。初期値を `usesS6b ? .s6b : …` にすると消える。

## §3 見て問題なしだった点
- セーブ: SaveData の新項目（debtWarnTier・myName・partnerName・didFireRiftWarn・riftWarnChoice・YearRecord.dissolved・GameState.rift 系）はすべて Optional で保存/復元される。YearOutcome は decodeIfPresent で旧セーブを読める。勝利演出中の中断（A-3）も復元で winFinale に戻る。
- 二重発火: 予告は `didFireRiftWarn`、借金の知らせは `debtWarnTier`（深い段へのみ前進）、初回説明は `mz.hint.*`（markDone）、図鑑は `recorded` ガード、番組の初回/短縮は `FinalsSeen.first` をボタン/タスクからのみ呼ぶ。UserDefaults キーに衝突なし（mz.endingsSeen / mz.hint.* / finals_bc_seen_* / finals_broadcast_intro_seen / stage_ceremony_seen / vol_* / notif_*）。
- 年またぎ: 年末週に riftWarned が立っても次年の最初の自由週で発火。yearHistory は pump の再入で二重に積まない（year ガード）。解散は careerOver・YearResultView・エンディング判定のすべてで扱われている。
- 決勝の番組化: 結果・点数・票順は `d.voteOrder`/`d.winnerIndex`/`d.entries` を読むだけで、書き換える式は無い。`voteOrder[revealVotes]` は `revealVotes < 7` ガード内。審査員 7 人・サーチライト 4 本の配列添字は範囲固定。acknowledgeWin/Result は `done` ガードで二重に呼ばれない。
- ゼロ割・force unwrap・メインスレッド外の更新: 新規コードに Task.detached / DispatchQueue.global は無く、割り算の分母は定数（compatCap）。
