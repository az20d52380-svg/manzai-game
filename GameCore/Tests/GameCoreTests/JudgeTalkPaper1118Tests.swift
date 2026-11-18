import XCTest
@testable import GameCore

/// 紙講評の矛盾の直し（code_review_judgetalk_1118 #1・#2）
final class JudgeTalkPaper1118Tests: XCTestCase {
    func testBigMarginFailDoesNotSayContentWasFine() {
        let bad = ["通過水準", "それだけで落とした", "中身の問題ではない", "通る水準"]
        for (st, me) in [(10.0, 50.0), (60.0, 5.0)] {
            let scene = JudgeTalk.Scene(netaName: "コンビニ", margin: -20, stamina: st, mental: me)
            for salt in 0..<200 {
                let t = JudgeTalk.paperReview(passed: false, scene: scene, salt: salt).text
                for w in bad { XCTAssertFalse(t.contains(w), "\(t)") }
            }
        }
    }

    func testFreshFailNeverOldFormAndRevivalPassNeverNotOld() {
        let fresh = JudgeTalk.Scene(netaName: "コンビニ", isFresh: true, margin: -5)
        let revival = JudgeTalk.Scene(netaName: "コンビニ", isRevivalNeta: true, margin: 5)
        for salt in 0..<300 {
            XCTAssertFalse(JudgeTalk.paperReview(passed: false, scene: fresh, salt: salt).text.contains("古い形"))
            XCTAssertFalse(JudgeTalk.paperReview(passed: true, scene: revival, salt: salt).text.contains("古くない"))
        }
    }
}

final class JudgeTalkBurstTop1118Tests: XCTestCase {
    /// 爆発した夜（burst）にトップでも、低い側の白波は「トップの客は冷えてんだよ」を言わない（#4）
    func testLowSideNoColdCrowdOnBurst() {
        guard let j = JudgeTalk.judgeNames.first(where: { $0.hasPrefix("白波") }) else { return }
        let lines = JudgeTalk.sceneLines(judge: j, scene: .init(burst: true, order: 1), high: false)
        XCTAssertFalse(lines.contains { $0.contains("冷えてんだよ") })
        let calm = JudgeTalk.sceneLines(judge: j, scene: .init(burst: false, order: 1), high: false)
        XCTAssertTrue(calm.contains { $0.contains("冷えてんだよ") })
    }
}
