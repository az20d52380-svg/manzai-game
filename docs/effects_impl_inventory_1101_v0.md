# 演出 実装棚卸し（2026-11-01 v0）
対象：docs/effects_design_argon_v1.md §2（表は19行）と §5 TOP10 ／ ManzaiGame/Sources を grep のみで確認（読み取り専用・一部は目視未確認）。

## 表（§2 全19項目）
分類：接続＝本編に接続済み（簡易版含む）／DEBUG＝部品はあるが DEBUG のみ／無い

| # | 出来事 | 分類 | 根拠（ファイル:行）と備考 |
|:-:|:--|:-:|:--|
| 1 | ボタン押下 | 接続（沈み込みのみ） | Design/YoseComponents.swift:129 offset(y: pressed ? depth : 0)。スタイル内に Haptics/SE 無し（各画面で個別に Haptics.tick） |
| 2 | 練習の結果 | 接続（簡易） | WeekMainView.swift:300 particleFire / :399 SpeedLinesBurst |
| 3 | ハマった！ | 接続（大会の夜のみ） | TournamentResultView.swift:279 YoseBigSuccessCutIn。練習側は未確認 |
| 4 | 能力[+] | 接続（簡易） | AbilityUpView.swift:299 scaleEffect(bumped)・:303 Haptics.tick。行の金フラッシュは未確認 |
| 5 | 能力「確定」 | 接続（簡易） | AbilityUpView.swift:278 Haptics.confirm。斜光シマー（yoseLightStreak）は未使用 |
| 6 | ランクアップ | 外した | オーナー判断で外す（56d1f8c）。YoseRankUpOverlay は Design/YoseFXPreview.swift:18 のみ |
| 7 | お金の出入り | 無い | Design/YoseGameParts.swift:66 は素の Text。numericText は支払い画面(RentStatement.swift:90)のみ |
| 8 | 体力の増減 | 無い | YoseGauge（YoseComponents.swift:264）は在るが回復の光・朱残像の接続は未確認 |
| 9 | 知名度アップ | 無い | 『↑+6』札の接続を grep で確認できず（YoseCatalog.swift:75 の見本のみ） |
| 10 | イベント選択と結果 | 接続（簡易） | ChoiceEventOverlay.swift:171 判子「好調」 |
| 11 | 大会エントリー | 接続（判子のみ） | NotebookView.swift:328 判子「真剣勝負」 |
| 12 | 本番の開始 | 接続 | FinalsBroadcastIntro.swift:347-349 拍子木・太鼓 Haptics |
| 13 | ウケの波 | 無い | 本番中の座布団/笑い波紋の実装を確認できず（拍手は FinalsPresentationView.swift:478 の Sound のみ） |
| 14 | 判（通過/敗退） | 接続 | TournamentResultView.swift:283 YosePassCelebrationView・:321 太鼓＋紙吹雪 |
| 15 | 賞金獲得 | 接続（優勝時） | Design/YoseChampionCelebrationView.swift:376 yoseNumberPop（FinalsPresentationView.swift:216 から） |
| 16 | 決勝の開票 | 接続 | FinalsPresentationView.swift:1020 / :478-509 |
| 17 | 優勝 | 接続 | FinalsPresentationView.swift:216・:504-509、YoseChampionCelebrationView.swift:148 yoseShake |
| 18 | 年の幕間 | 接続（済 14cd79e） | RootView.swift:337 YoseYearTurnCurtainView |
| 19 | 借金の警告 | 接続（別形のみ） | WeekMainView.swift:214 モーダル・YoseGameParts.swift:65 タグ。設計の赤ビネット脈動は無い |

件数：接続済み14（うち簡易・一部のみ多数）／DEBUGのみ0／無い4／外した1（#6）

## §5 TOP10 の状況
1位 ボタン沈み+rigid+SE：沈みのみ接続、Haptics/SE はスタイルに未集約（部分）
2位 yoseNumberPop 一括：優勝画面のみ（YoseChampionCelebrationView.swift:376）。週メイン等は未適用
3位 [+]/確定の行フラッシュ＋LightStreak：LightStreak は優勝画面と DEBUG のみ。能力アップ画面は未接続
4位 判子叩きつけ+shake：判子は多数だが yoseShake は優勝画面のみ
5位 決勝の開票：接続済み
6位 優勝の紙吹雪+集中線：接続済み
7位 ランクアップ：外した
8位 ハマった！カットイン：大会の夜のみ接続
9位 年の幕間：接続済み
10位 体力残像・お金フロート：無い

## 未接続で効き目が大きい順の上位5つ
1. 全ボタン共通の Haptics+SE を YoseButtonStyle に集約（#1）：最も触る部分で、今は画面ごとにばらつき・無振動のボタンが多い。
2. yoseNumberPop の一括適用（所持金・能力値・知名度）（#2,#7,#9）：成長の実感の核で、現状は優勝画面にしか無い。
3. 能力アップの行フラッシュ＋確定時 yoseLightStreak（#4,#5）：育成の一番楽しい画面なのに部品が未接続。
4. お金・体力・知名度の増減フロート札と体力ゲージ演出（#7,#8,#9）：毎週の消費・収入が視線に出ず手応えが薄い。
5. 判子の叩きつけ＋yoseShake／ウケの波（#4位,#13）：結果画面の判子が静止気味で、本番中の客席反応も無い。
