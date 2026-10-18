// GameState.swift
// コンビ1組の状態。SwiftUI 非依存の純 Swift（CLAUDE.mdルール1）。
//
// ⚠️ セーブ互換の規約（監査G-03・2026-10-06）: このstructは中断セーブ（GameSession.SaveData）にJSONで丸ごと乗る。
//    Swift の合成 Decodable は「既定値付きの非Optional」でも旧セーブにキーが無いと復号に失敗する。
//    出荷後に足すフィールドは必ず Optional（`var x: T? = nil`）にし、読む側で `?? 既定値` にすること。

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
    /// テレビ慣れ（キュー96）：直近でオファーを受けた通算週 ((年-1)*週数+週)。Codable は Optional（旧セーブ互換）
    public var offerWeeks: [Int]? = nil

    // --- 経験点残高（正典v3・パワプロ式5通貨・docs/exp_currency_redesign_v0.md） ---
    // 会計の二層: 稼ぐ時は成長予算を消費せずここに貯まり、能力へ注ぐ瞬間だけ GameEngine.add()
    // （①逓減→②割り振り時予算→③clamp・位置不変）を通る。注ぐ側は Allocation.swift（pourStep）。
    // 通貨は能力名と別立て（1能力=複数通貨のブレンド・1通貨=複数能力に寄与＝真の多対多。ExpCurrency参照）。
    /// 閃き（アイデアの瞬発力）
    public var exp閃き = 0.0
    /// 語彙（言葉の引き出し）
    public var exp語彙 = 0.0
    /// 間合い（間・テンポ）
    public var exp間合い = 0.0
    /// 存在感（華・舞台映え）
    public var exp存在感 = 0.0
    /// 胆力（メンタルの土台）
    public var exp胆力 = 0.0

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

    /// 相性成長の凍結週（0012 谷口の耳寄りな話）。>0 の間は add(.コンビ相性) の"増加"だけ止まる（減算は通す）。
    /// UI層イベント（GameSession）が設定し、週送りで1ずつ減る。★golden不変: gen_golden はイベント非発火＝
    /// 常に0＝ゲートは恒等 no-op（GameEngine.add / balance_sim.add の inert ゲートで golden 期待値バイト一致を実証）。
    public var compatFreezeWeeks = 0
    /// 途中解散のすれ違いゲージ 0〜100（nil＝古いセーブ＝0扱い）。乱数なし・golden の行には出ない
    public var rift: Double?
    /// 予告（rift≥riftWarn の初回）を出したか。アプリ側が予告イベントを出す合図
    public var riftWarned: Bool?
    /// 週頭の相性（この週に相性が上がったかの判定用）
    public var riftWeekStartCompat: Double?
    /// §94 この週に二人で舞台に立った（ネタ見せ会・フリーライブ・大会・GP）。週頭に false に戻す。Optional＝古いセーブ互換
    public var riftJointWeek: Bool?
    /// 途中解散でキャリアが終わったか
    public var dissolved: Bool?

    /// 覚えた特技（Skill.swift・キュー106。nil＝未習得＝今と同じ）
    public var skills: [Skill]? = nil

    /// ネタ合わせ（磨き）の効果ブースト週（0016 書けた一本＝寝かせた効果）。>0 の間は applyNetaRevise の
    /// polish 上昇に config.netaBoostMult を掛ける。UI層イベント（GameSession）が設定し、週送りで1ずつ減る。
    /// ★golden不変: applyNetaRevise は golden 非経路（gen_golden はネタ個体を持たない＝revise 自体を呼ばない）。
    /// gen_golden はイベント非発火＝常に0＝乗算ゲートは恒等 no-op（compatFreezeWeeks と同型の inert フィールド）。
    public var netaBoostWeeks = 0

    /// 稽古拘束週（0022 撮られる仕事＝撮影がその週の稽古枠を奪う）。>0 の間は稽古を選べない（UI層で自動休養化）。
    /// UI層イベント（GameSession）が設定し、週送りで1ずつ減る。★golden不変: enforcement は GameSession.choose
    /// （UI層・golden非経路）で行い WeekRunner.resolveAction には触れない＝gen_golden はイベント非発火＝常に0
    /// ＝稽古ロックは一度も効かない（compatFreezeWeeks/netaBoostWeeks と同型の inert フィールド）。
    public var preoccupiedWeeks = 0

    // --- アイテム（Item.swift・2026-10-12）。セーブ互換のため全て Optional（nil＝未購入・効果なし＝golden不変）---
    /// その年に買った回数（年初に消える）
    public var itemCounts: [String: Int]? = nil
    /// 銭湯の回数券の残り（休むの回復に上乗せ）
    public var sentoTickets: Int? = nil
    /// 中古のICレコーダー（ネタ作りの閃き+1・キャリアで1回）
    public var hasRecorder: Bool? = nil
    /// 新幹線回数券（その年の遠征が交通費0・体力減なし）
    public var shinkansenActive: Bool? = nil
    /// 稽古場の年契約（その年の稽古の主効果+1）
    public var studioActive: Bool? = nil
    // --- 部屋の段（キュー90）：nil/0＝安アパート（今と同一）。古いセーブは nil ---
    public var room: Int? = nil

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
