# preview-all 通しスモーク v2（2026-10-16・ブランチ preview-all）

## 結論
落ちる・進めない不具合は **見つからず**。直したコードなし。DEBUG の自己点検 `MZ_SMOKE=selftest`（GameSession.swift 末尾・RootView.swift:+1）を追加（実プレイ非経路）。重い順の不具合リストは空。気づき3件は下。

## 1. swift test
`swift test --package-path GameCore`：137 件・失敗 0。

## 2. 自動通し（iPhone 17）
- `MZ_SMOKE=3`＋`MZ_YEARS=0/2/9`：3本ともプロセス生存・クラッシュレポートなし。既定の台本は2〜3年目で「解散」になり、年末に「エンディングへ ▶」が出る（撮影 feedback_shots/smoke_v2/y0,y2,y9.png）。10年完走は台本が相性を保てず解散で止まるため、selftest で riftOn=false にして完走させた（下）。
- タップ操作（エンディングへ→場面送り）は途中でツールの判定エラーが続き、1枚目（#2「右と左」1/3）までしか目視できず。図鑑記録はコード読み（EndingViews.swift:50 の onAppear で EndingBook.record）で確認。

## 3. エンディング到達（selftest・headless・[ST] 行）
- #1 夜逃げ：所持金を借金ライン手前に置いて週を進める→第4週で bankrupt→ending=#1。
- #2 解散：既定台本4シード＋rift=97 開始のどちらも dissolved→ending=#2（3年目 第19〜29週／rift直指定は2年目頭）。
- #7/#8 優勝：相性10→#7、相性19→#8。
- 10年完走（riftOn=false）：能力20×相性5→#3、能力20×相性20→#4、能力70以上は早期優勝（#7/#8）。#5/#6 は完走プレイでは出せず、判定表（EndingID.judge に finals/compat 4通り）で #3/#4/#5/#6 の対応を確認（実プレイでの #5/#6 到達は未確認）。
- 図鑑：record 呼び出しで [1,2,7,8] が保存・読み戻せた（EndingBook は UserDefaults）。

## 4. イベント
- 0050：rift 49・相性3開始で第2週頭に発火（1回）。A「向き合う」＝rift 50.3→20.3・体力−10、B「流す」＝rift 変化なし・体力変化なし。riftWarnChoice に A/B が入る。
- 0041〜0049：60シード×最長10年の抽選で 0041・0042・0043・0044・0045・0046・0047・0048・0049 すべて発火を確認。

## 5. 古いセーブ
名前・rift・debtWarnTier・didFireRiftWarn・riftWarnChoice・yearStartState 等を消した JSON を復元：restored=true・broken=false・その後5年目まで自動プレイ継続。落ちない。

## 気づき（不具合ではない・判断材料）
1. 年末・エンディング画面の肩に「優勝」「無双」の称号札が出る（解散の年でも、過去の年の称号か要確認）。GameSession の称号表示。
2. 連敗3回の styleTalk（会話イベント）は、選択せず流すと styleTalkDone が立たず、連敗が続く間は毎週出る（selftest の台本は選択するため60シード合計で246件＝1シードあたり約4回出ていた）。見送りを繰り返すと毎週同じ会話になる可能性。
3. compat20 開始でも長期では相性が落ち、rift が 100 に届いて解散（plain の台本で8年目）。解散エンドは10年内に現実的に出る＝想定どおりなら問題なし。

## 再現
`SIMCTL_CHILD_MZ_SMOKE=selftest SIMCTL_CHILD_MZ_ALLOWSAVE=1 xcrun simctl launch --console <UDID> com.manzaigame.mvp`（stderr に [ST] 行・最後に DONE。実行約1〜2分）。
