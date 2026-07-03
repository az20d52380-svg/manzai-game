// GameState.swift
// コンビ1組の状態。SwiftUI 非依存の純 Swift（CLAUDE.mdルール1）。

public struct GameState {
    public var money: Int
    public var stamina: Double
    public var fame: Double
    public var センス: Double
    public var 発想: Double
    public var 表現: Double
    public var 華: Double
    public var メンタル: Double
    public var compat: Double

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
