# コード点検：エンディング・周回メタ・コンビ形選択（11/17・読むだけ・コード不変）

対象：Endings.swift／EndingViews.swift／Meta.swift／ComboKindPickerView.swift（GameSession.swift・Names.swift・IntroFlow.swift・ComboKind.swift は参照のみ）。
件数：高0／中0／低4（新規2・既知2）／要確認1。

## 結論
- 分岐の取りこぼし・重なりは無し（§A）。`bankrupt→dissolved→champion→最終年の履歴優勝→決勝有無×相性` で全ケースがちょうど1つに当たる。
- 配列の範囲外・強制アンラップは無し。女女・男女で崩れる文も見つからない（台詞の「俺」は話者札のみで Names.show が置き換え、文中は {me}{partner1}）。

## §1 指摘

### 1. 【低・新規】図鑑の読み返しが、いつも男コンビ・相方「谷口」の台詞で再生される
- EndingViews.swift:330（EndingFlowView(session: nil, replay: true)）／Names.swift:22 ／RootView.swift:372（returnToTitle の `GameSession()`）／GameSession.swift:251-252
- 状態→結果：女コンビ（femaleFemale）で #6 を見て図鑑に記録（EndingRecord は相方の名前だけ保存・コンビの形は未保存）→「もう一度」で returnToTitle → 新しい GameSession() が Names.kind=.maleMale・相方=既定「谷口」に戻す → 図鑑で #6 をタップすると、場面カードが「俺」「谷口」で出る。札には「相方：（実名）」が出ているのに台詞は谷口、一人称も男になる。
- 直し方：①今のまま（読み返しは既定の二人という扱い）②EndingRecord に `comboKind: String?`（Optional・旧データ nil＝男）を足し、replay 時に `Names.setKind`／相方名を一時的に当てる（表示専用）。
- 重さの根拠：図鑑の中だけ・進行に影響しない。

### 2. 【低・新規／DEBUG のみ】MZ_BOOKSEEN／MZ_TROPHIES を付けたまま周を進めると見本の値が実保存に混ざる
- Endings.swift:187-196,206-210／Meta.swift:94-97,105-109
- 状態→結果：load() が環境変数の見本を返し、record／award がそれを土台に保存し直す＝sim の UserDefaults に見本の図鑑・トロフィーが書き込まれる（MetaBook.points は MZ_META で固定可能だが、これらは未対応）。Release には無い。
- 直し方：DEBUG 時は record／award の保存をスキップするか、見本の load と保存用の load を分ける。

### 3. 【低・既知】読み込みの「1件の型違いで全部消える」
- Endings.swift:197-198（[String: EndingRecord] を一括デコード）／Meta.swift:99・132（[String] と CareerRecords）。既知＝trophy_meta_audit_1115_v0 §2（キュー154）。
- 補足（新規の気づき）：CareerRecords は `bestStreak = 0`・`totalWins = 0` が非 Optional。将来ここに非 Optional の項目を足すと、旧データのデコードが失敗し記録が全部 0 に戻り次の保存で上書きされる。足すなら必ず Optional。

### 4. 【低・既知】t18「十年選手」の名前が15年と合わない／最終年の判定リテラル
- Meta.swift:41,62,153＝既知（キュー172）。ten_year_leftovers_1108_v0 に既出。
- 補足：Endings.swift:88,90,92 の `compat >= 15` は GameConfig.compatCap とは別のリテラル（意図した閾値ならこのまま。cap が変わると相性上限＝20 のままなら影響なし）。

### 5. 【要確認・既知に近い】エンディング記録の二重カウント窓
- EndingViews.swift:43-51。記録は表示時の1回（@State recorded）。記録後に落ちた場合、saveNow が finished&&careerOver でセーブを消すため再開では再記録されない（既知＝trophy_meta_audit_1115 §2・キュー117 は「記録されない側」）。逆に、記録後・セーブ削除前に落ちると再開で同じ終わりをもう一度見て count が 2 になる窓が理論上ある。セーブ削除の呼び出し順を確かめ切れていない。
- 直し方：記録の直後にセーブを消す順にする、または再開時に同じ年の EndingID を重複記録しない目印を持つ。

## §A 確認済み（問題なし）
- 判定 EndingID.judge（Endings.swift:85-98）：破産・解散・優勝・最終年の分岐が上から順で、(決勝あり×相性) 4通りは網羅。年数は `careerYears` 参照で 10・9 の取り残しは判定側に無し（テスト出力 GameSession.swift:1962 だけ `year:10, careerYears:10`＝既知・ten_year_leftovers §3）。
- 優勝年は endingID が canChooseRetire 中 nil（Endings.swift:170）＝選択中に終わらず、最終年の優勝は即エンド（GameSession.swift:1171）。
- 二重付与：TrophyBook.award は Set.insert で冪等。recordChampion は didRecordChampion で年末の再入を防ぐ。EndingFlowView は recorded ガード。
- 範囲外：ReminiscencePlayer は cards が空なら EndingFlowView 側で守る（EndingViews.swift:36）／EndingArt の ForEach は定数範囲／yearHistory 参照は filter・contains のみ。強制アンラップ無し。
- 女女・男女：ComboKindPickerView は ComboKind から引くだけで4枚の表記と一致。台詞は Names.show 経由（IntroFlow.swift:76 ほか）。Endings の文中に生の「俺」は無し。
