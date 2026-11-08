# 通知の静的点検 2026-11-08 v0

**結論**
1. 通知の「予約」は本体に1本も無い（UNNotificationRequest・removePending・badge は grep で0件）。許可要求 `requestAuthorization`（IntroFlow.swift:756）だけが残り、それも呼ぶ画面が導線から外れている＝今は通知が一度も出ない。重複・取り消し漏れ・古い文・バッジ残りは構造上起きない。
2. 既知：docs/code_review_2026-10-19f.md の通知節、docs/playtest_v17_first_hour_1107.md（5-1 / 休眠の結論）と同じ結論。新しい穴は無し。
3. 実装する時の宿題を下表にまとめた（判断は「いつ通知を出すか」＝オーナー）。今すぐ直す物は無い。

点検方法：`grep -rn "UNUserNotificationCenter|UNNotificationRequest|removePending|removeAll|setBadgeCount|applicationIconBadgeNumber|UNMutableNotificationContent"` を ManzaiGame/Sources に実行。plist / entitlements にも通知用の設定は無し。

| 観点・場面 | ファイル:行 | 今の挙動 | 問題 | 直すならの案 | 判断が要るか |
|---|---|---|---|---|---|
| 1 重複予約 | （予約コード無し） | 予約しない | 該当なし | 実装時：identifier を固定（例 `mz.tournament.<年>`）し、予約前に `removePendingNotificationRequests` | 要（何を通知するか） |
| 2 キャリア終了・解散・新しい周・セーブ削除 | RootView.swift:326 付近（セーブ削除は GameSession 側）ほか | 取り消す物が無い | 該当なし。ただし実装後はセーブ削除・「この年をやめる」で通知が残る | セーブ削除と新周開始の入口で全 pending を一括 remove | 不要（実装時に必須） |
| 2 設定で通知オフ | 設定画面に通知の項目は無し | なし | 実装後、iOS 設定で切った人に再度案内が出せない | `getNotificationSettings` を見て、拒否なら予約しない・画面に案内を出さない | 要（案内を出すか） |
| 3 許可を断った／後で切った | IntroFlow.swift:754-758 `allow()` | `notif_asked=true` にして結果（granted）を捨てる。断っても二度と聞かない | 聞かない点は良い。granted を見ないので「断られた」状態を持てない | granted を保存せず、予約の直前に `getNotificationSettings` で毎回確認 | 不要 |
| 3 「あとで」 | IntroFlow.swift:759-762 | 7日後に1回だけ再表示（`shouldShow()` は :747） | `shouldShow()` の呼び出し元が無い（休眠）。復帰時、7日後にまた聞く＝「何度も聞かない」は満たすが、期限後は無限に出る可能性（asked は allow でしか立たない） | 「あとで」は1回きりの印（`notif_later_done`）を立てて2回目以降は出さない | 要（再表示の回数） |
| 3 導線 | IntroFlow.swift:852-856, :773 | `stage = .notif` の代入が無く到達不能。MZ_UI=notif（RootView.swift:69）で画面だけ開ける | 通知が無いので問題なし | 実装時に導線へ復帰 | 不要 |
| 4 文が状態とずれる | IntroFlow.swift:714 | 「大会の開演前に、お知らせします。」の固定文（画面のみ） | 通知本体が無い間は空約束（既知：code_review_2026-10-19f）。画面は出ないので実害なし | 実装時は文面を発火時に作らず、「大会が近い」程度の汎用文にするか、通知は日付だけ予約して中身は固定文 | 要（文面） |
| 4 予約時の値の焼き込み | （予約コード無し） | なし | 実装後：コンビ名・順位・残り週数を予約時に文へ入れると、発火までに変わる | 通知文は状態を含めない／状態が変わる節目で必ず再予約 | 不要（方針） |
| 5 バッジ | （badge の設定コード無し） | 付けない | `requestAuthorization` のオプションが `[.alert, .sound]` でバッジ無し＝バッジは出ず、消し忘れも起きない | バッジを使う予定なら `.badge` を足し、起動時に `setBadgeCount(0)`。使わないなら現状維持 | 要（バッジを使うか） |

判断不要で今すぐ直せる件数：0（休眠のため直す対象が無い）。
