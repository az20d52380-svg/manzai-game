# 文の採点の一巡（11/10 朝〜昼の定期）まとめ v0

**結論3行**
- これまで○△×で見ていなかった画面の文と講評を、ほぼ全部（約1,000個）採点した。× は合計14件（仕組みの×1件を含む）で、全部試し版の枝 `claude/text-fix-1110-bundle-cand` 1本で直っている（GameCore 472・アプリ 402 green・golden 一致）。
- いちばん効く直しは「決勝で最低点の審査員が全褒め＋司会『少し辛めでした』」の食い違い（優勝した回の約4割で起きる）。
- 残りは △ の直し案（各文書 §3）と、名前・言葉選びのオーナー判断（下の §2）。

## §1 採点の一覧
| 対象 | 文書 | ○△× | 直し（試し版） |
|---|---|---|---|
| 予選の紙講評 v8 | judge_comment_score_v8 | 41/9/0 | △の重なり6件（judge-v8-fix） |
| 決勝の審査員コメント | judge_final_comment_score_v1 | 57/6/0＋仕組み×1 | 全褒めは最高点の側だけ（judge-final-highonly） |
| 決勝の司会 | finals_mc_lines_score_1110 | 12/5/2 | 「少し辛め」→点だけ・「割れましたねえ」外し（finals-mc-fix） |
| 決勝画面（司会以外） | finals_screen_text_score_1110 | 62/9/1 | 観戦の帯（finals-screen-text-fix） |
| 週メイン | weekmain_text_score_1110 | 39/12/5 | 超える・ボタン名・今週は（weekmain-text-fix） |
| 設定・用語集 | settings_text_score_1110 | 61/10/2 | ボタン名・今の（settings-text-fix） |
| 称号・トロフィー | meta_text_score_1110 | 29/15/3 | 説明文3（meta-text-fix） |
| ガチャ | gacha_text_score_1110 | 31/8/1 | 見出し（gacha-text-fix） |
| 大会結果 | tournament_result_text_score_1110 | 42/7/0 | — |
| 手帳・能力アップ | notebook_abilityup_text_score_1110 | 69/13/1 | ヒント（notebook-abilityup-text-fix） |
| 予選の知らせ・お店・暦・導入 | qualifier_shop_calendar_intro_text_score_1110 | 105/11/0 | — |
| 場面・結末・演出 | scene_ending_fx_text_score_1110 | 106/9/0 | — |
| お知らせ・コマンド・ネタ・提供割合 | session_command_neta_rates_text_score_1110 | 82/12/1 | 提供割合の注記（session-command-text-fix） |
| 小さな置き場 | small_text_places_score_1110 | 87/5/0 | — |

起きる割合の実測：judge_final_lowside_band_measure_1110（決勝全体1.6%・優勝した回36〜39%）。

## §2 オーナー判断の論点（まとめ・詳細は各文書 §4）
1. 名前：称号8つ（十年選手・六冠の年・季節名など）／THE HANA 優勝でも「日本一」／字幕「漫才師の頂点」・暫定席など実在番組の連想。
2. 言葉の統一：「稽古／練習」・「通過／突破」・「頂グランプリ／頂GP」・番手の数え方・カレンダーの「第N週」（通算か月内か）。
3. 説明の足し：導入に「結成15年が期限」・飽きの「新しいネタで元どおり」の読み違い・用語集の長い2項目を割る。
4. 講評：関西弁の講評を増やすか（天堂寺の1行）・来歴の行の出る割合・決まり書きのメンタルの線（40/20）。
5. 中身のずれ：ボイトレ「安い部屋」なのに8万円・サウナ「家よりよく休める」・衣装「ジャージ」が柄の段・ガチャの無料券が先（229）。
