// 予選の通過者一覧：GP の1〜3回戦で顔ぶれが変わる（qualifier_finals_intro_audit_1115 低-1）
import XCTest
import GameCore
@testable import ManzaiGame

final class QualifierRoster1115Tests: IsolatedStoreTestCase {
    func testRoundsGiveDifferentRosters() {
        let rounds = ["GP1回戦", "GP2回戦", "GP3回戦"]
        let seeds = rounds.map { QualifierNoticeView.rosterSeed(year: 3, roundName: $0) }
        XCTAssertEqual(Set(seeds).count, 3)
        let rosters = seeds.map { FinalsData.yearRoster(year: $0, selfName: "なんば亭", count: 8) }
        XCTAssertNotEqual(rosters[0], rosters[1])
        XCTAssertNotEqual(rosters[1], rosters[2])
    }
}
