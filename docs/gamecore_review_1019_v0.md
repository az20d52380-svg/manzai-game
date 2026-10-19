# GameCore 読み取り点検（2026-10-19・v0）

**件数：全15件（確度「高」9件・「中」6件）。実害が中以上なのは F2 の1件、小さいものが残り。golden に効くもの：0件。**
コードは一切変えていない（規律A：式・乱数の消費順は Python 正典と golden で固定）。「直すなら」は規律Aの手順（tools/*.py → GameCore → `gen_golden.py` 再生成 → `swift test` を1コミット）が要るかどうかも添えた。

## 節構成
- §0 点検の範囲と結論
- §1 確度 高・実害あり／情報（F1〜F4）
- §2 確度 中・実害は条件つき（F5〜F7）
- §3 実害が小さい物（F8〜F15・確度は各項に記載）
- §4 突き合わせて一致していた所（調べたが問題なし）
- §5 check_golden_sync / golden が守っていない範囲

## §0 範囲と結論
- 読んだ：GameCore の 14 ファイル全部（JudgeTalk は構造と境界だけ）と、対応する Python（tools/sim_career.py・balance_sim.py・gen_golden.py・gen_golden_features.py）。
- 今日時点で `check_golden_sync.py` は OK（50行＋12週一致）。`gen_golden_features.py` を別の場所で再生成して `golden_features.json` と比べたが差は無し。
- 式・定数（GameConfig ⇔ balance_sim / sim_career）は全部一致。ずれていたのは「golden に載らない分岐」と「イベント・療養・runCareer」だけ。
- 一番大きい1件は **F2（選択肢イベントの効果を、アプリは素の加減算・sim は逓減/予算/知名度鈍化を通して測っている）**。sim の「イベント込み」の数字は、アプリより効果が小さく出ている。

## §1 確度 高・実害あり／情報（F1〜F4）

### F1　runCareer が「途中解散」で止まらない
- Swift：`Career.swift:114-119`（`champion` と `bankrupt` だけ見て `dissolved` を見ない）　Python：`sim_career.py:1046`（`_bankrupt or _dissolved` で break）
- 何が起きる：解散した後も次の年を回す。次年の1週目の週末で必ず再び解散判定になるので結果（優勝年 nil）は変わらないが、余分な年を回し乱数を消費する。`runCareer` を使うテスト・Swift 側の自動プレイで年数・乱数位置が Python とずれる。アプリは `GameSession.swift:977` で正しく止めている。
- 直すなら：`if outcome.dissolved { return nil }` を1行足す。
- 確度：高　実害：小　golden：効かない（golden は解散しないシードで assert 済み。`RunCareerTests` は夜逃げだけ検査）　規律A：Swift だけの修正（Python は既に止まる）＝golden 再生成は不要だが「Python 同期」の点で規律A対象

### F2　選択肢イベントの効果が、アプリ（素の加減算）と sim（add 経由）で別物
- Swift：`ChoiceEventEffect.swift:27-58`（`bumpAbility` は 0〜上限にクランプするだけ。逓減・成長予算・知名度の鈍化・愛され芸人を通さない。コメントに「別枠の付与」と明記）
  Python：`sim_career.py:195-243`（`_others_apply`）・`310-355`（`_app_apply`）・`398-406`（`_apply_event`）は全部 `B.add(...)` ＝ 逓減 ×(1−現在値/120)・年予算・`FAME_OTHER_MULT 0.6 × (1−知名度/80)²` を通す。
- 何が起きる：同じ「発想+2」でも、能力60なら sim は +1.0、アプリは +2。知名度 +3 は、知名度10で sim ≈ +1.4、アプリは +3。能力が上がるほど差が開く。`EVENTS_APP=True` の実測（docs/events_app_parity_v0.md の「parity」）は、アプリより弱いイベントを測っている＝優勝率・決勝到達率が低めに出ている。
- 直すなら：Swift の「別枠」が意図どおりなら Python 側の `_others_apply`/`_app_apply`/`_apply_event` を「素の加減算＋クランプ」の関数（`B.add` でない）に置き換える。Swift を `add` 経由に変えるなら逆で、アプリの体感が変わる（オーナー判断）。
- 確度：高（コードを読んだだけで食い違いが確定）　実害：中（バランス判断の根拠になる sim 数値）　golden：効かない（`EVENTS_APP` 既定 OFF・gen_golden はイベントを走らせない）　規律A：Python だけを直す案なら golden 再生成は不要。ただし直すと `EVENTS_APP` 系の過去実測は取り直し。

### F3　療養週に銭湯の回数券を使うかが Swift と Python で逆
- Swift：`WeekRunner.swift:375`（`applyRest(.完全休養, ..., useTicket: false)`＝選んでいない療養週は回数券を使わない）　Python：`sim_career.py:911-913` → `balance_sim.py:498 do_rest`（引数が無く、常に回数券を1枚使い +10 回復する）
- 何が起きる：回数券を持つ状態で体調ダウン→療養すると、Swift は温存・Python は消費。sim に回数券を買わせる実験をすると、アプリより回数券が早く減り、体力回復が +10 多く出る。
- 直すなら：Python の `do_rest` に `use_ticket=True` 引数を足し、`sim_career.py:913` の療養週だけ `False` で呼ぶ。
- 確度：高　実害：小（既定のボット・golden は回数券を買わない）　golden：効かない（`sento_tickets` が常に None）　規律A：Python 側だけの変更で golden 再生成は不要。ただし `gen_golden_features.py` に療養＋回数券の台本を足すと守れる。

### F4　Python にあって Swift に無い仕組み（全部既定 OFF）
- Python：`BOREDOM_ON`（同一回戦3年連続敗退で +3）・`UPSET_ON`（波乱の年）・`AUDIENCE_SPLIT`（客層二層）・旧 `EVENT_TABLE` 18種＋`SEASONAL`・`INJURY_ABILITY`・`RIFT_RESPOND`（`sim_career.py:122-131,422-426,147-170,396`）
- 何が起きる：`exp_*.py` でこれらを ON にして出した数字は、アプリでは再現できない（Swift に対応物が無い）。既定 OFF なので通常の sim・golden には影響しない。
- 直すなら：直す対象ではなく、実験スクリプトの冒頭に「アプリ未実装」と書いて混同を防ぐ。
- 確度：高　実害：情報のみ　golden：効かない　規律A：不要

## §2 確度 中・実害は条件つき（F5〜F7）

### F5　おすすめ注ぎ（recommendedPlan）が、最低の能力が器満了だと止まる
- Swift：`Allocation.swift:131`（`guard pourStep(...) > 0 else { break }`）　Python：`balance_sim.py:325`（同じ）
- 何が起きる：成長予算が尽きた年は演技4能力すべてが利得0。最も低い能力が演技系だと、メンタルにまだ注げても計画が空になる（実測：予算5・全通貨10で `recommended_plan` が `[]`、メンタルの `projected_gain` は +0.92）。
- 既知：UI は `GameSession.swift:464-486`（監査F-02）で台本の続きを足して回避済み。正典関数自体は意図的に不変。
- 直すなら：「利得0の候補を除いて次の最低へ進む」に変える。これは乱数ではなく**計画の中身**が変わる。
- 確度：中（コードと実測で確認済み。アプリでは UI が補う）　golden：**効かない見込み**（gen_golden の144回の計画で、途中打ち切りかつ他に注げた例は 0 回）。ただし sim・ボットの分布は変わる　規律A：必要（Python → Swift → 再生成 → swift test。golden の数値は変わらない想定だが再生成で確認する）

### F6　保存から復元すると「王者ライン上書き」が消える
- Swift：`WeekRunner.swift:610`（`self.finalLine = config.calendar.gpFinalLine`。コメントは「バランス更新を古いセーブに固定化させない」）。`finalLineOverride` は `init` 引数にだけあり、スナップショットにも載らない。
- 何が起きる：`finalLineOverride`（王者編の飽きられライン）を使った年を途中セーブ→復元すると、通常ラインに戻る。今のアプリは `finalLineOverride` を使っていない（grep で呼び出し無し）ので**潜在**。王者編を入れる時に踏む。
- 直すなら：スナップショットに「上書き値（Optional）」を載せ、復元時はそれがあれば優先、無ければ config から取り直す。
- 確度：中（現状は未使用）　golden：効かない（復元経路）　規律A：不要（式・乱数は動かない）

### F7　GameState の旧データ読み込みを守るテストが無い
- Swift：`GameState.swift` 冒頭の規約（後から足す物は Optional）。`SaveDataConventionTests` が見るのは `GameSession.SaveData` の宣言だけ。`GameState`・`WeekRunnerSnapshot`・`Neta`・`StageResult` は往復テスト（`CodableTests`）と `StageResult` 1件だけ。
- 何が起きる：非Optional のフィールドを `GameState` に足しても、テストは赤くならない。出荷後に足すと旧セーブが全部「復号失敗→退避→新規」になり進行が消える（`GameSession.swift:1156-1166`）。現状 `exp閃き〜胆力`（2026-08-03 追加・セーブ導入 07-24 の後）が非Optionalで、それ以前のセーブは読めない（開発中なので今は実害なし）。
- 直すなら：`SaveDataConventionTests` と同じ「宣言を文字で読む」テストを `GameState.swift`／`WeekRunner.swift`（Snapshot）／`Neta.swift` に増やし、「凍結済みの非Optional一覧」を持たせる。
- 確度：中　golden：効かない　規律A：不要

## §3 実害が小さい物（F8〜F15・確度は各項に記載）

### F8　特技を覚える判定に 1e-9 の許容があり、Python と微妙に違う
- Swift：`Skill.swift:46`（`>= amount - 1e-9`）　Python：`balance_sim.py:176`（`< v` なら不可＝許容なし）
- 何が起きる：残高がちょうど足りない（差が 1e-9 以内）と Swift は覚えられ、通貨が −1e-9 になる。`pourStep` は `<= pourEpsilon` で弾くので実害なし。`golden_features` の比較も 1e-9 なので検出されない。
- 直すなら：Python 側にも同じ許容を入れる（または Swift の許容を外す）。
- 確度：中　golden：効かない　規律A：どちらを直しても Python 同期が要る

### F9　決勝2本目に「1本目と同じネタ」を指しても減点を免れる（コア側に歯止めが無い）
- Swift：`GameEngine.swift:271-274`（`selectedNetaID2` が `selectedNetaID` と同じでも「2本目あり」扱い）　Python：`sim_career.py:600-604`（`others = [x for x in s.netas if x is not n]`＝別のネタだけ）
- 何が起きる：コアの関数単体では同じ id を許す。UI は `GameSession.swift:813` で外すので実害なし（code_review_2026-10-19f §2 で対応済み）。また `applyNetaRetire` は `selectedNetaID2` を消さない（UI の `:879` で補う）。
- 直すなら：`sid != id` の条件を `netaScoreBonus` に足す。
- 確度：中　golden：効かない（selectedNetaID==nil）　規律A：不要（ネタ未選択は恒等）

### F10　ネタの枠数の上限がコアに無い
- Swift：`WeekRunner.swift:458`（`applyNetaCreate`）・`:506`（`applyNetaRecall`）は件数を見ない。`netaActiveSlots=4` は UI だけ（`GameSession.swift:776,887`）。
- 何が起きる：UI 以外から呼ぶと5本以上になる。実害は今なし。
- 直すなら：コア側で `netas.count < config.netaActiveSlots` を見て、超えたら保管庫へ。
- 確度：高（コード上は事実）／実害は低　golden：効かない　規律A：不要

### F11　`@discardableResult` の付け先がずれている
- Swift：`GameEngine.swift:173-176`（`@discardableResult` の直後にコメントを挟んで `livingCostDue` が続き、`moveRoom` に付いていない）
- 何が起きる：`moveRoom` の戻り値を使わない呼び出しに警告が出る可能性。`livingCostDue`（Int を返す）は意図せず戻り値を捨てても無警告。動作は同じ。
- 直すなら：属性を `moveRoom` の直前へ動かす。
- 確度：高　golden：効かない　規律A：不要

### F12　特技の効き具合が GameConfig の外にある
- Swift：`Skill.swift:33-36`（`injuryMult 0.7`・`fameMult 1.1`・`livingMult 0.95`・`riftMult 0.8` と費用表）　Python：`balance_sim.py` の `SKILL_*`（同値）
- 何が起きる：絶対ルール3「バランス数値は全て GameConfig に集約」に反する。現状は値が一致していて、`golden_features.json` で守られている。
- 直すなら：GameConfig に移す（値は変えない）。
- 確度：高　golden：効かない（値が同じなら不変）　規律A：形式上は対象（Swift の位置変更だけ・Python 変更なし）

### F13　GP回戦の週と大会の週が重なると、その年のGPが止まる（今は重ならない）
- Swift：`WeekRunner.swift:343`（`!acted && ... week == cal.gpRounds[gpStage].week`）　Python：`sim_career.py:826`（同じ）
- 何が起きる：同じ週に大会があって出ると `acted` が立ち、その回戦は飛ばされる。`gpStage` は進まないので、以降の週が `gpRounds[gpStage].week` と一致せず GP が静かに終わる。現行カレンダー（大会 12/15/27/29/35/38/46・GP 30/39/41/43/45）では重ならない。`CalendarInvariantTests` に重なり検査が無い。
- 直すなら：カレンダーを変える時に備え、「大会の週と GP 回戦の週は重ならない」テストを足す。
- 確度：中　golden：効かない　規律A：不要（テスト追加のみ）

### F14　オファー無しで「受ける」を選んだ時の扱いが違う
- Swift：`WeekRunner.swift:307`（`.acceptOffer` でオファーが無ければ完全休養）　Python：`sim_career.py:943`（`act == "offer" and offer` が偽なら何もしない＝休養も行動も無い）
- 何が起きる：Swift は意図的（`CodableTests` の `testAcceptOfferWithoutOfferActsAsFullRest` で固定）。Python のボットはオファーがある時しか選ばないので差は出ない。
- 直すなら：Python に `else: B.do_rest(...)` を足して合わせる（ボットは通らない分岐）。
- 確度：高　実害：なし　golden：効かない　規律A：不要

### F15　相性が上限だと、すれ違いゲージが下がらない（設計メモ）
- Swift：`GameEngine.swift:280-304`（`applyRiftWeekEnd`）　Python：`sim_career.py:752-775`（同じ）
- 何が起きる：下がる条件は「その週に相性が上がった」だけ。相性20（上限）では上がれないので、すでに溜まったゲージは自然には減らない（増えもしない＝上限なので `gain` が0）。「向き合う」イベント（−30）だけが減らす。仕様どおりだが、相性が上限に張り付いたまま 50 を越えて止まる経路がある。
- 確度：高　golden：効かない　規律A：式を変えるなら必要。オーナー判断事項（決めない）

## §4 突き合わせて一致していたもの
- GameConfig の全数値（稽古・バイト・休む・オファー4種・大会7種・GP5回戦・復活74/決勝80・賞金・知名度・解散・誘い・体調ダウン・生活苦・夜逃げ・部屋・アイテム価格と回数・特技・ランク倍率・レシピ）⇔ `balance_sim.py`/`sim_career.py`。
- 週の処理順（大会→GP回戦→復活→決勝→オファー抽選→療養→行動→注ぎ→生活費→生活苦→夜逃げ→解散→誘い）と、乱数の消費順（perform は常に2回・オファーは1＋当選時2回・体調ダウンは条件を満たす時のみ1回）。
- 浮動小数の演算順（`perform` のスコア合算・決勝の人気補正・体調ダウン確率の掛け算順・知名度の逓減）。
- 別系統の乱数（誘い §102・追加の札・定数 0xD1B54A32D192ED03 と塩）の式とシード合成。
- 夜逃げ線・借金線の境界は厳密な `<`（Python と同じ）。所持金0ちょうどは借金扱いにならない。週48の生活費は払われ、夜逃げならその週で終わる。年末（week>48）は何も走らず `yearDone`。
- 選択肢イベント全31種の効果量（`ChoiceEventTable` ⇔ `_app_apply`/`_others_apply`）と発火帯（`weeklyFireable` ⇔ `_app_band`/`_others_fireable`）。差は F2 の「加減算の通し方」だけ。
- 整数割り算・丸めの切り捨て：`Int(compat)`（相性8〜14帯）は Python の `int()` と同じ。`Int(rounded())` は生活費のやりくり割引のみ（133,000 ちょうどで差なし）。他に意図しない切り捨ては見つからなかった。
- 空配列：`weakestSkillPlus` の `?? .表現`、`pick` の空プール、`extraOffers` の `rest` 空ガード、`recommendedPlan` の 10,000 ガードは安全。

## §5 check_golden_sync / golden が守っていない範囲
`check_golden_sync.py` は `gen_golden.py`（3年）と `gen_golden12.py` の出力行が Swift に貼ってあるかだけを見る。`gen_golden_features.py`（部屋・特技・店）は再生成して差が無いことを今回確認したが、同期チェックの対象外（手で再生成を忘れても検出されない）。
次は Python 由来の期待値が**無い**（Swift 側の手書き値だけで守っている）：
- 追加の札 `extraOffers` ⇔ `extra_offers`（`CoverageGapTests` の手書き値）
- ネタの補正 `netaScoreBonus`・飽き `tiredYears`・年初の飽き進行（`NetaTests`・`CoverageZTests` の手書き値）
- 選択肢イベントの効果と発火帯（`ChoiceEventTests`）
- 敗者復活・王者シード（`seedFinal`）・ライン上書き・GPシード（`gpSeeded`）の各分岐（3年 golden は台本上、通る分岐だけ）
- 療養週の回数券（F3）・体調ダウンの特技/喉のケア倍率（`golden_features` は決定的な式のみで、乱数判定は未カバー）
