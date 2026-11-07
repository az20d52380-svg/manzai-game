// Meta.swift
// 周回の配線（オーナー決定 11/07：トロフィーと図鑑を集めると次の周の最初の経験点・所持金・伸びしろの天井が増える）。
// 点の定義＝トロフィーpt（docs/trophy_design_v1.md の22個・30pt）＋図鑑の数（EndingBook・最大8）＝最大38
// （docs/calibration_meta_1102_v0.md §5 / kiritsu_a_1102_notes.md）。式側は GameState(config:metaPoints:)・表示専用の層（乱数・GameCore 不変）。
// 保存は EndingBook と同じ GameSession.store（UserDefaults）。周をまたいで残る。

import Foundation
import GameCore

/// トロフィー22個（rawValue は保存キー＝変えない）。pt は docs/trophy_design_v1.md §2（1pt×16・2pt×4・3pt×2＝30pt）
enum TrophyID: String, CaseIterable, Identifiable {
    case t01, t02, t03, t04, t05, t06, t07, t08, t09, t10, t11, t12, t13, t14, t15, t16, t17, t18, t19, t20, t21, t22
    var id: String { rawValue }

    var pt: Int {
        switch self {
        case .t17, .t18, .t19, .t20: 2
        case .t21, .t22: 3
        default: 1
        }
    }
    var title: String {
        switch self {
        case .t01: "初舞台の足音"
        case .t02: "二回戦の景色"
        case .t03: "冬の手前まで"
        case .t04: "準々の壁に爪痕"
        case .t05: "準決勝の空気"
        case .t06: "春一番"
        case .t07: "結成組の意地"
        case .t08: "真夏の頂"
        case .t09: "戎の福"
        case .t10: "五年目の全力"
        case .t11: "選ばれる側へ"
        case .t12: "夜行バスの常連"
        case .t13: "稽古の虫"
        case .t14: "阿吽の呼吸"
        case .t15: "満身創痍のセンターマイク"
        case .t16: "どん底からの声援"
        case .t17: "決勝の照明"
        case .t18: "十年選手"
        case .t19: "雨天決行"
        case .t20: "玉座奪還"
        case .t21: "敗者復活の奇跡"
        case .t22: "六冠の年"
        }
    }
    /// 取った後に読める条件（短く・標準語・％なし）
    var condition: String {
        switch self {
        case .t01: "GP1回戦を初めて通る"
        case .t02: "GP2回戦を初めて通る"
        case .t03: "GP3回戦を初めて通る"
        case .t04: "GP準々決勝を初めて通る"
        case .t05: "GP準決勝に初めて出る"
        case .t06: "春新人賞Aで優勝する"
        case .t07: "春新人賞Bで優勝する"
        case .t08: "夏中堅賞で優勝する"
        case .t09: "大阪戎コンクールで優勝する"
        case .t10: "若手限定賞で優勝する"
        case .t11: "推薦制中堅賞で優勝する"
        case .t12: "夜行バスで遠征を10回する"
        case .t13: "稽古を100回する"
        case .t14: "コンビの相性を上限まで育てる"
        case .t15: "体力が少ない状態で回戦を通る"
        case .t16: "所持金がマイナスのまま回戦を通る"
        case .t17: "GP決勝の舞台に初めて立つ"
        case .t18: "優勝しないまま最後の年まで走り切る"
        case .t19: "解散の危機を乗り越える"
        case .t20: "王座を失ってから、もう一度優勝する"
        case .t21: "敗者復活を通って決勝へ進む"
        case .t22: "同じ年に出た大会をすべて優勝し、GPも制する"
        }
    }
    /// 今のアプリで取れるか（解散危機の和解・王座陥落後の返り咲きは、まだ仕組みが無い）
    var obtainable: Bool { self != .t19 && self != .t20 }
}

/// 周をまたぐ記録（最多連覇・最速優勝・通算優勝）
struct CareerRecords: Codable, Equatable {
    var bestStreak = 0          // 最多連覇（年）
    var fastestWinYear: Int?    // 最速優勝（何年目）
    var totalWins = 0           // 通算優勝回数
    var hanaWins: Int? = nil    // THE HANA の通算優勝回数（女コンビだけ・nil＝旧データ）
}

enum TrophyBook {
    static let key = "mz.trophies"
    static let counterKey = "mz.trophyCounters"
    static let recordKey = "mz.careerRecords"
    private static var store: UserDefaults { GameSession.store }

    static func load() -> Set<TrophyID> {
        #if DEBUG
        if let s = ProcessInfo.processInfo.environment["MZ_TROPHIES"] {   // 目視用: MZ_TROPHIES=1,2,17（番号）で取得済み扱い（保存しない）
            return Set(s.split(separator: ",").compactMap { Int($0) }.compactMap { TrophyID(rawValue: String(format: "t%02d", $0)) })
        }
        #endif
        guard let data = store.data(forKey: key), let raw = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(raw.compactMap(TrophyID.init(rawValue:)))
    }

    /// 取ったら保存。初めて取れた時だけ true（再取得は無効＝ptは増えない）
    @discardableResult
    static func award(_ id: TrophyID) -> Bool {
        var all = load()
        guard all.insert(id).inserted else { return false }
        if let data = try? JSONEncoder().encode(all.map(\.rawValue).sorted()) { store.set(data, forKey: key) }
        return true
    }

    static var points: Int { load().reduce(0) { $0 + $1.pt } }

    // 通算カウンタ（夜行バス・稽古）
    static func counter(_ name: String) -> Int { (store.dictionary(forKey: counterKey) as? [String: Int])?[name] ?? 0 }
    @discardableResult
    static func bump(_ name: String) -> Int {
        var d = (store.dictionary(forKey: counterKey) as? [String: Int]) ?? [:]
        let n = d[name, default: 0] + 1
        d[name] = n
        store.set(d, forKey: counterKey)
        return n
    }

    static func loadRecords() -> CareerRecords {
        guard let data = store.data(forKey: recordKey), let r = try? JSONDecoder().decode(CareerRecords.self, from: data) else { return CareerRecords() }
        return r
    }
    /// 年末に優勝した時だけ呼ぶ（その年が何年目か・このキャリアで何連覇か）
    static func recordChampion(year: Int, streak: Int) {
        var r = loadRecords()
        r.totalWins += 1
        r.bestStreak = max(r.bestStreak, streak)
        r.fastestWinYear = min(r.fastestWinYear ?? Int.max, year)
        if let data = try? JSONEncoder().encode(r) { store.set(data, forKey: recordKey) }
    }

    /// THE HANA で優勝した時だけ呼ぶ
    static func recordHanaWin() {
        var r = loadRecords()
        r.hanaWins = (r.hanaWins ?? 0) + 1
        if let data = try? JSONEncoder().encode(r) { store.set(data, forKey: recordKey) }
    }

    // MARK: 判定（GameSession の各入力確定点から呼ぶ）

    /// 大会・GP回戦の結果1件。state は週末処理後
    static func onStage(_ r: StageResult, state: GameState, config: GameConfig) {
        if r.passed {
            switch r.name {
            case "GP1回戦": award(.t01)
            case "GP2回戦": award(.t02)
            case "GP3回戦": award(.t03)
            case "GP準々決勝": award(.t04)
            case "春新人賞A": award(.t06)
            case "春新人賞B": award(.t07)
            case "夏中堅賞": award(.t08)
            case "大阪戎コンクール": award(.t09)
            case "若手限定賞": award(.t10)
            case "推薦制中堅賞": award(.t11)
            case "敗者復活": award(.t21)
            case "HANA決勝": recordHanaWin()
            default: break
            }
            if r.name.hasPrefix("GP") || r.name == "敗者復活" {
                if state.stamina < 30 { award(.t15) }
                if state.money < 0 { award(.t16) }
            }
        }
        if r.name == "GP準決勝" { award(.t05) }
        if state.compat >= config.compatCap { award(.t14) }
    }

    /// 六冠の年の数え方：1件の結果が「出た大会」「優勝した大会」をいくつ増やすか。
    /// THE HANA は勝ち上がり戦なので1大会＝1回戦で「出た」・決勝の通過で「優勝」（回戦の通過を優勝に数えない）
    static func smallTournamentCount(_ r: StageResult) -> (entered: Int, won: Int) {
        if r.name.hasPrefix("GP") || r.name == "敗者復活" { return (0, 0) }
        if r.name.hasPrefix("HANA") {
            return (r.name == "HANA1回戦" ? 1 : 0, r.name == "HANA決勝" && r.passed ? 1 : 0)
        }
        return (1, r.passed ? 1 : 0)
    }

    /// 年末。smallEntered/smallWon＝その年の道中大会の出た数・優勝した数
    static func onYearEnd(outcome: YearOutcome, year: Int, careerYears: Int, smallEntered: Int, smallWon: Int) {
        if outcome.reachedFinal || outcome.champion { award(.t17) }
        if outcome.champion, smallEntered >= 5, smallWon == smallEntered { award(.t22) }
        if year >= careerYears, !outcome.champion, !outcome.bankrupt, !outcome.dissolved { award(.t18) }
    }
}

/// 周回の点と、それで増える物
enum MetaBook {
    /// 周回の点＝トロフィーpt＋図鑑の数（最大38）
    static var points: Int { TrophyBook.points + EndingBook.load().count }

    /// 次の周の初期ボーナスの見せ方（式は GameState.init と同じ。数だけ読む）
    struct Preview: Equatable {
        let points: Int
        let exp: Int
        let money: Int
    }
    static func preview(points p: Int, config: GameConfig = GameConfig()) -> Preview? {
        guard p > 0 else { return nil }
        let base = min(config.metaStartExpCap, config.metaStartExpPerPoint * Double(p))
        let top = config.metaStartExpTop * pow(Double(p) / config.metaTopPoints, config.metaTopExp)
        return Preview(points: p, exp: Int((base + top).rounded()), money: min(config.metaStartMoneyCap, config.metaStartMoneyPerPoint * p))
    }
    /// 周の始めに見せる短い文（標準語・％なし）。点0 は nil
    static func bannerLines(points p: Int) -> [String]? {
        guard let pv = preview(points: p) else { return nil }
        return ["これまでの実績が、二人の力になっています。",
                "はじめから 経験点 +\(pv.exp)／所持金 +\(pv.money / 10_000)万円",
                "年ごとの伸びしろの上限も、少し上がっています。"]
    }
}
