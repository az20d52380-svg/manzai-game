# コード点検 2026-10-26d（定期の回）

対象：4bdcc1a（26c の点検）以後のアプリの変更 7 ファイル（ChoiceEventData の言い換え5行・新春の備えの戻し・目視の早送り台本の体力の守り・目視フック MZ_NETA_PICK／MZ_QUIT／MZ_WEEK=farewell／MZ_EVWEEK）。

## 結果
- 本番の動きを変える不具合は見つからなかった。
- 目視フックはすべて `#if DEBUG` の内側（MZ_QUIT は SettingsView の onAppear の DEBUG 内・MZ_WEEK は debugWeekHook ごと DEBUG）。
- 前からあった `MZ_NETA_OPEN`（NetaSelectionView）だけ DEBUG の外にあった＝本番では環境変数が無いので害はないが、他のフックとそろえて DEBUG の内側へ移した。Release 構成のビルド OK。
- 全ソースを走査して、`MZ_` を読む所で DEBUG の外にある物は他に 0 件。
- debugFreeWeek の「体力25未満なら休む」は DEBUG の早送り専用。アプリ側テスト 212 green（selftest の対象外）。
