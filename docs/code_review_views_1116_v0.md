# コード点検 11/16（StageFrame・ChoiceEventOverlay・AbilityUpView・読むだけ）

## §1 要約
- 3ファイルを通読し、呼び元（WeekMainView:189/193・TournamentResultView:264・FinalsPresentationView:121/143/211）と GameSession の applyEventChoice／dismissChoiceEvent／availableEventChoices まで当たった。
- 件数：高0／中0／低3／要確認3。確定結果や状態を壊す物は見つからず。修飾子がコメント行に飲まれた箇所は3ファイルとも0件（正規表現で確認）。
- 一番重いのは §2-1（能力アップの行の経験点の数字が、VoiceOver で通貨名なしの裸の数字として読まれる）。

## §2 指摘

### 1. 能力アップ画面の行：値札の数字が「何の経験点か」なしで読まれる（低・確信 中）
- AbilityUpView.swift:345〜357（row の経験点5列）。各セルは `Text("\(n)")`／`Text("-")` だけで label も group も無く、行全体にも accessibilityElement が無い。
- 起きる条件：VoiceOver で行を送ると「センス」「12」「センスを元に戻す」「センスを上げる」の後に、通貨名なしの数字が5つ順に読まれる。見た目は列の色と上の見出し（閃・語…）で分かるが、読み上げには通貨名が出ない。空きは「-」が「ハイフン」と読まれる。
- 直し方の案：セルに `.accessibilityLabel("閃き 4")` のように通貨名つきを付ける（空きは accessibilityHidden）。または5セルを1つにまとめて「必要な経験点：閃き4、語彙…」と読ませる。
- 補足：＋の hint「経験点が足りない」は canTap=false の全てで出るため、器・上限・逓減で押せない時も同じ文になる（既知＝abilityup_audit_1115 #7 と同根）。

### 2. 効果チップの「↑↓」と下の黒帯の表示丸めが食い違う（低・確信 中）
- ChoiceEventOverlay.swift:309（showEffects の `add`：差が ±0.001 超なら ↑↓）と :104-105（黒帯は `Int(stamina.rounded())`・`Int(fame.rounded())`）。
- 起きる条件：体力・知名度が 0.5 未満だけ動く選択肢。「体力 ↑」のチップと読み上げ「体力が上がった」が出るのに、黒帯の数字は選ぶ前と同じ。選択肢の効果量が実際に小数かは ChoiceEventTable を全件は見ていない。表示だけで、効果自体は正しく入る。
- 直し方の案：チップ判定を表示と同じ丸め（rounded 後の差）にする。または方向だけ見せる規約のため現状維持。

### 3. 開演の儀：中断されても「初回」を消費してしまう（低・確信 高）
- StageFrame.swift:299-300（`seenKey` を run の最初で true にする）。
- 起きる条件：初回の儀（約1.5秒）が始まった直後に画面ごと消える（取り消し→ abandon 経路）。次に出る儀は短い版（約0.6秒）になり、長い初回版は二度と見られない。実害は演出の長さだけ。
- 直し方の案：seenKey は finish() 内（または2つ目の sleep 後）で立てる。

## §要確認
### A. StageMakuri が VoiceOver で1文字ずつ読まれる恐れ（低）
- StageFrame.swift:472。`ForEach(name.enumerated())` の1文字ごとに別 Text で、VStack に accessibilityElement／label が無い。呼び元 FinalsPresentationView:121・:143 は `allowsHitTesting(false)` 等のみで accessibilityHidden もしていない。
- 起きる条件：VoiceOver で決勝進行を送ると「そ」「よ」「風」「ズ」と1字ずつ止まる可能性。上位の view でまとめている／隠している可能性は未確認。
- 直し方の案：Makuri の外側 VStack に `.accessibilityElement(children: .ignore).accessibilityLabel(name)`、または装飾として hidden。

### B. 能力アップ：確定の余韻中に「戻る」が押されると、画面を閉じた後で反映が走る（低）
- AbilityUpView.swift:473-475（confirm の `Task { sleep; finishConfirm() }`）と :432（「戻る」＝反映せず閉じる）。余韻の Task は view に結びついておらず、閉じた後でも finishConfirm → `session.allocate(t)` を実行する。
- 通常は余韻中 `confirming` の透明なタップ面（:83-85）が全画面を覆うので指では「戻る」に届かない。VoiceOver／スイッチコントロールで透明面を越えて押せる場合だけ起きる（voiceover_audit_1109 #12 の透明面と同根。実機で未検証）。
- 直し方の案：余韻中は footer を `.disabled(confirming)`、または「戻る」で confirming なら finishConfirm() に回す。

### C. 「覚える？」ダイアログ：Button の action と Binding.set(false) の順序（低）
- AbilityUpView.swift:112-122。Binding の set が `skillToLearn = nil`、「覚える」の action は `guard let k = skillToLearn` で読む。OS によって set(false) が先に走れば何も起きない。
- iOS のバージョン依存で、実機で覚えられている前提なら問題なし（目視済みか未確認）。直す場合は `confirmationDialog(_:isPresented:presenting:)` に変えて対象を引数で渡す。

## 既知（重ねない）
- AbilityUpView：特技を覚える時に未確定の＋が黙って確定／「−」は行の全段を戻す／「+N段階」の単位／四捨五入と切り捨ての食い違い／押せない理由が出ない／おまかせの置き換え（abilityup_audit_1115_v0 #1〜#8）。
- 余韻中の透明面の VoiceOver（voiceover_audit_1109 #12・1115）。確定の二重押し（code_review_2026-10-19e §4＝confirmFinished で解決済み）。
- ChoiceEventOverlay：isFlavor の判定（code_review_2026-10-19 #1）、選択直後の強制終了で二重適用（2026-10-19c＝choiceApplied を保存から外して解決済み。GameSession.swift:1353 で確認）。
- StageCeremony：取り消し時の BGM 戻し・done の扱い（code_review_1116_night／2026-10-19g／2026-10-27b）。

## §3 見て問題なしの所
- StageFrame：`ForEach(0..<6)`／Canvas のループ（pleat 幅は正で必ず終わる）／audience の `&*` `&+` はオーバーフローしない／`done` ガードで finish は1回（tap と run の完走が重なっても duck(1) は先着1回、run 側は guard で何もしない）／呼び元 TournamentResultView・Finals は ceremonyDone で StageCeremony を外すので、onAppear／.task の再発火で done=true のまま再実行されることは無い。
- ChoiceEventOverlay：`ForEach(lines.enumerated(), id: \.element.id)` の id は setup=0〜・after=1000〜 で衝突しない／選択後に `availableEventChoices()` が変わっても footer は `chosenID == nil` を先に見るので選択肢が出直さない／choose の二度押しは session の choiceApplied と view の `chosenID == nil` の両方で止まる／armFooterIfNeeded の Task は `!hasMore` かつ `!footerReady` でしか立たず重複して残る場面は無い／閉じる二重タップは dismissChoiceEvent が冪等／チップの読み上げ文は見た目の札と同じ言い換え／chunkEnd は範囲外にならない（`guard shown < count`）。
- AbilityUpView：`ForEach(Ability／Skill／ExpCurrency.allCases)` は固定列挙で減らない／k.cost の enumerated は id が offset で安全／tapGen で光りの消去が前の時計に早められない／ExpDisplay.cost は「内部で足りるなら持ち分表示を超えない」ため short 判定と押せる判定がずれない／compareRow と row の整数表示は同じ `Int(x.rounded())`／finishConfirm は confirmFinished で1回／`.task` のヒント表示は閉じた後の view に影響しない（既知 2026-10-19e）。
- 修飾子の飲み込み：3ファイルで「`//` の後ろの同じ行に修飾子」を正規表現で探し0件。
