# アプリ本体の GameSession で「週イベントあり／なし」を直接測る（2026-11-08・測るだけ）

## 要点3行
- 向きは Python と同じ：週のランダムイベントを入れると、ローテの15年内初優勝は 3.7→7.0%（n=300）、決勝に1度でも 62→78%。ただし大きさは Python（2.52→9.57%）と比べて小さめ〜同程度で、n=300 でも誤差が大きい。
- やり込み近似は本体では優勝がほぼ出ず（A 0.3%／B 0%）、Python の 5.1→17.7% は再現しなかった。決勝到達は 19→32% と上がるが、解散が約4割で効いている（イベントの有無では変わらない）。
- イベント発火は A で 約15回/周（週イベント上限15にほぼ到達）、B は 0。1周の実行時間は約1.1秒で、1分制約の問題なし。

## 結果（iPhone 17・seed 1000〜1299・n=100 で当たり→n=300 に拡大。A＝今の設定 weeklyEventCap=15／B＝0）
| ボット | 条件 | n | 15年内初優勝 | 決勝に1度でも | 解散 | 週イベント/周 | 全イベント/周 | 秒/周 |
|---|---|---|---|---|---|---|---|---|
| ローテ | A | 300 | 7.0% (21) | 78.3% | 0% | 14.9 | 50.6 | 1.06 |
| ローテ | B | 300 | 3.7% (11) | 62.0% | 0% | 0 | 36.2 | 1.04 |
| やり込み | A | 300 | 0.3% (1) | 31.7% | 39.7% | 15.0 | 49.7 | 1.22 |
| やり込み | B | 300 | 0% (0) | 19.3% | 38.0% | 0 | 34.7 | 1.05 |

内訳（n=100／n=200）：ローテ優勝 A 3/9%・B 3/4%、決勝 A 75/80%・B 59/63.5%。やり込み優勝 A 0/0.5%・B 0/0%。夜逃げ（bankrupt）は全て 0%。stuck なし。
「全イベント」には週ランダム以外の確定発火イベントも含む。B でも確定発火は残る。

## 言える事／言えない事
言える事
- 本体でも、週イベントを入れると決勝到達が上がる（ローテ +16pt、やり込み +12pt）。向きは Python と一致。
- 発火数は上限 15 にほぼ張り付く（14.8〜15.0/周）。上限が実質の量を決めている。
- ローテの初優勝は A の方が高い（7.0 vs 3.7）。ただし件数は 21 対 11 で、差の信頼幅は広い（n=100 では 3 対 3 で差が出なかった）。
言えない事
- Python の 2.52→9.57% が本体で「そのままの大きさで」起きるとは言えない（優勝は件数が少なすぎる）。
- やり込みの 5.1→17.7% は本体では再現していない。ボットの近似が弱い可能性（下記）と本体の差の両方があり、どちらかは切り分けていない。
- 解散がやり込みで約4割あるのは、ボットが本体の解散条件に弱い（相性・メンタル等を見ない）せいかもしれない。実プレイ人間の値とは言えない。

## ボットの近似の中身と限界
共通：開始は GameState(config:) 既定。毎回 allocate(recommendedAllocation()) で経験点を注ぐ（アプリは autoPour=false のため）。オファーは先頭を受ける。大会の移動は所持金15万以上で新幹線、未満で夜行バス。イベント選択肢は押せる中の先頭。優勝したら retireAfterWin で勇退。
- ローテ：ネタ作り→ネタ合わせ→フリーライブを順に。バイト標準は所持金15万未満、完全休養は体力35未満、次の本番が1週以内で体力60未満でも休養。
- やり込み（Python PNeedMax 相当）：弱い能力（メンタルが平均より25以上低ければメンタル）の不足通貨を最も多く出す稽古を選ぶ。有料稽古は所持金15万以上。貯金線6万でバイト。体力35未満／本番前75未満で温泉（60万以上）／サウナ（30万以上）／完全休養。
限界：Python の カフェ・温泉の補助（Cafe/Spa ラッパー）は入れていない。「本番が近い」は nextStage.week − week ≤ 1 の近似。周回ボーナスなし。Python の bs=0 の組を完全には再現していない。seed は A/B で揃えたが、イベントの有無で乱数の使われ方が変わるため同一の走りにはならない。測定は GameSession のみで、Python は介していない。

## 一時テスト全文（AppBandDirect1108Tests.swift・コミットしない）
```swift
import XCTest
import GameCore
@testable import ManzaiGame

/// 一時テスト（コミットしない）：アプリ本体の GameSession を15年通し、週のランダムイベント有無（weeklyEventCap 15 / 0）で
/// 初優勝・決勝・解散を比べる。docs/app_band_direct_1108_v0.md。 環境変数 MZ_N（既定100）・MZ_SEED0（既定0）
final class AppBandDirect1108Tests: IsolatedStoreTestCase {
    enum Bot { case rotate, yari }

    struct Res { var firstWin: Int? = nil; var final = false; var dissolved = false; var bankrupt = false
        var weeklyEv = 0; var allEv = 0; var secs = 0.0; var stuck: String? = nil }

    static func cur(_ s: GameState, _ c: ExpCurrency) -> Double {
        switch c { case .閃き: return s.exp閃き; case .語彙: return s.exp語彙; case .間合い: return s.exp間合い; case .存在感: return s.exp存在感; case .胆力: return s.exp胆力 }
    }

    /// やり込み近似（Python PNeedMax 相当）：弱い能力の不足通貨を最も多く出す稽古。お金に余裕があれば有料稽古・有料休み。
    static func yariAction(_ s: GameSession) -> WeekAction {
        let st = s.state, cfg = s.config
        if let ns = s.nextStage, ns.week - s.week <= 1, st.stamina < 75 {
            return .rest(st.money >= 600_000 ? .温泉に一泊 : .完全休養)
        }
        if st.money < 60_000 { return .job(.標準) }
        if st.stamina < 35 { return .rest(st.money >= 600_000 ? .温泉に一泊 : (st.money >= 300_000 ? .サウナ : .完全休養)) }
        let perf: [Ability] = [.センス, .発想, .表現, .華]
        let avg = perf.map { st[$0] }.reduce(0, +) / 4
        let target: Ability = (st[.メンタル] + 25 < avg && st[.メンタル] < cfg.mentalCap) ? .メンタル : perf.min(by: { st[$0] < st[$1] })!
        let rec = cfg.abilityRecipes[target] ?? []
        let need = rec.min(by: { cur(st, $0.0) / $0.1 < cur(st, $1.0) / $1.1 })!.0
        var best: Training? = nil, bestAmt = -1.0
        for t in Training.allCases {
            guard let sp = cfg.trainings[t] else { continue }
            if sp.cost > 0 && st.money < 150_000 { continue }
            var amt = 0.0
            if case .currency(let c) = sp.main.0, c == need { amt += sp.main.1 }
            if let sub = sp.sub, case .currency(let c) = sub.0, c == need { amt += sub.1 }
            if amt > bestAmt { best = t; bestAmt = amt }
        }
        return .train(bestAmt > 0 ? best! : .ネタ合わせ)
    }

    static func rotAction(_ s: GameSession, _ i: inout Int) -> WeekAction {
        let st = s.state
        if let ns = s.nextStage, ns.week - s.week <= 1, st.stamina < 60 { return .rest(.完全休養) }
        if st.money < 150_000 { return .job(.標準) }
        if st.stamina < 35 { return .rest(.完全休養) }
        let r: [Training] = [.ネタ作り, .ネタ合わせ, .フリーライブ]
        defer { i += 1 }
        return .train(r[i % 3])
    }

    func run(seed: UInt64, bot: Bot, cap: Int) -> Res {
        GameSession.store.removeObject(forKey: "manzai.save.v1")
        var cfg = GameConfig(); cfg.weeklyEventCap = cap
        let s = GameSession(seed: seed, config: cfg, startState: GameState(config: cfg))
        var r = Res(); var rot = 0; var steps = 0; var lastKey = ""; var same = 0
        let t0 = Date()
        while steps < 80000 {
            steps += 1
            if s.winFinale { s.acknowledgeWin(); continue }
            if s.finished {
                if s.careerOver { break }
                if s.canChooseRetire { s.retireAfterWin(); continue }
                s.startNextYear(); continue
            }
            if s.watchingFinal { s.finishWatchingFinal(winner: "—"); continue }
            if let k = s.pendingChoiceEvent {
                r.allEv += 1; if k.isWeeklyRandom { r.weeklyEv += 1 }
                let cs = s.availableEventChoices()
                if !cs.isEmpty { s.applyEventChoice(cs[0].id) }
                s.dismissChoiceEvent(); continue
            }
            if s.pendingResult != nil { s.acknowledgeResult(); continue }
            let key = "\(s.year)-\(s.week)-\(String(describing: s.phase).prefix(12))"
            if key == lastKey { same += 1 } else { same = 0; lastKey = key }
            if same > 6 { r.stuck = "STUCK \(key)"; break }
            switch s.phase {
            case .tournamentDecision:
                let p = s.allocate(s.recommendedAllocation()); _ = p
                s.decideTournament(s.state.money >= 150_000 ? .新幹線 : .夜行バス)
            case .freeAction(let offer):
                if !s.recommendedAllocation().isEmpty { s.allocate(s.recommendedAllocation()) }
                if offer != nil && same < 2 {
                    if s.offerChoices != nil { s.chooseOffer(index: 0) }
                    s.choose(.acceptOffer); continue
                }
                s.choose(bot == .yari ? Self.yariAction(s) : Self.rotAction(s, &rot))
            case .gpRound, .gpRevival, .gpFinal: s.advanceAuto()
            default: r.stuck = "STUCK phase \(s.phase)"; return r
            }
        }
        r.secs = Date().timeIntervalSince(t0)
        r.firstWin = s.yearHistory.first(where: \.champion)?.year
        r.final = s.yearHistory.contains(where: \.reachedFinal)
        r.dissolved = s.outcome?.dissolved ?? false
        r.bankrupt = s.outcome?.bankrupt ?? false
        if steps >= 80000 { r.stuck = "steps" }
        return r
    }

    private func log(_ t: String) {
        let p = "/private/tmp/claude-501/-Users-hujiko/b6d47f5e-184f-4a27-8f17-0ddf9f4956f1/scratchpad/appband1108.log"
        if let d = (t + "\n").data(using: .utf8) {
            if let h = FileHandle(forWritingAtPath: p) { h.seekToEndOfFile(); h.write(d); try? h.close() } else { FileManager.default.createFile(atPath: p, contents: d) }
        }
    }

    private func batch(_ bot: Bot, _ name: String) {
        let env = ProcessInfo.processInfo.environment
        let n = Int(env["MZ_N"] ?? "") ?? 100, s0 = Int(env["MZ_SEED0"] ?? "") ?? 0
        for (label, cap) in [("A(cap15)", 15), ("B(cap0)", 0)] {
            var rs: [Res] = []
            for i in s0..<(s0 + n) { rs.append(run(seed: UInt64(1000 + i), bot: bot, cap: cap)) }
            let c = Double(rs.count)
            func pct(_ f: (Res) -> Bool) -> Double { 100 * Double(rs.filter(f).count) / c }
            let stuck = rs.compactMap(\.stuck)
            log(String(format: "%@ %@ n=%d seeds=%d.. win15=%.1f%% final=%.1f%% dissolved=%.1f%% bankrupt=%.1f%% weeklyEv/run=%.2f allEv/run=%.2f sec/run=%.2f stuck=%d %@",
                       name, label, rs.count, s0, pct { $0.firstWin != nil }, pct { $0.final }, pct { $0.dissolved }, pct { $0.bankrupt },
                       Double(rs.map(\.weeklyEv).reduce(0, +)) / c, Double(rs.map(\.allEv).reduce(0, +)) / c, rs.map(\.secs).reduce(0, +) / c, stuck.count, stuck.first ?? ""))
        }
    }

    func testRotate() { batch(.rotate, "ローテ") }
    func testYari() { batch(.yari, "やり込み") }
}
```
