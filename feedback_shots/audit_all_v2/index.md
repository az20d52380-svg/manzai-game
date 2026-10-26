# 全画面監査 audit_all_v2（iPhone 17・MZ_NOCHIP=1・900px・preview-all 4fd3447＋DEBUGフック1行）

## 崩れの候補（v1比）
明らかな崩れ（重なり・見切れ・空白・読めない）は並べて見た範囲で検出なし（v1→v2は大幅な作り直しで全画面の見た目が変わっている）。要確認のみ:
- 49 複数年_2年目: 画面下にトースト（『商店街の福引』…）が「お店」ボタンと所持金に重なる（状況依存の一時表示）。
- 26 preshow／29 loser: 撮影タイミング次第で状態が違う（幕のみ・演出途中）。崩れではないが v1 と同一状態ではない可能性。
- 44 年末リザルト: 下端で本文が見切れ（v1 も同様・スクロール想定か要確認）。

## 撮れた物
- 01〜48（47は11枚）＋49 = 58枚（番号・画面名・開き方は audit_all_v1/index.md と同じ）。
- bg_<場所>_<day|night>.png 22枚（keikoba/station/apartment/gakuya/train/park/famires/sento/theater/kissaten/office × 昼夜・全て昼夜で色味が違うので間引きなし）。背景は画面中央の帯のみ・上下は生成り（EventPlace単体表示）。

## 49 複数年_2年目
MZ_UI=stage が session を作り直し（year=1に戻る）MZ_YEARS が打ち消されていた。RootView.swift の stage/juice 分岐に `session.year == 1` を足して解決（commit済・preview-all）。コマンド: MZ_UI=stage MZ_YEARS=1 → 「2年目 第1週」表示を確認。

## 撮れなかった物
- 敗者復活の山場・決勝の負け版・（30 spectator は枠のみ）: 専用フック無し（v1と同じ）。通知許諾（MZ_UI=notif）は対象外。
