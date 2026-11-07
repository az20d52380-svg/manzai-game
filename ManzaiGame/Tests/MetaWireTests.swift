// 周回の配線（トロフィー・図鑑→点→次の周の初期値・記録）
import XCTest
import GameCore
@testable import ManzaiGame

final class MetaWireTests: XCTestCase {
    private var saved: UserDefaults!
    override func setUp() {
        saved = GameSession.store
        let d = UserDefaults(suiteName: "mz.metawire.test")!
        d.removePersistentDomain(forName: "mz.metawire.test")
        GameSession.store = d
    }
    override func tearDown() { GameSession.store = saved }

    func testTrophyPointsTotal30() {
        XCTAssertEqual(TrophyID.allCases.count, 22)
        XCTAssertEqual(TrophyID.allCases.reduce(0) { $0 + $1.pt }, 30)
    }
    func testAwardOnlyOnceAndPoints() {
        XCTAssertEqual(MetaBook.points, 0)
        XCTAssertTrue(TrophyBook.award(.t21))
        XCTAssertFalse(TrophyBook.award(.t21))
        XCTAssertEqual(TrophyBook.points, 3)
        EndingBook.record(.keptGoing, partner: "A")
        XCTAssertEqual(MetaBook.points, 4)
    }
    func testFirstLapUnchangedAndMetaApplied() {
        let s0 = GameSession()
        XCTAssertNil(s0.state.metaPoints)
        TrophyBook.award(.t17)
        let s1 = GameSession()
        XCTAssertEqual(s1.state.metaPoints, 2)
        XCTAssertGreaterThan(s1.state.money, s0.state.money)
    }
    func testRecords() {
        TrophyBook.recordChampion(year: 7, streak: 1)
        TrophyBook.recordChampion(year: 4, streak: 2)
        let r = TrophyBook.loadRecords()
        XCTAssertEqual(r, CareerRecords(bestStreak: 2, fastestWinYear: 4, totalWins: 2))
    }
    func testStageTrophies() {
        var st = GameState(config: GameConfig()); st.stamina = 10; st.money = -5
        TrophyBook.onStage(StageResult(name: "GP1回戦", passed: true, prize: 0), state: st, config: GameConfig())
        XCTAssertEqual(TrophyBook.load(), [.t01, .t15, .t16])
    }
    func testBanner() {
        XCTAssertNil(MetaBook.bannerLines(points: 0))
        XCTAssertEqual(MetaBook.preview(points: 10)?.money, 300_000)
    }
}
