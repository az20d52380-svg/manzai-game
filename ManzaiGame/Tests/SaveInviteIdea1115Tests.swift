// 2026-11-15：誘いの札（weekendInvite）が出た週に閉じて再開しても「行く」の発想+0.5 が付く（save_restore_audit_1115 #1）
import XCTest
import GameCore
@testable import ManzaiGame

@MainActor
final class SaveInviteIdea1115Tests: XCTestCase {
    private func enc(_ st: GameState) -> Data { let e = JSONEncoder(); e.outputFormatting = .sortedKeys; return try! e.encode(st) }
    /// 誘いの札が出るまで休んで進める。出なければ nil
    private func sessionAtInvite(seed: UInt64) -> GameSession? {
        let s = GameSession(seed: seed)
        var steps = 0
        while !s.finished, steps < 400 {
            steps += 1
            if let kind = s.pendingChoiceEvent {
                if kind == .weekendInvite { return s }
                if let c = ChoiceEventTable.choices(for: kind, config: s.config).first(where: { $0.gate(s.state) }) { s.applyEventChoice(c.id) }
                s.dismissChoiceEvent(); continue
            }
            if s.pendingResult != nil { s.acknowledgeResult(); continue }
            switch s.phase {
            case .freeAction:          s.choose(.rest(.完全休養))
            case .tournamentDecision:  s.decideTournament(nil)
            case .gpRound, .gpRevival, .gpFinal: s.advanceAuto()
            default: return nil
            }
        }
        return nil
    }

    func testInviteIdeaSurvivesRestore() throws {
        var checked = 0
        for seed in UInt64(1)...60 {
            guard let s = sessionAtInvite(seed: seed) else { continue }
            s.saveNow()
            let data = try XCTUnwrap(GameSession.store.data(forKey: "manzai.save.v1"))
            let save = try JSONDecoder().decode(GameSession.SaveData.self, from: data)
            let r = GameSession(restoring: save)
            XCTAssertEqual(r.pendingChoiceEvent, .weekendInvite)
            s.applyEventChoice("A"); r.applyEventChoice("A")
            XCTAssertEqual(enc(r.state), enc(s.state), "seed \(seed)：再開後の「行く」の効果が閉じる前と違う")
            checked += 1
            if checked >= 4 { break }
        }
        XCTAssertGreaterThan(checked, 0, "誘いの札が1度も出なかった（休むだけでは届かない）")
    }

    /// 休むだけの方針で1手進める（札は最初の選べる案）。進めない時は false
    private func policyStep(_ s: GameSession) -> Bool {
        if let kind = s.pendingChoiceEvent {
            if let c = ChoiceEventTable.choices(for: kind, config: s.config).first(where: { $0.gate(s.state) }) { s.applyEventChoice(c.id) }
            s.dismissChoiceEvent(); return true
        }
        if s.pendingResult != nil { s.acknowledgeResult(); return true }
        switch s.phase {
        case .freeAction:          s.choose(.rest(.完全休養))
        case .tournamentDecision:  s.decideTournament(.新幹線)   // 大会に出る＝結果の週・出場判断の週で待ちが残る
        case .gpRound, .gpRevival, .gpFinal: s.advanceAuto()
        default: return false
        }
        return true
    }

    /// 週末に決まった誘い（次の空いた週の頭で札）が、待ちの間に閉じて再開しても消えない（code_review_1116_night #4）
    func testWaitingInviteSurvivesRestore() throws {
        var checked = 0
        seeds: for seed in UInt64(1)...80 {
            let s = GameSession(seed: seed)
            for _ in 0..<400 where !s.finished {
                s.saveNow()
                let data = try XCTUnwrap(GameSession.store.data(forKey: "manzai.save.v1"))
                let save = try JSONDecoder().decode(GameSession.SaveData.self, from: data)
                if save.inviteWaiting == true {
                    let r = GameSession(restoring: save)
                    var sawInvite = false
                    for k in 0..<40 {
                        XCTAssertEqual(r.pendingChoiceEvent, s.pendingChoiceEvent, "seed \(seed)：再開後 \(k) 手目の札が違う")
                        if s.pendingChoiceEvent == .weekendInvite { sawInvite = true; break }
                        guard policyStep(s), policyStep(r) else { break }
                    }
                    XCTAssertTrue(sawInvite, "seed \(seed)：待ちの誘いが40手以内に出なかった")
                    checked += 1
                    if checked >= 3 { break seeds }
                    continue seeds
                }
                guard policyStep(s) else { continue seeds }
            }
        }
        XCTAssertGreaterThan(checked, 0, "誘いの待ちが1度も保存されなかった")
    }

    /// 年初の知らせを出した年が中断→再開で残る（save_restore_audit_1115 #2）
    func testYearNoticeMarkersSurviveRestore() throws {
        let s = GameSession(seed: 3)
        XCTAssertEqual(s.youthNoticeYear, 0); XCTAssertEqual(s.tiredNoticeYear, 0)
        s.markYouthNotice(); s.markTiredNotice()
        let data = try XCTUnwrap(GameSession.store.data(forKey: "manzai.save.v1"))
        let r = GameSession(restoring: try JSONDecoder().decode(GameSession.SaveData.self, from: data))
        XCTAssertEqual(r.youthNoticeYear, s.year); XCTAssertEqual(r.tiredNoticeYear, s.year)
    }

    /// 空の結果がセーブから来ても結果画面に渡さない（crash_audit_1115 #1＝results.last! で落ちる）
    func testEmptyPendingResultDroppedOnRestore() throws {
        let s = GameSession(seed: 2)
        s.saveNow()
        let data = try XCTUnwrap(GameSession.store.data(forKey: "manzai.save.v1"))
        var save = try JSONDecoder().decode(GameSession.SaveData.self, from: data)
        save.pendingResult = WeekSummary(year: 1, week: 1, results: [], state: s.state)
        XCTAssertNil(GameSession(restoring: save).pendingResult)
    }

    /// 結果を見せる段（weekDone）で結果が空のセーブ＝読み込み中で止まらず次の段へ進む（softlock_audit_1115 #3）
    func testWeekDoneWithEmptyResultAdvancesOnRestore() throws {
        let s = GameSession(seed: 2)
        s.debugAdvanceToFirstResult()
        guard case .weekDone = s.phase, s.pendingResult != nil else { throw XCTSkip("結果の段に届かなかった") }
        s.saveNow()
        let data = try XCTUnwrap(GameSession.store.data(forKey: "manzai.save.v1"))
        var save = try JSONDecoder().decode(GameSession.SaveData.self, from: data)
        save.pendingResult = WeekSummary(year: save.pendingResult!.year, week: save.pendingResult!.week, results: [], state: s.state)
        let r = GameSession(restoring: save)
        XCTAssertNil(r.pendingResult)
        if case .weekDone = r.phase { XCTFail("weekDone のまま＝画面が出ない") }
    }

    /// 誘いの待ちは年をまたがない（WeekRunner が新年に pendingInvite を落とすのと揃える・review_fixes_1116 低-1）
    /// 年末のセーブに待ちを立てて再開→次の年へ進めると、待ちは消えて札も出ない。
    func testWaitingInviteDroppedAtNewYear() throws {
        let s = GameSession(seed: 7)
        for _ in 0..<800 where !s.finished && !s.winFinale {   // debugAdvanceYears と同じ進め方（決勝の観戦も閉じる）
            if s.watchingFinal { s.finishWatchingFinal(winner: "—"); continue }
            if case .freeAction = s.phase, s.pendingChoiceEvent == nil, s.pendingResult == nil, s.state.money < 250_000 { s.choose(.job(.標準)); continue }   // 休むだけだと夜逃げで年末に届かない
            guard policyStep(s) else { break }
        }
        try XCTSkipUnless(s.finished && !s.careerOver, "年末まで届かなかった")
        s.saveNow()
        var save = try JSONDecoder().decode(GameSession.SaveData.self, from: try XCTUnwrap(GameSession.store.data(forKey: "manzai.save.v1")))
        save.inviteWaiting = true
        let r = GameSession(restoring: save)
        XCTAssertTrue(r.finished)
        r.startNextYear()
        XCTAssertFalse(r.finished, "次の年へ進まなかった")
        r.saveNow()
        let after = try JSONDecoder().decode(GameSession.SaveData.self, from: try XCTUnwrap(GameSession.store.data(forKey: "manzai.save.v1")))
        XCTAssertNil(after.inviteWaiting, "新しい年に誘いの待ちが残った")
        XCTAssertNotEqual(r.pendingChoiceEvent, .weekendInvite, "新しい年の頭に前の年の誘いが出た")
    }
}
