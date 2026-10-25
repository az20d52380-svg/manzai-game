# 懸念の台帳 棚卸し 2026-10-25 v0

対象: docs/concerns_register_v0.md の表38行（コードは無変更・台帳は無編集）。根拠は grep ベースの短い確認で、「記録なし」はAUTOPILOT/AUTOPILOT_done/START_HEREに決着の記録が見つからない意味。

## 集計

解消 4／一部解消 9／未解消 15／判断待ち 10（計38）

## 未解消で判断不要のもの 上位5件（次に自走で手を付けられる物）

1. #38 CIに xcodebuild を足す（ci.yml・xcodegen→build。cli-mac）
2. #50 H3（体力<10で-15）のON/OFFで exp_v2_anchor 差分測定→canonicalに記録
3. #67 「ビット一致」表記を「1e-9一致」に直す（WeekRunner.swift L4・ci.yml L21のコメントのみ）
4. #49 研究デバフ（AUDIENCE_K等）を現スコアスケールで再計測
5. #39 ファンレポ増補（62→200・帯別の枯渇画面から）

## 全行

| 台帳行 | 重要度 | 懸念（20字） | 判定 | 根拠 |
|---|---|---|---|---|
| L29 | high | 裏天井2案並存・未実装 | 判断待ち | START_HERE L56「裏天井を入れるか」未決 |
| L30 | high | 決勝優勝ライン数値不一致 | 未解消 | AUTOPILOT/START_HEREに決着記録なし |
| L31 | high | finals優勝例とrival年表矛盾 | 判断待ち | champion_selection §9未決2（owner） |
| L32 | high | finals §4-C.5モブ旧30組 | 一部解消 | コードは50組・夜行列車差替済（done 33/57）。finals L116の文書修正は記録なし |
| L35 | high | exp_neta非情報的 | 一部解消 | done 50 neta_bonus_remeasure_v0（測定道具のみ）。決勝到達帯ボットでの較正は記録なし |
| L36 | high | セーブ/中断復帰未実装 | 解消 | GameSession.saveNow/SaveData/loadedOrNew・WeekSummary/StageResult Codable・CoverageRAppTests復元 |
| L37 | high | resolve*二度押しガード | 一部解消 | WeekRunnerにPhase照合なし（preconditionはyearのみ）。ManzaiGameTestsに二度押し系あり |
| L38 | high | iOSがCIでビルドされない | 一部解消（10/25 夕） | 差分は docs/patches/ci_app_build_L38.patch（app-build ジョブ・macos-15）。push のトークンに workflow 権限が無く拒否＝オーナーが `git am docs/patches/ci_app_build_L38.patch` で入れる |
| L39 | high | ファンレポ枯渇 | 一部解消（10/25 夕） | 15c9de0 で 54→161本（重複を除く数え）。200 には追いレポ・常連フック等まだ無いプールが要る |
| L40 | high | 日常雑談の無口化 | 一部解消 | dialogue_batch4で#71〜110増補・DialogueData約340行。帯別必要本数の算出記録なし |
| L41 | high | 予選紙講評の反復 | 一部解消 | done 30/32/34でプール増・年混ぜsalt・採点v7(○43△7×0)。回戦帯別の到達確率換算は記録なし |
| L42 | high | B案が買い切りに劣後 | 判断待ち | 業態未決（START_HERE L54） |
| L43 | high | 資金決済法リスク | 未解消 | research・対応記録なし（業態未決に依存） |
| L44 | high | 景表法・ガチャ確率 | 未解消 | research・対応記録なし |
| L45 | high | 運営レス前提の崩壊 | 判断待ち | 業態未決に依存（owner-decision） |
| L46 | high | キャラ供給の計画なし | 判断待ち | owner-decision |
| L49 | medium | 研究デバフが旧スケール較正 | 未解消 | AUDIENCE_K等の再計測記録なし |
| L50 | medium | H3体力-15が無記録 | 未解消 | canonical_v2_spec.mdにSTAM_PEN記載なし |
| L51 | medium | gen_goldenとsim_career二重実装 | 一部解消 | tools/check_golden_sync.py（ドリフト検出）あり。実装の一本化・王者年カバーは記録なし |
| L52 | medium | GP優勝でS3結果スキップ | 判断待ち | owner-decision |
| L53 | medium | gpSeeded実行パス未テスト | 解消 | WeekRunnerGoldenTests(prevStage>=3→gpSeeded)・RunCareer/Rift/CoverageUTests |
| L54 | medium | 体調ダウン未テスト | 一部解消 | CodableTests療養・SessionGap1025cTests等。発生draw固定の網羅は未確認 |
| L55 | medium | state正が3箇所に分散 | 一部解消（10/25 夕） | StateSyncTests：2年通しで入口を呼ぶごとに state と runner.state をバイト比較＝ずれ0（アプリ 167 green）。一本化の作り替えはしていない |
| L56 | medium | 決勝審査コメントの反復 | 一部解消 | 書き直し6d60f1f（決勝112＋事情42＋状態18）。連続決勝での反復実測は記録なし |
| L57 | medium | 数量目標がファンレポのみ | 判断待ち | owner-decision |
| L58 | medium | モブ名50組の年跨ぎ再利用 | 判断待ち | AUTOPILOT L120に①②選択肢のまま |
| L59 | medium | 需要の絶対量が未計測 | 判断待ち | owner-decision |
| L60 | medium | ストア手数料の未確認前提 | 未解消 | research・記録なし |
| L61 | medium | 商標・パブリシティ未レビュー | 未解消 | research・記録なし。名称下調べ(app_name_prior_use_1025)のみ |
| L62 | low | champion_selection §7 JSON矛盾 | 解消（10/25 夕に確認） | §7 の例は6年目＝金字塔で§2表と一致・§4-4 は単一抽選（先頭を champion）・mobDraw 表記も正（L113/L141） |
| L63 | low | 王者編18ptゲートと15pt行 | 解消（10/25 夕に確認） | 王者編そのものが廃止（master_spec L58/L77/L140）・canonical §2-B の15pt行も取消線 |
| L64 | low | 審査員名の綴り照合 | 一部解消 | AUTOPILOT 116で神楽坂を重み表に反映。neta_system §4照合は記録なし |
| L65 | low | MVP1年版の体感未検証 | 未解消 | 記録なし |
| L66 | low | 初回固定シード424242 | 解消 | RootView L338 初回もランダムシード |
| L67 | low | ビット一致表記が近似(1e-9) | 一部解消（10/25 夕） | WeekRunner.swift L4 は既に「誤差1e-9以内」。ci.yml L21 の直しは L38 の patch に同梱（workflow 権限待ち） |
| L68 | low | WeekSummary/StageResult非Codable | 解消 | WeekRunner.swift L9,L33 Codable化済 |
| L69 | low | 充足カテゴリは前提付き | 未解消 | 10/14時点でトロフィー・ライバル台詞は未実装と記録（content_inventory §7）。再確認要 |
| L70 | low | 運用細目（未成年課金等） | 判断待ち | owner-decision |
