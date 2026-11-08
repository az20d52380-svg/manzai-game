import XCTest
import GameCore
@testable import ManzaiGame

/// 懸念の台帳 L52 の直し（GameSession.pump の yearDone：夜逃げ・解散で終わった週の大会の結果を出来事ログ・賞金年計に足す）。
/// 既定の数値では通らない（借金だと出場できない・生活費1回で夜逃げ線 −100万を割らない・二人で舞台に立つ週はすれ違いが増えない）
/// ＝11/09 定期のカバレッジで未通過と分かった。数値を変えた時に壊れていないよう、試験用の config で通す。
final class BankruptStageWeek1109Tests: XCTestCase {
    private var saved: UserDefaults!
    override func setUp() {
        saved = GameSession.store
        GameSession.store = UserDefaults(suiteName: "bsw1109-\(UUID().uuidString)")!
    }
    override func tearDown() { GameSession.store = saved }

    private func run(_ s: GameSession) {
        var steps = 0
        while !s.finished, !s.winFinale, !s.watchingFinal, steps < 200 {
            steps += 1
            if s.pendingChoiceEvent != nil { s.dismissChoiceEvent(); continue }
            if s.pendingResult != nil { s.acknowledgeResult(); continue }
            switch s.phase {
            case .freeAction: s.choose(.rest(.完全休養))
            case .tournamentDecision: s.decideTournament(.夜行バス)
            case .gpRound, .gpRevival, .gpFinal: s.advanceAuto()
            default: return
            }
        }
    }

    /// 夜逃げ線を 0・生活費を12週ごとにして、第12週（春新人賞A）に出た週の週末で夜逃げさせる
    func testBankruptInStageWeekKeepsTheStageInLog() {
        var cfg = GameConfig()
        cfg.bankruptLine = 0
        cfg.livingInterval = 12
        let need = cfg.calendar.entryFee + cfg.calendar.travelSpec(.夜行バス).cost
        var st = GameState(config: cfg)
        st.money = need + 10_000          // 出場は払える・生活費14万で 0 を割る（敗退なら）
        let s = GameSession(config: cfg, startState: st)
        run(s)
        XCTAssertTrue(s.finished)
        XCTAssertEqual(s.outcome?.bankrupt, true, "初期能力では春新人賞A（ライン30）は敗退＝賞金なしで夜逃げ")
        XCTAssertEqual(s.week, 12, "第12週の週末で夜逃げ")
        XCTAssertTrue(s.log.contains { $0.contains("第12週") && $0.contains("春新人賞A") }, "夜逃げした週の大会がログに残る: \(s.log)")
        XCTAssertEqual(s.log.filter { $0.contains("春新人賞A") }.count, 1, "二重に積まない")
    }
}
