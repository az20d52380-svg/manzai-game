# 決勝敗北時の優勝者選出データ表 v0 —— champion selection（実装可能形）

- 日付: 2026-07-04
- 位置づけ: `finals_direction_v0.md` §4-D「決勝敗北時の優勝者指名」の選出ロジックを、CLI 実装がそのまま落とせる**データ表＋決定規則＋擬似コード**にしたもの。
- 大原則の再掲（`rival_design_v0.md` §0）: 判定は絶対ライン方式のまま。**表示上の勝者だけ**を選ぶ。判定ロジック変更ゼロ。ライバルとは「並ぶが、戦わない」。
- 参照: `rival_design_v0.md` §0/§1、`finals_direction_v0.md` §4-C.5 / §4-D、モブ名プール＝`content_batch5_v0.md` §2（50組・index 0-49で凍結が正典）。
- 数値は全て【仮】。固有名は全て架空。実在コンビ・実在人物・実在SNSを想起させる名前は禁止（判定基準 `judge_design_v0.md` §10-D）。
- 【プール一本化・2026-07-05】モブ名は `content_batch5_v0.md` §2 の**50組が唯一の正典**。別案の独立30組プールは作らない（重複回避）。

---

## 0. この表が答えるもの

プレイヤーが**決勝で敗れた年**（内部スコア < 決勝ライン）に、その年（プレイヤー基準の 1〜10 年目）の:

1. **優勝者**（TOP3 の 1 枠・実名指名）
2. **TOP3 の残り 2 枠**（優勝者を除いた 2 組）

を、**周回で不変（＝リプレイ安定）**に確定する。谷の年（年表に優勝該当なし）と勇退済みの組はモブ名プールで埋める。

> 注: ここでの「年」は**プレイヤーの経過年**（1〜10 年目）＝ライバル年表の年と同一軸で扱う（`rival_design_v0.md` §2「プレイヤー成績はライバル年表に干渉しない」前提。周回±1年の揺らぎは §5-2 で扱う）。

---

## 1. 正規化年表（グランプリ決勝の顔ぶれに限定）

`rival_design_v0.md` §1 の 4 組×10 年から、**グランプリ決勝の表示候補になり得る状態だけ**を抽出。「優勝」は各年 1 組までに正規化（§4-D.1）。

| 年 | 金字塔 | 夜行列車 | ミラーボール兄弟 | 静物画 |
|---|---|---|---|---|
| 1 | 2回戦 | 準決 | 3回戦 | 準決 |
| 2 | 準々 | 準々 | 準決＋バズ | 準決 |
| 3 | 準決 | **準決→敗者復活散（資格ラスト）** | 賞レース欠場 | 準決 |
| 4 | **決勝(敗退)** | ベテラン大会へ移籍(卒業) | 2回戦落ち | 準決 |
| 5 | **決勝(敗退)** | 〃 | 2回戦落ち | 準決 |
| 6 | **優勝・勇退** | 〃 | 単独ライブ(劇場復帰) | 準決 |
| 7 | 勇退済(審査/TV) | 〃 | **決勝(返り咲き)** | 準決 |
| 8 | 勇退済 | 〃 | ── | 準決 |
| 9 | 勇退済 | 〃 | ── | **決勝(初)** |
| 10 | 勇退済 | 〃 | ── | **決勝(資格ラスト・周回変動)** |

太字 = 決勝以上（＝優勝者 or TOP3 他枠の**rival 候補**になる状態）。

**この表から導かれる、決勝表示候補になる年:**
- 金字塔: 4・5（決勝敗退＝TOP3他枠候補）／ 6（優勝）。7年目以降は**勇退済み＝表示候補から除外**。
- 夜行列車: グランプリ決勝には**一度も到達しない**（1準決/2準々/3準決→敗者復活散）。4年目以降は**ベテラン大会ルートへ卒業＝グランプリの選出プールから恒久除外**。→ champion / TOP3 いずれにも登場しない。
- ミラーボール兄弟: 7（返り咲き＝決勝＝TOP3他枠候補）のみ。優勝はしない。
- 静物画: 9（初決勝＝TOP3他枠候補）／ 10（決勝・**周回により優勝する分岐あり**）。

---

## 2. 年別 優勝者＆TOP3 選出データ表（マスタ）

決定的テーブル。CLI はこの表を引くだけで champion と TOP3 他 2 枠を確定できる。`mob(n)` = モブ名プールから疑似乱数で n 組（§4 の擬似コード）。

| 年 | 優勝者 | 谷の年? | TOP3 他2枠：rival候補 | モブ補充 | 勇退/卒業による除外 | 優勝時の固有1行 |
|---|---|---|---|---|---|---|
| 1 | `mob` | ✅ | ── | mob(2) | ─ | 汎用 |
| 2 | `mob` | ✅ | ── | mob(2) | ─ | 汎用 |
| 3 | `mob` | ✅ | ── | mob(2) | ─ | 汎用 |
| 4 | `mob` | ✅ | 金字塔 | mob(1) | ─ | 汎用 |
| 5 | `mob` | ✅ | 金字塔 | mob(1) | ─ | 汎用 |
| 6 | **金字塔** | ─ | ── | mob(2) | ─（本年で優勝→翌年勇退） | 「同期が、先に行った。」 |
| 7 | `mob` | ✅ | ミラーボール兄弟 | mob(1) | 金字塔=勇退済で除外 | 汎用 |
| 8 | `mob` | ✅ | ── | mob(2) | 金字塔=勇退済 | 汎用 |
| 9 | `mob` | ✅ | 静物画 | mob(1) | 金字塔=勇退済 | 汎用 |
| 10 | **静物画**〔勝ち周回〕/ `mob`〔負け周回〕 | 分岐 | 〔勝ち周回〕── ／〔負け周回〕静物画 | 〔勝ち〕mob(2) ／〔負け〕mob(1) | 金字塔=勇退済 | 静物画:「あの静物画が、ついに。8年分の準決勝を、今夜ぜんぶ回収した」 |

**優勝時の固有1行**（`finals_direction_v0.md` §4-D の指名演出・名鑑格納分）:
- 金字塔:「同期が、先に行った。」
- ミラーボール兄弟:「一度死んだ男らが、帰ってきて獲った。」（※本表では優勝者にならないが、将来の年表改訂で優勝周回を持つ場合に備え格納）
- 静物画:「あの静物画が、ついに。8年分の準決勝を、今夜ぜんぶ回収した」
- 夜行列車 / モブ 汎用:「今年の主役は、隣の楽屋の二人やった」

> 【設計上の懸念・要オーナー確認】`finals_direction_v0.md` §4-D.1 の例示は「金字塔6年目・ミラーボール7年目・静物画9〜10年目の優勝周回」と書くが、`rival_design_v0.md` §1 の年表本文で明示的に「優勝」なのは **金字塔6年目** と **静物画10年目（周回条件付き）** のみ。ミラーボール7年目＝「決勝(返り咲き)」、静物画9年目＝「初の決勝」であり、いずれも優勝表記ではない。本表は**一次ソースである rival_design §1 の年表本文に忠実**に「優勝」を金字塔6・静物画10(分岐)のみとし、§4-D の括弧内例示は「決勝表示候補の例」と読み替えて TOP3 他枠へ回した。§4-D 例示どおりミラーボール7年目/静物画9年目も優勝扱いにしたい場合は年表側の改訂が必要（後戻り困難なため明記）。

---

## 3. 静物画10年目の優勝分岐（config・要バランス確定）

`rival_design_v0.md` §4-未決2「静物画10年目の結果分岐率」は未確定。ここでは config 化し、周回で不変な疑似乱数で決める。

```
GameConfig.champion.shizubutsugaY10WinRate = 0.35   // 【仮】0.0〜1.0
```

- `runSeed` から決定的に「勝ち周回 / 負け周回」を確定（§4 `shizubutsugaWinsY10`）。同一周回では常に同じ結果＝リプレイ安定。
- 勝ち周回: 優勝者 = 静物画、TOP3 他 2 枠 = mob(2)。
- 負け周回: 優勝者 = mob（谷の年扱い）、TOP3 他枠 = 静物画 ＋ mob(1)。
- 演出補足（`rival_design_v0.md` §4-未決2）: プレイヤーの初優勝と静物画優勝が同年（＝プレイヤーが 10 年目で勝った年）に重なる場合、プレイヤー優勝が優先され本ロジックは呼ばれない（この表は**敗北年のみ**発火）。

---

## 4. モブ選出＆組み立て 擬似コード（決定的・リプレイ安定）

### 4-1. 決定的ハッシュ（プラットフォーム間で同一値を保証）

splitmix64 系。整数演算のみで浮動小数を使わない（機種依存回避）。オーバーフロー乗算（Swift の `&*` / `&+`）を用いる。

```swift
// 周回シード × 年 × 用途salt → 64bit 決定値
func champHash(_ runSeed: UInt64, _ year: Int, _ salt: UInt64) -> UInt64 {
    var x = runSeed &+ 0x9E3779B97F4A7C15
    x ^= (UInt64(bitPattern: Int64(year)) &* 0xBF58476D1CE4E5B9)
    x ^= (salt &* 0x94D049BB133111EB)
    x = (x ^ (x >> 30)) &* 0xBF58476D1CE4E5B9   // splitmix64 finalizer
    x = (x ^ (x >> 27)) &* 0x94D049BB133111EB
    return x ^ (x >> 31)
}

enum Salt {                       // 用途ごとに固定値（衝突回避）
    static let shizuY10: UInt64 = 0x5A17_0000_0000_0001
    static let mobDraw:  UInt64 = 0x5A17_0000_0000_0002
}
```

### 4-2. 静物画10年目 分岐

```swift
func shizubutsugaWinsY10(_ runSeed: UInt64, _ cfg: GameConfig) -> Bool {
    let h = champHash(runSeed, 10, Salt.shizuY10)
    // 0..9999 の整数域で判定（浮動小数比較を避ける）
    return Int(h % 10_000) < Int(cfg.shizubutsugaY10WinRate * 10_000)
}
```

### 4-3. モブを重複なく k 組引く（谷の年・補充共用）

同一 `year` 内では 1 本の連番系列から**非復元抽出**し、champion 用と TOP3 補充用が絶対に被らないようにする。

```swift
// MOB_POOL: §5 の 50 組（index 0..49 で固定）
// exclude: プレイヤーのコンビ名＋その年に既に確定した rival 名（重複表示防止）
func drawMobs(_ runSeed: UInt64, year: Int, count k: Int,
              exclude: Set<String>, poolFilter: (Int) -> Bool) -> [String] {
    var pool = (0..<MOB_POOL.count)
        .filter { poolFilter($0) && !exclude.contains(MOB_POOL[$0]) }
    var out: [String] = []
    for i in 0..<k {
        precondition(!pool.isEmpty, "mob pool exhausted")
        let h = champHash(runSeed, year, Salt.mobDraw &+ UInt64(i))
        let pick = Int(h % UInt64(pool.count))   // 非復元: 残プールから選ぶ
        out.append(MOB_POOL[pool[pick]])
        pool.remove(at: pick)
    }
    return out
}
```

### 4-4. 年ぶんの決勝キャストを組み立てる（トップレベル）

`FinalsCast` = (champion: 表示名, championFlavor: 1行, top3Others: [表示名] 2組)。

```swift
struct FinalsCast { let champion: String; let flavor: String; let top3Others: [String] }

func buildFinalsCast(year: Int, runSeed: UInt64,
                     playerName: String, cfg: GameConfig) -> FinalsCast {
    var reservedRivals: [String] = []           // その年に確定した rival 表示名
    var champion: String
    var flavor: String

    // --- (1) 年表の優勝組（勇退/卒業を除外済みのマスタ表を引く） ---
    switch year {
    case 6:
        champion = "金字塔"; flavor = FLAVOR["金字塔"]!          // 決定的
    case 10 where shizubutsugaWinsY10(runSeed, cfg):
        champion = "静物画"; flavor = FLAVOR["静物画"]!          // 勝ち周回
    default:
        champion = ""; flavor = FLAVOR["_generic"]!             // 谷の年 → 後でモブ
    }

    // --- (2) TOP3 他2枠の rival 候補（マスタ表・勇退/卒業除外済み） ---
    switch year {
    case 4, 5:            reservedRivals = ["金字塔"]
    case 7:               reservedRivals = ["ミラーボール兄弟"]
    case 9:               reservedRivals = ["静物画"]
    case 10 where !shizubutsugaWinsY10(runSeed, cfg):
                          reservedRivals = ["静物画"]           // 負け周回のみ
    default:              reservedRivals = []
    }

    // --- (3)+(4) champion（谷の年のみ）と TOP3 補充モブを「1回の非復元抽選」で確定 ---
    //     二度引きによる重複リスクを構造的に排除する推奨実装: 必要総数を drawMobs で
    //     一度に引き、谷の年は先頭を champion、残りを TOP3 補充へ割る。同一 drawMobs
    //     呼び出し内は非復元なので、champion と補充が被ることは原理的に起きない。
    let needMobChamp = champion.isEmpty         // 谷の年だけ champion 用に先頭 1 組を使う
    let needFill = 2 - reservedRivals.count      // TOP3 の残り枠
    let mobs = drawMobs(runSeed, year: year,
                        count: (needMobChamp ? 1 : 0) + needFill,
                        exclude: Set([playerName] + reservedRivals),
                        // 先頭を champion に割る谷の年は全体を CHAMP_ELIGIBLE で引く（補充も
                        // CHAMP_ELIGIBLE 内＝19/42 が落ちるが無害）。champion が rival で確定済みの
                        // 年は補充のみなので全プール可。
                        poolFilter: { needMobChamp ? CHAMP_ELIGIBLE.contains($0) : true })
    if needMobChamp {
        champion = mobs[0]                       // 谷の年: 先頭を champion（flavor は既に _generic）
    }
    let fill = Array(mobs.suffix(needFill))      // 残りを TOP3 補充へ
    let top3Others = reservedRivals + fill
    return FinalsCast(champion: champion, flavor: flavor, top3Others: top3Others)
}
```

> 実装上の要点: **champion モブと TOP3 補充モブの非重複**は、上記 (3)+(4) のとおり「その年に必要なモブ総数（谷の年なら 1+2=3、rival 優勝周回なら 0+2=2）を **drawMobs で一度に引き**、先頭を champion、残りを fill に割る」単一の非復元抽選で構造的に保証する（同一呼び出し内で同じ index を二度引かない）。二度に分けて引く旧案は連番 `i` を跨いで共有しないと事故るため、本書は単一抽選を正典とする。

---

## 5. モブ名プール（`content_batch5_v0.md` §2 の50組・index 0-49固定・実装参照用ミラー）

CLI が同一 index で参照できるよう順序を固定（0〜49）。**この配列順を変更したら周回再現性が壊れる**（config と同格に凍結）。

> **出典の正典は `content_batch5_v0.md` §2**。下表はCLI実装が同一indexで引くための転記ミラー。§2を変更したら本表も同期すること（片方だけ変更禁止）。本バッチで別途生成された30組案(mob_names)は正典化せず**不採用**（§2の50組で §4-C.5/§4-D の要件は充足済み）。

| idx | 名 | idx | 名 | idx | 名 | idx | 名 | idx | 名 |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 深夜のグラタン | 10 | 終電間際 | 20 | 二段ベッド | 30 | 冬眠明け | 40 | 満場一致 |
| 1 | 缶コーヒー兄弟 | 11 | 午前四時 | 21 | 延長コード | 31 | ハシビロコウ帝国 | 41 | 両想い未遂 |
| 2 | みそしるず | 12 | 踏切戦線 | 22 | ドライバーセット | 32 | ちくわ犬 | 42 | 敗者復活常連※ |
| 3 | おかわり自由 | 13 | 曇天予報 | 23 | 紙飛行機工場 | 33 | のら猫会議 | 43 | 説明不足 |
| 4 | レモンサワーズ | 14 | 夕焼け商店街 | 24 | せんぷう機関車 | 34 | ペンギン前線 | 44 | 異口同音 |
| 5 | 七味とうがらし | 15 | 満月書店 | 25 | リモコン紛失中 | 35 | カメの甲羅干し | 45 | 五十歩百歩 |
| 6 | 固いプリン | 16 | 裏路地ランタン | 26 | 乾電池兄弟 | 36 | ミノムシ観測所 | 46 | お茶を濁す |
| 7 | 追いがつお | 17 | 始発待ち | 27 | 折りたたみ傘団 | 37 | 金魚すくい放題 | 47 | 二度寝の達人 |
| 8 | 朝食ロールパン | 18 | 屋上遊園地 | 28 | 万年筆さん | 38 | 渡り鳥予備校 | 48 | 背水の陣内見会 |
| 9 | わんこそば理論 | 19 | 雨宿り※ | 29 | ガムテープ超特急 | 39 | ナマケモノ急行 | 49 | 有言不実行 |

**champion 抽選からの除外セット `CHAMP_ELIGIBLE`（優勝者にふさわしくない枠を外す）:**
- `19 雨宿り` … 既存 NPC（後輩コンビとして登録済み・§2 注記）。突発の優勝者にすると設定矛盾 → **champion 不可**。
- `42 敗者復活常連` … メタネタ枠。「優勝者」に置くと世界観のトーンを壊す → **champion 不可**。
- 上記 2 組は **TOP3 他枠の補充（fill）では使用可**（フレーバーとして自然）。
- ⇒ `CHAMP_ELIGIBLE = 0..49 の全 index から {19, 42} を除いた 48 組`。
- **谷の年の挙動【C1レッドチーム反映・2026-07-05】**: §4-4 の単一抽選では、谷の年（championもモブの年）は champion もTOP3補充も CHAMP_ELIGIBLE(48組) から引く。ゆえに `19雨宿り`・`42敗者復活常連` は**谷の年の TOP3 には登場せず**、rival が優勝する年（6年目・10年勝ち周回）の補充(fill)でのみ現れる。上の「fillでは使用可」はrival優勝年に限る、と読む。意図的挙動・無害。

---

## 6. 勇退・卒業の規則化（`rival_design_v0.md` §0・§1）

選出プールからの**恒久／時限除外**をデータで持つ。マスタ表（§2）は既に反映済みだが、将来の年表改訂に耐えるよう規則で明文化する。

| 組 | 除外種別 | 除外が効く年 | 根拠 | champion可否 | TOP3可否 |
|---|---|---|---|---|---|
| 金字塔 | **時限（勇退）** | 7年目以降 | §1「6年目=優勝・勇退」 | 7〜: 不可 | 7〜: 不可 |
| 夜行列車 | **恒久（グランプリ卒業）** | 全年 | §1 グランプリ決勝に一度も到達せず／3年目資格切れ後ベテラン大会へ | 不可 | 不可 |
| ミラーボール兄弟 | 状態依存 | 3〜6年目は決勝圏外 | §1（欠場・2回戦落ち・単独） | 7年目のみ返り咲き=TOP3候補、優勝は無し | 7年目のみ可 |
| 静物画 | **時限（資格ラスト）** | 11年目以降 | §1「10年目=資格ラストイヤー」 | 〜10 | 〜10 |

規則（擬似コード）:

```swift
func isEligibleThisYear(_ rival: RivalID, year: Int) -> Bool {
    switch rival {
    case .kinjitou:      return year <= 6      // 7年目に勇退
    case .yakoRessha:    return false          // グランプリ選出プールから恒久除外
    case .mirrorBall:    return year == 7      // 決勝候補は返り咲きの7年目のみ
    case .shizubutsuga:  return year <= 10     // 資格ラストが10年目
    }
}
```

- **勇退済み／卒業済みの組がその年の年表で「優勝」に該当してしまう**周回変動が将来入った場合は、`isEligibleThisYear == false` を優先し **モブへフォールバック**（§4-D.3・谷の年と同じ経路）。
- 金字塔 6年目は「本年で優勝 → 翌年勇退」の順。6年目時点では eligible（`year <= 6`）なので優勝表示は成立する。

---

## 7. 出力データ構造（CLI 消費用・JSON例）

`buildFinalsCast` の戻り値を UI（§4-C 暫定ボード／§4-C めくり／§4-D 指名演出）へ渡す形。

```json
{
  "year": 6,
  "runSeed": 20260704,
  "champion": { "name": "金字塔", "flavor": "同期が、先に行った。", "isRival": true },
  "top3Others": [
    { "name": "缶コーヒー兄弟", "isRival": false },
    { "name": "みそしるず", "isRival": false }
  ]
}
```

※ 上例は6年目（§2マスタ表: champion=金字塔〔本年で優勝→翌年勇退〕・TOP3他2枠=mob(2)）の出力。champion と top3Others には**同一組は入らない**（§4 の exclude 制御）。rival が優勝しない谷の年（例: 9年目）は champion=モブ、top3Others=[静物画, モブ] のように rival は必ず TOP3 側へ入る。

- champion の**表示合計点** = プレイヤー表示点 + Δ（§4-D 演出帯: TOP3入り僅差 Δ+1〜3／完敗 Δ大）。プレイヤー絶対点は非表示（§5-2 現案維持）。
- めくりの票（§4-C）は既存規則（スコアと優勝ラインの差）を流用。champion を最多得票者として札に載せ、席順割り当ては機械的。

---

## 8. セルフチェック（実装前チェックリスト）

- [ ] champion / top3Others のどの表示名も**プレイヤーのコンビ名と一致しない**（exclude に playerName）。
- [ ] champion と top3Others に**同一組が重複しない**（§4 exclude）。
- [ ] 勇退（金字塔7年目〜）・卒業（夜行列車 全年）の組が優勝者/TOP3 に**出ていない**。
- [ ] 同一 `runSeed` で**何度呼んでも同じ結果**（決定的ハッシュ・非復元抽出）。
- [ ] モブ名プールの**配列順が凍結**されている（並べ替え＝再現性破壊）。
- [ ] `19 雨宿り`・`42 敗者復活常連` が **champion に選ばれていない**。
- [ ] 全表示名が架空・実在コンビ/人物/SNS を想起させない・「笑」の字を含まない（`judge_design_v0.md` §10-D／リリース前に弁護士確認リスト §content_batch5 §4）。
- [ ] `shizubutsugaY10WinRate` は【仮】値でありバランス確定時に再計測（§3）。

---

## 9. 未決事項

1. `shizubutsugaY10WinRate` の確定値（§3・`rival_design_v0.md` §4-未決2）。プレイヤー初優勝との同年衝突演出も併せて。
2. §2 の【設計上の懸念】: §4-D 例示（ミラーボール7年目/静物画9年目を優勝扱い）を採るなら **rival_design §1 年表本文の改訂**が要る。本表は年表本文準拠で確定済みだが、オーナー判断で切替可能。
3. 周回±1年の揺らぎ（`rival_design_v0.md` §2）を年→選出に反映するか。現案は**プレイヤー経過年＝年表年で固定**（揺らぎ非適用）。適用するなら §4 の `year` に周回オフセットを噛ませる小改修で対応可。
