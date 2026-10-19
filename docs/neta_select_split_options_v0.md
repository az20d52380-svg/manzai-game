# 勝負ネタの印と「書く対象」を分けるか：案3つ（キュー114・オーナー判断の材料）v0

コードは変えていない。根拠は docs/code_review_2026-10-19f.md §7 と 19g §4、および下記の grep。

## §1 今の動き
`GameState.selectedNetaID`（GameCore/GameState.swift:56）が2つの役を兼ねている。
- **大会で使うネタ**：`GameEngine.netaScoreBonus`（GameEngine.swift:264）が `selectedNetaID` のネタの完成度・バズ・飽きを読んで本番ラインに足す。`markNetaUsed`（WeekRunner.swift:149）・紙講評（JudgeData.swift:17）・`selectedNeta`（GameSession.swift:759）も同じ id を読む。
- **次に書く対象**：`GameSession.applyNetaWork`（GameSession.swift:776〜）が「ネタ作り／喫茶店／ファミレス」の週に `selectedNetaID` を改稿し、無ければ新ネタを作ってそれを `applyNetaSelect` で選択する。画面側は `WeekMainView.writeTarget`（:664）が同じ id を読み、`netaPicker`（:728）で「替える」＝`selectNeta(n.id)`、「新しく書く」（:745）と `prepareNetaTarget`（:798）＝`selectNeta(nil)` を呼ぶ。つまり「新しく書く」を選ぶと勝負ネタが nil になり、書いた直後にその新ネタが勝負ネタとして自動選択される。さらに大会入口・本番前カード（StageViews.swift:192, 314）が開くたびに `ensureStageNetaDefault`（GameSession.swift:804）が走り、「選択なし、または舞台未経験で完成度が最高より低い」なら最高完成度のネタへ `selectNeta` で上書きする（手で選んだ未披露ネタも対象）。ネタ帳の「勝負ネタにする」（NotebookView.swift:356）も同じ `selectNeta`。
- **規律A**：`netaScoreBonus` は GameCore の式で `selectedNetaID` を読む。ただし Python 正典・golden 側はネタ個体を持たず `selectedNetaID==nil` で恒等0（GameEngine.swift:260-261）。だから「`selectedNetaID` の意味・式・乱数消費」を変えなければ規律Aには触れない。書く対象を持つ場所は `applyNetaWork`（GameSession＝アプリ層）と `writeTarget`（View）で、どちらも GameCore 外。

## §2 案
### A：書く対象を別の状態に分ける（アプリ側だけ）
- 変える所：GameSession.swift（`var writeNetaID: Int?` を足し、`applyNetaWork` の改稿対象・新ネタ作成後の選択をこちらに替える。新ネタ作成後は `selectedNetaID` を触らない＝勝負ネタ未設定ならそのまま nil）、WeekMainView.swift（`writeTarget`・`netaPicker`・`prepareNetaTarget` が `writeNetaID` を読み書き）、`ensureStageNetaDefault`。ネタ帳の「勝負ネタにする」は従来どおり `selectedNetaID`。ネタ見せ会／フリーライブの対象は勝負ネタを優先する現状維持でよい。
- 規律A：触らない（GameCore の式・乱数・golden は不変。`swift test` は念のため確認）。
- 手間：中（約3ファイル。`writeNetaID` はセーブに載せるか否かを決める。載せなければ再起動後は「勝負ネタ→無ければ最後のネタ」に戻るだけ）。
- 体感：手で選んだ勝負ネタが、何を書いても動かない。書いたばかりの新ネタは勝負ネタにならないので、大会前に「新ネタを勝負ネタにする」手動の一手が要る（案内を一言出すとよい）。
- `ensureStageNetaDefault`：自動選択の源（書く行為）が無くなるので「選択なしの時だけ最高完成度を入れる」に縮める。手で選んだ未披露ネタは尊重される＝19g §4 も解消。

### B：書く前の勝負ネタを覚えて、書いた後に戻す
- 変える所：GameSession.swift（`prepareNetaTarget` が呼ぶ `selectNeta(nil)` の前に現在の id を `prevStageNetaID` に退避。`applyNetaWork` の新ネタ作成直後に、退避した id が今も `state.netas` にあれば `applyNetaSelect` で戻す）。View は小変更。
- 規律A：触らない。
- 手間：小〜中（退避の消し忘れ・書く週に実行されず休みに差し替わった時の後始末、「替える」で選んだ既存ネタが勝負ネタを上書きする経路の扱いが要る）。
- 体感：勝負ネタは残る。ただし「替える」は依然 `selectedNetaID` そのものを書き換えるので、改稿するネタを選んだら勝負ネタが替わる挙動は残る（案A より穴が多い）。
- `ensureStageNetaDefault`：別途直さないと 19g §4 は残る。直すなら「手で選んだ印（`stageNetaPinned`）」を足して、印がある間は上書きしない。

### C：今のまま、分かりやすい案内だけ足す
- 変える所：WeekMainView.swift の netaPicker／netaTargetBar に「勝負ネタ「〇〇」は、書くと入れ替わります」の一言。大会入口には、自動で替えた時に「最高完成度の「〇〇」を選んだ」の表示。
- 規律A：触らない。
- 手間：小（1ファイル）。
- 体感：事故は減るが、勝負ネタを残したまま別のネタを書くことはできない。
- `ensureStageNetaDefault`：そのまま。ただし替えた時は入口の NetaPickRow に出す。

## §3 推奨
**案A**。原因（1つの id が2役）をそのまま分けるので、書くたび・入口を開くたびに起きる2件（19f §7 と 19g §4）が同時に消え、GameCore の式は触らないので規律A・golden の再生成が要らない。
案Bは「替える」経路が残り、`ensureStageNetaDefault` も別に直す必要があるため、結局手間が A に近いのに穴が残る。

## §4 決めてほしい点（案Aを選んだ場合）
1. 新しく書いたネタは、勝負ネタ未設定なら自動で勝負ネタにしてよいか（初回の手間を省く）。それとも案内だけにするか。
2. 年の切り替えで2本目（`selectedNetaID2`）を消すか（19f §3 後半。案Aと独立）。
