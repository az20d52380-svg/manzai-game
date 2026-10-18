// Skill.swift
// 特技（キュー106・規律A・docs/balance_q93_98_measure_v0.md §106）：余った経験点の使い道。
// 各1回きり・覚えたらずっと効く。費用は内部の単位（画面では ExpDisplay で×10）。能力の伸びの式は触らない。
// 乱数は一切引かない（覚えるのは純関数・効果は係数だけ）。ボット（golden台本）は覚えない＝skills が nil/空＝今と同じ。
// Python: balance_sim.SKILL_COST / learn_skill / has_skill。

public enum Skill: String, CaseIterable, Codable {
    case 体が資本
    case 愛され芸人
    case やりくり上手
    case 相方思い

    /// 費用（内部の単位）
    public var cost: [(currency: ExpCurrency, amount: Double)] {
        switch self {
        case .体が資本:     return [(.胆力, 4), (.存在感, 3)]
        case .愛され芸人:   return [(.存在感, 6)]
        case .やりくり上手: return [(.語彙, 2), (.間合い, 4)]
        case .相方思い:     return [(.存在感, 3), (.間合い, 4)]
        }
    }

    /// 効果の説明（短く・％は出さない）
    public var summary: String {
        switch self {
        case .体が資本:     return "体調を崩しにくくなる"
        case .愛され芸人:   return "知名度が少し伸びやすくなる"
        case .やりくり上手: return "月末の生活費が少し安くなる"
        case .相方思い:     return "相方とのすれ違いが増えにくくなる"
        }
    }

    public static let injuryMult = 0.7     // 体調ダウンの確率
    public static let fameMult = 1.1       // 知名度の伸び（正の増分だけ）
    public static let livingMult = 0.95    // 月末の生活費
    public static let riftMult = 0.8       // すれ違いの増え（増えた週だけ）
}

extension GameState {
    public func has(_ k: Skill) -> Bool { skills?.contains(k) ?? false }
}

extension GameEngine {
    /// 足りるか（まだ覚えていなくて、全通貨が費用以上）
    public static func canLearn(_ k: Skill, state s: GameState) -> Bool {
        !s.has(k) && k.cost.allSatisfy { s[currency: $0.currency] >= $0.amount - 1e-9 }
    }

    /// 特技を覚える（足りる時だけ費用を引く・乱数非消費）。覚えたら true。Python: balance_sim.learn_skill
    @discardableResult
    public static func learnSkill(_ k: Skill, to s: inout GameState) -> Bool {
        guard canLearn(k, state: s) else { return false }
        for c in k.cost { s[currency: c.currency] -= c.amount }
        s.skills = (s.skills ?? []) + [k]
        return true
    }
}
