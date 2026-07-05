// CommandData.swift
// v8育成メインのコマンドカタログ。カテゴリ（稽古/回復/バイト/データ/アイテム[＋オファー]）を押す→
// 変種カードの横スクロール列がせり上がる→カードのタップ＝即実行（session.choose）。決定ボタンは無い。
// 変種は実 GameCore アクション（5稽古・3バイト・3休み・オファー）に配線し、伸びの数値は View 側で
// GameSession.previewState（RNG非消費）から「現在値の整数→実行後の整数の差」で出す（怪我率・稽古Lvは出さない）。
// データ/アイテムは kind=.info の「器だけ」（variants空・押すと準備中パネル・WeekActionを持たない＝週を進めない）。
// 【設計判断】mockup固有の場所別新経済（喫茶-¥500等）は golden/GameConfig に触れるため未採用（規律A・要相談）。

import SwiftUI
import GameCore

/// カテゴリの種別。act=行動（カード=即 session.choose）／info=器のみ（準備中パネルを出すだけ・週を進めない）。
enum CommandKind { case act, info }

struct CommandVariant: Identifiable {
    let id: String            // DialogueData.reaction のキー互換（t_… / job_… / rest_… / offer）
    let name: String
    let desc: String
    let glyph: String
    let action: WeekAction    // タップ＝即実行の実体
    let isTrain: Bool         // 体力ゲート判定用（train かつ体力<staminaGate でグレー）
    var affordable: Bool = true
}

struct CommandGroup: Identifiable {
    let id: String
    let title: String
    let glyph: String
    let kind: CommandKind
    let dotColors: [Color]
    let variants: [CommandVariant]
}

enum CommandCatalog {

    /// v8の5カテゴリ（稽古/回復/バイト/データ/アイテム）＋ offer!=nil の週だけ「オファー」を先頭に条件表示。
    /// 数値ソース（config.trainings/jobs/rests）と WeekAction 配線は現行から完全据え置き。
    static func groups(config: GameConfig, offer: OfferSpec?, money: Int) -> [CommandGroup] {
        var groups: [CommandGroup] = []

        // オファー（offer!=nil の週のみ・条件表示）
        // 【設計判断・要記録】v8モックの5アイコンにオファー枠は無いが、acceptOffer は実phase入力のため
        //   既存API（session.choose(.acceptOffer)）を保持する目的で6枚目を条件表示する（モックからの意図的逸脱）。
        if let offer {
            groups.append(CommandGroup(id: "offer", title: "オファー", glyph: "star.circle.fill", kind: .act,
                dotColors: [Theme.gold], variants: [
                    CommandVariant(id: "offer", name: offer.name, desc: "仕事を受ける",
                                   glyph: "briefcase.fill", action: .acceptOffer, isTrain: false)
                ]))
        }

        // 稽古（5 Training）
        let trainOrder: [(Training, String, String, String)] = [
            (.ネタ作り, "ネタ作り", "机に向かって書く", "pencil"),
            (.ネタ見せ会, "ネタ見せ会", "人前で試す", "theatermasks.fill"),
            (.ネタ合わせ, "ネタ合わせ", "二人で合わせる", "arrow.left.arrow.right"),
            (.ランニング・サウナ, "ランニング", "体と心を整える", "figure.run"),
            (.フリーライブ, "フリーライブ", "客前で場数を踏む", "mic.fill"),
        ]
        var keiko: [CommandVariant] = []
        for (t, name, desc, glyph) in trainOrder {
            guard let spec = config.trainings[t] else { continue }
            let paid = spec.cost > 0
            keiko.append(CommandVariant(id: "t_\(t)", name: name, desc: desc, glyph: glyph,
                action: .train(t), isTrain: true, affordable: !paid || money >= spec.cost))
        }
        groups.append(CommandGroup(id: "keiko", title: "稽古", glyph: "pencil.and.outline", kind: .act,
                                   dotColors: [Theme.cSense, Theme.cIdea, Theme.cExpr], variants: keiko))

        // 回復（3 Rest）
        let restOrder: [(Rest, String, String, String)] = [
            (.完全休養, "自宅で休む", "回復 大", "house.fill"),
            (.気分転換, "気分転換", "回復 中", "cup.and.saucer.fill"),
            (.相方と過ごす, "相方と過ごす", "回復 小・相性", "figure.2"),
        ]
        var kaifuku: [CommandVariant] = []
        for (r, name, desc, glyph) in restOrder {
            guard config.rests[r] != nil else { continue }
            kaifuku.append(CommandVariant(id: "rest_\(r)", name: name, desc: desc, glyph: glyph,
                action: .rest(r), isTrain: false))
        }
        groups.append(CommandGroup(id: "kaifuku", title: "回復", glyph: "moon.zzz.fill", kind: .act,
                                   dotColors: [Theme.night, Theme.cMental], variants: kaifuku))

        // バイト（3 Job）
        let jobOrder: [(Job, String, String, String)] = [
            (.キツい, "引越し", "体力-大", "shippingbox.fill"),
            (.標準, "居酒屋", "体力-中", "fork.knife"),
            (.楽, "交通量調査", "体力-小", "car.fill"),
        ]
        var baito: [CommandVariant] = []
        for (j, name, desc, glyph) in jobOrder {
            guard config.jobs[j] != nil else { continue }
            baito.append(CommandVariant(id: "job_\(j)", name: name, desc: desc, glyph: glyph,
                action: .job(j), isTrain: false))
        }
        groups.append(CommandGroup(id: "baito", title: "バイト", glyph: "yensign.circle.fill", kind: .act,
                                   dotColors: [Theme.cMoney], variants: baito))

        // データ（器のみ・準備中）: 押しても session.choose を呼ばない＝週は進まない。
        groups.append(CommandGroup(id: "data", title: "データ", glyph: "chart.bar.fill", kind: .info,
                                   dotColors: [Theme.inkFaint], variants: []))
        // アイテム（器のみ・準備中）
        groups.append(CommandGroup(id: "item", title: "アイテム", glyph: "shippingbox", kind: .info,
                                   dotColors: [Theme.inkFaint], variants: []))

        return groups
    }
}
