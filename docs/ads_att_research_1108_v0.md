# 広告導入の材料集 v0（2026-11-08・調査のみ・決めない／コード変更なし）

> 検索 8 回＋公式ページ取得 3 回。法律・税の助言ではない。**日本の単価・SDK サイズ・最低入金額（円）は裏が取れなかった**（§1・出典の「未確認」参照）。既存資料：`privacy_policy_draft_v0.md`（今は「広告なし・収集なし」前提の本文）、`iap_design_v0.md`（広告カット買い切り・`AdProvider` 抽象化・広告会社は未定）。ここでは重複を避け、差分だけ書く。

## 結論の候補3行
1. 個人・日本・育成SLG なら、広告会社は「AdMob 単体（導入が最も簡単・公式資料が厚い）」が出発点。収益を伸ばしたくなったら後から MAX／LevelPlay へ（比較記事では MAX／Unity のほうがリワード・インタースティシャルで強いとされるが、単一ブログの主張で日本の数字は無し）。
2. ATT は「出さず、非パーソナライズ広告だけ」でも審査上は成立する（広告 ID が 0 でも動く・拒否しても機能を制限してはいけない）。代償は単価低下で、海外の調査では「同意あり／なし」で広告収益が約 4〜5 割違う（日本の数字は無し）。
3. 広告 SDK を入れると、プライバシー申告は「収集なし」から変わり、ポリシー本文・栄養ラベル・Privacy Manifest を全部書き換える必要がある。広告なし（買い切りのみ）なら今のドラフトがそのまま使える。

## §1 広告の会社の比較表
| 項目 | Google AdMob | AppLovin MAX | Unity LevelPlay（Unity Ads 系） |
|---|---|---|---|
| 位置づけ | 単体でも使える・導入が最も簡単 | 仲介（mediation）の最大手とされる（市場シェア 50% 超と書く記事あり・単一ブログ） | 仲介。「インディーには簡単」と評する記事あり。ROI 到達が AdMob 単体より遅いとする記事もあり |
| リワード広告 | あり（公式） | あり | あり |
| 単価の傾向 | 「ユーザーに優しい広告フローで eCPM は低め」という評（意見）。日本の数値は未確認 | Tier-1 市場でリワード・インタースティシャルは AdMob より高いという記事あり。日本固有の数値は未確認 | 同左 |
| 個人で使える条件 | 個人アカウント可。住所確認の PIN 郵送（2〜3 週間）・電話確認が国により必要 | 未確認（今回の検索では取れず） | 未確認 |
| 入金 | 月次・毎月 21 日前後・しきい値未満は翌月繰り越し。**しきい値は通貨ごとの表が別ページにあり、今回は円の金額を確認できず**（第三者 FAQ に「100 ドル」とあるが古い可能性）。PayPal は終了。支払い方法は住所で変わる（EFT・電信送金など） | 未確認（支払いの苦情が多いというコミュニティ報告が記事にある程度） | 未確認 |
| SDK の重さ | 未確認 | 未確認 | 未確認 |
| Privacy Manifest | Google Mobile Ads SDK は v11.2.0 から対応。仲介する場合はアダプタ側も対応版が必要 | ベンダー確認が必要 | ベンダー確認が必要 |
| 注意 | 仲介を足すと各社 SDK の申告が増える | 同左 | 同左 |

**次の一手（決めない範囲）**：AdMob の「お支払い」画面または公式しきい値表で円の金額、各社公式で SDK の MB 数、国内インディーの実績ブログ（日本語）を目視で確認する。

## §2 ATT を出す・出さない
**Apple の規則（公式）**
- IDFA の取得や「他社のアプリ・Web のデータと結び付けるターゲティング／計測」には ATT の許可が必要。**ターゲティング広告のために他社データと結び付ける SDK を入れるだけでも、使っていなくても「トラッキング」扱い**。SDK の挙動は開発者の責任。
- 許可しなかった場合、IDFA は 0 になる。**別の ID（ハッシュ化メール等）で代用して追跡してはいけない**。フィンガープリントは禁止（審査で却下されうる）。
- **許可と引き換えに機能を制限したり、許可の見返りを出したりしてはいけない**（ガイドライン 5.1.2(i)）。事前説明は可だが、だまして同意させるのは不可（5.1.1(iv)）。ATT の回答は他の同意画面と矛盾して上書きしてはいけない。
- EU 向けに代替の ATT 画面（「追加情報」ボタン付き）が iOS 27.2 以降にある（日本のみ配信なら関係薄）。

| | 出す（ATT 画面あり） | 出さない（非パーソナライズのみ） |
|---|---|---|
| 広告 | 許可した人にはパーソナライズ広告・SKAdNetwork 計測 | 全員に文脈ベース広告のみ（IDFA を使わない） |
| 単価 | 許可率に依存。海外では許可率 15%〜46%（時期と調査で幅が大きい・2021〜2024 年）。同意ありのユーザーは収益が約 4〜5 割高い（米国 51%・英国 44%・19 か国平均約 45%、Kraft ら 2024 年・Usercentrics 経由で原典は未確認） | 同意なし側の単価が基準。InMobi（2021 年）は IDFA 制限トラフィックの eCPM が非制限より 37〜42% 低いと報告 |
| 審査の論点 | 目的文（`NSUserTrackingUsageDescription`）が実態と合うこと・許可しなくても遊べること | ATT ダイアログ自体を出さなくてよい。**ただし広告 SDK が IDFA／他社データ結合をしていないこと、Privacy Manifest／栄養ラベルの「トラッキング」申告が実態と一致すること**が必要（ズレると差し戻しの原因になる） |
| ゲームの体験 | 起動直後に許可画面が出る＝世界観の入口が崩れる懸念 | 画面なし |
| 備考 | EU/英国向けには別途 Google の同意画面（UMP）が必要（日本のみ配信なら不要）。AdMob 公式は「GDPR 同意→ATT」の順を推奨 | 日本のみ配信なら、法的な同意画面は不要の可能性が高いが、**ここは専門家確認の領域**（材料のみ） |

注：単価低下の大きさは「許可率」と「そのユーザーの価値」に依存し、**日本の育成 SLG に当てはめた数字は取れていない**。リワード広告は文脈ベースでも需要が強いという説もあるが、今回は裏が取れていない。

## §3 Privacy Manifest と申告
- **Privacy Manifest（`PrivacyInfo.xcprivacy`）**：アプリ本体と、Apple が指定する「プライバシーに影響する SDK」は同梱が必要。Required Reason API（UserDefaults 等）の使用理由を各自が宣言する。**このアプリは UserDefaults を使うので、広告を入れなくても本体側で宣言が必要**（`privacy_policy_draft_v0.md` §1 に UserDefaults の記載あり。Manifest 自体の有無は未確認＝要点検）。
- 広告 SDK 追加時：SDK 付属の Manifest が自動で合算される。`NSPrivacyTracking`（トラッキングするか）と `NSPrivacyTrackingDomains`（トラッキング先ドメイン）の真偽は SDK と設定による。ATT なしの運用なら実態と一致させる（Google 側の設定で個別化を切る＋ドメインの扱いは要確認）。
- **App Store の栄養ラベル（Google の案内、Mobile Ads SDK 13.12.0 時点）**：SDK が集めうるデータとして、IP アドレス、クラッシュログ、パフォーマンスデータ、端末 ID（広告 ID など）、広告データ（表示した広告）、ユーザー操作（動画視聴等）、おおよその位置（IP 由来を含む）。つまり「データの収集なし」は不可。申告は開発者が最新の SDK に合わせて更新する責任がある。
- **ポリシーへの影響**：現ドラフトの「通信しない」「広告を組み込んでいない」「広告 ID を含む端末識別子を取得しない」はすべて書き換えが必要（`privacy_policy_draft_v0.md` §2 の 39・49 行付近）。広告会社のプライバシーポリシーへのリンクも要る。

## §4 年齢区分と広告
- Apple は 2025 年 7 月に年齢区分を 4+／9+／13+／16+／18+ に改定（12+・17+ は廃止）。質問票に「アプリ内コントロール」「広告」などが追加され、回答期限は 2026-01-31 だった。**広告があること自体は区分を決める回答項目の一つで、高い区分になると広告の出し方に制限が出る場合がある、との記述はあるが、各区分での具体的な広告規則は確認できず**。
- **子ども向けに見られた場合（Apple の Kids カテゴリ）**：App Review Guideline 1.3 により、Kids カテゴリのアプリはサードパーティ広告・解析が原則制限される。**この点は今回の検索で取れず、私の知識（要・公式確認）**。Kids カテゴリに載せなければ適用されないが、4+ で出す場合は「子どもも触る前提の広告」の質に注意。
- AdMob 側の設定：`tagForChildDirectedTreatment`（新しい SDK では年齢扱い設定に置き換え）を立てると、興味関心連動広告とリマーケティングが無効になり、仲介アダプタにも信号が伝わる。`setMaxAdContentRating` で広告の内容レーティング上限を設定できる（例：G／PG）。育成 SLG・お笑いなので、対象を 4+ に置くなら上限を設定して不適切広告を避ける案は材料になる（コード変更なし・案のみ）。
- 4+ のままにするか 9+ 以上にするかは、ゲーム内容（お笑い・軽い風刺）と広告の制約のバランスなので、オーナー判断。

## §5 広告なしの選択肢（短く）
| | 広告あり（現方針） | 買い切りのみ（広告なし） |
|---|---|---|
| 収益 | 広告収益＋広告カット課金。日本の単価は未確認 | 課金のみ。広告カットの商品が消え、本体価格か他の課金に寄せる |
| ATT／申告 | ATT 要否の判断・栄養ラベル・Manifest・ポリシーを書き換え | 現ドラフトのまま「収集なし」で出せる（審査もプライバシーも最軽量） |
| 体験 | 区切りの所だけ出す案（iap_design §7）。世界観への影響あり | 広告で没入が壊れない |
| 作業量 | SDK 導入・同意設計・目視・審査リスク | 追加作業なし |
| 手戻り | 後から広告なしには戻せるが、申告の変更が必要 | 後から広告を足すと、ポリシーと栄養ラベルの再申告と、既存ユーザーへの説明が必要 |

## §6 選択肢と推奨の材料（決めない）
- **案A 広告なし（買い切りのみ）**：審査と申告が最も軽い。収益は課金のみ。
- **案B AdMob 単体＋ATT なし（非パーソナライズ）**：導入が簡単・ATT 画面なし・単価は低め。栄養ラベル・ポリシーの書き換えは必須。推奨度の材料：今の `AdProvider` 抽象化と相性が良い。
- **案C AdMob＋ATT あり**：許可率が低めだと効果は限定的、世界観の入口に許可画面が出る。収益を最優先する場合のみ。
- **案D 仲介（MAX／LevelPlay）**：収益の上限は高いが SDK が増え、申告も増える。個人の初期では重い可能性。
- **決めるために要る追加調査（決めない範囲）**：①AdMob 円のしきい値の目視 ②各社 SDK の MB 数 ③国内の個人開発者の実績ブログ ④Apple 公式で Guideline 1.3 の広告規則 ⑤リワード広告を使うかの設計（`iap_design_v0.md` §7 と整合）。

## 出典
- Apple Developer, User privacy and data use（ATT の対象・拒否時の扱い・機能制限禁止）：https://developer.apple.com/app-store/user-privacy-and-data-use/
- Apple Developer, Privacy manifest files：https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- Apple Developer News, Updated age ratings in App Store Connect（2025-07）：https://developer.apple.com/news/?id=ks775ehf
- Google AdMob iOS, App Store data disclosure（SDK 13.12.0 時点・Manifest は 11.2.0 から）：https://developers.google.com/admob/ios/privacy/data-disclosure
- Google AdMob iOS, GDPR／ATT の順序：https://developers.google.com/admob/ios/privacy/gdpr
- Google AdMob iOS, Privacy strategies：https://developers.google.com/admob/ios/privacy/strategies
- Google AdMob iOS, targeting（子ども向け扱い・コンテンツ上限）：https://developers.google.cn/admob/ios/targeting?hl=en
- AdMob ヘルプ, 支払い（月次・21 日前後・しきい値は別表）：https://support.google.com/admob/answer/2772140
- InMobi, ATT の eCPM 影響（2021）：https://advertising.inmobi.com/blog/att-and-ios-14.5-impact-analysis-initial-insights
- Usercentrics（Kraft ら 2024 の引用・ベンダー資料）：https://usercentrics.com/knowledge-hub/app-ad-revenue-consent-calculator/
- ATT 許可率の報告（2021〜、ベンダー資料）：https://mobilemarketingmagazine.com/app-tracking-transparency-opt-in-rates-range-from-16-8-to-36-5-per-cent-report/
- 広告 SDK 比較ブログ（意見・Adster ほか）：https://adster.tech/blogs/the-10-ad-sdks-every-mobile-publisher-should-know-scored
- 未確認として残したもの：円のしきい値、各社 SDK サイズ、MAX／LevelPlay の個人条件・入金額、日本の eCPM、Apple Guideline 1.3 の広告規則。
