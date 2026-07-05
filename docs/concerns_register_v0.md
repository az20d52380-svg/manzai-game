# 懸念レジスタ v0（就寝中 5次元監査の統合）

> 作成: 2026-07-04 / 統合元: 設計整合性・バランス検証・技術実装・コンテンツ在庫・事業法務の5次元監査。
> 数値は全て【仮】。忖度なしで「都合の悪い指摘」を残す方針。重複はマージ済み。
> owner凡例: `owner-decision`=オーナー裁定 / `fable`=バランス&コンテンツ設計 / `4.8-cloud`=ドキュメント整合&実装 / `cli-mac`=Mac実機・CI・ビルド / `research`=法務&市場調査。

---

## 1. 朝イチで見るべき TOP7

1. **【critical/事業】業態が「B確定 / A維持 / 未決」で3文書矛盾したまま実装分岐に突入** — monetization=B確定、roadmap=A維持、START_HERE/red_team=未決。下流(pricing/partner_gacha)が全部これ依存。まず1回で確定を。(owner-decision)
2. **【critical/事業】B案の課金トリガーが構造的に不発** — 「無課金で全コンプ保証」＝売り物(早さ)を自分で無料充足。守るほど収益がゼロに漸近する自己矛盾。(owner-decision)
3. **【critical/整合】master_spec_v2が「正本」を自称しつつ§3/§5/§10の背骨数値が旧正典のまま(準決86/決勝94等)** — 実装者が正本ルールに従うとv2バランスが丸ごと壊れる。(4.8-cloud)
4. ~~【critical】王者編マトリクスが現コードで再現しない~~ → **【解決・moot 2026-07-05】王者編そのものを廃止（オーナー確定）**。王者の特権/連覇/殿堂/dynasty再測は不要になった。周回の到達目標は「一度の優勝＋コレクション」へ。
5. **【high/バランス+整合】裏天井(初回の保証弁)が2案並存・未統合・実装ゼロ・実測ゼロ** — 初回8割(準決敗退層)の救済という体験の芯がP0で停止。(fable)
6. **【high/技術】iOSアプリ(ManzaiGame)がCIで一度もビルドされない** — GameCore API変更でUIが壊れてもCIは緑。S1/S4/S5追加時の型エラーを機械が捕まえられない。(cli-mac)
7. ✅**【解決 2026-07-05・cloud】** canonical看板数値を74/80で再測して上書き（やり込み2.7%/41.5%・のんびり改0.3%/23.1%・バランス0.2%/8.4%＝`exp_v2_anchor.py 1000`シード20260704）。measurement作業ゆえFable不要でcloudが実施。**残**: 定数ドリフトの自動追跡（sim出力にsnapshot）は未着手。

---

## 2. 重大度順 一覧表

| 重大度 | 懸念 | 領域 | evidence | owner | 対処案 |
|---|---|---|---|---|---|
| critical | 業態がB確定/A維持/未決で3文書矛盾、実装分岐に突入 | 事業 | monetization L3,L78 / roadmap §2 L57 / red_team §5 / START_HERE | owner-decision | 単一正典で1回だけ確定し他文書に従属バナー。確定までB案専用実装(pricing/partner_gacha)凍結 |
| critical | B案の課金トリガーが構造的に不発(売り物=早さを無料充足) | 事業 | red_team §2致命1-2 / monetization §7 / pricing §6 | owner-decision | 「無課金全コンプ」と「早さを売る」の非両立を直視。ハイブリッド寄せ or 収益背骨を月額パス+復刻に全振り |
| critical | master_spec_v2が正本自称も§3/§5/§10背骨数値が旧正典(準決86/決勝94/王者91+5/成長4.5) | 整合 | master_spec L4,L47-48,L73,L139 ⇔ canonical §1/§2-B | 4.8-cloud | 3箇所をcanonical v2値へ実書換 or 行内読替併記。canonicalチェックリスト項7「✅v2化」を「◐部分」へ訂正し数値の正本を1文断定 |
| ✅解決(廃止) | 王者編マトリクスが再現しない → **王者編そのものを廃止(2026-07-05オーナー確定)** | バランス | master_spec §5廃止 / canonical §2-B廃止 | owner済 | 【完了】王者の特権/連覇/殿堂/dynasty再測は全て不要。周回到達目標は「一度の優勝＋コレクション」 |
| high | 裏天井が2案並存・未統合・実装ゼロ・実測ゼロ(初回体験の本命) | バランス/整合 | canonical §1 L25(3年ハマなし→2倍) ⇔ red_team §1-1(8年目以降+5%/年) / endgame_pity §5-6 / START_HERE L36 | fable | 2案を単一トリガ/効果式に統合しexp_v2_anchorで初回優勝率を帯内較正。sim_careerに決勝初到達年ヒストグラム追加(小改修)→晩年閾値N決定。恒久能力配布は禁止のまま |
| high | 決勝の優勝/TOP3ライン数値が3文書不一致(canonical80/finals95・91・89/master94)かつfinals内部矛盾 | 整合 | finals L46,L70-73 ⇔ canonical §1 ⇔ master L48 | 4.8-cloud | finals閾値を絶対値でなく「内部スコア vs 該当ライン(v2:74/80)の符号」で記述。出典をcanonical_v2に一本化 |
| high | finals §4-D優勝例(ミラーボール7年目/静物画9年目)がrival年表と食い違い、champion_selectionが年表準拠で一方的解決 | 整合 | finals L126,L136 ⇔ rival §1 L33,L40 ⇔ champion_selection §2 L75,§9未決2 | owner-decision | (A)finals例示を「決勝表示候補」へ訂正しミラーボール優勝フレーバーを死蔵と明記 or (B)年表を優勝化改訂。採用側で3文書同時更新 |
| high | finals §4-C.5がモブ旧30組のまま・夜行列車をTOP3候補に誤記(champion_selectionで恒久除外済) | 整合 | finals L116 ⇔ champion_selection §5 L215,§1 L46,§6 L245 / content_batch5(50組) | 4.8-cloud | finals L116を「50組(content_batch5 §2)から補充・TOP3他枠は金字塔/ミラーボール兄弟/静物画のみ(夜行列車除外)」へ修正しポインタ統一 |
| ✅解決(cloud) | 正本canonicalの体験テーブルを74/80で再測・上書済(2.7%/41.5%・のんびり23.1%・バランス8.4%) | バランス | canonical §2/§4上書済 ⇔ exp_v2_anchor.py 1000 シード20260704 | cloud済 | 【完了】exp_v2_anchorを正本値として再取得しcanonical §2/§4上書。残: ドリフト検出snapshotをsim出力に設置(未) |
| ✅解決(cloud) | SSRティア再価格(相性上限+4)をexp_v2_metaへ反映し「SSR 0pt優勝爆発」を解消 | バランス | exp_v2_meta.py:26 TIERS cap30→24(sim_meta.py:34と一致) / 実測 SSR分散0pt 67.6%→14.6% | cloud済 | 【完了 2026-07-05・T5】cap24へ修正・再測でcanonical目標13.3%圏へ復帰=「贅沢品」化。残: exp_dynasty_matrix:22/exp_renpa:26のcap30も別途整合(experiment-only) |
| high | exp_neta非情報的でネタ資産係数(0.04)が実質未検証 | バランス | sim_career.py:205-216 / exp_neta.py:42-54(弱ボットのみ) | fable | exp_netaを決勝到達30-40%帯ボット(PSpread等)でも回し決勝突破率差で較正 |
| high | セーブ/中断復帰が実質未実装、CodableテストがGameState+RNGだけで「土台完成」の誤った安心感 | 技術 | WeekRunner.swift:55-79(非Codable進行状態) / CodableTests / GameSession(save/load不在) | 4.8-cloud | WeekRunnerをCodable化 or (seed+アクション列)リプレイ方式を設計決定しsave/restore実装。決定までdoc表現を「部分的」へ訂正 |
| high | WeekRunnerのresolve*にPhase照合preconditionが無く、UI二度押しで週末処理が二重実行され得る(生活費二重徴収) | 技術 | WeekRunner.swift:131-252,255-316,309-315 / WeekMainView.swift:97-107 | 4.8-cloud | 各resolve*冒頭にpending存在preconditionを入れ不一致はno-op。UI側もphase遷移までボタンdisable。冪等性の回帰テスト固定 |
| high | iOSアプリ(ManzaiGame)がCIで一度もビルドされず、UI崩れ/S1・S4・S5のコンパイル破壊が素通り | 技術 | ci.yml(xcodebuild無) / project.yml と pbxproj 二重管理 | cli-mac | macランナーで`xcodegen generate`→`xcodebuild build`(署名OFF)追加。pbxprojをgitignore or xcodegen廃止で二重管理解消 |
| high | ファンレポ156/200で-44本、かつ再表示禁止×最長25年で最頻出画面(王者編5本/決勝実況9本)が枯渇 | コンテンツ | fan_report レジストリL137-148,§1.30 / content_batch5 #66-79 / master_spec L11 | fable | 200本まで+44本量産(王者編/決勝実況帯を各20本目安に優先補充)。枯渇時挙動(無口化/再表示解禁/低頻度化)を仕様化 |
| high | 日常雑談70本(売れっ子帯わずか6本)で「6年目以降無口化」が構造的に発生 | コンテンツ | dialogue_batch2 §2,§92 / batch3 #11-50,L197 / content_batch5 §3 | fable | 帯ごとに「年数×頻度」から必要本数を逆算目標化(売れっ子帯25年想定で最低30本)。長期滞在帯を優先増産 |
| high | 予選紙講評32本、回戦帯別プール5〜8本で毎年同回戦通過だと数年で反復(10年で最も多く読む文章) | コンテンツ | judge_comments_v1 §1 L26-70,§5 L132 | fable | 各回戦帯×通過/敗退を「到達確率×年数」で見積り増産(通過帯各15-20本)。特に3回戦〜準々通過(現5本)優先 |
| high | 自社見立てでB案が買い切りA案に売上2〜4倍劣後(B優位はDL10万超のみ・到達手段なし) | 事業 | red_team §2売上テーブルL51-58 | owner-decision | 業態決定前に事前登録・ティザーPVで需要絶対量を計測。DL10万の現実性を数字で確認し無ければ買い切り/ハイブリッドを既定に |
| high | 資金決済法・前払式支払手段リスク(iOSで6ヶ月除外不可、ヒット時に届出＋供託が確実発生) | 法務 | legal_risk §1(1-e),§5,§6-2 / red_team §2 | research | 業態決定初期に「有償通貨を介在させるか」確定。B案続行なら弁護士確認を必須イベント化(罰則条番号・未使用残高算定・消費型IAP直付与の非該当性照合)。都度課金/買い切りは退路 |
| high | 景表法・ガチャ確率表示リスク＋動的確率(気になるリスト×ピックアップ)の事故点と実装コスト未計上 | 法務 | legal_risk §2(2-g,2-h) / monetization §7 / red_team §2 | research | 実確率=表示文言を保証する検証プロセスと母数/実数値明示UIを工数計上。JOGA/CESAガイド最新版を弁護士照合。ガチャ実装時に弁護士確認を必須ゲート化 |
| high | 「運営レス/サーバレス」前提が有料石導入で崩壊(レシート検証・名鑑同期・時刻管理で最小BE必須) | 事業 | monetization §6-4 L65 / red_team §2 | owner-decision | 有料石を持つなら最小BE+CS+審査の恒常運用コストを事業計画に明記。持たない(買い切り/都度)ならサーバレス維持——この二択を業態決定に統合 |
| high | キャラ供給トレッドミル(収益生命線)に対し個人開発の供給計画が未確立(月1体の根拠レス) | 事業 | monetization §6-2 L70,§7懸念#1 / red_team §2 | owner-decision | 1体あたり実制作工数を試作で実測し持続可能ペース(月1/シーズン制)を数字確定。無料コンプ速度と突合し名鑑寿命の下限保証 |
| ✅解決(cloud) | ハマった夜の到達率が別ライン(76/82)混在で二重掲載 | 整合 | canonical §2/§4上書済(74/80: 41.5%/23.1%/8.4%) ⇔ human_calibration §5-C・master §1 も更新 | cloud済 | 【完了・#7/#33と同件】74/80で一本化・旧76/82値は失効注記。他doc(human_calibration等)もポインタ/更新済 |
| ✅解決(owner④) | finals点差表示の是非(点差非表示 vs Δ表示の半矛盾) | 整合 | owner④=M-1全表示で確定 → finals §冒頭/§5-2/§4-D・champion_selection §6-5・talent_unlock §で整合済 | owner済 | 【完了】オーナー④「M-1式で全組表示」を裁定。表示点≠内部スコアで逆算回避。旧「点差非表示」は全doc撤回済 |
| medium | 研究されるデバフ(飽きられ/波乱/客層二層)が旧スコアスケール(86/94)較正のまま未再計測 | バランス | sim_career.py:171-179 / v2圧縮 canonical §1 / exp_challenger旧基準 | fable | AUDIENCE_K/BOREDOM_PEN/UPSET_DELTAをv2ライン(74/80・0.55圧縮)で再走。（旧「BOREDOMを王者特権dynastyに組込む」は王者編廃止で不要） |
| medium | H3(体力<10で-15)が「再計測して判断」の保留ゲートを踏まず無記録で正典化 | バランス | rule_holes §5 / balance_sim.py:79 STAM_PEN / canonical §4に記載なし | fable | H3 -15のON/OFFでexp_v2_anchor差分測定しアンカー感度を数値化。rule_holes §5の決着をcanonical §4検証台帳に明記(看板数値ドリフトの原因切分にも使用) |
| medium | gen_goldenとsim_careerがrun_yearを二重実装=正典順序ドリフトの恒常リスク、王者年はgolden非カバー | バランス/技術 | gen_golden.py:59-152 / sim_career.py:350-526 / gen_goldenは非優勝3年のみ | 4.8-cloud | gen_goldenをsim_career.run_yearの薄いラッパへ寄せ単一実装化 or 週次スナップショット一致をCIに追加。裏天井導入前に解消（王者特権は廃止で不要） |
| medium | GP決勝優勝時にS3結果画面が丸ごとスキップされ「通過」演出とweekResultsが破棄(夜逃げも同様) | 技術 | WeekRunner.swift:198-207 / GameSession.swift:71-99 | owner-decision | 優勝・夜逃げでも最終StageResultをUIへ届ける経路を用意。優勝の通過スタンプを出すかYearResultViewに集約するかは演出方針裁定 |
| medium | gpSeeded=true(1回戦免除シード)の実行パスがどのテストでも一度も通っていない | 技術 | WeekRunner.swift:88-102,266-276 / CareerGoldenTests:122-133(非発生自認) | 4.8-cloud | gpSeeded=trueで1回戦(week30)が発生せず2回戦(week39)開始を直接検証する単体テスト追加 |
| medium | 体調ダウン(injury/療養)ロジックがSwift側で完全に未テスト | 技術 | WeekRunner.swift:227-233,298-301 / Testsに該当なし | 4.8-cloud | SeqRandomで発生drawを固定し①発生時completeRest+メンタル-5+recoveryWeeks=2 ②翌2週強制療養でオファー無効 ③計3週で復帰、を検証。tools側INJURY定数と同値固定 |
| medium | 状態の正がrunner.state/session.state/Phase埋込stateの3箇所に分散しdesyncしやすい(値型順序ハザード) | 技術 | GameSession.swift:14-38,71-99 / WeekRunner.swift:26-38 | 4.8-cloud | UIが読むstateを「runnerから写した唯一の派生」に一本化。pump後にrunner.stateとsession.stateの一致をassertする開発時チェック |
| medium | 決勝審査コメントが審査員×帯あたり実質3〜4本で、王者編の連続決勝進出で7人全員反復 | コンテンツ | judge_design 本体・§10-B/E/§166 / judge_comments_v1 §2 | fable | 王者編で最頻出のB帯(+C帯)を審査員ごと増量(現3-4→各8本)。票割れ演出/条件フックで見かけの多様性を併用 |
| medium | コンテンツ数量目標が数値化されているのはファンレポ(200)だけで、他は「十分か」の基準が無い | コンテンツ | fan_report L134 / dialogue_batch3 L197 / judge_comments §5 / master_spec L11 | owner-decision | 全カテゴリ横断の在庫計画表を作成(列=想定年数1年/10年/25年、行=カテゴリ×帯、値=必要本数/現在数/枯渇年)。MVP(1年)は本編/周回フェーズ限定タスクに切出 |
| medium | モブコンビ名50組が最長25年の毎年決勝ボード充填には不足の可能性、枯渇時/年跨ぎ再利用ルール未定義 | コンテンツ | content_batch5 §2,§143 / master_spec L11 | fable | 年跨ぎ再利用ルール(同一決勝内一意/年跨ぎ可 等)を明文化。25年想定で不足なら100組へ増産。実在名突合を弁護士確認リストへ |
| medium | 需要の絶対量が未計測のまま課金・供給設計が先行(お笑い題材の商業実績ほぼ皆無・実在大会名使用不可) | 事業 | red_team §2・推奨3 / monetization §7懸念#5 / roadmap §5-1 | owner-decision | 検証①ビルドの手応え＋事前登録数を課金実装より前に取得。需要計測をロードマップP0/P1へ昇格し、業態と値付けを後に確定 |
| medium | ストア手数料・審査の未確認前提(Apple手動エンロール漏れ=30%、Google2026新体系で日本に5%別途の可能性) | 法務 | legal_risk §3(3-d,3-e,3-i,3-h),§6-2 / roadmap §4-2 | research | Apple Small Business手動エンロールをリリース前必須項目化。Google2026新料金の日本適用日・billing fee5%可否・新規個人アカウントのテスト要件を一次資料確認しP/L反映。事前予約はビルド完成後のみ |
| medium | 商標・パブリシティ権：架空化の網羅性チェックとマーケ表現の事前レビューが未実施の残タスク | 法務 | legal_risk §4(4-a,4-b,4-f,4-g),§4-4 / roadmap §4-1 / red_team §2 | research | リリース前に(1)全架空名のJ-PlatPat商標実査＋弁護士「特定の実在を想起するか」テスト (2)似顔絵/経歴/決めゼリフまで含む網羅性レビュー (3)マーケ素材の事前レビュー。AI生成は実在人名プロンプト禁止＋目視検品 |
| low | champion_selection §7のJSON例が§2マスタ表と矛盾(9年目champion=静物画 vs 表=モブ)＋Salt.mobDrap誤記 | 整合 | champion_selection §7 L275 ⇔ §2 L66,§7 L283 / §4-4 L198,L207 | 4.8-cloud | §7 JSON例を正しい出力(年6=金字塔 or 谷の年=モブ)に差替。§4-4を「drawMobs1回で総数引き先頭をchampion割当」の単一抽選へ書換しmobDraw誤記修正 |
| low | 王者編ゲート18ptとcanonical王者マトリクスの15pt行が不整合(15pt総量では18ptゲートを開けない) | 整合 | master_spec §4-1 L58,§5 L72,§10未決7 ⇔ canonical §2-B(15pt行) | 4.8-cloud | マトリクス下限行を18pt(ゲート値)へ揃える or 15pt行に「※ゲート18pt未満・参考値」注記。有効レンジ18〜30ptをcanonicalに1行明示 |
| low | 審査員個人名(神楽坂とんぼ等)がneta_system §4に登場、judge_design正式7名リストとの綴り/採用状態が未照合 | 整合 | neta_system §4審査員相性表 ⇔ master_spec §10-4(審査員は味付けのみ) / finals §2-2,§4-C(順序一致) | 4.8-cloud | judge_design正式表記とneta_system §4個人名をクロス照合。netaフェーズ2「相性が実スコアに±乗る」がjudge §0「味付けのみ」の格上げになる点をネタ資産採用判断のオーナー確認事項に明記 |
| low | MVP 1年版のv2体感がcanonical §4で⛔未検証のまま(フリップは完了扱いだが確認記録なし) | バランス | canonical §4最終行 / §3-1〜9フリップ完了 | cli-mac | balance_sim単体で1年48週×分散/のんびり/バランスの実力値・体力・所持金推移を出力。48週到達値と上限6.0の頭打ち有無を検証①の前提数値として記録 |
| low | 起動時の初回プレイが常に固定シード424242で全プレイヤー・全再起動が同一展開 | 技術 | RootView.swift:7 / GameSession.swift:29 | owner-decision | 初回もランダムシードにするか固定にするか方針明記。再現デバッグ用にシードをリザルト画面等に表示/保存する小機能を検討 |
| low | 「ビット一致」を謳うparityが実際は1e-9許容の近似一致で、真のビット一致は担保していない | 技術 | CareerGoldenTests:90-101(acc=1e-9) / WeekRunner.swift:4・ci.yml コメント | 4.8-cloud | 表現を「1e-9一致」に正す or 能力値を丸めず文字列/ビット比較する厳密モードのテストを1本追加し主張と実装を一致 |
| low | WeekSummary/StageResultが非Codableで、S3結果を跨いだ保存・リプレイの器が無い | 技術 | WeekRunner.swift:8-38 / GameSession.swift:22 | 4.8-cloud | セーブ設計決定時にWeekSummary/StageResultもCodable化しS3中断点を含めて永続化可能に |
| low | 充足カテゴリ(ネタ題材100・トロフィー文22/22・ライバル4組)は現状問題なし——ただし前提条件付き | コンテンツ | neta_catalog §2/§49/§51 / trophy_flavor §2/§3 / rival_scripts 全体 | research | 在庫計画表上「完了」と明記し量産リソースを枯渇リスク帯(雑談売れっ子・紙講評通過帯・王者編レポ)へ集中。谷口の題材コメントのみ1本→3本に薄く増(低優先) |
| low | 未成年課金配慮・持ち越し無しの罪悪感設計・広告方針・名称確定・初回2倍規約の最終確認が未決の運用細目 | 事業 | pricing §8 / monetization §7懸念#2,#6,#7 / roadmap §4-2,§4-4 | owner-decision | リリース前チェックリスト(roadmap §4)に未成年課金/月額パス年齢配慮・通知文言トーン監修・広告方針・名称確定・初回2倍規約確認を明示項目化しガチャ実装時の弁護士確認1回に合流 |

---

## 3. owner別 集計（マージ後 全46件）

| owner | 件数 | 内訳(重大度) | 主な守備範囲 |
|---|---|---|---|
| **4.8-cloud** | 15 | critical1 / high4 / medium4 / low6 | ドキュメント数値整合、Swift実装の堅牢化(precondition/Codable/テスト)、二重実装解消 |
| **owner-decision** | 12 | critical2 / high4 / medium3 / low3 | 業態確定、収益モデル、演出方針(点差/優勝S3)、在庫計画スコープ、運用細目 |
| **fable** | 12 | critical1 / high6 / medium2 / (裏天井は整合次元と統合) | 王者特権実装＆再測、裏天井統合、SSR/ネタ/デバフ/H3較正、枯渇カテゴリ量産 |
| **research** | 5 | high2 / medium2 / low1 | 資金決済法、景表法/ガチャ表示、ストア手数料、商標・パブリシティ権、充足在庫の完了確定 |
| **cli-mac** | 2 | high1 / low1 | iOSアプリのCIビルド追加、MVP1年版のbalance_sim体感確認 |

**重大度別 総計:** critical 4 / high 18 / medium 15 / low 9（＝46件）。

### 統合メモ（マージ内容）
- 「裏天井」は設計整合性次元(2案未統合)とバランス次元(実装ゼロ・実測ゼロ)の2指摘を1件へ統合（owner=fable, high）。
- 「正本数値の非再現」は2件を別懸念として保持: (a)master_spec本文の旧値残存＝doc書換問題(4.8-cloud) と (b)canonical看板数値がsimで再現しない＝検証台帳問題(fable)。原因層が異なるため非マージ。
- 決勝ライン不一致(整合)と決勝到達率二重掲載(整合)は関連するが評価軸が違うため別行維持。

### 既知の未決（オーナー裁定待ちの後戻り困難点）
1. **業態(B案F2P vs 買い切り/ハイブリッド)** — 全収益・法務・供給設計の分岐点。critical2件＋high4件がこれに従属。
2. **裏天井の採否とトリガ/効果式** — 初回体験の芯。Fable待ちの本命(P0)。
3. **finals例示 vs rival年表**(ミラーボール/静物画の優勝扱い) — 年表改訂 vs 例示訂正の二択。
4. **点差(相対Δ)表示の可否** — 逆算誘発リスクの許容判断。
5. **コンテンツ数量目標の未定義** — 在庫計画表がファンレポ以外に存在しない。
