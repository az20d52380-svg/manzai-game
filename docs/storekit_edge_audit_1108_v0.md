# StoreKit 端の場面の静的点検（11/08・コード無変更・ビルド／テストなし）

## 結論
1. 危険度「高」は0件。起動直後の Transaction.updates 監視・付与→finish の順・取引ID台帳の永続化（上限なし）は正しく入っている。
2. 一番危ないのは「未検証（unverified）の券購入が、課金されたのに付与も案内もされない」点（中）。次いで「返金された券を回収しない」「iCloud 無しの再インストールで未開封の券が消える」（どちらも中・仕様判断）。
3. 設計doc `iap_design_v0.md` は「消耗型は作らない」のまま古い（実装は券＝消耗型）。文書の食い違いのみ。

対象: `ManzaiGame/Sources/Store/StoreManager.swift` / `GachaState.swift` / `GachaStore.swift` / `StoreIDs.swift`、`ManzaiGameApp.swift`、`GachaView.swift`、`SettingsView.swift`。

## 点検表
| # | 場面 | ファイル:行 | 今の挙動 | 危険度 | 直すなら（1行） | 判断 |
|---|---|---|---|---|---|---|
| 1 | updates の監視開始 | ManzaiGameApp.swift:10, StoreManager.swift:20-26 | App.init で shared を触り、init 内で Task が即 `Transaction.updates` を for await。承認待ち・未finishの再配信も拾える | 低（問題なし） | — | 不要 |
| 2 | finish の順 | StoreManager.swift:95-98 | `credit`（UserDefaults＋iCloud へ同期保存）→ `finish()`。付与前に finish はしない。付与後に落ちても再配信され、台帳で弾く | 低（問題なし） | — | 不要 |
| 3 | 二重付与の守り | GachaState.swift:173-176, 20-21(ledger) | 取引ID→回数の辞書。既にあれば不付与。encode される（GachaState:73付近）ので永続化OK。上限で古いIDを捨てる処理は無い＝再付与は起きない | 低（問題なし） | — | 不要 |
| 4 | 台帳の肥大 | GachaStore.swift:46 / GachaState.swift:139 | 台帳は増える一方。iCloud KVS は1キー1MB上限。1件約25B＝約4万件で超える。実用上は届かない | 低 | 古い（開封済み）IDを畳む案は再付与を招くので、やるなら上限監視だけ | 不要（記録のみ） |
| 5 | 購入と updates の同時処理 | StoreManager.swift:58, 24 | purchase() の結果と updates の両方が同じ tx を処理しうるが、MainActor 上で逐次＋台帳で冪等 | 低（問題なし） | — | 不要 |
| 6 | 返金（券） | StoreManager.swift:95 | revocationDate ありなら付与しない（コメントに code_review_1107e #11）。ただし**すでに付与済みの券は回収しない**（台帳は残り、使用済み分も戻さない） | 中 | 返金を受けたら該当IDの台帳値を0にする（paidOpened 超過分は負債として無視） | 要（回収する／しない＝方針） |
| 7 | 返金（非消耗型） | StoreManager.swift:103-114 | currentEntitlements は返金済みを含まない＋revocationDate を見る→所有が外れる。updates でも `updateEntitlements` が走る。黒紋付は isAdFree 連動（GachaStore:62）で追随 | 低（問題なし） | — | 不要 |
| 8 | 復元 | StoreManager.swift:76-89, SettingsView.swift:57 | `AppStore.sync()`→entitlements 読み直し。非消耗型は戻る。消耗型（券）は戻らない前提＝未開封の券は台帳（iCloud）頼み。起動時に sync は呼ばない（意図どおり） | 低 | — | 不要 |
| 9 | 復元の文言 | StoreManager.swift:81 | 所有が空なら「復元できる購入はありませんでした」。券しか買っていない人にも出る（券は復元対象外なので事実ではある） | 低 | 文言に「券は復元できません」を足す | 不要（任意） |
| 10 | 未検証（券の購入） | StoreManager.swift:94, 58-59 | `.unverified` は黙って false。**finish も付与もせず**、購入側にも文言なし（lastMessage 空のまま画面が何も起きない）。課金は成立しうる。次回起動で updates に再配信されるが、また同じく無視＝永久に付与されない | 中 | 未検証時は lastMessage に「購入を確認できませんでした。時間をおいて再起動してください」を出す（付与はしない・finish もしない＝現状維持） | 要（付与するかは安全側＝しない推奨） |
| 11 | 未検証（非消耗型・entitlements） | StoreManager.swift:109-111 | 既に持っていた物だけ維持、新規は付けない。再インストール直後で未検証だと一時的に戻らない（検証が通れば戻る） | 低 | — | 不要 |
| 12 | 購入が承認待ち（askToBuy） | StoreManager.swift:62-64, GachaView.swift:154 | 「購入は承認待ちです」を出して false→回さない。承認後は updates 経由で付与（起動中でも起動後でも）→GachaView の `pendingNote` は画面を開いた時 `.task` でしか立たない（GachaView:69）。開きっぱなしだと未開封の案内が出ない | 低 | `s.paidPending` の変化を見て pendingNote を更新 | 不要（見た目のみ） |
| 13 | 購入中に落ちた／裏に回った | StoreManager.swift:20-26 | 未finish取引は次回起動で updates に再配信→付与→finish。付与後・finish前に落ちても台帳で冪等 | 低（問題なし） | — | 不要 |
| 14 | 付与後・回す前に落ちた | GachaView.swift:154-155 | 台帳に残り paidPending>0。次に開くと pendingNote で「未開封あり」。券は消えない | 低（問題なし） | — | 不要 |
| 15 | 有料購入時に無料の券を先に消費 | GachaView.swift:155, GachaState.swift:105 | 無料→有料の順で消費。10連購入でも freeTickets があれば先に無料が減り、有料分が未開封で残る（減らないが画面の期待と違うことがある） | 低 | 購入直後の回しは有料分から引くフラグ | 要（体験の判断） |
| 16 | 再インストール（iCloud なし／未署名） | GachaStore.swift:16-29 | 台帳は UserDefaults＋iCloud KVS。iCloud 無しだと端末削除で未開封の券・購入済み衣装が失われる。消耗型は Apple から復元できない。非消耗型の adFree/黒紋付は復元で戻る | 中 | 規約表示で「券は復元不可・iCloud 推奨」と明記（store_listing §6 の iCloud 申告文の修正と同じ作業） | 要（文言・方針） |
| 17 | 台帳マージの取り違い | GachaState.swift:139 | 和集合＋max。別端末の購入が消えない・重複しない | 低（問題なし） | — | 不要 |
| 18 | テスト用 `_set` 行 | GachaState.swift:56-60 | `paidPending` の setter が本番コードにも残る。本番経路から呼ばれていない（grep済み）。呼ばれれば台帳に架空の券が入る | 低 | `#if DEBUG` に囲む | 不要（任意） |
| 19 | 商品が読めない時の購入 | StoreManager.swift:53-54 | refresh を再試行、無ければ「商品が見つかりません」 | 低（問題なし） | — | 不要 |
| 20 | 設計docとの食い違い | docs/iap_design_v0.md:7 | 「消耗型は作らない」だが券（ticket1/ticket10）は消耗型。復元が単純、の前提が崩れている | 低（文書） | 設計docに「券＝消耗型・台帳で冪等・復元不可」を追記 | 不要（記録のみ） |

## 既知（既存の記録で扱い済み・今回は再掲のみ）
- StoreIDs の bundle id／値段が【仮】（StoreIDs.swift:2）。確定時に `Configuration.storekit` も揃える。
- 起動時に `AppStore.sync()` を呼ばない（パスワード入力回避・StoreManager.swift:4）。
- 返金済み券の付与抑止（code_review_1107e #11）、未検証でも所有を外さない（同 #10）、オフライン起動の商品再読込（同 #12）は反映済み。
- iCloud 申告文（store_listing §6）の食い違いは `release_build_check_1108.md` §3 で既出。
- `release/release_checklist.md` に StoreKit 固有の項目があるかは見出し確認のみ（本点検では中身は未精読）。

## 実機で確かめたい点（静的点検の限界）
- Xcode の Transaction Manager で「券購入→返金」「承認待ち→承認」「購入直後にキル」を再現し、台帳の増減を確認。
- サンドボックス実機で、再インストール後の adFree 復元と、券の未開封が iCloud 経由で戻るか。
