// CommandData.swift
// 週メインの行動カード（A「削る」スライス1・docs/fun_uiux_overhaul_v0.md §5-1 A列／§6-1）。
// 常設4枚（2×2）＝ネタを書く／相方と合わせる／舞台に立つ／休む。条件付きで、オファー週だけ「オファー」、
// 所持金が生活費1回分（config.livingCost）未満の時だけ「バイト」を足す。カードのタップ＝即実行（session.choose）。
// カードは既存の WeekAction へ写像するだけ（新しい行動・数値は足さない＝GameCore/golden 不変）。
// 伸びの表示は View 側で GameSession.previewAfterPour（RNG非消費）から出す。
// 旧版（カテゴリ5タイル⇄変種11枚の2段・のばす/ネタ帳タイル）は git 履歴を参照。

import SwiftUI
import GameCore

struct CommandVariant: Identifiable {
    let id: String            // DialogueData.reaction のキー互換（t_… / job_… / rest_… / offer）
    let name: String
    let desc: String
    let glyph: String
    let action: WeekAction    // タップ＝即実行の実体
    let isTrain: Bool         // 体力ゲート判定用（train かつ体力<staminaGate でグレー）
    var affordable: Bool = true
}

enum CommandCatalog {

    /// 常設の行動カード4枚（2×2・この順で左上→右下）。id は DialogueData.reaction のキー互換。
    static func mainCards(config: GameConfig, money: Int) -> [CommandVariant] {
        let trains: [(Training, String, String, String)] = [
            (.ネタ作り, "ネタを書く", "机に向かって書く", "pencil"),
            (.ネタ合わせ, "相方と合わせる", "二人で合わせる", "arrow.left.arrow.right"),
            (.フリーライブ, "舞台に立つ", "客前で場数を踏む", "mic.fill"),
        ]
        var cards: [CommandVariant] = trains.compactMap { t, name, desc, glyph in
            guard let spec = config.trainings[t] else { return nil }
            return CommandVariant(id: "t_\(t)", name: name, desc: desc, glyph: glyph,
                                  action: .train(t), isTrain: true, affordable: spec.cost <= 0 || money >= spec.cost)
        }
        cards.append(CommandVariant(id: "rest_\(Rest.完全休養)", name: "休む", desc: "回復 大", glyph: "moon.zzz.fill",
                                    action: .rest(.完全休養), isTrain: false))
        return cards
    }

    /// 条件付きのカード（最下段に小さく足す）。オファー週だけオファー／所持金が生活費1回分未満の時だけバイト。
    static func extraCards(config: GameConfig, offer: OfferSpec?, money: Int) -> [CommandVariant] {
        var cards: [CommandVariant] = []
        if let offer {
            cards.append(CommandVariant(id: "offer", name: "オファー", desc: offer.name,
                                        glyph: "star.circle.fill", action: .acceptOffer, isTrain: false))
        }
        if money < config.livingCost, config.jobs[.標準] != nil {
            cards.append(CommandVariant(id: "job_\(Job.標準)", name: "バイト", desc: "居酒屋",
                                        glyph: "yensign.circle.fill", action: .job(.標準), isTrain: false))
        }
        return cards
    }
}
