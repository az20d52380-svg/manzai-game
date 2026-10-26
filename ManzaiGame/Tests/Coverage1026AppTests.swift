// 表示の判定ロジックの未カバー（app_coverage_1026_v0）。年末の判・独白プール・週画面の文言の選び分け。
import XCTest
import GameCore
@testable import ManzaiGame

final class Coverage1026AppTests: IsolatedStoreTestCase {
    private let names = GameConfig().calendar.gpRoundNames
    private func oc(_ rounds: Int = 0, final: Bool = false, champ: Bool = false, bank: Bool = false, diss: Bool = false) -> YearOutcome {
        YearOutcome(champion: champ, roundsPassed: rounds, reachedFinal: final, bankrupt: bank, dissolved: diss)
    }
    private func stamp(_ o: YearOutcome?, entered: Bool = true) -> (String, Bool) {
        YearResultView.reachStamp(o, gpRoundNames: names, notEnteredGP: YearResultView.notEntered(o, loggedGPEntry: entered))
    }

    func testReachStampPriorityOrder() {
        XCTAssertEqual(stamp(nil).0, "——")
        XCTAssertEqual(stamp(oc(5, final: true, champ: true)).0, "優勝")
        XCTAssertEqual(stamp(oc(0, bank: true, diss: true)).0, "夜逃げ")
        XCTAssertEqual(stamp(oc(2, diss: true)).0, "解散")
        XCTAssertEqual(stamp(oc(5, final: true)).0, "決勝")
    }

    func testReachStampNamesTheRoundLostNotPassed() {
        XCTAssertEqual(stamp(oc(1)).0, "2回戦敗退")
        XCTAssertEqual(stamp(oc(2)).0, "3回戦敗退")
        XCTAssertEqual(stamp(oc(3)).0, "準々決勝敗退")
        XCTAssertEqual(stamp(oc(5)).0, "準決勝敗退")
        XCTAssertTrue(stamp(oc(1)).1)
        XCTAssertFalse(stamp(oc(0)).1)     // 1回戦で負けた年は通過扱いでない
    }

    func testNotEnteredGPOnlyWhenNoRoundPassedAndNoEntryLogged() {
        XCTAssertEqual(stamp(oc(0), entered: false).0, "不出場")
        XCTAssertEqual(stamp(oc(0), entered: true).0, "1回戦敗退")
        XCTAssertFalse(YearResultView.notEntered(oc(1), loggedGPEntry: false))
        XCTAssertFalse(YearResultView.notEntered(nil, loggedGPEntry: false))
    }

    func testReachSubTextPerOutcome() {
        XCTAssertEqual(YearResultView.reachSubText(nil, notEnteredGP: false), "")
        XCTAssertEqual(YearResultView.reachSubText(oc(5, champ: true), notEnteredGP: false), "頂グランプリ制覇")
        XCTAssertEqual(YearResultView.reachSubText(oc(bank: true), notEnteredGP: true), "所持金が尽きてキャリア終了")
        XCTAssertTrue(YearResultView.reachSubText(oc(diss: true), notEnteredGP: false).contains("解散"))
        XCTAssertEqual(YearResultView.reachSubText(oc(5, final: true), notEnteredGP: false), "決勝の舞台に立った")
        XCTAssertTrue(YearResultView.reachSubText(oc(0), notEnteredGP: true).contains("出られなかった"))
        XCTAssertEqual(YearResultView.reachSubText(oc(2), notEnteredGP: false), "頂グランプリ 到達段階")
    }

    func testYearEndPoolSceneByOutcome() {
        XCTAssertEqual(YearResultView.yearEndPool(oc(bank: true), fame: 99, year: 3).scene, "yearEnd.bankrupt")
        XCTAssertEqual(YearResultView.yearEndPool(oc(diss: true), fame: 99, year: 3).scene, "yearEnd.dissolution")
        XCTAssertEqual(YearResultView.yearEndPool(oc(3), fame: 0, year: 3).scene, "yearEnd.leap")
        XCTAssertEqual(YearResultView.yearEndPool(oc(0), fame: 30, year: 3).scene, "yearEnd.leap")
        XCTAssertEqual(YearResultView.yearEndPool(oc(2), fame: 29, year: 3).scene, "yearEnd.stall")
        XCTAssertEqual(YearResultView.yearEndPool(oc(0, final: true), fame: 0, year: 3).scene, "yearEnd.leap")
    }

    func testYearEndPoolFirstYearDropsLastYearLines() {
        let first = YearResultView.yearEndPool(oc(3), fame: 0, year: 1)
        XCTAssertEqual(first.scene, "yearEnd.leap.first")
        XCTAssertFalse(first.pool.contains { $0.contains("去年") })
        XCTAssertFalse(first.pool.isEmpty)
        let stall = YearResultView.yearEndPool(oc(0), fame: 0, year: 1)
        XCTAssertEqual(stall.scene, "yearEnd.stall.first")
        XCTAssertFalse(stall.pool.contains { $0.contains("去年") })
        XCTAssertEqual(YearResultView.yearEndPool(oc(bank: true), fame: 0, year: 1).scene, "yearEnd.bankrupt")   // 貧乏・解散は1年目でも同じ
    }

    func testStaminaZoneBoundaries() {
        XCTAssertEqual(WeekMainView.staminaZone(0), 0)
        XCTAssertEqual(WeekMainView.staminaZone(19.9), 0)
        XCTAssertEqual(WeekMainView.staminaZone(20), 1)
        XCTAssertEqual(WeekMainView.staminaZone(49.9), 1)
        XCTAssertEqual(WeekMainView.staminaZone(50), 2)
        XCTAssertEqual(WeekMainView.staminaZone(100), 2)
    }

    func testVesselFullNeedsBudget() {
        XCTAssertFalse(WeekMainView.vesselFull(budget: nil, used: 999))
        XCTAssertFalse(WeekMainView.vesselFull(budget: 0, used: 5))
        XCTAssertFalse(WeekMainView.vesselFull(budget: 10, used: 9))
        XCTAssertTrue(WeekMainView.vesselFull(budget: 10, used: 10))
        XCTAssertTrue(WeekMainView.vesselFull(budget: 10, used: 12))
    }

    func testWeakAbilityNameIgnoresFlatAndPicksLowest() {
        let flat: [(String, Double)] = [("センス", 10), ("発想", 10), ("表現", 10), ("華", 10), ("メンタル", 10.5)]
        XCTAssertEqual(WeekMainView.weakAbilityName(flat), "")     // 差1未満は弱点なし
        let v: [(String, Double)] = [("センス", 30), ("発想", 20), ("表現", 25), ("華", 12), ("メンタル", 40)]
        XCTAssertEqual(WeekMainView.weakAbilityName(v), "華")
        XCTAssertEqual(WeekMainView.weakAbilityName([("センス", 11), ("発想", 10)]), "発想")   // ちょうど差1
    }

    func testLullTextByNetaAndShoot() {
        XCTAssertEqual(WeekMainView.lullText(netaName: nil, polish: 0, preoccupied: false), "大会まで間がある ・ まずはネタを書こう")
        XCTAssertEqual(WeekMainView.lullText(netaName: nil, polish: 0, preoccupied: true), "大会まで間がある ・ ネタは来週から")
        XCTAssertEqual(WeekMainView.lullText(netaName: "猫", polish: 41.6, preoccupied: true), "大会まで間がある ・ ネタ「猫」完成度 42/100")
    }

    func testNetaEffectText() {
        let cfg = GameConfig()
        let write = WeekMainView.netaEffectText(.train(.ネタ作り), config: cfg, revising: false, hasNetas: true)
        XCTAssertEqual(write, "新ネタ")
        XCTAssertEqual(WeekMainView.netaEffectText(.train(.ネタ作り), config: cfg, revising: true, hasNetas: true), "完成度 +\(Int(cfg.netaReviseGain))")
        XCTAssertEqual(WeekMainView.netaEffectText(.train(.喫茶店で書く), config: cfg, revising: true, hasNetas: true), "完成度 +\(Int(cfg.netaPlaceGain[.喫茶店で書く]!))")
        XCTAssertEqual(WeekMainView.netaEffectText(.train(.ネタ見せ会), config: cfg, revising: false, hasNetas: true), "完成度 +\(Int(cfg.netaLivePolishShow))")
        XCTAssertNil(WeekMainView.netaEffectText(.train(.ネタ見せ会), config: cfg, revising: false, hasNetas: false))
        XCTAssertEqual(WeekMainView.netaEffectText(.train(.フリーライブ), config: cfg, revising: false, hasNetas: true), "完成度 +\(Int(cfg.netaLivePolishFree))")
        XCTAssertNil(WeekMainView.netaEffectText(.rest(.完全休養), config: cfg, revising: false, hasNetas: true))
    }
}
