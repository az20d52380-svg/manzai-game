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
}
