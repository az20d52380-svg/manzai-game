// JudgeTalkTests.swift
// 審査員講評の差し込み（docs/judge_comment_rewrite_v1.md）の検証。表示専用・乱数非消費＝golden とは無関係。
// 確かめること: ①必ず具体物（型の語彙かネタ名）が入る ②空の変数でも差し込み口が残らない ③恒久規約（笑・来年）④決定的 ⑤同じ条件でも散る

import XCTest
@testable import GameCore

final class JudgeTalkTests: XCTestCase {

    private let katas: [NetaKata?] = NetaKata.allCases.map { Optional($0) } + [nil]
    private let scores = [84, 88, 92, 97]

    /// 具体物が入っているか（その型の語彙・ネタ名・型なし語彙のどれか）
    private func hasSpecific(_ text: String, _ scene: JudgeTalk.Scene) -> Bool {
        if let n = scene.netaName, text.contains("『\(n)』") { return true }
        let table = JudgeTalk.vocab[scene.kata] ?? JudgeTalk.vocab[nil]!
        return table.values.flatMap { $0 }.contains { text.contains($0) }
    }

    private func scenes() -> [JudgeTalk.Scene] {
        var out: [JudgeTalk.Scene] = []
        for k in katas {
            for name in [nil, "満員電車"] as [String?] {
                out.append(.init(netaName: name, kata: k))
                out.append(.init(netaName: name, kata: k, isTeppan: true, burst: true, order: 1))
                out.append(.init(netaName: name, kata: k, isRevivalNeta: true, order: 10, viaRevival: true, compat: 20, hana: 95))
                out.append(.init(netaName: name, kata: k, isFresh: true, order: 5, stamina: 20, mental: 30))
            }
        }
        return out
    }

    func testFinalsAlwaysCarrySpecificAndNoLeftoverSlots() {
        for scene in scenes() {
            for judge in JudgeTalk.judgeNames {
                for score in scores {
                    for high in [true, false] {
                        for salt in 0..<12 {
                            let c = JudgeTalk.finalComment(judge: judge, score: score, high: high, scene: scene, salt: salt)
                            let all = c.text + (c.pickup?.reply ?? "")
                            XCTAssertFalse(c.text.isEmpty)
                            XCTAssertFalse(all.contains("{"), "差し込み口が残った: \(all)")
                            XCTAssertFalse(all.contains("このネタ") && scene.netaName != nil)
                            XCTAssertFalse(all.contains("笑"), all)
                            XCTAssertFalse(all.contains("来年"), all)
                            XCTAssertTrue(hasSpecific(all, scene), "具体物なし: \(judge) \(score) \(all)")
                            if high { XCTAssertFalse(c.text.hasPrefix("点は辛うつけたけど"), "最低点専用の行が最高点に出た") }
                        }
                    }
                }
            }
        }
    }

    func testPaperAlwaysCarrySpecificAndNoLeftoverSlots() {
        for base in scenes() {
            for margin in [nil, -2.0, -6.0, -20.0, 5.0] as [Double?] {
                var scene = base
                scene.margin = margin
                for passed in [true, false] {
                    for salt in 0..<12 {
                        let r = JudgeTalk.paperReview(passed: passed, scene: scene, salt: salt)
                        XCTAssertFalse(r.text.contains("{"), r.text)
                        XCTAssertFalse(r.text.contains("笑"), r.text)
                        XCTAssertTrue(hasSpecific(r.text, scene), "具体物なし: \(r.text)")
                        XCTAssertTrue(JudgeTalk.judgeNames.contains(r.judge))
                    }
                }
            }
        }
    }

    func testEmptyNameNeverShowsBrackets() {
        let scene = JudgeTalk.Scene(netaName: nil, kata: nil)
        for salt in 0..<40 {
            for judge in JudgeTalk.judgeNames {
                let t = JudgeTalk.finalComment(judge: judge, score: 92, high: true, scene: scene, salt: salt).text
                XCTAssertFalse(t.contains("『』"))
                XCTAssertFalse(t.contains("このネタ"), "名前なしは {題} 行を候補から外す: \(t)")
            }
            XCTAssertFalse(JudgeTalk.paperReview(passed: false, scene: scene, salt: salt).text.contains("このネタ"))
        }
    }

    func testSceneFromStateWithoutNeta() {
        let config = GameConfig()
        let s = JudgeTalk.Scene.from(state: GameState(config: config), neta: nil, config: config, year: 1)
        XCTAssertNil(s.netaName)
        XCTAssertNil(s.kata)
        var blank = Neta(id: 0, name: "  ", kata: .瞬発, lengthFit: [.短尺], bornYear: 1)
        blank.stageCount = 0
        let s2 = JudgeTalk.Scene.from(state: GameState(config: config), neta: blank, config: config, year: 5)
        XCTAssertNil(s2.netaName, "空白だけの題は差し込まない")
        XCTAssertTrue(s2.isFresh)
        XCTAssertTrue(s2.isRevivalNeta)
    }

    func testDeterministic() {
        let scene = JudgeTalk.Scene(netaName: "商店街の福引", kata: .伏線回収)
        for salt in 0..<30 {
            XCTAssertEqual(JudgeTalk.finalComment(judge: "目白 慧", score: 92, high: true, scene: scene, salt: salt),
                           JudgeTalk.finalComment(judge: "目白 慧", score: 92, high: true, scene: scene, salt: salt))
        }
    }

    /// 同じ審査員・同じ帯・同じネタでも、本番ごと（salt）に違って見える
    func testVariety() {
        let scene = JudgeTalk.Scene(netaName: "商店街の福引", kata: .伏線回収)
        let texts = Set((0..<40).map { JudgeTalk.finalComment(judge: "天堂寺 銀郎", score: 92, high: true, scene: scene, salt: $0).text })
        XCTAssertGreaterThanOrEqual(texts.count, 12)
        let papers = Set((0..<40).map { JudgeTalk.paperReview(passed: true, scene: scene, salt: $0).text })
        XCTAssertGreaterThanOrEqual(papers.count, 20)
    }

    func testPickupReplyCarriesSpecific() {
        let scene = JudgeTalk.Scene(netaName: "満員電車", kata: .瞬発)
        let p = JudgeTalk.pickup(after: "粗を探す気で座った。粗がなかった。", scene: scene, salt: 3)
        XCTAssertEqual(p?.mc, "粗がなかった、と。")
        XCTAssertTrue(hasSpecific(p?.reply ?? "", scene))
        XCTAssertNil(JudgeTalk.pickup(after: "普通の講評です。"))
    }
}
