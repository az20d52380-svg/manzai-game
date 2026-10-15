# 漫才コンビ育成ゲーム 演出・エフェクト・手触り完全設計書
**〜『寄席と計器（Yose & Gauge）』商業スマホ育成ゲーム級エフェクト仕様〜**

パワプロ（サクセス）の「1タップごとに計器が跳ねる中毒性」、ウマ娘・学園アイドルマスターの「溜めと爆発のメリハリ」、そして上方演芸・寄席の「木札・拍子木・朱印・金紙吹雪の泥臭い熱量」を、**外部画像素材ゼロ（SwiftUI図形・`Canvas` + `TimelineView`・SF Symbols・グラデーション・Hapticsのみ）**で実現する演出正本です。

---

## 1. 演出の原則（気持ちよさの構造と強弱基準）

### 1-1. 気持ちよさの4段構成：「予告 → 溜め → 爆発 → 余韻」
売れている育成ゲームの気持ちよさは、エフェクトの派手さではなく**「コントラスト（静と動の落差）」**から生まれます。すべての演出（中規模以上）は以下の4段で組み立てます。

| 段 | 役割 | 寄席・計器での表現 | 秒数比率 |
| :--- | :--- | :--- | :---: |
| **① 予告（Anticipation）** | 「何かが起きる」と脳に構えさせる | ボタンが物理的に沈む（`y: +3pt`）、木札の枠が金色に光る、拍子木の「チョン！」という乾いた音 | `10%` |
| **② 溜め（Hold / Tension）** | 一瞬の静止・収縮でエネルギーを圧縮する | 判子が画面手前で最大拡大（`scale: 2.2`）して1フレーム止まる、審査員札の『封』が微振動する、無音の間 | `15%` |
| **③ 爆発（Impact / Burst）** | 圧縮を解放し、視覚・触覚・聴覚を同時直撃する | 判子叩きつけ＋画面縦揺れ＋数値ポップ＋放射パーティクル＋光の筋＋`rigid`/`success` Haptics | `25%` |
| **④ 余韻（Follow-through）** | 達成感を味わわせつつ、次の操作へ滑らかに繋ぐ | 金紙吹雪がゆっくり舞い落ちる、上がった数字が山吹金から墨色へ落ち着く、キラーンと斜光が走る | `50%` |

---

### 1-2. 秒数の絶対基準（何百回見ても疲れないテンポ）
育成ゲームは1周で数百回コマンドを叩きます。**「触った瞬間の反応は0.06秒以内」「毎週見る演出は0.5秒以内」「特別な節目だけ1.5秒」**を鉄の掟とします。

* **極小（マイクロ反応）**：**`0.06秒〜0.18秒`**（操作を一切止めない。連打可能）
* **小（毎週の行動結果）**：**`0.28秒〜0.45秒`**（指を離してから次のボタンに目が移る間に終わる）
* **中（山場・小節目）**：**`0.65秒〜0.95秒`**（短いカットイン帯やスタンプ。1タップで即スキップ可）
* **大（ランク昇格・突破・開票）**：**`1.20秒〜1.50秒`**（1タップで即確定・放置でも自動進行）
* **特大（優勝・大成功・年越し）**：**`1.80秒〜2.40秒`**（最大の見せ場。これも画面タップで即座に最終状態へ飛ばせる）

---

### 1-3. 強弱の4段階（小・中・大・特大）と出来事の割り当て
すべての出来事を同じ強さで光らせると、画面がうるさいだけで何も気持ちよくなくなります。以下の4段階に厳格に振り分けます。

| 強さ | 秒数目安 | 画面への干渉 | 割り当てる出来事 |
| :--- | :---: | :--- | :--- |
| **【小】日常の手触り** | `0.06s〜0.35s` | 部品の中だけで完結（暗転なし・揺れなし） | ・ボタン押下 / タブ切替<br>・能力アップの `[+]` `[-]` 1タップ<br>・体力ゲージの増減 / お金の日常増減<br>・通常練習の経験点獲得 / 知名度の小上昇 |
| **【中】手応えの節目** | `0.45s〜0.85s` | 対象カードのバウンス＋局所パーティクル＋微振動（`2pt`） | ・能力アップの「確定」（複数段階上昇）<br>・イベントの選択肢決定と結果反映<br>・大会エントリー完了 / 本番開始の幕開け<br>・本番中の「ウケの波」（小ウケ〜中ウケ）<br>・借金転落の警告（赤枠脈動） |
| **【大】脳汁が出る山場** | `1.10s〜1.50s` | カットイン帯 or 半透明暗転＋判子叩きつけ＋画面揺れ（`4pt`）＋集中線 | ・**ハマった！（練習大成功）**<br>・**能力ランクアップ（G→F…→S）**<br>・本番の「どっと沸いた！（大ウケ）」<br>・**予選・本戦の合否判（「突破」「敗退」）**<br>・賞金獲得 / 決勝の審査員札めくり（1枚ごと） |
| **【特大】1年のクライマックス** | `1.80s〜2.40s` | 全画面演出（定式幕・金紙吹雪・後光・大揺れ `6pt`） | ・**決勝4票目到達〜「優勝」決定の瞬間**<br>・**Sランク到達時**の特別昇格<br>・**年の幕間（1年の締め → 新年開幕）** |

---

## 2. 出来事ごとの演出一覧表（全18項目）

※効果音（SE）は実装時にそのままアセット名・Enum名として使える識別子（`SE_...`）と、鳴らす正確なタイミング（`+0.00s`等）を指定しています。
※「％」表記は一切使用しません。

| # | 出来事 | 強さ | 秒数 | 見た目の動き（予告 → 溜め → 爆発 → 余韻） | Haptics（触覚） | 効果音（名前と鳴らす瞬間） |
| :-: | :--- | :-: | :-: | :--- | :--- | :--- |
| **1** | **ボタン押下**<br>（週コマンド・主/副ボタン） | **小** | `0.06s`<br>（戻し`0.08s`） | **予告/爆発**：押した瞬間にボタンが下へ `+2pt`（週コマンドは `+3pt`）沈み込み、墨のハードシャドウが `0pt` になって「板を打ち付けた」接地感を作る。主ボタンは上辺ハイライトが一瞬白45%に光る。<br>**余韻**：指を離すと `0.08s` でパッと跳ね返る。 | 押下時：<br>`.impact(.rigid, intensity: 0.75)` | `SE_KIFUDA_TAP`（乾いた木札の「カッ」）：押下 `+0.00s` |
| **2** | **練習の結果**<br>（経験点が入る） | **小〜中** | `0.45s` | **予告**：選んだ練習カードの枠が山吹金（`yoseKinBright`）に `0.08s` フラッシュ。<br>**爆発**：獲得した5色経験点（閃・語・間・存・胆）の角札が下から `+12pt` せり上がりつつ、数字が `.numericText` でカウントアップ。カード周囲に該当属性色の四角い紙片が6個パッと散る。<br>**余韻**：実力木札（`YosePowerBadge`）の数字が `scale(1.18 -> 1.0)` で跳ねる。 | 経験点出現時：<br>`.impact(.medium)` | `SE_DRUM_DON`（和太鼓の短打「ドン」）：`+0.00s`<br>`SE_EXP_TICK`（算盤を弾く「パチパチッ」）：`+0.10s` |
| **3** | **ハマった！**<br>（練習の大成功） | **大** | `1.15s` | **予告**：練習直後、画面が一瞬（`0.08s`）白和紙色にフラッシュし、周囲に墨と金の「集中線」が出現。<br>**溜め**：画面中央を斜め（`-6度`）に横切る黒漆＋金枠の「カットイン帯」が左から高速突入（`0.14s`）。<br>**爆発**：帯の上に金袋文字『手応え抜群！ハマった！！』＋朱印『大成功』が `scale(2.2 -> 1.0)` で叩きつけられ、画面が縦に `4pt` 揺れる。金色の火花パーティクル24個が放射状に弾け、獲得経験点の数字が通常の1.35倍サイズで跳ねる。<br>**余韻**：獲得数値に斜めの光の筋（シマー）が走り、`1.15s` で自動消去。 | 帯突入時：<br>`.impact(.heavy)`<br>朱印着地時（`+0.18s`）：<br>`.notification(.success)` | `SE_HYOSHIGI_SHARP`（「カーン！」高い拍子木）：`+0.00s`<br>`SE_GREAT_SUCCESS`（大太鼓「ドドン！」＋三味線の上りフレーズ）：`+0.16s` |
| **4** | **能力アップの `[+]`** | **小** | `0.24s` | **爆発**：`[+]` を押した瞬間、ボタンが `+2pt` 沈み、その能力行の背景全体が `yoseKinBright.opacity(0.35)` でピカッと光る。左の能力値（例：`43 → 44`）と上部の実力値（`42 → 43`）が同時に `scale(1.22 -> 1.0)` でバウンスし、右の消費経験点セルがキュッと収縮（`scale: 0.92 -> 1.0`）。<br>**余韻**：行の金発光が `0.24s` でスッと和紙色に戻る。連打しても遅延ゼロで追従。 | 押下ごと：<br>`.impact(.rigid, intensity: 0.85)` | `SE_ABILITY_PLUS`（軽快な木琴/拍子木音。連続押下で半音ずつピッチが上がる設定）：押下 `+0.00s` |
| **5** | **能力アップの「確定」** | **中** | `0.65s` | **予告**：「確定」ボタンを押した瞬間、変更されたすべての能力行の枠が同時に朱色（`yoseShu`）に光る。<br>**爆発**：上昇した能力行すべてに斜めの金の光の筋（`YoseShimmer`）が左から右へ `0.28s` で走り抜け、上部の5能力六角ランク枠と「実力」木札が `scale(1.25 -> 1.0)` でドンと跳ねる。周囲に金・朱の火花12個が散る。<br>※ランク境界を跨いだ場合はそのまま **#6 ランクアップ** へ直結。 | 確定瞬間：<br>`.notification(.success)` | `SE_ABILITY_COMMIT`（太い太鼓「ドドン！」＋鈴の余韻）：`+0.00s` |
| **6** | **ランクアップ**<br>（G→F…→S） | **大**<br>（Sは特大） | `1.45s` | **予告**：背景が黒漆65%で暗転（`0.12s`）、中央に「番付昇格」の貼り紙カードが `scale(0.88 -> 1.0)` で出現。<br>**溜め/爆発**：右側の新ランク大木札（`72×72pt`）が `scale(1.75 -> 1.0)` で着地し四隅に金火花が弾ける（`+0.08s`）。直後（`+0.18s`）に朱印『昇格』が `scale(2.2 -> 1.0)` で叩きつけられ、カード全体が縦 `3pt -> -2pt -> 0pt` に揺れる。<br>**余韻**：Sランク到達時のみ背後に金の放射光（後光）と金紙吹雪が追加。複数能力同時昇格は下段ストリップに統合し1回で完結。 | 新ランク着地：<br>`.impact(.heavy)`<br>朱印着地（`+0.18s`）：<br>`.notification(.success)` | `SE_RANKUP_FANFARE`（寄せ太鼓の連打から三味線と笛の昇格ジングル）：`+0.00s`<br>`SE_STAMP_HEAVY`（重い朱印「ドン！」）：`+0.18s` |
| **7** | **お金の出入り**<br>（バイト・買い物・授業料） | **小** | `0.38s` | **爆発**：下部黒漆バー（`YoseVitalMoneyBar`）の所持金テキスト（`¥500,000`）が `.numericText` で回転更新。**収入時**は文字が一瞬明るい白金に光り、上に山吹金の小札『`+¥8万`』が `+14pt` 浮かび上がって消える。**支出時**は文字が朱色に光り、『`-¥8万`』が下へ `-10pt` 沈んで消える。 | 収入：`.impact(.light)`<br>支出：`.impact(.soft)` | 収入：`SE_COIN_CHARI`（小判・硬貨の「チャリン！」）：`+0.00s`<br>支出：`SE_REGISTER_PAY`（帳場の木札音「カシャン」）：`+0.00s` |
| **8** | **体力の増減**<br>（休む・練習消費） | **小** | `0.38s` | **爆発**：体力ゲージ（`YoseGauge`）の幅が `.spring(response: 0.35, dampingFraction: 0.78)` で伸縮。<br>**回復時（休む）**：ゲージ面が明るい若草色に発光し、緑の十字・木の葉型の小パーティクル4個がゲージからふわりと浮く。<br>**減少時（練習）**：減った分の差分領域が一瞬だけ朱色（`yoseShu`）に残像として残り、`0.25s` で銀鼠色に消える（どれだけ減ったか一目でわかるパワプロ式残像ゲージ）。 | 回復：`.impact(.soft)`<br>消費：なし（練習結果のHapticsに統合） | 回復：`SE_STAMINA_HEAL`（温かい笛の和音「フワァ♪」）：`+0.00s` |
| **9** | **知名度アップ** | **小〜中** | `0.45s` | **爆発**：知名度数値の横に朱枠の小角札『`↑+6`』が `scale(1.4 -> 1.0)` でポップし、数字がカウントアップ。同時に小さな金の菱形火花が4個キラッと弾ける。 | `.impact(.light)` | `SE_FAME_UP`（拍手と小さな歓声のショートSE「パチパチッ」）：`+0.00s` |
| **10** | **イベントの選択と結果** | **中** | 選択`0.20s`<br>結果`0.55s` | **選択時**：選んだ選択肢ボタンが `+2pt` 沈み、枠が朱色2.5ptに変わって他の未選択ボタンが `opacity(0.4)` に退く。<br>**結果表示時**：結果カードが下から `+14pt` せり上がり、プラス効果のタグ（『間合い +18』等）は山吹金フラッシュ＋上向きバウンス、マイナス効果は灰墨フラッシュ＋横微振動（`2pt`）。 | 選択時：`.impact(.rigid)`<br>結果時：プラスなら`.impact(.medium)` / マイナスなら`.notification(.warning)` | 選択：`SE_EVENT_SELECT`（「カッ！」）：`+0.00s`<br>結果：`SE_EVENT_GOOD`（三味線「シャン！」）または `SE_EVENT_BAD`（低い鉦「ゴーン…」）：`+0.05s` |
| **11** | **大会エントリー** | **中** | `0.75s` | **予告**：勝負ネタを選んで「エントリー」を押すと、勝負ネタカードが中央で `scale(1.05)` に浮き上がる。<br>**爆発**：カード右上に朱印『真剣勝負』が `scale(2.2 -> 1.0)` でビシッと叩きつけられ、画面上部の大会看板に金の光の筋が走る。 | 朱印着地時：<br>`.notification(.success)` | `SE_ENTRY_STAMP`（太い拍子木「チョン！」＋太鼓「ドン！」）：`+0.00s` |
| **12** | **本番の開始**<br>（出囃子・幕開け） | **中〜大** | `0.90s` | **予告**：画面を覆っていた定式幕（黒・柿・萌黄）が `0.15s` 小刻みに揺れる。<br>**爆発**：拍子木の音とともに定式幕が左右へ `0.32s`（`.easeOut`）で一気に引き開けられ、舞台中央の上部からスポットライト（山吹金の逆三角形グラデーション光）がパッと点灯。コンビの2人が下からステージへせり上がる。 | 幕開き瞬間：<br>`.impact(.heavy)` | `SE_DEBAYASHI_OPEN`（拍子木「チョン、チョン！」→ 出囃子の三味線と太鼓の立ち上がり）：`+0.00s` |
| **13** | **ウケの波**<br>（本番中の客席反応） | **中〜大** | `0.60s`<br>×波数 | **爆発（3段階）**：<br>・**小ウケ（くすくす）**：舞台下から白和紙色の小座布団/笑い波紋が2個フワッと浮き、客席が `1pt` 揺れる。<br>・**中ウケ（拍手笑い）**：山吹金の波紋が広がり、黒帯の煽り文字が `scale(1.15 -> 1.0)` で跳ねる。<br>・**大ウケ（どっと沸いた！）**：画面周囲に金の集中線が0.4秒出現し、舞台全体が縦に `4pt` 跳ね、金と朱の紙片16個が下から噴き上がる。黒漆帯の明朝体『――どっと沸いた！』が一文字ずつではなく塊でドン！と張り付く。 | 小：`.impact(.light)`<br>中：`.impact(.medium)`<br>大：`.impact(.heavy)`（2連打） | 小：`SE_LAUGH_SMALL`（小笑い）<br>中：`SE_LAUGH_MID`（笑い＋拍手）<br>大：`SE_LAUGH_ROAR`（地鳴りのような爆笑＋大拍手）：`+0.00s` |
| **14** | **判（通過 / 敗退）**<br>（予選・本戦の結果） | **大** | `1.25s` | **予告**：結果カードの上段で、`[通過ライン 30]` ▶ `[実力 134]` の数字が `0.35s` で高速ドラムロール（`.numericText`）してピタッと止まる。<br>**溜め**：`0.12s` の静寂。<br>**爆発（通過）**：右横に朱印『突破』が `scale(2.4 -> 1.0)` で叩きつけられ、画面が `4pt` 揺れる。上部の結果額縁に『予選通過』が金文字で点灯し、審査講評カードの右上に『秀』（または『良』）の角判子が連打で押される。<br>**爆発（敗退）**：数値が灰墨色に沈み、鈍色の角印『敗退』が静かに落ち、照明が一段暗くなる。 | 通過：ドラム停止時 `.impact(.medium)` → 突破判子 `.notification(.success)`<br>敗退：`.notification(.error)` | ドラム中：`SE_ROLL_TAIKO`（小太鼓連打）<br>通過：`SE_JUDGE_PASS`（大太鼓「ドドン！」＋歓声）：`+0.47s`<br>敗退：`SE_JUDGE_FAIL`（低い太鼓一打「ドン…」）：`+0.47s` |
| **15** | **賞金獲得** | **大** | `0.85s` | **予告**：結果カード下段の『`賞金 +50万`』の木札枠が山吹金に強く発光。<br>**爆発**：木札が `scale(1.3 -> 1.0)` で跳ね、木札から金の小判・四角い金箔パーティクル16個が噴き出して下部所持金バーへ向かって弧を描いて吸い込まれる（または弾ける）。所持金がカウントアップ。 | `.notification(.success)` | `SE_PRIZE_GET`（華やかなチャリンチャリン音＋和楽器の祝儀フレーズ）：`+0.00s` |
| **16** | **決勝の開票**<br>（審査員札を1枚めくる） | **大** | 1枚あたり<br>`0.65s` | ※実機画面 `42_決勝演出_一騎打ち.png` 準拠。<br>**予告**：「次の審査員札をめくる」を押すと、対象の審査員縦札（『封』の朱印入り生成り札）が `0.12s` 左右にカタカタ震える（`offset(x: ±2pt)`）。<br>**溜め**：札が縦軸（Y軸）を中心に `0.14s` で90度回転して裏返る瞬間、白い光の筋が縦に走る。<br>**爆発**：残り90度回転して朱色の縦札『あなたのコンビ』がバシッと表を向き（計 `0.28s`）、同時に上部コンビカードの得票数（`4 票` → `5 票`）が `scale(1.35 -> 1.0)` で跳ね、下部の赤い得票ブロックゲージが1マス分ガチャンと埋まる。自分への票なら画面が `3pt` 揺れ、金火花が散る。 | 震え：`.selectionChanged()`<br>開票（自コンビ）：`.impact(.heavy)`<br>開票（敵コンビ）：`.impact(.rigid)` | めくり開始：`SE_VOTE_FLIP`（木札を返す「パシッ！」）：`+0.00s`<br>自コンビ得票：`SE_VOTE_HIT`（太い太鼓「ドン！」＋客席のどよめき）：`+0.25s`<br>王手（3票目）：`SE_VOTE_REACH`（高い拍子木「カン！」追加） |
| **17** | **優勝**<br>（決勝4票目到達の瞬間） | **特大** | `2.20s` | **予告**：4票目（優勝決定票）の審査員札が裏返る瞬間だけ、溜めの震えが `0.22s` に伸び、背景が一瞬暗転。<br>**爆発**：4票目が開いた瞬間、画面全体に金の集中線＋大揺れ（`6pt`）。上部コンビカードが金枠（`yoseKinBright`）に輝き、画面中央に黒漆＋二重金額縁の特大看板『**優 勝**』が `scale(2.5 -> 1.0)` で叩きつけられる。<br>**余韻**：画面上部から**金・朱・白和紙の紙吹雪（計60枚）**が `Canvas` で舞い落ち続け、背後に金の放射後光がゆっくり回転する。 | 4票目着地：`.impact(.heavy)` → `0.12s`後に `.notification(.success)` → `0.25s`後に `.impact(.rigid)` の3段祝포振動 | `SE_CHAMPION_IMPACT`（大太鼓連打「ドドドン！！」＋大歓声＋金管/三味線の優勝ファンファーレ）：`+0.00s` |
| **18** | **年の幕間**<br>（1年の締め→新年開幕） | **特大** | `0.65s`<br>（以降タップ待ち） | **予告/締め**：年末リザルトから進むと、左右から定式幕が `0.22s` で閉まり1年を締める。<br>**爆発/開幕**：`0.18s` 後、定式幕が左右へサッと開き、中央の寄席めくり大札がX軸3D回転（`-85度 -> 0度`、`0.24s`）で『結成 1年目』から『結成 2年目』へパタンとめくれる。直後に右上へ朱印『開幕』が叩きつけられ、引き継ぎ3連木札がせり上がる。 | 幕閉め：`.impact(.rigid)`<br>開幕朱印（`+0.48s`）：`.notification(.success)` | `SE_YEAR_CURTAIN`（定式幕を引く布擦れ音「シャッ」＋拍子木）：`+0.00s`<br>`SE_NEWYEAR_STAMP`（新春太鼓「ドドン！」）：`+0.48s` |
| **19** | **借金の警告**<br>（所持金マイナス転落） | **中** | `0.70s` | **爆発**：所持金が `¥0` 未満になった瞬間、画面四辺に臙脂〜朱色のビネット（赤枠警報）が2回脈動（`0.35s × 2`）し、下部ステータスバー全体が横に `±4pt` ガタガタと揺れる。所持金文字が朱色（`yoseShu`）に変わり、上に『借金状態』の角札が張り付く。 | `.notification(.error)` | `SE_DEBT_WARNING`（低い津軽三味線の不協和音「ベベン…」＋帳場の重い音）：`+0.00s` |

---

## 3. 共通で使う演出部品 8種（そのまま動く SwiftUI 完全コード）

外部画像アセットを一切使わず、`Canvas` + `TimelineView` と SwiftUI 図形のみで **60〜120fps で軽快に動く共通エフェクトライブラリ（`YoseEffects.swift`）** です。
すべての部品は `@Environment(\.accessibilityReduceMotion)` に対応し、パーティクルは構造体配列のインプレース計算でメモリ割り当て（ARC負荷）をゼロに抑えています。

```swift
import SwiftUI
import UIKit

// ============================================================================
// MARK: - 0. 演出マネージャ（Haptics & 効果音フックの一元管理）
// ============================================================================

public enum YoseSoundEffect: String {
    case kifudaTap       = "SE_KIFUDA_TAP"
    case drumDon         = "SE_DRUM_DON"
    case expTick         = "SE_EXP_TICK"
    case hyoshigiSharp   = "SE_HYOSHIGI_SHARP"
    case greatSuccess    = "SE_GREAT_SUCCESS"
    case abilityPlus     = "SE_ABILITY_PLUS"
    case abilityCommit   = "SE_ABILITY_COMMIT"
    case rankupFanfare   = "SE_RANKUP_FANFARE"
    case stampHeavy      = "SE_STAMP_HEAVY"
    case coinChari       = "SE_COIN_CHARI"
    case registerPay     = "SE_REGISTER_PAY"
    case staminaHeal     = "SE_STAMINA_HEAL"
    case fameUp          = "SE_FAME_UP"
    case eventSelect     = "SE_EVENT_SELECT"
    case eventGood       = "SE_EVENT_GOOD"
    case eventBad        = "SE_EVENT_BAD"
    case entryStamp      = "SE_ENTRY_STAMP"
    case debayashiOpen   = "SE_DEBAYASHI_OPEN"
    case laughSmall      = "SE_LAUGH_SMALL"
    case laughMid        = "SE_LAUGH_MID"
    case laughRoar       = "SE_LAUGH_ROAR"
    case rollTaiko       = "SE_ROLL_TAIKO"
    case judgePass       = "SE_JUDGE_PASS"
    case judgeFail       = "SE_JUDGE_FAIL"
    case prizeGet        = "SE_PRIZE_GET"
    case voteFlip        = "SE_VOTE_FLIP"
    case voteHit         = "SE_VOTE_HIT"
    case voteReach       = "SE_VOTE_REACH"
    case championImpact  = "SE_CHAMPION_IMPACT"
    case yearCurtain     = "SE_YEAR_CURTAIN"
    case newYearStamp    = "SE_NEWYEAR_STAMP"
    case debtWarning     = "SE_DEBT_WARNING"
}

public enum YoseFX {
    /// 効果音再生フック（後から AVAudioPlayer / AudioServices を1箇所に繋ぐだけで全画面鳴る）
    public static var onPlaySound: ((YoseSoundEffect) -> Void)?

    public static func sound(_ se: YoseSoundEffect) {
        onPlaySound?(se)
    }

    public static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat = 1.0) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.impactOccurred(intensity: intensity)
    }

    public static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(type)
    }
}

// ============================================================================
// MARK: - 1. 放射パーティクル（YoseBurstParticles）
// 用途：練習結果・能力アップ確定・大成功・判子着地時に四角い金箔/木片/火花が弾ける
// ============================================================================

public struct YoseBurstParticles: View {
    let trigger: Int          // 値が増えるたびに1回バースト発火
    var count: Int = 18       // 粒の数（小:8 / 中:14 / 大:24）
    var colors: [Color] = [YoseColor.kinBright, YoseColor.shu, YoseColor.kin]
    var radius: CGFloat = 90  // 飛び散る最大距離
    var duration: Double = 0.55

    @State private var burstStart: Date? = nil
    @State private var seeds: [ParticleSeed] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct ParticleSeed {
        let angle: Double
        let speedScale: CGFloat
        let size: CGFloat
        let spinSpeed: Double
        let colorIndex: Int
        let isDiamond: Bool
    }

    public init(
        trigger: Int,
        count: Int = 18,
        colors: [Color] = [YoseColor.kinBright, YoseColor.shu, YoseColor.kin],
        radius: CGFloat = 90,
        duration: Double = 0.55
    ) {
        self.trigger = trigger
        self.count = count
        self.colors = colors
        self.radius = radius
        self.duration = duration
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: burstStart == nil)) { timeline in
            Canvas { context, size in
                guard let start = burstStart else { return }
                let elapsed = timeline.date.timeIntervalSince(start)
                guard elapsed >= 0, elapsed < duration else { return }

                let progress = elapsed / duration
                // 初速が速く、後半ピタッと減速するイージング (1 - (1-t)^3)
                let eased = 1.0 - pow(1.0 - progress, 3.0)
                let alpha = max(0, 1.0 - pow(progress, 1.8))
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                for seed in seeds {
                    let dist = radius * seed.speedScale * CGFloat(eased)
                    let gravityY = CGFloat(progress * progress) * 24.0 // わずかな重力落下
                    let x = center.x + CGFloat(cos(seed.angle)) * dist
                    let y = center.y + CGFloat(sin(seed.angle)) * dist + gravityY

                    var pContext = context
                    pContext.opacity = alpha
                    pContext.translateBy(x: x, y: y)
                    pContext.rotate(by: .degrees(seed.spinSpeed * elapsed))

                    let rect = CGRect(
                        x: -seed.size / 2,
                        y: -seed.size / 2,
                        width: seed.size,
                        height: seed.isDiamond ? seed.size : seed.size * 0.65
                    )
                    let color = colors[seed.colorIndex % max(1, colors.count)]
                    pContext.fill(Path(rect), with: .color(color))
                    pContext.stroke(Path(rect), with: .color(YoseColor.sumi), lineWidth: 1)
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _ in
            guard !reduceMotion else { return }
            regenerateSeeds()
            burstStart = Date()
        }
    }

    private func regenerateSeeds() {
        seeds = (0..<count).map { i in
            let baseAngle = (Double(i) / Double(max(1, count))) * (.pi * 2.0)
            let jitter = Double.random(in: -0.22...0.22)
            return ParticleSeed(
                angle: baseAngle + jitter,
                speedScale: CGFloat.random(in: 0.45...1.05),
                size: CGFloat.random(in: 6...11),
                spinSpeed: Double.random(in: -360...360),
                colorIndex: i,
                isDiamond: i.isMultiple(of: 2)
            )
        }
    }
}

// ============================================================================
// MARK: - 2. 数値の跳ね＋発光（YoseNumberPopModifier）
// 用途：実力・能力値・所持金・得票数が変わった瞬間に跳ねて光る計器モディファイア
// ============================================================================

public struct YoseNumberPopModifier<V: Equatable>: ViewModifier {
    let value: V
    var highlightColor: Color = YoseColor.kinBright
    var scalePeak: CGFloat = 1.24

    @State private var isPopping: Bool = false

    public func body(content: Content) -> some View {
        content
            .scaleEffect(isPopping ? scalePeak : 1.0)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(highlightColor.opacity(isPopping ? 0.38 : 0.0))
                    .padding(.horizontal, -4)
                    .padding(.vertical, -2)
            )
            .animation(.spring(response: 0.24, dampingFraction: 0.62), value: isPopping)
            .onChange(of: value) { _ in
                isPopping = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                    isPopping = false
                }
            }
    }
}

public extension View {
    func yoseNumberPop<V: Equatable>(
        value: V,
        highlightColor: Color = YoseColor.kinBright,
        scalePeak: CGFloat = 1.24
    ) -> some View {
        modifier(YoseNumberPopModifier(value: value, highlightColor: highlightColor, scalePeak: scalePeak))
    }
}

// ============================================================================
// MARK: - 3. 画面揺れ（YoseScreenShakeModifier）
// 用途：判子着地・大ウケ・開票・優勝時に物理的な減衰振動（縦揺れ／横揺れ）を与える
// ============================================================================

public enum YoseShakeIntensity {
    case small   // 2pt（中イベント・小判子）
    case medium  // 4pt（突破判子・大成功・開票）
    case heavy   // 6pt（優勝決定・特大衝撃）

    var amplitude: CGFloat {
        switch self {
        case .small:  return 2.0
        case .medium: return 4.0
        case .heavy:  return 6.5
        }
    }
}

public struct YoseScreenShakeModifier: ViewModifier {
    let trigger: Int
    var intensity: YoseShakeIntensity = .medium
    var axis: Axis = .vertical

    @State private var offset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public func body(content: Content) -> some View {
        content
            .offset(
                x: axis == .horizontal ? offset : 0,
                y: axis == .vertical ? offset : 0
            )
            .onChange(of: trigger) { _ in
                guard !reduceMotion else { return }
                let amp = intensity.amplitude
                Task { @MainActor in
                    let steps: [CGFloat] = [amp, -amp * 0.75, amp * 0.45, -amp * 0.2, 0]
                    for step in steps {
                        withAnimation(.linear(duration: 0.038)) {
                            offset = step
                        }
                        try? await Task.sleep(nanoseconds: 38_000_000)
                    }
                }
            }
    }
}

public extension View {
    func yoseShake(trigger: Int, intensity: YoseShakeIntensity = .medium, axis: Axis = .vertical) -> some View {
        modifier(YoseScreenShakeModifier(trigger: trigger, intensity: intensity, axis: axis))
    }
}

// ============================================================================
// MARK: - 4. 光の筋・斜光シマー（YoseLightStreakModifier）
// 用途：能力アップ確定時・勝負ネタ登録時・開票カードに「キラーン」と走る金の斜め光
// ============================================================================

public struct YoseLightStreakModifier: ViewModifier {
    let trigger: Int
    var streakColor: Color = YoseColor.kinBright
    var duration: Double = 0.36

    @State private var phase: CGFloat = -1.2
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    Rectangle()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: streakColor.opacity(0.65), location: 0.42),
                                    .init(color: Color.white.opacity(0.90), location: 0.50),
                                    .init(color: streakColor.opacity(0.65), location: 0.58),
                                    .init(color: .clear, location: 1.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(60, w * 0.45), height: h * 2.2)
                        .rotationEffect(.degrees(24))
                        .offset(x: phase * (w + 140), y: -h * 0.5)
                }
                .clipped()
                .allowsHitTesting(false)
            }
            .onChange(of: trigger) { _ in
                guard !reduceMotion else { return }
                phase = -0.8
                withAnimation(.easeOut(duration: duration)) {
                    phase = 1.35
                }
            }
    }
}

public extension View {
    func yoseLightStreak(trigger: Int, color: Color = YoseColor.kinBright) -> some View {
        modifier(YoseLightStreakModifier(trigger: trigger, streakColor: color))
    }
}

// ============================================================================
// MARK: - 5. 金・朱・白和紙の紙吹雪（YoseConfettiView）
// 用途：優勝・Sランク到達時に画面上部から舞い落ちる和紙吹雪（Canvas 60fps 描画）
// ============================================================================

public struct YoseConfettiView: View {
    var isActive: Bool = true
    var pieceCount: Int = 56

    @State private var startDate = Date()
    @State private var pieces: [ConfettiPiece] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct ConfettiPiece {
        let initialXRatio: CGFloat
        let initialYOffset: CGFloat
        let fallSpeed: CGFloat
        let swayAmp: CGFloat
        let swayFreq: Double
        let spinSpeed: Double
        let width: CGFloat
        let height: CGFloat
        let color: Color
    }

    public init(isActive: Bool = true, pieceCount: Int = 56) {
        self.isActive = isActive
        self.pieceCount = pieceCount
    }

    public var body: some View {
        Group {
            if isActive && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    Canvas { context, size in
                        let elapsed = timeline.date.timeIntervalSince(startDate)
                        let totalH = size.height + 80

                        for piece in pieces {
                            let rawY = piece.initialYOffset + CGFloat(elapsed) * piece.fallSpeed
                            let y = rawY.truncatingRemainder(dividingBy: totalH) - 40
                            let sway = sin(elapsed * piece.swayFreq + Double(piece.initialXRatio * 10)) * Double(piece.swayAmp)
                            let x = piece.initialXRatio * size.width + CGFloat(sway)

                            // 3Dヒラヒラ回転を cos スケールで擬似表現
                            let flipScale = max(0.2, abs(cos(elapsed * piece.spinSpeed)))

                            var c = context
                            c.translateBy(x: x, y: y)
                            c.rotate(by: .degrees(sin(elapsed * 2.0) * 25))
                            c.scaleBy(x: 1.0, y: CGFloat(flipScale))

                            let rect = CGRect(
                                x: -piece.width / 2,
                                y: -piece.height / 2,
                                width: piece.width,
                                height: piece.height
                            )
                            c.fill(Path(rect), with: .color(piece.color))
                            c.stroke(Path(rect), with: .color(YoseColor.sumi.opacity(0.65)), lineWidth: 0.8)
                        }
                    }
                }
                .onAppear {
                    startDate = Date()
                    if pieces.isEmpty {
                        let palette: [Color] = [
                            YoseColor.kinBright,
                            YoseColor.kin,
                            YoseColor.shu,
                            YoseColor.washi
                        ]
                        pieces = (0..<pieceCount).map { i in
                            ConfettiPiece(
                                initialXRatio: CGFloat.random(in: 0.02...0.98),
                                initialYOffset: CGFloat.random(in: 0...850),
                                fallSpeed: CGFloat.random(in: 110...210),
                                swayAmp: CGFloat.random(in: 14...34),
                                swayFreq: Double.random(in: 1.8...3.6),
                                spinSpeed: Double.random(in: 3.0...6.5),
                                width: CGFloat.random(in: 8...14),
                                height: CGFloat.random(in: 5...9),
                                color: palette[i % palette.count]
                            )
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// ============================================================================
// MARK: - 6. 判子叩きつけ＋朱肉しぶき（YoseAnimatedHanko）
// 用途：「突破」「秀」「昇格」「真剣勝負」を溜めから一気に叩きつける演出付き朱印
// ============================================================================

public struct YoseAnimatedHanko: View {
    let text: String
    let isStamped: Bool
    var isSquare: Bool = false
    var angle: Double = -6
    var playHapticsAndSound: Bool = true

    @State private var burstTrigger: Int = 0

    public init(
        text: String,
        isStamped: Bool,
        isSquare: Bool = false,
        angle: Double = -6,
        playHapticsAndSound: Bool = true
    ) {
        self.text = text
        self.isStamped = isStamped
        self.isSquare = isSquare
        self.angle = angle
        self.playHapticsAndSound = playHapticsAndSound
    }

    public var body: some View {
        ZStack {
            // 着地瞬間の朱肉・金粉しぶき
            YoseBurstParticles(
                trigger: burstTrigger,
                count: 10,
                colors: [YoseColor.shu, YoseColor.kinBright],
                radius: 44,
                duration: 0.38
            )
            .frame(width: 90, height: 90)

            YoseHankoStamp(text: text, isSquare: isSquare, angle: angle)
                .scaleEffect(isStamped ? 1.0 : 2.35)
                .opacity(isStamped ? 1.0 : 0.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.54), value: isStamped)
        }
        .onChange(of: isStamped) { stamped in
            if stamped {
                burstTrigger += 1
                if playHapticsAndSound {
                    YoseFX.notify(.success)
                    YoseFX.sound(.stampHeavy)
                }
            }
        }
    }
}

// ============================================================================
// MARK: - 7. 斜めカットイン帯（YoseCutInBanner）
// 用途：『手応え抜群！ハマった！！』『どっと沸いた！！』『4票獲得・優勝決定！』
// ============================================================================

public struct YoseCutInBanner: View {
    let title: String
    var subtitle: String? = nil
    var stampText: String? = "大成功"
    let isPresented: Bool

    @State private var stampReady: Bool = false

    public init(
        title: String,
        subtitle: String? = nil,
        stampText: String? = "大成功",
        isPresented: Bool
    ) {
        self.title = title
        self.subtitle = subtitle
        self.stampText = stampText
        self.isPresented = isPresented
    }

    public var body: some View {
        ZStack {
            if isPresented {
                // 黒漆＋上下二重金線の斜め帯
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        if let subtitle {
                            Text(subtitle)
                                .font(YoseFont.gothic(12, weight: .heavy))
                                .foregroundStyle(YoseColor.kin)
                        }
                        YoseOutlinedText(
                            text: title,
                            font: YoseFont.mincho(24),
                            fill: YoseColor.kinari,
                            outlineColor: YoseColor.kuroUrushi,
                            outlineWidth: 1.5,
                            dropShadowY: 2
                        )
                    }
                    Spacer(minLength: 4)
                    if let stampText {
                        YoseAnimatedHanko(
                            text: stampText,
                            isStamped: stampReady,
                            isSquare: false,
                            angle: -8
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    ZStack {
                        YoseColor.kuroUrushi
                        // 背後の朱斜めストライプ
                        HStack(spacing: 18) {
                            ForEach(0..<8, id: \.self) { _ in
                                Rectangle()
                                    .fill(YoseColor.enji.opacity(0.55))
                                    .frame(width: 14)
                                    .rotationEffect(.degrees(20))
                            }
                        }
                    }
                )
                .overlay(alignment: .top) {
                    VStack(spacing: 1.5) {
                        Rectangle().fill(YoseColor.sumi).frame(height: 2)
                        Rectangle().fill(YoseColor.kinBright).frame(height: 2)
                    }
                }
                .overlay(alignment: .bottom) {
                    VStack(spacing: 1.5) {
                        Rectangle().fill(YoseColor.kinBright).frame(height: 2)
                        Rectangle().fill(YoseColor.sumi).frame(height: 2)
                    }
                }
                .rotationEffect(.degrees(-4))
                .shadow(color: YoseColor.sumi, radius: 0, x: 0, y: 4)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    )
                )
                .onAppear {
                    stampReady = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                        stampReady = true
                    }
                }
            }
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.76), value: isPresented)
        .allowsHitTesting(false)
    }
}

// ============================================================================
// MARK: - 8. 集中線（YoseSpeedLinesView）
// 用途：大成功・大ウケ・突破・優勝決定の瞬間に画面外周へ出る劇画調の集中線
// ============================================================================

public struct YoseSpeedLinesView: View {
    var lineCount: Int = 36
    var color: Color = YoseColor.kinBright.opacity(0.45)
    var innerClearRadiusRatio: CGFloat = 0.34 // 中央の文字・キャラを邪魔しない空洞比率

    public init(
        lineCount: Int = 36,
        color: Color = YoseColor.kinBright.opacity(0.45),
        innerClearRadiusRatio: CGFloat = 0.34
    ) {
        self.lineCount = lineCount
        self.color = color
        self.innerClearRadiusRatio = innerClearRadiusRatio
    }

    public var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outerR = hypot(size.width, size.height) * 0.65
            let baseInnerR = min(size.width, size.height) * innerClearRadiusRatio

            for i in 0..<lineCount {
                let angle = (Double(i) / Double(lineCount)) * (.pi * 2.0)
                // 規則的すぎないよう周期関数で内径と太さに抑揚をつける
                let innerJitter = CGFloat(sin(Double(i) * 1.7) * 18.0 + cos(Double(i) * 3.1) * 10.0)
                let r1 = baseInnerR + innerJitter
                let halfSpread = 0.008 + abs(sin(Double(i) * 2.3)) * 0.012

                var wedge = Path()
                wedge.move(to: CGPoint(
                    x: center.x + CGFloat(cos(angle)) * r1,
                    y: center.y + CGFloat(sin(angle)) * r1
                ))
                wedge.addLine(to: CGPoint(
                    x: center.x + CGFloat(cos(angle - halfSpread)) * outerR,
                    y: center.y + CGFloat(sin(angle - halfSpread)) * outerR
                ))
                wedge.addLine(to: CGPoint(
                    x: center.x + CGFloat(cos(angle + halfSpread)) * outerR,
                    y: center.y + CGFloat(sin(angle + halfSpread)) * outerR
                ))
                wedge.closeSubpath()

                context.fill(wedge, with: .color(color))
            }
        }
        .allowsHitTesting(false)
    }
}
```

---

## 4. 『やりすぎ』の歯止め（頻度・重ね方・早送りの鉄則）

エフェクトを増やしたゲームが陥る最大の失敗は「画面がチカチカして目が疲れ、周回プレイが苦痛になること」です。以下の4つの歯止めをコードレベルで強制します。

### 4-1. 同時発火の上限（重ね方の制限）
1. **「全画面エフェクト（集中線・紙吹雪・暗転）」は同時に1つまで**：
   * 例：「ランクアップ」と「大成功カットイン」が同じターンで起きた場合、重ねて出さず、`大成功カットイン（0.8s） → ランクアップ貼り紙（1.45s）` と順番に出すか、または複数能力の昇格を1枚の貼り紙の「同時昇格ストリップ」に統合する。
2. **「画面揺れ（`yoseShake`）」は1アクションにつき最大1回（`0.18秒`以内）**：
   * 連続で画面を揺らし続けると画面酔いを起こす。審査員札の開票でも、揺れるのは「自分のコンビに票が入った着地瞬間」の1回だけにする。
3. **中央の可読領域（`innerClearRadiusRatio: 0.34`）を死守する**：
   * 集中線やパーティクルは必ず「カードの外周」または「数字の背後」で弾けさせ、明朝体のセリフ・審査講評・数値の上に不透明なエフェクトを被せない。

### 4-2. 頻度による自動ダイエット（何百回見ても疲れない仕組み）
* **毎週起きる行動（練習・バイト・休む）**：
  * 全画面カットインやモーダルは**一切出さない**。週メイン画面の数値バウンス（`0.28s`）と小パーティクル（`0.45s`）だけで完結させ、プレイヤーが1秒間に2回コマンドを叩けるテンポを維持する。
* **能力アップの `[+]` 連打**：
  * `[+]` を押すたびにモーダルや重い演出を出さない。`[+]` は「行が金に光って数字が跳ねる（`0.24s`）」だけにし、最後に「確定」を押した時だけまとめて昇格演出を1回出す。

### 4-3. 早送り・1タップ即完了の統一仕様（`Skip / Fast-Forward`）
すべての演出（中・大・特大）は以下の**「2段階タップ制御」**を共通ルールにします。

1. **演出の途中（アニメーション進行中）に画面のどこかをタップした場合**：
   * アニメーションを中断して消すのではなく、**`0.06秒` で即座に「最終到達フレーム（すべての判子が押され、すべての数値が上がりきった状態）」を画面にパッと完成表示**する。
   * 例：決勝の開票（`42_決勝演出_一騎打ち.png`）で、審査員札の回転中にタップしたら即座にその札が開き、さらに画面右上の「一括開票 ▶▶」またはダブルタップで残り審査員札を0.08秒間隔の高速連打で一気にめくり切る。
2. **最終到達フレームが表示されている状態でタップした場合**：
   * `0.12秒` で即座に閉じて次の画面・次の週へ進む。

---

## 5. 実装の優先順（最小工数で劇的に楽しくなる順 TOP 10）

今ある実機画面（`04_週メイン`〜`42_決勝演出`）に対して、**「実装コストが低く、かつプレイヤーが触った瞬間に『別のゲームみたいに気持ちよくなった！』と感じる順番」**で並べた実装ロードマップです。

| 順位 | 実装項目 | 対象画面 / ファイル | なぜ最優先か（効き目の理由） |
| :-: | :--- | :--- | :--- |
| **1位** | **全ボタンの物理沈み込み＋`rigid` Haptics＋木札SEフック** | 全画面共通<br>（`YoseButtonStyle` / `YoseFX`） | プレイヤーが1周で1,000回以上触る部分。押した瞬間に `+3pt` 沈んで下影が消え、コツンと振動するだけで、すべての画面が一瞬で「Webアプリ」から「ゲーム機」の手触りに変わる。 |
| **2位** | **数値の跳ね＋金発光（`.yoseNumberPop`）の一括適用** | `04_週メイン` / `13_能力アップ` / `35_予選結果`<br>（実力・能力値・所持金・得票数） | パワプロの中毒性の核。数字が増える瞬間に `scale(1.24 -> 1.0)` で跳ねて背景が一瞬山吹金に光るだけで、数字を上げる快感が3倍になる。 |
| **3位** | **能力アップ画面：`[+]` 押下時の行フラッシュと「確定」時の斜光シマー（`.yoseLightStreak`）** | `13_能力アップ_＋押下後.png` | 育成ゲームで一番楽しい「経験点を使って強くする画面」。`[+]` を押すたびに行が光り、「確定」で全上昇行にキラーンと金の光の筋が走るだけで脳汁が出る。 |
| **4位** | **判子叩きつけ＋朱肉しぶき＋画面微振動（`YoseAnimatedHanko` + `.yoseShake`）** | `35_予選結果`（『突破』『秀』）<br>ネタ帳（『真剣勝負』） | 今の結果画面は判子が最初から静止して貼られている。『突破』『秀』が2.3倍サイズから叩きつけられ、画面が縦に `4pt` 揺れるだけで、予選通過のカタルシスが劇的に跳ね上がる。 |
| **5位** | **決勝の開票：審査員札の震え → 3D縦反転 → 得票バウンス** | `42_決勝演出_一騎打ち.png` | ゲーム最大の山場。『封』の札がカタカタ震えてからパシッと裏返り、上の得票数『5票』が跳ねて画面が揺れるだけで、M-1最終決戦の緊張感と興奮が完成する。 |
| **6位** | **決勝4票目到達〜「優勝」決定時の金紙吹雪＋集中線（`YoseConfettiView` + `YoseSpeedLinesView`）** | `35_予選結果`（優勝時）<br>`42_決勝演出_一騎打ち.png` | 優勝した瞬間に金の集中線と60枚の和紙吹雪が舞うことで、「1年間育ててよかった！」という最高のご褒美画面になる。 |
| **7位** | **能力ランクアップ演出（`YoseRankUpOverlay`）の接続** | `13_能力アップ` 確定後<br>`04_週メイン` 練習後 | `F → E → D…` と段階が上がった瞬間に番付昇格の貼り紙と角火花が出ることで、中盤の中だるみが消え「次のランクまであと少し」という目標が明確になる。 |
| **8位** | **練習結果の経験点バースト＋「ハマった！（大成功）」斜めカットイン帯（`YoseCutInBanner`）** | `04_週メイン.png`<br>`05_練習選び.png` | 毎週の練習に「たまに大当たりが出る気持ちよさ（ランダム報酬の快感）」が加わり、練習ボタンを押す期待感が跳ね上がる。 |
| **9位** | **年の幕間（定式幕ワイプ＋年号めくり大札の3D反転：`YoseYearTurnCurtainView`）** | 年末リザルト → 翌年第1週 | 1年の終わりと新年の始まりに定式幕が閉じて開き、めくり札が『2年目』へパタンと返ることで、複数年プレイのドラマ性が一気に締まる。 |
| **10位** | **体力ゲージの朱色残像＆お金の `+¥万 / -¥万` フローティング小札** | 全画面下部<br>（`YoseVitalMoneyBar`） | 練習で体力がどれだけ減ったか、バイトや賞金でいくら増えたかが視線を動かさずに直感で伝わるようになり、計器としての完成度が極まる。 |
