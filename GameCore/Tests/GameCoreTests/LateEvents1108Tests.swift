import XCTest
@testable import GameCore

/// 終盤イベント40本（E1〜E20＝6年目以降／N1〜N20＝11年目以降）。late_events_cand_1108
final class LateEvents1108Tests: XCTestCase {
    private var late: [ChoiceEventKind] { ChoiceEventKind.allCases.filter(\.isLateEvent) }

    func testFortyLateEventsAreWeeklyTwoChoice() {
        XCTAssertEqual(late.count, 40)
        let config = GameConfig()
        for k in late {
            XCTAssertTrue(k.isWeeklyRandom, "\(k) は週次抽選プール")
            XCTAssertEqual(ChoiceEventTable.choices(for: k, config: config).map(\.id), ["A", "B"], "\(k) は二択")
        }
    }

    func testYearBoundaryE_year5_no_year6_yes() {
        let config = GameConfig(); let s = GameState(config: config)
        XCTAssertFalse(ChoiceEventTable.weeklyFireable(.lateE01, state: s, week: 20, config: config, year: 5))
        XCTAssertTrue(ChoiceEventTable.weeklyFireable(.lateE01, state: s, week: 20, config: config, year: 6))
        // 既定の year（1）では出ない＝従来の呼び方で終盤イベントが混ざらない
        XCTAssertFalse(ChoiceEventTable.weeklyFireable(.lateE01, state: s, week: 20, config: config))
    }

    func testYearBoundaryN_year10_no_year11_yes() {
        let config = GameConfig(); let s = GameState(config: config)
        XCTAssertFalse(ChoiceEventTable.weeklyFireable(.lateN01, state: s, week: 20, config: config, year: 10))
        XCTAssertTrue(ChoiceEventTable.weeklyFireable(.lateN01, state: s, week: 20, config: config, year: 11))
    }

    func testNeedsChampionOnlyN17toN20() {
        let need = late.filter(\.lateEventNeedsChampion)
        XCTAssertEqual(Set(need), [.lateN17, .lateN18, .lateN19, .lateN20])
    }

    func testMoneyCostChoiceGatedByMoney() {
        let config = GameConfig(); var s = GameState(config: config)
        // E5 A は所持金−8,000（足りなければ灰色）
        let a = ChoiceEventTable.choices(for: .lateE05, config: config)[0]
        s.money = 7_999; XCTAssertFalse(a.gate(s))
        s.money = 8_000; XCTAssertTrue(a.gate(s))
        // お金が足りなくても B が選べるなら発火する（どちらも選べない時は出さない）
        s.money = 0
        XCTAssertTrue(ChoiceEventTable.weeklyFireable(.lateE05, state: s, week: 20, config: config, year: 6))
    }

    func testEffectsAreDeterministicAndWithinRange() {
        let config = GameConfig()
        for k in late {
            for c in ChoiceEventTable.choices(for: k, config: config) {
                var s = GameState(config: config); s.money = 1_000_000
                let before = s
                for e in c.effects { s.applyEventEffect(e, config: config) }
                XCTAssertLessThanOrEqual(abs(s.money - before.money), 15_000, "\(k)\(c.id) お金は±1.5万以内")
            }
        }
    }
}
