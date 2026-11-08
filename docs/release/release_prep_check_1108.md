# 発売準備【C】の突き合わせ点検（2026-11-08）

## 要点3行
1. 掲載文・年齢区分・プライバシーポリシー・PrivacyInfo・課金ID・Info.plist を現行実装と突き合わせた。機能説明のずれは無し。文書の穴を3か所直した（コード・設定ファイルは変更なし）。
2. PrivacyInfo.xcprivacy（UserDefaults／CA92.1）は実際の使用と一致。ファイル日時・起動時間・ディスク容量などの必須理由 API は使っていない。ビルドは不要だったので回していない。
3. 残りの【C】は広告SDK・サイト公開・スクショ・アイコン・提出文面の流し込みで、いずれもオーナーの決定待ち（広告会社・URL・アイコン・バンドルID）。

## やった事（突き合わせ結果）
| 対象 | 結果 |
|---|---|
| 掲載文 app_store_text_ja.md ↔ 実装 | 一致：十五年（careerYears=15）／予選・準決勝・決勝／結末（夜逃げ・解散・続ける等8種／Endings.swift）／ログボ7枚で無料1回（loginGoal=7）／天井40pt（pityGoal）／ガチャ1回100円・10回1,000円／広告カットに衣装1着（黒紋付）付き／設定→購入に「衣装ガチャの提供割合」／ガチャ画面に「提供割合を見る」／縦向き・iPhoneのみ。**未実装：広告**（説明文は「広告が表示されます」と書いてある＝広告SDK実装前に提出しない） |
| PrivacyInfo.xcprivacy | UserDefaults の理由コード CA92.1（アプリ自身の設定の読み書き）は妥当。他の必須理由 API（ファイル日時・systemUptime・ディスク容量等）は Sources 内に該当なし。追跡なし・収集データなし（広告SDK導入前は正しい）。iCloud キー値ストアは必須理由 API の対象外 |
| Info.plist（生成物） | DisplayName／ITSAppUsesNonExemptEncryption=false／縦向き／iPhoneのみ／最低 iOS 17／LaunchScreen あり。ATT 文言（NSUserTrackingUsageDescription）は広告導入まで不要 |
| エンタイトルメント | iCloud kvstore のみ。実装（GachaStore の NSUbiquitousKeyValueStore）と一致 |
| 通知 | 許諾を求める導線は外れている（IntroFlow.swift:844 休眠）。通知の予約も無し。Info.plist に文言不要。ポリシー 2-6 の通知の一文は現状と矛盾しない |
| 課金ID ↔ Configuration.storekit | 4商品が完全一致（adfree／agency／ticket1／ticket10・種別 非消耗／非消耗／消耗／消耗）。値段：adfree 1,000円・ticket1 100円・ticket10 1,000円は掲載文・提供割合ページと一致 |
| 年齢区分 | 根拠（飲酒の台詞のみ・ガチャあり・広告あり）は現状と一致。Web確認で2026年に質問が増えていた（下記）ため行を追加 |
| 提出要件（Web 2回） | ① iOS 26 SDK 以降でのビルドが 2026-04-28 から必須→現ビルドは SDK 26.5／Xcode 26.6 で満たす。② 年齢区分の新質問：ソーシャルメディア（2026-07 追加・9月から必須）、位置情報の共有・出会い系（2026-11-16 から、2027-01-12 までに必須）。ルートボックスの扱いは検索では裏が取れず（引き続き提出画面で確認） |

## 直した物
- privacy_policy_ja.md 2-3：iCloud に保存している「購入の台帳（取引番号と付与回数）」の記述が抜けていた（GachaState.ledger が iCloud に載る）。1句を追記。
- age_rating_answers.md：2026年追加の質問（ソーシャルメディア／位置情報の共有／出会い・恋愛）の行を追加（答えは全て「なし」）。
- release_checklist.md 手順7：4商品の一致確認とSDK要件の点検結果を追記。

## 見つけた食い違い（直していない物）
- Sources/Store/StoreIDs.swift:11 のコメントが「広告カット 仮 480円」。実際の値段は Configuration.storekit／掲載文とも1,000円（コメントだけの誤り。コードに触れない指示のため未修正）。
- docs/store_listing_draft_v0.md:124,140 が「広告SDK未使用・StoreKitなし」の古い記述を一部含む（release/ 外の旧下書き。正本は release/ 側）。
- checklist 手順7は「商品＝広告カット・券1・券10」と書いていたが、コード／storekit には agency も入っている（UI なし）→追記済み、扱いは判断待ち。
- ※作業開始時点で ManzaiGame/Sources/RootView.swift に他者の未コミット変更があった。触っていない。

## オーナーの判断が要る物
1. agency（事務所選び 480円・UI未実装）を発売版の商品として App Store Connect に登録するか／外すか。
2. 広告SDKが入るまで掲載文の「広告が表示されます」と年齢区分「広告あり」をどう扱うか（広告会社の決定とセット）。
3. 広告会社・ATT を出すか（privacy_policy 2-4／PrivacyInfo／Appのプライバシー回答が連動）。
4. プライバシーポリシーURL・サポートURL・事業者名・問い合わせ先・特商法の住所の出し方。
5. アプリアイコン（AppIcon.appiconset に画像なし）とバンドルID（mvp が残る＝商品IDも連動）。
6. 通知機能を入れるか（入れないならポリシー 2-6 の通知の一文を削除、checklist の通知項目を閉じる）。

## 確かめられなかった物
- App Store Connect の実際の質問票の文言・自動計算される区分（ガチャ「あり」で上がるか）。
- Apple の最新のルートボックス／ガチャの審査上の扱い（検索で出ず）。
- 広告SDK導入後の PrivacyInfo／Appのプライバシー回答（SDK未決）。
- 実機・サンドボックスでの課金／復元／iCloud 引き継ぎ、スクリーンショット（シミュレータ操作は禁止のため未実施）。
- 掲載文の「ツッコミ擬音の有無」「講評に直せる一点」等の画面上の目視。
