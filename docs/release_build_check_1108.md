# 発売用ビルド点検（11/08・ソース無変更・commit なし）

## §0 要点
- Release（generic iOS Simulator）ビルドは**成功**（error・unused 警告ゼロ）。.app 59MB（実行ファイル 38MB・音声 7.3MB・フォント 14MB）。
- `strings` で Release の実行ファイルに `^MZ_` は**0件**＝開発フックは発売版に残らない。
- 重さ別：発売の妨げ 3件（署名・URL・アイコン）／中 2件／低 5件。最重＝**AppIcon が空（画像なし）**（既出・checklist 手順6）。

## §1 ビルド
コマンド指定どおり実行。grep 出力は空＝error なし。ただし `AppIcon.appiconset` に PNG が無い（Contents.json のみ）。シミュレータ向けでは通るが、実機の archive では不足になる（既知のアイコン未設定）。

## §2 開発用の仕掛け
`#if DEBUG` の外にある MZ_／print／fatalError／debug 関数を、DEBUG ネストを数えるスクリプトで抽出（コメント行は除外）。
- MZ_ 環境変数の読み取り：**囲い漏れなし**（コメント内の言及のみ）。strings でも 0 件で裏取り済み。
- fatalError・`as!`：本番経路に**なし**。
- `try!`：GameSession.swift:1898 の1箇所のみ。`#if DEBUG`（1768〜1932）の内側＝本番に入らない（確認済み）。
- 強制アンラップ `!`：正規表現の grep は拾い切れず**未確認**（推測の域。クラッシュ点検は別途が必要）。
- 指摘：
  1. 【低・確認済み】GameSession.swift:1333・1346 `print("[save] ...")` が DEBUG 外。セーブ失敗時のログのみで害は小さい。Release でも出る（コンソールのみ）。
  2. 【低・確認済み】FinalsBroadcastIntro.swift:15 `static func debug(_:)` が DEBUG 外。呼び出しは DEBUG 側のみ（推測）。バイナリ影響は極小。
  3. 【低・確認済み】WeekMainView.swift:122 の空 `debugWeekHook()` と、:266 の呼び出しが本番に残る（空関数・無害）。

## §3 Info.plist／project.yml／PrivacyInfo
| 項目 | 実態 | 判定 |
|---|---|---|
| バンドルID | com.manzaigame.mvp（`mvp` の語が残る。StoreIDs.prefix も同値） | 中・確認済み：商品IDにも焼かれるため、変えるなら App Store Connect 登録前に |
| バージョン／ビルド | 0.1 ／ 1 | 低：初回提出なら 1.0 が一般的（要判断） |
| 向き | Portrait のみ | OK |
| 対応OS | iOS 17.0 | OK |
| 端末 | iPhone のみ（UIDeviceFamily=1） | OK（iPad 非対応と申告を揃えること） |
| ITSAppUsesNonExemptEncryption | NO | OK（通信・独自暗号なし） |
| 権限の説明文（Usage） | 無し | OK（不要なものも無い） |
| 署名 | `CODE_SIGNING_ALLOWED: NO` | 発売の妨げ・確認済み：archive 前に署名ありへ戻す／Team 設定が要る（checklist 手順に既出：署名） |
| entitlements | iCloud KVS（ubiquity-kvstore-identifier） | 中・確認済み：実機で Team 署名＋iCloud 能力が無いと効かない。`store_listing_draft_v0 §6` の「iCloud なし」行が古い（11/07 に実装済み＝申告文の修正が要る） |
| PrivacyInfo | 追跡なし・収集なし・UserDefaults CA92.1 | OK。iCloud KVS は理由コード不要 |
| 通知 | IntroFlow.swift:751 に `requestAuthorization`。導線は `case .notif`（:843）が残る | 低・確認済み：`.notif` への遷移は IntroFlow 内に無く到達不能（コメントも休眠温存と明記）。コードと許可呼び出しが残るだけ（§6 要対応2に既出） |
| プライバシーポリシーURL | `AppInfo.privacyPolicyURL = nil`（SettingsView.swift:218） | 発売の妨げ・確認済み。store_listing §6 要対応1に既出 |
| 暗号以外の plist | UILaunchScreen あり・DisplayName「漫才王になろう」 | OK |
| .storekit | scheme の StoreKit 設定のみ。.app に同梱されない | OK |

## §4 文言の開発印
- プレイヤーに見える `【仮】`：GachaView.swift:137、GachaRatesView.swift:19・22・26・28 → **既出**（キュー142）。
- 「デモ」「テスト」「ダミー」「TODO」を含む表示文字列：**なし**（"…" リテラルを grep）。
- Info.plist の表示名・設定画面に「v0」「beta」等：なし。

## §5 リソース
.app 総容量 59MB（実行ファイルは Simulator 用で未 strip。実機 archive では小さくなる見込み＝推測）。
使っていない物（SoundManager 等で参照 0）は**無し**（全 mp3・全 ttf が参照あり）。大きい順：
1. MPLUSRounded1c-Black.ttf 3.6MB（使用）
2. MPLUSRounded1c-ExtraBold.ttf 3.6MB（使用）
3. MPLUSRounded1c-Bold.ttf 3.5MB（使用）
4. MPLUSRounded1c-Medium.ttf 3.4MB（使用）
5. bgm_daily.mp3 2.7MB（使用）
低・推測：フォント4本で約14MB。使う字だけに絞る（サブセット化）と大幅に減らせるが、日本語の字抜けに注意（発売の妨げではない）。

## §6 まとめ（重さ別）
- 発売の妨げ（3）：AppIcon 画像なし（既出）／署名無効設定（既出）／プライバシーポリシーURL nil（既出）。
- 中（2）：バンドルIDの `mvp` 語／iCloud 実装後の申告文の食い違い（store_listing §6）。
- 低（5・休眠中の通知許可コードを含む）：Release に残る print（セーブ失敗）／debug 関数1つ／空フック／バージョン 0.1・フォント容量。
- 問題なし：MZ_ 残存0・fatalError なし・try! は DEBUG 内・向き・OS・端末・暗号申告・Usage 文なし・PrivacyInfo 理由コード・使用音声すべて参照あり。
