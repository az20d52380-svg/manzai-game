# ストア手数料の確認（L60）v0 — 2026-10-25

## §1 結論
1. 文書の前提「個人開発規模なら両ストア実質15%」は、日本のAppleでは**実効15%（コミッション10%＋決済処理5%）で結果的に合う**。標準（非加入）は**21%＋5%＝26%**で、30%ではない。
2. Googleは「最初の100万USDは15%」が**新体系の一次資料に出てこない**（旧制度の記述）。日本は**2026/12/31まで**に新体系（課金5%別途＋サービス料15〜20%、サブスクは10%＋5%）へ移行予定＝リリース時期しだいで**15〜25%**。
3. Appleの「手動エンロール漏れ＝30%」は、日本では「漏れ＝26%」に読み替え。新規デベロッパーは自動で対象という二次情報あり（要一次確認）。

## §2 表（日本向け・2026-10時点）
| 項目 | 内容 | 確度 | 出典 |
|---|---|---|---|
| Apple 日本 IAP コミッション（標準） | 21％（デジタル商品）＋決済処理5％＝26％ | 高（Apple公式検索結果＋9to5mac） | https://developer.apple.com/support/payment-options-on-the-app-store-in-japan |
| Apple 日本 Small Business Program | 10％＋5％＝15％。サブスク2年目以降も10％（＋5％） | 高 | 同上 / https://9to5mac.com/2025/12/17/apple-announces-sweeping-app-store-and-iphone-changes-in-japan |
| Apple 日本 外部リンク決済 | 標準15％／SBP等10％（タップから7日以内の販売）。処理5％は不要 | 中〜高 | https://developer.apple.com/support/payment-options-on-the-app-store-in-japan |
| Apple 代替マーケット配信 | Core Technology Commission 5％ | 高 | https://developer.apple.com/support/alternative-app-marketplace-jp/ |
| Apple（参考・日本外の標準） | 30％／SBP 15％（年間proceeds100万USD以下）／サブスク2年目15％ | 高 | https://developer.apple.com/app-store/small-business-program/ |
| Apple SBP 登録 | 新規は自動、既存は手動との二次情報。年100万USD超で当年30%側 | 中（二次） | https://adapty.io/blog/app-store-small-business-program/ |
| Google 新体系（2026/3/4発表） | 課金5％（別枠）＋サービス料：参加者 新規インストール15％/既存20％、非参加 新規20％。サブスク10％（＋5％）。合計：参加・新規20％、参加・既存25％、非参加・新規25％、サブスク15％ | 中〜高（Google公式ブログ＋neonpay） | https://android-developers.googleblog.com/2026/03/a-new-era-for-choice-and-openness.html / https://www.neonpay.com/blog/google-just-announced-new-play-store-fees-heres-whats-actually-happening--how-it-impacts-dtc |
| Google 適用時期 | 米英EEA 6/30、豪 9/30、**日本・韓国 12/31まで**、他は2027/9/30 | 中〜高 | 同上 |
| Google 参加条件 | Apps Experience Program または Play Games Level Up（品質基準）。日本での詳細は未確認 | 低〜中 | 同上 |
| Google 日本の旧基準 | 標準30％（スマホ新法の代替決済は26％等、ベンダー情報が食い違う） | 低（二次） | https://xsolla.com/blog/mobile-software-competition-act-in-japan-and-what-mobile-game-developers-should-know |
| Google 「最初100万USDは15%」 | 新体系の発表本文に記載なし＝移行後は消える可能性 | 中 | 上記ブログ |

注意：Apple公式ページ本文は直接取得できず（404/要約のみ）、検索要約と報道経由。数値は業界団体が「実質的に新手数料」と批判している点も含め流動的。

## §3 文書側で直す箇所（docs/）
- legal_risk_v0.md L103, L131, L181：「両ストア15%前提」→「Apple日本=コミッション10%＋処理5%（非加入は21%＋5%）／Google=リリース時期で15〜25%」に。
- legal_risk_v0.md L111（3-c）：Apple日本の10%＋5%、Googleの「最初100万USD15%」は新体系で記載なしと注記。
- legal_risk_v0.md L112（3-d）：「30%」→日本では26%。新規は自動の可能性を併記。
- legal_risk_v0.md L113（3-e）：三次元の合計率（20/25/15%）と日本=12/31までを数値で追記、確度を「medium→中〜高」へ（原文WebFetch取得済み）。
- legal_risk_v0.md L114（3-f）：日本はスマホ新法で外部リンク決済が可能になった点を追記（「日本に及ばない」は米国限定救済の話なので維持しつつ、日本固有の道を足す）。
- legal_risk_v0.md L121〜123, L205〜207（未確認リスト）：Google新料金・SBP定義の項目に本書の結果を反映。
- concerns_register_v0.md の「ストア手数料・審査の未確認前提」行（医療数字ではなく法務行）：状態を research→一部確認済みに。
- monetization_decision_v0.md：手数料率の前提を直接書いた行は見つからず（P/Lの手数料欄が無い）。収益計算を入れる際は上記率を使う。

## §4 オーナーが決める選択肢（推奨のみ）
- A. P/Lの手数料率：Apple 15%（SBP加入前提）／Google 20〜25%でモデル化。推奨＝**保守的にApple15%・Google25%**。
- B. 外部リンク決済（日本で可能）を使うか：手数料は10〜15%＋決済会社手数料で、開発者団体は総額で同等と指摘。推奨＝**初期はIAPのみ**、業態確定後に再検討。
- C. Google参加プログラム（Apps Experience等）を狙うか：推奨＝要件が日本で公開されてから判断。
- D. リリース時期：Googleの12/31移行を跨ぐ場合は新体系で計算。推奨＝跨ぐ前提。
- 残タスク：Apple/Google一次ページを人の目で確認（本書はAppleを検索要約経由）、弁護士確認リストへ追加。

## 追記（2026-10-26・Apple 一次ページの確認＝L60 の残り）
- developer.apple.com/support/payment-options-on-the-app-store-in-japan：日本のデジタル商品は **標準21%**、**小規模事業者プログラム等の参加者は10%**、Apple の課金で払われた分に **決済処理5%** が別にかかる（どちらも客が払った額に対して）。§1 の結論どおり＝実効15%（参加）／26%（非参加）。
- developer.apple.com/app-store/small-business-program/：**登録は自動ではない**（「数ステップで登録」＝Paid Apps 契約の受諾・関連アカウントの申告）。条件は前年の売上（手数料等を引いた額）が100万USD以下、かつ当年も超えないこと。
- 残り：Google 側の日本の新体系の適用日（2026/12/31 までの予定）は、出す時期が決まったら確認。
