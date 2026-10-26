# 全画面監査 audit_all_v3（iPhone 17・MZ_NOCHIP=1・900px・preview-all 9e0da8d・Debugビルド）

## v2 と比べた崩れ（先頭）
- 44 年末リザルト【解消】: MZ_UI=yearend で本体を直接撮影済（45 は MZ_UI=yearend MZ_MODE=champion）。旧:SMOKE=3 が v2 の年末結果ではなく「頂グランプリ・客席から観戦中（順位ボード）」の途中画面で止まる（14秒待っても同じ＝ボタン送りが要る）。画面自体に崩れは無いが、年末リザルト本体は v3 では未撮影（45 が年末総決算を撮れている）。要フック調整。
- 49 複数年_2年目: v2 同様、下にトースト（『商店街の福引』）がお店ボタンに重なる（一時表示・崩れではない）。
- 21/33 ほか撮影した範囲（21,26,29,30,33,45,49 を目視）で重なり・見切れ・空白は検出なし。全画面の厳密な画像差分は未実施（PIL/ImageMagick 無し）。

## 撮れた物
- 01〜49（47 は11枚）= 59枚、番号・画面名・開き方は audit_all_v1/index.md と同じ（ファイル名も v2 と同形）。
- bg_<場所>_<day|night>.png 26枚＝13か所（keikoba/station/apartment/gakuya/train/park/famires/sento/theater/kissaten/office/yakiniku/uketsuke）×昼夜。焼肉屋・稽古場受付を含む。
- DEBUG見本（舞台部品の撮影用）: 25 lit / 26 preshow / 28 winner / 29 loser / 30 spectator。

## 撮れなかった物
- 敗者復活の山場・決勝の負け版（専用フック無し・v1/v2と同じ）。通知許諾（MZ_UI=notif）は対象外。
- （44 年末リザルト本体は MZ_UI=yearend で撮影済）

## 開き方の更新
- 44 年末リザルト: MZ_UI=yearend MZ_NOCHIP=1（未優勝の年末総決算・客席観戦の決勝は観終えた扱い）。45 優勝版: MZ_UI=yearend MZ_MODE=champion。
