# 優勝後「勇退／続ける」の点検 11/07（e42bba2d・448afa1f）

## 結論
コードの穴は見つからず（直した不具合なし）。目視（iPhone 17）は崩れなし。テストを1本足した（連覇の2回目の優勝）。

## §1 コード点検（異常なし）
- 復元：`winAcknowledged` は「finished かつ優勝」で保存。閉じて開き直すと演出ではなく選ぶ画面へ。旧セーブ（nil）は演出から＝従来どおり。勇退を選ぶと careerOver でセーブ削除（`retiredAfterWin` を保存しないのは意図どおり）。
- 連覇：`startNextYear` で `didRecordChampion` を戻す。streak は yearHistory の末尾から数える。玉座奪還 t20 は「前に優勝・前年は非優勝」のみ（連覇では付かない）。
- 年またぎの持ち越し：`totalPrize`・`didWatchFinal`・`lastFinalMargin` は年初に戻る。`didFireEve` 等の一発イベントはキャリア通算（設計どおり）。`smallEntered/Won` は yearDone で戻る。二重計上の経路なし（yearHistory は `last.year` で守る）。
- 最終年の優勝：`canChooseRetire` は careerOver で false → そのままエンディング。
- エンディング：続けて最後の年まで走ると、優勝歴があれば championPair／Retire（judge）。t18 は優勝歴があれば付かない。
- 軽い所見（直さない）：ShareCard の見出しは2回目以降も「優勝」だけ（連覇の表記なし）。

## §2 目視（iPhone 17）
DEBUG に `MZ_UI=yearend MZ_MODE=champion2`（続ける→2年目の週画面）／`champion3`（2年目も優勝した年末）を追加（RootView.swift・DEBUG内のみ）。
- 1年目優勝の年末：2択（勇退する／続ける（2年目へ））が並び、主は右の続ける。崩れなし。
- 2年目の週画面：1年目の記録を引き継いで正常。
- 2年目優勝の年末：「続ける（3年目へ）」。崩れなし。
スクショ：scratchpad の champion*.png

## §3 判断が要る物
なし。
