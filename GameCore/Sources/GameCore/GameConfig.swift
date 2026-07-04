// GameConfig.swift
// バランス数値の集約点（CLAUDE.mdルール3）。全て【仮】。
// tools/balance_sim.py の CONFIG と1対1対応させ、数式を変えたら必ず両方を更新する（ルール5）。
// 対応表は docs/gamecore_design.md を参照。

/// 能力5種（Python: sense / idea / expr / chara / mental）
public enum Ability: CaseIterable, Hashable {
    case センス
    case 発想
    case 表現
    case 華
    case メンタル
}

/// 増減の対象となるステータスの鍵（Python: add() の key）
public enum StatKey {
    case ability(Ability)
    case コンビ相性
    case 体力
    case 知名度
}

public enum Training: CaseIterable, Hashable {
    case ネタ作り
    case ネタ見せ会
    case ネタ合わせ
    case ランニング・サウナ
    case フリーライブ
}

public enum Job: CaseIterable, Hashable {
    case キツい
    case 標準
    case 楽
}

public enum Rest: CaseIterable, Hashable {
    case 完全休養
    case 気分転換
    case 相方と過ごす
}

public struct TrainingSpec {
    public let main: (StatKey, Double)
    public let sub: (StatKey, Double)?
    public let cost: Int
    public let stamina: Double
    public let fame: Double

    public init(main: (StatKey, Double), sub: (StatKey, Double)?, cost: Int, stamina: Double, fame: Double) {
        self.main = main
        self.sub = sub
        self.cost = cost
        self.stamina = stamina
        self.fame = fame
    }
}

public struct OfferSpec {
    public let name: String
    public let income: Int
    public let fame: Double
    public let ability: (Ability, Double)?
    public let stamina: Double

    public init(name: String, income: Int, fame: Double, ability: (Ability, Double)?, stamina: Double) {
        self.name = name
        self.income = income
        self.fame = fame
        self.ability = ability
        self.stamina = stamina
    }
}

public struct GameConfig {
    // --- 基本（Python: WEEKS ほか） ---
    public var weeks = 48
    public var initMoney = 300_000
    public var initStamina = 100.0
    public var initFame = 3.0
    public var initAbility = 10.0
    public var compatInit = 5.0
    public var compatCap = 20.0        // 【仮】相性の成長上限
    public var compatGrows = true      // 【TBD】ネタ合わせ/相方と過ごす で+1

    /// 成長逓減【仮】: 能力上昇量 × (1 − 現在値/D)。nil で逓減なし。
    /// docs/career_report_v1.md・endgame_design_v0.md で正式採用（balance_sim.py GROWTH_DECAY_D と同期）。
    /// D±1で10年優勝率が約15〜25pt動く鋭いレバー。トロフィー（才能解放）はDを+1ずつ上げる設計。
    public var growthDecayD: Double? = 120

    /// 演技系4能力（センス/発想/表現/華）の上限【仮・固定】。トロフィーで D が 120 を超えた分は
    /// 「上限への到達が速く・確実になる」効果として働く（balance_sim.py ABILITY_CAP と同期）
    public var abilityCap = 120.0
    /// メンタルの上限。ブレ幅式 (1−メンタル/100) に直結するため 100 のまま（balance_sim.py MENTAL_CAP と同期）
    public var mentalCap = 100.0

    // --- 生活費（Python: LIVING_COST / LIVING_INTERVAL） ---
    public var livingCost = 100_000
    public var livingInterval = 4

    // --- 稽古（Python: TRAININGS） ---
    public var trainings: [Training: TrainingSpec] = [
        .ネタ作り:     TrainingSpec(main: (.ability(.発想), 3),     sub: (.ability(.センス), 1), cost: 0,      stamina: -20, fame: 0),
        .ネタ見せ会:     TrainingSpec(main: (.ability(.表現), 6),     sub: (.ability(.メンタル), 3), cost: 80_000, stamina: -30, fame: 0),
        .ネタ合わせ:   TrainingSpec(main: (.ability(.センス), 3),   sub: (.コンビ相性, 1),        cost: 0,      stamina: -20, fame: 0),
        .ランニング・サウナ: TrainingSpec(main: (.ability(.メンタル), 6), sub: nil,                     cost: 80_000, stamina: -10, fame: 0),
        .フリーライブ:     TrainingSpec(main: (.ability(.華), 3),       sub: (.ability(.表現), 1),    cost: 0,      stamina: -30, fame: 1),
    ]

    // --- バイト（Python: JOBS） ---
    public var jobs: [Job: (income: Int, stamina: Double)] = [
        .キツい: (income: 120_000, stamina: -30),
        .標準:   (income: 80_000,  stamina: -20),
        .楽:     (income: 40_000,  stamina: -10),
    ]

    // --- 休む（Python: RESTS） ---
    public var rests: [Rest: (recovery: Double, bonus: (StatKey, Double))] = [
        .完全休養:     (recovery: 60, bonus: (.ability(.メンタル), 2)),
        .気分転換:     (recovery: 35, bonus: (.ability(.メンタル), 1)),
        .相方と過ごす: (recovery: 20, bonus: (.コンビ相性, 1)),
    ]

    // --- オファー（Python: OFFER_MONEY / OFFER_EXP / OFFER_RATES） ---
    public var offerMoney = OfferSpec(name: "お金重視", income: 300_000, fame: 1, ability: nil, stamina: -20)
    public var offerExp   = OfferSpec(name: "経験重視", income: 150_000, fame: 3, ability: (.表現, 2), stamina: -20)
    /// (知名度がこの値未満, 発生率/週)
    public var offerRates: [(fameBelow: Double, rate: Double)] = [(20, 0.05), (50, 0.15), (80, 0.30), (999, 0.50)]

    // --- 本番スコア（Python: W_SENSE ほか・STAM_PEN） ---
    public var weightSense = 0.30
    public var weightIdea = 0.30
    public var weightExpr = 0.25
    public var weightChara = 0.15
    /// (体力がこの値未満, ペナルティ)。先頭から評価し最初に該当したものを適用
    public var staminaPenalties: [(below: Double, penalty: Double)] = [(30, -10), (50, -5)]

    // --- 大会カレンダー（Python: sim_career.py の定数群） ---
    public var calendar = CalendarConfig()

    public init() {}
}
