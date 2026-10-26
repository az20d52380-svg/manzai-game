# 決勝の番組化 残り（設計 finals_broadcast_argon_v1.md §4）
済: 順位1（場面1オープニング）・順位6の前半（場面2審査員席・場面3進出組）= FinalsBroadcastIntro.swift（MZ_FIN=vtr/title/judges/finalists）
未: 2 スタジオ照明背景差し替え／3 優勝の瞬間（YoseChampionCelebrationView接続）／4 採点7連電光めくり／5 暫定3席ボード／7 LIVEヘッダー・下三分の全場面常設／8 籤の心拍・登場の扉／9 最終決戦の照明替え・出順選択・王手溜め／10 予選へ波及
目視未実施（sim 使用中のため）。

## 更新（番組化 続き・preview-all）
済（ビルド・swift test green／目視未実施＝sim 使用中のため）:
- 2 スタジオ照明（FinalsStudioLights: 金サーチライト／最終決戦は真紅×群青）
- 3 優勝の瞬間（resultへ入る時に YoseChampionCelebrationView を重ねる・賞金=gpPrize・タップで完成→先へ）
- 4 採点: 95点以上の金枠発光＋強振動／合計の0→カウントアップ／暫定順位の朱印（1人ずつめくるのは従来どおり）
- 5 暫定3席ボード（seatCard 3つ＋押し出し帯＋4位以下は敗退行）
- 7 LIVEヘッダー常設（FinalsLiveBar）※下三分は従来の StageLowerBand
- 8 出番くじの心拍（4拍/初回・1拍/以降・タップで畳む）／登場の扉（扉が割れて逆光・紹介テロップ=出番と結成年のみ）
- 9 最終決戦の照明替え／王手（3票）の札＋決定票前の無音溜め（初回0.9s/以降0.35s）
- 12 番組エンディング（FinalsBroadcastEnding・結果ボタン→エンディング→出口）
- 10 予選: 看板アイキャッチ(1.15→1.0)／LIVE下三分(コンビ名・結成年・週)／通過時の精算枠が金に光る
未: 出順選択（結果に影響しない選択UIになるため見送り）／肩書・連続出場年（元データ無し）
DEBUG: MZ_FIN=lot/pre/door/open/total/comments/board/seats/duel/oute/win/champ/ending（vtr/title/judges/finalists は導入）。MZ_FMARGIN=正で優勝・負で敗退。
