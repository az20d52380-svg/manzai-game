# 画面の文の採点（281004e5a..HEAD）v0

## 対象範囲
- `git diff 281004e5a..HEAD -U0 -- ManzaiGame GameCore/Sources` の追加行のうち日本語を含む89行。コメント行を除いた中身は、ほぼコード（比較用文字列・テスト・アクセシビリティ）。
- 画面に出る・読み上げられる文は **20本**（AbilityUp 3、ComboKindPicker 1、CommandData 4、FirstStage 1、NetaSelection 2、Notebook 1、RadarChart 3、RentStatement 3、Settings 2）。
- キャラ会話・講評の新規追加は無し（DialogueData の差分は「俺」の名前指定と除外フィルタ＝比較用文字列のみ）。よって v3 バナー（お笑い要素なし・日常会話）の違反は出ようがない。
- 採点対象外：FanReportData / YearResultView / DialogueData のフィルタ語（`contains("予選")` 等）、テスト内の文。

## 集計
○ 19 ／ △ 1 ／ × 0

## ×の行
なし。

## △の行
- AbilityUpView.swift:181 「G、F……と上がっていく。上の「現在」と「アップ後」で、上がったランクが分かる。」
  - 理由：ランクの並び（G→S）が初見では分からない／2文目がやや硬い。
  - 直し案：「ランクはG、F、E……と上がっていく。「現在」と「アップ後」を見比べると分かる。」

## ○は件数だけ
19（業界語・関西弁・ネタ本文・％表示なし。数値の復唱や事実との食い違いなし。RentStatement の「今月も払えた／円足りない」、CommandData のオファー説明＝仕事の内容・お金・疲れの日常語、を含む）
