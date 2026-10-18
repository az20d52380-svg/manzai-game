# 測定道具の修理：並列実行の上書き漏れ（2026-10-19）v0

## 要点3行
- 原因：`Pool(maxtasksperchild=1)` でも `map` の既定 chunksize が 2 以上になると、1つの子プロセスが複数の案を続けて処理し、前の案の上書き（C./B. の変数）が残る。`Pool(10)`（maxtasksperchild なし）は常に漏れうる。
- 直し：実験スクリプト23本の Pool を `maxtasksperchild=1` に、`p.map(...)` を `chunksize=1` に統一（正典・既定値・golden は未変更）。
- 影響：4本の再測定のうち結果が変わったのは exp_q60_q62_remeasure_v1 の n=300 参考表だけ（最大 約8pt）。n=1000 の本表と結論は不変。

## §1 判定の一覧
- 漏れうる＝直した（23本）：diag_mid_room_rift_v0, exp_balance_snapshot_v0, exp_compat_loss_rift_v0, exp_debt_warning_v0, exp_drink_invite_v0, exp_endings_distribution_v0, exp_event_cap_v0, exp_events_app_v0, exp_injury_v1, exp_items_q103_v0, exp_money_after_merge_v0, exp_money_sink_candidates_v0, exp_multi_ending_v0, exp_offer_named_v0, exp_q60_q62_remeasure_v1, exp_q93_retune_v0, exp_rift_measure_v0, exp_room_rent_exploit_v0, exp_rooms_q90_v0, exp_skills_q106_v0, exp_stuck_money_l, exp_stuck_v0, exp_winter_cup_v0。
  - うち Pool(10) だけ（maxtasksperchild なし＝常に漏れうる）：balance_snapshot, event_cap, multi_ending, rift_measure, stuck_money_l, stuck_v0, debt_warning, endings_distribution。
  - 残りは maxtasksperchild=1 だが chunksize 既定＝「案数×ボット数 > 4×CPU(10)」で漏れうる。
- 漏れない（元から安全）：exp_first_rank_cost_1019_v0・exp_first_rankup_v0・exp_rebalance_options_1019_v0（imap_unordered＝chunksize 1＋maxtasksperchild=1）、exp_events_app_ablation_v0・exp_exploit_search_v0/v1・exp_exploit_fix_sweep_v0・exp_exploit_diag_v0・exp_money_harshness_v0・diag_fame_mult_v0（元から chunksize=1＋maxtasksperchild=1）。
- 案ごとの全変数の再設定では判定していない（全スクリプト一律で プロセス分離 に統一）。

## §2 直す前後の差（n=300・同条件）
| スクリプト | ジョブ数 | 差 |
|---|---|---|
| exp_money_after_merge_v0 | ≤40 | なし（出力一致） |
| exp_events_app_v0 | 24 | なし |
| exp_room_rent_exploit_v0 | ≤40 | なし |
| exp_q60_q62_remeasure_v1 | 56（chunksize 2） | あり：56行中28行が違う。決勝到達で最大 約±8pt、知名度3年中央値は 33→93 など大きくずれた（前の案の知名度上書きが残っていた） |
注：前3本はジョブ数が 4×CPU 以下で chunksize が 1 になるため元から漏れていなかった。直した版を2回回して出力が同一（決定的）なのも確認。

## §3 撮り直しと影響
- exp_q60_q62_remeasure_v1 を n=1000 で撮り直し（5分半）。本表（旧／Dのみ／Gのみ／D+G0.6）は docs の既存値と一致＝影響なし。ずれたのは n=300 参考表の3案（E3年／D+G他×1.0／D+v62）だけで、`docs/q60_q62_remeasure_v1.md` に「【10/19 撮り直し】」注記と新表を足した（古い表は残す）。生出力 `docs/measure_raw/q60_q62_remeasure_v1_clean_1019.txt`。
- 結論は変わらない（推奨D・G他×0.6 のまま。他×1.0 が決勝で低い順も不変）。
- 未再測：money_after_merge 等は差が出なかったので文書は変更なし。Pool(10) 系（balance_snapshot, event_cap, multi_ending, rift_measure, stuck_*, debt_warning, endings_distribution）の過去の表は漏れていた可能性がある。上書きが案ごとに全部設定し直しなら無害だが、未確認＝必要なら撮り直し（判断はオーナー）。
