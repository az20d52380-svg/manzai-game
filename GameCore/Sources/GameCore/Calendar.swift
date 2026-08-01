// Calendar.swift
// 年間大会カレンダーと多段階グランプリの定義。
// tools/sim_career.py の TOURNAMENTS / GP_ROUNDS と1対1対応（数値は全て【仮】・週とラインの根拠は docs/endgame_design_v0.md）。

public struct TravelSpec {
    public let cost: Int
    public let stamina: Double

    public init(cost: Int, stamina: Double) {
        self.cost = cost
        self.stamina = stamina
    }
}

/// Codable は中断セーブ用（WeekRunnerSnapshot・proposals-0039）＝挙動・golden不変
public enum Travel: Codable {
    case 夜行バス
    case 新幹線
}

public struct TournamentSpec: Codable {
    public enum Eligibility: Codable {
        case always
        case careerYearAtMost(Int)   // 芸歴・結成n年以内
        case fameAtLeast(Double)     // 推薦制（知名度条件）【仮】
    }

    public let name: String
    public let week: Int
    public let line: Double
    public let prize: Int          // 手元に入る額（表示額の半分ルール適用済み）
    public let fame: Double        // 優勝時の知名度上昇
    public let osaka: Bool         // 大阪遠征（交通費と体力）が必要か
    public let eligibility: Eligibility

    public init(name: String, week: Int, line: Double, prize: Int, fame: Double, osaka: Bool, eligibility: Eligibility) {
        self.name = name
        self.week = week
        self.line = line
        self.prize = prize
        self.fame = fame
        self.osaka = osaka
        self.eligibility = eligibility
    }

    public func isEligible(year: Int, state: GameState) -> Bool {
        switch eligibility {
        case .always:
            return true
        case .careerYearAtMost(let n):
            return year <= n
        case .fameAtLeast(let f):
            return state.fame >= f
        }
    }
}

public struct CalendarConfig {
    /// 道中の大会（Python: sim_career.TOURNAMENTS）
    public var tournaments: [TournamentSpec] = [
        // ライン【正典v2 2026-07-05】旧値×0.55（docs/canonical_v2_spec.md）
        TournamentSpec(name: "春新人賞A",       week: 12, line: 30, prize: 500_000, fame: 10, osaka: true,  eligibility: .careerYearAtMost(10)),
        TournamentSpec(name: "春新人賞B",       week: 15, line: 28, prize: 250_000, fame: 5,  osaka: true,  eligibility: .careerYearAtMost(10)),
        TournamentSpec(name: "夏中堅賞",         week: 27, line: 33, prize: 500_000, fame: 10, osaka: true,  eligibility: .careerYearAtMost(10)),
        TournamentSpec(name: "大阪戎コンクール", week: 29, line: 22, prize: 100_000, fame: 5,  osaka: true,  eligibility: .always),
        TournamentSpec(name: "若手限定賞",       week: 35, line: 28, prize: 250_000, fame: 5,  osaka: false, eligibility: .careerYearAtMost(5)),
        TournamentSpec(name: "推薦制中堅賞",     week: 38, line: 33, prize: 500_000, fame: 10, osaka: false, eligibility: .fameAtLeast(30)),
    ]

    /// グランプリ各回戦（Python: sim_career.GP_ROUNDS。ライン【正典v2 2026-07-05】docs/canonical_v2_spec.md）
    public var gpRounds: [(week: Int, line: Double)] = [(30, 18), (39, 26), (41, 34), (43, 45), (45, 74)]
    /// 回戦の表示名（Python: GP_ROUNDS のラベルと同一・UI用）
    public var gpRoundNames = ["GP1回戦", "GP2回戦", "GP3回戦", "GP準々決勝", "GP準決勝"]
    public var gpFinalWeek = 47
    public var gpRevivalLine = 76.0   // 敗者復活 = 決勝-4（準決勝敗退のみ・決勝と同週）【正典v2】
    public var gpFinalLine = 80.0     // 【正典v2】のんびり改0.3%・やり込み2.1%（exp_v2_anchor）
    public var gpRoundFame = 3.0      // 回戦通過の知名度【仮】
    public var fameFinalBonus = 1.5   // 決勝のみの人気補正【機微】: 実効ライン = ライン − 本値×(知名度−50)/50
    public var gpPrize = 5_000_000    // 優勝賞金（表示1,000万の半分・手元）【仮】
    public var champFame = 20.0

    /// エントリー費（全大会・GP共通。実在の賞レース準拠 2,000円【正典v2】。Python: GP_ENTRY_FEE）
    /// 大会: 払えなければ不出場。GP: 1回戦週に払えなければその年は出場不可（夜逃げ寸前だけが踏む）
    public var entryFee = 2_000

    public var busTravel = TravelSpec(cost: 10_000, stamina: -25)   // Python: BUS
    public var trainTravel = TravelSpec(cost: 30_000, stamina: 0)   // Python: TRAIN

    public func tournament(inWeek week: Int) -> TournamentSpec? {
        tournaments.first { $0.week == week }
    }

    public func travelSpec(_ travel: Travel) -> TravelSpec {
        switch travel {
        case .夜行バス: return busTravel
        case .新幹線: return trainTravel
        }
    }

    public init() {}
}
