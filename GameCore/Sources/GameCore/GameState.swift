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

    // --- 経験点残高（正典: docs/exp_abilityup_impl_reply_v0.md・割り振り時予算＋二区画中間） ---
    // 会計の二層: 稼ぐ時は成長予算を消費せずここに貯まり、能力へ注ぐ瞬間だけ GameEngine.add()
    // （①逓減→②割り振り時予算→③clamp・位置不変）を通る。注ぐ側は Allocation.swift（pourStep）。
    // 発行側の配線（稽古→ここへの積み上げ・ρ分割）はMac側の会計移設（規律A第1段）＝それまで常に0で挙動不変。
    /// 同色ロック粒: その色の能力にしか注げない（色変換ηは存在しない・0040追補で廃止確定）
    public var expセンス = 0.0
    public var exp発想 = 0.0
    public var exp表現 = 0.0
    public var exp華 = 0.0
    public var expメンタル = 0.0
    /// 共通枠粒: 枠内のどの能力にも注げる（ネタ=センス/発想・舞台=表現/華。ExpGroup 参照）。
    /// メンタルへの共通経路は無い＝予算外の能力へ新しい供給路を作らない（安全条件）
    public var expネタ = 0.0
    public var exp舞台 = 0.0

    // --- 持ちネタ（正典: docs/neta_system_redesign_v2.md）。selectedNetaID は Phase 1-a で本番スコアに効く ---
    // ★golden不変: perform（GameEngine.swift:145-158）はこれらを一切読まない＝合否スコア・乱数消費順に非干渉。
    //   exp* 追加（上 30-38）と完全に同型の「セーブに乗る器」。init では代入しない＝既定値に委ねる（exp* と同様）。
    /// アクティブな持ちネタ（少数・磨き対象＝鉄板枠。v2 §2-2）
    public var netas: [Neta] = []
    /// 保管庫（多数・年跨ぎ資産＝倉庫。いつでも大会に呼び戻せる。古いネタは玉突きで消えない。v2 §2-2）
    public var archivedNetas: [Neta] = []
    /// 生成連番の採番（決定論・乱数非依存）
    public var nextNetaID = 0
    /// 大会に「今かける」ネタ（自由週にデフォルト=前回踏襲・v2 §4）
    public var selectedNetaID: Int? = nil
    /// 決勝の2本目（v2 §4-2）
    public var selectedNetaID2: Int? = nil

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
