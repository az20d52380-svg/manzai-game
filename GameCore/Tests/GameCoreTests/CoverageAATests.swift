// CoverageAATests.swift
// 10/25 自走の点検：llvm-cov で通っていなかった分岐の固定（紙講評の2分岐・チケット買い取りの所持金ゲート・
// 空白だけのネタ名・誘いの空回答・見積もりの0以下）。Sources は不変。

import XCTest
@testable import GameCore

final class CoverageAATests: XCTestCase {
    let cfg = GameConfig()

    /// pool のどれかを fill した文と一致するか
    private func isFromPool(_ text: String, _ pool: [String], scene: JudgeTalk.Scene, salt: Int) -> Bool {
        pool.contains { JudgeTalk.fill($0, scene: scene, salt: salt) == text }
    }

    // MARK: 予選の紙講評

    func testPaperReviewPassMentalLowWhenChemistryAndStaminaAreOrdinary() {
        // 相性<18・体力>=30 の時、メンタル<20 の通過は passMentalLow から
        let scene = JudgeTalk.Scene(compat: 10, stamina: 60, mental: 19)
        for salt in 0..<30 {
            let r = JudgeTalk.paperReview(passed: true, scene: scene, salt: salt)
            XCTAssertTrue(isFromPool(r.text, JudgeTalk.Paper.passMentalLow, scene: scene, salt: salt), "salt \(salt)")
        }
        // メンタル20ちょうどは通常の通過（passMentalLow ではない）
        let ok = JudgeTalk.Scene(compat: 10, stamina: 60, mental: 20)
        XCTAssertFalse(isFromPool(JudgeTalk.paperReview(passed: true, scene: ok, salt: 0).text,
                                  JudgeTalk.Paper.passMentalLow, scene: ok, salt: 0))
    }

    func testPaperReviewFailChemistryLowWhenStaminaAndMentalAreOrdinary() {
        // 体力>=30・メンタル>=20 の時、相性<8 の敗退は failChemistryLow から（点差の帯より先）
        let scene = JudgeTalk.Scene(margin: -1, compat: 7.9, stamina: 60, mental: 50)
        for salt in 0..<30 {
            let r = JudgeTalk.paperReview(passed: false, scene: scene, salt: salt)
            XCTAssertTrue(isFromPool(r.text, JudgeTalk.Paper.failChemistryLow, scene: scene, salt: salt), "salt \(salt)")
        }
        // 相性8ちょうど・点差-1 は惜敗の帯
        let near = JudgeTalk.Scene(margin: -1, compat: 8, stamina: 60, mental: 50)
        XCTAssertTrue(isFromPool(JudgeTalk.paperReview(passed: false, scene: near, salt: 0).text,
                                 JudgeTalk.Paper.failNear, scene: near, salt: 0))
    }

    // MARK: 場面の組み立て

    func testSceneFromBlankNetaNameIsNil() {
        var neta = Neta(id: 1, name: "  \n ", kata: .王道しゃべくり, lengthFit: [.中尺], bornYear: 1)
        let s = GameState(config: cfg)
        XCTAssertNil(JudgeTalk.Scene.from(state: s, neta: neta, config: cfg, year: 1).netaName)
        neta.name = " 回転寿司 "
        XCTAssertEqual(JudgeTalk.Scene.from(state: s, neta: neta, config: cfg, year: 1).netaName, "回転寿司")
        XCTAssertNil(JudgeTalk.Scene.from(state: s, neta: nil, config: cfg, year: 1).netaName)
    }

    // MARK: 0049 ライブのチケット

    func testOfficeTicketQuotaBuyOutGatedAt6000() {
        let cs = ChoiceEventTable.choices(for: .officeTicketQuota, config: cfg)
        XCTAssertEqual(cs.map(\.id), ["A", "B"])
        var s = GameState(config: cfg)
        s.money = 5999
        XCTAssertTrue(cs[0].gate(s), "手売りはいつでも選べる")
        XCTAssertFalse(cs[1].gate(s), "買い取りは 6000 未満で灰色")
        s.money = 6000
        XCTAssertTrue(cs[1].gate(s))
    }

    // MARK: 誘いの空回答

    func testResolveInviteWithoutPendingInviteIsNoOp() {
        let s = GameState(config: cfg)
        var r = WeekRunner(state: s, year: 1, config: cfg, rng: FixedRandom(value: 0.5))
        XCTAssertNil(r.pendingInvite)
        let before = r.state
        r.resolveInvite(accept: true)
        XCTAssertEqual(r.state.money, before.money)
        XCTAssertEqual(r.state.stamina, before.stamina)
        XCTAssertEqual(r.state.メンタル, before.メンタル)
    }

    // MARK: 見積もり

    func testProjectedGainIsZeroForNonPositiveAmount() {
        let s = GameState(config: cfg)
        for a in Ability.allCases {
            XCTAssertEqual(GameEngine.projectedGain(a, amount: 0, state: s, config: cfg), 0)
            XCTAssertEqual(GameEngine.projectedGain(a, amount: -3, state: s, config: cfg), 0)
        }
    }
}
