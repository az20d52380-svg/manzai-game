// アプリ側の穴埋めテスト その6（GP決勝の優勝→勝ち版演出→年末・敗者復活の通過/落選・予選落ち年の客席決勝・現在の挙動を固定）
import XCTest
import GameCore
@testable import ManzaiGame

final class SessionGap1025fTests: IsolatedStoreTestCase {
    private enum Plan { case champion, revivalPass, revivalFail, qualifierFail }

    /// ラインを極端にして、開始状態から数手で目的の場面を作る（能力は最大・乱数は固定シード）
    private func make(_ plan: Plan) -> GameSession {
        var cfg = GameConfig()
        switch plan {
        case .champion:      cfg.calendar.gpRounds = cfg.calendar.gpRounds.map { ($0.week, 0) }; cfg.calendar.gpFinalLine = 0
        case .revivalPass:   cfg.calendar.gpRounds = cfg.calendar.gpRounds.enumerated().map { ($1.week, $0 == 4 ? 9999 : 0) }
                             cfg.calendar.gpRevivalLine = 0; cfg.calendar.gpFinalLine = 0
        case .revivalFail:   cfg.calendar.gpRounds = cfg.calendar.gpRounds.enumerated().map { ($1.week, $0 == 4 ? 9999 : 0) }
                             cfg.calendar.gpRevivalLine = 9999
        case .qualifierFail: cfg.calendar.gpRounds = cfg.calendar.gpRounds.map { ($0.week, 9999) }
        }
        let st = GameSession.debugMaxedState(config: cfg)
        return GameSession(config: cfg, startState: st)
    }
    /// 条件が立つまで決まった台本で進める（自由週はバイトで破産回避）
    private func drive(_ s: GameSession, maxSteps: Int = 600, until stop: (GameSession) -> Bool) {
        var steps = 0
        while !stop(s), !s.finished, steps < maxSteps {
            steps += 1
            if s.watchingFinal { return }
            if s.pendingChoiceEvent != nil { s.dismissChoiceEvent(); continue }
            if s.pendingResult != nil { s.acknowledgeResult(); continue }
            switch s.phase {
            case .tournamentDecision: s.decideTournament(.夜行バス)
            case .freeAction:         s.choose(.job(.標準))
            case .gpRound, .gpRevival, .gpFinal: s.advanceAuto()
            default: return
            }
        }
    }
    private func isRevival(_ s: GameSession) -> Bool { if case .gpRevival = s.phase { return true }; return false }
    private func isFinal(_ s: GameSession) -> Bool { if case .gpFinal = s.phase { return true }; return false }

    // MARK: 優勝

    func testChampionStopsAtWinFinaleBeforeYearEnd() {
        let s = make(.champion)
        drive(s) { $0.winFinale }
        XCTAssertTrue(s.winFinale, "決勝優勝は勝ち版演出で一度止まる")
        XCTAssertFalse(s.finished, "演出の間はまだ年末ではない")
        XCTAssertTrue(s.outcome?.champion == true)
        XCTAssertGreaterThanOrEqual(s.totalPrize, GameConfig().calendar.gpPrize, "優勝賞金が年計に足される（回戦の賞金も含む）")
        XCTAssertTrue(s.log.contains { $0.contains("頂GP 決勝 優勝 +") }, "出来事に優勝の行が足される")
        XCTAssertEqual(s.week, GameConfig().calendar.gpFinalWeek)
    }
    func testChampionYearRecordIsWrittenOnceWithPrize() {
        let s = make(.champion)
        drive(s) { $0.winFinale }
        XCTAssertEqual(s.yearHistory.count, 1)
        let r = s.yearHistory[0]
        XCTAssertTrue(r.champion); XCTAssertTrue(r.reachedFinal); XCTAssertFalse(r.bankrupt)
        XCTAssertEqual(r.roundsPassed, 5)
        XCTAssertEqual(r.prize, s.totalPrize, "優勝年の賞金は戦績の行にも載る")
        XCTAssertEqual(s.bestRunLine?.contains("優勝"), true)
    }
    func testAcknowledgeWinFinishesCareerAndClearsSave() {
        let s = make(.champion)
        drive(s) { $0.winFinale }
        let key = "manzai.save.v1"
        XCTAssertNotNil(GameSession.store.data(forKey: key), "勝利演出中も保存される（A-3）")
        s.acknowledgeWin()
        XCTAssertFalse(s.winFinale)
        XCTAssertTrue(s.finished)
        XCTAssertTrue(s.careerOver, "優勝＝勇退でキャリアが区切れる")
        XCTAssertNil(GameSession.store.data(forKey: key), "優勝後はセーブが消える")
        XCTAssertEqual(s.yearHistory.count, 1, "二重に積まれない")
    }

    // MARK: 敗者復活

    func testSemifinalLossGoesToRevivalStageAtFinalWeek() {
        let s = make(.revivalPass)
        drive(s) { self.isRevival($0) }
        XCTAssertTrue(isRevival(s), "準決勝敗退は決勝週に敗者復活の段へ")
        XCTAssertEqual(s.week, GameConfig().calendar.gpFinalWeek)
        XCTAssertFalse(s.finished)
        XCTAssertTrue(s.log.contains { $0.contains("準決勝") }, "準決勝の行が残る")
    }
    func testRevivalPassLeadsToFinalStage() {
        let s = make(.revivalPass)
        drive(s) { self.isRevival($0) }
        s.advanceAuto()
        drive(s) { self.isFinal($0) || $0.winFinale }
        XCTAssertTrue(isFinal(s) || s.winFinale, "復活を通れば決勝の段へ進む")
        XCTAssertFalse(s.finished)
    }
    func testRevivalPassThenFinalWinIsChampionWithFinalistRecord() {
        let s = make(.revivalPass)
        drive(s) { $0.winFinale }
        XCTAssertTrue(s.winFinale)
        let r = s.yearHistory.last
        XCTAssertEqual(r?.champion, true)
        XCTAssertEqual(r?.roundsPassed, 4, "準決勝で落ちて復活経由＝通過した回戦は4")
        XCTAssertEqual(r?.reachedFinal, true)
    }
    func testRevivalFailEndsYearWithoutFinal() {
        let s = make(.revivalFail)
        drive(s) { self.isRevival($0) }
        s.advanceAuto()
        drive(s) { $0.finished || $0.watchingFinal }
        XCTAssertFalse(s.winFinale)
        let o = s.outcome
        XCTAssertEqual(o?.champion, false)
        XCTAssertEqual(o?.reachedFinal, false, "復活で落ちたら決勝には立たない")
        XCTAssertEqual(o?.roundsPassed, 4)
        if s.watchingFinal { XCTFail("復活に出た年は客席決勝にならない（現在の挙動の確認）") }
        XCTAssertEqual(s.yearHistory.last?.reachedFinal, false)
    }

    // MARK: 予選落ち→客席から観る

    func testQualifierFailWatchesFinalFromAudience() {
        let s = make(.qualifierFail)
        drive(s) { $0.watchingFinal }
        XCTAssertTrue(s.watchingFinal, "決勝週に自由週を迎えたら客席版決勝")
        XCTAssertFalse(s.finished)
        XCTAssertEqual(s.week, GameConfig().calendar.gpFinalWeek)
        s.finishWatchingFinal(winner: "テストコンビ")
        XCTAssertFalse(s.watchingFinal)
        XCTAssertTrue(s.log.contains { $0.contains("優勝「テストコンビ」（客席から）") })
        XCTAssertNotNil(GameSession.store.data(forKey: "manzai.save.v1"), "観終えたらセーブ")
    }
    func testWatchedFinalIsMarkedInYearRecordAndNotRewatched() {
        let s = make(.qualifierFail)
        drive(s) { $0.watchingFinal }
        s.finishWatchingFinal(winner: "A")
        drive(s) { $0.finished }
        XCTAssertFalse(s.watchingFinal, "同じ年に二度観せない")
        XCTAssertTrue(s.finished)
        XCTAssertEqual(s.yearHistory.last?.watchedFinal, true)
        XCTAssertEqual(s.yearHistory.last?.champion, false)
        XCTAssertEqual(s.yearHistory.last?.roundsPassed, 0)
    }
}
