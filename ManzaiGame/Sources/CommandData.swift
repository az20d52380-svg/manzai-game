// CommandData.swift
// 育成メインの練習コマンド・タイル（mockup SCREEN 01）。実アクションは GameCore に配線し、
// 「どの能力が伸びるか（色ドット）＋おおよその量＋コスト」を GameConfig から算出して表示する。
// 数値表示は「出す派」＝パワプロ サクセス式（ui_design 数値表示の方針【確定】）。

import SwiftUI
import GameCore

/// 獲得プレビューの1チップ（能力名＋色＋おおよその量）
struct GainChip: Identifiable {
    let id = UUID()
    let label: String
    let color: Color
    let amount: String   // "+3" や "+¥8万" 等（成長逓減があるので目安）
}

struct CommandTile: Identifiable {
    let id: String
    let title: String
    let glyph: String          // SF Symbol名
    let action: WeekAction
    let dotColors: [Color]     // 伸びる能力の色ドット
    let costText: String       // 体力/金コスト（タイル下）
    let costIsUp: Bool         // 回復・収入など＋方向
    let gains: [GainChip]      // 選択時の獲得プレビュー
}

enum CommandCatalog {

    /// StatKey → (表示名, 色)
    static func meta(_ key: StatKey) -> (String, Color) {
        switch key {
        case .ability(let a): return ("\(a)", Theme.abilityColor(a))
        case .コンビ相性: return ("相性", Theme.cCompat)
        case .体力: return ("体力", Theme.cMental)
        case .知名度: return ("知名度", Theme.gold)
        }
    }

    /// GameConfig から当週のタイル一覧を組む（オファーがある週は先頭に「仕事を受ける」）
    static func tiles(config: GameConfig, offer: OfferSpec?) -> [CommandTile] {
        var tiles: [CommandTile] = []

        if let offer {
            tiles.append(CommandTile(
                id: "offer", title: "仕事を受ける", glyph: "briefcase.fill",
                action: .acceptOffer, dotColors: [Theme.cMoney, Theme.gold],
                costText: "+¥\(offer.income / 10000)万", costIsUp: true,
                gains: [GainChip(label: offer.name, color: Theme.gold, amount: "+¥\(offer.income / 10000)万")]))
        }

        // 稽古5種
        for t in [Training.ネタ作り, .ネタ見せ会, .ネタ合わせ, .ランニング・サウナ, .フリーライブ] {
            guard let spec = config.trainings[t] else { continue }
            var dots: [Color] = []
            var gains: [GainChip] = []
            let (mName, mColor) = meta(spec.main.0)
            dots.append(mColor)
            gains.append(GainChip(label: mName, color: mColor, amount: "+\(fmt(spec.main.1))"))
            if let sub = spec.sub {
                let (sName, sColor) = meta(sub.0)
                dots.append(sColor)
                gains.append(GainChip(label: sName, color: sColor, amount: "+\(fmt(sub.1))"))
            }
            let cost = spec.cost > 0 ? "-¥\(spec.cost / 10000)万" : "体力 \(Int(spec.stamina))"
            tiles.append(CommandTile(
                id: "t_\(t)", title: glyphTitle(t).0, glyph: glyphTitle(t).1,
                action: .train(t), dotColors: dots,
                costText: cost, costIsUp: false, gains: gains))
        }

        // バイト（標準）
        if let job = config.jobs[.標準] {
            tiles.append(CommandTile(
                id: "job", title: "バイト", glyph: "yensign.circle.fill",
                action: .job(.標準), dotColors: [Theme.cMoney],
                costText: "+¥\(job.income / 10000)万", costIsUp: true,
                gains: [GainChip(label: "お金", color: Theme.cMoney, amount: "+¥\(job.income / 10000)万"),
                        GainChip(label: "体力", color: Theme.inkDim, amount: "\(Int(job.stamina))")]))
        }

        // 休む（完全休養）
        if let rest = config.rests[.完全休養] {
            let (bName, bColor) = meta(rest.bonus.0)
            tiles.append(CommandTile(
                id: "rest", title: "休む", glyph: "moon.zzz.fill",
                action: .rest(.完全休養), dotColors: [Theme.cMental],
                costText: "体力回復", costIsUp: true,
                gains: [GainChip(label: "体力", color: Theme.cMental, amount: "+\(Int(rest.recovery))"),
                        GainChip(label: bName, color: bColor, amount: "+\(fmt(rest.bonus.1))")]))
        }

        // 相方と過ごす
        if let rest = config.rests[.相方と過ごす] {
            let (bName, bColor) = meta(rest.bonus.0)
            tiles.append(CommandTile(
                id: "aikata", title: "相方と過ごす", glyph: "person.2.fill",
                action: .rest(.相方と過ごす), dotColors: [Theme.cCompat],
                costText: "体力回復", costIsUp: true,
                gains: [GainChip(label: "体力", color: Theme.cMental, amount: "+\(Int(rest.recovery))"),
                        GainChip(label: bName, color: bColor, amount: "+\(fmt(rest.bonus.1))")]))
        }

        return tiles
    }

    private static func fmt(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.0f", v)
    }

    private static func glyphTitle(_ t: Training) -> (String, String) {
        switch t {
        case .ネタ作り: return ("ネタ作り", "pencil")
        case .ネタ見せ会: return ("ネタ見せ会", "theatermasks.fill")
        case .ネタ合わせ: return ("ネタ合わせ", "arrow.left.arrow.right")
        case .ランニング・サウナ: return ("ランニング", "figure.run")
        case .フリーライブ: return ("フリーライブ", "mic.fill")
        }
    }
}
