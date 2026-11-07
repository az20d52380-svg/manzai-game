// 境界値の追加（1107）。既存カバレッジはほぼ100%のため、年またぎ・範囲外・空の意味のある境界だけ。
import XCTest
@testable import GameCore

final class Boundary1107Tests: XCTestCase {
    // gpLateStartYear=11: 10年目までは0、11年目からラインに上乗せ（境界は11）
    func testGpLateBonusBoundary() {
        let cal = GameConfig().calendar
        XCTAssertEqual(cal.gpLateBonus(year: cal.gpLateStartYear - 1), 0)
        XCTAssertEqual(cal.gpLateBonus(year: cal.gpLateStartYear), cal.gpLateLineBonus)
        XCTAssertEqual(cal.gpLateBonus(year: 99), cal.gpLateLineBonus)   // 上限なし
    }

    // 週0・年の最終週+1 は大会なし（範囲外でも落ちず nil）
    func testTournamentOutsideYearIsNil() {
        let c = GameConfig()
        XCTAssertNil(c.calendar.tournament(inWeek: 0))
        XCTAssertNil(c.calendar.tournament(inWeek: c.weeks + 1))
        XCTAssertNil(c.calendar.tournament(inWeek: -1, state: GameState(config: c, femaleCombo: true)))
    }

    // THE HANA は女性コンビだけ。通常大会の週は femaleCombo に関わらず通常大会が優先
    func testHanaOnlyForFemaleCombo() {
        let c = GameConfig()
        let cal = c.calendar
        let male = GameState(config: c, femaleCombo: false)
        let female = GameState(config: c, femaleCombo: true)
        for h in cal.hanaTournaments {
            XCTAssertNil(cal.tournament(inWeek: h.week, state: male))
            XCTAssertNotNil(cal.tournament(inWeek: h.week, state: female))
        }
        for t in cal.tournaments {
            XCTAssertEqual(cal.tournament(inWeek: t.week, state: female)?.week, t.week)
        }
    }

    // 通貨が空なら pourStep は何も動かさず0（浮動小数の塵で空費しない）
    func testPourStepWithEmptyCurrenciesDoesNothing() {
        let c = GameConfig()
        var s = GameState(config: c)
        for cur in ExpCurrency.allCases { s[currency: cur] = 0 }
        let before = Ability.allCases.map { s[$0] }
        for a in Ability.allCases { XCTAssertEqual(GameEngine.pourStep(a, to: &s, config: c), 0) }
        XCTAssertEqual(Ability.allCases.map { s[$0] }, before)
        for cur in ExpCurrency.allCases { XCTAssertEqual(s[currency: cur], 0) }
    }
}
