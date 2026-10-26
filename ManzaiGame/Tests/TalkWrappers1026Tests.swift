// 決勝の司会・紙講評の窓口（アプリ層の薄い包み）の現状固定（10/26 定期・カバー率で未通過だった所）。文面・選び方は不変。
import XCTest
import GameCore
@testable import ManzaiGame

final class TalkWrappers1026Tests: XCTestCase {
    func testAskJudgeUsesFamilyNameAndTone() {
        XCTAssertEqual(FinalsMC.askJudge("鳴海 一郎", score: 95, high: true), "鳴海さん、95点。いかがでしたか？")
        XCTAssertEqual(FinalsMC.askJudge("鳴海 一郎", score: 88, high: false), "鳴海さんは88点と、少し辛めでした。いかがでしたか？")
        XCTAssertEqual(FinalsMC.askJudge("ひとり", score: 90, high: true), "ひとりさん、90点。いかがでしたか？", "空白が無い名前はそのまま")
    }

    func testPickupAndCommentDelegateToJudgeTalk() {
        let scene = JudgeTalk.Scene()
        for salt in 0..<8 {
            for c in ["", "テスト"] {
                XCTAssertEqual(FinalsMC.pickup(after: c, scene: scene, salt: salt)?.reply,
                               JudgeTalk.pickup(after: c, scene: scene, salt: salt)?.reply)
            }
            let a = FinalsJudgeTalk.comment(judge: "鳴海 一郎", score: 90, high: salt % 2 == 0, scene: scene, salt: salt)
            let b = JudgeTalk.finalComment(judge: "鳴海 一郎", score: 90, high: salt % 2 == 0, scene: scene, salt: salt)
            XCTAssertEqual(a.text, b.text)
        }
        XCTAssertEqual(FinalsJudgeTalk.band(95), JudgeTalk.band(95))
    }

    func testPaperReviewDelegatesWithSelectedNeta() {
        let cfg = GameConfig()
        let st = GameSession.debugNetaState()
        for salt in 0..<6 {
            let r = JudgeData.review(passed: salt % 2 == 0, state: st, salt: salt, config: cfg, year: 2, margin: 3, burst: false)
            XCTAssertFalse(r.text.isEmpty)
            XCTAssertFalse(r.text.contains("{"), "差し込みが残らない")
            XCTAssertFalse(r.judge.isEmpty, "署名がある")
        }
    }
}
