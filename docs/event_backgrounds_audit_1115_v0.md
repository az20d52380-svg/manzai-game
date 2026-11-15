# イベント背景まわりの点検（2026-11-15・読むだけ）

対象：ManzaiGame/Sources/Design/EventBackgrounds.swift（1769行）・Design/EventBackdropTable.swift（49行）・ManzaiGame/Sources/WaIcons.swift（63行）。
（依頼の「Sources/EventBackgrounds.swift」は実際は Sources/Design/ にある。）

## §1 要約
- 高：0件／中：0件／低：3件。落ちる所・重い所・動き続けるアニメは見つからなかった（背景は完全な静止画で、アニメ・TimelineView・Canvas・onAppear が0）。
- 表（EventBackdropTable）と実体（EventStageBackdropView の switch）は両方とも網羅的な switch でコンパイラが保証しており、食い違いなし。
- 参照0は WaIcon 一式（既知）と、EventPlace.sento（表にもエンディングにも出ない＝デバッグ用 MZ_BG=sento でしか見えない）の2点。

## §2 指摘
### 高
なし。

### 中
なし。

### 低
1. **EventPlace.sento は実体があるのに、どのイベント・エンディングからも使われていない**
   - 場所：EventBackgrounds.swift:1068 SentoBackdrop（約85行）・:1049-1066 FujiShape/FujiCapShape・:1152 SentoBucketShape。参照は RootView.swift:34 の MZ_BG デバッグ（EventPlace(rawValue:)）だけ。EventBackdropTable.swift に .sento は無い。
   - 何が起きるか：画面には出ない（死んだ描画コード）。nightStrength の .sento 分岐（:49）も同様。
   - 直し方の案：銭湯イベントを足す予定があるなら残す。無いなら表示だけの削除候補（unused_parts_1027_v0.md には未掲載＝新規）。
2. **WaIcons.swift 全体（WaIcon・SensuShape・SensuRibs）は参照0（既知）**
   - 場所：WaIcons.swift:6／:41／:52。docs/unused_parts_1027_v0.md の16行目に「WaIcon（未使用）」と、案1（claude/unused-parts-cand）で削除済みの記載あり。
   - 直し方の案：その案1を merge するだけ。
3. **`ForEach([w * 0.24, w * 0.76], id: \.self)` のように、幅 w から作った値を id にしている**
   - 場所：EventBackgrounds.swift:386, 587, 628, 1011, 1130, 1184, 1740（他の定数配列は :425, :455, :638 など問題なし）。
   - 何が起きるか：w が 0 の瞬間（レイアウト前）に2要素が同じ値になり、SwiftUI が「ID が重複」の警告を出し得る。表示は直後に直るので実害は小さい。幅が正常なら起きない。
   - 直し方の案：`ForEach(0..<2, id: \.self)` ＋ 中で x を計算する形に変える（表示のみ・数値は同じ）。

## §3 問題なしと確かめた観点
1. **落ちる可能性**：`.count`・強制アンラップ（`!`）・配列の添字アクセスは EventBackgrounds.swift に0件。ForEach はすべて定数範囲（0..<N）か定数配列で、変わる配列を回す所なし。割り算は :248-250 の `w / s` のみで、`h = max(geo.size.height, 1)`・`drawH = max(h, 220)` のため s は常に 0 より大きい（0割りなし）。:1239 の `while x < w` は x が必ず +28 で進むので終わる。高さ（`h - floorY` 等）も描画高さが 220 以上なので負にならない。
2. **重さ**：repeatForever・withAnimation・.animation・TimelineView・Canvas・onAppear/onDisappear は0件（grep 済）。blendMode(.screen) と RadialGradient（EventGlowLayer の halo）は夜・夕のみで数十個だが静止画で、再描画は背景の切り替え時だけ。
3. **視差を減らす（accessibilityReduceMotion）**：動くものが無いので対象外（Environment の参照も不要）。EventStageBackdropView は accessibilityHidden(true)、EventGlowLayer も飾り扱いで読み上げ対象外。
4. **ダークモード**：背景の色は Color(hex:) と YoseColor（どちらも固定色）で、絵の一部としてすべて固定。YoseColor.kinari 等も固定色で、画面全体が同じ明るい和紙調のため、背景だけが浮く・見えにくくなる所は見つからなかった。project.yml・Resources に UIUserInterfaceStyle 指定は見当たらないので、端末がダークでも背景と周囲の色は変わらず、組み合わせが崩れない。夜の場面は明度12%以上の方針（:44 のコメント）で作られている。WaIcons の `.white.opacity` と 0x2C2C2C も、朱の札の上に載るので固定色で問題なし（かつ参照0）。
5. **参照0**：EventPlace の16場所のうち sento 以外（keikoba 9・station 8・apartment 6・gakuya 14・train 25・park 1・famires 11・theater 6・kissaten 2・office 8・yakiniku 7・uketsuke 1・theaterOutside 7・street 9・stationGate 2 の外部参照）はどれも使われている。EventTimeTintModifier／eventTimeTint／EventGlowLayer／nightStrength は同ファイル内で参照されている。
6. **表と実体の対応**：EventBackdropTable.swift の `switch kind` は default なしで ChoiceEventKind を網羅（コンパイラが保証）。表が返す場所（keikoba・street・theaterOutside・yakiniku・uketsuke・gakuya・office・famires・station・theater・kissaten・park・apartment・stationGate）はすべて EventStageBackdropView の switch に実体あり。EventStageBackdropView の switch も EventPlace を default なしで網羅。逆（実体があって表に無い）は sento と train（train は Endings 等から使われているが表には無い。表はイベント用なので問題ではない）。
