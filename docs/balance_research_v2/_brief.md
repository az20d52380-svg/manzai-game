# サブエージェント共通ブリーフ（ゲームバランス調査 v2・2026-10-10）

## オーナー判断（2026-10-10・これが前提）
- 本作の根幹＝**何年もかけて成長させて優勝する**（4月デビュー・1年目優勝はほぼ無い・本編は結成10年で完結）。
- **評価が「審査員の好み」「ネタの型」「大会の形式」で変わる**ようにする（2026-07-04 の「審査員の違いは表示のみ・合否非干渉」を覆す）。
- **能力アップはパワプロのサクセス式＝経験点を貯めて自分で割り振る**を戻す（10/07 に自動注ぎにしていた）。
- **周回**：トロフィーやガチャ（相方名鑑）を集めると初期経験値が上がる。**1年目から優勝も「あり」。ただし確率が高くなるのは、初期経験値がめちゃくちゃ上がってから**。
- ％（通過見込み）は画面に出さない。

## プロジェクト
- iOS/SwiftUI の漫才コンビ育成SLG（48週×最大10年）。本体 `~/manzai-game`。運用は `CLAUDE.md`、索引 `docs/START_HERE.md`。
- いまの評価式：`GameCore/Sources/GameCore/GameEngine.swift` の `perform`＝実力値（センス0.30・発想0.30・表現0.25・華0.15 の固定重み）＋相性＋ブレ（メンタルで幅が決まる）＋ハマった夜＋体力ペナルティ＋ネタの完成度補正（±5）。ラインを越えたら通過。大会表は `Calendar.swift`、数値は `GameConfig.swift`、正典は `docs/canonical_v2_spec.md`・`docs/master_spec_v2.md`。
- 既存の調査（重複しない・先に読む）：`docs/judge_preference_research_v0.md`・`docs/multiyear_and_judge_preference_integration_v0.md`（7審査員の固定嗜好とネタの型×好みの表）・`docs/pawapuro_core_research_v0.md`・`docs/replayability_research_v0.md`・`docs/meta_report_v0.md`・`docs/trophy_design_v1.md`・`docs/partner_gacha_design_v0.md`・`docs/neta_system_redesign_v2.md`・`docs/comedy_research_v2/r1_m1_grandprix.md`・`r2_contests_and_industry.md`。

## 絶対制約
- **コード・git・simulator を触らない**。書いてよいのは指定の出力ファイルだけ。
- ゲーム内の固有名は架空（実在の作品・大会・人名は調査文書の中だけで使ってよい）。漫才のネタ本文は書かない。
- 事実には出典URL。確かめられないことは「未確認」。数値の提案は【仮】。
- 日本語・言い切り。

## 書き方（中断に強くする・必須）
- 最初の数手で、出力ファイルを節見出しだけの骨組みで作る。以後は節を1つ書くごとに追記する。
- 最後の節は「このゲームへの提案（数式の形・係数の幅【仮】・検証のしかた）」。

## 返し方
- 最後の返答は「保存先パス＋要点3行」だけ。
