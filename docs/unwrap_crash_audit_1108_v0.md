# 強制アンラップ・0除算・Int変換 落ち監査（静的・2026-11-08・v0）

範囲：ManzaiGame/Sources と GameCore/Sources/GameCore（Tests・build 除く）。直していない。添字の範囲外は docs/index_crash_audit_1108_v0.md で済みのため重複させない（TournamentResultView:52 だけ強制アンラップとして再掲）。
結論：**確実に落ちる箇所は 0 件**。条件付きは 3 件（いずれも低）。残りは固定リテラル・ガード・値域クランプで安全。
`try!` は DEBUG 限定の自己診断 1 件のみ。`as!` `URL(string:)!` `.first!` `.last!`（1件除く）`.randomElement()!` `: T!` はコード中に 0 件。

## 条件付き（何に頼っているか）

| ファイル:行 | 形 | 分類 | 根拠 | 直すなら |
|---|---|---|---|---|
| TournamentResultView.swift:52 | `summary.results.last!` | 条件付き・低 | results が空の WeekSummary が来ると即落ち。守りは GameSession.pump() の `!big.isEmpty` のみ（添字監査と同件） | `guard let` にして空なら閉じる／`results.last ?? .placeholder` |
| YearResultView.swift:384, 399 | `Int(s.fame)` | 条件付き・低 | fame は clamp(0,100) で通常安全。NaN/∞ なら落ちる（`max(lo,min(hi,NaN))` は NaN を通し得る）。DialogueData:55,62 は `isFinite` を見ているのにここだけ無い | `Int(s.fame.isFinite ? s.fame : 0)` |
| 保存データ復元（GameState の stamina/fame/compat/money 経由の `Int(x.rounded())` 全般：StageViews:198,334 / ShopView:20 / WeekMainView:567-580,1046-1052,1311-1324,1378,1541 / NotebookView:123-136,438 / TournamentResultView:531-532 / RootView:376 ほか約 40 行） | `Int(Double)` | 条件付き・低 | 通常は engine の clamp で 0〜100 に収まる。JSON を手で壊した/改ざんしたセーブ（1e30 や極端値）を decode すると、表示行で Int 変換が落ちる。通常の遊びでは起きない | loadedOrNew の decode 後に Double 状態を一括 clamp/isFinite 検査（1か所で全部守れる） |

## 安全（分類まとめ）

| ファイル:行 | 形 | 根拠 |
|---|---|---|
| GameSession.swift:1898 | `try! JSONSerialization.data` | `#if DEBUG`（1768〜）内の debugSelfTest のみ。直前で読んだ辞書の再直列化で失敗しない。製品ビルドに入らない |
| GachaView.swift:155 | `plan!.count` | `plan` は関数引数（let）。`.paid1/.paid10` の case 内なので非 nil。await を挟んでも変わらない |
| GameEngine.swift:281 | `second!.polish` | `second == nil ||` の短絡の右辺。安全 |
| JudgeTalk.swift:142 | `vocab[nil]!` | static リテラル辞書に nil キーが書いてある（行120）。消さない限り安全 |
| NetaCatalog.swift:36,55 | `% all.count` `% names.count` | allCases / 固定配列で非空 |
| DialogueData.swift:27-29,399,840,971 / FanReportData.swift:58,418 / ChoiceEventData.swift:54 | `% count` | 直前に `count>0` ガード、または固定リテラルで非空。`reaction` は pool を `?? [既定]` で非空にしている。banter は `!pools.isEmpty` ガード。picker は indexAvoidingUsed（count>0 前提で範囲内を返す） |
| JudgeTalk.swift:147,158,484 | `% list.count` / `% judgeNames.count` | 147 は `!list.isEmpty` ガード、158 は `guard !list.isEmpty`、484 は固定 7 名 |
| JudgeTalk.swift:137 | `Int(z % UInt64(Int.max))` | 剰余が Int.max 未満＝必ず収まる |
| FinalistAnnounceView.swift:49 | `nx() % (i+1)` | i は 1 以上＝右辺 2 以上 |
| FinalsPresentationView.swift:1424 | `next() % span`、`Int(...)` | span は呼び元が全部リテラル範囲（≥1）。結果は span 未満で Int に収まる |
| FinalsPresentationView.swift:1214 | `Int((-m-4)/3)` | margin は有限（採点差）。 |
| FinalsPresentationView.swift:1193-1194 | `Int(s.発想)` 等 | 能力値は有限・小さい（&* で桁あふれも避けている） |
| WeekMainView.swift:505,506,1490 / GameSession.swift:406 / GameEngine.swift:335 | `% livingInterval` | GameConfig で既定 4。セーブから config は復元されず 0 にならない |
| RentStatement.swift:25 | `/ sum` | ratio 固定で sum=14 |
| WeekMainView.swift:539,544, Design/YoseComponents.swift:278 | Double の `/` | Double（落ちない）かつ `budget>0`/`total>0` ガード |
| Juice.swift:54, Design/YoseYearTurnCurtain.swift:157,339, Design/YoseChampionCelebrationView.swift:997, Design/YoseEffects.swift:432, FinalsPresentationView.swift:1480 | `% colors.count` / `% palette.count` | 色配列はローカルのリテラルで非空。YoseEffects:128,153 は `max(1,count)` で 0 除算回避（ただし count==0 なら添字側で落ちる：colors は呼び元全部非空） |
| GameSession.swift:629, GameEngine.swift:240 | `Int(nextUniform()*Double(count))` | `candidates.isEmpty`/`rest.isEmpty` を先に除外。nextUniform は [0,1) |
| SoundManager.swift:179, FinalistAnnounceView.swift:204, WeekMainView.swift:1291, TournamentResultView.swift:401 | `Int(duration/0.05)`、`0..<Int(...)` | 呼び元は全部正のリテラル（305: 1.0/1.2、340: 0.10/0.18）。負だと `0..<n` が落ちるが到達しない |
| AbilityUpView.swift:512,521, GameSession.swift:549-555, JudgeData.swift:24, Meta.swift:213, Theme.swift:465, Design/YoseYearTurnCurtain.swift:433, RentStatement.swift:87 | `Int(Double)` | 有限な能力値/経験点/金額（money は Int→Double 往復、`m==m.rounded()` で整数確認済み、RentStatement の money は表示アニメ用 @State で有限）。Meta.preview は p>0 ガード・config 定数 |
| GameSession.swift:1037 | `Int(raw[r]) ?? 0` | 失敗は nil 扱い（`!` 無し） |
| Design/YoseComponents.swift:263 | `Int(t) != nil` | 判定のみ |
| GameSession.swift:1808 | `Int(m0)` 等 | `#if DEBUG` 内（1768〜） |
| Allocation.swift:60 / GameEngine.swift:29,299 / Theme.swift:140 / RadarChart.swift:96-111 / StageScene.swift:282-286 | Double の `/` | Double は 0 除算で落ちない（NaN/∞ は clamp や min で表示に潜るだけ）。対象外 |

## fatalError / precondition / assert
`grep` 対象外とされたため集計せず。実データで到達し得る fatalError は、上の読解中に目に入らなかった（要望があれば別途 grep する）。

## 件数
- 確実に落ちる：0 件
- 条件付き：3 件（TournamentResultView:52、YearResultView:384/399、セーブ改ざん経由の Int 変換群）。いずれも通常プレイでは到達しない

## 方法メモ
grep：`try!|as!|\)!|\]!|[a-z]![.,)]`、`/` `%` の右辺が変数の行（62 行）、`Int(` の変換（77 行）を全部読み分類。`: T!` 宣言は 0 件。
