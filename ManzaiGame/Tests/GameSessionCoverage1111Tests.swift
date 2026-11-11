// GameSession の「本番で通る分岐」の穴埋め（11/11 網羅測定：行単位では DEBUG 以外ほぼ通過済み＝領域単位の未通過を足す）
import XCTest
import GameCore
@testable import ManzaiGame

final class GameSessionCoverage1111Tests: IsolatedStoreTestCase {
    private func bytes(_ s: GameState) -> Data {
        let e = JSONEncoder(); e.outputFormatting = .sortedKeys
        return try! e.encode(s)
    }
    private func rec(_ y: Int, champ: Bool) -> GameSession.YearRecord {
        GameSession.YearRecord(year: y, roundsPassed: champ ? 5 : 1, reachedFinal: champ, champion: champ, bankrupt: false, prize: 0)
    }
    private func session(history: [GameSession.YearRecord], year: Int) throws -> GameSession {
        let s0 = GameSession(seed: 1)
        s0.saveNow()
        let data = try XCTUnwrap(GameSession.store.data(forKey: "manzai.save.v1"))
        var save = try JSONDecoder().decode(GameSession.SaveData.self, from: data)
        save.yearHistory = history
        save.runner.year = year
        return GameSession(restoring: save)
    }

    // 1. 選ぶ文が 0 個の時は 0 を返す（クラッシュしない）
    func testPickIndexWithZeroCountIsZero() {
        let s = GameSession(seed: 1)
        XCTAssertEqual(s.pickIndex(scene: "none", count: 0, salt: 3), 0)
        XCTAssertEqual(s.pickIndex(scene: "none", count: 0, salt: 9, key: 5), 0)
    }

    // 2. 自由週でない段での choose は何も変えない（大会入口の段）
    func testChooseIgnoredOutsideFreeActionPhase() {
        let s = GameSession(startState: GameSession.debugNetaState())
        s.debugAdvanceToTournamentEntry(week: 12)
        if case .freeAction = s.phase { return XCTFail("大会入口まで進む想定") }
        let before = bytes(s.state), week = s.week
        s.choose(.rest(.完全休養))
        XCTAssertEqual(bytes(s.state), before)
        XCTAssertEqual(s.week, week)
    }

    // 3. 借金の知らせ：同じ段・浅い段は記録を戻さない／深い段へだけ進む
    func testDebtWarnTierOnlyMovesDeeper() {
        let s = GameSession(seed: 1)
        XCTAssertNil(s.debtNoticeTierToShow(money: 10_000))
        s.markDebtWarned(2)
        XCTAssertEqual(s.debtWarnTier, 2)
        s.markDebtWarned(1)
        s.markDebtWarned(2)
        XCTAssertEqual(s.debtWarnTier, 2, "浅い段・同じ段では戻らない")
        XCTAssertNil(s.debtNoticeTierToShow(money: -600_000), "出した段は再び出さない")
        XCTAssertEqual(s.debtNoticeTierToShow(money: -900_000), 3)
        s.markDebtWarned(3)
        XCTAssertEqual(GameSession.loadedOrNew().debtWarnTier, 3, "深い段は保存される")
    }

    // 4. 予告の後の一言：二度目の markRiftHintShown は何もしない
    func testMarkRiftHintShownTwiceIsStable() {
        let s = GameSession(seed: 1)
        XCTAssertFalse(s.didShowRiftHint)
        s.markRiftHintShown()
        s.markRiftHintShown()
        XCTAssertTrue(s.didShowRiftHint)
        XCTAssertFalse(s.riftHintToShow)
        XCTAssertTrue(GameSession.loadedOrNew().didShowRiftHint)
    }

    // 5. 優勝していない時の勇退は何も起きない（セーブも変わらない）
    func testRetireAfterWinIgnoredWhenNotChampion() {
        let s = GameSession(seed: 1)
        XCTAssertFalse(s.canChooseRetire)
        s.saveNow()
        let saved = GameSession.store.data(forKey: "manzai.save.v1")
        s.retireAfterWin()
        XCTAssertFalse(s.retiredAfterWin)
        XCTAssertEqual(GameSession.store.data(forKey: "manzai.save.v1"), saved)
    }

    // 6. 連覇の見出し：2連続で「2連覇」・間に負けがあれば数え直し
    func testWinHeadlineCountsOnlyTrailingStreak() throws {
        XCTAssertEqual(try session(history: [], year: 1).winHeadline, "優勝")
        XCTAssertEqual(try session(history: [rec(1, champ: true), rec(2, champ: false), rec(3, champ: true)], year: 4).winHeadline, "優勝")
        XCTAssertEqual(try session(history: [rec(1, champ: false), rec(2, champ: true), rec(3, champ: true)], year: 4).winHeadline, "2連覇")
        XCTAssertEqual(try session(history: [rec(1, champ: true), rec(2, champ: true), rec(3, champ: true)], year: 4).winHeadline, "3連覇")
    }

    // 7. 持ちネタが無い時の既定ネタ整え：何も起きない
    func testEnsureStageNetaDefaultWithoutNetasIsNoOp() {
        let s = GameSession(seed: 1)
        XCTAssertTrue(s.activeNetas.isEmpty)
        let before = bytes(s.state)
        s.ensureStageNetaDefault()
        XCTAssertEqual(bytes(s.state), before)
        XCTAssertNil(s.selectedNeta)
    }

    // 8. 次の一段の費用：粒が尽きている状態では nil
    func testCostOfNextStepNilWithoutGrains() {
        let s = GameSession(seed: 1)
        var empty = GameState(config: GameConfig())
        empty.exp閃き = 0; empty.exp語彙 = 0; empty.exp間合い = 0; empty.exp存在感 = 0; empty.exp胆力 = 0
        for a in Ability.allCases { XCTAssertNil(s.costOfNextStep(a, in: empty)) }
    }
}
