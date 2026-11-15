import XCTest
@testable import GameCore

/// THE HANA 1回戦（動画審査）の紙講評に、客席・会場がある前提の行が出ないこと（候補 hana-video-review）
final class JudgeVideoReview1116Tests: XCTestCase {
    private func scenes() -> [JudgeTalk.Scene] {
        var out: [JudgeTalk.Scene] = []
        for (compat, stamina, mental) in [(10.0, 60.0, 50.0), (19, 60, 50), (10, 20, 50), (10, 60, 10), (5, 60, 50)] {
            for margin in [nil, -2.0, -6.0, -15.0, 5.0] as [Double?] {
                for burst in [false, true] {
                    var s = JudgeTalk.Scene(netaName: "回転寿司", isFresh: burst, burst: burst, margin: margin,
                                            compat: compat, stamina: stamina, mental: mental)
                    s.isVideo = true
                    out.append(s)
                }
            }
        }
        return out
    }

    func testVideoReviewHasNoVenueWords() {
        for s in scenes() {
            for passed in [true, false] {
                for salt in 0..<200 {
                    let t = JudgeTalk.paperReview(passed: passed, scene: s, salt: salt).text
                    XCTAssertFalse(JudgeTalk.isVenueLine(t), "動画審査に客前の行: \(t)")
                }
            }
        }
    }

    /// ハマった夜（passBurst）は全行が客前＝通常の束へ落ちる（上のテストで担保）
    func testEveryPaperPoolKeepsLinesForVideo() {
        let pools: [[String]] = [JudgeTalk.Paper.pass, JudgeTalk.Paper.fail, JudgeTalk.Paper.failNear, JudgeTalk.Paper.failFar,
                                 JudgeTalk.Paper.passChemistryHigh, JudgeTalk.Paper.passStaminaLow, JudgeTalk.Paper.passMentalLow,
                                 JudgeTalk.Paper.failStaminaLow, JudgeTalk.Paper.failMentalLow,
                                 JudgeTalk.Paper.failChemistryLow]
        for p in pools { XCTAssertGreaterThan(p.filter { !JudgeTalk.isVenueLine($0) }.count, 0) }
    }

    func testNonVideoUnchanged() {
        let s = JudgeTalk.Scene(netaName: "回転寿司")
        var v = s; v.isVideo = false
        for salt in 0..<50 {
            XCTAssertEqual(JudgeTalk.paperReview(passed: true, scene: s, salt: salt).text,
                           JudgeTalk.paperReview(passed: true, scene: v, salt: salt).text)
        }
    }
}
