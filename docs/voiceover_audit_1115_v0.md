# 読み上げ（VoiceOver）点検 voiceover_audit_1115_v0（2026-11-15・読み取りのみ・コード未変更）

見方：11/09 以降に変わった 24 ファイルの差分（+行とその周り）と、1109 の指摘箇所を今のコードで grep して読んだ。実機の VoiceOver は未確認＝コードを読んだ推測。

## §1 要約3行
- 11/09 以降の差分で新しく入った読み上げの穴は小さい（中1・低3）。文字の無いボタンの label 抜けは 0 件。
- 1109 の指摘 #1〜#12 は **すべて未対応のまま**（`accessibilityAction` は FinalsBroadcastIntro:612 の既存 1 件のみ）。#14（CharacterFace の hidden）も未対応。
- 新規の主な点：S6b の「透明なボタン」が読み上げには出る／カレンダー凡例の記号が二重読み（「仕」を足して 4 組に増えた）。

## §2 指摘
| # | 重さ | ファイル:行 | 何が起きるか（推測） | 直し方の案（表示・読み上げだけ） |
|---|---|---|---|---|
| N1 | 中 | S6bView.swift:235-239 | 11/15 の直しで `.opacity(burned ? 1 : 0)` ＋ `.allowsHitTesting(burned)` になった。見た目と押下は塞がったが、読み上げの木には透明の間も「finishLabel」ボタンが残り、0.8 秒の焼き付き前から読まれる。VoiceOver の起動操作は hit test を通らない可能性があり、`finished` の守りに頼る形 | ボタンに `.accessibilityHidden(!burned)`（または `.disabled(!burned)`）。同じ並びの Text「楽屋の壁。最後の舞台の夜。」(:233) も `.accessibilityHidden(!burned)` |
| N2 | 低 | CalendarView.swift:133-138 | 凡例が `Text(cat.label.prefix(1))`（記号）＋ `Text(cat.label)` で、「練」「練習」のように 2 回読まれる。今回 `.offer`（仕）が足されて 4 組に。CalendarView には accessibility 指定が 1 つも無い | 記号側の Text に `.accessibilityHidden(true)`、または HStack に `.accessibilityElement(children: .combine)` を付けず記号だけ hidden |
| N3 | 低 | WeekMainView.swift:1444（toastBar）／:338 `.task(id: toastSeq)` | toast は文字として出て 1.4〜4.5 秒で消える。読み上げの通知（`AccessibilityNotification.Announcement`）が無く、フォーカスが別の所にあると聞き逃す。toastSeq で同文再表示は直ったので、通知の足しどころが作りやすくなった | `toast` が決まった所（showToast :1458 付近）で announcement を 1 回出す案。読み上げ中のみ |
| N4 | 低 | GachaView.swift:218-220 | 11/15 の直しで label が「◯◯、着用中」に、isSelected も付いた＝問題なし寄り。ただし未入手は「未入手の衣装」だけで、カード名のレア度（`o.rarity?.label`）が画面には出るのに読まれない | 未入手の label にレア度を足す（表示と揃える）。任意 |
| N5 | 低 | FinalsPresentationView.swift:173, 1016 | `.disabled(holdingSeventh)` で押せない見た目と読み上げ（「使用不可」）は揃っている＝観点3は問題なし。ただし溜めの間、ボタンだけ無効で画面全体タップ（送り）側は別処理か未確認 | 実機で、溜め中に VoiceOver で押せるか確認（推測のみ） |
| 1109#1 | 高 | IntroFlow.swift:84 | 未対応。結成カードの送りが無言 | `.accessibilityAction(named: "次へ")`（同ファイル :850 付近の最後のカードは「始める」等） |
| 1109#2 | 高 | ChoiceEventOverlay.swift:107 | 未対応 | action 足し |
| 1109#3 | 高 | TournamentResultView.swift:644 | 未対応（行が 643→644 にずれただけ） | action 足し（最後の 1 枚は「閉じる」） |
| 1109#4 | 高 | S6bView.swift:207 | 未対応 | `.accessibilityAction(named: "次へ")` |
| 1109#5 | 中 | FinalistAnnounceView.swift:108 | 未対応 | action 足し |
| 1109#6 | 中 | FinalsBroadcastIntro.swift:57 | 未対応（同ファイル :601 は :612 で済み＝不揃いのまま） | action 足し |
| 1109#7-#11 | 中 | Design/YoseChampionCelebrationView:172／YoseRankUpOverlay:113／YoseMilestoneFX:146／YoseYearTurnCurtain:134／StageFrame:291 | 未対応（各 onTapGesture の行は不変） | 各 1 行の action 足し |
| 1109#12 | 低 | AbilityUpView.swift:86 | 未対応（85→86） | action 足し、または透明面を hidden |
| 1109#13 | 判断 | TournamentResultView.swift:214, 249 | 未対応（判断待ちのまま） | 送りの別手段があるか実機確認 |
| 1109#14 | 低 | CharacterAvatars.swift:30（CharacterFace） | accessibilityHidden 未対応 | body に `.accessibilityHidden(true)`（名札が別に読まれる所のみ） |

## §3 問題なしと確かめた所
- 観点1：差分内に Image/SF Symbols だけで label 無しのボタンは無い。WeekMainView の下帯（日程・コンビ・設定）は YoseFooterItem 経由で title が label になり、記号は :171 で hidden 済み。ShareCard の `.hidden()` 枠は `accessibilityHidden(true)` 付き（枠だけ・読まれない）。
- 観点3：FinalsPresentationView の `.disabled(holdingSeventh)`、IntroFlow:570 の `.disabled(decided)` は実際の disabled なので「押せない」と伝わる。S6b を除き、押せない見た目だけで押せる物は見つからず。
- 観点4：Gacha 札は label で子を置き換えるので二重なし。YoseVitalMoneyBar は 1109 時点どおり label 済み。RentStatement の「−0」直し・FanReportData・QualifierNotice の seed 変更は読み上げに影響なし。AbilityUpView の確認ダイアログ message 追加は標準 alert で問題なし。
- 変更のあった GameSession／Meta／RootView／SettingsView／AdProvider／GachaStore／YearResult／ShopView／NetaStage は表示文・内部処理の変更で、読み上げ上の新規の穴は見つからず（DEBUG 専用フックを含む）。
