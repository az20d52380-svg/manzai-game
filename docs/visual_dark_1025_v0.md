# ダークモードの点検 10/25 深夜（定期の回）

## 結論
崩れ・読めない文字は 0。アプリ本体は端末のダークモードに追従する（`preferredColorScheme(.light)` は部品見本 YoseCatalog だけ）が、色はすべて YoseColor の固定色で、システム任せの色（`.primary`/`.secondary`/`systemBackground`/`Color(.label)`）は本体に 0 か所。

## 見た所
- コード：入力欄4つ（ネタの題名 WeekMainView:796・コンビ名 IntroFlow:510・二人の名前 IntroFlow:627・題材名の変更 NotebookView:382）はどれも `.foregroundStyle(YoseColor.sumi)` で文字色が固定＝ダークでも白文字にならない。題材名の変更だけは仮の文字（プレースホルダ）がシステムの灰色（読める）。
- 目視（iPhone 17・`simctl ui appearance dark`・各1枚）：`MZ_UI=week`／`settings`／`intro_name`＝ライトと同じ見た目。
- 点検の後、sim の外観はライトに戻した。

## 残り（タップ確認の時に）
- 出会い方のメニュー（Picker の一覧）・能力アップの確認ダイアログは iOS の標準の見た目＝ダークでは黒地になる（壊れではない）。紙の画面の上で黒い一覧が出るのが気になるかは、オーナーのタップ確認の時に一緒に見る。
