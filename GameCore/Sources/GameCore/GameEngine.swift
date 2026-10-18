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
        case .currency:
            // 通貨は add() を経由しない（creditCurrency が直接加算・decay/予算/clampを一切通さない・正典v3）。
            // 呼ばれたら設計違反＝実運用では到達しない分岐（applyGrowth が .currency を creditCurrency へ振り分け済み）。
            break
        case .コンビ相性:
            if config.compatGrows {
                // 0012 相性凍結: freeze 中は"増える方向"だけ止める（減算=負は通す＝0019A等の相性-は効く）。
                // ★golden不変: gen_golden はイベント非発火＝compatFreezeWeeks は常に0＝この分岐は恒等 no-op。
                if s.compatFreezeWeeks > 0, amount > 0 {
                    break
                }
                s.compat = clamp(s.compat + amount, 0, config.compatCap)
            }
        case .体力:
            s.stamina = clamp(s.stamina + amount, 0, 100)
        case .知名度:
            // キュー62 案G：その他の伸びは小さく・80に近いほど鈍る（決勝進出・優勝は addFameBig／addFameRaw）。Python: _add_v62
            var amt = amount
            if amt > 0 {
                let d = max(0.0, 1 - s.fame / config.fameOtherCap)
                amt = amt * config.fameOtherMult * (d * d)
                if s.has(.愛され芸人) { amt *= Skill.fameMult }
            }
            s.fame = clamp(s.fame + amt, 0, 100)
        }
    }

    /// 決勝進出の知名度（×(1−知名度/100)）。Python: _fame_big
    public static func addFameBig(_ amount: Double, to s: inout GameState) {
        guard amount > 0 else { return }
        s.fame = clamp(s.fame + amount * (1 - s.fame / 100), 0, 100)
    }

    /// 優勝の知名度（逓減なし）。Python: fame_champ（FAME_CHAMP_FLAT）
    public static func addFameRaw(_ amount: Double, to s: inout GameState) {
        s.fame = clamp(s.fame + amount, 0, 100)
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

    /// 正典v3（パワプロ式5通貨・docs/exp_currency_redesign_v0.md）: 稽古発行の通貨への正の加算 v を
    /// 供給スケールで割り引いて積む。通貨はどの能力にも直接ロックされない（発行側はもう1:1マッピングを持たない）。
    /// balance_sim.credit_currency の鏡像。v<=0 は実運用では発生しない（稽古の main/sub は常に正）。
    static func creditCurrency(_ c: ExpCurrency, _ v: Double, to s: inout GameState, config: GameConfig) {
        guard v > 0 else { return }
        s[currency: c] += v * config.expSupplyScale
    }

    /// Python: do_training。有料稽古は所持金必須【仮】。払えなければ false（呼び出し側でフォールバック）。
    /// 借金中は通貨獲得に debtTrainFactor（正典v2・生活苦）——倍率は通貨の量に掛ける（能力でなく通貨に）。
    /// 正典v3: 通貨の正加算は creditCurrency へ。cost/stamina/fame/相性は従来どおり add 直結。
    /// 稼いだ通貨は行動直後に WeekRunner.applyAllocation（recommendedPlan）で注ぐ（sim_career / gen_golden と同一順序）。
    @discardableResult
    public static func applyTraining(_ t: Training, to s: inout GameState, config: GameConfig) -> Bool {
        guard let spec = config.trainings[t] else { return false }
        if spec.cost > 0 && s.money < spec.cost {
            return false
        }
        let factor: Double? = (s.money < 0) ? config.debtTrainFactor : nil
        s.money -= spec.cost
        // アイテム（Item.swift）：ICレコーダー＝ネタ作りの主効果+、稽古場の年契約＝全稽古の主効果+。未購入（nil）なら恒等＝golden不変
        var mainAmt = spec.main.1
        if t == .ネタ作り, s.hasRecorder == true { mainAmt += config.itemRecorderBonus }
        if s.studioActive == true { mainAmt += config.itemStudioBonus }
        applyGrowth(spec.main.0, factor.map { mainAmt * $0 } ?? mainAmt, to: &s, config: config)
        if let sub = spec.sub {
            applyGrowth(sub.0, factor.map { sub.1 * $0 } ?? sub.1, to: &s, config: config)
        }
        add(.体力, spec.stamina, to: &s, config: config)
        if spec.fame != 0 {
            add(.知名度, spec.fame, to: &s, config: config)
        }
        return true
    }

    /// 稽古の main/sub 効果の適用先分岐: 通貨＝creditCurrency（経済へ）／相性など＝add 直結（経済外）。
    /// balance_sim.do_training の _grow クロージャの鏡像。
    private static func applyGrowth(_ key: StatKey, _ amt: Double, to s: inout GameState, config: GameConfig) {
        if case .currency(let c) = key {
            creditCurrency(c, amt, to: &s, config: config)
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
    public static func applyRest(_ r: Rest, to s: inout GameState, config: GameConfig, useTicket: Bool = true) {
        var r = r
        if let cost = config.restCosts[r], cost > 0 {   // お金を払う休み：払えなければ完全休養（Python do_rest と同じ）
            if s.money < cost { r = .完全休養 } else { s.money -= cost }
        }
        guard let spec = config.rests[r] else { return }
        var recovery = spec.recovery
        if useTicket, let t = s.sentoTickets, t > 0 {           // 銭湯の回数券（Item.swift）。未購入は nil＝恒等
            recovery += config.itemSentoRecovery
            s.sentoTickets = t - 1
        }
        let room = s.room ?? 0
        if room > 0, r == .完全休養 || r == .気分転換, room < config.roomHeals.count { recovery += config.roomHeals[room] }
        add(.体力, recovery, to: &s, config: config)
        add(spec.bonus.0, spec.bonus.1, to: &s, config: config)
        if room >= 2, r == .完全休養 { add(.ability(.メンタル), config.roomBestMental, to: &s, config: config) }
    }

    /// 今の部屋の4週ごとの上乗せ（0=安アパート）
    public static func roomRent(_ s: GameState, config: GameConfig) -> Int {
        let r = s.room ?? 0
        return r > 0 && r < config.roomRents.count ? config.roomRents[r] : 0
    }

    /// 部屋を選び直せるか。下げる・同じ段は常に可。上げる時は1か月分の上乗せ（その部屋の家賃上乗せ）が払える時だけ。
    public static func canMoveRoom(to target: Int, state s: GameState, config: GameConfig) -> Bool {
        guard target >= 0, target < config.roomRents.count else { return false }
        if target <= (s.room ?? 0) { return true }
        return s.money >= config.roomRents[target]
    }

    /// 部屋を選び直す（乱数なし・お金は引かない＝上乗せは次の生活費から）。選べたら true。
    @discardableResult
    /// 月末の支払いの額（生活費・特技「やりくり上手」の割引込み＋部屋の上乗せ）。引き落としと画面の表示の両方がこれを使う。乱数なし
    public static func livingCostDue(_ s: GameState, config: GameConfig) -> Int {
        (s.has(.やりくり上手) ? Int((Double(config.livingCost) * Skill.livingMult).rounded()) : config.livingCost) + roomRent(s, config: config)
    }

    public static func moveRoom(to target: Int, state s: inout GameState, config: GameConfig) -> Bool {
        guard canMoveRoom(to: target, state: s, config: config) else { return false }
        s.room = target == 0 ? nil : target
        return true
    }

    /// Python: do_offer
    /// atWeek（通算週）を渡すとテレビ慣れを判定・記録する（nil=従来どおり何もしない＝エンジン単体テスト用）
    public static func applyOffer(_ o: OfferSpec, to s: inout GameState, config: GameConfig, atWeek: Int? = nil) {
        s.money += o.income
        add(.知名度, o.fame, to: &s, config: config)
        if let ab = o.ability {
            add(.ability(ab.0), ab.1, to: &s, config: config)
        }
        add(.体力, o.stamina, to: &s, config: config)
        if let wk = atWeek {
            if offerFatigued(state: s, atWeek: wk, config: config) {
                add(.ability(.センス), -config.offerFatigueD, to: &s, config: config)
                add(.ability(.表現), -config.offerFatigueD, to: &s, config: config)
            }
            s.offerWeeks = (s.offerWeeks ?? []).filter { wk - $0 < config.offerFatigueWindow } + [wk]
        }
    }

    /// Python: offer_fatigued。次にオファーを受けると腕が落ちるか（テレビ慣れ）
    public static func offerFatigued(state s: GameState, atWeek wk: Int, config: GameConfig) -> Bool {
        (s.offerWeeks ?? []).filter { wk - $0 < config.offerFatigueWindow }.count >= config.offerFatigueK
    }

    /// Python: roll_offer。知名度帯で発生率が決まり、種類は50/50【仮】
    public static func rollOffer<R: RandomSource>(state s: GameState, config: GameConfig, rng: inout R) -> OfferSpec? {
        var rate = 0.0
        for entry in config.offerRates where s.fame < entry.fameBelow {
            rate = entry.rate
            break
        }
        guard rng.nextUniform() < rate else { return nil }
        let isMoney = rng.nextUniform() < 0.5
        let sub = rng.nextUniform() < 0.5 ? 1 : 0          // 名前を決める追加の乱数1回（キュー96）
        return config.offersNamed[(isMoney ? 2 : 0) + sub]
    }

    /// キュー96：追加の札（2枚目以降）。1枚目は本編の乱数（rollOffer）。ここは本編の乱数を消費しない別の決定論
    /// （シード＋年週＋塩のハッシュ→SplitMix64）で、1枚目と違う種類を残りから floor(u×残り数) で引く。Python: sim_career.extra_offers（同値）
    public static func extraOffers(first: OfferSpec, fame: Double, seed: UInt64, year: Int, week: Int, config: GameConfig) -> [OfferSpec] {
        let n = config.offerCardFames.filter { fame >= $0 }.count
        guard n > 0 else { return [] }
        let st = seed &+ UInt64(year * 1000 + week) &* 0xD1B5_4A32_D192_ED03 &+ config.offerCardSalt
        var g = SplitMix64(seed: st)
        var rest = config.offersNamed.filter { $0.name != first.name }
        var out: [OfferSpec] = []
        for _ in 0..<n where !rest.isEmpty {
            let i = min(rest.count - 1, Int(g.nextUniform() * Double(rest.count)))
            out.append(rest.remove(at: i))
        }
        return out
    }

    /// Python: perform。スコア = 実力値 + 相性 + ブレ + ハマった夜 + 体力ペナルティ、ライン以上で通過。
    /// 乱数消費は常に2draw（出来ブレ→ハマ判定）——gen_golden.py の正典順序と同期
    public static func perform<R: RandomSource>(
        _ s: GameState, line: Double, config: GameConfig, rng: inout R
    ) -> (passed: Bool, score: Double, burst: Bool) {
        let b = blurWidth(mental: s.メンタル)
        var roll = rng.uniform(in: -b ... b)
        var burst = false
        if config.burstP > 0, rng.nextUniform() < config.burstP {
            roll += config.burstBonus   // ハマった夜（正典v2・A案）
            burst = true                // 表示専用（「見える運」canonical_v2 §1・fan_report_design §1）。判定・乱数には関与しない
        }
        var penalty = 0.0
        for entry in config.staminaPenalties where s.stamina < entry.below {
            penalty = entry.penalty
            break
        }
        let score = jitsuryoku(s, config: config) + s.compat + roll + penalty
        return (score >= line, score, burst)
    }

    /// ネタのスコア寄与（Phase 1-a・Python: sim_career._neta_bonus ＋ 決勝2本制）。
    /// 戻り値は「本番スコアに足す量」＝呼び出し側で `line` から引く（ラインを下げる＝有利。sim と同じライン調整）。
    /// ★選択中ネタ（`selectedNetaID`）が無ければ **恒等的に 0** を返す＝ネタ未使用は従来の合否のまま。
    ///  golden 生成器（gen_golden.py）はネタ個体を持たない＝`selectedNetaID==nil`＝この項は常に 0＝3年ビット一致は不変。
    ///  perform の乱数消費（2draw）には一切触れない（この関数は RandomSource を受け取らない）。
    public static func netaScoreBonus(_ s: GameState, isFinal: Bool, config: GameConfig) -> Double {
        guard let id = s.selectedNetaID,
              let neta = s.netas.first(where: { $0.id == id }) else { return 0 }
        var bonus = (neta.polish - 50) * config.netaScoreCoefComp
                  + (neta.buzz - 50) * config.netaScoreCoefBuzz
        bonus = max(-config.netaScoreClamp, min(config.netaScoreClamp, bonus))
        bonus -= config.netaTiredPenalty * Double(neta.tiredYears ?? 0)   // 同じネタは飽きられる（キュー60）。Python: _neta_bonus
        if isFinal {
            let second = s.selectedNetaID2.flatMap { sid in s.netas.first(where: { $0.id == sid }) }
            if second == nil || second!.polish < config.netaSecondMinPolish {
                bonus -= config.netaSecondPenalty   // 「2本目が無かった／弱かった」敗因
            }
        }
        return bonus
    }

    /// 途中解散のすれ違いゲージ（週末・生活費と夜逃げ判定の後）。乱数なし。解散なら true。Python: sim_career.rift_weekend
    public static func applyRiftWeekEnd(year: Int, to s: inout GameState, config: GameConfig) -> Bool {
        guard config.riftOn else { return false }
        var r = s.rift ?? 0
        let joint = s.riftJointWeek == true   // §94 この週に二人で舞台に立ったか
        s.riftJointWeek = false
        if s.compat > (s.riftWeekStartCompat ?? s.compat) {
            r = max(0, r - config.riftHeal)
        } else if joint && config.riftJointStill {
            // §94 二人の週はすれ違いがたまらない（増えない・減らない）
        } else {
            var gain = config.riftGain * (config.compatCap - s.compat) / config.compatCap
            if s.has(.相方思い) { gain *= Skill.riftMult }
            r = min(100, r + gain)
        }
        if r >= config.riftWarn && s.riftWarned != true { s.riftWarned = true }
        if year < 2 { r = min(r, 99) }
        s.rift = r
        if r >= 100 && s.riftWarned == true {
            s.dissolved = true
            return true
        }
        return false
    }

    /// §102 飲みの誘いの抽選。本編の乱数（runner の rng）は一切消費しない＝シード＋年週のハッシュで引く別の決定論。
    /// 来なければ nil、来たら「行ったとき発想が付くか」を返す。Python: sim_career.invite_roll（同じ式・同値）
    public static func rollInvite(seed: UInt64, year: Int, week: Int, config: GameConfig) -> Bool? {
        guard config.inviteRate > 0 else { return nil }
        let st = seed &+ UInt64(year * 1000 + week) &* 0xD1B5_4A32_D192_ED03
        var g = SplitMix64(seed: st)
        guard g.nextUniform() < config.inviteRate else { return nil }
        return g.nextUniform() < config.inviteIdeaP
    }

    /// 誘いに「行く」確定効果（断るは何もしない）。Python: sim_career.invite_weekend
    public static func applyInviteGo(idea: Bool, to s: inout GameState, config: GameConfig) {
        s.money -= config.inviteMoney
        add(.体力, config.inviteStamina, to: &s, config: config)
        add(.ability(.メンタル), config.inviteMental, to: &s, config: config)
        if idea { add(.ability(.発想), config.inviteIdea, to: &s, config: config) }
    }

    /// 週末処理（Python: run_year 末尾）。生活費は livingInterval 週ごと。
    /// 正典v2: 所持金<0なら生活苦（体力・メンタル減）、夜逃げライン未満で true（キャリア終了）を返す
    @discardableResult
    public static func applyWeekEnd(week: Int, to s: inout GameState, config: GameConfig) -> Bool {
        if week % config.livingInterval == 0 {
            s.money -= livingCostDue(s, config: config)
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
