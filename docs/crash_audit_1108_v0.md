# クラッシュ点検 2026-11-08（読むだけ・コード変更なし）

対象：ManzaiGame/Sources/**/*.swift と GameCore/Sources/**/*.swift（`#if DEBUG` 内を除いた約2.8万行）。方法：正規表現で候補を出し、該当行と呼び出し元を読んだ。実行はしていない。

## §0 要点3行
- 「手順を追えた」本番クラッシュは 0 件。強制アンラップは 5 箇所だけで、全て直前の条件で守られている。
- 「推測」止まりの弱い所が 3 件（すべて低）：Career.swift の `1...years`、GameSession.swift の `names[... - 1]`、`Int(Double.rounded())` 群の NaN。いずれも今の呼び出し・設定値では届かない。
- セーブ復元は過去の監査で丸め処理が入っており、回戦数を減らした場合も `gpStage` が配列外を指さない作りだった。

## §1 指摘（重さ順・全て低）

### 1. Career.runCareer の `1...years`（確かさ：推測）
- 場所：GameCore/Sources/GameCore/Career.swift:110
- 起きる手順：`years` に 0 以下を渡すと範囲の下限が上限を超えて実行時エラー。
- 結果：クラッシュ。ただし runCareer を呼ぶのは GameCore 内の定義だけで、アプリ側（ManzaiGame/Sources）に呼び出しは見つからなかった。シミュレーション／テスト用の入口。
- 直し案：`guard years >= 1 else { return nil }` を足す（挙動不変）。

### 2. 年間ベスト表示の `names[min(roundsPassed, names.count) - 1]`（確かさ：推測）
- 場所：ManzaiGame/Sources/GameSession.swift:1072
- 起きる手順：`roundsPassed == 0` かつ `reachedFinal == false` かつ `prize == -1` の記録、または `gpRoundNames` が空の設定。
- 結果：添字 -1 でクラッシュ。ただし `prize == -1` の記録は GameSession.swift:1061 の `runner.gpRoundsPassed > 0 || runner.isFinalist` の時だけ追加され、`gpRoundNames` は設定の定数（非空）。今は届かない。
- 直し案：`max(0, ...)` で下限を守り、`names.isEmpty` なら別の文言にする。

### 3. `Int(x.rounded())` 群の NaN／無限大（確かさ：推測）
- 場所：WeekMainView.swift（567, 580, 1046, 1316, 1541 ほか）、NotebookView.swift（123, 136, 438）、AbilityUpView.swift（228, 302, 426, 521）、TournamentResultView.swift（308, 531）、RootView.swift:373 など。
- 起きる手順：状態の Double（知名度・相性・完成度・実力）が NaN か無限大になった時だけ。0 割りは調べた範囲で設定定数の除算（`livingInterval`、`judgeDeltaK` 等）に限られ、`s[a]/d` の d も設定値。NaN が生まれる手順は追えなかった。
- 結果：`Int(NaN)` はクラッシュ。
- 直し案：保険が欲しければ表示用の小さな関数 `safeInt(_:)`（非有限なら 0）を 1 つ作って置き換える。優先度は低。

## §2 調べて問題なしと確かめた型

- **強制アンラップ `!`：5 箇所、全て安全。**
  - AbilityUpView.swift:340 `n!`：直前の `n != nil &&` で守られる。
  - GachaView.swift:155 `plan!`：`case .paid1, .paid10` の中なので nil ではない。
  - GameEngine.swift:281 `second!`：`second == nil ||` の短絡で守られる。
  - JudgeTalk.swift:142 `vocab[nil]!`：辞書リテラルに `nil:` キーがある（121 行）。
  - TournamentResultView.swift:52 `results.last!`：`pump()` の `!big.isEmpty` で生成時に非空を保証。復元した `pendingResult` も同じ経路で作られた物。
- **`try!`・`as!`・`.first!`・`.randomElement()!`：0 件。** `removeFirst`／`removeLast`：GameSession.swift:140 の 1 件のみ（`count > 600` の条件内で、引く数も count−600 なので安全）。
- **`% count`／`/ count` の 0 割り：安全。** DialogueData（397-399, 840, 970-971）、FanReportData（58, 410）、ChoiceEventData:54、NetaCatalog（36, 56）、JudgeTalk（147, 158, 484）はすべて固定の非空配列か `guard !isEmpty`／`count > 0` で守られている。`mix()` は非負を返すので負の剰余も出ない。
- **範囲 `a...b`／`a..<b`：** 定数の範囲は多数で全て a≤b。変数の範囲を個別に確認。
  - GameSession.swift:710 `gpRoundsPassed..<gpRounds.count`：復元時に `min(snap.gpStage, gpRounds.count)` で丸めてあり、a==b なら空範囲で安全（WeekRunner.swift:677）。
  - WeekRunner.swift:141 `1...min(year, growthEndYear)`：year は 1 以上、growthEndYear は 15。
  - GameEngine.swift:252 `-b ... b`：b=5+15(1−メンタル/100)。メンタル上限は `mentalCap`=100 なので b≥5 で逆転しない。
  - TournamentResultView.swift:386、YearResultView.swift:591、QualifierNoticeView.swift:168 は `n>0` のガードか `max(...)` がある。
  - FinalsPresentationView.swift:859 `4..<min(7, judges.count)`：judges は常に 7 人（Spec 7 件）。
  - `Int.random(in:)` は全て定数範囲。`rng.int(0...i)` は stride が i≥1 の時だけ。
- **`stride`：** 全て定数か `pool.count-1 through 1 by -1` で、空配列でも空のループになる。
- **`Array(repeating:count:)`：** count は全て定数（5, 2, 3 など）。`prefix`／`dropFirst`／`suffix`：負の数を渡す箇所なし（FinalistAnnounceView:152 は `count − count/2` で非負）。
- **`Dictionary(uniqueKeysWithValues:)`：** Endings.swift:209 の 1 件。キーは辞書のキー（EndingID）の rawValue で、EndingID の rawValue が重複しなければ安全（enum の rawValue はコンパイラが重複を禁止する）。
- **配列の添字：** WeekRunner.swift:256 `gpRounds[gpStage]` は `gpStage < gpRounds.count` の判定（407 行）経由でのみ届く。`gpLossCompat[gpStage]` は 273 行の条件付き。`roomRents[target]` は `target < count` を判定。`roomHeals[room]` も同様。`chooseOffer` は `indices.contains`。GameSession.swift:630 `candidates[idx]` は `isEmpty` のガードと `min(..., count-1)` あり。`offersNamed[(isMoney ? 2 : 0) + sub]`（GameEngine.swift:227）は設定の 4 件前提で今は安全。
- **セーブ復元：** SaveData の後付けフィールドは全て Optional。復元は `try` で失敗すれば退避して新規に落ちる（GameSession.swift:1338-1349）。回戦数減少に対する丸めあり、`pendingAuto == .round` も丸め後に解除、config は保存せず毎回取り直し、`week` は `min(save.runner.week, cfg.weeks)`。壊れた値（週・年が範囲外）を直接検証する所は無いが、アプリが書いた JSON でそのような値が出る手順は追えなかった（外部から壊された JSON は decode が型違反で弾く範囲まで。値の範囲外は推測）。
- **端の状態：** ネタ 0 本（`netas.first(where:)` は nil 許容）、2 本目なし（GameEngine.swift:281 で守る）、所持金が負（`debtTier` は Int 比較のみ）、15 年通し（`careerYears=15`、`growthEndYear=15`、11 年目以降の pow は有限）、相方不在（`weeksWithoutPartner` は加算のみ）、年末直後（`week` は 48 に丸め）、いずれも添字や範囲に届く経路は見つからなかった。
