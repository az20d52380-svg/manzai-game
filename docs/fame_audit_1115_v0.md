# 知名度（fame）の流れのコード点検（2026-11-15・読むだけ）

- 要点1：新規 4件（高0・中1・低3）＋既出 2件。上限 clamp・負・二重適用・Python 正典との式の食い違いは 0（規律A 違反なし）。
- 要点2：いちばん重いのは「画面の知名度は四捨五入（Int(x.rounded())）、資格・札の枚数・オファー率・イベントの条件は生の小数で判定」＝表示 30 なのに 29.6 で推薦制に出られない／札が増えない（#1）。
- 要点3：増減の表示は結果画面（GP 直しの後）・年末は実差と一致。残る食い違いは週のチップ／カードの「増分を丸める」流儀（既出 number_display #2）と、小数の伸びの 0.5 未満を捨てる点（#2）。

## 節構成
§1 知名度の流れ（上がる所・下がる所・clamp）／§2 知名度で変わる物／§3 新規の指摘（#1〜#4）／§4 既出／§5 問題なし

---

## §1 知名度の流れ

### 上がる所（すべて GameEngine 経由。Python は balance_sim.add / sim_career）
| 契機 | Swift | 式 | Python |
|---|---|---|---|
| 稽古（フリーライブ fame 1）・オファー（1〜3）・道中大会の通過（5/10）・GP 各回戦通過（3）・HANA（3/8）・選択肢イベントの `.fame` は別（下） | GameEngine.swift:55-62（`add(.知名度)`）／WeekRunner.swift:233,267,292 | 正の増分 ×0.6×(1−f/80)²（f≥80 は 0）、愛され芸人 ×1.1、clamp 0..100 | balance_sim.py:199-207（同じ演算順）。一致 |
| GP 決勝進出（準決勝通過・敗者復活通過） | GameEngine.swift:67-70 `addFameBig` ＝ 30×(1−f/100) | 100 には届かない | sim_career.py:637-640 `_fame_big`。一致 |
| GP 優勝 | GameEngine.swift:73-75 `addFameRaw` ＝ +10（逓減なし・clamp 100） | 2回目の優勝で 100 | sim_career.py:628-635。一致 |
| 選択肢イベント | ChoiceEventEffect.swift:32 `fame + d` を 0..100 に clamp（逓減・愛され芸人・0.6 倍を通さない素の加減算） | | sim_career.py:301-308 `_ev_add`（素の加減算）。一致（意図的・gamecore_review_1019 F2） |

### 下がる所
- 知名度を下げる経路は無い（時間減衰なし・イベントの `.fame` は全て正・負の `.fame` を持つ選択肢なし・敗退でも下がらない）。`add` の負の増分は clamp 0 で受けるが到達しない。fame_gap_y7_1027_v0.md が「減衰なし」を確認済み（既出）。

### clamp
- `add`（0..100）・`addFameBig`（0..100・式上 100 未満）・`addFameRaw`（0..100）・`ChoiceEventEffect`（0..100）。100 超え・負になる経路は無し。
- 初期値 3.0（GameConfig.swift:125・Python INIT_FAME=3 と一致）。
- 保存データの復元は fame を検証しない（NaN・範囲外の改ざん値は通る）。UI の `Int(fame.rounded())` は NaN で落ちる（DialogueData と YearResultView だけ `isFinite` ガードあり）。通常の遊びでは到達しない（crash_audit_1115 の範囲・#4 に低で記載）。

## §2 知名度で変わる物（判定はすべて生の Double）
| 物 | 値 | 場所 |
|---|---|---|
| オファーの発生率 | <10:5%／<30:15%／<55:30%／以上 50% | GameEngine.swift:219-224・GameConfig.swift:344・Python OFFER_RATES |
| オファーの札の枚数 | ≥30 で 2 枚・≥55 で 3 枚 | GameEngine.swift:233・GameConfig.swift:336（`fame >= $0`）・Python OFFER_CARD_FAMES=(30,55) |
| 推薦制中堅賞の資格 | ≥30 | Calendar.swift:53,70・sim_career.py:160 |
| GP 決勝の人気補正 | 実効ライン −1.5×(f−50)/50 | WeekRunner.swift:301・Python :1017（一致） |
| 選択肢イベントの条件 | f<50／<20／5≤f／≥10／≥15／<30／<40／20≤f≤50 | ChoiceEvent.swift:389-428・Python :284-294,415-423（一致） |
| 客に知られているか（講評の台詞） | 2 年目以降かつ ≥15 | FanReportData.swift:415 |
| 年末の「躍進年」の台詞プール | Int(fame)（切り捨て）≥30 | YearResultView.swift:367,384 |
| 年末の伸び | 年初との差（YearResultView.swift:320） | 下の #3 |

---

## §3 新規の指摘

### #1【中】画面の知名度は四捨五入、資格・札の枚数・オファー率は生の値＝境目で食い違う
- 場所：表示＝WeekMainView.swift:1409（`Int(s.fame.rounded())`）・ChoiceEventOverlay.swift:102・TournamentResultView.swift:533・YearResultView.swift:320・RootView.swift:396・YoseYearTurnCurtain.swift:271。判定＝Calendar.swift:54（`state.fame >= f`）・GameEngine.swift:233（`fame >= $0`）・GameEngine.swift:220（`s.fame < entry.fameBelow`）・ChoiceEvent.swift:389-428。
- 起きる手順：知名度が 29.6 の時、バー（最下帯）は「知名度 30」と出る。第38週に推薦制中堅賞の入口は出ない（資格 ≥30 を満たさない）。同様に 54.6 で「55」と出ているのに札は 2 枚のまま、9.6 で「10」と出ているのにオファー率は 5% のまま。
- 画面の説明との一致：資格の数値（30）・札の枚数の閾値（30/55）は画面に書いていない（SettingsView.swift:264,273・WeekMainView.swift:1497 は「舞台に立つと上がる／知名度が高いほど札が増える」だけ）＝文言の食い違いは無い。ただ、遊ぶ人が「バーが 30 になったのに推薦制が来ない」と見る可能性は残る。一度小数の 0.5 未満は「あと少し」で、1 試合後に消える差（体感は小さい）。
- 既出：no（number_display #2 は増分の丸め。AUTOPILOT 457 以降にも該当なし）。
- 直し方の案：①表示だけを切り捨て（`Int(fame)`）に揃える＝表示 N なら必ず生の値 ≥N＝閾値判定と常に整合する（式・golden 不変・見た目の変更箇所は 6 か所・差分表示は#2 と合わせて前後の切り捨ての差にする）。②判定側を `fame.rounded() >= f` に直す＝規律A（Python の sim_career.py:160・OFFER_RATES・offer_extra_count を同時に変える）で golden と 実測の再計算が要る（重い・非推奨）。③据え置き（体感の差が小さい・文面に数値が出ていないので許容）。判断はオーナー。

### #2【低〜中】小数の伸びが 0.5 未満だと「知名度 +n」が出ず、0.5〜1.49 は「+1」だがバーは動かないことがある（既出の周辺・追加分）
- 場所：WeekMainView.swift:1352-1354（`Int(fd.rounded()) > 0` で出す）・:1577-1578（カード予告）・TournamentResultView.swift:516,534（`>= 0.5` で札を出す・「+Int(delta.rounded())」）・GameSession.swift:432,372,991。
- 起きる手順：知名度 60 でひな壇（+3×0.6×(1−60/80)² ≒ +0.11）を受ける→チップは出ない（0.5 未満）が、生の値は上がっている（59.96→60.07 でバーが 60→60 でなく 60 のまま・または 59.6→60.1 でバーだけ 60 へ動く場合は「+0」で説明がつかない）。逆に 3.0→3.55（フリーライブ）はチップ「+1」・バーは 3→4 で一致。3.0→3.45 はチップ無しなのにバーは 3→3。
- 既出：yes（number_display_audit_1115 #2「増分の丸めと値の丸めの違い」・AUTOPILOT 456 で「並べるだけ」）。新規部分は「0.5 未満のとき、バーの数字が変わるのに +n が出ない」「結果画面は同じ丸め」の確認。
- 直し方の案：number_display #2 と同じ。前後を（#1 の方針で）切り捨て／四捨五入で丸めて引き、差が 0 の時だけ出さない。G1（押した週に何か残す）の意図は、舞台週の知名度の増分が高い帯で 0.1〜0.4 しかないため、元から満たせない（offer_audit #1 の本文と同根）。

### #3【低】年末の「↑+n」は「年末の丸め − 年初の丸め」だが、画面の「知名度 N」は年末の値の丸め＝一致するが、解散・夜逃げの年の扱いは別
- 場所：YearResultView.swift:320。年初 `yearStartState.fame` は 4 月の状態（年初処理後）。
- 確認：年初が分かる時は N と↑の整数が揃う（`Int(a.rounded())−Int(b.rounded())`）。旧セーブの全量表示は yearend_audit_1115 #1 で既出・直し済み（hasYearStart で守る）。
- 問題：なし（確認のみ）。#1 を直すなら 320 行も同じ丸め方に合わせる必要がある（資格が絡まない表示どうしなので揃えるだけ）。

### #4【低】保存データの fame を検証しない（NaN・範囲外）
- 場所：GameSession.swift:287 付近（復元）・各 UI の `Int(state.fame.rounded())`（WeekMainView:1409・ChoiceEventOverlay:102・RootView:396・TournamentResultView:533・YoseYearTurnCurtain の summary）。`isFinite` ガードがあるのは DialogueData.swift:55,62 と YearResultView.swift:384,399 のみ。
- 起きる手順：手で編集した（または壊れた）セーブで fame が NaN／inf の時、バーの `Int(...)` が実行時エラー。通常の遊びでは到達しない。
- 既出：部分的（crash_audit_1115 で `fame.isFinite` ガードの有無を確認済み・結論は「到達しない」）。
- 直し方の案：①据え置き（正常系で到達しない）。②復元時に `clamp(fame, 0, 100)`（NaN は 0）をかける 1 行（表示専用でなく状態の変更だが、正常な値には不変）。

---

## §4 既出（grep で確認）
- number_display_audit_1115 #2：週のチップ・カードの「+1」とバーの丸め方の違い（上の #2 の本体）。
- result_screen_audit_1115 #1：GP の結果画面の「↑+n」が古い値（今日 3f215eaa1 で `advanceAuto` に `lastResultFameDelta` を足して直し済み。現コード GameSession.swift:987-991 で確認）。
- offer_audit_1115 #1：高い知名度の帯で札の説明（顔が売れて）と実際の伸び（+0.1〜+0.7）が食い違う（本件の根）。
- fame_gap_y7_1027_v0.md：減衰なし・7年目の 36→33 は別の台本の別走行。

## §5 問題なし（確認したもの）
- Python 正典と Swift の式：その他の伸び（0.6×(1−f/80)²・愛され芸人 1.1・clamp）・決勝進出（30×(1−f/100)）・優勝（+10 素加算）・GP 回戦（3）・HANA（3/3/3/8）・イベントの素の加減算・人気補正（−1.5×(f−50)/50）・オファー率の帯・札の枚数・推薦制 ≥30・イベントの条件の各値が一致。呼ぶ順（回戦通過の +3 の後に決勝進出の +30）も Swift WeekRunner.swift:267-271,292-294 と sim_career.py:983-988,1010-1015 で同じ。
- 100 超え・負：なし（全経路が 0..100 に clamp・addFameBig は式上 100 未満）。
- 画面の説明（設定「知名度＝0〜100」・「決勝では高いほど有利」・「札が増える」・用語「舞台に立つと上がり、仕事の誘いが増える」）と GameConfig／Calendar：数値を持たない文言のみで矛盾なし（offer_audit #1 の「顔が売れて」を除く）。
- 結果画面（大会・GP）の増減：`fameBefore` との差を `decideTournament`／`advanceAuto` で取る＝実差と一致（今日の直し後）。「知名度 N」は `summary.state.fame`（結果後の値）。
- 年末の年計：年初状態との整数の差で、画面の N と整合（旧セーブは hasYearStart で非表示）。
- イベント選択の効果チップ（ChoiceEventOverlay.swift:319）：生の差（>0.001）で出す＝「知名度 ↑」は実際に上がった時だけ。数字は出さない。
- 時間減衰：なし（意図どおり）。

## §6 規律A の補足（式の食い違いではなく「同期の見張りが無い」点）
- tools/check_config_sync.py の PAIRS に入っていない知名度の定数：initFame（3.0）・fameOtherMult（0.6）・fameOtherCap（80）・offerRates（10/30/55）・offerCardFames（30/55）・offerMoney 等のオファーの知名度（1/3/3/2/2/1）・Skill.fameMult（1.1）・推薦制の下限 30 は `_TOUR_RE` が拾う（これだけ見張りあり）。今は全部一致しているが、片側だけ変えても `check_config_sync.py` は通る。重さ：低。直し方の案：PAIRS に `fameOtherMult/fameOtherCap/initFame` を足し、`offerRates`・`offerCardFames` は正規表現で拾う（既存の offerCardSalt と同じ形）。
