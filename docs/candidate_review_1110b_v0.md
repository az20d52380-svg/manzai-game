# 候補ブランチ3本の点検（1110b・正しさのバグ観点）

対象：本体 claude/manzai-slg-foundation-wprqlu との差分。コード変更・コミットなし。ビルド・テストは未実行（読んだだけ）。

## 1. meta-lenient-load-cand（図鑑・CareerRecords の寛容な読み込み）
結論：マージして問題なし（低の指摘のみ）。
- 低｜Endings.swift:183-187 / :204-207｜1件の中で1項目だけ壊れた（例：lastPartnerName が欠けた）場合も、その1件を丸ごと捨てる。count や初回日付も消える。1項目ずつの既定値補完ではなく「1件ずつ」の粒度。壊れた件だけが失われ他の件は残るので、今回の目的（全消し防止）は満たす。
- 低｜Endings.swift:207｜未知の EndingID（新しい版で足した鍵）は読み込みで捨てられ、次の record() で保存データから消える。旧版に戻したときの前方互換は無いが、これは変更前からの挙動。
- 問題なし｜Meta.swift:87-97｜拡張内の init(from:) は合成 Decodable を置き換える。メモリワイズ init は残る。encode は合成のまま。fastestWinYear と hanaWins の欠け・型違いは nil、bestStreak と totalWins は 0 に落ちる。欠けた鍵の既定値は旧データ互換（hanaWins＝nil）と一致。トップレベルが辞書でない場合は throw し、loadRecords 側で CareerRecords() になる（従来どおり）。
- 問題なし｜テスト｜EndingID の rawValue（breakup/gaveUp/keptGoing/championPair）は実在。壊れた2件＝count 型違い・count 欠け、正しい1件が残ること、次の record() で消えないこと、鍵欠け・型違い・未知鍵・全部そろった往復を固定している。MZ_BOOKSEEN / MZ_RECORDS 設定時は skip する（DEBUG 環境変数との衝突を避けている）。

## 2. first-week-two-terms-cand（初回「はじめに」を2語に）
結論：マージして問題なし（低の指摘のみ）。
- 低｜WeekMainView.swift:1472-1478 / :1496｜短い版の note に「まずはネタを書こう」と固定で入る。初週にすでにネタがある状態（開始時にネタを持つ設定やデバッグ起動）なら不自然。通常の新規開始ではネタ0なので実害は小さい。
- 低｜WeekMainView.swift:1496｜自動表示が短い版に変わった結果、実力・相性・経験点は初週に自動では説明されない。経験点は能力アップ画面の初回説明（key "abilityUp"）で補われるが、実力・相性は左上の「？」を押した人だけ。意図どおり（コメントに明記）。
- 問題なし｜既読フラグ｜短い版は full.key（"firstWeek"）を引き継ぐ。閉じると markDone("firstWeek") が同じ鍵に付く。すでに5語版を見た既存ユーザーは再表示されない。「？」は firstWeekHint（5語）のまま。
- 問題なし｜絞り込み｜rows.filter で term が "体力"・"知名度" の行だけ。文面は5語版と同一。
- 弱い点｜テスト｜短い版の構造（2語・同じ鍵・5語のまま・行が部分集合）は固定しているが、自動表示の経路（maybeShowFirstHints が短い版を使うこと）はテストしていない（private 関数）。差し替えが外れても落ちない。

## 3. stamina-dedup-cand（一言行が低体力を出す週は独白の低体力を譲る）
結論：マージして問題なし（低の指摘のみ）。
- 低｜WeekHint.swift:57-60｜isStaminaLine は文面の接頭辞・接尾辞の一致で判定する。WeekHint.line の体力2文（:49-50）の文言を直すと、判定が静かに外れて二重表示が戻る。テストは2文を固定しているので、文言変更時は落ちる（検知はできる）。
- 低｜DialogueData.swift:47｜独白の低体力は stamina<25、一言行は体力 30 以下で出る。独白が出る領域（<25）はつねに一言行が体力の文を出す領域に含まれるが、所持金マイナス・撮影週・生活費不足・ネタ0の週は一言行が別の文になる。その週は stamina<25 でも独白の低体力が出る（過剰な抑制は起きない。条件の取り違えなし）。
- 問題なし｜呼び出し｜weekHintLine は body 直下で常時表示（WeekMainView.swift:156）。独白と一言行が同じ画面に並ぶので、「一言行が言っているのに独白が黙る」ことで体力の注意が完全に消える経路は無い。innerVoice の呼び出し元は monoBox だけ、新引数の既定値は false で他に影響なし。療養中の分岐は譲る処理より先で不変。
- 問題なし｜テスト｜picker の scene 名で分岐を直接確認（譲る→別の話、お金0なら lowMoney へ落ちる）。isStaminaLine の肯定・否定・nil も確認。
