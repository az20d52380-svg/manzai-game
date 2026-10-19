// FeatureGoldenTests.swift
// 部屋(§90)・特技(§106)・お店の品の Python⇄Swift 一致テスト（規律A）。
// 期待値は tools/gen_golden_features.py（balance_sim / sim_career の関数をそのまま呼ぶ・乱数なし）が
// Resources/golden_features.json に書く。同じ台本を GameCore で再生して全値比較（Double は 1e-9）。
// 落ちたら「どの台本の何手目のどの値か」がメッセージに出る（どちらが正かは人が判断する）。
// 再生成: cd tools && python3 gen_golden_features.py

import XCTest
@testable import GameCore

final class FeatureGoldenTests: XCTestCase {

    private static let curMap: [(String, ExpCurrency)] = [
        ("hirameki", .閃き), ("goi", .語彙), ("maai", .間合い), ("sonzaikan", .存在感), ("tanryoku", .胆力)
    ]

    private func apply(_ key: String, _ v: Double, to s: inout GameState, config: GameConfig) {
        switch key {
        case "money": s.money = Int(v)
        case "stamina": s.stamina = v
        case "mental": s.メンタル = v
        case "compat": s.compat = v
        case "fame": s.fame = v
        case "rift": s.rift = v
        default:
            if key.hasPrefix("exp_"), let c = Self.curMap.first(where: { "exp_" + $0.0 == key }) { s[currency: c.1] = v }
            else { XCTFail("unknown set key \(key)") }
        }
    }

    private func snap(_ s: GameState) -> [String: Double] {
        var d: [String: Double] = [
            "money": Double(s.money), "stamina": s.stamina, "fame": s.fame, "mental": s.メンタル,
            "compat": s.compat, "rift": s.rift ?? 0, "sento": Double(s.sentoTickets ?? 0),
            "shinkansen": s.shinkansenActive == true ? 1 : 0
        ]
        for (k, c) in Self.curMap { d["exp_" + k] = s[currency: c] }
        return d
    }

    func testFeatureGolden() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Resources/golden_features.json")
        let data = try Data(contentsOf: url)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let scripts = try XCTUnwrap(root["scripts"] as? [[String: Any]])
        XCTAssertGreaterThanOrEqual(scripts.count, 10)
        let config = GameConfig()
        var checked = 0

        for sc in scripts {
            let name = sc["name"] as! String
            let initD = sc["init"] as! [String: Any]
            var s = GameState(config: config)
            for (k, v) in initD {
                switch k {
                case "room": s.room = (v as! Int) == 0 ? nil : (v as! Int)
                case "skills": s.skills = (v as! [String]).compactMap { Skill(rawValue: $0) }
                default: apply(k, (v as! NSNumber).doubleValue, to: &s, config: config)
                }
            }
            let steps = sc["steps"] as! [[String: Any]]
            for (i, st) in steps.enumerated() {
                let op = st["op"] as! [String: Any]
                let o = op["op"] as! String
                var val: Double? = nil
                switch o {
                case "set":
                    for (k, v) in op["v"] as! [String: Any] { apply(k, (v as! NSNumber).doubleValue, to: &s, config: config) }
                case "rest":
                    let r: Rest = ["完全休養": .完全休養, "気分転換": .気分転換, "相方と過ごす": .相方と過ごす][op["name"] as! String]!
                    GameEngine.applyRest(r, to: &s, config: config)
                case "buy":
                    val = GameEngine.buy(ShopItem(rawValue: op["item"] as! String)!, to: &s, config: config) ? 1 : 0
                case "learn":
                    val = GameEngine.learnSkill(Skill(rawValue: op["skill"] as! String)!, to: &s) ? 1 : 0
                case "week_end":
                    _ = GameEngine.applyWeekEnd(week: op["week"] as! Int, to: &s, config: config)
                case "living_due":
                    val = Double(GameEngine.livingCostDue(s, config: config))
                case "new_year":
                    GameEngine.resetYearlyItems(&s)
                case "fame":
                    GameEngine.add(.知名度, (op["amt"] as! NSNumber).doubleValue, to: &s, config: config)
                case "rift":
                    s.riftWeekStartCompat = (op["compat0"] as! NSNumber).doubleValue
                    s.riftJointWeek = (op["joint"] as? Bool) ?? false
                    _ = GameEngine.applyRiftWeekEnd(year: op["year"] as! Int, to: &s, config: config)
                case "injury_prob":
                    // WeekRunner.resolveAction の式と同じ部品（閾値・1点あたり・喉のケア係数・体が資本）
                    val = (config.injuryThreshold - s.stamina) * config.injuryProbPerPoint
                        * GameEngine.injuryProbMultiplier(state: s, config: config) * (s.has(.体が資本) ? Skill.injuryMult : 1.0)
                default: XCTFail("unknown op \(o)")
                }
                let tag = "[\(name) step\(i) \(o)]"
                let exp = st["state"] as! [String: Any]
                let got = snap(s)
                for (k, g) in got {
                    let e = (exp[k] as! NSNumber).doubleValue
                    XCTAssertEqual(g, e, accuracy: 1e-9, "\(tag) \(k): swift=\(g) python=\(e)")
                    checked += 1
                }
                let gSk = (s.skills ?? []).map { $0.rawValue }.sorted()
                XCTAssertEqual(gSk, exp["skills"] as! [String], "\(tag) skills")
                let gCounts = s.itemCounts ?? [:]
                let eCounts = (exp["counts"] as! [String: Any]).mapValues { ($0 as! NSNumber).intValue }
                XCTAssertEqual(gCounts, eCounts, "\(tag) itemCounts")
                if let ev = st["value"] as? NSNumber {
                    XCTAssertEqual(val ?? .nan, ev.doubleValue, accuracy: 1e-9, "\(tag) value: swift=\(String(describing: val)) python=\(ev)")
                } else {
                    XCTAssertNil(val, "\(tag) value should be nil")
                }
            }
        }
        print("FeatureGolden: \(scripts.count) scripts, \(checked) values compared")
    }
    // MARK: 拡張台本（10/19）：ネタの補正・飽き・書く/ライブの伸び／追加の札・テレビ慣れ（期待値は gen_golden_features.py の ext）

    private func loadExt() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Resources/golden_features.json")
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        return try XCTUnwrap(root["ext"] as? [String: Any])
    }
    private func num(_ v: Any?) -> Double { (v as! NSNumber).doubleValue }
    private func mkNeta(_ id: Int, _ d: [String: Any]) -> Neta {
        var n = Neta(id: id, name: "n\(id)", kata: .王道しゃべくり, lengthFit: [.中尺], bornYear: 1)
        n.polish = num(d["comp"]); n.buzz = num(d["buzz"]); n.tiredYears = (d["tired"] as! NSNumber).intValue
        return n
    }

    func testNetaBonusGolden() throws {
        let cases = try XCTUnwrap(try loadExt()["neta_bonus"] as? [[String: Any]])
        let config = GameConfig()
        XCTAssertGreaterThanOrEqual(cases.count, 30)
        for (i, c) in cases.enumerated() {
            var s = GameState(config: config)
            let kind = c["kind"] as! String
            if kind == "bonus" {
                s.netas = [mkNeta(1, c)]; s.selectedNetaID = 1
                let got = GameEngine.netaScoreBonus(s, isFinal: false, config: config)
                XCTAssertEqual(got, num(c["value"]), accuracy: 1e-9, "[bonus case\(i)] \(c)")
            } else {
                let ds = c["netas"] as! [[String: Any]]
                s.netas = ds.enumerated().map { mkNeta($0.offset + 1, $0.element) }
                if let p = c["pick"] as? NSNumber { s.selectedNetaID = p.intValue + 1 }
                if let q = c["second"] as? NSNumber { s.selectedNetaID2 = q.intValue + 1 }
                let got = GameEngine.netaScoreBonus(s, isFinal: true, config: config)
                XCTAssertEqual(got, num(c["value"]), accuracy: 1e-9, "[final case\(i)] \(c)")
            }
        }
    }

    func testNetaGrowGolden() throws {
        let scripts = try XCTUnwrap(try loadExt()["neta_grow"] as? [[String: Any]])
        let config = GameConfig()
        let places: [String: Training] = ["喫茶店で書く": .喫茶店で書く, "ファミレスで書く": .ファミレスで書く]
        for sc in scripts {
            let name = sc["name"] as! String
            var s = GameState(config: config)
            for (k, v) in sc["init"] as! [String: Any] {
                switch k {
                case "sense": s.センス = num(v)
                case "idea": s.発想 = num(v)
                case "expr": s.表現 = num(v)
                case "chara": s.華 = num(v)
                default: XCTFail("unknown init \(k)")
                }
            }
            var r = WeekRunner(state: s, year: 1, config: config, rng: SplitMix64(seed: 1))
            for (i, st) in (sc["steps"] as! [[String: Any]]).enumerated() {
                let tr = st["train"] as! String
                let idx = (st["idx"] as! NSNumber).intValue
                if st["ev"] as! String == "new" {
                    _ = r.applyNetaCreate(kata: .王道しゃべくり, lengthFit: [.中尺], name: "n")
                } else if tr == "ネタ見せ会" || tr == "フリーライブ" {
                    r.applyNetaLive(id: r.state.netas[idx].id, hard: tr == "ネタ見せ会")
                } else if tr == "ネタ作り" {
                    r.applyNetaRevise(id: r.state.netas[idx].id)
                } else {
                    r.applyNetaRevise(id: r.state.netas[idx].id, gain: config.netaPlaceGain[places[tr]!])
                }
                let tag = "[\(name) step\(i) \(tr)]"
                let pol = (st["polish"] as! [NSNumber]).map { $0.doubleValue }
                let buz = (st["buzz"] as! [NSNumber]).map { $0.doubleValue }
                XCTAssertEqual(r.state.netas.count, pol.count, "\(tag) count")
                for (j, n) in r.state.netas.enumerated() where j < pol.count {
                    XCTAssertEqual(n.polish, pol[j], accuracy: 1e-9, "\(tag) polish[\(j)]")
                    XCTAssertEqual(n.buzz, buz[j], accuracy: 1e-9, "\(tag) buzz[\(j)]")
                }
            }
        }
    }

    func testExtraOffersGolden() throws {
        let cases = try XCTUnwrap(try loadExt()["offers"] as? [String: Any])["extra"] as! [[String: Any]]
        let config = GameConfig()
        XCTAssertGreaterThanOrEqual(cases.count, 100)
        for (i, c) in cases.enumerated() {
            let first = try XCTUnwrap(config.offersNamed.first { $0.name == (c["first"] as! String) })
            let seed = try XCTUnwrap(UInt64(c["seed"] as! String))
            let got = GameEngine.extraOffers(first: first, fame: num(c["fame"]), seed: seed,
                                             year: (c["year"] as! NSNumber).intValue, week: (c["week"] as! NSNumber).intValue, config: config)
            let tag = "[extra case\(i) \(c["first"]!) fame\(c["fame"]!) seed\(c["seed"]!)]"
            XCTAssertEqual(got.map { $0.name }, c["names"] as! [String], tag)
            XCTAssertEqual(got.map { Double($0.income) }, (c["income"] as! [NSNumber]).map { $0.doubleValue }, tag)
            XCTAssertEqual(got.map { $0.fame }, (c["gfame"] as! [NSNumber]).map { $0.doubleValue }, tag)
            XCTAssertEqual(got.map { $0.stamina }, (c["stam"] as! [NSNumber]).map { $0.doubleValue }, tag)
        }
    }

    func testOfferFatigueGolden() throws {
        let cases = try XCTUnwrap(try loadExt()["offers"] as? [String: Any])["fatigue"] as! [[String: Any]]
        let config = GameConfig()
        for c in cases {
            let name = c["name"] as! String
            let spec = try XCTUnwrap(config.offersNamed.first { $0.name == (c["offer"] as! String) })
            var s = GameState(config: config)
            s.fame = num(c["fame0"]); s.money = 1000
            for (i, st) in (c["steps"] as! [[String: Any]]).enumerated() {
                GameEngine.applyOffer(spec, to: &s, config: config, atWeek: (st["wk"] as! NSNumber).intValue)
                let tag = "[\(name) step\(i)]"
                XCTAssertEqual(Double(s.money), num(st["money"]), accuracy: 1e-9, "\(tag) money")
                XCTAssertEqual(s.fame, num(st["fame"]), accuracy: 1e-9, "\(tag) fame")
                XCTAssertEqual(s.stamina, num(st["stamina"]), accuracy: 1e-9, "\(tag) stamina")
                XCTAssertEqual(s.センス, num(st["sense"]), accuracy: 1e-9, "\(tag) sense")
                XCTAssertEqual(s.表現, num(st["expr"]), accuracy: 1e-9, "\(tag) expr")
                XCTAssertEqual(s.offerWeeks ?? [], (st["weeks"] as! [NSNumber]).map { $0.intValue }, "\(tag) offerWeeks")
            }
        }
    }

    /// 選択イベントの効果：同じ開始状態に、sim の方針が選ぶ側の effects を applyEventEffect で当てた結果が Python（EVENTS_APP=True）と一致
    func testEventEffectsGolden() throws {
        let cases = try XCTUnwrap(try loadExt()["event_effects"] as? [[String: Any]])
        let config = GameConfig()
        XCTAssertGreaterThanOrEqual(cases.count, 80)
        var kinds = Set<String>()
        for (i, c) in cases.enumerated() {
            let kindName = c["kind"] as! String
            let side = c["side"] as! String
            let kind = try XCTUnwrap(ChoiceEventKind(rawValue: kindName), "unknown kind \(kindName)")
            let ini = c["init"] as! [String: Any]
            var s = GameState(config: config)
            s.センス = num(ini["sense"]); s.発想 = num(ini["idea"]); s.表現 = num(ini["expr"]); s.華 = num(ini["chara"])
            s.メンタル = num(ini["mental"]); s.stamina = num(ini["stamina"]); s.money = Int(num(ini["money"]))
            s.compat = num(ini["compat"]); s.fame = num(ini["fame"])
            let choice = try XCTUnwrap(ChoiceEventTable.choices(for: kind, config: config).first { $0.id == side }, "no choice \(side)")
            XCTAssertTrue(choice.gate(s), "[event case\(i) \(c["key"]!) \(c["state"]!)] gate closed for side \(side)")
            for e in choice.effects { s.applyEventEffect(e, config: config) }
            let p = c["post"] as! [String: Any]
            let tag = "[event case\(i) \(c["key"]!)/\(kindName) \(side) \(c["state"]!)]"
            XCTAssertEqual(s.センス, num(p["sense"]), accuracy: 1e-9, "\(tag) sense")
            XCTAssertEqual(s.発想, num(p["idea"]), accuracy: 1e-9, "\(tag) idea")
            XCTAssertEqual(s.表現, num(p["expr"]), accuracy: 1e-9, "\(tag) expr")
            XCTAssertEqual(s.華, num(p["chara"]), accuracy: 1e-9, "\(tag) chara")
            XCTAssertEqual(s.メンタル, num(p["mental"]), accuracy: 1e-9, "\(tag) mental")
            XCTAssertEqual(s.stamina, num(p["stamina"]), accuracy: 1e-9, "\(tag) stamina")
            XCTAssertEqual(Double(s.money), num(p["money"]), accuracy: 1e-9, "\(tag) money")
            XCTAssertEqual(s.compat, num(p["compat"]), accuracy: 1e-9, "\(tag) compat")
            XCTAssertEqual(s.fame, num(p["fame"]), accuracy: 1e-9, "\(tag) fame")
            XCTAssertEqual(s.netaBoostWeeks, (c["neta_boost"] as! NSNumber).intValue, "\(tag) netaBoost")
            XCTAssertEqual(s.preoccupiedWeeks, (c["preocc"] as! NSNumber).intValue, "\(tag) preoccupied")
            kinds.insert(kindName)
        }
        XCTAssertEqual(kinds.count, 29, "守ったイベント数")
    }

    // MARK: 体調ダウン（乱数の抽選）×喉のケア用品×特技「体が資本」（10/19・docs/golden_injury_1019_v0.md）
    // 体力を低く保つ台本で乱数込みの1年（大会・GP・オファー・誘い込み）を回し、週ごとの全状態と体調ダウン回数を Python（gen_golden.run_year）と比べる。

    private struct InjuryPolicy: WeekPolicy {
        // tools/gen_golden_features.py の INJURY_PATTERN と同一（9週周期）
        static let pattern: [WeekAction] = [
            .train(.ネタ作り), .train(.ネタ合わせ), .train(.フリーライブ), .job(.キツい), .train(.ネタ見せ会),
            .job(.キツい), .train(.ネタ作り), .job(.キツい), .rest(.完全休養),
        ]
        mutating func action(week: Int, year: Int, state: GameState, offer: OfferSpec?) -> WeekAction {
            offer != nil ? .acceptOffer : Self.pattern[(week - 1) % Self.pattern.count]
        }
        mutating func enterTournament(_ spec: TournamentSpec, year: Int, state: GameState) -> Travel? { .夜行バス }
    }

    func testInjuryDrawGolden() throws {
        let scripts = try XCTUnwrap(try loadExt()["injury"] as? [[String: Any]])
        XCTAssertEqual(scripts.count, 8)
        let config = GameConfig()
        var distinctCounts = Set<Int>()
        for sc in scripts {
            let name = sc["name"] as! String
            var s = GameState(config: config)
            if sc["skill"] as! Bool { s.skills = [.体が資本] }
            var runner = WeekRunner(state: s, year: 1, config: config, rng: SplitMix64(seed: UInt64(sc["seed"] as! String)!), inviteSeed: 424243)
            if sc["item"] as! Bool { XCTAssertTrue(runner.applyItemPurchase(.喉のケア用品), "\(name) 購入") }   // 年初リセットの後・1週目の前
            var policy = InjuryPolicy()
            let weeks = sc["weeks"] as! [[NSNumber]]
            var idx = 0, injuries = 0
            var phase = runner.begin()
            loop: while true {
                switch phase {
                case .tournamentDecision(let spec):
                    phase = runner.resolveTournament(travel: policy.enterTournament(spec, year: 1, state: runner.state))
                case .freeAction(let offer):
                    phase = runner.resolveAction(policy.action(week: runner.week, year: 1, state: runner.state, offer: offer))
                case .gpRound, .gpRevival, .gpFinal:
                    phase = runner.resolveAuto()
                case .weekDone(let summary):
                    if runner.pendingInvite != nil { runner.resolveInvite(accept: policy.acceptInvite(state: runner.state)) }
                    injuries += summary.results.filter { $0.name == "体調ダウン" }.count
                    let e = weeks[idx].map { $0.doubleValue }, g = runner.state, tag = "[\(name) w\(idx + 1)]"
                    XCTAssertEqual(g.money, Int(e[0]), "\(tag) money")
                    let got = [g.stamina, g.fame, g.センス, g.発想, g.表現, g.華, g.メンタル, g.compat]
                    for (k, label) in ["stamina", "fame", "センス", "発想", "表現", "華", "メンタル", "compat"].enumerated() {
                        XCTAssertEqual(got[k], e[k + 1], accuracy: 1e-9, "\(tag) \(label)")
                    }
                    idx += 1
                    phase = runner.begin()
                case .yearDone:
                    break loop
                }
            }
            XCTAssertEqual(idx, 48, "\(name) 週数")
            XCTAssertEqual(injuries, (sc["injuries"] as! NSNumber).intValue, "\(name) 体調ダウン回数")
            distinctCounts.insert(injuries)
        }
        XCTAssertGreaterThanOrEqual(distinctCounts.count, 3, "用品・特技で抽選結果が変わる台本であること")
    }
}
