# コンビ名を置き換えなしで表示（C-19 候補・combi_name_verbatim_1108_v0）

候補ブランチ：claude/combi-name-verbatim-cand（コミット 368f8c8e・14b6d14f）。本体には入れていない（決めるのはオーナー）。

## 要点
- 事実：コンビ名の表示は19ファイル・約50箇所すべてが `Text(String)` 経由で `Names.show` を通っていた（単独表示も「{名}　最後の舞台」のような埋め込みも）。
- 直し：表示箇所を1つずつ直さず、`Names.show` の中で「コンビ名と一致する部分」を飛ばして谷口・{me} を差し替える形にした（Names.swift +16行、コンビ名の登録3行）。画面と共有カードは同じ道を通るので、ずれない。
- 残り：コンビ名がちょうど「谷口」「俺」の時だけは台詞と区別できないので従来どおり置き換わる。

## 表示箇所の一覧（すべて Names.show 経由だった）
| 種別 | 箇所 | 直し後 |
|---|---|---|
| 単独表示 | ShareCard、S6bView 3、FinalsPresentationView 約10、TournamentResultView、YoseYearTurnCurtain、CalendarView、NotebookView、YearResultView、FirstStageView(StageSign)、FinalistAnnounceView、QualifierNoticeView | 置き換えなし |
| 文に埋め込み | 「{名}　最後の舞台」「—— {名} ——」「結成N年目 —— {名}」、MC の呼び出し文（FinalsMC）、ファンの声（FanReportData）、通過者の読み上げ | コンビ名の部分だけ保護・前後の谷口、{me} は従来どおり差し替え |
| 対象外（もともと別） | SharePreview の文字列（LocalizedStringKey で置き換わらない） | 変更なし |

## 直した所
- Names.swift：`Names.combi`（入力どおりのコンビ名）を追加。`show` が `combi` を含む文字列を combi で分割し、各断片だけ差し替えて元の名前でつなぎ直す。保護するのは名前に「谷口」か「{」を含み、ちょうど「谷口」「俺」でない時だけ（それ以外は差し替えが起きないので動作が変わらない）。
- 登録：GameSession の新規作成とセーブ復元、IntroFlow の名前入力直後（回想で使う）。
- 式・乱数・GameConfig・golden・保存形式には触っていない。

## 残り
- コンビ名がちょうど「谷口」または「俺」の場合は従来どおり（台詞の谷口・俺札と区別がつかない）。結成届で弾く／警告する案はオーナー判断。

## テスト
- ManzaiGame/Tests/ComboNameVerbatim1108Tests.swift 6件（谷口一座・{me}ズが入力どおり／台詞の谷口は差し替わる／普通のコンビ名と既定の相方名で表示が変わらない／ちょうど「谷口」は従来どおり）。
- GameCore swift test：448 tests, 0 failures。
- アプリ（iPhone 17 シミュレータ）：360 tests, 0 failures、TEST SUCCEEDED。
