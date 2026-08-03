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

    /// おすすめ注ぎ（決定論・golden台本の単一純関数）。正典v3: 通貨が能力間で共有される（同じ通貨を複数
    /// 能力が奪い合う）ため、旧来の「ロック→共通枠」2段ではなく、注げる（gain>0）能力の中で現在値が最も
    /// 低いものへ毎ステップ回す単一の追いつきループに一般化した（min-max照準をおすすめに載せない保守設計は不変）。
    /// UIの「おすすめ」ボタンと、週次ボット（golden台本）・simのおすすめボットが全てこの1関数（とPython鏡像）
    /// を使う——3系統の台本分裂＝golden毒源を作らない。
    public static func recommendedPlan(state: GameState, config: GameConfig) -> [Ability] {
        var scratch = state
        var plan: [Ability] = []
        var guardCount = 0
        while guardCount < 10_000 {
            let candidates = Ability.allCases.filter { affordableRaw($0, state: scratch, config: config) > pourEpsilon }
            guard let target = candidates.min(by: { scratch[$0] < scratch[$1] }) else { break }
            guard pourStep(target, to: &scratch, config: config) > 0 else { break }
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
            pourStep(a, to: &s, config: config)
        }
    }
}
