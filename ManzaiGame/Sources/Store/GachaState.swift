// GachaState.swift
// 衣装ガチャの純ロジック（抽選・被り→かけら・天井・ログインボーナス）。数値はすべて【仮】（docs/costume_gacha_v0.md §2）。
// 乱数は引数で渡す（アプリは SystemRandomNumberGenerator・テストは固定列）。GameCore の乱数とは完全に別＝本編の乱数消費を変えない。
// 提供割合ページ（GachaRatesView）は下の GachaCatalog の表から生成する＝表示と実際の割合がずれない。

import Foundation

enum OutfitRarity: Int, CaseIterable {
    case iro, gara, tokubetsu

    var label: String { ["色替え", "柄", "特別"][rawValue] }
    /// 段ごとの提供割合（%・合計100）【仮】
    var tierPercent: Int { [60, 30, 10][rawValue] }
    /// 被りでもらえるかけら【仮】
    var shardGain: Int { [1, 2, 5][rawValue] }
    /// かけら交換に要る数【仮】
    var shardCost: Int { [10, 20, 40][rawValue] }
}

enum GachaCatalog {
    static let pityGoal = 40          // 天井ポイントの交換ライン【仮】
    static let loginGoal = 7          // ログインの札がこの枚数で無料1回【仮】
    static let price1 = 100           // 円【仮】
    static let price10 = 1000

    /// ガチャの対象の衣装（12着）
    static var pool: [StageOutfit] { StageOutfit.allCases.filter { $0.rarity != nil } }
    static func items(_ r: OutfitRarity) -> [StageOutfit] { StageOutfit.allCases.filter { $0.rarity == r } }

    /// 1着あたりの提供割合（%）。段の割合 ÷ その段の着数（段内は均等）
    static func percent(of o: StageOutfit) -> Double {
        guard let r = o.rarity else { return 0 }
        return Double(r.tierPercent) / Double(items(r).count)
    }
    /// 表示用：小数第3位以下を切り捨てて「12.00%」の形に（切り上げると合計が100%を超えるため）
    static func display(_ p: Double) -> String { String(format: "%.2f%%", (p * 100).rounded(.down) / 100) }
    /// 割合の版（変えるときは上げて告知・docs/release/gacha_rates_page.md）
    static let rateVersion = 1
}

struct PullResult: Equatable {
    let outfit: StageOutfit
    let isNew: Bool
    let shardsGained: Int
}

struct GachaState: Codable, Equatable {
    var owned: Set<String> = []        // ガチャで出た衣装（standard/黒紋付は含めない）
    var freeTickets = 1                // 無料の回数（新規は「はじめての1回」分の1回を最初から持つ。以後はログインボーナスで貯まる）
    var paidCredited = 0               // 購入で付与された回数の累計（増えるだけ）
    var paidOpened = 0                 // 購入分を開封（回した）回数の累計（増えるだけ）
    /// 買ったが、まだ回していない回数＝付与−開封（旧データは付与＝旧の未開封・開封＝0 に移す）。代入は付与側で合わせる
    var paidPending: Int {
        get { max(0, paidCredited - paidOpened) }
        set { paidCredited = paidOpened + max(0, newValue) }
    }
    var shards = 0
    var pity = 0
    var totalPulls = 0
    var loginStamps = 0
    var lastLoginDay = ""              // yyyy-MM-dd（端末の日付）
    var creditedTx: [String] = []      // 付与済みの取引ID（二重付与の防止・直近50件）

    init() {}
    private enum CodingKeys: String, CodingKey {
        case owned, freeTickets, paidPending, paidCredited, paidOpened, shards, pity, totalPulls, loginStamps, lastLoginDay, creditedTx
    }
    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: CodingKeys.self)
        try c.encode(owned, forKey: .owned); try c.encode(freeTickets, forKey: .freeTickets)
        try c.encode(paidCredited, forKey: .paidCredited); try c.encode(paidOpened, forKey: .paidOpened)
        try c.encode(shards, forKey: .shards); try c.encode(pity, forKey: .pity); try c.encode(totalPulls, forKey: .totalPulls)
        try c.encode(loginStamps, forKey: .loginStamps); try c.encode(lastLoginDay, forKey: .lastLoginDay)
        try c.encode(creditedTx, forKey: .creditedTx)
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        owned = try c.decodeIfPresent(Set<String>.self, forKey: .owned) ?? []
        freeTickets = try c.decodeIfPresent(Int.self, forKey: .freeTickets) ?? 1
        shards = try c.decodeIfPresent(Int.self, forKey: .shards) ?? 0
        pity = try c.decodeIfPresent(Int.self, forKey: .pity) ?? 0
        totalPulls = try c.decodeIfPresent(Int.self, forKey: .totalPulls) ?? 0
        loginStamps = try c.decodeIfPresent(Int.self, forKey: .loginStamps) ?? 0
        lastLoginDay = try c.decodeIfPresent(String.self, forKey: .lastLoginDay) ?? ""
        creditedTx = try c.decodeIfPresent([String].self, forKey: .creditedTx) ?? []
        if let cr = try c.decodeIfPresent(Int.self, forKey: .paidCredited) {
            paidCredited = cr
            paidOpened = try c.decodeIfPresent(Int.self, forKey: .paidOpened) ?? 0
        } else {   // 旧形式：未開封の数だけ持っていた
            paidCredited = try c.decodeIfPresent(Int.self, forKey: .paidPending) ?? 0
            paidOpened = 0
        }
    }

    func owns(_ o: StageOutfit) -> Bool { o == .standard || owned.contains(o.rawValue) }
    var availableTickets: Int { freeTickets + paidPending }

    // MARK: 抽選
    /// 1回分を引く（券は無料→有料の順に使う）。券が無ければ nil
    mutating func pullOne<G: RandomNumberGenerator>(_ g: inout G) -> PullResult? {
        if freeTickets > 0 { freeTickets -= 1 } else if paidPending > 0 { paidOpened += 1 } else { return nil }
        let outfit = (totalPulls == 0) ? Self.drawFirst(&g) : Self.draw(&g)   // 初回ガチャ【仮】：最初の1回は特別が必ず出る
        totalPulls += 1
        pity += 1
        if owns(outfit) {
            let n = outfit.rarity?.shardGain ?? 0
            shards += n
            return PullResult(outfit: outfit, isNew: false, shardsGained: n)
        }
        owned.insert(outfit.rawValue)
        return PullResult(outfit: outfit, isNew: true, shardsGained: 0)
    }

    static func draw<G: RandomNumberGenerator>(_ g: inout G) -> StageOutfit {
        var x = Int.random(in: 0..<100, using: &g)
        for r in OutfitRarity.allCases {
            if x < r.tierPercent { return pick(r, &g) }
            x -= r.tierPercent
        }
        return pick(.iro, &g)
    }
    static func drawFirst<G: RandomNumberGenerator>(_ g: inout G) -> StageOutfit { pick(.tokubetsu, &g) }
    private static func pick<G: RandomNumberGenerator>(_ r: OutfitRarity, _ g: inout G) -> StageOutfit {
        let list = GachaCatalog.items(r)
        return list[Int.random(in: 0..<list.count, using: &g)]
    }

    // MARK: かけら・天井の交換
    func canExchangeShards(for o: StageOutfit) -> Bool {
        guard let r = o.rarity, !owns(o) else { return false }
        return shards >= r.shardCost
    }
    @discardableResult
    mutating func exchangeShards(for o: StageOutfit) -> Bool {
        guard canExchangeShards(for: o), let r = o.rarity else { return false }
        shards -= r.shardCost
        owned.insert(o.rawValue)
        return true
    }
    func canExchangePity(for o: StageOutfit) -> Bool { o.rarity != nil && !owns(o) && pity >= GachaCatalog.pityGoal }
    @discardableResult
    mutating func exchangePity(for o: StageOutfit) -> Bool {
        guard canExchangePity(for: o) else { return false }
        pity -= GachaCatalog.pityGoal
        owned.insert(o.rawValue)
        return true
    }

    // MARK: ログインボーナス
    static func dayKey(_ d: Date = Date(), calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
    /// 今日の札をもらえるか（日付が戻された時はもらえない）
    func canClaimLogin(today: String) -> Bool { today > lastLoginDay }
    /// 札を1枚もらう。もらえたら true。札がたまったら無料1回に替わる
    @discardableResult
    mutating func claimLogin(today: String) -> Bool {
        guard canClaimLogin(today: today) else { return false }
        lastLoginDay = today
        loginStamps += 1
        if loginStamps >= GachaCatalog.loginGoal { loginStamps -= GachaCatalog.loginGoal; freeTickets += 1 }
        return true
    }

    // MARK: 購入の付与
    /// 取引IDごとに1度だけ回数を足す（Transaction.updates の再配信で二重に付かない）
    @discardableResult
    mutating func credit(txID: String, count: Int) -> Bool {
        guard !creditedTx.contains(txID) else { return false }
        creditedTx.append(txID)
        if creditedTx.count > 50 { creditedTx.removeFirst(creditedTx.count - 50) }
        paidCredited += count
        return true
    }

    // MARK: iCloud 競合の合流（増える一方の値は大きい方・所有は和集合）
    func merged(with o: GachaState) -> GachaState {
        var m = self
        m.owned.formUnion(o.owned)
        m.totalPulls = max(totalPulls, o.totalPulls)
        m.loginStamps = max(loginStamps, o.loginStamps)
        m.lastLoginDay = max(lastLoginDay, o.lastLoginDay)
        // 残高は回数の多い側（新しい側）を採る
        // 回数が同じでも、かけら・天井で交換して持ち物が増えた側が新しい（古い側の残高が戻って二重に使えるのを防ぐ）
        let newer = (o.totalPulls, o.owned.count) > (totalPulls, owned.count) ? o : self
        m.shards = newer.shards; m.pity = newer.pity; m.freeTickets = newer.freeTickets
        m.paidCredited = max(paidCredited, o.paidCredited)
        m.paidOpened = max(paidOpened, o.paidOpened)
        for t in o.creditedTx where !m.creditedTx.contains(t) { m.creditedTx.append(t) }
        if m.creditedTx.count > 50 { m.creditedTx.removeFirst(m.creditedTx.count - 50) }
        return m
    }
}
