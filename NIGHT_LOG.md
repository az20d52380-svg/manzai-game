# NIGHT_LOG — 夜間リサーチ・提案セッション（2026-07-06 未明〜）

オーナー就寝中の自律セッション。**コード改変なし**。成果物は `proposals/` 以下と本ログのみ。

## ルール確認（着手前の自己復唱）
1. **既存コードは書き換えない**：新規作成は `proposals/` 以下と本 `NIGHT_LOG.md` だけ。既存ファイルは読むのみ。サブエージェントも読み取り＋Web検索のみ（ファイルは書かせず、内容はテキストで受け取り、こちらが proposals/ にだけ書く）。`git add` は対象限定（`-A`/`.` 不使用）。
2. **成果物は proposals/ 以下だけ**：1提案＝1ファイル（狙い/対象箇所/学んだ元URL/貼れるスニペット/リスク/レッドチーム）。
3. **CLIに影響を与えない**：当方はクラウド（別マシン・別チェックアウト）。共有は git リモートのみ。push は新規の proposals/・NIGHT_LOG.md だけ＝本体コードとファイル非衝突。push 前に必ず `git pull --rebase` で同期。プロセス/ポート/ビルド/依存/ロック/DB は触らない。迷ったら「やらない」→本ログに「要相談」。

## 前提（誤認防止）
- MVPは実装途中。**未実装なだけの箇所を"欠陥"と誤認しない**。判断がつかないものは「提案」として書く（直す前提にしない）。
- 会話・イベントの土台は既に docs に多数あり（dialogue_design_v0 / dialogue_batch2-4 / event_design_v0・v1_batch2 / rival_scripts_v0 / guest_appearance_design_v0 / relationship_* / character_archetypes_v0 / partner_characters_v0 / rival_design_v0 / judge_comments_v1 / neta_catalog_v0 等）。**重複でなく"弱い/薄い/伸ばせる"箇所の改善・拡張**を狙う。
- 絶対の一線：ボケ(オチ/ネタ本文)は書かない・筆致にウィット・固有名架空・数値【仮】・既存作品のセリフのコピペ禁止。

---

## サイクル記録
（以下、各サイクルで追記）
