// CommandData.swift
// 育成メインの2段階コマンド（mvp_ui_build_prompt_v1 §5・mockup v3）。
// グループ（けいこ/しごと/休み）を押す→変種パネルがせり上がる→選ぶ→獲得プレビュー→つぎへ。
// 変種は実 GameCore アクション（5稽古・3バイト・3休み）に配線し【実数値】を表示。
// 【設計判断】mockup固有の場所別新経済（喫茶-¥500等）は golden/GameConfig に触れるため未採用（規律A・要相談）。

import SwiftUI
import GameCore

struct GainChip: Identifiable {
    let id = UUID()
    let label: String
    let color: Color
    let amount: String
}

struct CommandVariant: Identifiable {
    let id: String            // DialogueData.reaction のキーと一致（t_… / job_… / rest_… / offer）
    let name: String
    let desc: String
    let glyph: String
    let action: WeekAction
    let costText: String
    let costIsUp: Bool
    let eff: String
    let gains: [GainChip]
    var affordable: Bool = true
}

struct CommandGroup: Identifiable {
    let id: String
    let title: String
    let glyph: String
    let dotColors: [Color]
    let variants: [CommandVariant]
}

enum CommandCatalog {

    static func meta(_ key: StatKey) -> (String, Color) {
        switch key {
        case .ability(let a): return ("\(a)", Theme.abilityColor(a))
        case .コンビ相性: return ("相性", Theme.cCompat)
        case .体力: return ("体力", Theme.cMental)
        case .知名度: return ("知名度", Theme.gold)
        }
    }

    static func groups(config: GameConfig, offer: OfferSpec?, money: Int) -> [CommandGroup] {
        var groups: [CommandGroup] = []

        if let offer {
            groups.append(CommandGroup(id: "offer", title: "オファー", glyph: "star.circle.fill",
                dotColors: [Theme.gold], variants: [
                    CommandVariant(id: "offer", name: offer.name, desc: "仕事を受ける", glyph: "briefcase.fill",
                        action: .acceptOffer, costText: "+¥\(offer.income / 10000)万", costIsUp: true,
                        eff: "知名度＋", gains: [GainChip(label: "お金", color: Theme.cMoney, amount: "+¥\(offer.income / 10000)万")])
                ]))
        }

        // けいこ（5稽古）
        var keiko: [CommandVariant] = []
        let trainOrder: [(Training, String, String, String)] = [
            (.ネタ作り, "ネタ作り", "机に向かって書く", "pencil"),
            (.ネタ見せ会, "ネタ見せ会", "人前で試す", "theatermasks.fill"),
            (.ネタ合わせ, "ネタ合わせ", "二人で合わせる", "arrow.left.arrow.right"),
            (.ランニング・サウナ, "ランニング", "体と心を整える", "figure.run"),
            (.フリーライブ, "フリーライブ", "客前で場数を踏む", "mic.fill"),
        ]
        for (t, name, desc, glyph) in trainOrder {
            guard let spec = config.trainings[t] else { continue }
            var dots: [Color] = []; var gains: [GainChip] = []
            let (mName, mColor) = meta(spec.main.0)
            dots.append(mColor); gains.append(GainChip(label: mName, color: mColor, amount: "+\(fmt(spec.main.1))"))
            if let sub = spec.sub {
                let (sName, sColor) = meta(sub.0)
                dots.append(sColor); gains.append(GainChip(label: sName, color: sColor, amount: "+\(fmt(sub.1))"))
            }
            let paid = spec.cost > 0
            keiko.append(CommandVariant(id: "t_\(t)", name: name, desc: desc, glyph: glyph,
                action: .train(t),
                costText: paid ? "-¥\(spec.cost / 10000)万" : "体力 \(Int(spec.stamina))",
                costIsUp: false, eff: "\(mName)中心",
                gains: gains, affordable: !paid || money >= spec.cost))
        }
        groups.append(CommandGroup(id: "keiko", title: "けいこ", glyph: "pencil.and.outline",
                                   dotColors: [Theme.cSense, Theme.cIdea, Theme.cExpr], variants: keiko))

        // しごと（3バイト・実収入）
        let jobOrder: [(Job, String, String)] = [
            (.キツい, "引越し", "体力-大"), (.標準, "居酒屋", "体力-中"), (.楽, "交通量調査", "体力-小"),
        ]
        var shigoto: [CommandVariant] = []
        for (j, name, eff) in jobOrder {
            guard let spec = config.jobs[j] else { continue }
            shigoto.append(CommandVariant(id: "job_\(j)", name: name, desc: eff, glyph: "shippingbox.fill",
                action: .job(j), costText: "+¥\(spec.income / 10000)万", costIsUp: true, eff: eff,
                gains: [GainChip(label: "お金", color: Theme.cMoney, amount: "+¥\(spec.income / 10000)万"),
                        GainChip(label: "体力", color: Theme.inkDim, amount: "\(Int(spec.stamina))")]))
        }
        groups.append(CommandGroup(id: "shigoto", title: "しごと", glyph: "yensign.circle.fill",
                                   dotColors: [Theme.cMoney], variants: shigoto))

        // 休み（3休み）
        let restOrder: [(Rest, String, String)] = [
            (.完全休養, "自宅で休む", "回復 大"), (.気分転換, "気分転換", "回復 中"), (.相方と過ごす, "相方と過ごす", "回復 小・相性"),
        ]
        var yasumi: [CommandVariant] = []
        for (r, name, eff) in restOrder {
            guard let spec = config.rests[r] else { continue }
            let (bName, bColor) = meta(spec.bonus.0)
            yasumi.append(CommandVariant(id: "rest_\(r)", name: name, desc: eff, glyph: "moon.zzz.fill",
                action: .rest(r), costText: "体力回復", costIsUp: true, eff: eff,
                gains: [GainChip(label: "体力", color: Theme.cMental, amount: "+\(Int(spec.recovery))"),
                        GainChip(label: bName, color: bColor, amount: "+\(fmt(spec.bonus.1))")]))
        }
        groups.append(CommandGroup(id: "yasumi", title: "休み", glyph: "moon.zzz.fill",
                                   dotColors: [Theme.cMental], variants: yasumi))

        return groups
    }

    private static func fmt(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.0f", v)
    }
}
