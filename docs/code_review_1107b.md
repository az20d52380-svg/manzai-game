# コード点検 11/07 その2（6a92f9c~1..HEAD：ガチャ台帳・MZSpeed・共有ボタン・経験点の合計）

範囲：`git diff 6a92f9c~1..HEAD -- ManzaiGame/Sources`。読むだけ（ソース無変更）。code_review_1107.md の指摘は除く。
観点③④：共有画像の文面に実在の大会・事務所名は無い（「漫才王になろう」「優勝/決勝進出/エンディング名」「結成N年目」「No.N 種別」＋コンビ名）。％表示も差分内に無い。
MZSpeed の係数は 1.0 / 0.5 のみ＝待ちが0になって順序が崩れる所は無い。

| # | 場所 | 何が起きる（具体的な手順） | 重さ |
|---|---|---|---|
| 1 | Design/YoseChampionCelebrationView.swift 791・997（ChampionStageBackdropCanvas / GoldenHalo / CannonAndConfetti の .task）、FinalsPresentationView.swift RaysView(6.6秒)・ConfettiView(16.6秒) | 設定を「はやい」にして優勝演出へ。描画の時刻 t は実時間（Date().timeIntervalSince(startTime)）で進むのに、停止までの待ち（rest）だけ0.5倍になる。そのため `frozen = true`（TimelineView を paused）が本来より早く掛かり、後光・紙吹雪・キャノンのテープが途中の位置で固まったまま画面に残る（紙吹雪は 16.6秒→8.3秒で空中停止）。「ふつう」では起きない。待ちの短縮は表示の待ちだけに限り、描画の停止時刻には掛けない方が安全 | 中 |
| 2 | Store/GachaState.swift merged(with:) の `paidOpened = max(...)` | 2台が iCloud で合流。端末Aは購入X（1回）を開封（opened=1）、端末Bは別の購入Y（1回）を開封（opened=1）。合流後は 台帳 X+Y=2、開封 max=1 → 未開封が1回残る（本当は0）。購入分の回数が1回ぶん無料で復活する（二重付与の向き。消失はしない）。開封を取引ID別に持たないと防げない | 中 |
| 3 | GachaState.swift init(from:) 旧形式→台帳 "legacy" | 旧版が未開封3回を持つ端末と、新版へ上げて1回開封済み（legacy=3→ opened=2、または旧版が先に3→1へ減らした値で legacy=1）の端末が合流。legacy は max で合流するので、旧版側が古い値（3）のままだと開封済みの2回が戻る。更新の順序が混ざる移行期の1回限り。両端末が新版になれば起きない（未確認：実機の旧→新の混在は未再現） | 低 |
| 4 | GachaState.swift encode(to:)（paidPending・creditedTx を書かない） | 新版で保存したデータを旧版（paidPending が必須キー）が読むと keyNotFound → `decode` は GachaState() を返し、`persist` で旧版が空の状態を iCloud に上書きする恐れ。ダウングレード（TestFlight で古いビルドを入れ直す等）の時だけ。旧版→新版の向きは decodeIfPresent と migrate で読める | 低 |
| 5 | WeekMainView.swift の toast（.task(id: toast)：長文 4.5秒→2.25秒、21〜30字 2.6秒→1.3秒、短文 1.4秒→0.7秒）ほか通知系 | 「はやい」で、谷口の長めの一言のトースト（30字超）が約2.3秒で消える。読み終える前に消えて、読み返す手段がない（ログ等が無い画面）。設定の説明に「台詞送りが速くなる」とあるが、台詞送り本体（ChoiceEventOverlay / StageFrame 等）の sleep は未変換のまま＝説明と実際が合わない（未確認：台詞の自動送りが別実装なら説明の言い過ぎだけ） | 中 |
| 6 | WeekMainView.swift 306 付近 `MZSpeed.sleep(250ms)`（退場を見せ切ってから cover 解禁） | 「はやい」だと待ちが125ms。チップの退場アニメ（withAnimation の長さは未変換）が終わる前に presentRent が cover を出す。コメントは「見せ切ってから解禁（defer）」＝SwiftUI が dismiss 中の present を落とす対策だった。支払い画面が出ない週がある可能性（未確認：実機で再現していない） | 中 |
| 7 | WeekMainView.swift tapOrQueue（n<60 × 50ms＝3秒の上限が1.5秒に） | 獲得チップの表示中、月末の支払い画面（presentRent：rent が閉じられるまで burstHold が続く）が出ている間に行動ボタンを押すと、「はやい」では1.5秒で待ちを打ち切り、`if !burstHold { run() }` が偽のまま押下が黙って捨てられる。「ふつう」でも3秒で同じ事が起きるが、半分になる分だけ起きやすい | 低 |
| 8 | FinalsPresentationView.swift 360〜374（7人目前 0.6秒→0.3秒、決定票前 0.35/0.9秒→0.18/0.45秒） | 「はやい」で、全SEを断つ無音の間が短くなり、`Sound.duck(0.25, over: 0.2)` の絞り（0.2秒）とほぼ同じ長さになる。finals_direction の「伝説の間」が聞こえない。勝ち負けは不変。設計意図を変えて良いかはオーナー判断 | 低 |
| 9 | FinalsPresentationView.swift 402〜412 の `Task { … while revealVotes < 7 … }`（既存の作り・今回は待ちだけ変更） | 決着後の残り札を開く最中に画面を閉じる（観客版の終了等）と、この Task は取り消されず、閉じた後も Sound.play(.don)・Haptics が最大4回鳴る。「はやい」では一斉に近い速さで鳴る。今回の差分で生じた物ではないが演出の速さ導入で目立つ | 低 |
| 10 | ShareCard.swift ShareCardButton の `.task { … }`（id なし） | 画像は画面が出た時の1回だけ作る。YearResultView が年をまたいで同じ位置の View として使い回されると、前の年の「結成N年目」「優勝/決勝進出」の画像が残る可能性がある（未確認：RootView 387 の YearResultView が年ごとに作り直されるかは確かめていない）。`.task(id: "\(combiName)\(headline)\(detail ?? "")")` にすれば確実 | 低 |
| 11 | ShareCard.swift の ImageRenderer 呼び出し | `.task` の中で ImageRenderer（MainActor 専用）を使う。この SDK/設定で .task のクロージャが MainActor を引き継ぐかは未確認（引き継がなければ Swift 6 モードで警告/エラー、実行時は main 外で呼ばれて uiImage が nil → 「共有」ボタンが出ない）。画像は 720×720pt×2＝1440px で巨大にはならない。uiImage が nil の時は何も出さない作りなので空の画像は共有されない | 低 |
| 12 | YearResultView.swift ShareCardButton の detail「結成\(session.year)年目」 | `session.year` が「いま何年目か」か「終えた年」かで、画像の年数が1ずれる可能性（未確認：year の進め方を確かめていない）。表示している結果の年（YearOutcome の年）を使う方が確実 | 低 |

## 確認して問題なしだった点
- MZSpeed：factor は 0.5 / 1.0 のみ。waitOrSkip・pause・fan の for 文は回数固定で時間だけ縮む＝0待ちや無限ループは無い。`try?` で取り消しを飲む形は従来と同じ。
- ガチャ台帳：credit は txID が既にあれば false（二重付与なし）。旧 creditedTx は 0 回の行で移すので、旧版で付与済みの取引の再配信も弾かれる。合流は台帳を max の和集合にするので別端末の購入は消えない。購入→回す（GachaView 153〜155）は credit 後に availableTickets を見て回すため、Transaction.updates との競合でも二重付与しない。paidPending の setter（"_set" 行）はテスト以外から使われていない。
- 共有画像：コンビ名は利用者入力のみ、実在の大会・事務所名・％・個人情報なし。ending.title が長くても minimumScaleFactor(0.4) で1行に収まる。
- 経験点の合計：ExpDisplay.total を使う2か所（WeekMainView の週トースト・TournamentResultView の大会結果）と札の数字（value の足し算）が一致。他に旧式の合計は見当たらない。

## 対応（11/07 定期の回・親）
- 直した：#1（固まる所の待ちを実時間に）／#5（トーストは読む時間なので縮めない・設定の説明から「台詞送り」を外す）／#6（250ms は実時間に）／#7（上限は実時間に）／#10（画像は内容が変わると作り直す）。
- 問題なし：#11（ビルドが通り、View の .task はメインで動く）／#12（年末の画面の見出し「N年目 年末総決算」と同じ session.year で揃っている）。
- 未対応：#2 #3 #4（ガチャの保存形式の話＝低頻度・課金まわりなので形式を変えるならオーナー確認の後）／#8（決勝の無音の間を「はやい」でも縮めるか＝オーナー判断）／#9（既存の作り・低）。

