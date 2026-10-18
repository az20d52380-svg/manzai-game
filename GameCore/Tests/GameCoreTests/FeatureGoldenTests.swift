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
}
