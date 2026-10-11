# 引き継ぎ：作り直し v2（2026-10-11）

## 状況（3行）
1. ①複数年キャリア（b15ae02）と、決勝の M-1 化（65468c2・c53ca9a・7078cdf：内部結果どおりの順位／出順どおりの進行と暫定席／司会「鳴海ジョー」と講評／全員一致は圧倒時のみ）は push 済み。
2. 次は **②手動の能力アップ復活＋評価が「審査員の好み・ネタの型・大会の形式」で変わる式（規律A）**。オーナー承認済み（`core_loop_reconsideration_v0.md` §7）。
3. 材料：`docs/balance_research_v2/`（b1 評価軸とビルド／b2 周回とガチャ／b3 賞レースの審査傾向。サブエージェントが続きを執筆中＝未完なら §2 以降を確認）、`comedy_research_v2/`（r1〜r5）。

## 次の手順（②）
1. b1〜b3 の §5/§6（提案）だけ読み、式の案を1枚に（`docs/eval_axes_design_v0.md`）：重み表（大会形式×審査員類型×ネタの型）・係数の幅【仮】・合格線（初回優勝 2〜4%・決勝到達 2〜4割を維持、ビルドで勝ち筋が変わること）。オーナーに1論点ずつ確認。
2. 規律A：`tools/sim_career.py`→`GameCore`→`gen_golden.py`→`swift test` を1コミットで。
3. 手動割り振り：`GameSession.swift:112/131` の `autoPourAllocation=true` を false、のばす入口（`AllocationView`）を戻す。
4. その後 ③周回（初期経験値は大きく上がって初めて1年目優勝が現実に）、見せ方（会話の作り直し＝キャラ会話はボケない・ユーモアは審査員と司会だけ／イベント／第2便 D1〜P3）、Phase 7 試遊。

## 注意
- sim は iPhone 17（E5D11233-…）だけ。ビルド・撮影手順は `docs/visual_overhaul/handoff_v1.md` §2。DEBUG：`MZ_YEARS=n`・`MZ_ALLOWSAVE=1`・`MZ_FMARGIN=点差`・`MZ_FIN=pre/open/comments/board/duel/win`。
- 決勝の残り：最終決戦前の2本目のネタ場面、地の文の締め（「——開票、出揃った。」等）を司会/事実テロップへ。
- 年をまたぐとイベントが枯れる（キャリア通算の一発化と上限15）＝r4 のイベント再設計で直す。
