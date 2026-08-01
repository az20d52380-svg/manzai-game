// TitleData.swift
// 称号（NotebookView きろく・YearResultView・TournamentResultView の報酬チップで表示）。
// 表示層の純データ＋純関数のみ＝RNG非消費・GameCore非接触・golden不変。名称は全て【仮】・実在大会名は不使用。
// ⚠️ 道中大会名の文字列は Calendar.swift（GameCore）の正典名と一致させる（大会名を変えたら両方直す）。
// tone: gold=栄誉（優勝・決勝進出級）／verm=通過・達成系／ink=傷跡系（敗者復活・解散・夜逃げ＝ポップさせず静かに刻む）。

import SwiftUI
import GameCore

enum TitleID: String, Codable, CaseIterable {
    case firstPass          // 初通過（最初の本番通過）
    case springA, springB, midsummer, ebisu, youngLtd, recommended   // 道中6大会の優勝
    case doubleCrown, tripleCrown   // 道中大会の優勝2つ目・3つ目
    case quarterfinalist    // GP3回戦を通過＝準々決勝進出
    case semifinalist       // GP準々決勝を通過＝準決勝進出
    case finalist           // GP準決勝 or 敗者復活を通過＝決勝進出
    case revivalStage       // 敗者復活の舞台に立った（勝敗問わず・傷跡系）
    case champion           // 優勝
    case firstMillion       // 賞金年計100万到達
    case fullYear           // 一年を走り切った（優勝・夜逃げ以外の年末）
    case dissolution        // 解散年（相性が最後まで低い）
    case nightFlight        // 夜逃げ
}

/// 獲得済み称号（獲得週つき）。Codable=中断セーブ（GameSession.SaveData にオプショナルで載る）。
struct EarnedTitle: Codable, Identifiable {
    let id: TitleID
    let week: Int
}

enum TitleTone {
    case gold, verm, ink
    var color: Color {
        switch self {
        case .gold: return Theme.goldD
        case .verm: return Theme.verm
        case .ink: return Theme.inkDim
        }
    }
}

struct TitleSpec {
    let name: String
    let tone: TitleTone
}

enum TitleData {

    static func spec(_ id: TitleID) -> TitleSpec {
        switch id {
        case .firstPass:      return TitleSpec(name: "初通過", tone: .verm)
        case .springA:        return TitleSpec(name: "春新人賞A 優勝", tone: .gold)
        case .springB:        return TitleSpec(name: "春新人賞B 優勝", tone: .gold)
        case .midsummer:      return TitleSpec(name: "夏中堅賞 優勝", tone: .gold)
        case .ebisu:          return TitleSpec(name: "大阪戎コンクール 優勝", tone: .gold)
        case .youngLtd:       return TitleSpec(name: "若手限定賞 優勝", tone: .gold)
        case .recommended:    return TitleSpec(name: "推薦制中堅賞 優勝", tone: .gold)
        case .doubleCrown:    return TitleSpec(name: "二冠", tone: .gold)
        case .tripleCrown:    return TitleSpec(name: "三冠", tone: .gold)
        case .quarterfinalist: return TitleSpec(name: "準々決勝進出", tone: .verm)
        case .semifinalist:   return TitleSpec(name: "準決勝進出", tone: .verm)
        case .finalist:       return TitleSpec(name: "決勝進出", tone: .gold)
        case .revivalStage:   return TitleSpec(name: "敗者復活", tone: .ink)
        case .champion:       return TitleSpec(name: "頂", tone: .gold)
        case .firstMillion:   return TitleSpec(name: "賞金100万", tone: .verm)
        case .fullYear:       return TitleSpec(name: "一年完走", tone: .verm)
        case .dissolution:    return TitleSpec(name: "解散", tone: .ink)
        case .nightFlight:    return TitleSpec(name: "夜逃げ", tone: .ink)
        }
    }

    /// 道中大会名→称号（Calendar.swift の正典名と1対1。名前ヒューリスティックはここに閉じ込める）
    private static let midTournamentTitle: [String: TitleID] = [
        "春新人賞A": .springA,
        "春新人賞B": .springB,
        "夏中堅賞": .midsummer,
        "大阪戎コンクール": .ebisu,
        "若手限定賞": .youngLtd,
        "推薦制中堅賞": .recommended,
    ]

    /// 大会週の称号判定（純関数・RNG非消費）。earned に無いものだけ新規獲得として返す。
    /// GP回戦名（"GP3回戦"等）は Calendar.swift の gpRoundNames と一致させる。
    static func stageAwards(result r: StageResult, isMidTournament: Bool,
                            earned: Set<TitleID>, totalPrize: Int) -> [TitleID] {
        var out: [TitleID] = []
        var have = earned
        func grant(_ id: TitleID) { if have.insert(id).inserted { out.append(id) } }

        if r.isStage, r.passed { grant(.firstPass) }
        if isMidTournament, r.passed, let t = midTournamentTitle[r.name] {
            grant(t)
            let crowns = midTournamentTitle.values.filter { have.contains($0) }.count
            if crowns >= 2 { grant(.doubleCrown) }
            if crowns >= 3 { grant(.tripleCrown) }
        }
        if !isMidTournament {
            switch r.name {
            case "GP3回戦" where r.passed:    grant(.quarterfinalist)
            case "GP準々決勝" where r.passed: grant(.semifinalist)
            case "GP準決勝" where r.passed:   grant(.finalist)
            case "敗者復活":
                grant(.revivalStage)               // 立った事実を刻む（勝敗問わず・傷跡系）
                if r.passed { grant(.finalist) }
            default: break
            }
        }
        if totalPrize >= 1_000_000 { grant(.firstMillion) }   // 【仮】年計100万の節目
        return out
    }

    /// 年末の称号判定（純関数）。champion 年は fullYear を出さない（週47で年が閉じる＝完走と意味が違う）。
    static func yearEndAwards(outcome o: YearOutcome, state: GameState, earned: Set<TitleID>) -> [TitleID] {
        var out: [TitleID] = []
        var have = earned
        func grant(_ id: TitleID) { if have.insert(id).inserted { out.append(id) } }
        if o.champion { grant(.champion) }
        if o.bankrupt { grant(.nightFlight) }
        else if !o.champion { grant(.fullYear) }
        if isDissolutionYear(outcome: o, state: state) { grant(.dissolution) }
        return out
    }

    /// 解散年の判定（YearResultView の年次独白分岐と同一条件・閾値【仮】＝単一ソース）。
    static func isDissolutionYear(outcome o: YearOutcome, state: GameState) -> Bool {
        !o.champion && !o.reachedFinal && state.compat < 10
    }
}
