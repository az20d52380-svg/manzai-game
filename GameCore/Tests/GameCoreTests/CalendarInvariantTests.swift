// CalendarInvariantTests.swift
// 大会カレンダーの設定の整合（週が1年の範囲内・GP の回戦は週もラインも昇順・名前の数が一致・決勝が最後）を固定する。
// 式・乱数・golden・ソースは不変（設定を書き換えた時の取り違えを早く見つけるため）。

import XCTest
@testable import GameCore

final class CalendarInvariantTests: XCTestCase {
    private let cfg = GameConfig()

    func testTournamentWeeksInsideYearAndUniqueNames() {
        let t = cfg.calendar.tournaments
        XCTAssertFalse(t.isEmpty)
        for spec in t {
            XCTAssertTrue((1...cfg.weeks).contains(spec.week), spec.name)
            XCTAssertGreaterThan(spec.line, 0, spec.name)
            XCTAssertGreaterThanOrEqual(spec.prize, 0, spec.name)
        }
        XCTAssertEqual(Set(t.map(\.name)).count, t.count)
        XCTAssertEqual(t.map(\.week), t.map(\.week).sorted())
    }

    func testGPRoundsAscendAndFinalIsLast() {
        let c = cfg.calendar
        XCTAssertEqual(c.gpRounds.count, c.gpRoundNames.count)
        let weeks = c.gpRounds.map(\.week), lines = c.gpRounds.map(\.line)
        XCTAssertEqual(weeks, weeks.sorted())
        XCTAssertEqual(Set(weeks).count, weeks.count)
        XCTAssertEqual(lines, lines.sorted())
        XCTAssertLessThan(weeks.last!, c.gpFinalWeek)
        XCTAssertLessThanOrEqual(c.gpFinalWeek, cfg.weeks)
        XCTAssertLessThan(lines.last!, c.gpRevivalLine)
        XCTAssertLessThan(c.gpRevivalLine, c.gpFinalLine)
    }
}
