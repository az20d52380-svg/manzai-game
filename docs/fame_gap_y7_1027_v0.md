# 7年目 知名度 36（第40週）と 33（年末）のずれ（playtest_v16 #5）

## 結論（1行）
(b) 年末画面は別の台本の別走行。本番の不具合ではなく、表示の取り違え(c)でも減衰(a)でもない。

## 根拠
- 知名度に時間経過の減衰は無い。GameCore/Sources/GameCore/GameEngine.swift:58-74 は加算のみ（clamp 0..100）で、decay 処理は見当たらない。第41〜48週で自然に下がる仕様ではない。(a)は否定。
- 年末の知名度の表示元は ManzaiGame/Sources/YearResultView.swift:312 で、現在の `s.fame` を丸めたもの（括弧の差分だけ yearStartState.fame との差）。前年や年初の値の取り違えではない。(c)は否定。
- 走行が違う:
  - 第40週の画面は MZ_YEARS=6（+MZ_CARE=1）+ MZ_STOPWEEK=40。GameSession.swift:1596-1626 の debugAdvanceYears が debugFreeWeek(care:true)（:1636-、相方と過ごす・ネタ合わせ中心）で6年進める。
  - 年末の画面は MZ_UI=yearend MZ_YEARS=6。RootView.swift:92-96 で同じく debugAdvanceYears(6) は走るが、その後 RootView.swift:124-130 が `session.debugPlayToEnd()`（GameSession.swift:1652、バイトと完全休養を交互・大会は夜行バス）で7年目を最後まで進める。MZ_CARE は debugPlayToEnd に効かない。
  - つまり7年目の自由週の台本が違う（care あり／なし）ため、第40週から先で同じ状態にならず、年末の知名度が別の値になる。第40週時点で既に別走行になっている。
  - 補足: 6年目までは同じ台本だが、MZ_UI 指定時はセーブを読まず固定シード（RootView.swift:16-19）なので、6年目終了時点は一致するはず。

## 直し方の案（任意・コードは未変更）
1. 目視の運用で解決: 年末の同一走行を見たい時は MZ_STOPWEEK=48 のような「第48週で止める」か、debugPlayToEnd を debugAdvanceYears と同じ台本にする。
2. debugPlayToEnd の自由週を debugFreeWeek(care:) に寄せる（MZ_CARE を尊重）。ただし debugPlayToEnd は他のスモーク（soak など）でも使うので、`MZ_UI=yearend` 経路だけ `debugAdvanceYears` 側に MZ_STOPWEEK 相当の「年末まで」を足す方が安全。
3. playtest の表に台本差を明記し、第40週と年末の数字を比較しない。
