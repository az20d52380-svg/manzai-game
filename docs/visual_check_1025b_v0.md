# 目視 10/25 追補（iPhone 17・14画面）

## §1 見た画面とフック（MZ_UI=）
calendar（年間香盤）/ glossary（用語集）/ allocate（能力アップ）/ catalog（部品見本・DEBUG）/ stamina / living / forecast / injury（体調ダウン）/ endingbook（エンディング図鑑）/ qual_notice / qual_line / finalist_announce / offer（オファー）/ prestage（大会前の振り忘れ）。

## §2 所見
- 中：stamina / living / forecast の3フックは、起動後の画面が通常の週メイン（1年目第1週）と同一で、それぞれの目的の状態（体力低下・生活費・予報）が再現されていない。フックが空振りか、DEBUG 用の状態積みが無い。直し案：状態を積む関数（offer/prestage と同様）を足す、または不要ならフックを削る。目視の網羅性に関わる。
- 低：catalog（部品見本）に「型を変える」「型」の文言が残る（DEBUG 画面なので本番影響なし。「型」の名残の洗い出し用に注記）。
- 低：finalist_announce は「準決勝の終演から、しばらく。」の暗転だけで、ここだけでは何の画面か分かりにくい（直後に進む前提なら問題なし）。
- 低：glossary は用語の説明に「実力」「相性」が出る一方、週メインの掲示板は「実力 10／相性 5」のみで用語集への導線は「?」だけ。初見で気づきにくい。

## §3 崩れなし
calendar・glossary・allocate・endingbook・qual_notice・qual_line・offer・prestage・injury は、文字の切れ・重なり・はみ出し・内部キー名の露出・古い用語（粒）なし。男女で不自然な語なし。
