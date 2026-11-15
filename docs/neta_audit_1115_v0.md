# ネタの仕組み コード点検（2026-11-15・読むだけ・コード無変更）

**要点3行**
1. 新規 6件（中 3・低 3）＋既出の確認 4件。Python 正典と Swift の式・係数（polish 30／改稿+8／見せ会+12／フリー+6／α0.4／0.7・0.5／0.04・0.02／±5／2本目-3・60／飽き1.0×段・上限2）は一致＝規律A違反なし（check_config_sync も同じ定数を見ている）。
2. 最も重いのは N1：決勝の2本目は自動で入らず、未選択・1本しか持っていない・完成度60未満だと一律 −3。ネタ0本の方が減点が無く（0）、画面の一言は「2本目は選ばずに進む」と軽い。
3. 飽きは「新しいネタを書くと元どおり」と画面が言うが、新ネタは完成度30・反応0＝−1.8 で出発し、飽きた古いネタの方が点が高い場合が多い（文言の食い違い）。復元・削除で別のネタを審査／polish 二重／飽きが戻る経路は見つからず。

構成：§1 新規の指摘（N1〜N6）／§2 問題なしの確認／§3 既出

---

## §1 新規の指摘

### N1 【中】決勝の2本目：既定が入らず、−3 が一言で伝わらず、ネタ0本より1本の方が不利
- 場所：GameEngine.swift:272-286（netaScoreBonus）・GameSession.swift:896-900（ensureStageNetaDefault＝1本目しか入れない）・StageViews.swift:304-309（goNote）・StageViews.swift:326-329（2本目の選択行）
- 手順：ネタを1本だけ持って（または2本目を選ばずに）決勝へ→「本番へ」を押す。2本目の完成度が60未満でも同じ。
- 起きること：実効ラインに −3（netaSecondPenalty）。ネタを1本しか持たない人は、2本目の候補が空（「ほかにかけるネタが無い」）で、減点を避ける手段が無い。しかも selectedNetaID==nil（ネタ0本または選ばない）なら guard で 0＝減点なし。つまり「1本・完成度30・反応0」（−1.8−3＝−4.8）より「ネタ無し」（0）の方が有利。goNote は「2本目は選ばずに進む」とだけ出る（点が3下がることは言わない）。完成度60未満を選んだ時は何も出ない。
- Python 側：sim_career.py:782-789 は2本目を「他のネタで最高完成度」と自動で当てる（ボット）＝アプリのプレイヤーより常に有利に測っている面がある。式（−3・60）自体は一致。
- 直し方の案：①2本目も ensureStageNetaDefault で「1本目以外で完成度が最高のネタ」を既定に入れる（1本目と同じ扱い・手で選んだら戻さない）。②goNote を「2本目なし（点が下がる）」「2本目の完成度が60に届いていない（点が下がる）」に。③ネタ0本・未選択でも決勝の −3 を掛けるかは式の判断＝オーナー判断（規律A：Python・Swift・golden を揃える。golden は selectedNetaID==nil で不変のはず）。
- 備考：docs/decision_brief_2026-11-08.md C-17 は「1本目と2本目を同じにした時の沈黙」で別件。

### N2 【中】「新しいネタを書くと元どおり」が実際の式と合わない（飽きの説明）
- 場所：SettingsView.swift:261・WeekMainView.swift:1546（toast）／式：Neta.swift:52・WeekRunner.swift:151（飽きは下がらない）・GameEngine.swift:274-278
- 手順：大会で同じネタを2年使う→3年目の年初に toast「新しいネタを書くと元どおり」。
- 起きること：飽きた古いネタの tiredYears は何をしても戻らない（式どおり・決定①）。「元どおり」は、新ネタに替えれば飽きの減点が付かないという意味だが、新ネタは完成度30・反応0＝ (−20×0.04)+(−50×0.02)＝−1.8 から始まる。仕上がった古いネタ（例 80／60／飽き2）＝1.2+0.2−2＝−0.6 の方が点が高い。「書くと元どおり」と読むと損な乗り換えに誘導する。
- 直し方の案：①文言を「見飽きられたネタは点が下がる（寝かせても戻らない）。新しく書けば、飽きの減点は付かない」に。②式を変える（寝かせると1段戻る＝sim の V2_TIRED_REST／V2_TIRED_REST_YEARS が既に試作済み）＝オーナー判断・規律A。
- toast は activeNetas の「最初に飽きた1本」を名指しするだけで、勝負ネタとは限らない（低）。

### N3 【中】「新しく書く」の印が保存されず、書けない状態でも画面は「新ネタ」のまま／枠が満杯になると食い違う
- 場所：GameSession.swift:63-66（writeNewNeta・保存しない）・GameSession.swift:855-868（枠満杯なら末尾を改稿）・WeekMainView.swift:709（writeTarget）・WeekMainView.swift:1603（netaEffectText＝「新ネタ」）
- 手順：「ネタを書く」→「新しく書く」（枠3/4・writeNewNeta=true）→ネタ帳でしまったネタを「出す」で4/4にする→週に戻って場所を選ぶ。
- 起きること：画面は「新しいネタ」「新ネタ」と出すが、エンジンは枠が満杯なので末尾のネタを改稿（完成度が上がる）して writeNewNeta を下ろす。入力した題名は pendingNetaTitle の id が合わず捨てられる。
- 別経路（低）：「新しく書く」を選んだ週が体力ゲート／体調ダウンで休みに差し替わると、題名は消え writeNewNeta は true のまま残る。
- 既出：writeNewNeta が再開で消える点（save_restore_audit_1115 #6・code_review_2026-10-25 §7b）。今回は再開ではなく「枠が埋まる」食い違いで別件。
- 直し方の案：①writeTarget（WeekMainView:709）と applyNetaWork を同じ関数に寄せ、満杯なら writeNewNeta を表示側でも無効扱い。②recallNeta で枠が埋まった時に writeNewNeta を下ろす（retireNeta が writeNetaID を外すのと同型・1行）。

### N4 【低】「客の反応」の説明が実装（乱数なし）と違う
- 場所：SettingsView.swift:259（「その日の客の反応で動く」）／Neta.swift:90-93・GameConfig.swift:379-382
- 起きること：buzz は 実力×0.7＋完成度×0.5 の移動平均で、客層の当たり外れは無い（Phase 1-c は見送り）。同じ実力・完成度なら誰がやっても同じ値。「その日の客の反応」は日ごとに変わるように読める。
- 直し方の案：「ネタをかけるたびに、その時の実力と完成度から決まる手応えに近づく」。乱数を入れる案は規律A＝触らない。

### N5 【低】ネタの伸びの表示がブースト（書けた一本）と上限を反映しない
- 場所：WeekMainView.swift:1595-1606（netaEffectText）／WeekRunner.swift:534-538（applyNetaRevise の ×netaBoostMult）
- 起きること：ブースト中（netaBoostWeeks>0）は実際の伸びが 8→12.8 などになるが、カードは「完成度 +8」のまま（ブースト後は実際より小さい表示）。完成度100付近でも「+12」と出る。lastNetaGain（GameSession.swift:419-424）は実測の差分なので、結果側の数字は正しい。
- 直し方の案：config と state から「+8（×1.6）」とクランプ後の見込みを出す。数字だけで体感に影響は小さい。

### N6 【低】保管庫のネタに飽きの札・完成度が出ず、「出す」が満杯の時に無言で押せない
- 場所：NotebookView.swift:455-482（archivedRow）
- 起きること：しまった間も飽きは進む（WeekRunner.swift:155-157）が、保管庫の行には名前と「もう一度」しか出ない。呼び戻して初めて「見飽きられた」が見える。枠が4/4だと「出す」がグレーになるだけで理由の一言が無い。「もう一度」は作成から3年以上の印で、飽きとは無関係。
- 直し方の案：①保管庫の行に NetaTiredBadge と完成度の数字を足す。②満杯の時は「持ちネタが一杯」と一言。
- 補足（低）：自動命名は50個で一巡する（NetaCatalog.swift:54-57・90-101）。nextNetaID は減らないので、一生で50本書くと同名が出る。プレイヤーが付けた題名にも重複防止は無い。同名でも内部は id で区別され、動作に害は無い。

---

## §2 問題なしの確認（読んだ範囲）
- 規律A：式・係数は Python（NETA_COEF_COMP 0.04／V2_COEF_BUZZ 0.02／NETA_CLAMP 5／NETA_SECOND_PEN 3／V2_SECOND_MIN 60／V2_TIRED_PEN 1.0／V2_TIRED_CAP 2／V2_LIVE_SHOW 12／V2_LIVE_FREE 6／V2_ALPHA 0.4／V2_POWER_W 0.7／V2_POLISH_W 0.5／NEW 30／書く 8・10・12／ブースト 1.6×2週）と GameConfig が一致。飽きの減点は clamp の後に引く順も同じ。buzz→polish の更新順（手応え算出→移動平均→完成度↑）も同じ。ボットの違い（見せ会で最高完成度のネタ／フリーライブで最低反応のネタ／枠2本）は戦略の近似で式の食い違いではない。
- 飽き（tiredYears）：年初の WeekRunner.init で lastUsedTaikaiYear == year−1 の時だけ +1（上限2）。再開は init(restoring:) を通るので二重に進まない。年末→次の年の生成は1回。Python の used_y pop と同義（gamecore_boundary_audit_1115 に既出の判定どおり）。
- 大会直前に中断→復元：selectedNetaID／2・netas・lastUsedTaikaiYear はすべて state に入りセーブされる。ensureStageNetaDefault は nil の時だけ埋め、手で選んだネタは動かさない。別のネタで審査される経路は見つからず。GP の回戦ごとに選び直すと使ったネタ全部が翌年飽きるが、これは仕様どおり。
- polish の二重加算：applyNetaWork は runner.lastTrainingDone == t の週だけ（休みに差し替わった週は進まない）。choose は1回の週送りで1回だけ呼ぶ。ネタ作り（書く場所3種）／見せ会／フリーライブは同じ週に1つの稽古しか走らない。
- ネタを消す／選び直す：applyNetaRetire は勝負ネタ・2本目・書く対象（retireNeta）を外す。selectNeta は2本目と同じ id なら2本目を外す・selectNeta2 は1本目と同じを拒否。保管庫のネタは state.netas に無いので選択もスコアも対象外（呼び戻してから）。
- ネタ0本：netaScoreBonus は 0。見せ会／フリーライブは何もしない（hasNetas で効果文も出さない）。持ちネタ帳は「まだネタがない」・選択行は「持ちネタがない」。配列の [i] は firstIndex 由来でクラッシュ無し（crash_audit_1115 と一致）。
- 上限本数：netaActiveSlots=4（GameConfig.swift:362）。書く週は満杯なら末尾を改稿、recall は満杯で何もしない（画面も無効化）、UI の「N / 4」は config を読んでいて数字の食い違い無し。
- 画面の数字の出所：「完成度 +n」は config（netaReviseGain／netaPlaceGain／netaLivePolishShow／Free）から出ている。段の境界（35／60／85）と2本目の下限60は偶然 stage 2 の境に一致。鉄板の閾値（80／8場／60）は画面の文に数字が無く食い違い無し。

## §3 既出（新規に数えない）
- 決勝の2本目に使ったネタは飽きが進まない：gamecore_boundary_audit_1115 §3-3（Python も1本目のみ＝式は一致）。
- しまったネタが2本目に残る：同 §1-3（WeekRunner.applyNetaRetire で直し済み）。
- 年初の飽き toast が再開で2回出る：save_restore_audit_1115 #2（AUTOPILOT 451 で済）。
- writeNewNeta が再開で消える：save_restore_audit_1115 #6／code_review_2026-10-25 §7b。

## 追記（11/15 定期・親）
- N3 ② を入れた（recallNeta で枠が埋まったら writeNewNeta を下ろす）。N3 ① の表示側の寄せ・休みに差し替わった週の別経路は残す。N1・N2 は判断が要る（文言か式か）＝材料のみ。
