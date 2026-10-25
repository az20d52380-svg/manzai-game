// CareerGoldenTests.swift
// 年間進行の完全同期テスト: PythonのSplitMix64と同一乱数列で3年を実行し、週ごとの全状態が一致することを検証する。
// 期待値の再生成: cd tools && python3 gen_golden.py（週処理と乱数消費の順序の正典はそちらのdocstring参照）
// このテストが通れば、大会・グランプリ・オファー・生活費込みの年間ループがPython検証機と同値。

import XCTest
@testable import GameCore

struct GoldenPolicy: WeekPolicy {
    // tools/gen_golden.py の PATTERN と同一（10週周期）
    static let pattern: [WeekAction] = [
        .train(.ネタ作り), .train(.ネタ合わせ), .job(.標準), .rest(.完全休養), .train(.フリーライブ),
        .job(.キツい), .rest(.気分転換), .train(.ネタ見せ会), .job(.楽), .rest(.相方と過ごす),
    ]

    mutating func action(week: Int, year: Int, state: GameState, offer: OfferSpec?) -> WeekAction {
        if offer != nil {
            return .acceptOffer
        }
        return Self.pattern[(week - 1) % Self.pattern.count]
    }

    mutating func enterTournament(_ spec: TournamentSpec, year: Int, state: GameState) -> Travel? {
        .夜行バス   // 常にバスで出場（払えない場合の不参加はエンジン側の責務）
    }
}

final class CareerGoldenTests: XCTestCase {

    // gen_golden.py seed=424243 /【正典v3 2026-08-02・パワプロ式5通貨】準決72 決勝80(人気補正1.5込み) 復活74 / 上限カーブ(6.0,0.4,2.0)累計予算 / ハマ10%+12 / 生活ルール込み / エントリー費2,000 / 前年準々以上は1回戦シード / D=120 / 経験点通貨（稽古→5通貨→recommendedPlan即時全量注ぎ・abilityRecipes重み付きLeontief・供給0.48【仮】）（イベント層はgolden対象外・既定OFF）
    // (year, week, money, stamina, fame, sense, idea, expr, chara, mental, compat)
    static let year1: [(Int, Int, Int, Double, Double, Double, Double, Double, Double, Double, Double)] = [
        (1, 1, 300000, 80.0, 3, 10, 11.254305555555556, 10, 10, 10, 5),
        (1, 2, 300000, 60.0, 3, 10, 11.254305555555556, 10, 10, 10, 6),
        (1, 3, 364000, 40.0, 3, 10, 11.254305555555556, 10, 10, 10, 6),
        (1, 4, 224000, 100, 3, 10, 11.254305555555556, 10, 10, 11.833333333333334, 6),
        (1, 5, 224000, 70, 3.55584375, 10, 11.254305555555556, 10, 11.66986111111111, 11.833333333333334, 6),
        (1, 6, 320000, 40, 3.55584375, 10, 11.254305555555556, 10, 11.66986111111111, 11.833333333333334, 6),
        (1, 7, 320000, 75, 3.55584375, 10, 11.254305555555556, 10, 11.66986111111111, 12.734722222222222, 6),
        (1, 8, 460000, 55, 4.103691471072602, 10, 11.254305555555556, 10, 11.66986111111111, 12.734722222222222, 6),
        (1, 9, 492000, 45, 4.103691471072602, 10, 11.254305555555556, 10, 11.66986111111111, 12.734722222222222, 6),
        (1, 10, 492000, 65, 4.103691471072602, 10, 11.254305555555556, 10, 11.66986111111111, 12.734722222222222, 7),
        (1, 11, 492000, 45, 4.103691471072602, 10, 11.254305555555556, 11.254305555555556, 11.876204232804232, 12.734722222222222, 7),
        (1, 12, 340000, 20, 4.103691471072602, 10, 11.254305555555556, 11.254305555555556, 11.876204232804232, 12.734722222222222, 7),
        (1, 13, 404000, 0, 4.103691471072602, 10, 11.254305555555556, 11.254305555555556, 11.876204232804232, 12.734722222222222, 7),
        (1, 14, 404000, 60, 4.103691471072602, 10, 11.254305555555556, 11.254305555555556, 11.876204232804232, 14.522476851851852, 7),
        (1, 15, 392000, 35, 4.103691471072602, 10, 11.254305555555556, 11.254305555555556, 11.876204232804232, 14.522476851851852, 7),
        (1, 16, 472000, 10, 5.1837382801322525, 10, 11.254305555555556, 11.254305555555556, 11.876204232804232, 14.522476851851852, 7),
        (1, 17, 472000, 45, 5.1837382801322525, 10, 11.254305555555556, 11.254305555555556, 11.876204232804232, 15.401456211419754, 7),
        (1, 18, 392000, 15, 5.1837382801322525, 12.769715583204732, 11.254305555555556, 11.254305555555556, 11.876204232804232, 15.401456211419754, 7),
        (1, 19, 424000, 5, 5.1837382801322525, 12.769715583204732, 11.254305555555556, 11.254305555555556, 11.876204232804232, 15.401456211419754, 7),
        (1, 20, 279000, 15, 5.1837382801322525, 12.769715583204732, 11.254305555555556, 11.254305555555556, 11.876204232804232, 16.273110742991257, 8),
        (1, 21, 279000, 75, 5.1837382801322525, 12.769715583204732, 11.254305555555556, 11.254305555555556, 11.876204232804232, 18.00189223060807, 8),
        (1, 22, 279000, 55, 5.1837382801322525, 12.769715583204732, 11.254305555555556, 11.254305555555556, 11.876204232804232, 18.00189223060807, 9),
        (1, 23, 343000, 35, 5.1837382801322525, 12.769715583204732, 11.254305555555556, 11.254305555555556, 11.876204232804232, 18.00189223060807, 9),
        (1, 24, 203000, 95, 5.1837382801322525, 12.769715583204732, 11.254305555555556, 11.254305555555556, 11.876204232804232, 19.70186069343127, 9),
        (1, 25, 203000, 65, 5.708501375544979, 12.769715583204732, 11.254305555555556, 11.254305555555556, 11.876204232804232, 20.506645395297642, 9),
        (1, 26, 299000, 35, 5.708501375544979, 12.769715583204732, 11.254305555555556, 11.254305555555556, 11.876204232804232, 20.506645395297642, 9),
        (1, 27, 287000, 10, 5.708501375544979, 12.769715583204732, 11.254305555555556, 11.254305555555556, 11.876204232804232, 20.506645395297642, 9),
        (1, 28, 147000, 70, 5.708501375544979, 12.769715583204732, 11.254305555555556, 11.254305555555556, 11.876204232804232, 22.164867972042682, 9),
        (1, 29, 235000, 45, 8.295638922982825, 12.769715583204732, 11.254305555555556, 11.254305555555556, 11.876204232804232, 22.164867972042682, 9),
        (1, 30, 233000, 45, 8.295638922982825, 12.769715583204732, 11.254305555555556, 11.254305555555556, 11.876204232804232, 22.164867972042682, 8.5),
        (1, 31, 333000, 35, 9.259673060007184, 12.769715583204732, 11.254305555555556, 13.066733796296297, 11.876204232804232, 22.164867972042682, 8.5),
        (1, 32, 193000, 15, 9.259673060007184, 12.769715583204732, 11.254305555555556, 13.066733796296297, 11.876204232804232, 22.164867972042682, 9.5),
        (1, 33, 257000, 0, 9.259673060007184, 12.769715583204732, 11.254305555555556, 13.066733796296297, 11.876204232804232, 22.164867972042682, 9.5),
        (1, 34, 257000, 60, 9.259673060007184, 12.769715583204732, 11.254305555555556, 13.066733796296297, 11.876204232804232, 23.79545350584197, 9.5),
        (1, 35, 505000, 60, 11.605388929808939, 12.769715583204732, 11.254305555555556, 13.066733796296297, 11.876204232804232, 23.79545350584197, 9.5),
        (1, 36, 461000, 30, 11.605388929808939, 12.769715583204732, 11.254305555555556, 13.066733796296297, 11.876204232804232, 23.79545350584197, 9.5),
        (1, 37, 461000, 65, 11.605388929808939, 12.769715583204732, 11.254305555555556, 13.066733796296297, 11.876204232804232, 24.597158059959952, 9.5),
        (1, 38, 381000, 35, 11.605388929808939, 12.769715583204732, 11.254305555555556, 13.066733796296297, 11.876204232804232, 25.841860878954414, 9.5),
        (1, 39, 413000, 25, 11.605388929808939, 12.769715583204732, 11.254305555555556, 13.066733796296297, 11.876204232804232, 25.841860878954414, 9.5),
        (1, 40, 273000, 45, 11.605388929808939, 12.769715583204732, 11.254305555555556, 13.066733796296297, 11.876204232804232, 25.841860878954414, 10.5),
        (1, 41, 273000, 25, 11.605388929808939, 12.769715583204732, 12.494308543595679, 13.066733796296297, 12.755578414554064, 25.841860878954414, 10.5),
        (1, 42, 373000, 15, 12.482480709204445, 12.769715583204732, 12.494308543595679, 14.848954899691359, 12.755578414554064, 25.841860878954414, 10.5),
        (1, 43, 437000, 0, 12.482480709204445, 12.769715583204732, 12.494308543595679, 14.848954899691359, 12.755578414554064, 25.841860878954414, 10.5),
        (1, 44, 517000, 0, 13.337221098801248, 12.769715583204732, 12.494308543595679, 14.848954899691359, 12.755578414554064, 25.841860878954414, 10.5),
        (1, 45, 517000, 60, 13.337221098801248, 12.769715583204732, 12.494308543595679, 14.848954899691359, 12.755578414554064, 27.41116319763851, 10.5),
        (1, 46, 515000, 60, 13.337221098801248, 12.769715583204732, 12.494308543595679, 14.848954899691359, 12.755578414554064, 27.41116319763851, 10.5),
        (1, 47, 515000, 95, 13.337221098801248, 12.769715583204732, 12.494308543595679, 14.848954899691359, 12.755578414554064, 28.182736837658187, 10.5),
        (1, 48, 295000, 65, 13.337221098801248, 13.277634289940876, 12.494308543595679, 14.848954899691359, 12.755578414554064, 28.182736837658187, 10.5),
    ]

    // (year, money, stamina, fame, sense, idea, expr, chara, mental, compat) — 年末スナップショット
    static let yearEnds: [(Int, Int, Double, Double, Double, Double, Double, Double, Double, Double)] = [
        (2, 1012000, 25, 27.662217542509527, 16.377033849302656, 16.241758404585514, 20.28846710345416, 13.520542043643546, 44.092800763943934, 15.25),
        (3, 1385000, 45, 35.810060209223906, 18.16779759504881, 19.59225055538847, 27.277118311948826, 16.412614655577773, 55.30890971491562, 19.75),
    ]

    func assertState(_ s: GameState, money: Int, stamina: Double, fame: Double,
                     sense: Double, idea: Double, expr: Double, chara: Double,
                     mental: Double, compat: Double, _ label: String) {
        let acc = 1e-9
        XCTAssertEqual(s.money, money, "\(label) money")
        XCTAssertEqual(s.stamina, stamina, accuracy: acc, "\(label) stamina")
        XCTAssertEqual(s.fame, fame, accuracy: acc, "\(label) fame")
        XCTAssertEqual(s.センス, sense, accuracy: acc, "\(label) センス")
        XCTAssertEqual(s.発想, idea, accuracy: acc, "\(label) 発想")
        XCTAssertEqual(s.表現, expr, accuracy: acc, "\(label) 表現")
        XCTAssertEqual(s.華, chara, accuracy: acc, "\(label) 華")
        XCTAssertEqual(s.メンタル, mental, accuracy: acc, "\(label) メンタル")
        XCTAssertEqual(s.compat, compat, accuracy: acc, "\(label) 相性")
    }

    func testThreeYearsMatchPythonExactly() {
        let config = GameConfig()
        var rng = SplitMix64(seed: 424243)
        var policy = GoldenPolicy()
        var s = GameState(config: config)

        var rowIndex = 0
        let outcome1 = GameCareer.runYear(state: &s, year: 1, config: config, policy: &policy, rng: &rng, inviteSeed: 424243) { week, state in
            guard rowIndex < Self.year1.count else { return }
            let r = Self.year1[rowIndex]
            XCTAssertEqual(week, r.1)
            self.assertState(state, money: r.2, stamina: r.3, fame: r.4, sense: r.5, idea: r.6,
                             expr: r.7, chara: r.8, mental: r.9, compat: r.10, "y1w\(week)")
            rowIndex += 1
        }
        XCTAssertEqual(rowIndex, 48, "48週ぶんの検証が走っていない")
        XCTAssertFalse(outcome1.champion)

        // シード制の配線: 正典生成器(gen_golden.py main)と同じく前年到達回戦を持ち回る。
        // 現goldenでは3年とも非発生(到達2,2,4)だが、配線しないと再生成時に無言でズレる時限爆弾になる（レッドチーム指摘）
        var prevStage = outcome1.roundsPassed
        for expected in Self.yearEnds {
            let outcome = GameCareer.runYear(state: &s, year: expected.0, config: config, policy: &policy, rng: &rng,
                                             gpSeeded: prevStage >= 3, inviteSeed: 424243)
            prevStage = outcome.roundsPassed
            XCTAssertFalse(outcome.champion, "goldenシードでは3年間優勝しない想定")
            assertState(s, money: expected.1, stamina: expected.2, fame: expected.3,
                        sense: expected.4, idea: expected.5, expr: expected.6, chara: expected.7,
                        mental: expected.8, compat: expected.9, "y\(expected.0)end")
        }
    }

    // 分岐 golden（tools/gen_golden.py BRANCH_SCRIPTS・2026-10-19）: 3年台本が通らない 敗者復活 / GPシード(gpSeeded) / 王者シード(seedFinal) / ライン上書き を通す。
    // (seed, year, money, stamina, fame, sense, idea, expr, chara, mental, compat, roundsPassed, champion0/1)
    // 台本A: seed=1・4年とも通常（3年目に敗者復活・4年目は前年到達>=3でシード）
    static let branchA: [(Int, Int, Int, Double, Double, Double, Double, Double, Double, Double, Double, Int, Int)] = [
        (1, 1, -397000, 90, 8.260638993670993, 13.449904932656036, 13.099634137863639, 14.85702510025723, 13.332194364279514, 2.4248990154945176, 11.0, 0, 0),
        (1, 2, -66000, 0, 18.714192949650624, 13.449904932656036, 16.47451234767657, 23.331703157184677, 17.12748819457815, 0, 17.0, 0, 0),
        (1, 3, 499000, 75, 28.37177448474992, 16.656766905003593, 17.845561949385747, 24.291089303689308, 17.12748819457815, 23.91494410413394, 19.875, 4, 0),
        (1, 4, 3789000, 60, 42.33739827258378, 16.656766905003593, 19.11717927101391, 37.726641767110415, 17.12748819457815, 39.09498282383368, 19.75, 3, 0),
    ]
    // 台本B: seed=424243・1年目通常 / 2年目 seedFinal+ライン-999（優勝して即終了）/ 3年目 seedFinal+ライン999（決勝で落ちる）
    static let branchB: [(Int, Int, Int, Double, Double, Double, Double, Double, Double, Double, Double, Int, Int)] = [
        (424243, 1, 295000, 65, 13.337221098801248, 13.277634289940876, 12.494308543595679, 14.848954899691359, 12.755578414554064, 28.182736837658187, 10.5, 0, 0),
        (424243, 2, 6394000, 90, 34.920394961160234, 18.19883517414202, 18.291039475260607, 20.28846710345416, 13.520542043643546, 41.378356406297826, 15.5, 0, 1),
        (424243, 3, 7423000, 40, 41.9590414399111, 19.33166684257791, 20.691632218510286, 30.21235505396111, 15.792285020445266, 49.26928741075736, 19.5, 0, 0),
    ]

    private func runBranch(seed: UInt64, plan: [(Bool, Double?)],
                           expected: [(Int, Int, Int, Double, Double, Double, Double, Double, Double, Double, Double, Int, Int)]) {
        let config = GameConfig()
        var rng = SplitMix64(seed: seed)
        var policy = GoldenPolicy()
        var s = GameState(config: config)
        var prev = 0
        for (i, e) in expected.enumerated() {
            let y = i + 1
            XCTAssertEqual(e.1, y)
            let o = GameCareer.runYear(state: &s, year: y, config: config, policy: &policy, rng: &rng,
                                       seedFinal: plan[i].0, finalLineOverride: plan[i].1,
                                       gpSeeded: prev >= 3, inviteSeed: 424243)
            prev = o.roundsPassed
            XCTAssertEqual(o.roundsPassed, e.11, "seed\(seed) y\(y) roundsPassed")
            XCTAssertEqual(o.champion ? 1 : 0, e.12, "seed\(seed) y\(y) champion")
            assertState(s, money: e.2, stamina: e.3, fame: e.4, sense: e.5, idea: e.6, expr: e.7,
                        chara: e.8, mental: e.9, compat: e.10, "branch seed\(seed) y\(y)")
        }
    }

    func testBranchRevivalAndGpSeed() {
        runBranch(seed: 1, plan: Array(repeating: (false, nil), count: 4), expected: Self.branchA)
    }

    func testBranchSeedFinalAndLineOverride() {
        runBranch(seed: 424243, plan: [(false, nil), (true, -999), (true, 999)], expected: Self.branchB)
    }

    // THE HANA golden（tools/gen_golden.py run_hana_script・2026-10-25・女性コンビだけの大会・既定無効）
    // seed=1191・6年・hanaEnabled=true: 1回戦/2回戦/準決勝で落ちる年と優勝の年（6年目）を全部通る。
    // (seed, year, money, stamina, fame, sense, idea, expr, chara, mental, compat, roundsPassed, champion0/1, hanaPassed0〜4)
    static let hanaYears: [(Int, Int, Int, Double, Double, Double, Double, Double, Double, Double, Double, Int, Int, Int)] = [
        (1191, 1, 909000, 55, 15.584849637280906, 15.378197404378696, 13.390189305732381, 13.397717715498237, 11.877206018518518, 25.147672286515505, 10.5, 0, 0, 0),
        (1191, 2, 982000, 70, 23.855072838496103, 19.189771557151182, 17.229905820887684, 18.096896433695655, 14.23220485660815, 41.77803532311149, 12.0, 1, 0, 1),
        (1191, 3, 1279000, 10, 33.94358540437082, 19.833950098525364, 20.25772339490935, 23.91504076489435, 19.338508001253185, 52.856627489249654, 14.75, 3, 0, 2),
        (1191, 4, 2799000, 0, 42.74098662423498, 20.948586395905902, 22.916882003446492, 36.41174258731042, 21.492256237289965, 60.89942110001317, 16.25, 2, 0, 1),
        (1191, 5, 5370000, 95, 50.578263171695774, 20.948586395905902, 24.679713097444292, 41.84652080011685, 22.792979089063277, 65.43870437249461, 19.75, 3, 0, 1),
        (1191, 6, 9313000, 30, 56.173279716521584, 20.948586395905902, 26.305313190658595, 50.73763093301043, 26.269961112305044, 74.16837994710845, 19.875, 4, 0, 4),
    ]

    func testTheHanaSixYearsMatchPython() {
        let config = GameConfig()
        var rng = SplitMix64(seed: 1191)
        var policy = GoldenPolicy()
        var s = GameState(config: config)
        var prev = 0
        var hanaSeen = Set<Int>()
        for (i, e) in Self.hanaYears.enumerated() {
            let y = i + 1
            XCTAssertEqual(e.1, y)
            let o = GameCareer.runYear(state: &s, year: y, config: config, policy: &policy, rng: &rng,
                                       gpSeeded: prev >= 3, inviteSeed: 424243, hanaEnabled: true)
            prev = o.roundsPassed
            XCTAssertEqual(o.roundsPassed, e.11, "hana y\(y) roundsPassed")
            XCTAssertEqual(o.champion ? 1 : 0, e.12, "hana y\(y) champion")
            XCTAssertEqual(o.hanaPassed, e.13, "hana y\(y) hanaPassed")
            hanaSeen.insert(o.hanaPassed)
            assertState(s, money: e.2, stamina: e.3, fame: e.4, sense: e.5, idea: e.6, expr: e.7,
                        chara: e.8, mental: e.9, compat: e.10, "hana y\(y)")
        }
        XCTAssertTrue(hanaSeen.isSuperset(of: [0, 1, 2, 4]), "1回戦/2回戦/準決勝で落ちる年と優勝の年を通る台本であること")
    }

    // 既定（hanaEnabled=false）では THE HANA の週は何も起きない＝男コンビ・男女コンビは今までと同じ
    func testTheHanaDisabledByDefault() {
        let config = GameConfig()
        var a = GameState(config: config), b = GameState(config: config)
        var ra = SplitMix64(seed: 1191), rb = SplitMix64(seed: 1191)
        var pa = GoldenPolicy(), pb = GoldenPolicy()
        let oa = GameCareer.runYear(state: &a, year: 1, config: config, policy: &pa, rng: &ra, inviteSeed: 424243)
        let ob = GameCareer.runYear(state: &b, year: 1, config: config, policy: &pb, rng: &rb, inviteSeed: 424243, hanaEnabled: false)
        XCTAssertEqual(oa.hanaPassed, 0)
        XCTAssertEqual(a.money, b.money)
        XCTAssertEqual(ra.nextUInt64(), rb.nextUInt64())
        XCTAssertEqual(ob.hanaPassed, 0)
        XCTAssertEqual(config.calendar.hanaRounds.map(\.week), [32, 37, 42, 44])
        for r in config.calendar.hanaRounds {
            XCTAssertNil(config.calendar.tournament(inWeek: r.week), "THE HANA の週に他の大会が無い")
            XCTAssertFalse(config.calendar.gpRounds.contains { $0.week == r.week }, "THE HANA の週に GP の回戦が無い")
        }
    }

    // 中断セーブ：THE HANA の途中（2回戦の前）で保存→復元しても段が続く
    func testTheHanaSnapshotRoundTrip() throws {
        let config = GameConfig()
        var runner = WeekRunner(state: GameState(config: config), year: 3, config: config, rng: SplitMix64(seed: 1191), hanaEnabled: true)
        var policy = GoldenPolicy()
        var phase = runner.begin()
        while runner.week < 33 {
            switch phase {
            case .tournamentDecision(let spec): phase = runner.resolveTournament(travel: policy.enterTournament(spec, year: 3, state: runner.state))
            case .freeAction(let offer): phase = runner.resolveAction(policy.action(week: runner.week, year: 3, state: runner.state, offer: offer))
            case .gpRound, .gpRevival, .gpFinal: phase = runner.resolveAuto()
            case .weekDone: phase = runner.begin()
            case .yearDone: XCTFail("年が終わった"); return
            }
        }
        let data = try JSONEncoder().encode(runner.snapshot())
        let back = WeekRunner(restoring: try JSONDecoder().decode(WeekRunnerSnapshot<SplitMix64>.self, from: data), config: config)
        XCTAssertTrue(back.hanaEnabled)
        XCTAssertEqual(back.hanaPassed, runner.hanaPassed)
        XCTAssertEqual(back.hanaOut, runner.hanaOut)
        XCTAssertEqual(back.hanaNextRound?.name, runner.hanaNextRound?.name)
    }
}
