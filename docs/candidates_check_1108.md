# 候補ブランチの確認 11/08（`tools/check_candidates_build.sh`・どのブランチも書き換えていない）

本体 claude/manzai-slg-foundation-wprqlu に試しに重ねて確かめた。失敗を見逃さないことは、わざと壊した一時ブランチで確認済み（「ビルド失敗」と出た。一時ブランチは消した）。

## §1 結果（26本）
| 確かめたこと | 本数 | ブランチ |
|---|---|---|
| ビルドOK＋アプリのテスト全部通過（354〜355件） | 15 | a11y-tap-next・button-press-se・calendar-jan・final-year-history・lost-notebook-neta・mob-roster-per-run・money-short-choice・offer-desc-short・q-candidate・qual-long-list・revival-short・season-sure・tv-fatigue-display・week-hint-priority・yearly-goal |
| ビルドOKのみ（今回テストは回していない） | 8 | allocate-confirm・career-end-save・gacha-entry・money-format・money-format-cprime・retire-confirm・rift-trophy・unused-parts |
| 本体と衝突（ビルドせず） | 3 | the-hana-candidate・the-hana-candidate-r1027・vitalbar-numberpop |

GameCore の swift test と目視は候補ごとには回していない。入れる時に改めて確かめる。

## §2 衝突3本
- vitalbar-numberpop：衝突した所では、お金の浮き札が本体にすでに別の形で入っている（視差を減らす時の代わりの光り方まで本体の方が新しい）。数字が跳ねる方の差分が本体に全部入ったかは未確認。
- the-hana 2本：衝突のファイルは Calendar・WeekRunner など6つ。THE HANA は本体で動いているので古い候補とみられるが、1行ずつは比べていない。
- 3本とも消していない。消すかどうかはオーナー判断。

## §3 候補どうし
本体とは入っても、候補どうしは同じファイルで衝突する組がある（ManzaiGameTests.swift の末尾・YoseGameParts.swift など）。一覧は `bash tools/check_candidates.sh`。複数入れる時は順に取り込み直す。
