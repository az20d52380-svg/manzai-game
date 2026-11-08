# 古い作業場所（git worktree）の片付けの材料（2026-11-08・判断の一覧 C-13）

何も消していない。消すかはオーナー判断（C-13）。

## 要点
- 作業場所は本体を除いて **56個・合計約13GB**（C-13 の時点の43個・8.7GB から増えた）。
- **56個とも、追跡しているファイルの未コミット変更は0**。`git worktree remove` は作業場所（フォルダ）だけを消し、ブランチは残る＝コミットは失われない。
- ブランチの状態：本体に入り済み 28／リモートに push 済み 12／手元だけ 16（多くは `worktree-agent-*`＝24日前のサブエージェントの作業跡）。
- 未追跡のファイルが残るのは5個（下の表）＝消す前にそれだけ見る。
- 11/08 に見つけた事：候補 `claude/rift-trophy-cand`（A-2 の候補）がリモートに無かった＝push した（aec46ccc）。

## 案
1. 何もしない（ディスクを使い続ける）
2. **作業場所だけ消す（ブランチは残す）**：未追跡のある5個は中身を見てから。今日（0日）使った物は最後に。＝推奨（コミットは失われない・約13GB 空く）
3. 2 に加えて、本体に入り済み（merged）のブランチも消す

## 未追跡のファイルがある5個
| 作業場所 | 未追跡 |
|---|---|
| agent-a77086bda5aa37589 | feedback_shots/playtest_v9/（スクショ） |
| agent-aa78456a4a6096108 | feedback_shots/prep_check/（スクショ） |
| agent-a8a528a4d9fbe53db | ManzaiGame/docs |
| agent-aa63b05f7908d6490 | tools/exp_gates.py・tools/exp_rho_sweep.py（118日前） |
| agent-af2352698c3ad0fa2 | docs/text_repeat_rate_v0.md |

## 一覧（作業場所｜ブランチ｜変更｜未追跡｜ブランチの状態｜最終更新｜大きさ）
- agent-a0250a74ec353acc8|claude/combo-intro-1107|変更0|未追跡0|merged|0日| 89M
- agent-a08f1242e9f2bdb7c|worktree-agent-a08f1242e9f2bdb7c|変更0|未追跡0|local-only|24日| 71M
- agent-a15284c63646b2b06|claude/q94-compat-rift|変更0|未追跡0|merged|20日|291M
- agent-a153dbc9f2506d678|claude/the-hana-candidate|変更0|未追跡0|pushed|14日|639M
- agent-a1b4d54b7818222b9|claude/meta-wire-1107|変更0|未追跡0|merged|0日| 89M
- agent-a229095a8064ebcbd|claude/q93-exp-rebalance|変更0|未追跡0|pushed|20日|291M
- agent-a253875639283aef8|claude/fun-1019-proto2|変更0|未追跡0|pushed|20日| 82M
- agent-a26014a73609d0ae4|worktree-agent-a26014a73609d0ae4|変更0|未追跡0|local-only|24日|254M
- agent-a392962c4bb246a0d|claude/q97-injury|変更0|未追跡0|merged|20日|291M
- agent-a3a18bb1f138d327b|claude/fun-1019-proto|変更0|未追跡0|pushed|20日| 82M
- agent-a4087749c33a8fdd6|claude/q93-r2m|変更0|未追跡0|pushed|20日|301M
- agent-a55c171d99ac73150|worktree-agent-a55c171d99ac73150|変更0|未追跡0|local-only|24日|254M
- agent-a5618c7c86001d2b1|claude/speed-share-1107|変更0|未追跡0|merged|0日| 89M
- agent-a5b7754a8f9a5f6d9|claude/ui-1102|変更0|未追跡0|merged|5日|312M
- agent-a5fb534eee47c75eb|claude/kiritsu-a-1102|変更0|未追跡0|merged|5日|645M
- agent-a625a0621dab7940c|worktree-agent-a625a0621dab7940c|変更0|未追跡0|local-only|24日| 74M
- agent-a648f7720b0bb98d4|claude/button-press-se-cand|変更0|未追跡0|pushed|7日| 89M
- agent-a66f183f1dfa977d5|claude/q106-skills|変更0|未追跡0|merged|20日|292M
- agent-a6d57486fbbebfb47|claude/judge-display-1107|変更0|未追跡0|merged|0日| 89M
- agent-a705f4eca83945124|claude/q-combined7|変更0|未追跡0|merged|20日|293M
- agent-a729a2e937d8a9625|cand96b|変更0|未追跡0|merged|20日|293M
- agent-a7388fd0c85b0d3ef|claude/q102-invites|変更0|未追跡0|merged|20日|292M
- agent-a76258d88ad1790d0|claude/q-combined|変更0|未追跡0|pushed|20日|293M
- agent-a77086bda5aa37589|playtest-v9|変更0|未追跡1|merged|20日| 87M
- agent-a7755db8e0c05fdf9|claude/q-candidate|変更0|未追跡0|merged|20日|292M
- agent-a78d3a79f05bb64ff|worktree-agent-a78d3a79f05bb64ff|変更0|未追跡0|local-only|24日|282M
- agent-a83ac1212c51f3b67|claude/feel-1102|変更0|未追跡0|merged|5日| 89M
- agent-a8a528a4d9fbe53db|worktree-agent-a8a528a4d9fbe53db|変更0|未追跡1|local-only|24日| 72M
- agent-a8e9338d437c060a9|worktree-agent-a8e9338d437c060a9|変更0|未追跡0|pushed|24日| 71M
- agent-a92f63d767a29d393|claude/fifteen-ui-1107|変更0|未追跡0|merged|0日| 89M
- agent-a9c73aa5de8cd95d4|claude/q96-offers|変更0|未追跡0|merged|20日|292M
- agent-aa63b05f7908d6490|worktree-agent-aa63b05f7908d6490|変更0|未追跡2|pushed|118日|444M
- agent-aa78456a4a6096108|claude/q-combined8s|変更0|未追跡1|merged|20日|294M
- agent-aae79a4d76506a76c|worktree-agent-aae79a4d76506a76c|変更0|未追跡0|local-only|24日|285M
- agent-ab085283aad034aff|worktree-agent-ab085283aad034aff|変更0|未追跡0|local-only|24日| 75M
- agent-ab1b38c7cc695bb68|claude/firststage-1107|変更0|未追跡0|merged|0日| 89M
- agent-ab475be602b9eaeb2|claude/q103-items|変更0|未追跡0|merged|20日|291M
- agent-abdf2f28583b65dba|worktree-agent-abdf2f28583b65dba|変更0|未追跡0|local-only|24日| 74M
- agent-ac29ee7140453988b|worktree-agent-ac29ee7140453988b|変更0|未追跡0|local-only|24日| 75M
- agent-ac5a167e400fbb762|claude/gacha-1107|変更0|未追跡0|merged|0日| 89M
- agent-ac669d6230abd00cc|claude/q98-wintercup|変更0|未追跡0|merged|20日|291M
- agent-acc06169b5c7b43db|claude/fix-v11-1107|変更0|未追跡0|merged|0日|314M
- agent-acc849e472ff370ef|claude/gacha-entry-cand|変更0|未追跡0|pushed|0日|314M
- agent-ad0c0cca576ac2a99|worktree-agent-ad0c0cca576ac2a99|変更0|未追跡0|local-only|24日| 72M
- agent-ad1373c3ef0d272e4|worktree-agent-ad1373c3ef0d272e4|変更0|未追跡0|local-only|24日|284M
- agent-ad908e3cb6056e536|claude/q90-rooms|変更0|未追跡0|merged|20日|622M
- agent-ae2ad689bfedc6be0|claude/rift-trophy-cand|変更0|未追跡0|local-only|0日| 90M
- agent-ae3e1c7e9d0980d2a|worktree-agent-ae3e1c7e9d0980d2a|変更0|未追跡0|local-only|24日|279M
- agent-af1575953abc2f4a7|worktree-agent-af1575953abc2f4a7|変更0|未追跡0|local-only|24日|286M
- agent-af2352698c3ad0fa2|worktree-agent-af2352698c3ad0fa2|変更0|未追跡1|merged|24日|285M
- agent-afa362d58fc5f1572|worktree-agent-afa362d58fc5f1572|変更0|未追跡0|local-only|24日| 72M
- mz-ability-exchange|ability-exchange-proposal|変更0|未追跡0|pushed|22日|290M
- mz-compare-exchange|preview-all-with-exchange|変更0|未追跡0|pushed|22日|291M
- mz-preview-all|preview-all|変更0|未追跡0|merged|23日|1.2G
- mz-q6062|q60-62-impl|変更0|未追跡0|merged|24日|284M
- mz-ui-all|ui-overhaul-preview|変更0|未追跡0|merged|24日|283M
