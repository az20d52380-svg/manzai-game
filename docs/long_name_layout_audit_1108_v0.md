# 長い名前の画面崩れ 静的点検（2026-11-08 v0）

**結論**
1. 入力上限は コンビ名＝全角12字（IntroFlow.swift:525）・自分／相方の名前＝全角6字（Names.maxLength）。点検した表示箇所のうち、実際に崩れるのは1件（導入回想の縦名札 RecallNameBoard）。際どいのが2件。
2. 最も目立つ崩れ：IntroFlow.swift:253 の縦書き名札。字26pt×字数を高さ150/176の枠に積むため、自分の名前5字以上・相方6字で枠の下へはみ出す。
3. それ以外のコンビ名の出し先は lineLimit(1)＋minimumScaleFactor か縦札の字号縮小で最大長に対応済み。台詞の文中に入る名前は折り返し可なので対象外。

方法：Text を grep→周囲を sed で読んで机上判定。Names.swift:54 の Text(String) 拡張が自動で Names.show を掛けるため、台詞系は全て差し替え対象。際どい1件だけ iPhone 17 sim（MZ_UI=finalist_announce／MZ_COMBI／MZ_HOLD_AT=10）で1枚確認。MZ_COMBI（GameSession.swift:221）以外に名前を入れる環境変数は無く、自分／相方の名前は机上のみ。

## 表（最大長＝コンビ名12字／自分・相方6字）

| ファイル:行 | 出す物 | 修飾 | 最大長での結果 | 直すなら（1行） |
|---|---|---|---|---|
| IntroFlow.swift:253（RecallNameBoard、使用 196/197/209/210） | 縦書き名札＝自分(俺)／相方(谷口)の名前 | 縦に1字ずつ mincho26＋spacing2、枠は height 150/176 固定・字号固定・lineLimit なし | **はみ出す**：6字≒190pt超が150〜176の枠を越え、枠外（下の机・帯）に重なる（自分5字以上・相方6字） | StageMakuri と同様に字数で字号を縮める（n>4 で 26→max(16,…)）か minimumScaleFactor を掛ける |
| S6bView.swift:226 | 壁写真の下のコンビ名 | maru12、lineLimit なし、幅150の写真に overlay・offset | **際どい**：12字≒144pt で幅150ぎりぎり。フォント差で2行に折れて写真の下端へ（未実測） | lineLimit(1)＋minimumScaleFactor(0.6) を付ける |
| FinalistAnnounceView.swift:164/185 | 発表の自組名札（7字で「…」省略） | gothic13 bold・fixedSize・overlay・scale1.18 | 省略で最大≒8字相当。sim 1枚（12字）で中央席は問題なし。端の席だと名札が画面外に半分出る可能性（席は乱数） | 端の席の時だけ位置を内側へ寄せる、または省略を5字に |
| IntroFlow.swift:73 → Design/YoseComponents.swift:301-316（YoseSpeechBox の speaker） | 台詞の話し手札（自分／相方） | gothic15 fixed、minWidth58、lineLimit なし、横並び | 6字≒90＋余白で約106pt。台詞側が約250pt に狭まるだけ。折れない（話し手が長いほど台詞の行数が増える） | 現状で可。気になるなら speaker に lineLimit(1) |
| IntroFlow.swift:130 | 助言の1行「名前「…」」 | mincho14、折り返し可 | 問題なし（文中・折り返し） | — |
| TalkParts.swift:86/IntroFlow.swift:137 | accessibilityLabel | 読み上げのみ | 問題なし | — |
| Design/YoseChampionCelebrationView.swift:392 | 優勝演出の相方名ラベル | gothic13 heavy、padding8、HStack 先頭、lineLimit なし | 6字≒78＋16＝94pt。台詞側が狭まるだけ。問題なし | — |
| Design/YoseChampionCelebrationView.swift:288 | 優勝コンビ名 | mincho30、lineLimit1＋minScale0.7 | 12字＝360pt は幅超え→0.7で≒252pt＋padding40。画面幅内（小さくなる） | — |
| Design/YoseYearTurnCurtain.swift:204 | 年替わり幕のめくり台のコンビ名 | mincho15・tracking3、lineLimit なし、台 幅290固定（内側266） | 12字＝約216pt＋留め具18。入るが余裕約30pt。縮まない・折れない（問題なし／際どさ小） | lineLimit(1)＋minScale を保険に |
| StageFrame.swift:453（StageMakuri、使用 FinalsPresentationView:121 ほか） | 舞台のめくり札（縦書きコンビ名） | 字数で字号を縮小（12字で11pt／big 15pt） | 縮小済みで収まる（コメントに最大12字対応の記載あり） | — |
| StageFrame.swift:321（StageSign、使用 FirstStageView:51） | 初舞台の看板 | lineLimit1＋minScale0.7 | 縮む（問題なし） | — |
| StageFrame.swift:398（StageLowerBand の name） | 舞台下の帯のコンビ名 | mincho16、lineLimit1＋minScale0.7 | 縮む（問題なし） | — |
| FinalsBroadcastIntro.swift:497（FinalsEntranceDoors） | 入場扉のコンビ名 | mincho26、lineLimit1＋minScale0.5 | 縮む（問題なし） | — |
| FinalsPresentationView.swift:535 / 797 / 841 | 決勝のコンビ名（出番札・合計ボード・採点バー） | mincho22/20/17、lineLimit1＋minScale0.6 | 縮む（12字×22pt=264 が0.6まで縮んで収まる）。問題なし | — |
| FinalsPresentationView.swift:575/960/961（MC の吹き出し） | MC 台詞内のコンビ名 | 吹き出し・折り返し可 | 問題なし（文中） | — |
| TournamentResultView.swift:139 | 結果画面のコンビ名 | mincho14、lineLimit1＋minScale0.6 | 縮む（問題なし） | — |
| CalendarView.swift:46 | カレンダー上部のコンビ名 | gothic17 heavy、frame(maxWidth: .infinity)、lineLimit なし | 12字≒204pt＜画面幅。収まる（問題なし） | — |
| NotebookView.swift:39（YoseHeaderBar の subtitle） | 手帳ヘッダーの副題 | gothic12 bold、lineLimit なし、中央寄せ | 12字≒150pt 収まる。閉じるボタン用の左 Spacer 64 があるが幅内（問題なし） | — |
| NotebookView.swift:91-98 | 名札の行（コンビ名／相方） | mincho18、lineLimit1＋minScale0.6、ラベル幅72固定 | 12字＝216pt が約250の余白に入る（問題なし） | — |
| QualifierNoticeView.swift:93 / 161 / 192 | 通知の相方名・トーク見出し | gothic13/16 bold、HStack＋Spacer | 6字で収まる。問題なし | — |
| QualifierNoticeView.swift:119（通過者一覧の行、自組＝コンビ名） | 通過者一覧 | mincho18、HStack、幅は画面幅 | 12字＝216pt 収まる。問題なし | — |
| ShareCard.swift:19 | 共有カードのコンビ名 | serif52、minScale0.4＋lineLimit2、中央 | 2行まで折れて縮む。12字は1〜2行で収まる（問題なし） | — |
| S6bView.swift:78 | 最後の舞台の見出し「◯◯　最後の舞台」 | mincho18、lineLimit1＋minScale0.6 | 縮む。16字≒288pt、問題なし | — |
| S6bView.swift:202 | 「—— ◯◯ ——」 | serif13、折り返し可 | 12字＋記号≒210pt、収まる（折れても崩れない） | — |
| EndingViews.swift:377 | 図鑑の「相方：◯◯」 | gothic12、lineLimit1＋minScale0.7 | 縮む（問題なし） | — |

## 補足
- 自分の名前（Names.me）は、台詞の話し手札・縦名札・文中の「俺」差し替えに使われる。縦名札（RecallNameBoard）が最大の弱点。
- 「相方：◯◯」「谷口→相方名」の文中差し替えは折り返し可で問題なし。
- 実測は FinalistAnnounceView の1枚のみ（scratchpad/fa.png、12字で中央席は問題なし）。RecallNameBoard と S6bView:226 の確認は、名前を入れる環境変数（自分／相方）が無く未実測。必要なら MZ_ME／MZ_PARTNER の目視フックを足してから確認する。
