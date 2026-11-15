# S6b／コンビ形選択／ネタ選択カード コード点検（11/15・読むだけ）

1. 対象 3 ファイル（S6bView 246行・ComboKindPickerView 57行・NetaSelectionView 158行）と読む値を点検。新規 3 件（中 0・低 3）。落ちる所（強制アンラップ・空配列 first!/max!）は無し。
2. 一番重いのは 低-1：S6b の最後の「また、幕が上がる ▶」ボタンが、見えない間（opacity 0 の0.8秒）も押せて、連打で onFinish が2回走る。
3. 配列の添字・遅延コールバック・15年目表記・旧セーブ nil は、この3ファイルでは問題を見つけられなかった（§問題なし一覧）。

## 新規

### 低-1 壁写真の「もう一度」ボタンが透明のまま押せる／連打で onFinish が2回
- 場所：S6bView.swift:232-236（`.opacity(burned ? 1 : 0)`）、呼び先 RootView.swift:365 returnToTitle・EndingViews.swift:59 s6bDone
- 手順：勇退（#7 championRetire）で壁の場面に入った直後（0.8秒以内）、ボタンのある下部を叩く。または表示後に素早く2回叩く。
- 起きること：opacity 0 は当たり判定を消さない＝見えないボタンが効く。焼き付き（写真と「楽屋の壁」の文）を見ないままタイトルへ戻る。2回叩くと returnToTitle が2回走り `GameSession()` が2つ作られる（2つ目が1つ目の保存を上書きするか＝未確認）。
- 既出か：double_tap_audit_1115 に S6b の記載なし（grep 済）。stale_timer_audit_1115 は counted のみ。
- 直し方の案：①ボタンに `.allowsHitTesting(burned)` を足す（推奨：1行・見た目不変）②加えて onFinish 側に「一度だけ」フラグ（@State done）。①だけで0.8秒の窓は消えるが、表示後の連打は②で止まる。①＋②を推奨。

### 低-2 NetaPickRow の `requiredLength`（尺）が画面のどこにも出ない
- 場所：NetaSelectionView.swift:13（引数）・冒頭コメント「尺マッチのラベル表示」・StageViews.swift:191,321,327（渡している）
- 手順：大会入口・GP 各回戦でネタ札を開く。
- 起きること：呼び出し側は尺（大会ごとの長さ）を毎回渡すが、カード内で一度も使っていない＝尺の表示は無い。設計 v2 §4-3 の「尺マッチのラベル」と画面が食い違う（尺は表示のみで合否に効かない設計なので害は無く、情報が出ないだけ）。
- 既出か：neta_audit_1115 に該当なし（grep 済）。
- 直し方の案：①引数を使って候補行に「尺：◯」札を出す ②設計を「尺は出さない」に改め、未使用引数を消す。推奨は②（％や見込みを出さない方針に近く、画面が足りている）。判断はオーナー。

### 低-3 千秋楽の「最終到達舞台」が成績ではなく所持金の帯で決まり、次の年表とずれうる
- 場所：S6bView.swift:81-89（見出し・4段階の札）と :151-159（venueTier は s.money の帯）
- 手順：15年で区切る（tenYearsClose）または優勝で、所持金が少ないまま千秋楽へ。直後の年表（:178- の各年の到達）で「優勝」「決勝」が並ぶ。
- 起きること：所持金が少ないと「最終到達舞台：町の劇場」と出る一方、年表には頂グランプリ優勝が並び、「到達」の意味が画面内で食い違って見える。所持金を失った年に出ると借金でも「¥0」表示（既出 number_display_audit_1108 #13）。「全額懸ける」と言うが state.money を実際に0にはしていない（表示のみ・その後の画面で所持金が出るかは未確認）。
- 既出か：見出しの意味のずれは未記載。借金表示のみ既出。
- 直し方の案：①見出しを「最後の舞台の大きさ」等、所持金で決まる意味に改める ②venueTier を年表の最高到達（優勝→ドーム等）から決める。推奨は①（数式・演出の意図を変えず文言だけ・golden 非干渉）。

## §問題なし一覧
- 添字：S6b の `venueNames[t / venueTier]`＝4要素固定・venueTier は 0〜3 のみ（既出確認）。`montageCards` は固定3枚。`first!`／`max!`／`[0]` はこの3ファイルに無い（grep 済）。NetaPickRow の候補は `filter`、既定ネタは GameSession.ensureStageNetaDefault が `max(by:)` を guard 付きで使う。
- 15年目：S6b に「10年」直書きは無し（grep 済）。tenYearsClose は興行のみ（kougyouOnly）で終わり、年表・壁には進まない。年表は `yearHistory` を回すだけで15行まで ViewThatFits＋ScrollView。0行でも落ちず（枠だけ出る＝害は小）。
- 女コンビ：ComboKindPickerView の4枚は cardTitle／cardSub／顔を ComboKind から引き、「俺」「私」の説明文と矛盾なし。S6b モンタージュの「俺」「谷口」は Names の置き換えを通る（name_substitution_audit_1115）。
- 旧セーブ nil：tiredYears nil は `?? 0`（NetaTiredBadge）。comboKind／myName の nil は既定（男コンビ・俺・谷口）。S6b は session.state・yearHistory のみ読む。
- 二度押し：ComboKindPicker は `picked` で2回目を無視（既出 stale_timer_audit_1115）。年表の「タップで進む」は advance が同じ値への代入で無害。千秋楽ボタンも同様。
- 遅延：ComboKindPicker:39 の asyncAfter 0.3秒は既出（delayed_callback_audit_1108 ③）。S6b:135 の Task は `counted = true` にしか書かず、閉じた後に走っても無害（既出）。NetaSelection:57 は DEBUG のみ。
- ネタ選択：1本目で2本目と同じネタを選ぶと2本目が黙って外れる件は既出（decision_brief C-17・neta_audit_1115 備考）。2本目の既定が入らない件は neta_audit_1115 N1。同じネタを2回並べない・候補が空の時の文言（「ほかにかけるネタが無い」）は問題なし。
- 画面同士の文言：「このコンビでいるあいだは変えられない」はコンビ形の仕様どおり（newcycle_audit_1115 の周回やり直しとは別）。
