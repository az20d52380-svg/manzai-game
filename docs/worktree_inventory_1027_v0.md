# 作業場所（git worktree）の棚卸し（2026-10-27 深夜の定期）

本体以外に作業場所が43個ある。`.claude/worktrees/` だけで約8.7GB（多くは古いサブエージェントの跡）。**何も消していない**（消すかはオーナー判断）。

## 要点
- 本体にもう入っている（merged）・変更なし：17個（約5.6GB・うち preview-all 1.2GB）＝消しても失うものは無い。
- 本体に入っていない・変更なし：25個（約5.4GB）。中身は古い試作・却下/保留の案・候補（the-hana-candidate は手元だけ＝ただし本体に合わせた版を claude/the-hana-candidate-r1027 で push 済み）。ブランチは残るので、作業場所だけ外してもコミットは消えない。
- 変更あり：1個（claude/q6-save-until-ending・別セッションの scratchpad・2日前）＝触らない。

## 選択肢
1. merged の17個だけ外す（`git worktree remove`・ブランチは残す）【推奨＝失うもの0・容量の半分以上が戻る】
2. 1＋未 merge の25個も作業場所だけ外す（ブランチは残る＝後から取り出せる）
3. 今のまま

## 一覧（本体に入っているか｜変更｜最後のコミット｜大きさ｜ブランチ）
- merged|dirty0|12 days ago|283M|ui-overhaul-preview
- merged|dirty0|12 days ago|284M|q60-62-impl
- merged|dirty0|12 days ago|285M|worktree-agent-af2352698c3ad0fa2
- merged|dirty0|8 days ago|292M|claude/q-candidate
- merged|dirty0|8 days ago|293M|cand96b
- merged|dirty0|9 days ago| 87M|playtest-v9
- merged|dirty0|9 days ago|1.2G|preview-all
- merged|dirty0|9 days ago|291M|claude/q103-items
- merged|dirty0|9 days ago|291M|claude/q94-compat-rift
- merged|dirty0|9 days ago|291M|claude/q97-injury
- merged|dirty0|9 days ago|291M|claude/q98-wintercup
- merged|dirty0|9 days ago|292M|claude/q102-invites
- merged|dirty0|9 days ago|292M|claude/q106-skills
- merged|dirty0|9 days ago|292M|claude/q96-offers
- merged|dirty0|9 days ago|293M|claude/q-combined7
- merged|dirty0|9 days ago|294M|claude/q-combined8s
- merged|dirty0|9 days ago|622M|claude/q90-rooms
- merged|dirty5|2 days ago| 87M|claude/q6-save-until-ending
- notmerged|dirty0|11 days ago|290M|ability-exchange-proposal
- notmerged|dirty0|11 days ago|291M|preview-all-with-exchange
- notmerged|dirty0|12 days ago| 71M|worktree-agent-a08f1242e9f2bdb7c
- notmerged|dirty0|12 days ago| 71M|worktree-agent-a8e9338d437c060a9
- notmerged|dirty0|12 days ago| 72M|worktree-agent-a8a528a4d9fbe53db
- notmerged|dirty0|12 days ago| 72M|worktree-agent-ad0c0cca576ac2a99
- notmerged|dirty0|12 days ago| 72M|worktree-agent-afa362d58fc5f1572
- notmerged|dirty0|12 days ago| 74M|worktree-agent-a625a0621dab7940c
- notmerged|dirty0|12 days ago| 74M|worktree-agent-abdf2f28583b65dba
- notmerged|dirty0|12 days ago| 75M|worktree-agent-ab085283aad034aff
- notmerged|dirty0|12 days ago| 75M|worktree-agent-ac29ee7140453988b
- notmerged|dirty0|12 days ago|254M|worktree-agent-a26014a73609d0ae4
- notmerged|dirty0|12 days ago|254M|worktree-agent-a55c171d99ac73150
- notmerged|dirty0|12 days ago|279M|worktree-agent-ae3e1c7e9d0980d2a
- notmerged|dirty0|12 days ago|282M|worktree-agent-a78d3a79f05bb64ff
- notmerged|dirty0|12 days ago|284M|worktree-agent-ad1373c3ef0d272e4
- notmerged|dirty0|12 days ago|285M|worktree-agent-aae79a4d76506a76c
- notmerged|dirty0|12 days ago|286M|worktree-agent-af1575953abc2f4a7
- notmerged|dirty0|19 hours ago|639M|claude/the-hana-candidate
- notmerged|dirty0|4 months ago|444M|worktree-agent-aa63b05f7908d6490
- notmerged|dirty0|8 days ago| 82M|claude/fun-1019-proto2
- notmerged|dirty0|8 days ago| 82M|claude/fun-1019-proto
- notmerged|dirty0|8 days ago|301M|claude/q93-r2m
- notmerged|dirty0|9 days ago|291M|claude/q93-exp-rebalance
- notmerged|dirty0|9 days ago|293M|claude/q-combined
