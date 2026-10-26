# コード点検 2026-10-27（491ac6e..HEAD）

対象：16コミット（11ファイル・差分287行）。見たのは正しさのみ。用語集の文言は GameConfig / GameCore の実値と突き合わせた。
結論：高 0件・中 0件・低 3件（うち要確認 2件）。クラッシュ・状態の取り違えは見つからなかった。

## 照合して問題なしだった物（記録）
- ハマった夜：burstP=0.10・burstBonus=+12（GameConfig:233-234）＝「まれに」「大きく上がる」と合う。
- オファー：ひな壇・ラジオ・ロケ・営業の4種、体力は全部マイナス、知名度は全部プラス、offerCardFames=[30,55] で知名度が高いほど札が増える（GameConfig:293-300）＝文言と合う。
- 敗者復活：準決勝敗退のみ・決勝と同週（Calendar.swift:77）＝合う。
- 客の反応＝neta.buzz。ネタ帳の棒（NotebookView:339）。netaScoreBonus は (buzz-50)×係数で、高いほど点が上がる（GameEngine:263-）。
- 年末の所持金：旧文言「最終所持金」はアプリ内に残っていない。
- 「週は進まない」：能力アップ→showAllocation、お店→showShop に直行（WeekMainView:979-980）。週送りはしない＝合う。
- Theme.Motion.r：Theme.swift が import UIKit 済み。withAnimation(nil) / .animation(nil, value:) は有効で、クラッシュしない。
- NotebookView:125 の fixedSize()＋frame(minWidth:48)、:254 の lineLimit(1)＋minimumScaleFactor は正しい。
- WeekMainView:1053 の accessibilityHidden(true) は記号 Image だけにかかる（名前の Text は読まれる）＝正しい。

## 指摘

### 1. 低・要確認　週の札の副題が長くなり、1行で切れる恐れ
- ファイル：ManzaiGame/Sources/WeekMainView.swift:971-972（副題を表示する側は actionCardLabel の v.desc／sub）
- 何が起きるか：副題が「経験点を使う・週は進まない」（13字）「買い物・週は進まない」に伸びた。副題を lineLimit(1)＋縮小なしで出す札（半幅のグリッド）だと、文字最大の時に末尾の「週は進まない」が「…」で切れて、足した意味が消える。通常サイズでは収まるかは未確認（実機の目視が要る）。
- 直し方案：副題を表示する Text に lineLimit(2)＋fixedSize(horizontal:false, vertical:true)、または minimumScaleFactor(0.8)。

### 2. 低　「視差効果を減らす」の対応にもれが残る
- ファイル：CalendarView.swift:165（`withAnimation { toast = nil }`）、WeekMainView.swift:983（`withAnimation(Theme.Motion.appearQuick)`）ほか、素の `withAnimation(.…)` はまだ約70か所（コミット8d15428 の「13か所」の外）。
- 何が起きるか：トーストは出す側だけ r() で消す側は動くので、設定オンの人にも一部アニメが残る。害は小さい（見た目だけ）。
- 直し方案：全体で `Theme.Motion.r()` に寄せるか、`withAnimation` を包む共通関数を1つ作る。今回の範囲外なら記録だけでよい。

### 3. 低・要確認　用語集「客の反応」の説明に抜け
- ファイル：ManzaiGame/Sources/SettingsView.swift（「客の反応」の項）
- 何が起きるか：「高いほど大会の本番の点が上がる」とあるが、点に効くのは勝負ネタに選んだ1本だけ（selectedNetaID が無いと恒等で0＝GameEngine:259-263）。かつ50を下回ると点がマイナスになる（NetaSelectionView:109 のコメントと同じ）。誤りではないが「どのネタでも点が上がる」と読める。また、動くのは「ネタ見せ会」と「フリーライブ」（WeekRunner:512 applyNetaLive）で、文言の「舞台に立つ」がフリーライブを指すなら合う（要確認）。
- 直し方案：「勝負ネタにした1本の、大会の本番の点に効く。50より低いと点が下がる」と添える。
- 10/27 定期：③は直した（「そのネタを勝負ネタにした時」・GameEngine.netaScoreBonus は選んだネタだけ＝確認済み）。①②は低・要確認のまま（①は文字最大の目視、②は既存の方針＝主要13か所のみ対応）。
- 10/27 定期：①を目視（iPhone 17・文字サイズ最大・MZ_UI=week）＝副題は2行に折れるだけで切れない（「経験点を使う・週は進／まない」の折れ目はやや不格好・対応不要の範囲）。②は既存の方針のまま。
