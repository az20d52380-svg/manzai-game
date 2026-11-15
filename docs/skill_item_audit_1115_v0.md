# 特技（Skill）と道具（ShopItem）の効果の点検 2026-11-15 v0

対象：GameCore Skill.swift・Item.swift・GameEngine（add 知名度・applyTraining・applyRest・livingCostDue・applyRiftWeekEnd）・WeekRunner（体調ダウン抽選・resolveTournament・療養週）・GameConfig 211-235・ShopView／AbilityUpView の文言・tools/balance_sim.py／sim_career.py。読むだけ（コード変更なし）。
節構成：§1 指摘（4件）／§2 問題なしと確かめた所（1行ずつ）／§3 既出の突き合わせ。

## 要点3行
1. 式と値は Python 正典と Swift で一致（規律A違反なし）。特技4・道具の効果は golden_features（skills_learn・injury_mult_skill_throat・items_*）で両側から固定されている。二重に効く・消える経路も見つからない。
2. 指摘は4件（中1・低3）。最も重いのは **新幹線回数券（¥20万）が金額では回収できない設計**（4大会ぜんぶ出ても節約は交通費12万円止まり・判断が要る）。
3. 他は「愛され芸人は決勝進出・優勝・イベントの知名度に効かない」「銭湯の回数券が体調ダウンの発症週で減る」「Skill.* の4倍率と店の価格が check_config_sync の対象外（golden で間接的に固定）」。

## §1 指摘

### 1. 新幹線回数券は買うほど金は減る（体力だけが得）　【中・確信度 高・設計判断】
- 場所：GameConfig.swift:220（¥200,000・年1回）／GameConfig.swift 大阪の大会＝Calendar.swift:65-68（春新人賞A・B・夏中堅賞・大阪戎の最大4つ）／Calendar.swift:108-109（夜行バス ¥10,000・体力−25／新幹線 ¥30,000・体力0）／WeekRunner.swift:208-209（回数券があると交通費0・体力0）。
- 手順：年の初めに回数券を買い、その年の大阪4大会すべてに出る。
- 見えること：札は「今年の大阪遠征が交通費なし・疲れない」。
- 実際：節約できる交通費は、普段の新幹線なら 4×¥3万＝¥12万、夜行バスなら 4×¥1万＝¥4万。¥20万の値段に届かない（体力は最大 25×4＝100点ぶん浮く）。資格で出られる大阪が減る年（careerYearAtMost(10) を過ぎた年は大阪戎だけ＝1回）は ¥3万しか浮かず、差はもっと開く。
- 起きないこと：効かない場面は無い（大阪の4大会で効く・東京開催の週は効かない＝説明どおり）。
- 直し方の案（数値＝規律A・判断はオーナー）：①値段を下げる（例 ¥10万）②「体力温存」を売りとして文面に出す（「交通費は戻らない・体力を温存する品」）③現状維持（意図した体力の買い物）。
- 既出：いいえ（shop_audit_1115 は値段と上限のみ・money_audit_1115 は部屋と賞金）。

### 2. 愛され芸人は「決勝進出」「優勝」「イベント」の知名度には効かない　【低・確信度 高・表示／設計判断】
- 場所：GameEngine.swift:55-62（×1.1 は `add(.知名度)` の正の増分だけ）／GameEngine.swift:67-74（addFameBig・addFameRaw は素通り）／WeekRunner.swift:270・294・313／ChoiceEventEffect.swift:32（イベントの fame は素の加減算）。
- 手順：愛され芸人を覚える→大会で決勝進出か優勝する／イベントで知名度が増える。
- 見えること：説明は「知名度が少し伸びやすくなる」。大きな増え（優勝の知名度・決勝進出・イベント）には掛からず、稽古・オファー・大会の通過・GP の1回戦ごとの増えだけに掛かる。
- 実際に起きること：数値は Python と一致（sim 側も `_add_v62` の中だけ）。実害は「効いた実感が薄い」。
- 直し方の案：①説明を「稽古・オファー・大会通過の知名度が少し伸びやすくなる」に具体化（表示のみ）②優勝・決勝にも掛ける（式変更＝規律A・golden 再生成）③現状維持。
- 既出：いいえ。

### 3. 銭湯の回数券が「体調ダウンの発症週」で1回減る　【低・確信度 高】
- 場所：WeekRunner.swift:340-346（発症した週は action を `.rest(.完全休養)` に差し替え）→ :365 `applyRest(r, …)`（useTicket 既定 true）／:437-439（続く療養の2週は useTicket:false）／Python sim_career.py:1058-1070・1084 も同じ。
- 手順：銭湯の回数券を持つ→体力<50で稽古かキツいバイトを選ぶ→体調ダウンが当たる。
- 見えること：発症週にも回復 +10 が付き、のこり回数が1減る。療養の2週は減らない。
- 起きること：コードの注釈（A-10「選んでいない療養週は回数券を使わない」）は発症週にも当てはまりそうだが、発症週だけ使う。札は「休む4回ぶん」なので、強制休養を数えるかは読み方次第。Python と一致＝食い違いではなく設計の揺れ。体力がすでに満タン近くで休んだ週も +10 は丸められて捨てられる（体力 clamp・shop_audit #3 の同型）。
- 直し方の案：①発症週も useTicket:false にする（式変更＝golden 影響を測る）②札を「休む4回ぶん（倒れた週も数える）」にする③現状維持。
- 既出：近い話＝cancelled_sleep_audit_1115（寝る行動の中止）とは別。本件は未記載。

### 4. 特技の倍率4つと店の値段が `check_config_sync` の対象外（golden で間接的に固定）　【低・確信度 高】
- 場所：Skill.swift:33-36（`Skill.injuryMult/fameMult/livingMult/riftMult` は GameConfig でなく static）／check_config_sync.py:61-63（道具で同期するのは itemDrinkStamina・itemDrinkLStamina・itemThroatInjuryMult の3つだけ）／GameConfig.swift:213-223（価格・年上限・shopLineup）／FeatureGoldenTests.swift:88-91（体調ダウンの確率の式を WeekRunner.swift:342 と別に書き写している）。
- 状況：Python と Swift の値は今は一致（0.7・1.1・0.95・0.8・0.5・価格9品・上限）。gen_golden_features.py:263-324 が skills_learn／injury_mult_skill_throat／items_drinks／items_sento_room／items_shinkansen_throat／items_no_money を Python から出して Swift が突き合わせる＝片側だけ変えると落ちる。ただし (a) 体調ダウン確率は WeekRunner の実コードでなくテスト側の写しの式を比べている＝WeekRunner の式だけ書き換えても golden は通る、(b) 稽古場の年契約・ICレコーダー・sentoRecovery・勉強会・ボイトレは店に出ていない（shopLineup に無い）ので Swift 側の単体テストのみ（EdgeBranchTests:116-130・ItemTests:24-43）。
- 直し方の案：①check_config_sync に Skill.*（4）と itemSentoRecovery・itemRecorderBonus・itemStudioBonus の定数を足す②injury 式を `GameEngine.injuryProbability(state:config:)` の1関数に出して WeekRunner と golden の両方が呼ぶ（乱数の消費順は不変）。いずれも表示・値は不変。
- 既出：485（定数149個の棚卸し）は GameConfig の定数だけを数えたので Skill.* は対象外だった＝本件は新規。

## §2 問題なしと確かめた所
- **体が資本**：確率に ×0.7（WeekRunner.swift:342・Python sim_career.py:1060 と同順の掛け算）。稽古とキツいバイトの週だけ＝説明「体調を崩しにくくなる」どおり。喉のケア用品と重なると ×0.35（意図どおり・stamina_audit 既出）。
- **愛され芸人（効く所）**：`add(.知名度)` の正の増分だけに ×1.1（Python balance_sim.py:205 と演算順が同じ）。減る方向は変えない。稽古・オファー（GameEngine.swift:198）・大会の通過（WeekRunner.swift:233）・GP の各回（:266・:292）に掛かる。
- **やりくり上手**：`livingCostDue` の1か所（GameEngine.swift:183）が引き落とし（:336）・画面（WeekMainView.swift:525・1504／ShopView.swift:81／GameSession.swift:429）の全部を担う＝一致。¥14万×0.95＝¥13.3万で丸めのずれなし。部屋の上乗せには掛からない（説明「月末の生活費」どおり）。
- **相方思い**：週末の「増えた週だけ」×0.8（GameEngine.swift:300）。イベントの rift 効果は −30 だけで増える向きが無い（ChoiceEvent.swift:361）＝抜け道なし。大会の週・療養週・年末でも `applyRiftWeekEnd` は週末に毎回走り同じ式。
- **喉のケア用品（効果の場面）**：その年に1回以上買えば抽選の確率が ×0.5（Item.swift:77）。年初の `resetYearlyItems`（WeekRunner.swift:149）で消える。中断セーブは `WeekRunnerSnapshot`（init(restoring:)）経由で年初処理を通らず、復元で消えない・二重にもならない。「戻す」は `replayItemPurchases` が起点から買い直す＝回数と効果が一緒に戻る（shop_audit 確認済み）。
- **栄養ドリンク／回復ドリンク大**：+8／+20（itemDrinkStamina／itemDrinkLStamina・同期対象）。年上限 6／4 は itemCounts（年初に消える）で数え、golden items_drinks が年またぎを固定。
- **銭湯の回数券（持ち越し）**：`sentoTickets` は年初で消えない（キャリアを通して残り、ShopView の「のこり◯回」と一致）。新しい周回は `GameState(config:…)` で nil に戻る＝周回をまたいで残らない。購入は tickets>0 の間は不可で二重に買えない（Item.swift:35）。療養の2週は減らない（WeekRunner.swift:439）。行動カードの回復量の見積もりにも回数券が入っている（WeekMainView.swift:1073）。
- **新幹線回数券（効く場面）**：大阪の大会の出場確定時だけ交通費0・体力0（WeekRunner.swift:208）。東京開催と動画審査には掛からない（`spec.osaka` のときだけ使う）。画面の文言と所持金の判定は StageViews.swift:211-214 が実コードと同じ条件。年初で消える。
- **稽古場の年契約・ICレコーダー・勉強会・ボイトレ**：店の品書き外（shopLineup 外）で `canBuy` が偽＝アプリでは買えず効果も出ない（原則「能力は売らない」どおり）。式は applyTraining（GameEngine.swift:119-120）と balance_sim.py:371-374 が一致。借金中は係数が通貨へ掛かる（意図どおり）。
- **特技を覚える**：`learnSkill` は乱数なし・費用は全通貨そろった時だけ引く・同じ特技は二度覚えられない（`canLearn`）。年をまたいで残り（skills は年初で消えない）、新しい周回で消える。AbilityUpView は押した段を先に確定してから覚える（abilityup_audit_1115 #1 対応済み）。旧セーブの未知の特技名は黙って捨てる（Skill.swift:59-66）。
- **画面の説明文と実効果**：特技の summary は「％なし・少し」で式と向きが一致（体調・知名度・生活費・すれ違い）。道具の summary も向きが一致（回復ドリンクは +20 が「しっかり」・喉は ×0.5 が「今年は」）。

## §3 既出の突き合わせ（「既出」と書ける所）
- 年末の週に喉のケア用品・新幹線回数券を買うと年初で消える → **既出**（shop_audit_1115 #2）。
- 体力満タンで回復ドリンクを買うと回復が捨てられる／所持金ぴったりまで使える → **既出**（shop_audit_1115 #3・#5）。
- 二度押しで年上限の無い品が2個買える → **既出**（double_tap_audit_1115 #5）。
- 体調ダウンの閾値20と50（赤の線）・体力の定数の棚卸し → **既出**（stamina_audit_1115）。
- 銭湯・稽古場・ICレコーダーが行動カードの見積もりに入っている → **既出**（preview_audit_1115 道具の行）。
- 本書の指摘1〜4 は上記のどこにも無い＝新規。
