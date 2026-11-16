# 未点検ファイルのコード点検（2026-11-16・コード変更なし）

## 対象の選び方と5つの一覧
`ManzaiGame/Sources` の全 .swift 名を 1109/1110/1111/1115/1116 の docs で grep。触れている文書が0〜1本のものは4つだけ（小さいファイルばかり）。
2本以下に広げて行数順：
1. Design/YoseComponents.swift 336行（文書2本）← 今回の主対象
2. Design/YoseTokens.swift 94行（2本）
3. WaIcons.swift 63行（1本）← 読んだ
4. Design/EventBackdropTable.swift 49行（1本）← 読んだ
5. Store/StoreIDs.swift 25行（0本）← 読んだ（ManzaiGameApp.swift 17行・FontLoader/JudgeData も小さく問題なし）
除外：Preview・Catalog・FXPreview 系。YoseTokens は定数のみのため未読。
大きいファイルは実質 YoseComponents だけ。ここは async/sleep・onFinish・セーブ状態を持たないので、観点のうち「落ちる所」「透明で押せる」「数値の食い違い」だけが該当。

## 確認して問題なしだった点
- EventBackdropTable：GameCore の ChoiceEventKind 36 case と switch の case 36 個が一致（comm で差分なし）＝網羅漏れなし。
- StoreIDs：Configuration.storekit の4商品ID（adfree/agency/ticket1/ticket10）と一致。
- YoseGauge：total<=0 と範囲外は clamp 済み。ForEach(1..<4) は範囲正常。
- YoseComponents に `!`・添字アクセス・Task/sleep は無い。

## 所見

### 1. WaIcon が未使用（死んだコード）　重さ 低／確信度 中
- WaIcons.swift:6（struct WaIcon）。`grep WaIcon` で Sources 内の他ファイルに使用が無い（ビルド成果物のみ）。コマンド札のアイコンは別実装に置き換わったと思われる。
- 何が起きるか：実害なし。保守時に「使われている」と誤解する・色 0xA62B1E が YoseColor とずれていても気付かれない。
- 直し方の案：本当に不要か確認のうえ削除、または WeekMainView で使う。

### 2. YoseButtonStyle の押下音が action 側の音と二重に鳴り得る　重さ 低／確信度 中
- YoseComponents.swift:135（`.onChange(of: isPressed)` で Sound.play(.cursor)）。
- 手順：action 内で別の決定音を鳴らすボタンに `silent: true` を付け忘れると、指を下ろした瞬間に cursor 音→離した時に決定音で二重になる。silent 指定漏れの箇所は未検査。
- 直し方の案：Sound.play を呼んでいる action を持つ YoseButtonStyle 利用箇所を grep し、silent の付け忘れを確認。

### 3. 視差を減らす設定の取得が描画時の一回読み　重さ 低／確信度 低
- YoseComponents.swift:112（UIAccessibility.isReduceMotionEnabled）と 300 付近（YoseSpeechBox は @Environment で別方式）。
- 手順：ButtonStyle は UIKit の値を直接読むため、アプリ使用中に設定を変えても次の再描画までは反映されない。SpeechBox は環境値で、onAppear 時のみ判定のため、点滅開始後に設定を ON にしても止まらない。
- 直し方の案：ButtonStyle も @Environment(\.accessibilityReduceMotion) に統一。推測が主で実害は小さい。

### 4. YoseHankoStamp.spoken が Int 変換で負数・小数を拾う　重さ 低／確信度 低
- YoseComponents.swift:236 付近（`Int(t) != nil`）。
- 手順："-3" のような文字列が来ると「-3点の判」と読み上げる。現状 GameCore が負の点数を判子にするかは未確認（推測）。
- 直し方の案：判子に渡す値の範囲を確認し、不要なら対応しない。

## 件数
高 0／中 0／低 4（うち確信度 低 2）。この束のファイルは小さく、落ちる・止まる類のバグは見つからなかった。
次に点検価値が高いのは「文書に出てこない」ではなく「行数が大きく状態を持つ」ファイル（View 系の大型ファイル）。文書への言及数の基準だと、既に主要ファイルは点検済みの可能性が高い。

## 確かめた結果（親・11/16）
- WaIcon は WaIcons.swift の外から呼ばれていない（grep で0件）＝死んだコード。消すかは今後使う予定次第なので並べるだけ。
- 押下音の二重：YoseComponents.swift:142 は silent を見ている＝呼ぶ側で silent を付け忘れた所だけの話（確信度 低）。直さない。
