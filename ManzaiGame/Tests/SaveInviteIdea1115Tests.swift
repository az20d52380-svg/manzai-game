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

    /// コンビ名に「谷口」「俺」を含んでも、文の中のコンビ名は差し替えない（name_substitution_audit_1115 #1）
    func testComboNameNotSubstituted() {
        let saved = (Names.me, Names.partner, Names.combo, Names.kind)
        defer { Names.set(me: saved.0, partner: saved.1, combo: saved.2); Names.setKind(saved.3) }
        Names.setKind(.maleMale)
        Names.set(me: "佐藤", partner: "田中", combo: "俺たち谷口")
        XCTAssertEqual(Names.show("俺たち谷口、拍手がまばらだった。谷口は黙っていた"), "俺たち谷口、拍手がまばらだった。田中は黙っていた")
        XCTAssertEqual(Names.show("谷口「行こう」"), "田中「行こう」")
        XCTAssertEqual(Names.show("俺"), "佐藤")
        Names.set(me: nil, partner: nil, combo: "満月ロケット")
        XCTAssertEqual(Names.show("満月ロケットの谷口"), "満月ロケットの谷口")
    }
}
