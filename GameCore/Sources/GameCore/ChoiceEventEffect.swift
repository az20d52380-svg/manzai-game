// ChoiceEventEffect.swift
// 選択肢イベントの「確定効果」。純加減算＋clamp のみ（RandomSource を一切呼ばない＝乱数消費順不変＝3年golden不変）。
// 成長逓減・成長予算は通さない＝イベントは「別枠の付与」で、総量は sim の EVENT_FIRE_CAP=15 で管理する（proposals/0024 §4-B）。
// proposals/0024 ピース1。数値は全て【仮】（各 proposals/0010,0017,0018,0019 の【効果】節）。

public enum EventEffect {
    case ability(Ability, Double)     // 能力（0..abilityCap / メンタルは 0..mentalCap）
    case compat(Double)               // 相性（0..compatCap）
    case stamina(Double)              // 体力（0..100）
    case fame(Double)                 // 知名度（0..100）
    case money(Int)                   // 所持金（クランプ無し・負可）
    case weakestSkillPlus(Double)     // センス/発想/表現/華 の最小に加算（メンタル除外・0017A の効果バグ回避版）
    case weakerSenseIdeaPlus(Double)  // センス/発想 の低い方に加算（0018B）
    case compatFreeze(Int)            // 相性成長を指定週だけ凍結（0012A・UI層で週送り減算・golden非対象）
    case netaBoostNextWeek(Int)       // ネタ合わせ効果ブーストを指定週だけ付与（0016B・UI層で週送り減算・golden非対象）
    case growthCeiling(Double)        // その年の成長天井（growthBudget）を増減（0023A・負で縮む＝定職の機会費用）
    case preoccupyNextWeek(Int)       // 指定週だけ稽古を拘束（0022A・UI層で稽古ロック＆週送り減算・golden非対象）
}

extension GameState {
    /// イベントの確定効果を1件適用（RNG非消費・成長逓減/予算を通さない純加減算＋clamp）。
    public mutating func applyEventEffect(_ e: EventEffect, config: GameConfig) {
        func bumpAbility(_ a: Ability, _ d: Double) {
            let cap = (a == .メンタル) ? config.mentalCap : config.abilityCap
            self[a] = max(0, min(cap, self[a] + d))
        }
        switch e {
        case .ability(let a, let d): bumpAbility(a, d)
        case .compat(let d):  compat = max(0, min(config.compatCap, compat + d))
        case .stamina(let d): stamina = max(0, min(100, stamina + d))
        case .fame(let d):    fame = max(0, min(100, fame + d))
        case .money(let d):   money += d
        case .weakestSkillPlus(let d):
            let skills: [Ability] = [.センス, .発想, .表現, .華]   // メンタル除外（0017: 相殺バグ回避）
            let weakest = skills.min(by: { self[$0] < self[$1] }) ?? .表現
            bumpAbility(weakest, d)
        case .weakerSenseIdeaPlus(let d):
            bumpAbility(self[.センス] <= self[.発想] ? .センス : .発想, d)
        case .compatFreeze(let w):
            compatFreezeWeeks = max(compatFreezeWeeks, w)   // 既に凍結中ならより長い方を残す
        case .netaBoostNextWeek(let w):
            netaBoostWeeks = max(netaBoostWeeks, w)         // 既にブースト中ならより長い方を残す
        case .growthCeiling(let d):
            // 成長天井（growthBudget）を増減。nil＝無制限（エンジン単体テスト）は対象外＝no-op。
            // 下限0（負に振り切っても既に使った分＝growthUsed は不動＝以後の伸びが止まるだけ）。
            if let b = growthBudget { growthBudget = max(0, b + d) }
        case .preoccupyNextWeek(let w):
            preoccupiedWeeks = max(preoccupiedWeeks, w)     // 既に拘束中ならより長い方を残す
        }
    }
}
