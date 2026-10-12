// Item.swift
// 円で買うアイテム（docs/item_design_v0.md §1-A/1-B を v3 経済に合わせた最小実装・2026-10-12）。
// 三大原則：恒久的な強さは売らない（例外＝ICレコーダー1点）／年間の回数制限／能力は直接上げず経験点か体力で渡す。
// ★golden不変：購入は乱数を引かず、gen_golden の台本は何も買わない＝フラグは全て nil のまま＝式は恒等。
// Python鏡像：tools/balance_sim.py の ITEMS / buy_item（ルール5）。数値は全て【仮】。

public enum ShopItem: String, CaseIterable, Codable {
    case 栄養ドリンク
    case 銭湯の回数券
    case 中古のICレコーダー
    case 新幹線回数券
    case ネタ作家の勉強会
    case ボイトレ短期集中
    case 稽古場の年契約
}

public struct ItemSpec {
    public let price: Int
    public let yearlyLimit: Int?     // nil＝キャリアで1回だけ
    public let summary: String       // 画面用の1行（効果の向きだけ）
    public init(price: Int, yearlyLimit: Int?, summary: String) {
        self.price = price; self.yearlyLimit = yearlyLimit; self.summary = summary
    }
}

extension GameEngine {
    /// 今買えるか（所持金・回数・持ち越し中の回数券）。表示と確定の両方がこれを使う。
    public static func canBuy(_ item: ShopItem, state s: GameState, config: GameConfig) -> Bool {
        guard let spec = config.items[item], s.money >= spec.price else { return false }
        switch item {
        case .中古のICレコーダー: return s.hasRecorder != true
        case .銭湯の回数券: return (s.sentoTickets ?? 0) == 0
        case .新幹線回数券: if s.shinkansenActive == true { return false }
        case .稽古場の年契約: if s.studioActive == true { return false }
        default: break
        }
        if let lim = spec.yearlyLimit, (s.itemCounts?[item.rawValue] ?? 0) >= lim { return false }
        return true
    }

    /// 購入して効果を適用。買えなければ false（状態は不変）。乱数は引かない。
    @discardableResult
    public static func buy(_ item: ShopItem, to s: inout GameState, config: GameConfig) -> Bool {
        guard canBuy(item, state: s, config: config), let spec = config.items[item] else { return false }
        s.money -= spec.price
        var counts = s.itemCounts ?? [:]
        counts[item.rawValue, default: 0] += 1
        s.itemCounts = counts
        switch item {
        case .栄養ドリンク:
            add(.体力, config.itemDrinkStamina, to: &s, config: config)
        case .銭湯の回数券:
            s.sentoTickets = config.itemSentoTickets
        case .中古のICレコーダー:
            s.hasRecorder = true
        case .新幹線回数券:
            s.shinkansenActive = true
        case .ネタ作家の勉強会:
            s[currency: .閃き] += config.itemStudyHirameki
            s[currency: .語彙] += config.itemStudyGoi
        case .ボイトレ短期集中:
            s[currency: .間合い] += config.itemVoiceMaai
            s[currency: .語彙] += config.itemVoiceGoi
        case .稽古場の年契約:
            s.studioActive = true
        }
        return true
    }

    /// 年替わりで「その年だけ」の効果と回数を消す（WeekRunner の年初・sim の run_year 冒頭と同じ位置）。
    static func resetYearlyItems(_ s: inout GameState) {
        if s.itemCounts != nil { s.itemCounts = nil }
        if s.shinkansenActive != nil { s.shinkansenActive = nil }
        if s.studioActive != nil { s.studioActive = nil }
    }
}
