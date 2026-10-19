// CodableLegacyTests.swift
// 旧セーブ互換：後から足した Optional 項目のキーが無い JSON でも復号でき、nil のまま読めること。

import XCTest
@testable import GameCore

final class CodableLegacyTests: XCTestCase {

    private func dict(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// Neta：lastUsedTaikaiYear・tiredYears が無い旧 JSON を読め、両方 nil になる
    func testNetaLegacyJSONWithoutOptionalKeys() throws {
        var n = Neta(id: 3, name: "終電の二人", kata: .関係性, lengthFit: [.短尺, .長尺], bornYear: 2)
        n.lastUsedTaikaiYear = 4
        n.tiredYears = 2
        var d = try dict(JSONEncoder().encode(n))
        XCTAssertNotNil(d["lastUsedTaikaiYear"])
        d.removeValue(forKey: "lastUsedTaikaiYear")
        d.removeValue(forKey: "tiredYears")
        let old = try JSONSerialization.data(withJSONObject: d)
        let back = try JSONDecoder().decode(Neta.self, from: old)
        XCTAssertNil(back.lastUsedTaikaiYear)
        XCTAssertNil(back.tiredYears)
        XCTAssertEqual(back.id, 3)
        XCTAssertEqual(back.lengthFit, [.短尺, .長尺])
    }

    /// GameState：Optional 項目（rift 系・skills・offerWeeks 等）が全部無い JSON を読め、nil になる
    func testGameStateLegacyJSONWithoutOptionalKeys() throws {
        var s = GameState(config: GameConfig())
        s.rift = 12; s.riftWarned = true; s.riftWeekStartCompat = 30
        s.riftJointWeek = true; s.dissolved = false
        s.skills = []; s.offerWeeks = [5]; s.growthBudget = 6
        s.selectedNetaID = 1; s.selectedNetaID2 = 2
        var d = try dict(JSONEncoder().encode(s))
        let optionalKeys = ["rift", "riftWarned", "riftWeekStartCompat", "riftJointWeek",
                            "dissolved", "skills", "offerWeeks", "growthBudget",
                            "selectedNetaID", "selectedNetaID2"]
        for k in optionalKeys {
            XCTAssertNotNil(d[k], "\(k) が符号化されていない")
            d.removeValue(forKey: k)
        }
        let old = try JSONSerialization.data(withJSONObject: d)
        let back = try JSONDecoder().decode(GameState.self, from: old)
        XCTAssertNil(back.rift)
        XCTAssertNil(back.riftWarned)
        XCTAssertNil(back.riftWeekStartCompat)
        XCTAssertNil(back.riftJointWeek)
        XCTAssertNil(back.dissolved)
        XCTAssertNil(back.skills)
        XCTAssertNil(back.offerWeeks)
        XCTAssertNil(back.growthBudget)
        XCTAssertNil(back.selectedNetaID)
        XCTAssertNil(back.selectedNetaID2)
        XCTAssertEqual(back.money, s.money)
    }

    /// 新規 GameState は Optional 項目を符号化しない（nil はキーごと出ない＝旧形式と同じ形）
    func testFreshGameStateOmitsNilOptionalKeys() throws {
        let d = try dict(JSONEncoder().encode(GameState(config: GameConfig())))
        for k in ["rift", "dissolved", "skills", "offerWeeks", "selectedNetaID"] {
            XCTAssertNil(d[k], "\(k) が nil なのにキーが出ている")
        }
    }
}
