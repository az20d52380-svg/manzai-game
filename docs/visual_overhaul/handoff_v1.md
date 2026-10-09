# 引き継ぎ：見た目の作り直し v1（第1便完了 → 第2便から再開）

2026-10-10 時点・最終コミット `aee2e50`（push 済み・作業ツリーはクリーン）。ブランチ `claude/manzai-slg-foundation-wprqlu`。

## §1 状況（3行）
1. 依頼文 `proposals/PROMPT_visual-genre-overhaul_v1.md` の Phase 0〜5 完了、Phase 6 の**第1便が全て完了**（画面ごとにコミット・sim目視・push）。
2. 正本 `docs/visual_genre_overhaul_v1.md`（§4 採用案・§5 レッド対処・§6 実装計画・§7 やらないこと）。**オーナー承認済み（2026-10-09）**：Q1 本番＝「暖色の客席に光る舞台」／Q2 決勝の採点＝**M-1と同じく1人ずつ**（7/7の一斉オープンは失効・`finals_direction_v0.md` §2-2 に正典移行バナー済み）／Q3＝第1便＋第2便の全部。
3. 次にやること＝**第2便**（§3）。その後 Phase 7（オーナー試遊・所感を正本 §8 に記録）。

## §2 運用の注意（必読）
- **simulator はリード専用の iPhone 17（UDID `E5D11233-FE99-429F-A55C-8B0FA5793568`）だけを触る。** iPhone 17 Pro / Pro Max は**オーナー用**（触らない。試遊用にビルドを入れる時は事前にオーナーへ確認）。
- このMacから `git push` 可。オーナーとは日本語。長文はファイル＋短いカバー（要点3行＋節マップ）。ペースへの言及はしない。％表示は出さない。
- 規律：GameCore・乱数・GameConfig 既定値は触らない（触るなら規律A＝要オーナー判断）。UI変更は sim 目視まで（D-10）。新規 Swift ファイルは `cd ManzaiGame && xcodegen generate`。1目的1コミット＋末尾 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`。新規ゲーム内テキストは `.claude/skills/manzai-drama-voice/` を通す（第1便は新規文言ゼロ＝既存文の分割のみ）。
- SourceKit の「No such module 'GameCore'」「Cannot find 'Theme'」は索引の誤検知。正は xcodebuild。
- サブエージェントは過去4回利用制限で止まった。使うなら「最初に骨組みを書いて節ごとに追記」を必ず指示（`docs/visual_overhaul/_brief_common.md` 末尾）。

### ビルド・撮影コマンド（scratchpad は消えるので再作成する）
```bash
# ビルド→インストール（iPhone 17）
cd ~/manzai-game/ManzaiGame && xcodebuild -project ManzaiGame.xcodeproj -scheme ManzaiGame -destination 'platform=iOS Simulator,id=E5D11233-FE99-429F-A55C-8B0FA5793568' -derivedDataPath build/dd build -quiet && xcrun simctl install E5D11233-FE99-429F-A55C-8B0FA5793568 build/dd/Build/Products/Debug-iphonesimulator/ManzaiGame.app
# 起動（環境変数は SIMCTL_CHILD_ 接頭辞）→撮影
SIMCTL_CHILD_MZ_UI=stage xcrun simctl launch --terminate-running-process E5D11233-FE99-429F-A55C-8B0FA5793568 com.manzaigame.mvp
xcrun simctl io E5D11233-FE99-429F-A55C-8B0FA5793568 screenshot ~/manzai-game/feedback_shots/overhaul_v1/after_XX.png
# 本番画面の明るさの検収（目標 平均L≥0.18・点灯面積≥35%・紫の暗部ほぼ0）
python3 tools/measure_brightness.py feedback_shots/overhaul_v1/after_*.png
cd GameCore && swift test   # 78件 green を維持
```
- 確認用フック（DEBUG）：`MZ_UI=stage|event(MZ_EV=0013等)|pass|notebook|neta|calendar|settings|ending|cards|frame(MZ_MODE=preshow/lit/judging/winner/loser/spectator)`、`MZ_SMOKE=1(大会結果)|2(大会入口)|3(客席から観る決勝→年末)|4(優勝の決勝)|5(優勝の年末)`、`MZ_FIN=open|board|duel|win`（決勝のビート直行）、`MZ_RANKUP=1`（等級チップ）。
- 初回の開演の儀・イントロを見るには `xcrun simctl uninstall … com.manzaigame.mvp` → install。
- タップは iOS Simulator の control ツール（device=上のUDID）。tap と screenshot は別手番。点(pt)＝画像px÷3。

## §3 次にやること（第2便・正本 §6）
| # | 内容 | 主に触るファイル |
|---|---|---|
| D1 | Dynamic Type 追従（読む部品は `accessibility2` まで・札/判/数字は固定）＋375×667 で崩れを撮る。`Font.maru(_ step:)` を `relativeTo:` 対応に | `Theme.swift`・各画面 |
| S1 | 勇退エンディング：真っ黒をやめ StageFrame の満員の興行→夕景のエピローグ（NarrationCard）→緞帳 | `S6bView.swift` |
| N1 | ネタ帳「ちから」に等級と数字（レーダーの縮尺は L 済み）・ネタタブの字を段へ・ボタンの主従 | `NotebookView.swift` |
| N2 | カレンダー：済んだ大会の判（通過/敗退）・現在週の強調・大会名 | `CalendarView.swift` |
| N3 | 設定：「演出ひかえめ」（Reduce Motion と同じ写像）・BGM 既定値の食い違い（画面70/実60）を直す | `SettingsView.swift`・`SoundManager.swift` |
| W3 | 行動カードの押下音の二重鳴り（`PressableStyle(silent:)`）・常設4枚の高さ固定・下帯の375pt溢れ | `WeekMainView.swift` |
| P1 | 全ボタンの沈みと音（`.plain` 残り）・▼の送り音 | 各画面 |
| P2 | 背景2枚（帰り道・事務所）とイベント場面の割り当て（`ChoiceEventData.scene`） | 新規背景・`ChoiceEventOverlay.swift` |
| P3 | 41画面の撮り直し（`feedback_shots/overhaul_v1/README.md` の表と同じ順で after を撮り、索引に追記） | — |
その後 Phase 7：オーナー試遊（①育成ゲームの領域に入ったか ②一番ワクワクした画面/まだ暗い・読みにくい画面 ③1週の秒数と迷った週の数）→正本 §8 に記録→次の一手を1つ提案（候補＝§7-2「舞台に立つ単独で実力が動かない」数値論点・規律A）。

## §4 第1便で入ったもの（コミット順の要約）
- 土台：フォント名修正 `RoundedMplus1c-*`（L1）／イベント選択直後の空欄（L2）／優勝年の年末記録（L3）／Beat2 とイベント提示の作り直し（L4・`showEvent`＋`syncEventPresentation`）／大会結果の開示を保持タスク＋タップで判へ（L5）／`Sound.duck`・`hushSE`・取り消せるフェード（L6）／`FinalsBeat` 列挙＋見せ札キャッシュ（L7）／v1 トークン・`TypeStep`・`.hardShadow`（L8）／`TalkParts.swift`（TalkBubble・NarrationCard・ChoiceCard・GainChip・AdvanceCue・NameTag）＋Juice の Reduce Motion（L9）／`StageFrame.swift`（StageFrame・FlipCard・Telop・StageCeremony）＋`tools/measure_brightness.py`（L10/L11）。
- 画面：イベント（E1/E2）・回想/名付け/タイトル（I2/I3/I1）・大会結果（R1）・決勝（F1〜F3）・大会入口/本番前（T1）・年末（Y1）・週メイン（W1/W2）・開演の儀（L11）。
- 未目視（到達させるフックが無い）：GP本番前 `StagePreludeView`、敗者復活で散る山場（`TournamentResultView.climaxOverlay`）。必要なら DEBUG フックを足して目視する。

## §5 材料の場所
- 正本 `docs/visual_genre_overhaul_v1.md`／材料 `docs/visual_overhaul/`（research 5・audit 3・blue 3＋mock・red 4＋recheck）／撮影 `feedback_shots/overhaul_v1/`（README＝before 41枚の索引、`after_*.png`＝第1便の目視）。
- オーナー向け判断材料ページ（Artifact・非公開）：https://claude.ai/artifact/WEXRed65xE337AREzJpcak
- 未追跡の `.claude/worktrees/` は前セッションの残り（触らない）。

## §6 新セッション用のキックオフ文（コピペ用）
> manzai-game の見た目の作り直し v1 の続き。まず `~/manzai-game/docs/visual_overhaul/handoff_v1.md` を読み、§2 の運用（sim は iPhone 17 だけ）に従って、§3 の第2便を D1 から順に、画面ごとに1目的1コミット・sim 目視・push で最後まで実装して。終わったら Phase 7 の試遊の準備をして私に声をかけて。
