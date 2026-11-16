# 候補ブランチ10本のコードレビュー（2026-11-16）

対象：基点 claude/manzai-slg-foundation-wprqlu との差分（ManzaiGame / GameCore のみ）。コード・シミュレータ・ビルドは触っていない（読み取りのみ）。

## §1 要約
- 高（落ちる・数値が変わる・予告が消える）は0件。GameCore で変わったのは JudgeTalk の文章選びだけ（乱数・golden・数値に非接触）。10本どうしの merge-tree 衝突も無し。
- 中1件：rest-cap-preview の「体力は満タン」ピルが半幅の札で金額ピルと並ぶと横にはみ出す恐れ（fixedSize・未実機確認）。
- 低8件：文言の抜け・VoiceOver・死んだ引数・語彙の穴など（直さなくても出せる）。

## §2 指摘

### 中
**M1 rest-cap-preview-cand：「体力は満タン」ピルの幅**
- ファイル：ManzaiGame/Sources/WeekMainView.swift の 1126-1130 行付近（HStack の costPill と staminaPill）と staminaPill（1394-）
- 起きる条件：体力100付近で、有料の休み（銭湯など＝金額ピルあり）を半幅の札で開く。「体力は満タン」（6字）は「体力 +40」より約2字ぶん長く、両ピルとも `.fixedSize()`。1126 行の並びには ViewThatFits が無い（1140 行側にはある）ので、狭い端末（SE 幅）で札の外へ出る／隣へ食い込む可能性。
- 直し案：札の最下段の HStack を ViewThatFits で2段に折る、または文言を「満タン」だけにする。目視（SE 幅・銭湯）で1枚確認。

### 低
**L1 hana-video-review-cand：語の除外が「差し込む前」の文にしか効かない**
- JudgeTalk.swift paperReview（usable 作成）。除外は束の雛形に対して行い、`{題}` に入るネタ名は後から入る。ネタ名に「客」「席」（例『客引き』）があると動画審査の紙講評にも出る。語彙表（vocab[nil]）の `{入り}{中}{一言}{締め}` 側は確認済みで客の語は無い。
- 直し案：fill 後の文にも isVenueLine をかけ、当たったら別の行を選び直す（または許容と決める）。
- 補足：isVenueLine は「席」を含む語全般に当たる（今の束では誤除外なし）。

**L2 exp-hint-dedup-cand：死んだ入力が残る**
- WeekHint.swift 26-28 行：`plusAvailable` / `expBannerShown` は line() から使われなくなった。WeekMainView.swift 527-528 行は計算だけ続ける（anyPlusEnabled を毎回走らせる）。
- 起きる条件：動作は正しい（ボタンの小さい字は expGrains>0 で「振れる経験点あり」、unspentBeforeStage の時は朱札と看板が言う）。ただし「能力アップ」カードが見えない状態（練習の一覧を開いている等）では一言もボタンの字も出ない。
- 直し案：入力2項目と呼び出し側の計算を消す（テストの base() も）。一覧展開中の扱いは目視で確認。

**L3 short-money-price-cand：VoiceOver と1行幅**
- WeekMainView.swift shortMoneyLine：`¥6万・あと¥4万不足` は記号の読み方が機械的（「円マーク6万」「中黒」と読まれる恐れ）。半幅の札で2行に折れる可能性（コメントは「1行に収める」と書くが lineLimit が無い）。
- 直し案：`.accessibilityLabel("6万円、あと4万円不足")` を付ける。`.lineLimit(1).minimumScaleFactor(0.8)`。
- 補足：タップ時のトースト（925 行）は「お金が足りない」のまま＝札と言い方が不一致（直さなくても害は無い）。Yen.man は小数1桁に丸める（14,999→「1.5万」）が不足額は「あと」なので実害は小さい。
- 端の場合：所持金が負（−10万）でも cost−money は大きい正の数になり落ちない。cost=0 は旧文言。確認済み。

**L4 hana-seal-cand：帯の英字間隔が読み上げで1文字ずつになる**
- YoseChampionCelebrationView.swift 237-245 行：`"T H E   H A N A"` は VoiceOver が文字ごとに読む。直下の tournamentName「THE HANA 決勝」と内容も重複（元の「漫 才 の 頂…」も同じ型）。
- 直し案：帯の Text に `.accessibilityHidden(true)`。
- 補足：朱印の読みは「栄冠の判子」で問題なし。頂GP 側は既定値が元の文字列と同一（FinalsPresentationView は引数なし呼び出し）なので退行なし。コメント（234/321行）に「日本一」が残るだけ。

**L5 second-neta-note-cand：ネタが1本しか無い人にも「2本目を選ばないと減点」**
- StageViews.swift goNote（312-320行）：選べる2本目が無い（持ちネタ1本）ときも出る。選べない人への脅しになる。エンジンの条件（GameEngine.netaScoreBonus：1本目がある＋2本目なし／polish<netaSecondMinPolish）とは一致している。
- 直し案：2本目になりうるネタ（1本目を除いた activeNetas）が0本なら別文言（「2本目のネタが無いので減点」）か出さない。

**L6 tired-notice-text-cand：トーストが長い**
- WeekMainView.swift 1550 行：本文が約45字に伸びた。toast の lineLimit 次第で端末幅によっては欠ける。VoiceOver は全文を読む（長い）。内容は tiredYears の仕様（寝かせても戻らない・新規は0）と一致＝正しい。
- 直し案：2文に絞る（例「『名』は見飽きられてきた。寝かせても戻らない」）か、目視で折り返しを確認。

**L7 self-order-cand：QualifierNoticeView の読みの代用が変わった**
- QualifierNoticeView.swift 39-40 行：読み表に無い名前の代用が `selfY`（自組の読み）から `$0`（その名前そのもの）に変わった。今は FinalistAnnounceView.yomi が npcNames 全52組を持つので実害なし。表に無い名が増えた時は漢字名が末尾に集まる（元々 selfY で不定だった）。
- 補足（確認済み）：空の名前は isKana=false→FNV 経路で落ちない（`others.count+1`≥1 で剰余OK）。束が空のときは idx=0 で自組だけ。名前が他組と同じでも yearRoster が selfName を除外するので重複しない。落選時（自組が items に無い）は others をそのまま返す。FNV は UInt64 の `&*=` で桁あふれしない。

**L8 venue-heading-cand：説明行に lineLimit が無い**
- S6bView.swift 91 行：12pt・17字。通常は1行に入る。文字を大きくする設定では折れる（折れても枠は伸びる＝崩れはしない）。
- 補足：見出しと数字（venueTier は残金の帯）は一致。年表の「到達」（194行）は別の意味（年ごとの頂グランプリの到達）なので変更不要。

### rift-defer-cand（指摘なし）
- GameSession.swift 599-618 行：予告が永久に出なくなる経路は見つからなかった。理由：(1) 前に回った4つ（負けた後・連敗の底・通過の分かれ道・前夜）はすべてキャリア1回のフラグ（didFire…／styleTalkDone）で、出たら次の自由週に予告の番が来る。(2) riftWarned は印として残り、didFireRiftWarn が false の間は毎回評価される。(3) 年末へ（1016 行）の巻き戻しと保存復元（317-319 行）も不変。(4) 解散は rift≥100 かつ riftGain 0.5/週以下＝警告50→100に100週超かかるので、1〜数週の遅れで予告前に解散にはならない。
- 影響：同じ週に「負けた後」などと重なった時に予告が1週以上遅れる（意図どおり）。既存テスト（RiftWarnEventTests・SessionCoverage1109・AppSaveFixture1110）は優先順位に依存しないつくりで、読んだ限り壊れない（未実行）。

## §3 問題なしと確かめた点
- GameCore の変更は JudgeTalk.swift の paperReview（文章選び）のみ。isVideo は既定 false・`usable = pool` で非動画は同一（テスト testNonVideoUnchanged あり）。RandomSource・GameEngine・GameConfig・golden に触れていない。salt 剰余のみ。
- hana-video：JudgeData.review の呼び出しは TournamentResultView 1か所だけ（TalkWrappers1026Tests はデフォルト引数で不変）。isHanaVideo は同ファイル 72 行に既存。束が空になる場合は `Paper.pass/fail` → 元の束へ段階的に戻り、最終 `?? "{入り}、要確認。"` もあり落ちない。紙講評の束に客の語以外の客席前提語（笑い・拍手・場内・反応・どっと）は無い。
- rest-cap：体力が100超でも `max(0, 100−…)` で0に丸まり「満タン」。負の体力でも上限は recovery のまま。払えない札は restFull=false で旧挙動。非休みの札（練習など）は stamDelta 計算が従来どおり。staminaPill の `up = delta>=0` は delta=0 が休みの満タンのときだけ来る。回数券・部屋の上乗せは applyRest と同じ式のまま上限だけ足した。
- short-money：cost の既定0で他の札は変わらない。pbxproj のテスト登録（PBXBuildFile／FileReference／group／Sources の4か所）は揃っている。RootView の MZ_EVSKIP は `#if DEBUG` の中（91-347 行）で本番に出ない。
- venue-heading・hana-seal・tired-notice・second-neta の RootView「final_entry」も DEBUG ブロック内。hana-seal の引数は既定値つきで末尾の onFinish の前に追加＝既存呼び出し（FinalsPresentationView・YoseFXPreview）は無変更で動く。
- exp-hint-dedup：変更したテスト3か所以外に、旧文言「経験点で上げられる能力がある」を見る箇所は無い。
- self-order：かなの名前は読みの位置（テスト通り「こだま」=2番目）、同じ年なら同じ位置（決定論）、他組の並びは不変。ゲームの乱数を使わない。
- 10本の総当たり merge-tree：衝突なし（WeekMainView を触る rest-cap／short-money／tired-notice、TournamentResultView を触る hana-video／hana-seal、RootView を触る short-money／second-neta も離れた行）。
- 未実施：ビルド・テスト実行・実機目視（指示により）。上の中・低は読解での推定。
