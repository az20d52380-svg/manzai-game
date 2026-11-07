# ボタン押下SE 候補（button_press_se_cand）v0 — 2026-11-01

## 変更点
- `YoseButtonStyle`（Design/YoseComponents.swift）に `silent: Bool = false` を追加（init 末尾の引数・既定 false＝既存呼び出しは無変更でコンパイル可）。
- 押下の瞬間（onChange・isEnabled の時）に rigid 振動に加えて `if !silent { Sound.play(.cursor) }`。演出設計書 §2 #1「沈み＋rigid Haptics＋SE」に合わせた。PressableStyle と同じ二重鳴り防止の考え方。
- PressableStyle への振動追加はしない（Theme.swift の「閲覧操作は無振動」方針）。

## silent: true にした箇所（3件）
- ChoiceEventOverlay.swift:251 「次へ 進む」＝ `advance()` が先頭付近で `Sound.play(.cursor)`（※並べた1枚を閉じる分岐は無音で閉じる）
- ChoiceEventOverlay.swift:264 選択肢カード＝ `choose()` → `showEffects` が `.pop/.grain` を鳴らす（効果札が空の時だけ無音）
- WeekMainView.swift:1034 週メインのコマンド札＝ action が `.deny` / `.tap` を鳴らす（イベント待ち等の guard で戻る時だけ無音）

## 迷ったもの（silent にしていない）
- FinalsPresentationView.swift:174, 1021 — `advance()` は分岐により `.cursor` を鳴らす／鳴らさない（別音は呼び先）。分岐が混在。
- TournamentResultView.swift:214 「次の声へ」— `fanTap += 1` の後、別タスクが `.cursor` を鳴らす（同一タップではあるが遅延・二重になる可能性）。
- TournamentResultView.swift:176 — action 内で直接の音なし（遷移先で別音の可能性）。押下音を残した。
- WeekMainView.swift:642/731/820 — 音なし（820は Haptics.tick のみ）。押下音を残した。
- IntroFlow.swift:365(onStart)/617(decide) — decide は Haptics.confirm のみで音なし。押下音を残した。onStart は呼び先未確認。
- YearResultView.swift:477, SettingsView.swift:130/170/183, 他（Stage/Shop/Ability/Notebook/Ending/S6b 等）— action 内に即時の Sound.play なし。押下音を残した。

## ビルド／テスト
- ビルド：エラー出力なし。
- テスト：未完了。xcodebuild test が「Timed out while preparing execution worker」で失敗（先行ビルド等の xcodebuild が複数残りシミュレータが競合した模様）。親側で再実行が要る。変更は UI の ButtonStyle のみで GameCore には触れていない。

## 注意
音の二重鳴りは実機タップでの確認が要る。
