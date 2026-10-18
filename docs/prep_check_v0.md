# 準備ブランチの目視（claude/q-combined8s・iPhone 17・2026-10-18）

土台＝q-combined7 ＋ q106-skills の merge（衝突は生活費=やりくり上手×家賃、体調ダウン確率=喉のケア用品×体が資本の併用で解決。golden 再生成・sync OK・swift test 180 緑）。
撮影＝feedback_shots/prep_check/（コミットしない）。8 画面すべて見られた。崩れ 1 件（直した）。

1. 部屋を選ぶ（1_shop）：3 段の札・家賃・説明・「今住んでいる」印・引っ越すボタン、切れ・重なりなし。
2. 新アイテム（1_shop 下段）：回復ドリンク大／喉のケア用品、価格・「今年あと◯回」とも収まっている。
3. オファーの札（3_offer）：「オファー：ひな壇」＋説明＋谷口「最近ネタやれてへんな」が 3 行で収まる。
4. 飲みの誘い（4a_invite_weekend／4b_invite_broke）：「行く（5,000円）／断る」、会話の吹き出しとも崩れなし。
5. 特技の段（5_skills）：4 枚の札・足りない札は灰色・覚えた印あり。**崩れ 1**：覚えた札が灰色の「足りない札」と同じ薄さになり印が読みにくかった → 直した（下）。
6. カレンダー（6_calendar）：3 月 第2週に「寒梅杯 大会」（第46週）。
7. 予選落ち（7_gploss）：GP1回戦「敗退」の講評の下に谷口「……次や、次」。切れなし。
8. 体力50未満（8_injury）：週メインの案内行に「谷口：無理すると倒れるで。」。小さめだが読める。

％表示・数字の能力値・実在名は見当たらず（特技の費用は経験点の数字のみ）。

## 直した所（元の準備ブランチ）
- ManzaiGame/Sources/AbilityUpView.swift（**q106-skills の物**）：覚えた特技の札を薄くしない（`.disabled` を「足りない札」だけに）。覚えた札は押しても何も起きない。→ 元ブランチにも同じ 2 行を入れる。

## 足した DEBUG フック（このブランチ限定・#if DEBUG 内）
- RootView.swift：MZ_UI=offer（MZ_FRESH=1 で谷口の一言なし）／MZ_UI=gploss／MZ_UI=event MZ_EV=weekend／MZ_UI=allocate MZ_SKILL=1／MZ_UI=weekhint MZ_WH=injury。
- GameSession.swift：debugUntilOffer()。
