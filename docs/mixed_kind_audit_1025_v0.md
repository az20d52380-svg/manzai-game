# 男女混成（maleFemale / femaleMale）目視点検 v0（2026-10-25）

方法：`MZ_KIND` ＋ MZ_UI フックで iPhone 17 に各形8画面（計16枚。画像は feedback_shots/mixed_kind_audit_1025/・未コミット）。

## 見た画面（各形）
cards（週の画面）／yearend（年末総決算）／result_done（大会結果）／netaentry（大会エントリー）／disband（別れ）／event（月末の飲み会）／partner（相方ふきだし）／offer（オファー札）

## ①崩れ・切れ・重なり
- 重：なし。中：なし。
- 低：offer 画面でオファー3枚が舞台の演者に重なり、立ち絵が隠れる（形に依らず既存の見え方。femaleFemale 前回と同じ。意図どおりなら対応不要）。

## ②絵・衣装・一人称
- maleFemale：自分は青衣装の男・札「俺」、相方は桃衣装のお団子髪の女・札「谷口」。独白「俺「…」」。形どおり。
- femaleMale：自分は紫衣装の女・札「私」、相方は赤衣装の男・札「谷口」。独白「私「…」」。形どおり。
- 食い違い（相方の絵が女なのに「俺」等）は、見た8画面×2形では無し。ソース上も相方の顔 `FaceCatalog.taniguchi(for:)`（CharacterAvatars.swift:128,150）・衣装 `StageOutfit.taniguchi(rival:kind:)`（Store/StageOutfit.swift:54-56）・一人称 `{partner1}`（Names.swift:39-45）は相方の性別で出し分け済み。

## ③会話の不自然さ
- 恋愛前提・「兄弟」等の男性前提語は、見た画面とソース grep（彼女／彼氏／兄弟／おっさん）で該当なし。「兄弟」は屋号候補「ドラ焼き兄弟」(IntroFlow.swift:498) のみで人物呼称ではない。
- 相方の台詞は「{partner1}」差し込み（ChoiceEventData.swift ほか）で男女どちらでも成立。「あいつ」(ChoiceEventData.swift:217,335) は第三者を指す語で中立。

## 所見
| 重さ | 所見 | 場所 | 直し方の案 |
|---|---|---|---|
| 中 | 形選びの「男女コンビ」カードが2枚とも同じ見出し（前回 femaleFemale 点検と同件） | ComboKind.swift:26-27 | 見出しを「男女コンビ（男×女）」「男女コンビ（女×男）」等に（決定はオーナー） |
| 低 | offer 札が舞台の立ち絵に重なる | WeekMainView（オファー表示） | 意図確認のみ。対応不要なら据え置き |
| 低 | 解散画面の背景に立ち絵が無く札だけ（形に依らず同じ） | 解散シーン | 対応不要（演出意図の確認のみ） |

件数：重0／中1（既出）／低2。混成2形の絵・一人称は形どおりで、新規の不具合は無し。
