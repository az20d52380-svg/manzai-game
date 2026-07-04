// GameState.swift
// コンビ1組の状態。SwiftUI 非依存の純 Swift（CLAUDE.mdルール1）。

public struct GameState: Codable {
    public var money: Int
    public var stamina: Double
    public var fame: Double
    public var センス: Double
    public var 発想: Double
    public var 表現: Double
    public var 華: Double
    public var メンタル: Double
    public var compat: Double

    // --- 正典v2の進行状態（Python: s._yg / s._inj / s._bankrupt と同期） ---
    /// 成長予算の上限（キャリア累計・Career.runYear が年初に更新。nil なら無制限=エンジン単体テスト用）
    public var growthBudget: Double? = nil
    /// 成長予算の使用量（実力値換算・キャリア通算でリセットしない）
    public var growthUsed = 0.0
    /// 体調ダウンの残り療養週数
    public var recoveryWeeks = 0
    /// 夜逃げ（破産）でキャリアが終了したか
    public var bankrupt = false

    public init(config: GameConfig = GameConfig()) {
        money = config.initMoney
        stamina = config.initStamina
        fame = config.initFame
        センス = config.initAbility
        発想 = config.initAbility
        表現 = config.initAbility
        華 = config.initAbility
        メンタル = config.initAbility
        compat = config.compatInit
    }

    public subscript(_ a: Ability) -> Double {
        get {
            switch a {
            case .センス: return センス
            case .発想: return 発想
            case .表現: return 表現
            case .華: return 華
            case .メンタル: return メンタル
            }
        }
        set {
            switch a {
            case .センス: センス = newValue
            case .発想: 発想 = newValue
            case .表現: 表現 = newValue
            case .華: 華 = newValue
            case .メンタル: メンタル = newValue
            }
        }
    }
}
