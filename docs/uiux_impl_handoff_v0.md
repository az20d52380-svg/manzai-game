# UI/UXビジョン実装トラック 引き継ぎ v0 — Fable実装分の記録と残り全量の順序

- 日付: 2026-07-07
- 位置づけ: UI/UXビジョン全4便回答（`uiux_vision_reply_part1〜4_v0.md`・全確定・未決ゼロ）の**実装トラックの正本**。ブリーフ記載の次工程「実装可能性・コスト感の整理→正本反映」を兼ねる。第一弾はFableセッションが実装済み（§1）。**以降はCLI（4.8）セッションがこの順で進める**（合言葉: Fableは金型を彫る・4.8は鋳込む）。
- 設計の正本は4便の回答doc（各画面のレイアウト/トランジション/マイクロ/音ハプ＋実装ブリッジ）。本書は「どこまで済んだか・次に何を・どう検証するか」だけを持つ。

## 1. 実装済み（2026-07-07・コミット 352d1e9〜bf39457・全てpush済み）

| # | 内容 | ファイル | 検証 |
|---|---|---|---|
| 1 | **§3-0トークン**（Space/Rad/Motion5段/ink影e1〜e3/Haptics3段）+ Pressable改修（沈み0.97+明度−6%・無効は沈まない）+ ShakeEffect | `Theme.swift` | ビルド+目視 |
| 2 | **S2(B)マイクロ**: 引き抜きフェード0.12s→hTick→実行／実行不可=横ブレ+トースト／不足コストのみstaminaCrit塗り／体力ゲージ閾値明滅（黄1/赤2）+色クロスフェード／トースト=最下帯上+16pt／カテゴリ⇄変種0.18s | `WeekMainView.swift` | ビルド+目視（静止状態） |
| 3 | **器の充填**: 演技系4種のみ能力色で満ちる（value/abilityCap・数値なし）・メンタル/相性は器なし・上限でgold縁 | 同上 | 目視（10/120と115/120） |
| 4 | **+N規格**: 出現0.2s+8pt浮き→滞留0.6s→退場0.4s上昇フェード | 同上 | ビルドのみ（※実タップ未検証） |
| 5 | **S3判の§3-5規格**: 角判rStamp4・通過=verm/敗退=ink・押印0.2s+hConfirm＋**段階開示**（判→0.4s→講評→0.6s→星/賞金/次へ） | `TournamentResultView.swift` | ビルド+目視（MZ_SMOKE=1） |

**未検証の残り（次に実機/simulatorを手で触るとき）**: カード連打時の横ブレ・トースト実位置・引き抜きの見え方・体力50/20跨ぎの明滅・hTick/hConfirmの振動（simctlはタップ注入不可のため静的目視のみ実施）。

## 2. 検証環境（このまま使う）

```bash
# ビルド（GameCoreのWIPが居ても現状green・2026-07-07時点）
cd ManzaiGame && xcodebuild -project ManzaiGame.xcodeproj -scheme ManzaiGame \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/dd build
# インストール＆起動＆スクショ
xcrun simctl install "iPhone 17 Pro" build/dd/Build/Products/Debug-iphonesimulator/ManzaiGame.app
SIMCTL_CHILD_MZ_UI=cards xcrun simctl launch --terminate-running-process "iPhone 17 Pro" com.manzaigame.mvp
xcrun simctl io "iPhone 17 Pro" screenshot /tmp/shot.png
```

- **UIスモーク環境変数**（DEBUG限定・`SIMCTL_CHILD_` プレフィクスで渡す）: `MZ_UI=cards`=稽古カード列で起動／`MZ_UI=grown`=能力マックスで週メインに留まる／`MZ_SMOKE=1..5`=既存（初結果/大会入口/年末/優勝/優勝ボード）。目視フックが足りなくなったら**この慣習で増やす**（本導線は不変のまま）。
- SourceKit(LSP)の「No such module」診断は索引の誤検知。**正はxcodebuild**。

## 3. 残り実装の順序（回答docの実装順提案の統合・上から順に）

**Part 1（単年キャリア・正本=part2）**
1. ~~S2(B)~~ ✅ → **S6 年次リザルト**（判/レーダーCanvas新規/行動内訳帯。レーダーは**S5・大会後と3画面共用**部品として書く）
2. **S1 タイトル/結成**（KV(B)切り絵3層・名入力見開き・**紙芝居プレイヤー部品**=S6b/優勝エピローグ共用）
3. **S5 ネタ帳**（見開き・レーダー流用・器の弧）→ **S4 カレンダー**（48セル・表示専用getter=RNG非消費厳守）
4. 薄物 **S1b/S1c/S6b** → **S2(A)仕上げ**（matchedGeometry色連結・表情差分フック・微動・時間帯照明・音の階段）
5. S3残り: 会場テロップ様式3種の出し分け（ベテラン=観客ボード/復活=実況。**形式を混ぜない**）

**Part 2（周回間・正本=part3）** — 着手前に**GameCore外の永続レイヤ**（名鑑所有・抽選・天井・人脈P・連覇フラグ）の設計すり合わせを1回置く（part3依頼6）
6. **S8(B)** 排出の骨格（暗転→カード→彩色0.4s・SE断0.6sだけは死守）→ **S7**（見学札・壁）→ **S10/S10b**（サンパチ表記・煽り禁止トーン）→ **S8(A)**（廊下・ドア・木札）→ **S9 王者編**
7. **Part 3（正本=part4）**: S11（綴り・貼り紙・週非消費）→ S12（棚・記録の帯・年表）

**アセット**: part4依頼5の**(B)最小到達版＝必須ティア+簡易版列（外部発注ゼロ）**で開始。増強順は①決勝SE4種②S8ドアSE3種③主役2体の半身差分④審査員21枚⑤BGM階段。

## 4. 規律リマインダ（CLAUDE.mdの実装トラック適用）

- **GameCore・golden・乱数消費順に触れない**（全て表示層。getterが要る時はRNG非消費で追加し、消費順に影響しないことを確認）
- 新規Swiftファイル追加時は `cd ManzaiGame && xcodegen generate`（D-9・pbxproj手編集禁止）
- UI変更は**simulatorビルド→起動→目視まで**で「完了」（D-10）。本書§2のスモークフックを使う
- 1コミット=1目的・正本docの§参照をメッセージに（例: 「正本: part2 S6」）・作業前pull/区切りpush
- 課金石の呼称=**サンパチ**確定（UI表記主・法務は「石」併記）。`gold`はマイルストン専用＝課金UIに使わない
- ターミナル側の ChoiceEvent WIP（WeekRunner.swift+ChoiceEventEffect+EventEffectTests）は**別トラックの所有物**——コミットに巻き込まない

## 5. CLIキックオフ（コピペ用1行）

> docs/uiux_impl_handoff_v0.md を読み、§3の順序で次の未実装画面から着手。設計詳細は uiux_vision_reply_part1〜4_v0.md の該当画面（4小見出し+実装ブリッジ）を正本とし、§2のスモークで目視検証、§4の規律で1コミットずつ進めること。着手前に ChoiceEvent WIP を先に決着（コミット&push）させるか、巻き込まない運用を確認。
