# コード点検 NetaSelectionView / SoundManager / StageScene（2026-11-16・読み取りのみ）

## 要点3行
- 3ファイルとも、クラッシュ・取り消し握りつぶし後の状態変更・選択ボタンの二重実行で、実害のある新規の不具合は見つからなかった（高0・中0）。
- 低が2件、要確認が1件：割り込み後に「再開してよい」が来ない場合の SE 無音（既知 1108b の残り）／デバッグ専用の `try? Task.sleep`／`requiredLength` が使われていない。ゲーム数値への影響はどれも無し。
- 既判定（1107e #8・#9、1108c #5、19f §2・§4・§5、1108b）は再掲せず、現行コードで直っていることだけ §3 に記した。

## §1 件数
高 0／中 0／低 2／要確認 1（計3）

## §2 指摘
| # | 度合い | 場所 | 内容 |
|---|---|---|---|
| 1 | 低 | NetaSelectionView.swift:55-58（`#if DEBUG` 内） | `Task { try? await Task.sleep(...); onSelect(...) }` はキャンセルを握りつぶして続行する型。画面が消えた後でも `onSelect`（＝`session.selectNeta` → `saveNow`）が走る。ただし環境変数 MZ_NETA_PICK を付けた DEBUG 実行の時だけ。Release には入らない。対策：`do { try await Task.sleep } catch { return }` か `guard !Task.isCancelled`。ゲーム数値への影響なし。 |
| 2 | 低 | SoundManager.swift:90-96・:108-133 | 割り込み終了時に `.shouldResume` が付かない場合（他アプリが音を出し続ける等）は何もしない。`setActive(true)` は resume 経路でしか呼ばないため、その後の SE（`play`）は AVAudioPlayer が鳴らないまま黙る可能性がある（実機で未確認・推測）。BGM は次の `playBGM` の同曲分岐で `p.play()` を試みるが、これも session 再有効化はしない。直し案：`.ended` なら `shouldResume` に関係なく `setActive(true)` だけ呼び、BGM 再開は shouldResume の時だけにする。数値影響なし。 |
| 3 | 要確認 | NetaSelectionView.swift:12・StageViews.swift:191・:331・:336・RootView.swift:447-453 | `requiredLength`（尺）は渡されるが NetaPickRow 内で一度も使われていない。冒頭コメントの「尺マッチのラベル表示」は現状出ていない。選択候補は `activeNetas` 全件で、尺・型（kata）の絞りも検証もない。これが設計どおり（v2 §4-1補「表示のみで合否に効かせない」）なら問題なし。「大会の尺に合わないネタを選べる」こと自体はゲーム数値には効かない（GameEngine.netaScoreBonus は id で引くだけ）。意図の確認だけお願いしたい。 |

## §3 問題なしと確かめた所
- NetaSelectionView の選択ボタン（:118-145）：`onSelect` は冪等（`selectNeta` は同じ id を同じ state に入れるだけ）。続けて2回押しても二重処理にならない。`withAnimation` で閉じるだけで Task なし。
- 決勝の1本目と2本目の重複：`selectNeta`（GameSession:909-914）が2本目を外す／`selectNeta2`（:917-922）が1本目と同じ id を弾く／`ensureStageNetaDefault`（:901-905）が旧セーブの重複を直す／2本目の行は `excludeID` で候補から除外。
- 無効な選択の残り：`selectedNeta` は `state.netas`（アクティブ）からしか引かない。しまった／消えたネタの id は WeekRunner:567-568 で外す。GameEngine:273-280 も netas から引いて無ければ恒等0（golden 不変）。
- 候補が空のときの文言（:33-37）で ForEach が空にならず、配列の添字アクセス・force unwrap なし（`candidates.first(where:)` は DEBUG のみで if let）。
- SoundManager：フェード Timer は `.common` で登録・プレイヤーごとに取り消し・`[weak self]`。`stopBGM` で duckFactor を戻す（:163）。同曲の再 `playBGM` は音量追従＋再生中でなければ再開（:136-139）。BGM 切替は旧プレイヤーをフェードアウト後に `stop()`（クロスフェードの重なりは 0.5 秒で意図どおり）。SE プールは最大3面で上限あり、`Bundle.main.url` の nil は guard 済み。AVAudioSession は `.ambient`（消音スイッチ尊重・他アプリ音と混ざる）で、BGM と SE が同一セッションのため競合しない。割り込み通知は購読済み（:75-79）。
- StageScene：Task・Timer・Sound 呼び出しなし。`h`・`w` での割り算は GeometryReader の実寸（`micX / w`、:85）だが、0 の場合は SwiftUI が描画を呼ばない範囲。配列の直接添字アクセス・force unwrap なし（既判定 1107e・19k と同じ結論）。
