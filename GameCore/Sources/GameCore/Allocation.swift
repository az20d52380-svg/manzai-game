// Allocation.swift
// 経験点残高（GameState.exp*）→ 能力への注入（割り振り）。正典v3: docs/exp_currency_redesign_v0.md
// （パワプロ式5通貨・オーナー指示2026-08-02「経験値はパワーそのままじゃない。筋力技術などで振り分けて
// 能力アップする」への対応）。旧・同色ロック+共通枠2グループ方式（docs/exp_abilityup_impl_reply_v0.md）を置換。
// 会計の二層は不変（0040追補・GO確定）: 稼ぐ時は予算非消費で通貨が貯まり／注ぐ瞬間だけ既存 GameEngine.add()
// （①逓減→②割り振り時予算→③clamp・位置と順序は不変）を通す。発行ゲート（逓減前の生値で予算消費）はNO-GO確定＝禁止。
// このファイルは「注ぐ側」のみ。発行側（稽古→通貨への積み上げ）は GameEngine.creditCurrency。
// RandomSource を一切呼ばない＝乱数消費順は不変（applyEventEffects と同じ規律）。
// Python鏡像: tools/balance_sim.py に projected_gain / pour_step / recommended_plan を同値実装する（ルール5）。
// 数値は全て【仮】（abilityRecipes / allocationStep / expSupplyScale は GameConfig 集約・sim較正で確定）。

extension GameState {
    /// 経験点通貨の残高
    public subscript(currency c: ExpCurrency) -> Double {
        get {
            switch c {
            case .閃き: return exp閃き
            case .語彙: return exp語彙
            case .間合い: return exp間合い
            case .存在感: return exp存在感
            case .胆力: return exp胆力
            }
        }
        set {
            switch c {
            case .閃き: exp閃き = newValue
            case .語彙: exp語彙 = newValue
            case .間合い: exp間合い = newValue
            case .存在感: exp存在感 = newValue
            case .胆力: exp胆力 = newValue
            }
        }
    }

    /// 未割り振り通貨の総量（「のばす」タイルのバッジ・ネタ帳の残粒表示用）
    public var expTotal: Double {
        exp閃き + exp語彙 + exp間合い + exp存在感 + exp胆力
    }

    /// a が今すぐ注げるか（レシピの全通貨がボトルネックなく揃っているか）。UIの押せる/押せない判定の元。
    /// 正典v3では単一の残高でなくレシピ全体のボトルネックで決まるため config を要求する（旧 pourable(_:) と非互換）。
    public func pourable(_ a: Ability, config: GameConfig) -> Double {
        GameEngine.affordableRaw(a, state: self, config: config)
    }
}

extension GameEngine {
    /// 浮動小数の塵で通貨を空費しない・ループを止めるための下限。balance_sim.py の鏡像と同値に保つこと
    public static let pourEpsilon = 1e-9

    /// add() の①逓減→②予算キャップ→③clamp と同一式で「見える伸び」を副作用なしで返す純関数。
    /// UI（バーの逐次見積もり）・pourStep（ゼロ利得段の事前拒否）・sim（較正）の3所がこれを共有する
    /// ＝見積もりと確定の丸め・逓減の食い違い（goldenの毒）を構造で断つ。
    /// 通貨変換とは独立＝amount は既に「能力への生の伸び試行量」（呼び出し側がボトルネックで決める・下記）。
    /// 同値性は AllocationTests.testProjectedGainMatchesAdd が全分岐グリッドで担保する。
    public static func projectedGain(_ a: Ability, amount: Double, state s: GameState, config: GameConfig) -> Double {
        guard amount > 0 else { return 0 }
        var amt = amount
        if let d = config.growthDecayD {
            amt = amount * max(0, 1 - s[a] / d)
        }
        if let budget = s.growthBudget, amt > 0, a != .メンタル {
            let w = weight(of: a, config: config)
            let remaining = budget - s.growthUsed
            amt = max(0, min(amt, remaining / w))
        }
        let cap = (a == .メンタル) ? config.mentalCap : config.abilityCap
        return clamp(s[a] + amt, 0, cap) - s[a]
    }

    /// 正典v3-1（2026-08-03オーナー指示「能力が上がるほど必要な経験点も変動する」への対応）: 現在ランクが
    /// 高いほど1段あたりの通貨消費が重くなる階段状の倍率。balance_sim._rank_cost_multiplier の鏡像。
    static func rankCostMultiplier(_ a: Ability, state s: GameState, config: GameConfig) -> Double {
        let value = s[a]
        for band in config.abilityRankCostBands where value < band.threshold {
            return band.multiplier
        }
        return config.abilityRankCostMultS
    }

    /// レシピの通貨残高から「このステップで注げる生の伸び試行量」をボトルネック（最も乏しい通貨）で決める
    /// （Leontief固定比率＝1能力を伸ばすには、レシピの全通貨を同じ比率で同時に持っている必要がある）。
    /// ある通貨の重みが w・現在ランクの倍率が m で残高が b なら、その通貨だけで賄える生量は b/(w×m)。
    /// 全通貨中の最小値が実際に払える量。現在ランクが高いほど m が重くなる＝同じ通貨残高でも段が伸びにくくなる
    /// （正典v3-1）。allocationStep を上限にクランプ（段刻みループ正典・論点C不変）。balance_sim._affordable_raw の鏡像。
    static func affordableRaw(_ a: Ability, state s: GameState, config: GameConfig) -> Double {
        let recipe = config.abilityRecipes[a] ?? []
        let mult = rankCostMultiplier(a, state: s, config: config)
        let afford = recipe.map { s[currency: $0.0] / ($0.1 * mult) }.min() ?? 0
        return min(config.allocationStep, afford)
    }

    /// 「次の1段」に要る各通貨量（表示専用の純関数・RNG非消費・監査C-02）。
    /// 1段＝allocationStep の生量を注ぐ時に pourStep が引く量（重み×現在ランクの倍率）。上げるほど増える。
    public static func nextStepCost(_ a: Ability, state s: GameState, config: GameConfig) -> [(currency: ExpCurrency, amount: Double)] {
        let mult = rankCostMultiplier(a, state: s, config: config)
        return (config.abilityRecipes[a] ?? []).map { ($0.0, config.allocationStep * $0.1 * mult) }
    }

    /// 1段（ボトルネック通貨で決まる生量・端数はあるだけ）を a に注ぐ。注入の最小単位＝全経路（+1タップ・
    /// おすすめ・sim/goldenボット）がこの関数を同じ刻みで回す（論点C(b): N回ループ正典。単位を跨いだ
    /// 一括評価を許さない＝貯め込みの1点評価上振れを構造的に不能にする）。
    /// レシピの全通貨を同じ比率で同時消費（Leontief）。見える伸びが無い段は通貨を消費しない（余剰許容）。
    /// 戻り値=実効伸び（0なら状態は一切動いていない）。
    @discardableResult
    public static func pourStep(_ a: Ability, to s: inout GameState, config: GameConfig) -> Double {
        let amount = affordableRaw(a, state: s, config: config)
        guard amount > pourEpsilon else { return 0 }
        let gain = projectedGain(a, amount: amount, state: s, config: config)
        guard gain > pourEpsilon else { return 0 }
        let mult = rankCostMultiplier(a, state: s, config: config)
        for (c, w) in config.abilityRecipes[a] ?? [] {
            s[currency: c] -= amount * w * mult
        }
        add(.ability(a), amount, to: &s, config: config)
        return gain
    }

    // MARK: 交換（詰まり対策・案D 試作・balance_sim の EXCHANGE_* / exchange / pour_tap の鏡像）
    // 今の配合だと間合いの粒が余り、語彙・閃き・胆力が足りず「経験点はあるのに押せる＋が0」の週が1〜3年の約9割
    // （docs/ability_stall_measure_v0.md）。どの能力も押せない時に限り、余り exchangeRate つ → 不足1つ に替えて1段押す。
    // RandomSource 非消費。余りは残高の多い順（同数は ExpCurrency.allCases 順）に払う。

    /// 交換1回の記録（UIの一言用）。paid=払った余り、got=受け取った不足（どちらも粒の量）
    public struct ExchangeRecord: Equatable {
        public let ability: Ability
        public let paid: [ExpCurrency: Double]
        public let got: [ExpCurrency: Double]
    }

    static func isPushable(_ a: Ability, state s: GameState, config: GameConfig) -> Bool {
        let amount = affordableRaw(a, state: s, config: config)
        return amount > pourEpsilon && projectedGain(a, amount: amount, state: s, config: config) > pourEpsilon
    }

    /// a を1段押すのに足りない粒（配合の通貨ごと・足りていれば0）。配合の並び順を保つ
    static func exchangeNeed(_ a: Ability, state s: GameState, config: GameConfig) -> [(ExpCurrency, Double)] {
        let mult = rankCostMultiplier(a, state: s, config: config)
        return (config.abilityRecipes[a] ?? []).map { c, w in (c, max(0, config.allocationStep * w * mult - s[currency: c])) }
    }

    /// 払える余り＝a の配合に無い通貨で残高>0。残高の多い順（同数は allCases 順）
    static func exchangeSources(_ a: Ability, state s: GameState, config: GameConfig) -> [ExpCurrency] {
        let recipe = Set((config.abilityRecipes[a] ?? []).map { $0.0 })
        let all = ExpCurrency.allCases
        let src = all.filter { !recipe.contains($0) && s[currency: $0] > 0 }
        return src.sorted { x, y in
            let bx = s[currency: x], by = s[currency: y]
            if bx != by { return bx > by }
            return all.firstIndex(of: x)! < all.firstIndex(of: y)!
        }
    }

    static func canExchange(_ a: Ability, state s: GameState, config: GameConfig) -> Bool {
        guard config.exchangeEnabled,
              projectedGain(a, amount: config.allocationStep, state: s, config: config) > config.exchangeMinGain else { return false }
        let tot = exchangeNeed(a, state: s, config: config).reduce(0.0) { $0 + $1.1 }
        guard tot > pourEpsilon else { return false }
        let have = exchangeSources(a, state: s, config: config).reduce(0.0) { $0 + s[currency: $1] }
        return have >= config.exchangeRate * tot
    }

    @discardableResult
    static func exchange(_ a: Ability, state s: inout GameState, config: GameConfig) -> ExchangeRecord {
        let need = exchangeNeed(a, state: s, config: config)
        var rest = config.exchangeRate * need.reduce(0.0) { $0 + $1.1 }
        var paid: [ExpCurrency: Double] = [:]
        for c in exchangeSources(a, state: s, config: config) {
            let t = min(s[currency: c], rest)
            s[currency: c] -= t
            paid[c] = t
            rest -= t
            if rest <= 1e-12 { break }
        }
        var got: [ExpCurrency: Double] = [:]
        for (c, n) in need where n > 0 {
            s[currency: c] += n
            got[c] = n
        }
        return ExchangeRecord(ability: a, paid: paid, got: got)
    }

    /// タップ1つの再生（全経路共通・balance_sim.pour_tap の鏡像）: まず普通に1段。押せず、かつ**どの能力も
    /// 押せない**時に限り交換して1段。人の手配りは押せる能力しか押せないので、交換が起きるのはおまかせの列だけ。
    @discardableResult
    public static func pourTap(_ a: Ability, to s: inout GameState, config: GameConfig,
                               log: ((ExchangeRecord) -> Void)? = nil) -> Double {
        let g = pourStep(a, to: &s, config: config)
        if g > 0 { return g }
        if Ability.allCases.contains(where: { isPushable($0, state: s, config: config) }) { return 0 }
        guard canExchange(a, state: s, config: config) else { return 0 }
        let rec = exchange(a, state: &s, config: config)
        log?(rec)
        return pourStep(a, to: &s, config: config)
    }

    /// おすすめ注ぎ（決定論・golden台本の単一純関数）。正典v3: 通貨が能力間で共有される（同じ通貨を複数
    /// 能力が奪い合う）ため、旧来の「ロック→共通枠」2段ではなく、注げる（gain>0）能力の中で現在値が最も
    /// 低いものへ毎ステップ回す単一の追いつきループに一般化した（min-max照準をおすすめに載せない保守設計は不変）。
    /// 交換（試作）: どの能力も押せなくなったら、交換できる能力の中で現在値が最も低いものへ交換して1段（pourTap）。
    /// UIの「おすすめ」ボタンと、週次ボット（golden台本）・simのおすすめボットが全てこの1関数（とPython鏡像）
    /// を使う——3系統の台本分裂＝golden毒源を作らない。
    public static func recommendedPlan(state: GameState, config: GameConfig) -> [Ability] {
        var scratch = state
        var plan: [Ability] = []
        var guardCount = 0
        while guardCount < 10_000 {
            let candidates = Ability.allCases.filter { affordableRaw($0, state: scratch, config: config) > pourEpsilon }
            if let target = candidates.min(by: { scratch[$0] < scratch[$1] }) {
                if pourStep(target, to: &scratch, config: config) > 0 {
                    plan.append(target)
                    guardCount += 1
                    continue
                }
                // 従来どおり（最も低い能力が器切れ等で止まる＝監査F-02・UI側で延長）
                if Ability.allCases.contains(where: { isPushable($0, state: scratch, config: config) }) { break }
            }
            let ex = Ability.allCases.filter { canExchange($0, state: scratch, config: config) }
            guard let target = ex.min(by: { scratch[$0] < scratch[$1] }) else { break }
            guard pourTap(target, to: &scratch, config: config) > 0 else { break }
            plan.append(target)
            guardCount += 1
        }
        return plan
    }

    /// 行動直後の即時全量注ぎ（golden台本）: recommendedPlan を作って本状態に適用する。
    /// balance_sim.pour_all の鏡像。人ボット・simボット・golden・（UIのおすすめ）が全てこの1経路を通る
    /// ＝3系統の台本分裂（golden毒源）を作らない。RandomSource 非消費。
    public static func pourRecommended(to s: inout GameState, config: GameConfig) {
        for a in recommendedPlan(state: s, config: config) {
            pourTap(a, to: &s, config: config)
        }
    }
}
