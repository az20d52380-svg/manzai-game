# 規律A 11/02 コミット4本の仕様突き合わせ点検（2026-11-08）

対象：c5f01822（段1 較正A）・85c75cf5（段2 周回）・22bd4831（段3 THE HANA）・22972f44（復活ライン79）。仕様の出所は docs/calibration_all_1101_v0.md §5・docs/calibration_meta_1102_v0.md §5・docs/kiritsu_a_1102_notes.md。Python/Swift 一致は golden 保証済みなので、両者が同じ向きにずれていないかを見た。コード・golden・docs は変更していない。

## 結論
- 高 0件／中 1件／低 5件。仕様の数字・境界（以上/超・1始まり・11年目の境目・上限の掛け方・男コンビで HANA が出ないこと）は、確かめた範囲でずれなし。
- 最重要（中）：THE HANA の定数（週・ライン・賞金・知名度）が check_config_sync に入っておらず、golden の女性分岐も決勝（ライン84・手元250万・知名度+8）を通らない。片方だけ変えても赤にならない。

## 指摘
### 中-1 THE HANA の定数が同期検査・golden の外
- 仕様（calibration_all_1101_v0 §5）：週 32/37/42/44・ライン 36/52/70/84・優勝 手元250万/知名度+8。
- 実装：Python tools/sim_career.py の HANA_WEEKS/HANA_LINES/HANA_PRIZE/HANA_CHAMP_FAME（約L171-182）と Swift Calendar.swift の hanaTournaments（L78-83）。tools/check_config_sync.py の対象に hana が無い（grep で0件）。golden の女性分岐（gen_golden.py の seed=24・4年）は「1回戦通過→2回戦敗退」と「準決勝敗退」までで、決勝の通過は単体テスト testTheHanaFemaleOnly のみ。
- ずれ：今は両者一致（コミットの検証どおり）。将来どちらか一方の数字を変えても検査が通る。
- 影響の見込み：現状の挙動は正しい。保守時に静かにずれる恐れ。

### 低-1 HANA の通過時知名度が config とつながっていない
- 仕様：通過で知名度+gpRoundFame（Calendar.swift L76 の注記）。
- 実装：Swift は hanaTournaments の fame に直書き 3（Calendar.swift L79-81）。Python は定義時に GP_ROUND_FAME を読む。
- ずれ：gpRoundFame を調整しても Swift の HANA は追従しない（Python は import 時に追従）。現在値は 3 で一致。
- 対処（11/08 親）：d830dc74 で check_config_sync が HANA の fame を Python（GP_ROUND_FAME 由来）と突き合わせるので、片方だけ変えると NG になる＝事故は拾える。直書きをやめる作りの変更はしない。

### 低-2 王者ライン上書きには 11年目以降の +2 が付かない（仕様どおりだが穴）
- 仕様（notes 段1）：上書きには足さない。sim_career.py L934 / WeekRunner.swift L166。
- ずれ：仕様どおり。ただ上書きを使う王者編（sim_meta・Career.runYear の finalLineOverride）では11年目以降、王者のほうが通常より決勝ラインが2低くなりうる。アプリ本体の経路では上書きは使われていない（grep で Career.swift のみ）ので影響は sim 側のみ。
- 関連：中断セーブの復元（WeekRunner.swift L677）は上書き値を捨てて config から取り直す（A-4 の意図・以前からの挙動）。

### 低-3 敗者復活と決勝の差は知名度100で 0.5pt まで縮む
- 仕様：復活は準決勝78より難しく決勝81より易しく（22972f44）。
- 実装：決勝の実効ラインは 81−1.5×(知名度−50)/50（WeekRunner.swift L301）。復活には知名度補正なし（L284）。
- 確かめた値：知名度100で決勝 79.5／復活 79、11年目以降は 81.5／81。逆転はしない（ネタの補正は決勝のほうが不利側に付くので逆転しない）。差が薄いだけ。

### 低-4 周回の点 P に上限 38 の丸めがない
- 仕様：P は最大38（calibration_meta §5）。
- 実装：頂点の束 36·(P/38)^8（sim_career.py の meta_budget・GameState.init・WeekRunner.swift L131-148）は P を丸めない。P=76 で 9216。経験点の頂点の束も上限なし（仕様どおり）。
- 影響：点の数え方のアプリ配線は未実装（notes 記載）なので今は届かない。配線時に min(P,38) を入れるか数え方の上限を保証すること。

### 低-5 Python のボットは女性コンビの HANA 前に休まない／アプリのイベント判定は HANA を「次の本番」に数える
- notes 段3に記載済み。EVENT_WEEKS に HANA を入れていない（男コンビの動きを変えないため）。Python の _honban_ahead/_app_stages は女性なら HANA を数えるが、ボットの休み判定は数えない。アプリ（GameSession L722）は数える。正典で女性の系列を測り直す時、実測と数字が少し動きうる。仕様違反ではない。

## 確かめて問題なしの項目
- 準決勝 72→78、決勝 80→81、復活 74→75→79、最初の帯 1.00→0.70（しきい値15未満＝初期値10のG帯）：Python と Swift（Calendar.swift・GameConfig.swift）一致。復活79＝準決勝78と決勝81の間、11年目以降は 81/83。
- 11年目の境目：late = year >= 11（1始まりのループ range(1, YEARS+1)）。決勝・復活の両方に +2、復活は late の後に upset（既定OFF）とネタ補正を足す順も実測と同じ。
- 成長予算 ×0.6^(k−10)：k=11 で 0.6、k=15 で 0.0778、10年目以前は 1.0。累計予算 10年=42.0・11年=43.2・15年=44.77。growthEndYear=15 で11〜15年が打ち切られない。Swift は k−(11−1) で一致。
- 結成年数：YEARS=15・careerYears=15・GROWTH_END_YEAR=15。GP の出場に年数上限はない。道中の大会の「10年以内」は仕様どおり変更なし。
- 大会の経験点：GP 回戦 i（1始まり）= 1+0.35(i−1) を Python は 0始まり gp_stage で 1+0.35·stage、Swift も同じ。シード組は stage1 から＝1.35。敗退は ×0.5、重みは道中0.5/回戦1.0/復活・決勝2.0、量は pw×0.5×w を5通貨に ×4×0.2。位置は perform の直後で両者同じ。
- 温泉：メンタル 2→0（PAID_RESTS と Swift rests）。回復100・費用6万は不変。他にメンタル+2 を表す箇所は grep で無し。
- 周回：頂点の束・相性 min(14, 2.27√P) を COMPAT_CAP(20) で止める・型1（4/点・上限160・所持金3万/点・上限100万）・配分 35/27/18/10/10＝合計1.0・年の成長上限の基準と下限に +0.2P^0.3（k を問わず、late の倍率はその後に掛かる）。足し順は型1→相性→頂点。P=0 は何も足さず nil のまま。
- THE HANA：女性コンビ以外では tournament(inWeek:state:)/tournament_of が返さず、isEligible も femaleCombo==true が必須。2回戦以降は同じ年に前の段を通過した時だけ（hanaYear==year && hanaNext==i）で、翌年に持ち越さない。1回戦は毎年（芸歴制限なし）。敗者復活なし。週 32/37/42/44 は TOURNAMENTS（12/15/27/29/35/38/46）・GP（30/39/41/43/45/47）と重ならない。優勝は手元250万・知名度+8、道中の通過は知名度+3。
- 中断セーブの復元で HANA の大会が state 付きで引き直される（WeekRunner.swift L689）。
