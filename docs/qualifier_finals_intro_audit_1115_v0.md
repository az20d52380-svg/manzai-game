# 予選の知らせ・決勝進出者の発表・初舞台・決勝の番組導入 点検（11/15・読むだけ）

- 要点1：新規 4 件（高0・中0・低4）。落ちる所・画面が二度出る所・閉じた後に走る遅延は見つからず。
- 要点2：一番重いのは 低-1「予選の通過者一覧が 1回戦・2回戦・3回戦で同じ顔ぶれ」（種が `roundName.count`＝3回戦とも5）。
- 要点3：既出（gp_final #4＝発表10組と決勝9組のずれ／settings_leak／delayed_callback／double_tap／sound_state 等）は除いた。
- 節構成：§低-1〜低-4 → §問題なし一覧

対象：QualifierNoticeView.swift／FinalistAnnounceView.swift／FirstStageView.swift／FinalsBroadcastIntro.swift（呼び出し側 TournamentResultView:279-291・FinalsPresentationView:203・IntroFlow:862 も確認）。

### 低-1 予選の通過者一覧が 1回戦・2回戦・3回戦で同じ顔ぶれになる
- 場所：QualifierNoticeView.swift:40（`FinalsData.yearRoster(year: year &+ roundName.count &* 31, …)`）。
- 手順：「GP1回戦」「GP2回戦」「GP3回戦」はどれも5文字＝種が同じ → 同じ年なら 3 回とも同じ 8 組（落選時は 9 組）が同じ並びで出る。準々決勝はチャット形式なので一覧なし。週は 30/39/41…と離れているが、現実の予選は回戦が進むほど残る組が絞られるのに、同じ名前が 3 回出る。
- 既出か：新規。（AUTOPILOT 110＝一覧の長さの判断待ちは別論点。qualifier_list_research §5 は長さのみ）
- 直し方の案：①今のまま（回戦間で名前を覚えている人は少ない）②種に回戦の番号を足す（`roundName.count` を `roundName.hashValue` でなく固定の添字、例：1回戦=1,2回戦=2,3回戦=3 に）。②は表示だけで GameCore・乱数に触れない。ただし回戦が上がるほど前の回戦の組が混ざる方がより現実的なので、さらに凝るなら「3回戦の一覧は2回戦の一覧の部分集合」にする案もあるが、判断が要る。推奨②の素朴版（理由：1行・非接触・同名反復が消える）。

### 低-2 漢字・英字のコンビ名は、読み上げ順と通過者一覧で必ず末尾／先頭に並ぶ
- 場所：FinalistAnnounceView.swift:73-77（`readOrder`・自組の yomi＝名前をひらがな化しただけ）／QualifierNoticeView.swift:44-45（同じ型の並べ替え）。他組の yomi は全部ひらがな（50組すべて辞書にあり・確認済み）。
- 手順：コンビ名を漢字（例「十字路」）にする → 文字コードがひらがなより大きい → 決勝進出者の発表で必ず最後（＝溜めの2組のうち最後）に呼ばれ、通過者一覧でも必ず一番下。英字名なら必ず最初。ひらがな／カタカナ名だけが本物の五十音位置になる。ヘッダの「読み上げは五十音順＝成績の手がかりにしない」と、実際の効果（漢字名の人は通過した年に毎回「最後に呼ばれる」）が食い違う。落ちる所はなし。
- 既出か：新規（long_name_layout は幅のみ）。
- 直し方の案：①今のまま（漢字名の人が最後に呼ばれるのは演出として悪くない）②自組の位置だけ年で決まる決定論の疑似乱数で置く（`year` と名前から位置を出す・一覧では 9 行のどこか）。推奨②（理由：注記と実際を揃えられる・表示だけ）。ただし「最後に呼ばれて溜めが乗る」を気に入っているなら①。判断はオーナー。

### 低-3 決勝の番組導入（FinalsBroadcastIntro）は、直前画面のボタンの二度押しで最初の場面を飛ばしうる（未確認）
- 場所：FinalsBroadcastIntro.swift:48（`.onTapGesture { advanceStage() }`・出始めの無視時間なし）／呼び出し FinalsPresentationView.swift:202-206。
- 手順：決勝の「本番前カード」の進むボタン等を素早く二度押し → 二度目のタップが出たての導入に当たり、煽りV（vtr）が即タイトルへ進む。初回はフル尺を見せたい場面で、1 場面が一瞬で消える。結果画面（TournamentResultView）は `tapAccepted()` で出始め 0.4 秒を無視しているが、導入には無い。
- 既出か：double_tap_audit_1115 は導入の `done` の二度終了のみ（#51）。出始めのタップは新規。直前画面がボタン連打を許すかは未確認＝実害は小さい。
- 直し方の案：①今のまま②onAppear 時刻を持って 0.4 秒は `advanceStage()` を無視。推奨②（理由：数行・結果画面と同型・スキップボタンは別経路で生きる）。

### 低-4 発表の文言「敗者復活戦は決勝当日です」と、他の画面の呼び方の細かいずれ
- 場所：FinalistAnnounceView.swift:90（「敗者復活戦」「決勝当日」）／SettingsView.swift:288（「決勝と同じ週の舞台」）／WeekRunner の大会名「敗者復活」。
- 手順：発表の司会は「敗者復活戦」、結果・大会名・設定は「敗者復活」。「当日」は実装上は「決勝と同じ週の舞台」で、同じ日の昼に行う設計（reachedFinalViaRevival の講評の「昼からもう一本」と合う）。実害なし。
- 既出か：AUTOPILOT 89 の「敗者復活の案内（オーナー確認待ち）」の隣接論点。文言の揺れは新規（軽微）。
- 直し方の案：①今のまま（司会の口調として自然）②「敗者復活は決勝と同じ日です」に揃える。推奨①。

## §問題なし一覧

- **落ちる所**：QualifierNoticeView `resultLines` の添字（`n - 3 < count`・`0..<max(0,msgs-2)`＋`i < count`）／FinalistAnnounceView `swapAt`（`nx() % (i+1)` は i≥1）・自組の置き場 `count/2+count/4`＝15枠で10・16枠で12（範囲内）・`order[i]` は一度取った配列／FinalsBroadcastIntro `judges[min(step,7)-1]`（`cur>=0` ガード・テロップは `step>=1`）・`parts[0]`（7名とも空白あり）・finalists 空でも `0..<0`。強制アンラップ・`first!`・`max!`・Int 変換は4ファイルとも無し。
- **名簿の一貫**：`yomi` 辞書 50 組＝`npcNames` 50 組（過不足 0・重複 0）。自組名が mob と同名でも `pool` から除かれ ForEach の `id: \.self` は重複しない。落選時の一覧9組は通過時の8組の上位互換（同じ prefix）。
- **15年目・年またぎ**：4画面とも `year` は表示と名簿の種だけ。15年目で変わる所なし。決勝導入の「結成N年目」は session.year（決勝は同年内）。敗者復活は準決勝落ち＝常に出られる（WeekRunner:277・421）ので「決勝当日」の案内は常に正しい。
- **女コンビ（THE HANA）**：QualifierNoticeView の `HANA1回戦` は動画審査の送り主・表題だけ差し替え（`applies` は HANA1回戦のみ）。決勝導入・発表は GP 専用で HANA は通らない。他の HANA 2回戦以降は通知なし（仕様）。
- **二度押し・途中で閉じる**：QualifierNotice/FinalistAnnounce の `finish`・`つづける`・飛ばす は二度呼ばれても呼び元は `qualDone=true`/`announceDone=true` を立てるだけで無害。FirstStageView の第1週へは `finished` ガード、IntroFlow 側も `finished` ガード。FinalsBroadcastIntro は `done` ガード。
- **遅延コールバック**：4ファイルの Task は `.onDisappear` で cancel。QualifierNotice は `open()`/`pickOpen()` で前の task を cancel して作り直し、各ループ頭・成功音の前で isCancelled を確認（チャット枝 :232 の msgs=1 は既出・無害）。FinalistAnnounce `pause()` は取り消しで抜け、`run()` の各段で再確認。skipAll 後に `dim=true` へ戻る経路なし。FirstStageView `wait()` は取り消しで false。FinalsBroadcastIntro は各ループ頭と末尾に `guard !Task.isCancelled`＋`advanceStage(from:)` の場面照合。
- **中断復元**：結果画面は復元で最初から再生される（qualDone/announceDone/introDone は @State）ので、予選の知らせ・発表・導入も二度見るだけで結果は同じ。導入は `seenKey` で短縮版。
- **FirstStageView**：`onSkip` は本番（IntroFlow:862）では渡されない＝飛ばす経路は DEBUG のみ（死んだ引数・実害なし）。VoiceOver 中は自動で押さない。reduceMotion 対応済み。
- **文言**：大会名は「頂GP」（通知・設定が許容）／「頂グランプリ」（番組・決勝）の使い分けが設定の説明（SettingsView:287）と一致。「決勝進出 N組」は d.entries の件数で観戦年10・通常10（自組込み）と一致。「1本目の上位3組が最終決戦へ」は duelEntries 3 組の注記と一致（hardcoded_numbers_audit 既出の審査員7名と同じ扱い）。
