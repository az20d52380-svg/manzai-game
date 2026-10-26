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

    // MARK: 差し込みの崩れ（採点 judge_comment_score_v1 の×△の再発防止）

    /// 全テンプレート（帯・場面・状態・紙・ネタの来歴・司会の拾いの返し）
    private func allTemplates() -> [String] {
        var t: [String] = JudgeTalk.bandLines.values.flatMap { $0.values.flatMap { $0 } }
        let condScenes: [JudgeTalk.Scene] = [
            .init(isTeppan: true, isRevivalNeta: true, isFresh: true, burst: true, order: 1, viaRevival: true, compat: 20, stamina: 20, mental: 30, hana: 95),
            .init(isTeppan: true, isRevivalNeta: true, isFresh: true, burst: true, order: 10, viaRevival: true, compat: 20, stamina: 20, mental: 30, hana: 95),
            .init(order: 5, compat: 10, stamina: 60, mental: 50, hana: 95),   // 華だけ（卯月・音羽の華フック）
        ]
        for j in JudgeTalk.judgeNames {
            for sc in condScenes {
                for high in [true, false] {
                    t += JudgeTalk.sceneLines(judge: j, scene: sc, high: high)
                    t += JudgeTalk.hookLines(judge: j, scene: sc, high: high) ?? []
                }
            }
            // 敗者復活だけ・相性だけの時のフック（上の全部入りでは先に別の条件が当たる審査員がいる）
            t += JudgeTalk.hookLines(judge: j, scene: .init(viaRevival: true), high: true) ?? []
            t += JudgeTalk.hookLines(judge: j, scene: .init(compat: 20), high: true) ?? []
            t += JudgeTalk.hookLines(judge: j, scene: .init(stamina: 20), high: false) ?? []
        }
        let P = JudgeTalk.Paper.self
        t += P.pass + P.fail + P.failNear + P.failFar + P.passBurst + P.passChemistryHigh + P.passStaminaLow
        t += P.failStaminaLow + P.passMentalLow + P.failMentalLow + P.failChemistryLow
        let rich = JudgeTalk.Scene(isTeppan: true, isRevivalNeta: true, isFresh: true)
        t += JudgeTalk.paperNetaLines(scene: rich, passed: true) + JudgeTalk.paperNetaLines(scene: rich, passed: false)
        t += JudgeTalk.pickups.compactMap { $0.reply }
        return Array(Set(t))
    }

    /// テンプレートを語彙表の全組み合わせで展開する（salt を介さず総当たり）
    private func expandAll(_ template: String, kata: NetaKata?) -> [String] {
        let table = JudgeTalk.vocab[kata]!
        var outs = [template.replacingOccurrences(of: "{題}", with: "『満員電車』")]
        for slot in JudgeTalk.Slot.allCases {
            let token = "{\(slot.rawValue)}"
            guard template.contains(token) else { continue }
            outs = outs.flatMap { o in table[slot]!.map { o.replacingOccurrences(of: token, with: $0) } }
        }
        return outs
    }

    /// 同じ語が2回出ない（所・最後・最初・一言・だけ と、差し込み口の形の語・客席・相方・本題）／助詞が重ならない
    func testExpansionHasNoRepeatsOrDoubledParticles() {
        let watch = ["所", "最後", "最初", "一言", "だけ", "入り", "場面", "ツッコミ", "締め", "客席", "相方", "本題"]
        let doubled = ["のの", "でで", "がが", "をを", "にに", "からから", "はは", "まで、まで"]
        var bad: [String] = []
        let templates = allTemplates()
        XCTAssertGreaterThan(templates.count, 250)
        for t in templates {
            for k in JudgeTalk.vocab.keys {
                for text in expandAll(t, kata: k) {
                    XCTAssertFalse(text.contains("{"), text)
                    for w in watch where text.components(separatedBy: w).count - 1 >= 2 { bad.append("[\(w)] \(text)") }
                    for d in doubled where text.contains(d) { bad.append("[\(d)] \(text)") }
                }
            }
        }
        let uniq = Array(Set(bad)).sorted()
        // 一覧が要る時: JT_DUMP=<ファイル> swift test --filter JudgeTalkTests
        if let path = ProcessInfo.processInfo.environment["JT_DUMP"] { try? uniq.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8) }
        XCTAssertTrue(uniq.isEmpty, "崩れ \(uniq.count) 件:\n" + uniq.prefix(10).joined(separator: "\n"))
    }

    /// 語彙表の形の決まり（口ごとに語尾を固定・重なりやすい語を含めない・同じ型の中で語を重ねない）
    func testVocabShape() {
        let suffix: [JudgeTalk.Slot: String] = [.入り: "の入り", .中: "の場面", .一言: "ツッコミ", .締め: "締め"]
        let banned = ["所", "最後", "最初", "一言", "だけ", "客席", "相方", "本題", "ボケ", "決め", "戻"]
        for (k, table) in JudgeTalk.vocab {
            var heads: [String] = []
            for slot in JudgeTalk.Slot.allCases {
                let list = table[slot]!
                if k == nil { XCTAssertGreaterThanOrEqual(list.count, 8) } else { XCTAssertEqual(list.count, 4) }  // 型なしは各口8語以上（judge_comment_score_v6 §4・v7 直しで{中}を11語）
                for w in list {
                    XCTAssertTrue(w.hasSuffix(suffix[slot]!), "\(String(describing: k)) \(slot) \(w)")
                    for b in banned { XCTAssertFalse(w.contains(b), "\(w) に \(b)") }
                    heads.append(String(w.prefix(2)))
                }
            }
            XCTAssertEqual(Set(heads).count, heads.count, "同じ型の中で語の頭が重なる: \(String(describing: k)) \(heads)")
        }
    }

    /// 声の長さ（rewrite_v1 §3）: 文の数の上限を審査員ごとに守る（『』の中は数えない）
    func testSentenceCountPerJudge() {
        let limit = ["天堂寺 銀郎": 2, "花園 千代": 2, "卯月 走太": 3, "白波 剛": 2, "目白 慧": 3, "神楽坂 とんぼ": 2, "音羽 ルリ": 2]
        func sentences(_ t: String) -> Int {
            var depth = 0, n = 0
            for c in t {
                if c == "『" { depth += 1 } else if c == "』" { depth -= 1 }
                else if depth == 0 && "。！？".contains(c) { n += 1 }
            }
            if let last = t.last, !"。！？".contains(last) { n += 1 }
            return n
        }
        let rich: [JudgeTalk.Scene] = [
            .init(isTeppan: true, isRevivalNeta: true, isFresh: true, burst: true, order: 1, viaRevival: true, compat: 20, stamina: 20, mental: 30, hana: 95),
            .init(isTeppan: true, isRevivalNeta: true, isFresh: true, burst: true, order: 10, compat: 10, stamina: 60, mental: 50, hana: 95),
        ]
        for (j, max) in limit {
            var lines = JudgeTalk.bandLines[j]!.values.flatMap { $0 }
            for sc in rich { for h in [true, false] {
                lines += JudgeTalk.sceneLines(judge: j, scene: sc, high: h) + (JudgeTalk.hookLines(judge: j, scene: sc, high: h) ?? [])
            } }
            for t in lines { XCTAssertLessThanOrEqual(sentences(t), max, "\(j): \(t)") }
        }
    }

    /// 紙講評の状態フックは「体力→メンタル→相性」の順で1つだけ効く（重なっても先の方が勝つ）
    func testPaperStateHookPriority() {
        func text(_ passed: Bool, st: Double, me: Double, co: Double, _ salt: Int) -> String {
            var sc = JudgeTalk.Scene(netaName: nil, kata: nil)
            sc.stamina = st; sc.mental = me; sc.compat = co
            return JudgeTalk.paperReview(passed: passed, scene: sc, salt: salt).text
        }
        var differs = false
        for salt in 0..<60 {
            // 不合格：体力低＋メンタル低＋相性低 ＝ 体力低だけ と同じ
            XCTAssertEqual(text(false, st: 20, me: 10, co: 5, salt), text(false, st: 20, me: 50, co: 12, salt))
            // 不合格：メンタル低＋相性低 ＝ メンタル低だけ
            XCTAssertEqual(text(false, st: 60, me: 10, co: 5, salt), text(false, st: 60, me: 10, co: 12, salt))
            // 合格：体力低＋メンタル低 ＝ 体力低だけ
            XCTAssertEqual(text(true, st: 20, me: 10, co: 12, salt), text(true, st: 20, me: 50, co: 12, salt))
            if text(false, st: 20, me: 50, co: 12, salt) != text(false, st: 60, me: 10, co: 12, salt) { differs = true }
        }
        XCTAssertTrue(differs, "体力低とメンタル低は別の文の束")
    }
}

