# 懸念の台帳 棚卸し 2026-10-25 v0

対象: docs/concerns_register_v0.md の表38行（コードは無変更・台帳は無編集）。根拠は grep ベースの短い確認で、「記録なし」はAUTOPILOT/AUTOPILOT_done/START_HEREに決着の記録が見つからない意味。

## 集計

解消 13／一部解消 15／未解消 1／判断待ち 9（計38・10/25 夜に数え直し・10/25 夕に更新。朝の時点は 解消4／一部9／未解消15／判断待ち10）

## 未解消で判断不要のもの 上位5件（次に自走で手を付けられる物）

（10/25 夜に更新：朝の上位5件は #50 解消・#38/#67 は patch 済みで workflow 権限待ち・#49/#39 は実測済みで判断待ち）
判断不要で残る物はほぼ無い。残りは「オーナーの一手が要る物」：
1. #38・#67 CI の patch を入れる（`git am docs/patches/ci_app_build_L38.patch`・オーナーのトークンで push）
2. #39 ファンレポ A帯を増やすか（fan_report_repeat_measure_1025_v0）
3. #41 紙講評の反復の次の手（AUTOPILOT 125）
4. #49 研究デバフを閉じるか（AUTOPILOT 124）
5. #69 トロフィー・ライバルの実装（AUTOPILOT 46・110 の判断が先）

## 全行

| 台帳行 | 重要度 | 懸念（20字） | 判定 | 根拠 |
|---|---|---|---|---|
| L29 | high | 裏天井2案並存・未実装 | 判断待ち | START_HERE L56「裏天井を入れるか」未決 |
| L30 | high | 決勝優勝ライン数値不一致 | 解消（10/25 夕に確認） | finals_direction に 95/91/89 の記述は残っていない・master_spec L49 は「94 →v2: 80（canonical §1 が正）」・Calendar.gpFinalLine=80・canonical_v2 L6 が唯一の正典と明記 |
| L31 | high | finals優勝例とrival年表矛盾 | 判断待ち（10/25 夜：失効の見込み） | champion_selection §9未決2（owner）。v1（2026-07-05 オーナー確定の正典移行バナー）で v0 の年別マスタ表・固定名方式ごと失効＝この矛盾は v1 では起きない見込み。閉じるかはオーナー確認 |
| L32 | high | finals §4-C.5モブ旧30組 | 解消（10/25 夕に確認） | finals_direction L124 は既に「name_generator が毎周生成（固定50組…）」に更新済み |
| L35 | high | exp_neta非情報的 | 一部解消（10/25 実測・値はオーナー判断） | neta_coef_calibration_1025_v0：決勝30〜40%帯のボットで係数 0→今→2倍＝決勝 21.5→34.6→46.6%（EVENTS_APP=True・n=1000・今の列は基準表と一致）。今の値は帯を押し上げる側、0.5倍でネタ無しの帯に戻る。【10/26】磨かない人（完成度30固定）は係数を上げると逆に下がる（0→2倍で決勝 ローテ 21.4→11.9%・必要充足 54.4→44.9%・n=1000）＝今の値は「磨くとご褒美」側で、磨かない人への罰は最大約−4pt（neta_coef_nopolish_1026_v0）。値はオーナー判断 |
| L36 | high | セーブ/中断復帰未実装 | 解消 | GameSession.saveNow/SaveData/loadedOrNew・WeekSummary/StageResult Codable・CoverageRAppTests復元 |
| L37 | high | resolve*二度押しガード | 解消（10/25 夜） | アプリ（GameSession の phase 照合）に加え、4f89b0c で WeekRunner も週が閉じた後の resolve* を無効化（週末処理の二重を防ぐ・weekClosed は中断セーブに載る・WeekRunnerDoubleCallTests 3本）。続く 1 コミットで週の途中の段違いの呼び出し（例：大会の決断中に resolveAction）も無効化（currentPhase）＝WeekRunnerDoubleCallTests 4本 |
| L38 | high | iOSがCIでビルドされない | 一部解消（10/25 夕） | 差分は docs/patches/ci_app_build_L38.patch（app-build ジョブ・macos-15）。push のトークンに workflow 権限が無く拒否＝オーナーが `git am docs/patches/ci_app_build_L38.patch` で入れる |
| L39 | high | ファンレポ枯渇 | 一部解消（10/25 夜 実測） | 15c9de0 で 54→161本。増補後の10年の読み返し率 steady 63%・strong 67%・poor 45%（1〜3年目19%→4〜6年目75〜82%→7〜10年目85〜92%）＝fan_report_repeat_measure_1025_v0（16bab4b）。最も薄いのは A帯（大ウケで通過・24〜26本・読みの約65%が集中・読み返し88〜89%）、負け続きの型では D帯（23本・69%）。10/25 夜に既存の A帯 26→50本 747598b・D帯 24→46本 2686cfd・B帯 25→45・C帯 25→45 a2df153 を増補（新しいプールは作らない）。新しいプール（追いレポ・常連）を作るかはオーナー｜増補後の測り直し 6b6b0c0：steady 63→53%・strong 67→59%・poor 45→31%（最も薄いのは A帯 77〜79%） |
| L40 | high | 日常雑談の無口化 | 一部解消（10/25 夜 測り直し） | 増補 9b2ac26 の後の10年の読み返し率（banter_repeat_measure_1025_v0 追補・794761d）：全体 約60%→約38%・7〜10年目 97%→80%・掛け合い 62→46%・独白 59→33%。残る薄いプール＝掛け合い afterPass（11組・52%）・eve（11組・44%）・plain（12組・52%）・独白 plain（32本・50%）。本番2週前の独り言は 1型→4通りに 73dd445。10/25 夜に薄い既存プールを増補 1e399d8（掛け合い afterPass 11→21・eve 11→21・plain 12→22・独り言 plain 32→45・採点で3組を直し 141ba02）。さらに増やすかはオーナー｜増補後の測り直し 6b6b0c0：全体 38→24%・7〜10年目 80→57%（最も薄いのは掛け合い lull 43〜45%）｜その後 lull 31→46組 3491a6d（採点で1組差し替え 35fb3ad） |
| L41 | high | 予選紙講評の反復 | 一部解消（10/25 実測） | 10年の読み返し率 約11〜18%（最大22%・強い組で予選を何度も通る型で目立つ）＝judge_comment_repeat_measure_1025_v0。増やすかはオーナー。増補 9d36f5f（opus）：passChemistryHigh 11→24・failStaminaLow 11→18＝読み返し A 10.5→7.6%・B 19.9→14.3%・C 21.2→14.4%（370 green）。これ以上は「直近の文を避ける表示側の履歴」か「相性フックの出方」の見直しが要る＝判断 |
| L42 | high | B案が買い切りに劣後 | 判断待ち | 業態未決（START_HERE L54） |
| L43 | high | 資金決済法リスク | 一部解消（10/25 夕） | payment_services_act_check_1025_v0：今の作り（非消耗型のみ）は前払式支払手段の対象外の見込み（公的資料での明記は未発見＝推論）。有料石を入れると自家型＝基準日残高1,000万円超で届出＋1/2供託。条文の確認は弁護士へ |
| L44 | high | 景表法・ガチャ確率 | 一部解消（10/25 夕） | gacha_law_check_1025_v0：今の課金は買い切り4商品のみでガチャ無し＝確率表示・コンプガチャは対象外。入れる場合の対応表あり。legal_risk L74「CESAへの統合」は根拠なし・monetization_decision L3「B案F2P確定」は現状と食い違い（業態はオーナー判断） |
| L45 | high | 運営レス前提の崩壊 | 判断待ち | 業態未決に依存（owner-decision） |
| L46 | high | キャラ供給の計画なし | 判断待ち | owner-decision |
| L49 | medium | 研究デバフが旧スケール較正 | 一部解消（10/25 実測・閉じるのはオーナー） | research_debuff_remeasure_1025_v0：客層二層（計測コードの不具合を直すと）±1〜3pt・波乱は優勝±1〜2pt＝誤差内、飽きられは一度も発動せず。3つとも研究用の分岐（sim_career のみ・アプリに無し・既定無効）。推奨＝見送って閉じる |
| L50 | medium | H3体力-15が無記録 | 解消（10/25 夕） | 実測 a6fb0ea（h3_stamina_penalty_measure_1025_v0）＋canonical_v2 §1 生活ルールに STAM_PEN を記録 |
| L51 | medium | gen_goldenとsim_career二重実装 | 一部解消 | tools/check_golden_sync.py（ドリフト検出）あり。王者年は分岐 golden の台本B 2年目（seedFinal＋ライン-999＝優勝して即終了）で通っている＝CareerGoldenTests.branchB（10/25 夜に確認）。残り＝gen_golden と sim_career の実装の一本化のみ |
| L52 | medium | GP優勝でS3結果スキップ | 一部解消（10/25 夜） | 優勝の年は「勝ち版の演出（winFinale）」＋出来事ログ・賞金年計への記録で補われている。夜逃げ・解散の週の大会結果がログ・年計から落ちていたのは次のコミットで記録だけ足した（GameSession.pump）。残り＝優勝・夜逃げの週に S3 の結果画面そのものを挟むかはオーナー |
| L53 | medium | gpSeeded実行パス未テスト | 解消 | WeekRunnerGoldenTests(prevStage>=3→gpSeeded)・RunCareer/Rift/CoverageUTests |
| L54 | medium | 体調ダウン未テスト | 解消（10/25） | 34cb2f3 InjuryFlowTests：抽選値を固定して「閾値未満の最初の危ない週で発生→療養2週」と「抽選が高い／安全な行動なら起きない」を WeekRunner で固定（370 green） |
| L55 | medium | state正が3箇所に分散 | 一部解消（10/25 夕） | StateSyncTests：2年通しで入口を呼ぶごとに state と runner.state をバイト比較＝ずれ0（アプリ 167 green）。一本化の作り替えはしていない |
| L56 | medium | 決勝審査コメントの反復 | 解消（10/25 実測） | 決勝講評の読み返し率は型C 1.1%・型B 0%（7人全員を出しても4.3%）＝judge_comment_repeat_measure_1025_v0 |
| L57 | medium | 数量目標がファンレポのみ | 判断待ち（10/25 夜 棚卸しあり） | content_inventory_count_1025_v0：今の在庫 約960本（独白148・掛け合い89組・行動への一言61・ファンレポ161・紙講評165・決勝講評約194・選択イベント36種ほか）。計画表との差＝掛け合い 89/110・ファンレポ 161/200。最も薄いのはファンレポ A帯（26本・10年で約220回表示）。プールごとの目標はオーナー |
| L58 | medium | モブ名50組の年跨ぎ再利用 | 判断待ち（10/25 夜 実測あり） | mob_roster_repeat_1025_v0：10年で42組登場・最多6回・前年との重なり平均約2組。顔ぶれは年だけで決まる＝何周しても N 年目は同じ9組。①今のまま ②周ごとに変える ③名簿を増やす はオーナー |
| L59 | medium | 需要の絶対量が未計測 | 判断待ち | owner-decision |
| L60 | medium | ストア手数料の未確認前提 | 一部解消（10/25 夕） | store_fee_check_1025_v0：日本の Apple は小規模で実効15%（10%＋決済5%）で前提と一致、Google は新体系で15〜25%＝「両ストア15%」は不一致。legal_risk・market_research の該当行は 10/25 の追記で済。【10/26】Apple 一次ページで確認済み（日本：標準21%・参加10%＋決済5%・登録は手動＝store_fee_check 追記）。残りは Google 新体系の適用日だけ（出す時期が決まってから） |
| L61 | medium | 商標・パブリシティ未レビュー | 一部解消（10/25 夕） | trademark_publicity_check_1025_v0：Web 検索の範囲で実在の芸人・大会・商標との一致なし。J-PlatPat の称呼検索（ヒトコエ・頂GP）とストア内検索は未＝出す前に人の手で |
| L62 | low | champion_selection §7 JSON矛盾 | 解消（10/25 夕に確認） | §7 の例は6年目＝金字塔で§2表と一致・§4-4 は単一抽選（先頭を champion）・mobDraw 表記も正（L113/L141） |
| L63 | low | 王者編18ptゲートと15pt行 | 解消（10/25 夕に確認） | 王者編そのものが廃止（master_spec L58/L77/L140）・canonical §2-B の15pt行も取消線 |
| L64 | low | 審査員名の綴り照合 | 解消（10/25 夕に照合） | 7名（音羽ルリ・白波剛・卯月走太・花園千代・目白慧・神楽坂とんぼ・天堂寺銀郎）は neta_system 系・judge_design・finals_direction・JudgeTalk.judgeNames で表記一致（姓名間の空白の有無だけ）・並び順も一致 |
| L65 | low | MVP1年版の体感未検証 | 一部解消（10/25 実測・体感はオーナーの実プレイ） | mvp_one_year_growth_1025_v0：48週で実力値 10.0→中央12.5〜13.0・上限6.0の頭打ちは のんびり改/ローテ≒0%・必要充足2〜3%・やり込み13〜18%（初到達は週33〜41）・1年目の夜逃げ/解散0%。所持金は中央−5〜+3万 |
| L66 | low | 初回固定シード424242 | 解消 | RootView L338 初回もランダムシード |
| L67 | low | ビット一致表記が近似(1e-9) | 一部解消（10/25 夕） | WeekRunner.swift L4 は既に「誤差1e-9以内」。ci.yml L21 の直しは L38 の patch に同梱（workflow 権限待ち） |
| L68 | low | WeekSummary/StageResult非Codable | 解消 | WeekRunner.swift L9,L33 Codable化済 |
| L69 | low | 充足カテゴリは前提付き | 未解消（10/25 夕に再確認） | アプリにトロフィー22・ライバル57項はまだ0（grep 該当なし）。ライバルは AUTOPILOT 46（名前の生成器の未決が先）、トロフィー/称号は 110（周回メタの型1/型2 判断待ち）に依存＝判断待ちの後 |
| L70 | low | 運用細目（未成年課金等） | 判断待ち | owner-decision |
