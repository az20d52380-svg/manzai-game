# 試作：観客の声を「判の前」に2〜4枚流す（オーナー確認待ち）

## 何を変えたか
- 前：判（通過/敗退）と講評が出た後に、ハマった夜だけ観客の声が1枚付いた。
- 後：予選の大会結果で、判が出る前に観客の声のカードが2〜4枚、1枚ずつ上がってくる。画面タップで次の1枚、右下の「飛ばす」で判へ直行。各枚は約2.4秒で自動で進む。点数は出さない。
- 声の選び方：通過なら点差が大きいと熱狂、小さいと手応え。敗退ならあと一歩だと五分五分、遠いと重い空気。ハマった夜は必ず先頭に1枚。5回に1回は最後の1枚を逆の空気（通る組に渋い声／落ちる組に熱い声）に替えて、合否を確定させない。
- 文は設計書 fan_report_design の既存文（熱狂・手応え・五分五分・重い・ミスリード）から。乱数は新しく使わず、年と週から決まる（同じ週は同じ声）。GameCore・数値は触っていない。紙講評の後の1枚は廃止（判の前に移した）。

## 画面
- docs/proposal_shots/fan_before.png（前）／fan_after_1.png（1枚目）／fan_after_2.png（3枚並び）／fan_after_judge.png（判）
- 目視フック：MZ_UI=pass MZ_FANREPORT=1（声を必ず出す）

## コード
- ManzaiGame/Sources/FanReportData.swift（voices）・TournamentResultView.swift（runFanVoices）

## ブランチ
- worktree-agent-ac29ee7140453988b（コミットは git log 参照）
