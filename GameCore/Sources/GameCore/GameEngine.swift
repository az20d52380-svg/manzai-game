// GameEngine.swift
// 週次の行動と数式。tools/balance_sim.py（＋成長逓減 exp_decay.py）と厳密に同値であること。
// 同値性は Tests/GameCoreTests/GoldenTests.swift（Python から生成した期待値）で担保する（CLAUDE.mdルール5）。

public enum GameEngine {

    static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        max(lo, min(hi, v))
    }

    /// 演技系4能力の実力値重み（Python: add() の重み辞書と同期）
    static func weight(of a: Ability, config: GameConfig) -> Double {
        switch a {
        case .センス: return config.weightSense
        case .発想: return config.weightIdea
        case .表現: return config.weightExpr
        case .華: return config.weightChara
        case .メンタル: return 0
        }
    }

    /// Python: add(s, key, amt)。能力5種は成長逓減 ×(1−現在値/D) を正の上昇にのみ適用し、
    /// 演技系4能力はさらに成長予算（キャリア累計・正典v2）で頭打ちにしてから 0〜上限 にクランプ
    public static func add(_ key: StatKey, _ amount: Double, to s: inout GameState, config: GameConfig) {
        switch key {
        case .ability(let a):
            var amt = amount
            if let d = config.growthDecayD, amount > 0 {
                amt = amount * max(0, 1 - s[a] / d)
            }
            if let budget = s.growthBudget, amt > 0, a != .メンタル {
                let w = weight(of: a, config: config)
                let remaining = budget - s.growthUsed
                amt = max(0, min(amt, remaining / w))
                s.growthUsed += amt * w
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

    /// 会計移設（規律A第1段・docs/exp_abilityup_impl_reply_v0.md）: 稽古発行の能力への正の上昇 v を
    /// 二区画クレジットへ置換（add 直結の代わり）。ロック側 += v×(1−ρ)／所属枠 += v×ρ。メンタルは枠なし＝100%ロック。
    /// balance_sim.credit_training の鏡像。負・ゼロは経済外＝直add（実運用では稽古の main/sub は常に正）。
    static func creditTraining(_ a: Ability, _ v: Double, to s: inout GameState, config: GameConfig) {
        guard v > 0 else { add(.ability(a), v, to: &s, config: config); return }
        let g0 = v * config.expSupplyScale   // 供給スケール（§4-2ゲート3・帯順序の復元ツマミ）
        if let g = ExpGroup.of(a) {
            s[bank: a] += g0 * (1 - config.expFreeShare)
            s[free: g] += g0 * config.expFreeShare
        } else {
            s[bank: a] += g0   // メンタル: 100%ロック
        }
    }

    /// Python: do_training。有料稽古は所持金必須【仮】。払えなければ false（呼び出し側でフォールバック）。
    /// 借金中は能力上昇に debtTrainFactor（正典v2・生活苦）——倍率は粒の量に掛ける（能力でなく粒に）。
    /// 会計移設: 能力の正加算は creditTraining（二区画クレジット）へ。cost/stamina/fame/相性は従来どおり add 直結。
    /// 稼いだ粒は行動直後に WeekRunner.applyAllocation（recommendedPlan）で注ぐ（sim_career / gen_golden と同一順序）。
    @discardableResult
    public static func applyTraining(_ t: Training, to s: inout GameState, config: GameConfig) -> Bool {
        guard let spec = config.trainings[t] else { return false }
        if spec.cost > 0 && s.money < spec.cost {
            return false
        }
        let factor: Double? = (s.money < 0) ? config.debtTrainFactor : nil
        s.money -= spec.cost
        applyGrowth(spec.main.0, factor.map { spec.main.1 * $0 } ?? spec.main.1, to: &s, config: config)
        if let sub = spec.sub {
            applyGrowth(sub.0, factor.map { sub.1 * $0 } ?? sub.1, to: &s, config: config)
        }
        add(.体力, spec.stamina, to: &s, config: config)
        if spec.fame != 0 {
            add(.知名度, spec.fame, to: &s, config: config)
        }
        return true
    }

    /// 稽古の main/sub 効果の適用先分岐: 能力＝二区画クレジット（経済へ）／相性など＝add 直結（経済外）。
    /// balance_sim.do_training の _grow クロージャの鏡像。
    private static func applyGrowth(_ key: StatKey, _ amt: Double, to s: inout GameState, config: GameConfig) {
        if case .ability(let a) = key {
            creditTraining(a, amt, to: &s, config: config)
        } else {
            add(key, amt, to: &s, config: config)
        }
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

    /// Python: perform。スコア = 実力値 + 相性 + ブレ + ハマった夜 + 体力ペナルティ、ライン以上で通過。
    /// 乱数消費は常に2draw（出来ブレ→ハマ判定）——gen_golden.py の正典順序と同期
    public static func perform<R: RandomSource>(
        _ s: GameState, line: Double, config: GameConfig, rng: inout R
    ) -> (passed: Bool, score: Double) {
        let b = blurWidth(mental: s.メンタル)
        var roll = rng.uniform(in: -b ... b)
        if config.burstP > 0, rng.nextUniform() < config.burstP {
            roll += config.burstBonus   // ハマった夜（正典v2・A案）
        }
        var penalty = 0.0
        for entry in config.staminaPenalties where s.stamina < entry.below {
            penalty = entry.penalty
            break
        }
        let score = jitsuryoku(s, config: config) + s.compat + roll + penalty
        return (score >= line, score)
    }

    /// 週末処理（Python: run_year 末尾）。生活費は livingInterval 週ごと。
    /// 正典v2: 所持金<0なら生活苦（体力・メンタル減）、夜逃げライン未満で true（キャリア終了）を返す
    @discardableResult
    public static func applyWeekEnd(week: Int, to s: inout GameState, config: GameConfig) -> Bool {
        if week % config.livingInterval == 0 {
            s.money -= config.livingCost
            if s.money < 0 {
                add(.体力, config.debtLifeStamina, to: &s, config: config)
                add(.ability(.メンタル), config.debtLifeMental, to: &s, config: config)
            }
            if s.money < config.bankruptLine {
                s.bankrupt = true
                return true
            }
        }
        return false
    }
}
