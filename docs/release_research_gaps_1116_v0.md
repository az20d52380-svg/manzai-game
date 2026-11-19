# 発売前の未確認3点（続）：内閣府令4条と退蔵益・Apple質問票・日本の年齢制限 v0（2026-11-16）

注意：法律の助言ではなく材料。判断はオーナー。前回（`release_research_gaps_1115_v0.md` §4）の 2・4・5 だけを調べた。「読めた事実」と「見解」を分けて書く。

## 要点3行
1. §2：内閣府令4条は、有効期限の到来などで使えなくなった額を明文で「回収額」に含める（=未使用残高から引く）。一方、事務ガイドライン I-2-1(2) は退蔵益として収益計上した発行残高も基準日未使用残高に「含む」と書く。2つが同じ額に当たる場合の整理は、当局の説明を読めず「分からない」。
2. §4：質問票の項目は「Loot Boxes」（購入できるランダムな仮想アイテムの容器）で、Apple の表では 9+。ガチャが該当すれば 9+ 未満にする方法は公式資料に見えない（上げる override しか書かれていない）。
3. §5：Apple 公式の定義ページ（日・英）全文に日本の項は無く、地域別の値があるのは豪・ブラジル・韓国・ベトナム・フランスだけ。日本独自の年齢制限は見つからなかった。

## §2の答え（内閣府令4条と事務ガイドライン I-2-1(2)）
### 読めた事実
- 内閣府令4条（e-Gov 本文）：基準日未使用残高＝①基準期間発行額の合計 − ②回収額。回収額のイ（1号型）は「使用により代価の弁済に充てられた金額（当該前払式支払手段に係る有効期限の到来その他の理由により代価の弁済に充てられなくなった金額…を含む）」。ロ（2号型）も同様に「有効期限の到来その他の理由により請求されなくなった数量」を含む。払戻手続・権利実行手続から除斥された者の残高も含む。
- 事務ガイドライン I-2-1(2)：「上記⑴の基準日未使用残高には、財務諸表に税法による収益（いわゆる退蔵益）として計上された前払式支払手段の発行残高も含むものとする。」
- つまり条文は「期限切れ＝回収額＝残高から引く」、ガイドラインは「退蔵益に計上した分も残高に含める（=引かない）」。
### 見解（断定しない）
- 両者は矛盾して見えるが、ガイドラインの趣旨は「会計・税務上で収益に計上しても、法の未使用残高からは外さない」とも読める。ただし、その場合に内閣府令4条の「期限到来＝回収額」がどの場面で効くのか（失効を発行者が規約で定めた場合は含める／単に会計上の退蔵処理は含めない、という線引きか）は、私は当局の説明で確認できていない。
- 本作への影響：ガチャ券に期限を付けると、期限切れ分は条文上は回収額になり得るが、ガイドラインの退蔵益の扱いとどちらが優先か未確定。残高が基準額（千万円）に近づく規模になってから、財務局・日本資金決済業協会へ確認すれば足りる（見解）。
### 取れなかった物
- 2010年のパブコメ回答（金融庁 1-3.pdf）は機械で読めなかった。ここに両者の関係の説明がある可能性はあるが未確認。
出典：[内閣府令（e-Gov API 経由で本文取得）](https://laws.e-gov.go.jp/law/422M60000002003)、[事務ガイドライン 05.pdf（第3分冊5、I-2-1(2) をローカルで抽出）](https://www.fsa.go.jp/common/law/guide/kaisya/05.pdf)、[金融庁パブコメ 1-3.pdf（未読）](https://www.fsa.go.jp/news/21/kinyu/20100223-1/1-3.pdf)

## §4の答え（Apple 質問票の項目とガチャ）
### 読めた事実
- 手順（Apple 公式ヘルプ）：App Store Connect → App Information → Age Ratings の Set Up で、①アプリ内コントロール（機能）を選ぶ → ②各項目ごとに頻度などを選ぶ → ③Age Categories and Override は通常「Not Applicable」。ヘルプ本文は質問文を一字一句は載せていない。「Chance-Based Activities」の画面は、模擬ギャンブルと懸賞（Contests）は頻度の選択、ギャンブルとルートボックスは Yes/No の選択、と画像の説明文から読める。
- 定義ページの項目文言：Loot Boxes＝「Virtual containers that provide players with randomized virtual items for purchase. May include: randomized functional cards or cosmetic items for purchase.」Simulated Gambling＝「Betting or wagering without using real money or in-game currency that can be exchanged for real money.」Contests＝競い合うイベント（ランキング・報酬）で、まれなら 4+・頻繁なら 13+。Parental Controls／Age Assurance は 4+。
- 値：ルートボックスは世界共通で 9+（頻度の区別なし）。模擬ギャンブルは まれ＝13+／頻繁＝18+。4+ の一覧にルートボックスは出てこない。
- 下げる方法：公式ヘルプにあるのは「Override to Higher Age Rating」（上げる）のみ。下げる手段の記述は無い。EU の代替マーケット用に「Unrated」もある。
### 見解
- 本作のガチャは「購入した（有償）券でランダムに出る」ので、Loot Boxes に「あり」と答える設計になる読み。その場合は 9+ が下限。9+ 未満（4+）にしたいなら、ガチャを Loot Boxes に当たらない形にするか（例：有償でランダムを買えない）、外すしか見えない。ただし「無償の券だけで回すガチャ」が購入に当たるかは、定義文（for purchase）からは断定できず、実画面または App Review への確認が要る。
- 本作のガチャ券が「ゲーム内通貨で換金不能」なので模擬ギャンブル（13+）には当たらない読みだが、Apple の判断としては未確認。
出典：[Set an app age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating)、[Age ratings values and definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions)、[同（日本語版）](https://developer.apple.com/jp/help/app-store-connect/reference/age-ratings/)

## §5の答え（日本の App Store の年齢制限）
### 読めた事実
- 定義ページ（英語版の全文・日本語版）に「日本」の項や日本向けの特別な値は無い。地域別の値があるのは、オーストラリア（ルートボックスは 16+）、ブラジル（A18）、韓国（GRAC の等級、別の等級が出たら RCN の提出を求められる場合あり）、ベトナム（00+/12+/16+/18+）、フランス（グローバル 17+ に対して 18+）。
- 日本の2025年12月の iOS 変更（スマホソフトウェア競争促進法対応）：インストール前の画面に分かりやすい年齢区分を表示することが、App Store 配信でも代替マーケットでも全アプリに求められる。代替決済や外部サイト誘導を使うアプリは 18歳未満にペアレンタルゲートが要る。App Store の通常のアプリ内課金（ガチャ）は、この規則の対象外と読める。年齢確認（age assurance）の拡大対象にも日本は入っていない（検索結果の要約から。原文は未読）。
- 日本のブログに「ルートボックスを謳うと自動で 18+ になる」という記述があるとの検索要約があったが、Apple の資料と合わず、確認できていない（Apple 公式の表では 9+）。
### 見解
- 日本の質問票・定義ページ上、日本独自の年齢制限は見つからなかった。出る年齢区分は世界共通（ガチャあり＝9+）になる読み。日本の景品表示法（コンプガチャ）など別の法規は年齢区分とは別の話で、今回は調べていない。
出典：[Apple 公式 定義ページ（上と同じ）](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions)、[Apple Newsroom 2025-12（日本の iOS 変更）](https://www.apple.com/newsroom/2025/12/apple-announces-changes-to-ios-in-japan/)（検索結果の要約のみ・未取得）、[Apple Developer News 豪・ベトナム](https://developer.apple.com/news/?id=yrrb45pw)（検索結果のみ）

## まだ分からない事
1. 内閣府令4条「期限到来＝回収額」とガイドライン「退蔵益も含む」が同じ額に当たる場合の当局の整理（2010年パブコメ回答が読めず）。→ 財務局・資金決済業協会への相談。
2. App Store Connect の実画面での Loot Boxes の質問文と、無償券のみで回すガチャの扱い。→ App Store Connect の実画面か Apple への問い合わせ。
3. Apple Newsroom の日本向け変更の原文（検索要約だけで、取得はしていない）。
4. 日本の景品表示法・コンプガチャなど、年齢区分以外の日本の規制（今回の範囲外）。
