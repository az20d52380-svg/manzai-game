# 文字サイズ拡大の目視監査（2026-10-19）v0
iPhone 17 / extra-extra-large（一般の最大）で10画面、accessibility-large で3画面。コードは未変更。終了後 content_size は large に戻し済み。

## extra-extra-large
| 画面(フック) | 結果 |
|---|---|
| offer | 崩れなし（所見L1あり） |
| neta | 崩れなし |
| shop | 崩れなし（家賃説明が2行に折返すが切れない） |
| settings | 崩れなし |
| glossary | 崩れなし |
| calendar | 崩れなし |
| allocate | 崩れなし（下端の「特技」欄は戻る等のボタン行の背面に隠れ、スクロールで見える想定） |
| qual_notice | 崩れなし |
| finalist_announce | 崩れなし |
| event(0055) | 所見M1 |

## accessibility-large（offer / allocate / event）
大半の文字は固定サイズらしく xxl と見た目がほぼ同じ。
| 画面 | 結果 |
|---|---|
| offer | 所見L1 |
| allocate | 崩れなし（下端の特技欄がボタン行で隠れる点は xxl と同じ） |
| event | 所見M1（xxl と同じ） |

## 所見
- **M1（中）イベント画面：場面イラストが本文ログの先頭に重なる。** 「稽古場。谷口から電話が来た朝。」の1行目が上端で切れる（xxl/ax 両方）。直し案：本文ログ側の上余白をイラスト高に合わせる、またはイラストを本文と同じスクロールに入れる。ファイル：イベント画面のView（grep `EventScene` 系）。画像 docs/dynamic_type_audit_1019_event.png
- **L1（低）週の画面：上部3つの選択肢カードの説明が ax では3行で「喋りも磨…」と末尾が切れる。** 押せなくなりはしない。直し案：説明に lineLimit を緩める／最小高さを可変に。画像 docs/dynamic_type_audit_1019_offer.png
- **L2（低）能力アップ：下端の「特技」欄がボタン行の背面に入り、初期位置では見出しだけ見える。** スクロールで読める想定だが、スクロール可能と気づきにくい。直し案：下に余白を足す。

高0／中1／低2。押せなくなるボタンは無し。
