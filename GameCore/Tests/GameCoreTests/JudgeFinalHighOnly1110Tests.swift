import XCTest
@testable import GameCore

/// 採点 v1 §4 論点1 案A【仮・候補】: 最低点の審査員が B帯のとき、全褒めの行（highOnly）と、その行に付く拾いを出さない。
final class JudgeFinalHighOnly1110Tests: XCTestCase {
    private func scenes() -> [JudgeTalk.Scene] {
        var out: [JudgeTalk.Scene] = [JudgeTalk.Scene(), JudgeTalk.Scene(netaName: "引っ越しの夜")]
        out.append(.init(netaName: "牛丼の逆襲", isTeppan: true, burst: true, order: 1))
        out.append(.init(netaName: "夏祭りの後", isRevivalNeta: true, order: 10, lastOrder: 10))
        out.append(.init(netaName: nil, isFresh: true, order: 5))
        return out
    }

    func testHighOnlyLinesExistInBandB() {
        let all = Set(JudgeTalk.bandLines.values.flatMap { $0["B"] ?? [] })
        for t in JudgeTalk.highOnly { XCTAssertTrue(all.contains(t), "B帯に無い印: \(t)") }
    }

    func testLowSideBandBNeverShowsHighOnly() {
        let pickHeads = JudgeTalk.pickups.map { $0.head }.filter { h in JudgeTalk.highOnly.contains { $0.hasPrefix(h) } }
        for judge in JudgeTalk.judgeNames {
            for score in 91...94 {
                for scene in scenes() {
                    var seen = Set<String>()
                    for salt in 0...200 {
                        let c = JudgeTalk.finalComment(judge: judge, score: score, high: false, scene: scene, salt: salt)
                        seen.insert(c.text)
                        for t in JudgeTalk.highOnly {
                            XCTAssertNotEqual(c.text, JudgeTalk.fill(t, scene: scene, salt: salt), "\(judge) \(score) \(c.text)")
                        }
                        for h in pickHeads { XCTAssertFalse(c.text.hasPrefix(h), "低い側に拾い: \(c.text)") }
                    }
                    XCTAssertGreaterThanOrEqual(seen.count, 2, "低い側B帯の行が細い: \(judge) \(scene)")
                }
            }
        }
    }

    func testHighSideStillShowsHighOnly() {
        let scene = JudgeTalk.Scene(netaName: "引っ越しの夜")
        let texts = Set((0...200).map { JudgeTalk.finalComment(judge: "天堂寺 銀郎", score: 92, high: true, scene: scene, salt: $0).text })
        XCTAssertTrue(texts.contains("粗を探す気で座った。粗がなかった。"))
    }
}
