// AllocationTests.swift
// 割り振り（Allocation.swift）の同値性・会計則の単体保証（docs/exp_abilityup_impl_reply_v0.md）。
// 核は testProjectedGainMatchesAdd: 見積もり純関数が add()（①逓減→②予算→③clamp）と全分岐で
// 厳密一致すること＝UI見積もり・確定・sim較正の3所が食い違わないことの担保。
// これらは golden（3年ビット一致）とは独立の追加テスト——既存 golden には一切触れない。

import XCTest
@testable import GameCore

final class AllocationTests: XCTestCase {

    /// projectedGain == add() の見える伸び。逓減あり/なし・予算 nil/満杯/残りわずか/十分・
    /// cap際・メンタル（予算除外）の全グリッドで厳密一致（同一式・同一演算順なのでビット一致を要求）
    func testProjectedGainMatchesAdd() {
        var config = GameConfig()
        let values: [Double] = [0, 10, 60, 115, 119.5, 120]
        let budgets: [Double?] = [nil, 0, 0.05, 6]
        let amounts: [Double] = [0.4, 1, 5]
        for decay in [config.growthDecayD, nil] {
            config.growthDecayD = decay
            for a in Ability.allCases {
                for v in values {
                    for b in budgets {
                        for amt in amounts {
                            var s = GameState(config: config)
                            s[a] = min(v, a == .メンタル ? config.mentalCap : config.abilityCap)
                            s.growthBudget = b
                            s.growthUsed = 1.0   // b=0 のとき remaining<0 の分岐も踏む
                            let projected = GameEngine.projectedGain(a, amount: amt, state: s, config: config)
                            var applied = s
                            GameEngine.add(.ability(a), amt, to: &applied, config: config)
                            XCTAssertEqual(projected, applied[a] - s[a],
                                           "projectedGain が add() とずれた: \(a) v=\(v) budget=\(String(describing: b)) amt=\(amt) decay=\(String(describing: decay))")
                        }
                    }
                }
            }
        }
    }

    /// 支払いは同色ロック→共通枠の固定順。ロックが先に空き、不足分だけ共通枠から出る
    func testPourStepPaysLockedFirst() {
        let config = GameConfig()   // allocationStep = 1.0
        var s = GameState(config: config)
        s.growthBudget = nil        // 予算の影響を切って支払い順だけ見る
        s.expセンス = 0.4
        s.expネタ = 10
        let gain = GameEngine.pourStep(.センス, to: &s, config: config)
        XCTAssertGreaterThan(gain, 0)
        XCTAssertEqual(s.expセンス, 0, accuracy: 1e-12, "同色ロックが先に空く")
        XCTAssertEqual(s.expネタ, 9.4, accuracy: 1e-12, "不足分 0.6 だけ共通枠から")
    }

    /// ゼロ利得段は粒を消費しない（余剰許容: 器が満ちたら残高・能力・帳簿とも一切動かない）
    func testPourStepRefusesWhenBudgetFull() {
        let config = GameConfig()
        var s = GameState(config: config)
        s.growthBudget = 6
        s.growthUsed = 6            // 器が満ちている
        s.exp発想 = 3
        s.expネタ = 2
        let before = s
        let gain = GameEngine.pourStep(.発想, to: &s, config: config)
        XCTAssertEqual(gain, 0)
        XCTAssertEqual(s.exp発想, before.exp発想, "粒は減らない")
        XCTAssertEqual(s.expネタ, before.expネタ)
        XCTAssertEqual(s.発想, before.発想, "能力も動かない")
        XCTAssertEqual(s.growthUsed, before.growthUsed, "帳簿も動かない")
    }

    /// メンタルは共通枠から払えない（同色のみ＝予算外の能力へ新しい供給路を作らない・安全条件）
    func testMentalHasNoFreeRoute() {
        let config = GameConfig()
        var s = GameState(config: config)
        s.expネタ = 5
        s.exp舞台 = 5
        let gain = GameEngine.pourStep(.メンタル, to: &s, config: config)
        XCTAssertEqual(gain, 0)
        XCTAssertEqual(s.メンタル, GameState(config: config).メンタル)
        XCTAssertEqual(s.expネタ, 5)
        XCTAssertEqual(s.exp舞台, 5)
        // 同色ロックからは注げる（メンタルは予算②を通らない＝器は動かない）
        s.expメンタル = 2
        let used = s.growthUsed
        let g2 = GameEngine.pourStep(.メンタル, to: &s, config: config)
        XCTAssertGreaterThan(g2, 0)
        XCTAssertEqual(s.growthUsed, used, "メンタル注入は器を消費しない")
    }

    /// 段刻みループは一括 add() を決して上回らない（貯め込みの1点評価上振れが構造的に消えている）
    func testStepLoopNeverExceedsSingleShot() {
        let config = GameConfig()
        var single = GameState(config: config)
        single.growthBudget = 100   // 予算で切られない条件で逓減複利だけを見る
        GameEngine.add(.ability(.発想), 6, to: &single, config: config)

        var looped = GameState(config: config)
        looped.growthBudget = 100
        looped.exp発想 = 6
        while GameEngine.pourStep(.発想, to: &looped, config: config) > 0 {}
        XCTAssertLessThanOrEqual(looped.発想, single.発想, "段刻みが一括評価を上回ったら1点評価ガードが壊れている")
        XCTAssertGreaterThan(looped.発想, GameState(config: config).発想, "注げてはいる")
    }

    /// 同じタップ列の再生は常に同じ結果（プレビュー=確定のリプレイ決定論・RNG非消費）
    func testReplayDeterminism() {
        let config = GameConfig()
        var base = GameState(config: config)
        base.growthBudget = 6
        base.expセンス = 2; base.exp表現 = 3; base.expネタ = 4; base.exp舞台 = 1; base.expメンタル = 2
        let taps: [Ability] = [.センス, .表現, .発想, .メンタル, .センス, .華, .発想]
        var a = base, b = base
        for t in taps { GameEngine.pourStep(t, to: &a, config: config) }
        for t in taps { GameEngine.pourStep(t, to: &b, config: config) }
        let enc = JSONEncoder()
        enc.outputFormatting = .sortedKeys
        XCTAssertEqual(try? enc.encode(a), try? enc.encode(b), "同一タップ列の再生が非決定的")
    }

    /// おすすめ注ぎ: 決定論・注げる粒を残さない（器と上限が許す限り）・共通枠は低い方を先に
    func testRecommendedPlanIsDeterministicAndDrains() {
        let config = GameConfig()
        var s = GameState(config: config)
        s.growthBudget = 100
        s.センス = 40; s.発想 = 10   // 発想が低い→ネタ共通粒は発想へ向かうはず
        s.expセンス = 1; s.exp発想 = 1; s.expネタ = 3
        let plan1 = GameEngine.recommendedPlan(state: s, config: config)
        let plan2 = GameEngine.recommendedPlan(state: s, config: config)
        XCTAssertEqual(plan1, plan2, "おすすめ注ぎが非決定的")
        var after = s
        for t in plan1 { GameEngine.pourStep(t, to: &after, config: config) }
        XCTAssertLessThan(after.expTotal, GameEngine.pourEpsilon + 0.001, "器が十分なら注げる粒を残さない")
        let freeTaps = plan1.filter { $0 == .発想 }.count
        XCTAssertGreaterThan(freeTaps, plan1.filter { $0 == .センス }.count, "共通枠は低い方（発想）へ多く向かう")
    }
}
