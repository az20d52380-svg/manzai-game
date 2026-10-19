# コード点検 2026-10-19 (l)　未点検のアプリ側ファイル（読み取りのみ・コード変更なし）

## 対象ファイル（`ManzaiGame/Sources/` 配下）
- Design/YoseYearTurnCurtain.swift（459行）
- Design/YoseComponents.swift（328行）
- Design/YoseGameParts.swift（287行）
- Design/YoseMotion.swift（76行）
- Design/EventBackdropTable.swift（49行）
- FanReportData.swift（158行）
- CharacterAvatars.swift（150行）
- ChoiceEventData.swift（1027行）／DialogueData.swift（515行）＝データ表。文章の良し悪しは見ず、引く側の論理・キー・死にデータだけ

観点：落ちる／後始末漏れ／reduceMotion・Dynamic Type・VoiceOver／描画の無駄／表示と GameCore のずれ。呼び手は grep で確認済み。
結論：**クラッシュに直結する所見は無し**。重い所見は3件（うち1件は画面に出る数字のずれ）。

---

## §1 直すべき（重い順）

### 1-1　年の幕間の「実力」が他の画面と別の計算（表示と GameCore のずれ）
- 場所：`RootView.swift:344-348`（`beginYearTurn`）→ 表示は `Design/YoseYearTurnCurtain.swift:259-263`
- 起きる場面：年末リザルト →「◯年目へ」で幕間が出る時。
  `power` を `Ability.allCases` 5つ（メンタル含む）の**単純合計**で作っている。ゲーム本体の「実力」は `GameEngine.jitsuryoku`（センス・発想・表現・華を `config.weight*` で重み付け、メンタルは入らない）で、`NotebookView.swift:68`・`WeekMainView.swift:532` はそちらを使っている。
  → 幕間の「実力」が手帳・週メインと違う数字になる（メンタル分だけ必ず大きく、重みの違いでもずれる）。
- 直し方の案：`power: Int(GameEngine.jitsuryoku(st, config: session.config).rounded())` に変える（NotebookView と同じ式）。
- 付随：幕間の体力「100/100 全回復」は `YearTurnSummary.maxStamina = 100` の固定値（`YoseYearTurnCurtain.swift:24`）。実際の全回復は `config.initStamina`（`WeekRunner.swift:121`、現状 100.0 で一致）。値を変えた時にだけずれる。`maxStamina: Int(session.config.initStamina)` を渡すと安全。
- 判断：不要（式の置き換えだけ。ただし規律Aの式には触れず表示側のみ）。

### 1-2　`YoseModal` が VoiceOver のモーダルとして扱われず、スクロールもできない
- 場所：`Design/YoseGameParts.swift:136-179`
- 起きる場面：体調ダウン・借金・コンビ・やり直し確認・初回ヒント（`StageViews:235`、`WeekMainView:196/204/212`、`SettingsView:144`、`HintModal`）。
  - `.accessibilityAddTraits(.isModal)` が無く、**アプリ全体で `isModal` は1箇所も使われていない**（grep 確認）。VoiceOver で背面の週メインのボタンまで読み進められ、モーダルの外へ出られてしまう。背面の操作で二重進行する恐れもある。
  - 中身が `ScrollView` でない。文字を最大（mzScaled の上限 1.35 倍）にすると、`firstWeek` ヒント（4行＋note）や体調ダウンの長文で縦にあふれ、「わかった」ボタンが画面外に出て閉じられなくなる可能性（実機 SE クラス・最大文字は**要確認**）。
- 直し方の案：外側 ZStack に `.accessibilityAddTraits(.isModal)`。中身の `content` を `ScrollView`（`.scrollBounceBehavior(.basedOnSize)`）に入れて、ボタン行は外に固定。
- 判断：不要。

### 1-3　年の幕間：画面を閉じた後にも触覚が鳴る（Task のキャンセルを見ていない）
- 場所：`Design/YoseYearTurnCurtain.swift:362-402`（`playTransitionSequence`）、起動は `:137`
- 起きる場面：幕が閉じている最中（約0.3秒）や演出中に画面をタップ → `triggerStart()` → `yearTurn = nil` でビューが消え `.task` がキャンセルされる。
  `try? await Task.sleep` はキャンセルされると**例外を握りつぶして即戻る**ので、残りの手順（`.heavy` の衝撃、`.success` の通知ハプティクス、揺れ・スタンプの `withAnimation`）が**ゼロ待ちで一気に実行**され、次の年の第1週に入った瞬間に強い振動が2発鳴る。
- 直し方の案：各 `try? await Task.sleep` を `do { try await ... } catch { return }` に変えるか、各ステップ直前に `guard !Task.isCancelled else { return }`。
- 判断：不要。

### 1-4　年の幕間：小さい端末・大きい文字で下が切れる可能性／VoiceOver で背面が読める
- 場所：`Design/YoseYearTurnCurtain.swift:58-113`（`ScrollView` なしの縦積み）、`:188`（めくり札は幅196固定）、`RootView.swift:321-325`（`.overlay` で重ねるだけ）
- 起きる場面：
  - 画面高 667pt（SE 級）や最大文字で、めくり看板（約280pt）＋引き継ぎカード＋54ptボタン＋黒帯が収まらず、主ボタンが下にはみ出す恐れ（実測していないので**要確認**。ただし幕間全体が画面どこでもタップで進むので詰みにはならない）。
  - 重ねた幕間に `isModal` が無く、VoiceOver で背面の年末リザルトが読み上げ・操作される。さらに、前年のめくり札（「全日程 終了」）は透明になった後も読まれる可能性があり、実力・知名度の木札は個別に読まれず「結成 二 年目」など断片的に読まれる。
- 直し方の案：`.accessibilityElement(children: .contain)`＋`.accessibilityAddTraits(.isModal)`、前年札に `.accessibilityHidden(true)`、めくり看板を「結成N年目」と1つのラベルにまとめる。縦が足りない時は看板を縮める（`minimumScaleFactor`／`ViewThatFits`）。
- 判断：レイアウト案が複数あるので、見た目を変えるなら要判断（VoiceOver 側の修正だけなら不要）。

---

## §2 軽微

1. **`YoseToast` は VoiceOver に伝わらない**（`YoseGameParts.swift:182-212`、実使用は `CalendarView.swift:36`）。表示1.8秒で消えるのに `UIAccessibility.post(.announcement)` が無い。表示時に1回 post する。なお `.yoseToast(_:)` モディファイアはカタログ（`YoseCatalog.swift:121`）以外から使われておらず、**アプリ本体では死にコード**。
2. **`YoseTopTabBar` に選択状態の読み上げが無い**（`YoseGameParts.swift:83-101`）。`.accessibilityAddTraits(sel ? .isSelected : [])` を足す。ラベルも文字が `Text` なので読みは出る。
3. **`YoseHeaderBar` のとじるボタンが 64×28pt**（`YoseComponents.swift:40-45`）。タップ領域が44pt未満。見た目は変えずに `.contentShape` と透明余白で44pt確保。15画面で使われている。
4. **`YoseModal` の `cancelTitle` 既定が "やめる" なのに `cancelAction` が nil だとボタンが出ない**（`YoseGameParts.swift:140, 161`）。現在の呼び手は全て nil か両方指定で問題なし。将来の呼び手の罠なので `if let cancelTitle, let cancelAction` の片方欠けを assert か型で防ぐと安全。
5. **`YoseSpeechBox` の点滅**（`YoseComponents.swift:326`）：`repeatForever` は `onAppear` で一度かけるだけで止めない。表示中は軽い不透明度のみなので負荷は小さいが、reduceMotion オフ時に画面を出入りする度に新規アニメが積まれる。実害なし。
6. **`YoseAppearModifier` は reduceMotion を見ない**（`YoseMotion.swift:54-65`）。10pt のせり上がりだけだが他の部品と作法が違う。**呼び手ゼロ**（下の死にコード参照）。
7. **`YoseNumberBounceModifier`**（`YoseMotion.swift:22-37`）：`DispatchQueue.main.asyncAfter` で `bump=false`。ビューが消えた後でも走るが State への代入だけで無害。
8. **`YoseStampImpactModifier`**（`YoseMotion.swift:7-19`）：reduceMotion 時も `isStamped` が true になるたびに成功ハプティクスが鳴る（動きではないので許容）。年の幕間では reduceMotion 経路でも鳴る。
9. **`YoseVitalMoneyBar` は高さ36pt固定**（`YoseGameParts.swift:71`）かつ「大きい文字か」を `Font.mzScaled(10) > 11` で判定（`:40`）。`@Environment(\.dynamicTypeSize)` を読んでいないため、**アプリ起動中に文字サイズを変えても、再描画されるまで反映されない**（`mzScaled` を使う部品全般の性質）。実害は小。
10. **`kanjiNumber`**（`YoseYearTurnCurtain.swift:411-417`）：負数は `max(0,n)` で守っており安全。20以上は桁ごとの漢数字（「二〇」）で、`year >= 10` の分岐でフォントを小さくしている。10年以上遊ぶと「結成 十一 年目」が出るが、20年目以降は「二〇」。仕様として想定内なら問題なし。
11. **`compactYen`**（`YoseYearTurnCurtain.swift:419-428`）：`abs(Int.min)` はトラップするが、所持金でそこまでの値は取り得ない。実害なし。
12. **`CharacterFace`**（`CharacterAvatars.swift:30-114`）：`size` が 0 でも落ちない（全部 size 倍率）。1顔あたり View が10個前後で、決勝の審査員席・会話ごとに複数枚並ぶだけなので負荷は小さい。装飾なので VoiceOver ラベルは不要（呼び手 `TalkParts:77` 側が `.combine` で名前込みの文を読む）。
13. **`FaceCatalog.speaker`**（`CharacterAvatars.swift:142-148`）：`speaker(nil)` と "俺" は主人公の顔、未知の名前（第三者の先輩・店長・母など）は `judge("…")` を経由して `FaceSpec()` の汎用顔になる。落ちない。意図通りか（同じ灰色の襟の顔が複数人に出る）は表示確認の対象。
14. **`DialogueData.innerVoice`**（`:63, 66, 69`）の `Int(state.fame)`：fame が NaN／無限だと `Int(_:)` がトラップ。GameCore 側で fame は有限に保たれているので現状は到達しない。念のため `Int(state.fame.isFinite ? state.fame : 0)` 相当にしておくと安全。
15. **banter の「金欠」帯と独白の「金欠」帯のしきい値が違う**：`GameSession.swift:600` は `money < 50_000`、`DialogueData.swift:62` の `lowMoney` は `< 30_000`。3万〜5万円の間は掛け合いだけが金欠話になる。意図なら問題なし（コメントに残すとよい）。
16. **`EventBackdropTable` と `ChoiceEventData.scene(for:)` が別々の場所表**（下の死にコード参照）。現在は前者が実使用、後者は使われていない。

### 死にデータ・死にコード（どの呼び手からも引かれない）
| 対象 | 場所 | 状況 |
|---|---|---|
| `ChoiceEventData.scene(for:)`、`enum EventScene` | `ChoiceEventData.swift:16-33` | 呼び手は `ChoiceEventOverlay.swift:22` の `private var scene` だけで、その `scene` は読まれていない。`EventSceneView`／`PlaceScene`（`ChoiceEventOverlay.swift:329-`）も他から生成されていない＝**背景作り直し（EventBackdrop）で置き換わった旧実装が残っている**。まとめて削除できる |
| `DialogueData.indexAvoiding`、`recentLimit` | `DialogueData.swift:24-45` | 参照ゼロ（`indexAvoidingUsed` に置き換わった名残） |
| `FanReportData.burst(name:salt:known:)` | `FanReportData.swift:36-40` | アプリ側の呼び手ゼロ（テスト `ManzaiGameTests` のみ）。「紙講評の後の1枚は廃止」とコメントにある旧経路 |
| `FanReportData.pick(_:_:_:)` | `FanReportData.swift:96-99` | private で参照ゼロ（警告の元） |
| `yoseAppear`／`YoseAppearModifier`、`yoseRowGlow`／`YoseRowGlowModifier` | `YoseMotion.swift:39-65, 72-75` | アプリ側参照ゼロ（`yoseNumberBounce` は `YosePowerBadge` 内でのみ使用、`yoseStampImpact` は使用あり） |
| `YoseToastModifier`／`.yoseToast` | `YoseGameParts.swift:196-215` | カタログのみ |

---

## §3 問題なしと確認した所

- **添字・範囲外**：
  - `FanReportData` の `burst`／`pick`／`ordered`／`voices`：`n = pool.count` が0にならない（全プール非空、`ordered` は `n > 0` ガード済み）。剰余は `((x % n) + n) % n` で負数も安全。`knownOnly` フィルタ後も最小で bandB 4本・burst 12本残る。
  - `DialogueData`：`pick`／`banter`／`reaction` は空配列ガード・負数対応の剰余あり。`banterPools` は6帯すべて存在。`picker`（`GameSession.pickIndex`）は `count > 0` ガードと `idx < count` 確認つきで範囲内の値を返す。
  - `joshikimakuHeader`／`curtainPanel` の色配列：`idx % colors.count` で安全。`YoseGauge` は `total > 0` と 0...1 クランプでゼロ除算なし。`YoseDiagonalStripes` は有限矩形で終了。
- **キー・ID の整合（スクリプトで機械照合）**：
  - `ChoiceEventData` の全36種：`ChoiceEventKind` の全 case を `text(for:)` が網羅（switch で網羅性をコンパイラが強制）。
  - 各イベントの `choiceLabels`／`afterChoice` のキー（A/B/C）が `GameCore ChoiceEventTable.choices` の ID と**完全一致**（選択肢ありの32種：A/B、0017のみ C）。選択肢なしの4種（`namelessReservationSlip`／`lineupTop`／`luckyThirdLine`／`greenroomSilentTen`）は `choiceLabels` 無し＝GameCore も空で一致。
  - `DialogueData.reactionPools` のキー：`CommandData` が作る全 `variantID`（`t_…` 9種・`job_…` 3種・`rest_…` 5種・`offer`）がすべて存在。余分なキーも無し。
  - `FanReportData.knownOnly` の8文はすべて元のプールの文と**逐語一致**（フィルタが効かない文字ずれ無し）。プール間の文の重複も無し。
  - `FaceCatalog.judge` の7名は `JudgeTalk.judgeNames` と一致。`EventBackdropTable` の `switch` は全 case 網羅（コンパイラ強制）。
- **後始末**：`YoseYearTurnCurtainView` は `.task` 1つのみで Timer・TimelineView・Combine 購読を持たない。`YoseToastModifier` は `.task(id:)` でメッセージが変わると前のタイマーが自動キャンセルされ、閉じた後に走る処理は無い。`YearTurnStageBackdrop` は `Canvas` 静的描画（`lit` 変化時のみ再描画）で毎フレーム再計算は無し。
- **reduceMotion**：幕間は `reduceMotion` で演出を全部省いて即表示。`YoseSpeechBox`／`YoseStampImpact`／`YoseNumberBounce` は対応済み（`YoseAppear` のみ未対応・呼び手ゼロ）。
- **VoiceOver**：`YoseButtonStyle` はボタンのまま読める。`YoseHankoStamp.spoken`、`YosePowerBadge`、`YoseVitalMoneyBar`（体力・知名度・所持金の読み上げ文）、`HintMarkButton`（「説明を見る」）、`YoseGauge`（数字が隣にあるため非表示）は適切。幕間の幕パネルは `accessibilityHidden`。
- **二重実行の防止**：幕間の `triggerStart` は `hasTriggeredStart` で1回限り（全画面タップ＋ボタンの二重発火なし）。
- **表示と GameCore の値**：幕間の体力・所持金・知名度・持ちネタ数は `GameState` の値をそのまま整数化（実力のみ §1-1 のずれ）。`YoseVitalMoneyBar` の借金表示は `money < 0` で判定し、読み上げ文もマイナス表記と一致。
