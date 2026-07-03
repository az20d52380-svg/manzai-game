// GameEngine.swift
// 週次の行動と数式。tools/balance_sim.py（＋成長逓減 exp_decay.py）と厳密に同値であること。
// 同値性は Tests/GameCoreTests/GoldenTests.swift（Python から生成した期待値）で担保する（CLAUDE.mdルール5）。

public enum GameEngine {

    static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        max(lo, min(hi, v))
    }

    /// Python: add(s, key, amt)。能力5種は成長逓減 ×(1−現在値/D) を正の上昇にのみ適用してから 0〜100 にクランプ
    public static func add(_ key: StatKey, _ amount: Double, to s: inout GameState, config: GameConfig) {
        switch key {
        case .ability(let a):
            var amt = amount
            if let d = config.growthDecayD, amount > 0 {
                amt = amount * max(0, 1 - s[a] / d)
            }
            let cap = (a == .メンタル) ? config.mentalCap : config.abilityCap
            s[a] = clamp(s[a] + amt, 0, cap)
        case .コンビ相性:
            if config.compatGrows {
                s.compat = clamp(s.compat + amount, 0, config.compatCap)
            }
        case .体力:
            s.stamina = clamp(s.stamina + amount, 0, 100)
        case .知名度:
            s.fame = clamp(s.fame + amount, 0, 100)
        }
    }

    /// Python: jitsuryoku(s)
    public static func jitsuryoku(_ s: GameState, config: GameConfig) -> Double {
        s.センス * config.weightSense + s.発想 * config.weightIdea
            + s.表現 * config.weightExpr + s.華 * config.weightChara
    }

    /// Python: blur_width(mental)。ブレ幅B = 5 + 15×(1−メンタル/100)
    public static func blurWidth(mental: Double) -> Double {
        5 + 15 * (1 - mental / 100)
    }

    /// Python: do_training。有料稽古は所持金必須【仮】。払えなければ false（呼び出し側でフォールバック）
    @discardableResult
    public static func applyTraining(_ t: Training, to s: inout GameState, config: GameConfig) -> Bool {
        guard let spec = config.trainings[t] else { return false }
        if spec.cost > 0 && s.money < spec.cost {
            return false
        }
        s.money -= spec.cost
        add(spec.main.0, spec.main.1, to: &s, config: config)
        if let sub = spec.sub {
            add(sub.0, sub.1, to: &s, config: config)
        }
        add(.体力, spec.stamina, to: &s, config: config)
        if spec.fame != 0 {
            add(.知名度, spec.fame, to: &s, config: config)
        }
        return true
    }

    /// Python: do_job
    public static func applyJob(_ j: Job, to s: inout GameState, config: GameConfig) {
        guard let spec = config.jobs[j] else { return }
        s.money += spec.income
        add(.体力, spec.stamina, to: &s, config: config)
    }

    /// Python: do_rest
    public static func applyRest(_ r: Rest, to s: inout GameState, config: GameConfig) {
        guard let spec = config.rests[r] else { return }
        add(.体力, spec.recovery, to: &s, config: config)
        add(spec.bonus.0, spec.bonus.1, to: &s, config: config)
    }

    /// Python: do_offer
    public static func applyOffer(_ o: OfferSpec, to s: inout GameState, config: GameConfig) {
        s.money += o.income
        add(.知名度, o.fame, to: &s, config: config)
        if let ab = o.ability {
            add(.ability(ab.0), ab.1, to: &s, config: config)
        }
        add(.体力, o.stamina, to: &s, config: config)
    }

    /// Python: roll_offer。知名度帯で発生率が決まり、種類は50/50【仮】
    public static func rollOffer<R: RandomSource>(state s: GameState, config: GameConfig, rng: inout R) -> OfferSpec? {
        var rate = 0.0
        for entry in config.offerRates where s.fame < entry.fameBelow {
            rate = entry.rate
            break
        }
        guard rng.nextUniform() < rate else { return nil }
        return rng.nextUniform() < 0.5 ? config.offerMoney : config.offerExp
    }

    /// Python: perform。スコア = 実力値 + 相性 + ブレ + 体力ペナルティ、ライン以上で通過
    public static func perform<R: RandomSource>(
        _ s: GameState, line: Double, config: GameConfig, rng: inout R
    ) -> (passed: Bool, score: Double) {
        let b = blurWidth(mental: s.メンタル)
        let roll = rng.uniform(in: -b ... b)
        var penalty = 0.0
        for entry in config.staminaPenalties where s.stamina < entry.below {
            penalty = entry.penalty
            break
        }
        let score = jitsuryoku(s, config: config) + s.compat + roll + penalty
        return (score >= line, score)
    }

    /// 週末処理（Python: run_one 末尾）。生活費は livingInterval 週ごと。マイナスOK・ペナルティなし＝仕様どおり
    public static func applyWeekEnd(week: Int, to s: inout GameState, config: GameConfig) {
        if week % config.livingInterval == 0 {
            s.money -= config.livingCost
        }
    }
}
