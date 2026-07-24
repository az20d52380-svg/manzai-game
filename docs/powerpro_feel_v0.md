# パワプロ・サクセス化 第1弾 — 週の手触り改善＋中断セーブ（2026-07-24・実装済み）

> これは実装記録＋設計判断のdoc。数値は全て【仮】。ブランチ: `claude/game-review-improvements-56r5ss`

## 0. 発端（オーナー評・原文）

「UIUXと会話とか動きがそそられない。ゲームっぽくなってない。パワプロのサクセスのようにして欲しい。優勝到達とかの話してないです。」

→ 週ループの体感の問題として受け、`ui_design_v0.md §7-B`（体感の問題を数値で直さない）の正規レバー
【会話・イベント差し込み頻度UP／差分ポップ強調／行動結果テキスト増】だけで解いた。
**バランス数値・大会ライン・成長式・乱数消費順は一切触っていない（golden不変）**。

## 1. 何を入れたか（コミット順）

| # | 内容 | 主ファイル | golden |
|---|---|---|---|
| 1 | 死にコード削除: `WinFinaleView`（未参照・実体ゼロの「才能解放」表示の残骸） | WinFinaleView.swift（削除） | 不変 |
| 2 | 衛生4点: 通知許諾の導線撤去（通知未実装のため摩擦のみ）／初回シード固定424242→ランダム化／療養週の判を「休」三値化（NotebookView）／アイテム「準備中」タイル撤去 | IntroFlow / RootView / NotebookView / CommandData | 不変 |
| 3 | **行動の二拍**: タップ→Beat1発話バブル0.7s（`DialogueData.reaction` 死に辞書を配線・salt=週の決定的回転）→choose→Beat2獲得バースト（粒/能力/相性/体力/収支チップが立ち絵頭上にstagger）。画面タップで即スキップ。選択肢イベントcoverは burstHold で退場まで遅延（世代トークンで競合防止）。lastDeltaWeek ゲートで大会復帰時の古い増減再生を防止 | WeekMainView / GameSession / DialogueData | 不変（uiEventRngも非消費） |
| 4 | **常時目標バナー**（次の本番＋残り週・残3週で朱・≥6週は「仕込みどき・弱点は◯◯」）／週送りスタンプ「第N週」／谷口評ランク（5能力平均・ランクアップでpunch+Haptics.confirm）／`nextMilestone()` の**出場資格バグ修正**（知名度不足でも推薦制中堅賞が次目標に出ていた） | WeekMainView | 不変 |
| 5 | **週頭の掛け合い**（俺⇄谷口・タップ送り）: `rollWeekBanter` を pump の freeAction 分岐に配線。uiEventRng・イベント抽選の後・イベント週は譲る・行動で失効。頻度=基礎30%【仮】／**次の本番≥6週の空白帯（週16-26の中だるみ）は55%【仮】**。6帯×各3本＋innerVoice中盤帯6本＋reaction各変種3本（全て manzai-drama-voice Skill 採点済: A表/B表/V表全○） | GameSession / DialogueData / WeekMainView | 不変 |
| 6 | **中断セーブ/復帰**（proposals/0039準拠）: `WeekRunnerSnapshot`＋UI層イベントフラグ（didFire系/fired集合/uiEventRng/掛け合い/categoryLog）を UserDefaults 単一キーに保存。各入力確定点＋scenePhase(.background)。復帰は IntroFlow スキップで保存位相へ直行。finished/優勝で削除。MZ_SMOKE/MZ_UI は読まない/書かない | GameCore(WeekRunner/GameConfig/Calendar/Career/ChoiceEvent) / GameSession / RootView / CodableTests | 不変（snapshot=読み書きのみ。`tools/check_golden_sync.py` 50行一致を確認済み） |

## 2. 設計判断（後から読む人へ）

- **Beat1の700msはスキップ可能が前提**。ビート中の全面タップ=beatTask.cancel()=残りのsleepが即返り choose は必ず1回走る。3秒動線（§2）はスキップ経路で維持。
- **burstHold**: choose が選択肢イベントを立てると fullScreenCover が Beat2 を隠すため、choose 直前に立ててバースト退場後に必ず下ろす。旧タスクの defer が新しい保留を下ろす競合は世代トークン（burstGen）で防いだ。
- **掛け合いのUI乱数**: イベント抽選の後に引く＝既存ビルドとイベント出現週の再現列を揃える（以後のUI列は banter の消費分だけずれる・golden非対象）。頻度定数は判定に関与しないUI定数のため GameConfig に置かない。
- **セーブに GameConfig を含めない**（0039どおり）: バランス値の更新が古いセーブに固定化されない。復元時に毎回 `GameConfig()` を注入。
- **相方名の焼き込み禁止**を新規テキストで遵守（reaction/innerVoice に谷口名なし）。banter は会話スロットのため谷口固定（ChoiceEventData と同じ扱い・ガチャ相方実装時に分岐化）。

## 3. 既知の残課題（今回スコープ外）

- **セーブがあると周回を途中で捨てる手段が無い**（SettingsView は通常導線から未到達）。「はじめから」導線は次の便で。
- 通知は許諾ごと撤去＝機能実装時に NotificationPromptView を復帰させる（休眠温存）。
- 立ち絵はシルエット仮のまま（本イラスト差替は別トラック）。
- 多年キャリア（本編=結成10年・オーナー決定⑦）のUI配線は別セッション。

## 4. Mac側での検証チェックリスト（この環境にSwift/simulatorが無いため必須）

1. `cd ManzaiGame && xcodegen generate`（WinFinaleView削除のため pbxproj 再生成・規律D-9）
2. `cd GameCore && swift test` **全green**（新規 `testWeekRunnerSnapshotResumesBitIdentical` 含む。
   コンパイル注意点: `WeekRunner<R>.Phase`/`Section`/`AutoStage` の Codable 合成・OfferSpec 書き換え・
   `WeekRunnerSnapshot` の同一ファイル extension）
3. simulator 目視（規律D-10）:
   - 週の行動タップ→発話→週送り→獲得バーストの二拍テンポ／ビート中タップで即スキップ
   - 選択肢イベント発火週にバーストが隠れず、退場後に cover が出る
   - 掛け合いのタップ送り・行動で消える・中だるみ帯（週16-26）で頻度が上がる
   - 目標バナー（資格外の大会が出ない）・週送りスタンプ・谷口評ランクアップpunch
   - **強制終了→再起動→同じ画面に復帰**（自由週/大会入口/結果画面/イベント表示中の4パターン）
   - 年末（finished）後に再起動→IntroFlow から新規で始まる（セーブが消えている）
