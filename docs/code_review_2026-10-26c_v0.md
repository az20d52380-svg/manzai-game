# コード点検 2026-10-26c（a51216f..HEAD の Sources/Tests・読むだけ）

## §1 確実な不具合
なし。

## §2 たぶん（軽い）
1. 「最終年」の判定が careerOver と食い違う。
   - 場所：YearResultView.swift:346、TournamentResultView.swift:64、WeekMainView.swift:1506。いずれも `session.year >= session.config.careerYears`。
   - 本来の区切りは GameSession.swift:1056 の `careerOver`（優勝・夜逃げ・解散・careerYears年目の年末）。
   - 10年目より前に優勝・夜逃げ・解散で終わる年の年末には、「来年」の独白（YearResultView の385/406/408/422/423行）が残る。
   - 再現：MZ_YEARS=3 などで3年目に解散か夜逃げの年末を出す → 年末の独白に「来年は…」が出ることがある。
   - 直し案：YearResultView は `session.careerOver || year >= careerYears`（careerOver は outcome が要る＝年末画面なら立っている）。週メインの吹き出し（WeekMainView）は年末前なので現状のままでよい。
   - 影響は小さい。優勝は勇退の画面、夜逃げ・解散はエンディングに続く。
2. 他の「来年」が未処理。
   - S6bView.swift:157「うん。来年も、また出よう」は回想カード。過去の場面なので問題なし。
   - Endings.swift の keptGoing 系は、10年目を続ける結末なので意図どおり。
3. 敗者復活の最終年版は、`hasPrefix("悔しいね。来年は")` の文字列一致に頼る。
   - ClimaxData.revivalLoss の当該行の文言を直すと、切り替えが黙って効かなくなる。
   - 直し案：当該行の添字を固定するか、ClimaxPage に flag を持たせる。
   - テスト WeekendInviteVariantTests 付近の「行は切るだけ・ページ数は同じ」が先頭の一致を守っている（count 一致の検査あり）。ただし文言変更を落とす検査は無い。
4. gploss のループで30種すべて通過だと、最後の種（通過した結果）のまま画面が出る。
   - 失敗は画面が違うだけ（目視用のみ）。気づける警告も無い。
   - 直し案：落ちる種が無かった時は print を1行出す。

## §3 見たが問題なし
- ClimaxData.pages：map で1対1に置き換え。ページ数・話者は不変。speaker はそのまま引き継ぎ。準決勝は変更なし。
- 言い換えの添字：`((year &* 48 &+ week) % n + n) % n`。負の値や範囲外にならない（&* &+ でオーバーフローも落ちない）。week が0でも問題なし。
- 文面の途中入れ替え：ChoiceEventOverlay の text は computed property だが、イベント表示中に year/week は変わらない。
  - applyEventChoice は runner.applyEventEffects のみで週送りしない（GameSession.swift:734-771）。
  - pendingChoiceEvent は選択後も保つ（dismissChoiceEvent で落とす）。
  - fastForwardToYearEnd もイベントを dismiss してから送る。
  - 中断復帰も同じ year/week に戻るので文面は同じ。
- ChoiceEventData.text(for:) を year/week なしで呼ぶのはテストのみ（Tests:773,781,784）。
  - アプリ側の text / afterChoice / choiceLabels は、すべて ChoiceEventOverlay の `text`（year/week あり）から引いている。
  - hiddenEffectNote は kind と choice だけで引く＝文面に依存しない（効果は変わらない）。
- 言い換えの選択肢ラベルは元と同一で、afterChoice の A/B キーも同じ。テスト済み。
- DEBUG フック
  - RootView の notebook / offer / gploss は `#if DEBUG`（82〜305行）の内。
  - FinalsPresentationView の comments2 は `#if DEBUG` 内（246〜）。
  - QualifierNoticeView の MZ_OPEN=3 は `#if DEBUG` 内。
  - 環境変数が無ければ何もしない。
- gploss の session 作り直し：saveNow は `MZ_UI` 指定時に DEBUG で即 return する（GameSession.swift:1198-1202）。
  - 繰り返し作っても、保存・削除の副作用は無い（MZ_ALLOWSAVE を付けない限り）。
  - init 自体は保存しない。
- 「新年度の備え」への変更は表示文字だけ。
  - テスト参照なし（docs の旧設計にだけ残る）。
  - YoseTag の幅は、手前の文字数が1字増えるのみ。目視で一度確認するとよい。
- 朱印の拡大条件 `text.count > 4`：「優勝」「夜逃げ」などは従来どおり1.25倍、「準々決勝敗退」は等倍。

## 追記（10/26・親の対応）
- 済 §2-1：年末の独白は careerOver（優勝・夜逃げ・解散）でも「来年」の行を外す（実際は夜逃げ・解散は別のプール・優勝の年は独白なしで、当たる経路はほぼ無いが揃えた）。
- 済 §2-3：敗者復活の切り替えを定数 ClimaxData.revivalNextYearLine との一致に（テストで行が入っていることも確かめる）。
- 済 §2-4：gploss で30種とも通過した時に1行出す。
- §2-2 は問題なし（回想・続ける結末）。212 green。
