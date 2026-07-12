// Allocation.swift
// 経験点残高（GameState.exp*）→ 能力への注入（割り振り）。正典: docs/exp_abilityup_impl_reply_v0.md。
// 会計の二層（0040追補・GO確定）: 稼ぐ時は予算非消費で粒が貯まる／注ぐ瞬間だけ既存 GameEngine.add()
// （①逓減→②割り振り時予算→③clamp・位置と順序は不変）を通す。発行ゲート（逓減前の生粒で予算消費）はNO-GO確定＝禁止。
// このファイルは「注ぐ側」のみ。発行側（稽古→exp*への積み上げ・expFreeShare分割）はMac側の会計移設（規律A第1段）。
// RandomSource を一切呼ばない＝乱数消費順は不変（applyEventEffects と同じ規律）。
// Python鏡像: tools/balance_sim.py に projected_gain / pour_step / recommended_plan を同値実装する（Mac側・ルール5）。
// 数値は全て【仮】（allocationStep / expFreeShare は GameConfig 集約）。

/// 共通枠（二区画中間の"選べる側"）。枠内のどの能力にも注げる粒の受け皿。
/// 対応は稽古の系と一致する: ネタ系（ネタ作り/ネタ合わせ→センス・発想）／舞台系（ネタ見せ会/フリーライブ→表現・華）。
/// メンタルはどの枠にも属さない＝共通粒はメンタルに注げない（予算外能力へ新しい供給路を作らない・安全条件）。
public enum ExpGroup: String, CaseIterable, Hashable {
    case ネタ
    case 舞台

    /// 能力→所属枠（メンタルは nil）。対応表は【仮】——変える時はこの1箇所（＋Python鏡像）だけ。
    public static func of(_ a: Ability) -> ExpGroup? {
        switch a {
        case .センス, .発想: return .ネタ
        case .表現, .華: return .舞台
        case .メンタル: return nil
        }
    }

    /// 枠→注げる能力（各枠2能力に限定＝完全多対多を禁じる安全条件）
    public var members: [Ability] {
        switch self {
        case .ネタ: return [.センス, .発想]
        case .舞台: return [.表現, .華]
        }
    }
}

extension GameState {
    /// 同色ロック粒の残高（色Cの粒は能力Cにしか注げない・η=色変換は存在しない）
    public subscript(bank a: Ability) -> Double {
        get {
            switch a {
            case .センス: return expセンス
            case .発想: return exp発想
            case .表現: return exp表現
            case .華: return exp華
            case .メンタル: return expメンタル
            }
        }
        set {
            switch a {
            case .センス: expセンス = newValue
            case .発想: exp発想 = newValue
            case .表現: exp表現 = newValue
            case .華: exp華 = newValue
            case .メンタル: expメンタル = newValue
            }
        }
    }

    /// 共通枠粒の残高
    public subscript(free g: ExpGroup) -> Double {
        get {
            switch g {
            case .ネタ: return expネタ
            case .舞台: return exp舞台
            }
        }
        set {
            switch g {
            case .ネタ: expネタ = newValue
            case .舞台: exp舞台 = newValue
            }
        }
    }

    /// a へ注げる残高の合計（同色ロック＋所属枠の共通粒）。UIの押せる/押せない判定の元
    public func pourable(_ a: Ability) -> Double {
        self[bank: a] + (ExpGroup.of(a).map { self[free: $0] } ?? 0)
    }

    /// 未割り振り粒の総量（「のばす」タイルのバッジ・ネタ帳の残粒表示用）
    public var expTotal: Double {
        expセンス + exp発想 + exp表現 + exp華 + expメンタル + expネタ + exp舞台
    }
}

extension GameEngine {
    /// 浮動小数の塵で粒を空費しない・ループを止めるための下限。balance_sim.py の鏡像と同値に保つこと
    public static let pourEpsilon = 1e-9

    /// add() の①逓減→②予算キャップ→③clamp と同一式で「見える伸び」を副作用なしで返す純関数。
    /// UI（バーの逐次見積もり）・pourStep（ゼロ利得段の事前拒否）・sim（較正）の3所がこれを共有する
    /// ＝見積もりと確定の丸め・逓減の食い違い（goldenの毒）を構造で断つ。
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

    /// 1段（allocationStep 経験点・端数はあるだけ）を a に注ぐ。注入の最小単位＝全経路（+1タップ・
    /// おすすめ・sim/goldenボット）がこの関数を同じ刻みで回す（論点C(b): N回ループ正典。単位を跨いだ
    /// 一括評価を許さない＝貯め込みの1点評価上振れ +3.6〜4.7pt を構造的に不能にする）。
    /// 支払いは 同色ロック→共通枠 の固定順（タップ順に依存しない）。
    /// 見える伸びが無い段は粒を消費しない（余剰許容: 器満ち・上限・逓減死では残高がそのまま残る）。
    /// 戻り値=実効伸び（0なら状態は一切動いていない）。
    @discardableResult
    public static func pourStep(_ a: Ability, to s: inout GameState, config: GameConfig) -> Double {
        let lockedPay = min(s[bank: a], config.allocationStep)
        let group = ExpGroup.of(a)
        let freePay = group.map { min(s[free: $0], config.allocationStep - lockedPay) } ?? 0
        let amount = lockedPay + freePay
        guard amount > pourEpsilon else { return 0 }
        let gain = projectedGain(a, amount: amount, state: s, config: config)
        guard gain > pourEpsilon else { return 0 }
        s[bank: a] -= lockedPay
        if let g = group { s[free: g] -= freePay }
        add(.ability(a), amount, to: &s, config: config)
        return gain
    }

    /// おすすめ注ぎ（決定論・golden台本の単一純関数）。方針【仮】:
    /// (1) 同色ロックを Ability.allCases 順に注ぎ切る（同色は行き先の選択が無い＝機械的に正しい）
    /// (2) 共通枠は各枠の「現在値が低い方」へ（追いつき既定。min-max照準をおすすめに載せない＝
    ///     sim較正ゲート「おすすめ最適度がバランス帯を押し上げない」への保守設計）。低い方が注げなければ高い方。
    /// UIの「おすすめ」ボタンと、Mac側の会計移設後の週次ボット（golden台本）・simのおすすめボットが
    /// 全てこの1関数（とPython鏡像）を使う——3系統の台本分裂＝golden毒源を作らない。
    public static func recommendedPlan(state: GameState, config: GameConfig) -> [Ability] {
        var scratch = state
        var plan: [Ability] = []
        var guardCount = 0
        for a in Ability.allCases {
            while scratch[bank: a] > pourEpsilon, guardCount < 10_000,
                  pourStep(a, to: &scratch, config: config) > 0 {
                plan.append(a)
                guardCount += 1
            }
        }
        for g in ExpGroup.allCases {
            while scratch[free: g] > pourEpsilon, guardCount < 10_000 {
                let ordered = g.members.sorted { scratch[$0] < scratch[$1] }
                var poured = false
                for t in ordered {
                    if pourStep(t, to: &scratch, config: config) > 0 {
                        plan.append(t)
                        poured = true
                        guardCount += 1
                        break
                    }
                }
                if !poured { break }
            }
        }
        return plan
    }
}
