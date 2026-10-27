# 参照0の画面部品の一覧（2026-10-27 深夜の定期）

アプリ（ManzaiGame/Sources）で、宣言の行のほかにどこからも名前が出てこない型を機械で拾った（テストからも参照0）。**何も消していない**。消すか使い道を当てるかはキュー118（背景の作り直し 72 とまとめて）で判断。

## 要点
- 参照0の型は12個（約270行）＋それにぶら下がるだけの部品（DuskScene・PlaceScene・ChoiceEventData.scene(for:)・ChoiceEventOverlay の private var scene＝約250行）。合わせて約520行。
- 多くは作り直しで置き換わった跡（選択イベントの背景は EventBackdropTable へ・吹き出しの部品は今の会話の部品へ）。
- 消してもゲームの数値・セーブ・golden に影響なし（見た目の部品だけ）。

## 一覧（ファイル：型・行数）
| ファイル | 型 | 行数 | 見立て |
|---|---|---|---|
| ChoiceEventOverlay.swift | EventSceneView（＋DuskScene・PlaceScene・scene(for:)） | 13＋約235 | 選択イベントの古い背景。今は EventBackdropTable |
| StageViews.swift | WaveformView | 86 | 舞台の波形の演出（未使用） |
| TalkParts.swift | TalkBubble・ChoiceCard・GainChip | 35・15・17 | 会話の古い部品 |
| WaIcons.swift | WaIcon | 34 | 和柄のアイコン（未使用） |
| StageFrame.swift | YoseAdvanceCue | 16 | 「次へ」の合図（未使用） |
| AbilityUpView.swift | HexEmblem | 14 | 能力アップの六角の印（未使用） |
| Theme.swift | CurrencyBadge | 11 | code_review_2026-10-19m §3 で既出 |
| WeekMainView.swift | DogEar・BubbleTail・BounceArrow | 11・9・10 | 吹き出しの古い部品（BounceArrow はキュー118 で既出） |

## 選択肢
1. 全部消す（約520行・ビルドとテストで確かめる）【推奨＝今の画面に出ない・読みやすさが上がる】
2. 背景の作り直し（72）で使えそうな物（PlaceScene の場所の絵・WaveformView）だけ残して他を消す
3. 今のまま

## 拾い方
`python3` で Sources の `struct/enum/class/func` の名前を集め、全ソースでの出現が1回（宣言だけ）の物。#Preview の中だけで使う物はこの一覧に入らない（出現2回以上になる）。
