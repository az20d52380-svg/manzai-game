<!-- 引き継ぎ / 声の実装→実機テスト（proposals専任セッション → MVP側CLIセッション）/ 2026-07-06 -->

# 【引き継ぎ】声をSwiftへ配線して実機テストへ

## 結論（3行）

**書いた声（voice_bible/voice_corpus・500行超）は、まだ1行もSwiftに入っていない。** `DialogueData.swift`/`JudgeData.swift`は7/5時点の旧内容のまま（`pick(lowStamina,...)`が2行ずつ、「財布が軽い。ネタより先に、家賃だ。」等）。今すぐ実機で見えるのは**この旧内容**で、書いた新しい声ではない。

**正典の所在に注意**：`main`の`voice_corpus_v0.md`は途中版（コミット`a5badcc`まで）。**最新は`claude/manzai-voice-calibration-2i9etz`ブランチ**（コミット`0be8a11`）＝§8再監査・選択肢イベント会話・大会前後会話書き直し(Task6)・相方名是正まで含む。**必ずこちらをfetchすること。**

```
git fetch origin claude/manzai-voice-calibration-2i9etz
git show origin/claude/manzai-voice-calibration-2i9etz:docs/voice_bible_v0.md > /tmp/voice_bible_v0.md
git show origin/claude/manzai-voice-calibration-2i9etz:docs/voice_corpus_v0.md > /tmp/voice_corpus_v0.md
```

作業ブランチはこのcalibrationブランチを引き継ぐか、そこからMVP実装用の新ブランチを切る（CLAUDE.mdのセッション運用ルール＝同一ブランチの同時編集禁止に注意）。

---

## Part A — 配線（Swiftへの転記）

配線は6種類。**難易度が大きく違う**ので、下から順に着手すること（安い順）。

### A-1. 心の声（`DialogueData.swift` の `pick()` 配列）— 最も安い・golden安全

**現状**（`DialogueData.swift:42-62`）:
```swift
private static let lowStamina = ["さすがに体が重い。無理はきかない。", "疲れが抜けていない。今日は無理しないでおこう。"]
private static let lowMoney = ["今月はきつい…バイトを挟むか。", "財布が軽い。ネタより先に、家賃だ。"]
private static let losing = ["何が足りないんだ…。", "同じ壁の前で、また止まっている気がする。"]
private static let passedLines = ["先週の通過、悪くなかった。次に行こう。", "手応えはあった。ここで気を抜くなよ、俺。"]
private static let 平常 = ["今週も、一歩だけ前に。", "焦らず、四分をよくするだけだ。", "調子は悪くない。このまま積み上げよう。"]
```

**やること**: `voice_corpus_v0.md` の以下の節から本文列だけを抜き出し、上記の配列に**丸ごと置換**する。

| 配列 | corpus節（seed＋量産分） |
|---|---|
| `lowStamina` | §1-2（seed）＋ §8「lowStamina」（+3行） |
| `lowMoney` | §1-3（seed）＋ §8「lowMoney」（+3行） |
| `losing` | §1-4（seed）＋ §8「losing」（+3行） |
| `passedLines` | §1-5（seed）＋ §8「passedLines」（+2行） |
| `平常`（`default`） | §1-1（seed 6行）＋ §8「default 平常の心の声」（+8行、うち1行は0709時点で「相方」に是正済み） |

- **相方名は既に是正済み**（`谷口`→`相方`置換、コミット`0be8a11`）＝そのままコピーして良い。**新たに`谷口`等の相方固有名を書き加えない**（`slots.md`「相方名の焼き込み禁止」＝コード上`innerVoice`は相方非依存）。
- `pick(_ pool: [String], salt: Int)` は乱数を引かない（saltは既存state値の剰余）＝**配列を差し替えるだけでgoldenに触れない**。`swift test`は緑のまま。
- `reaction` 辞書（`DialogueData.swift:69-82`）は §1-7（seed）＋ §8「reaction 残6種」で12キー全部に本数を足せる。**ただし`rest_相方と過ごす`キーの既存値「谷口と、ネタ抜きで飯でも。」は相方名の既知違反＝置換候補**（`slots.md`に明記済み）。§1-7 seedの同キー行（相方名なし版）に差し替え推奨。**現状UIから未参照の可能性あり**（slots.md注記）——配線前に`WeekMainView.swift`で`DialogueData.reaction`の呼び出し有無を確認。

### A-2. 予選講評（`JudgeData.swift` の配列）— 安い・golden安全

**現状**（`JudgeData.swift:15-51`）は`pass`/`fail`/状態フック4種の配列。corpus側は:
- `verdict.pass`/`verdict.fail` 汎用: §2（seed）＋ §8「予選講評 状態フック残り」＋今回追加分（音羽/卯月=通過, 花園/白波=敗退）
- 状態フック `passChemistryHigh`/`passStaminaLow`/`failMentalLow`: §8に完成分あり

**注意**: corpus側は「話者（審査員名）＋本文」のペアだが、現行`review(passed:state:salt:)`の戻り値は`(text: String, judge: String)`——**話者ローテのロジックを壊さず本文だけ差し替える**（該当関数のロジックは変更しない。数式ではないが選定順序に触れるなら一度止めて確認）。

### A-3. 大会前後会話・週次相方会話（`会話.*`）— **未実装・新規UI要**

corpus §5（大会前夜/予選通過/予選敗退3年連続/準決敗退/決勝進出/週次相方会話）は**話者ごと1セリフの会話送り**を前提にしているが、現行`DialogueData`/`Advice`は「俺」単独の1行独白のみ（`Advice.name`はnullableで将来の話者切替を見込んだ設計だが、**複数話者を順送りする実装は存在しない**）。
- ここは**テキストを流し込む前に、話者切替の会話送りUIを新設する必要がある**（0003/0025/0027等の過去提案が共通して指摘している未実装点）。
- 小さく始めるなら：`会話.決勝進出`（谷口版＋相方=八雲版、Task6で確定済み）を`WinFinaleView`に足すのが一番近い（下記A-5参照、ただし分岐設計の食い違いに注意）。

### A-4. 決勝コメント `final.B`/`final.D` — **未実装**

`JudgeData.swift`に決勝コメント機構自体が無い（正本は`docs/judge_design_v0.md`のみ）。corpus §3・§8には7審査員×B帯/D帯がほぼ揃っている（花園/卯月/白波/目白/神楽坂は今回追加、天堂寺/音羽はseed）。**画面（決勝の顔付きコメント表示）を新設してから流し込む**。

### A-5. 山場（決勝敗退・優勝・年次独白）— **分岐がズレている・要判断**

ここが一番罠がある。**corpusが前提にしている分岐と、実装の分岐が一致していない。**

- **実装**（`YearResultView.swift:124-130`の`monolog`）: `champion` / `bankrupt` / `reachedFinal` / それ以外、の**4分岐・各1本の固定文字列**（プールではない）。谷口の台詞も直書き。
  ```swift
  if o.champion { return "今年の頂点は——あなたたち。\n谷口が、はじめて言葉に詰まった。「……やったな」それだけ。" }
  if o.bankrupt { return "所持金が底をついた。\n谷口は笑って言った。「まあ、なんとかなるやろ」——今回は、ならなかった。" }
  if o.reachedFinal { return "今年の頂点は——静物画。0.3の差。\n谷口は、何も言わなかった。帰りの自販機の前で「来年な」と、それだけ。" }
  return "今年も、ここまで。\n谷口「来年の、いっちばん面白いネタの話、していい？」"
  ```
- **corpus**（§4-3 `yearEnd.*`）: `躍進年`/`停滞年`/`貧乏年`/`9年目未優勝`の4分岐（`proposals/0008`設計案が前提）。
- **食い違い**: `9年目未優勝`はMVP（`GameSession`は`year=1`固定・多年キャリア未実装）では**到達不可能**。`躍進年`/`停滞年`は現行の`champion`/`reachedFinal`/`else`と**軸が違う**（勝敗の結果でなく調子の良し悪し）。**単純な1:1貼り替えは不可**。

**推奨**: 今回は**貧乏年→`bankrupt`分岐、それ以外の停滞content→`else`（今年も、ここまで）分岐**にだけ対応づけて流し込む（該当corpus本文はA-1と同じ「相方名なし」なので独白部分に使える。谷口の台詞部分は`会話.決勝進出`/`会話.準決敗退`等、Task6で書き直し済みの行に差し替え可）。`躍進年`/`9年目`は**本編（多年）機能として保留**——無理に当てはめない。判断に迷ったら実装せず一度止めて相談。

- `finals.loss`（決勝敗退直後の袖～帰り、seed＋§8で3行）/`finals.win`（優勝・勇退、seed＋§8で7行）は、**`YearResultView`/`WinFinaleView`のどのタイミングに載せるか**（既存の1行固定文の代わりか、追加の1画面か）は設計判断が要る。オーナー確認推奨。

### A-6. 選択肢イベント（`event:0010〜0023`）— **絶対に急がない・新エンジンが要る**

corpus §6には14イベント全てのセットアップ＋分岐会話が揃っている（0010, 0017は完全版。0011-0023はA-1と同様「相方名なし」ではなく谷口版＋一部相方版）。**ただしゲーム側に選択肢イベントを発火・表示する仕組みが一切無い**（`applyEventPatch`/`pendingEvent`等の関数はgrep一致ゼロ＝コード上未着手）。

**実装ブリーフは`proposals/0024_choice-event-mvp-framework.md`に別途ある**。そこに書いた通り:
- 確定発火（抽選しない）＋確定効果（`RandomSource`を呼ばないパッチ）にすれば**golden不変**で入る。
- ランダム抽選や効果内の乱数ロールを入れた瞬間golden（3年ビット一致）に触れる＝**その場合は必ず止めて相談**。
- 最初に着手するなら発火表の安い順（`0018`→`0019`→`0017`→`0010`）。

**この工程はテキストの転記だけでは終わらない**（GameCore/GameSession/UIの新規実装が要る）ので、他の配線（A-1〜A-5）を先に終わらせてから、別タスクとして着手すること。

---

## 配線時の絶対規律（CLAUDE.md再掲）

1. `tools/*.py`（正典）・数式・乱数消費順には触れない。触れたくなったら実装前に必ず止めてオーナーに相談。
2. 配列/プールの中身を差し替えるだけなら`swift test`は緑のまま。**赤くなったら何かが数式/消費順に触れている**——原因を特定してから進める。
3. 新規Swiftファイルを足したら`cd ManzaiGame && xcodegen generate`。
4. **UI変更は`swift test`では検証できない**。simulatorでビルド→起動→各状態まで行動して目視するまで「完了」としない（下記Part B）。
5. 声の規約は`.claude/skills/manzai-drama-voice/`（＋`manzai-choice-events`／`manzai-judge-comments`）に正典化済み。転記した文言に手を入れる場合は、そのSkillの自己採点（A表16項＋該当ならV表）を通してから確定する。

---

## Part B — 実機プレイテストのチェックリスト（配線後）

配線が終わったら、simulatorで実際にプレイして次を確認する。**AIの採点表と同じ観点を、人間の言葉に落としたもの**。

### 状態ごとに実際に見に行く（どう到達するか）

| 状態 | 実機での起こし方 |
|---|---|
| 低体力（`lowStamina`） | 稽古/バイトを連続選択して体力を削る |
| 金欠（`lowMoney`） | バイトをせず稽古や休養を続けて所持金を減らす |
| 連敗（`losing`） | 大会でわざと弱い状態のまま出場して2連敗以上する |
| 直近通過（`passedLines`） | 大会を1つ通過した直後の週 |
| 大会前（`preTournament`） | 大会まで残り2週以内 |
| 平常（`default`） | 上記いずれでもない通常週（最頻＝一番長く見る） |
| 予選講評 | 大会で通過/敗退した直後の紙講評画面 |
| 決勝敗退・優勝 | 決勝まで到達（体力/能力を上げて狙う） |

### 読みながらチェックする8項目（人間版・技術用語なし）

1. **感情語を言ってないか**：「悔しい」「嬉しい」「緊張してる」と直接言っていたら違反。物や仕草で分かるはずのところ。
2. **キザに聞こえないか**：俺のセリフが「うまいこと言った」感じで終わっていたら違反（例：格言っぽい一言で締める）。
3. **方言が合っているか**：谷口以外の相方が関西弁を喋っていたら違反。俺は常に標準語。
4. **同じ話を何度も見た気がしないか**：短時間で似た文が連続して出たら「反復が薄い」のサイン（本数不足の可能性）。
5. **説明台詞になっていないか**：「メンタルが下がった」等、ゲームの数値をセリフで言い直していたら違反。
6. **ボケていないか**：ゲームは笑いを取りにいく台詞（ネタの中身）を絶対に書かない方針。もしどこかでボケているように見えたら報告。
7. **谷口の名前が心の声（俺の独白）に出ていないか**：出ていたら実装ミス（2周目でガチャ相方に変わると破綻する）。
8. **単純に「寒い」「浮いてる」と感じたら、理由がわからなくてもそのまま報告してOK**（Skillの採点表は"迷いゼロは失敗のサイン"という前提で作ってある。人間の直感の方が正しいことが多い）。

---

## Part C — フィードバックの戻し方

1. **「寒い」と感じた行は、そのまま以下の形式でメモ**：
   ```
   スロット: default（平常）
   本文: 「（実際の文言）」
   状況: 3年目・相性15・大会2週前
   感じたこと: 谷口の台詞っぽいのに標準語で喋っていて違和感
   ```
2. 明確な違反（規約に反する）は`.claude/skills/manzai-drama-voice/references/examples.md`の**悪い例に追記**（理由タグ付き）——次の量産で同じ間違いを踏まないための資産になる。
3. 「理由は分からないが寒い」は`voice_bible_v0.md`/`voice_corpus_v0.md`側にコメントとして残し、次回オーナー判断で原則化するか検討。
4. 配線・修正した内容は**calibrationブランチ（またはそこから切った実装ブランチ）にpush**。声の内容そのものを変える場合はSkillの採点ゲートを通してから確定する。

---

## 参照ファイル一覧

- 声の正典（**最新はcalibrationブランチ**）: `docs/voice_bible_v0.md`／`docs/voice_corpus_v0.md`
- Skill（main反映済み）: `.claude/skills/manzai-drama-voice/`／`manzai-choice-events/`／`manzai-judge-comments/`
- Skill運用ガイド: `docs/skill_handoff_v0.md`
- 選択肢イベント実装ブリーフ: `proposals/0024_choice-event-mvp-framework.md`
- 選択肢イベント本文（14本）: `proposals/0010〜0023`
- 実装対象ファイル: `ManzaiGame/Sources/DialogueData.swift`／`JudgeData.swift`／`YearResultView.swift`／`WinFinaleView.swift`／`WeekMainView.swift`
- キャラ書き分け調査: `proposals/0037_character-voice-differentiation.md`

これは種・数値は全て【仮】・最終確定は実機目視。
