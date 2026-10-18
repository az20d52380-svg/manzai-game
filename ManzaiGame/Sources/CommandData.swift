// CommandData.swift
// 週メインの行動カード（A「削る」スライス1・docs/fun_uiux_overhaul_v0.md §5-1 A列／§6-1）。
// 常設4枚（2×2）＝ネタを書く／相方と合わせる／舞台に立つ／休む＋下段に小さく「バイト」（常設・オーナー判断 2026-10-08
// 「常備の方がゲームっぽい」）。オファー週だけ「オファー」を足す。カードのタップ＝即実行（session.choose）。
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

/// 週メインの4ボタン（パワプロのサクセス式・オーナー指示 2026-10-12）。押すと同じ場所が種類の一覧に切り替わる。
enum CommandCategory: String, CaseIterable, Identifiable {
    case ネタを書く, 練習, バイト, 休む, 能力アップ, お店   // ネタを書くは練習から独立・お店も並べる（オーナー 2026-10-12）
    var id: String { rawValue }
    var glyph: String {
        switch self {
        case .ネタを書く: return "square.and.pencil"
        case .練習: return "figure.mind.and.body"
        case .バイト: return "yensign.circle.fill"
        case .休む: return "moon.zzz.fill"
        case .能力アップ: return "arrow.up.circle.fill"
        case .お店: return "bag.fill"
        }
    }
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

    /// 種類の一覧（4ボタンの下位）。id は DialogueData.reaction のキー互換。名前は旧版（2028990^）と今の常設カードから。
    static func cards(_ cat: CommandCategory, config: GameConfig, money: Int) -> [CommandVariant] {
        switch cat {
        case .練習:
            let trains: [(Training, String, String, String)] = [
                (.ネタ合わせ, "相方と合わせる", "二人で合わせる", "arrow.left.arrow.right"),
                (.フリーライブ, "舞台に立つ", "客前で場数を踏む", "mic.fill"),
                (.ネタ見せ会, "ネタ見せ会", "作家の前で試す", "theatermasks.fill"),
                (.ランニング・サウナ, "エントリーライブに出る", "出演料を払って小さなライブに出る", "person.wave.2.fill"),
                (.作家の勉強会, "大喜利ライブに出る", "お題に答えて、ひらめきと言葉を鍛える", "book.fill"),
                (.ボイトレ, "カラオケボックスで声出し", "安い部屋を借りて声を通す練習", "waveform"),
            ]
            return trains.compactMap { t, name, desc, glyph in
                guard let spec = config.trainings[t] else { return nil }
                return CommandVariant(id: "t_\(t)", name: name, desc: desc, glyph: glyph,
                                      action: .train(t), isTrain: true, affordable: spec.cost <= 0 || money >= spec.cost)
            }
        case .バイト:
            let jobs: [(Job, String, String, String)] = [
                (.楽, "交通量調査", "座って数える", "car.fill"),
                (.標準, "居酒屋", "夜の立ち仕事", "fork.knife"),
                (.キツい, "引っ越し", "一日中運ぶ", "shippingbox.fill"),
            ]
            return jobs.compactMap { j, name, desc, glyph in
                guard config.jobs[j] != nil else { return nil }
                return CommandVariant(id: "job_\(j)", name: name, desc: desc, glyph: glyph, action: .job(j), isTrain: false)
            }
        case .休む:
            let rests: [(Rest, String, String, String)] = [
                (.完全休養, "家で寝る", "しっかり回復", "house.fill"),
                (.気分転換, "気分転換", "少し回復", "cup.and.saucer.fill"),
                (.相方と過ごす, "相方と過ごす", "少しだけ回復・相性", "figure.2"),
                (.サウナ, "サウナ", "家よりよく休める", "thermometer.sun.fill"),
                (.温泉に一泊, "温泉に一泊", "ほぼ全回復", "mountain.2.fill"),
            ]
            return rests.compactMap { r, name, desc, glyph in
                guard config.rests[r] != nil else { return nil }
                let cost = config.restCosts[r] ?? 0
                return CommandVariant(id: "rest_\(r)", name: name, desc: desc, glyph: glyph, action: .rest(r), isTrain: false,
                                      affordable: cost <= 0 || money >= cost)
            }
        case .ネタを書く, .能力アップ, .お店:
            return []   // ネタを書く＝ネタの一覧（WeekMainView.netaWriteList）／能力アップ＝AbilityUpView
        }
    }

    /// 「ネタを書く」の場所（オーナー確定 2026-10-13「家で書くとか喫茶店で書くとか、そういうふうに選んだら」）
    static func netaPlaces(config: GameConfig, money: Int) -> [CommandVariant] {
        let places: [(Training, String, String, String)] = [
            (.ネタ作り, "家で書く", "いつもの机で", "house.fill"),
            (.喫茶店で書く, "喫茶店で書く", "家より集中できる", "cup.and.saucer.fill"),
            (.ファミレスで書く, "ファミレスで朝まで", "安いけど疲れる", "fork.knife"),
        ]
        return places.compactMap { t, name, desc, glyph in
            guard let spec = config.trainings[t] else { return nil }
            return CommandVariant(id: "t_\(t)", name: name, desc: desc, glyph: glyph,
                                  action: .train(t), isTrain: true, affordable: spec.cost <= 0 || money >= spec.cost)
        }
    }

    /// 「ネタを書く」の実体（ネタの一覧から、選んだネタ／新ネタに対して実行する）
    static func netaWrite(config: GameConfig) -> CommandVariant? {
        guard config.trainings[.ネタ作り] != nil else { return nil }
        return CommandVariant(id: "t_\(Training.ネタ作り)", name: "ネタを書く", desc: "机に向かって書く", glyph: "pencil",
                              action: .train(.ネタ作り), isTrain: true)
    }

    /// 下段の小カード。オファー週だけオファー。
    /// キュー96：オファーは仕事の名前＋短い説明。続けて受けていて次に受けると腕が落ちる時（fatigued）は谷口の一言を足す
    static func offerBlurb(_ name: String) -> String {
        switch name {
        case "ひな壇": return "ひな壇に座って喋る。顔が売れて、喋りも磨かれる"
        case "ラジオ": return "ラジオで喋る。軽い仕事で、喋りが磨かれる"
        case "ロケ":   return "ロケに出る。お金になるけど、くたびれる"
        case "営業":   return "地方の営業回り。一番お金になる"
        default:       return name
        }
    }

    static func extraCards(config: GameConfig, offer: OfferSpec?, money: Int, fatigued: Bool = false) -> [CommandVariant] {
        var cards: [CommandVariant] = []
        if let offer {
            let blurb = offerBlurb(offer.name) + (fatigued ? "\n谷口「最近ネタやれてへんな」" : "")
            cards.append(CommandVariant(id: "offer", name: "オファー：\(offer.name)", desc: blurb,
                                        glyph: "star.circle.fill", action: .acceptOffer, isTrain: false))
        }
        return cards   // バイトは4ボタンの1つへ移した（2026-10-12）
    }
}
