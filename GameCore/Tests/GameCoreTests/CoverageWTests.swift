// CoverageWTests.swift
// JudgeTalk の部品（帯・差し込み・候補選び・拾い）／すれ違い（rift）の境目／runCareer の解散停止／特技の費用表の固定。
// Sources は不変。

import XCTest
@testable import GameCore

final class CoverageWTests: XCTestCase {
    let cfg = GameConfig()

    // MARK: JudgeTalk 部品

    func testBandBoundaries() {
        XCTAssertEqual(JudgeTalk.band(100), "A")
        XCTAssertEqual(JudgeTalk.band(95), "A")
        XCTAssertEqual(JudgeTalk.band(94), "B")
        XCTAssertEqual(JudgeTalk.band(91), "B")
        XCTAssertEqual(JudgeTalk.band(90), "C")
        XCTAssertEqual(JudgeTalk.band(87), "C")
        XCTAssertEqual(JudgeTalk.band(86), "D")
        XCTAssertEqual(JudgeTalk.band(0), "D")
    }

    func testMixIsDeterministicAndNonNegative() {
        XCTAssertEqual(JudgeTalk.mix(5, 3), JudgeTalk.mix(5, 3))
        XCTAssertNotEqual(JudgeTalk.mix(5, 3), JudgeTalk.mix(5, 4))
        for salt in [-7, 0, 1, Int.max, Int.min] {
            XCTAssertGreaterThanOrEqual(JudgeTalk.mix(salt, 1), 0)
        }
    }

    func testFillReplacesSlotsAndTitle() {
        let scene = JudgeTalk.Scene(netaName: "桃太郎", kata: .関係性)
        let out = JudgeTalk.fill("{入り}と{中}と{一言}と{締め}と{題}", scene: scene, salt: 3)
        XCTAssertFalse(out.contains("{"))
        XCTAssertTrue(out.hasSuffix("と『桃太郎』"))
        let table = JudgeTalk.vocab[.関係性]!
        XCTAssertTrue(table[.入り]!.contains { out.hasPrefix($0) })
    }

    func testFillWithoutTitleFallsBackAndNilKataUsesGenericVocab() {
        let scene = JudgeTalk.Scene()
        XCTAssertEqual(JudgeTalk.fill("{題}が良い", scene: scene, salt: 0), "このネタが良い")
        let out = JudgeTalk.fill("{入り}", scene: scene, salt: 1)
        XCTAssertTrue(JudgeTalk.vocab[nil]![.入り]!.contains(out))
    }

    func testFillLeavesTextWithoutTokensUntouched() {
        XCTAssertEqual(JudgeTalk.fill("そのままです。", scene: JudgeTalk.Scene(), salt: 9), "そのままです。")
    }

    func testPickFiltersTitleLinesWhenNoNetaName() {
        let pool = ["{題}が良い", "普通の一言"]
        for salt in 0..<20 {
            XCTAssertEqual(JudgeTalk.pick(pool, scene: JudgeTalk.Scene(), salt: salt, k: 1), "普通の一言")
        }
        // 全部 {題} 行なら外さず元の候補のまま
        XCTAssertEqual(JudgeTalk.pick(["{題}だけ"], scene: JudgeTalk.Scene(), salt: 0, k: 1), "{題}だけ")
        XCTAssertNil(JudgeTalk.pick([], scene: JudgeTalk.Scene(netaName: "A"), salt: 0, k: 1))
        // ネタ名があれば {題} 行も候補に残る
        let seen = Set((0..<40).compactMap { JudgeTalk.pick(pool, scene: JudgeTalk.Scene(netaName: "A"), salt: $0, k: 1) })
        XCTAssertEqual(seen, Set(pool))
    }

    func testIsLowOnlyAndPickupHeads() {
        XCTAssertTrue(JudgeTalk.isLowOnly("点は辛うつけたけど、好きは好きやねん。"))
        XCTAssertFalse(JudgeTalk.isLowOnly("好きは好きやねん。"))
        XCTAssertNil(JudgeTalk.pickup(after: "ふつうの講評です。"))
        let p = JudgeTalk.pickup(after: "粗を探す気で座った。粗がなかった。続き")
        XCTAssertEqual(p?.mc, "粗がなかった、と。")
        XCTAssertNotNil(p?.reply)
        XCTAssertFalse(p!.reply!.contains("{"))
        let low = JudgeTalk.pickup(after: "点は辛うつけたけど、好きは好きやねん。")
        XCTAssertNotNil(low)
        XCTAssertNil(low?.reply, "割れ→流すは司会だけで審査員の言い直しなし")
    }

    func testFinalCommentHighNeverUsesLowOnlyLineAndIsDeterministic() {
        let scene = JudgeTalk.Scene(netaName: "桃太郎", kata: .伏線回収)
        for judge in JudgeTalk.judgeNames {
            for salt in 0..<30 {
                let a = JudgeTalk.finalComment(judge: judge, score: 96, high: true, scene: scene, salt: salt)
                XCTAssertFalse(a.text.hasPrefix("点は辛うつけたけど"))
                XCTAssertFalse(a.text.contains("{"))
                XCTAssertEqual(a, JudgeTalk.finalComment(judge: judge, score: 96, high: true, scene: scene, salt: salt))
            }
        }
    }

    func testFinalCommentUnknownJudgeStillProducesText() {
        let c = JudgeTalk.finalComment(judge: "存在しない審査員", score: 80, high: false, scene: JudgeTalk.Scene(), salt: 4)
        XCTAssertFalse(c.text.isEmpty)
        XCTAssertFalse(c.text.contains("{"))
    }

    // MARK: すれ違い（rift）

    private func riftState(rift: Double, warned: Bool?, compat: Double = 10) -> GameState {
        var s = GameState(config: cfg)
        s.rift = rift
        s.riftWarned = warned
        s.compat = compat
        s.riftWeekStartCompat = compat
        s.riftJointWeek = false
        return s
    }

    func testRiftOffDoesNothing() {
        var c = cfg
        c.riftOn = false
        var s = riftState(rift: 99.9, warned: true)
        XCTAssertFalse(GameEngine.applyRiftWeekEnd(year: 5, to: &s, config: c))
        XCTAssertEqual(s.rift, 99.9)
        XCTAssertNil(s.dissolved)
    }

    func testRiftGainFormulaAndSkillAndHeal() {
        var s = riftState(rift: 10, warned: nil, compat: 10)
        _ = GameEngine.applyRiftWeekEnd(year: 3, to: &s, config: cfg)
        XCTAssertEqual(s.rift!, 10 + cfg.riftGain * (cfg.compatCap - 10) / cfg.compatCap, accuracy: 1e-9)

        var k = riftState(rift: 10, warned: nil, compat: 10)
        k.skills = [.相方思い]
        _ = GameEngine.applyRiftWeekEnd(year: 3, to: &k, config: cfg)
        XCTAssertEqual(k.rift! - 10, (s.rift! - 10) * Skill.riftMult, accuracy: 1e-9)

        var h = riftState(rift: 2, warned: nil, compat: 10)
        h.compat = 11     // 週内で相性が上がった
        _ = GameEngine.applyRiftWeekEnd(year: 3, to: &h, config: cfg)
        XCTAssertEqual(h.rift, 0, "癒しは 0 で止まる")
    }

    func testRiftJointWeekStaysStillAndResetsFlag() {
        var s = riftState(rift: 20, warned: nil)
        s.riftJointWeek = true
        _ = GameEngine.applyRiftWeekEnd(year: 3, to: &s, config: cfg)
        XCTAssertEqual(s.rift, 20)
        XCTAssertEqual(s.riftJointWeek, false)
    }

    func testRiftWarnFlagSetAtThreshold() {
        var s = riftState(rift: cfg.riftWarn, warned: nil, compat: cfg.compatCap)   // 相性が上限＝増えない
        _ = GameEngine.applyRiftWeekEnd(year: 3, to: &s, config: cfg)
        XCTAssertEqual(s.riftWarned, true)
        XCTAssertNil(s.dissolved)
    }

    func testRiftYearOneCapAndDissolveNeedsWarning() {
        var s = riftState(rift: 99.9, warned: true)
        XCTAssertFalse(GameEngine.applyRiftWeekEnd(year: 1, to: &s, config: cfg), "1年目は 99 で頭打ち")
        XCTAssertEqual(s.rift, 99)

        var s2 = riftState(rift: 99.9, warned: true)
        XCTAssertTrue(GameEngine.applyRiftWeekEnd(year: 2, to: &s2, config: cfg))
        XCTAssertEqual(s2.dissolved, true)
        XCTAssertEqual(s2.rift, 100, "上限 100")

        // 予告前（warned が false でも）rift>=riftWarn なら同じ週に warned が立つので解散する＝警告フラグは判定の前に立つ
        var s3 = riftState(rift: 99.9, warned: nil)
        XCTAssertTrue(GameEngine.applyRiftWeekEnd(year: 2, to: &s3, config: cfg))
        XCTAssertEqual(s3.riftWarned, true)

        // 低い rift は警告前に解散しない
        var s4 = riftState(rift: 30, warned: nil)
        XCTAssertFalse(GameEngine.applyRiftWeekEnd(year: 9, to: &s4, config: cfg))
    }

    // MARK: runCareer の解散停止

    struct CountingPolicy: WeekPolicy {
        var years = Set<Int>()
        mutating func action(week: Int, year: Int, state: GameState, offer: OfferSpec?) -> WeekAction {
            years.insert(year)
            return offer != nil ? .acceptOffer : .job(.楽)
        }
        mutating func enterTournament(_ spec: TournamentSpec, year: Int, state: GameState) -> Travel? { nil }
    }

    func testRunCareerStopsAtDissolutionOnYearTwo() {
        var s = GameState(config: cfg)
        s.money = 50_000_000
        s.rift = 99.9
        s.riftWarned = true
        var p = CountingPolicy()
        var r = SplitMix64(seed: 11)
        let champ = GameCareer.runCareer(state: &s, years: 5, config: cfg, policy: &p, rng: &r)
        XCTAssertNil(champ)
        XCTAssertEqual(s.dissolved, true)
        XCTAssertEqual(p.years, [1, 2], "2年目の解散で終わり、3年目以降は回らない")
    }

    func testRunYearReportsDissolvedFlag() {
        var s = GameState(config: cfg)
        s.money = 50_000_000
        s.rift = 99.9
        s.riftWarned = true
        var p = CountingPolicy()
        var r = SplitMix64(seed: 11)
        let o = GameCareer.runYear(state: &s, year: 2, config: cfg, policy: &p, rng: &r)
        XCTAssertTrue(o.dissolved)
        XCTAssertFalse(o.bankrupt)
        XCTAssertFalse(o.champion)
    }

    func testYearOutcomeDecodesOldSaveWithoutBankruptOrDissolved() throws {
        let json = #"{"champion":false,"roundsPassed":2,"reachedFinal":true}"#.data(using: .utf8)!
        let o = try JSONDecoder().decode(YearOutcome.self, from: json)
        XCTAssertEqual(o.roundsPassed, 2)
        XCTAssertTrue(o.reachedFinal)
        XCTAssertFalse(o.bankrupt)
        XCTAssertFalse(o.dissolved)
    }

    // MARK: 特技

    func testSkillCostTableAndSummaries() {
        XCTAssertEqual(Skill.allCases.count, 4)
        for k in Skill.allCases {
            XCTAssertFalse(k.summary.isEmpty)
            XCTAssertFalse(k.summary.contains("%") || k.summary.contains("％"))
            XCTAssertFalse(k.cost.isEmpty)
        }
        XCTAssertEqual(Skill.体が資本.cost.map { $0.amount }.reduce(0, +), 7)
        XCTAssertEqual(Skill.愛され芸人.cost.count, 1)
    }

    func testCanLearnBoundaryAndExactCostDeduction() {
        var s = GameState(config: cfg)
        s.exp存在感 = 6 - 1e-12      // 許容誤差内＝足りる
        XCTAssertTrue(GameEngine.canLearn(.愛され芸人, state: s))
        s.exp存在感 = 5.9
        XCTAssertFalse(GameEngine.canLearn(.愛され芸人, state: s))
        XCTAssertFalse(GameEngine.learnSkill(.愛され芸人, to: &s))
        XCTAssertEqual(s.exp存在感, 5.9, "足りない時は何も引かない")
        XCTAssertNil(s.skills)

        s.exp存在感 = 10; s.exp語彙 = 2; s.exp間合い = 9
        XCTAssertTrue(GameEngine.learnSkill(.やりくり上手, to: &s))
        XCTAssertEqual(s.exp語彙, 0, accuracy: 1e-9)
        XCTAssertEqual(s.exp間合い, 5, accuracy: 1e-9)
        XCTAssertEqual(s.exp存在感, 10)
        XCTAssertEqual(s.skills, [.やりくり上手])
        XCTAssertTrue(s.has(.やりくり上手))
        XCTAssertFalse(s.has(.体が資本))
        XCTAssertTrue(GameEngine.learnSkill(.相方思い, to: &s))
        XCTAssertEqual(s.skills, [.やりくり上手, .相方思い], "覚えた順に並ぶ")
    }
}
