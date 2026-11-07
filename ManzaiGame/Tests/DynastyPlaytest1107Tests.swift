import XCTest
import GameCore
@testable import ManzaiGame

/// 実プレイ点検（優勝後も続けるキャリアを最終年まで通す）。docs/playtest_dynasty_1107.md
final class DynastyPlaytest1107Tests: IsolatedStoreTestCase {
    struct Snap: Equatable { let year: Int; let hist: [GameSession.YearRecord]; let money: Int; let prize: Int; let fin: Bool; let win: Bool }
    private func snap(_ s: GameSession) -> Snap { Snap(year: s.year, hist: s.yearHistory, money: Int(s.state.money), prize: s.totalPrize, fin: s.finished, win: s.winFinale) }

    /// 優勝しても勇退せず続ける自動プレイ。区切り（careerOver）まで。各年末で保存→復元の一致も見る。
    private func playOn(_ s: GameSession, checkRestore: Bool = true) -> String? {
        var steps = 0
        while steps < 60000 {
            steps += 1
            if s.winFinale {
                if checkRestore, let r = Optional(GameSession.loadedOrNew()), s.year > 1 || true { XCTAssertEqual(snap(r), snap(s), "win-finale restore y\(s.year)") }
                s.acknowledgeWin(); continue
            }
            if s.finished {
                if s.careerOver { return nil }
                if checkRestore { let r = GameSession.loadedOrNew(); XCTAssertEqual(snap(r), snap(s), "year-end restore y\(s.year)") }
                s.startNextYear()
                if checkRestore { let r = GameSession.loadedOrNew(); XCTAssertEqual(r.year, s.year); XCTAssertEqual(r.yearHistory, s.yearHistory) }
                continue
            }
            if s.watchingFinal { s.finishWatchingFinal(winner: "—"); continue }
            if let _ = s.pendingChoiceEvent {
                let cs = s.availableEventChoices()
                if !cs.isEmpty { s.applyEventChoice(cs[0].id) }
                s.dismissChoiceEvent(); continue
            }
            if s.pendingResult != nil { s.acknowledgeResult(); continue }
            switch s.phase {
            case .tournamentDecision: s.decideTournament(.新幹線)
            case .freeAction:
                if s.state.stamina < 25 { s.choose(.rest(.完全休養)) }
                else if s.state.money < 250_000 { s.choose(.job(.標準)) }
                else if s.state.stamina >= 45 { s.choose(.train(.ネタ作り)) }
                else { s.choose(.rest(.完全休養)) }
            case .gpRound, .gpRevival, .gpFinal: s.advanceAuto()
            default: return "STUCK \(s.phase) y=\(s.year) w=\(s.week)"
            }
        }
        return "STUCK steps y=\(s.year)"
    }

    private func check(_ s: GameSession, _ label: String) {
        let h = s.yearHistory
        XCTAssertEqual(h.map(\.year), Array(1...max(h.count, 1)).prefix(h.count).map { $0 }, "\(label) 年表の年が連番でない")
        XCTAssertEqual(h.count, s.year, "\(label) 年表の行数と年が合わない")
        XCTAssertLessThanOrEqual(s.year, s.config.careerYears, "\(label) 年が上限超え")
        XCTAssertEqual(h.last?.champion, s.outcome?.champion, "\(label) 最終年の優勝が結果と食い違う")
        for r in h { XCTAssertGreaterThanOrEqual(r.prize, 0); XCTAssertLessThan(r.prize, 1_000_000_000) }
        XCTAssertLessThan(abs(s.state.money), 10_000_000_000, "\(label) お金が桁あふれ気味")
        // 優勝の年だけ賞金に頂GPの賞金が入る
        for r in h where r.champion { XCTAssertGreaterThanOrEqual(r.prize, s.config.calendar.gpPrize, "\(label) 優勝年の賞金が頂GP未満 y\(r.year)") }
        // 連覇の数え方
        var streak = 0; for r in h.reversed() { if r.champion { streak += 1 } else { break } }
        if streak >= 2 { XCTAssertEqual(s.winHeadline, "\(streak)連覇") }
    }

    func testContinueAfterWinTo15Years() {
        var champYears: [[Int]] = []
        for seed in [1, 2, 3, 4, 5, 6] {
            GameSession.store.removeObject(forKey: "manzai.save.v1")
            let s = GameSession(startState: GameSession.debugMaxedState())
            var st = s.state; st.money = 500_000; _ = st
            let r = playOn(s)
            XCTAssertNil(r, "seed \(seed) \(r ?? "")")
            check(s, "seed\(seed)")
            champYears.append(s.yearHistory.filter(\.champion).map(\.year))
            dynLog(" seed=\(seed) y=\(s.year) careerYears=\(s.config.careerYears) champ=\(s.yearHistory.filter(\.champion).map(\.year)) bank=\(s.outcome?.bankrupt ?? false) diss=\(s.outcome?.dissolved ?? false) money=\(Int(s.state.money)) prizes=\(s.yearHistory.map(\.prize).map { $0 / 10000 })")
        }
        dynLog(" champs \(champYears)")
    }

    func testDefaultStateContinueTo15() {
        for _ in 0..<3 {
            let s = GameSession(startState: GameState(config: GameConfig()))
            let r = playOn(s)
            XCTAssertNil(r, r ?? "")
            check(s, "default")
            dynLog(" default y=\(s.year) champ=\(s.yearHistory.filter(\.champion).map(\.year)) bank=\(s.outcome?.bankrupt ?? false)")
        }
    }
}

func dynLog(_ s: String) {
    let p = "/private/tmp/claude-501/dyn1107.log"
    if let d = ("[DYN]" + s + "\n").data(using: .utf8) {
        if let h = FileHandle(forWritingAtPath: p) { h.seekToEndOfFile(); h.write(d); try? h.close() } else { FileManager.default.createFile(atPath: p, contents: d) }
    }
}
