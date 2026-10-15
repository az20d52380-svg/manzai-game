# 重さ点検 v1（2026-10-16）

注意：シミュレータ iPhone 17（Mac 上・ソフト描画）の数字は実機と違う目安。相対比較用。測り方＝`top -pid` で1秒ごと（CPU% は1コア=100%）、Debug ビルド、起動2秒後から。

| 画面（フック） | CPU 平均 | CPU 最大 | メモリ(MB) | 所見 |
|---|---|---|---|---|
| 静的画面（MZ_UI=glossary） | 0 | 0 | 23 | 基準 |
| エンディング図鑑 | 0 | 0 | 23→23 | 問題なし |
| 週メイン（MZ_SMOKE=0・放置） | 6.2 | 6.5 | 35→35 | 常時動く。やや高いが許容（下記） |
| 演出 champion | 33 | 36 | 28→29 | 高い（ループする設計）。終わらない |
| 演出 rankup | 7〜8 | 16 | 24 | 終了後に下がる範囲 |
| 演出 yearturn | 1.3 | 1.4 | 23 | 軽い |
| 演出 pass | 10 | 11 | 30 | 紙吹雪が続く |
| 演出 burst | 6 | 9 | 21 | 問題なし |
| 決勝 vtr / judges | 10 / 10 | 15 / 13 | 30→33 / 32 | 番組導入。許容 |
| 決勝 board / duel | 6 / 6.5 | 6.4 / 7.2 | 31 / 32 | 週メイン並み |
| 決勝 champ（優勝演出） | 30 | 33 | 39→38 | champion と同じ（背景3＋紙吹雪の Canvas 60fps） |
| イベント会話（MZ_UI=event 0011） | 8.4 | 8.7 | 38 | 夜の背景。許容 |

メモリ：どの画面も10〜20秒で増加なし（漏れの兆候なし）。画面往復の長時間テストは未実施。

## 試した直し（採用せず）
- champion 系 Canvas（背景・後光・紙吹雪）と WashiConfetti の TimelineView を 60fps→30fps に落とした：top の CPU が 33%→33%、pass 10→10 で変化なし（app プロセスの `sample` はほぼ待機＝負荷は描画側／シミュレータのソフトウェア Metal 側）。効果が測れないので戻した。
- 週メインの 6%：DustField（20fps）を止めても、呼吸 repeatForever を止めても 6.1 のまま＝原因はそれらではない（週メインの他の常時要素か SwiftUI の基礎負荷）。未特定。

## 次の候補（実機で見る）
- champion/優勝演出は終わりの無いループ：実機の Instruments（Time Profiler / Energy）で確認。ループ数秒後に紙吹雪を止める案（見た目が変わるので要相談）。
- 週メイン 6% の内訳は Instruments で。

## 追記：演出ループの停止（preview-all・2026-10-16）
優勝（YoseChampionCelebrationView 3つの Canvas）・予選通過/昇格の紙吹雪（YoseConfettiView）・決勝結果の背景（RaysView/ConfettiView）を、余韻6.5秒の後に止める作りへ。光・幕は6.5秒の状態で静止、紙吹雪は新しい粒を出さず残りが落ちきったら TimelineView を paused。視差軽減では最初から最小限。見た目は変化なし（feedback_shots/perf_v1/）。
実測（iPhone 17・アプリ CPU%・1秒ごと22回）：champion は 約200→17秒以降 約1%／pass は 約10%→14秒以降 約1.2%／MZ_SMOKE=4 MZ_FIN=champ は 23%→約10%（17秒以降）。
残り約10%（決勝の結果画面）は演出外のループ（吹き出しの▼点滅 repeatForever・StageScene の呼吸等）＝次の候補。
