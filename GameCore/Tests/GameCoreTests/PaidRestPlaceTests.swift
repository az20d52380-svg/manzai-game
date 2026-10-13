// PaidRestPlaceTests.swift
// お金を払う休み（サウナ・温泉に一泊）と練習の場所（喫茶店・ファミレスで書く）の単体テスト（money_items_neta_v1 §1・§2）

import XCTest
@testable import GameCore

final class PaidRestPlaceTests: XCTestCase {

    // MARK: お金を払う休み

    func testPaidRestDeductsCostAndRecovers() {
        let config = GameConfig()
        var s = GameState(config: config)
        s.money = 100_000; s.stamina = 10
        let mental = s.メンタル
        GameEngine.applyRest(.サウナ, to: &s, config: config)
        XCTAssertEqual(s.money, 100_000 - config.restCosts[.サウナ]!)
        XCTAssertEqual(s.stamina, 10 + config.rests[.サウナ]!.recovery, accuracy: 1e-9)
        XCTAssertGreaterThan(s.メンタル, mental)
    }

    /// 払えなければ完全休養に落ちる（Python do_rest と同じ）。お金は減らない
    func testPaidRestFallsBackToFullRestWhenShort() {
        let config = GameConfig()
        var s = GameState(config: config)
        s.money = config.restCosts[.温泉に一泊]! - 1; s.stamina = 10
        var expect = s
        GameEngine.applyRest(.完全休養, to: &expect, config: config)
        GameEngine.applyRest(.温泉に一泊, to: &s, config: config)
        XCTAssertEqual(s.money, expect.money)
        XCTAssertEqual(s.stamina, expect.stamina, accuracy: 1e-9)
        XCTAssertEqual(s.メンタル, expect.メンタル, accuracy: 1e-9)
    }

    /// ちょうど払える額なら払って休める（境界）
    func testPaidRestExactCashIsEnough() {
        let config = GameConfig()
        var s = GameState(config: config)
        s.money = config.restCosts[.サウナ]!; s.stamina = 0
        GameEngine.applyRest(.サウナ, to: &s, config: config)
        XCTAssertEqual(s.money, 0)
        XCTAssertEqual(s.stamina, config.rests[.サウナ]!.recovery, accuracy: 1e-9)
    }

    /// 無料の休みはお金に触れない
    func testFreeRestDoesNotTouchMoney() {
        let config = GameConfig()
        var s = GameState(config: config)
        s.money = -5_000
        GameEngine.applyRest(.気分転換, to: &s, config: config)
        XCTAssertEqual(s.money, -5_000)
    }

    // MARK: 練習の場所

    func testPlaceTrainingRequiresCash() {
        let config = GameConfig()
        var s = GameState(config: config)
        s.money = config.trainings[.喫茶店で書く]!.cost - 1
        let before = s
        XCTAssertFalse(GameEngine.applyTraining(.喫茶店で書く, to: &s, config: config))
        XCTAssertEqual(s.money, before.money)

        s.money = 100_000
        XCTAssertTrue(GameEngine.applyTraining(.ファミレスで書く, to: &s, config: config))
        XCTAssertEqual(s.money, 100_000 - config.trainings[.ファミレスで書く]!.cost)
    }

    /// 場所ごとの完成度の伸び：家で書く（netaReviseGain）より喫茶店・ファミレスの方が伸びる
    func testPlaceGainRaisesPolishMoreThanHome() {
        let config = GameConfig()
        func polishAfter(_ gain: Double?) -> Double {
            var r = WeekRunner(state: GameState(config: config), year: 1, config: config, rng: SplitMix64(seed: 1))
            let id = r.applyNetaCreate(kata: .瞬発, lengthFit: [.短尺], name: "N")
            let base = r.state.netas[0].polish
            r.applyNetaRevise(id: id, gain: gain)
            return r.state.netas[0].polish - base
        }
        let home = polishAfter(nil)
        XCTAssertEqual(home, config.netaReviseGain, accuracy: 1e-9)
        for t in [Training.喫茶店で書く, .ファミレスで書く] {
            let g = config.netaPlaceGain[t]!
            XCTAssertEqual(polishAfter(g), g, accuracy: 1e-9)
            XCTAssertGreaterThan(g, config.netaReviseGain)
        }
    }

    func testNetaWriteTrainingsSet() {
        XCTAssertEqual(GameConfig.netaWriteTrainings, [.ネタ作り, .喫茶店で書く, .ファミレスで書く])
    }
}
