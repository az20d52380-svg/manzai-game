// CareerSkillGapTests.swift
// 未カバーだった所の点検（式・golden は触らない）：YearOutcome の古いセーブの読み込み／特技の説明文。
import XCTest
@testable import GameCore

final class CareerSkillGapTests: XCTestCase {
    /// 古いセーブ（bankrupt・dissolved のキーが無い）も読める＝どちらも false
    func testYearOutcomeDecodesOldSaveWithoutNewKeys() throws {
        let json = #"{"champion":false,"roundsPassed":3,"reachedFinal":false}"#.data(using: .utf8)!
        let o = try JSONDecoder().decode(YearOutcome.self, from: json)
        XCTAssertFalse(o.champion)
        XCTAssertEqual(o.roundsPassed, 3)
        XCTAssertFalse(o.reachedFinal)
        XCTAssertFalse(o.bankrupt)
        XCTAssertFalse(o.dissolved)
    }

    /// 書いて読み戻すと全項目が一致する
    func testYearOutcomeRoundTrip() throws {
        let src = YearOutcome(champion: true, roundsPassed: 5, reachedFinal: true, bankrupt: false, dissolved: true)
        let o = try JSONDecoder().decode(YearOutcome.self, from: JSONEncoder().encode(src))
        XCTAssertEqual([o.champion, o.reachedFinal, o.bankrupt, o.dissolved], [true, true, false, true])
        XCTAssertEqual(o.roundsPassed, 5)
    }

    /// 特技の説明は全件あり・重複なし・％を出さない（no-win-percentage の方針）
    func testSkillSummaryPresentUniqueNoPercent() {
        let s = Skill.allCases.map(\.summary)
        XCTAssertTrue(s.allSatisfy { !$0.isEmpty })
        XCTAssertEqual(Set(s).count, s.count)
        XCTAssertTrue(s.allSatisfy { !$0.contains("%") && !$0.contains("％") })
    }
}
