# tools/*.py 動作確認 2026-10-26（v0）

対象 109 本（前回 10/19 は 91 本。その後に増えた18本を含む）。試行回数は n=5 等の最小で、1本60秒まで。スクリプトは一切書き換えていない。追跡ファイルの変更なし。

## 集計

| 分類 | 本数 |
|---|---|
| ok（終了コード0） | 99 |
| 失敗 | 5 |
| 重いため未実行（60秒超） | 2 |
| 意図して未実行（golden を書き換えるため） | 3 |

**前回 ok だったのに今回失敗した物：0本。** 失敗5本はすべて前回の「以前から動かない過去の実験」6本の中身と同じ。

## 失敗（5本・すべて前回から動かない）

- exp_fame62.py：AttributeError: module 'sim_career' has no attribute 'FAME_OTHER_MULT'
- exp_money_balance_v1.py：同上（FAME_OTHER_MULT）
- exp_q60_62.py：同上（FAME_OTHER_MULT）
- exp_money_harshness_v0.py：AssertionError
- exp_offer_named_v0.py：ValueError: 'ラジオ' is not in list

## 前回から動かない（6本）

上の5本と measure_brightness.py。measure_brightness は画像パスを引数に取る道具で、今回は引数なしで走らせて終了コード0（実画像での動作は未確認）。

## 重いため未実行（2本）

- sim_meta.py：n=2 でも60秒を超えた（60秒で打ち切り）
- exp_corner_multiseed.py：引数なしの固定実行で60秒を超えた

## 意図して未実行（3本）

- gen_golden.py、gen_golden12.py：golden を書き換えるため実行しない
- gen_golden_features.py：同上（出力先が追跡ファイル）。check_golden_sync.py が一時ファイルへ出力して突き合わせる形で間接的に走り、ok

## ok（99本）

check_golden_sync.py（golden 一致）を含む。n=5 で走らせた物のほか、次は引数の都合で別設定：
- bots_v3・canon_v2 は引数なしで ok。exp.py は引数なしで27秒（並列実行時は60秒超だったが単独で ok）。
- exp_event_b_ranking_v0.py は n=3 top=1 topn=3（既定の topn=1000 が重いため）で ok。
- exp_meta_start_bonus_1020_v0.py は n=2 で26秒（n=5 では60秒を超えたため）。

残りは n=5 で終了コード0：
balance_sim bots_v3 canon_v2 check_golden_sync diag_fame_mult_v0 diag_mid_room_rift_v0 exp exp_ability_stall_v0 exp_balance_snapshot_v0 
exp_challenger exp_compat_loss_rift_v0 exp_corner exp_debt_warning_v0 exp_decay exp_drink_invite_v0 exp_dynasty_matrix exp_dynasty_seed_vs_qual 
exp_dynasty_v2 exp_dynasty_v3 exp_dynasty_v4 exp_endgame exp_endings_distribution_v0 exp_event_b_ranking_v0 exp_event_budget_choice_v0 
exp_event_cap_v0 exp_event_scale_v0 exp_event_scale_v1 exp_events exp_events_app_ablation_v0 exp_events_app_v0 exp_exp_rebalance_v0 
exp_exploit_diag_v0 exp_exploit_fix_sweep_v0 exp_exploit_search_v0 exp_exploit_search_v1 exp_exploit_search_v2 exp_fifteen_years_1020_v0 
exp_first_rank_cost_1019_v0 exp_first_rankup_v0 exp_fun_audit_v0 exp_human exp_human_fix exp_human_fix2 exp_injury_v1 exp_items_q103_v0 exp_items_v3 
exp_items_v4 exp_lastyear exp_lastyear_fable exp_lastyear_gate exp_meta exp_meta_curve_v3 exp_meta_curve_v3_extend exp_meta_curve_v3_opts 
exp_meta_curve_v3_r2 exp_meta_start_bonus_1020_v0 exp_money_after_merge_v0 exp_money_all_v1 exp_money_cap_v1 exp_money_price_v1 
exp_money_sink_candidates_v0 exp_multi_ending_v0 exp_neta exp_neta_stale exp_neta_v2 exp_office_choice_v0 exp_pity exp_pity2 exp_pity3 exp_places_v1 
exp_q60_q62_remeasure_v1 exp_q93_r2m_current_v0 exp_q93_retune_v0 exp_rebalance_options_1019_v0 exp_renpa exp_rests_v1 exp_rift_measure_v0 
exp_room_rent_exploit_v0 exp_rooms_q90_v0 exp_skills_q106_v0 exp_stuck_money_l exp_stuck_v0 exp_talent_ability exp_the_hana_1025_v0 
exp_tourney_exp_1020_v0 exp_v2_anchor exp_v2_meta exp_v3_anchor exp_winter_cup_v0 exp_year1_compat_curve exp_year1_compat_once exp_year1_levers 
exp_year1_wall find_golden_seeds_v0 measure_band_reference_v1 measure_blank_weeks_v1 measure_brightness sim_career sim_gacha 