// ChoiceEventLate.swift（終盤イベント40本の効果表・late_events_cand_1108・数値は全て【仮】）
// E1〜E20＝6年目以降／N1〜N20＝11年目以降（N17〜N20 は優勝経験者のみ＝GameSession 側の追加ゲート）。
// 効果は docs/late_game_content_v0.md §2・docs/late_game_events_draft_1107.md の下書きどおり。お金が減る選択肢は所持金が足りない時は灰色（gate）。
// sim 側の同じ表は tools/late_events_data.py。RandomSource を呼ばない決定的な加減算＝golden 不変。

extension ChoiceEventKind {
    /// 終盤イベント（6年目以降／11年目以降）か
    public var isLateEvent: Bool { lateEventMinYear != nil }
    /// 出る最初の年（1始まり）。終盤イベント以外は nil
    public var lateEventMinYear: Int? {
        switch self {
        case .lateE01, .lateE02, .lateE03, .lateE04, .lateE05, .lateE06, .lateE07, .lateE08, .lateE09, .lateE10, .lateE11, .lateE12, .lateE13, .lateE14, .lateE15, .lateE16, .lateE17, .lateE18, .lateE19, .lateE20:
            return 6
        case .lateN01, .lateN02, .lateN03, .lateN04, .lateN05, .lateN06, .lateN07, .lateN08, .lateN09, .lateN10, .lateN11, .lateN12, .lateN13, .lateN14, .lateN15, .lateN16, .lateN17, .lateN18, .lateN19, .lateN20:
            return 11
        default:
            return nil
        }
    }
    /// 優勝を1度でも経験した人だけに出る（N17〜N20・GameSession の yearHistory で判定）
    public var lateEventNeedsChampion: Bool {
        switch self {
        case .lateN17, .lateN18, .lateN19, .lateN20:
            return true
        default:
            return false
        }
    }
}

extension ChoiceEventTable {
    /// 終盤イベントの選択肢。終盤イベント以外は空
    static func lateChoices(for kind: ChoiceEventKind) -> [ChoiceEventChoice] {
        switch kind {
        case .lateE01:  // E1 後輩の相談
            return [
                ChoiceEventChoice(id: "A", effects: [.ability(.メンタル, 1), .stamina(-10), .fame(1)]),
                ChoiceEventChoice(id: "B", effects: [.stamina(5)]),
            ]
        case .lateE02:  // E2 後輩に抜かれる
            return [
                ChoiceEventChoice(id: "A", effects: [.ability(.メンタル, 1), .fame(1), .stamina(-5)]),
                ChoiceEventChoice(id: "B", effects: [.stamina(10), .ability(.メンタル, -1)]),
            ]
        case .lateE03:  // E3 先輩が売れる
            return [
                ChoiceEventChoice(id: "A", effects: [.fame(1), .money(-3_000)], gate: { $0.money >= 3_000 }),
                ChoiceEventChoice(id: "B", effects: [.ability(.メンタル, -1), .stamina(5)]),
            ]
        case .lateE04:  // E4 先輩が辞める
            return [
                ChoiceEventChoice(id: "A", effects: [.ability(.メンタル, 1), .compat(1), .stamina(-10)]),
                ChoiceEventChoice(id: "B", effects: [.stamina(5), .ability(.センス, 1)]),
            ]
        case .lateE05:  // E5 実家からの電話
            return [
                ChoiceEventChoice(id: "A", effects: [.ability(.メンタル, 2), .money(-8_000), .stamina(-5)], gate: { $0.money >= 8_000 }),
                ChoiceEventChoice(id: "B", effects: [.ability(.表現, 1), .ability(.メンタル, -1)]),
            ]
        case .lateE06:  // E6 親の体調
            return [
                ChoiceEventChoice(id: "A", effects: [.ability(.メンタル, 2), .stamina(-10)]),
                ChoiceEventChoice(id: "B", effects: [.stamina(15), .money(-3_000)], gate: { $0.money >= 3_000 }),
            ]
        case .lateE07:  // E7 同期の解散
            return [
                ChoiceEventChoice(id: "A", effects: [.ability(.メンタル, 1), .ability(.発想, 1), .stamina(-10), .money(-2_000)], gate: { $0.money >= 2_000 }),
                ChoiceEventChoice(id: "B", effects: [.ability(.センス, 1), .ability(.メンタル, -1)]),
            ]
        case .lateE08:  // E8 同期のコンビ再結成
            return [
                ChoiceEventChoice(id: "A", effects: [.fame(1), .stamina(-10)]),
                ChoiceEventChoice(id: "B", effects: [.stamina(5), .ability(.メンタル, 1)]),
            ]
        case .lateE09:  // E9 初めての会議室
            return [
                ChoiceEventChoice(id: "A", effects: [.fame(2), .money(10_000), .stamina(-10)]),
                ChoiceEventChoice(id: "B", effects: [.ability(.表現, 1), .ability(.メンタル, 1)]),
            ]
        case .lateE10:  // E10 編集で消えた場面
            return [
                ChoiceEventChoice(id: "A", effects: [.ability(.センス, 1), .stamina(-10)]),
                ChoiceEventChoice(id: "B", effects: [.stamina(10), .ability(.メンタル, 1)]),
            ]
        case .lateE11:  // E11 昔のネタの依頼
            return [
                ChoiceEventChoice(id: "A", effects: [.money(12_000), .fame(1), .stamina(-5)]),
                ChoiceEventChoice(id: "B", effects: [.ability(.発想, 1), .ability(.メンタル, 1)]),
            ]
        case .lateE12:  // E12 ネタ帳が一冊分たまった
            return [
                ChoiceEventChoice(id: "A", effects: [.ability(.発想, 1), .ability(.センス, 1), .stamina(-10)]),
                ChoiceEventChoice(id: "B", effects: [.ability(.メンタル, 1), .stamina(-5)]),
            ]
        case .lateE13:  // E13 階段で息が切れる
            return [
                ChoiceEventChoice(id: "A", effects: [.stamina(10), .compat(1)]),
                ChoiceEventChoice(id: "B", effects: [.ability(.表現, 1), .stamina(-10)]),
            ]
        case .lateE14:  // E14 健康診断の結果
            return [
                ChoiceEventChoice(id: "A", effects: [.stamina(10), .ability(.メンタル, 1), .money(-3_000)], gate: { $0.money >= 3_000 }),
                ChoiceEventChoice(id: "B", effects: [.stamina(-5), .ability(.メンタル, -1)]),
            ]
        case .lateE15:  // E15 劇場の若い客
            return [
                ChoiceEventChoice(id: "A", effects: [.fame(2), .stamina(-10)]),
                ChoiceEventChoice(id: "B", effects: [.ability(.メンタル, 1), .compat(1)]),
            ]
        case .lateE16:  // E16 中堅の肩書き
            return [
                ChoiceEventChoice(id: "A", effects: [.ability(.センス, 1), .ability(.メンタル, -1), .stamina(-10), .money(8_000)]),
                ChoiceEventChoice(id: "B", effects: [.ability(.表現, 1), .ability(.メンタル, 1)]),
            ]
        case .lateE17:  // E17 長い休みの提案
            return [
                ChoiceEventChoice(id: "A", effects: [.stamina(20), .ability(.メンタル, 2), .money(-5_000)], gate: { $0.money >= 5_000 }),
                ChoiceEventChoice(id: "B", effects: [.ability(.発想, 1), .stamina(-10)]),
            ]
        case .lateE18:  // E18 事務所の新しい契約
            return [
                ChoiceEventChoice(id: "A", effects: [.money(15_000), .stamina(-10), .ability(.メンタル, -1)]),
                ChoiceEventChoice(id: "B", effects: [.stamina(5), .ability(.メンタル, 1)]),
            ]
        case .lateE19:  // E19 同じ劇場の閉館
            return [
                ChoiceEventChoice(id: "A", effects: [.fame(1), .ability(.メンタル, 2), .stamina(-15)]),
                ChoiceEventChoice(id: "B", effects: [.ability(.センス, 1), .ability(.メンタル, 1)]),
            ]
        case .lateE20:  // E20 十年目の写真
            return [
                ChoiceEventChoice(id: "A", effects: [.ability(.メンタル, 2), .compat(1)]),
                ChoiceEventChoice(id: "B", effects: [.stamina(5), .ability(.発想, 1)]),
            ]
        case .lateN01:  // N1 小さな取材
            return [
                ChoiceEventChoice(id: "A", effects: [.fame(1), .stamina(-5)]),
                ChoiceEventChoice(id: "B", effects: [.stamina(5), .ability(.メンタル, 1)]),
            ]
        case .lateN02:  // N2 ラジオの代役
            return [
                ChoiceEventChoice(id: "A", effects: [.money(10_000), .stamina(-10), .fame(1)]),
                ChoiceEventChoice(id: "B", effects: [.stamina(10)]),
            ]
        case .lateN03:  // N3 小学校の公演
            return [
                ChoiceEventChoice(id: "A", effects: [.fame(1), .stamina(-10), .money(5_000)]),
                ChoiceEventChoice(id: "B", effects: [.ability(.メンタル, 1), .stamina(-5)]),
            ]
        case .lateN04:  // N4 若手大会の審査員
            return [
                ChoiceEventChoice(id: "A", effects: [.ability(.発想, 1), .fame(1), .stamina(-5)]),
                ChoiceEventChoice(id: "B", effects: [.ability(.メンタル, 1), .stamina(5)]),
            ]
        case .lateN05:  // N5 稽古場の更新
            return [
                ChoiceEventChoice(id: "A", effects: [.money(-10_000), .compat(1)], gate: { $0.money >= 10_000 }),
                ChoiceEventChoice(id: "B", effects: [.stamina(-10)]),
            ]
        case .lateN06:  // N6 声がかすれる
            return [
                ChoiceEventChoice(id: "A", effects: [.ability(.メンタル, 1), .stamina(-5)]),
                ChoiceEventChoice(id: "B", effects: [.stamina(10), .ability(.メンタル, -1)]),
            ]
        case .lateN07:  // N7 客席が空いた日
            return [
                ChoiceEventChoice(id: "A", effects: [.ability(.メンタル, 2), .stamina(-5)]),
                ChoiceEventChoice(id: "B", effects: [.stamina(10), .ability(.メンタル, -1)]),
            ]
        case .lateN08:  // N8 谷口にナレーションの話
            return [
                ChoiceEventChoice(id: "A", effects: [.money(10_000), .compat(1), .stamina(-5)]),
                ChoiceEventChoice(id: "B", effects: [.ability(.発想, 1)]),
            ]
        case .lateN09:  // N9 ファンレター
            return [
                ChoiceEventChoice(id: "A", effects: [.ability(.メンタル, 2), .compat(1)]),
                ChoiceEventChoice(id: "B", effects: [.stamina(5), .ability(.メンタル, 1)]),
            ]
        case .lateN10:  // N10 商店街の店主の言葉
            return [
                ChoiceEventChoice(id: "A", effects: [.ability(.メンタル, 1), .stamina(5)]),
                ChoiceEventChoice(id: "B", effects: [.fame(1)]),
            ]
        case .lateN11:  // N11 定食屋の前で
            return [
                ChoiceEventChoice(id: "A", effects: [.fame(1), .stamina(-5)]),
                ChoiceEventChoice(id: "B", effects: [.ability(.メンタル, 1), .compat(1)]),
            ]
        case .lateN12:  // N12 年末の事務所の幹事
            return [
                ChoiceEventChoice(id: "A", effects: [.fame(1), .stamina(-10)]),
                ChoiceEventChoice(id: "B", effects: [.stamina(5)]),
            ]
        case .lateN13:  // N13 新しい衣装
            return [
                ChoiceEventChoice(id: "A", effects: [.money(-10_000), .ability(.メンタル, 1), .compat(1)], gate: { $0.money >= 10_000 }),
                ChoiceEventChoice(id: "B", effects: [.stamina(5)]),
            ]
        case .lateN14:  // N14 会社の新人研修
            return [
                ChoiceEventChoice(id: "A", effects: [.fame(1), .ability(.メンタル, 1), .stamina(-5)]),
                ChoiceEventChoice(id: "B", effects: [.stamina(5)]),
            ]
        case .lateN15:  // N15 配信ライブの提案
            return [
                ChoiceEventChoice(id: "A", effects: [.money(10_000), .fame(1), .stamina(-10)]),
                ChoiceEventChoice(id: "B", effects: [.ability(.メンタル, 1), .stamina(5)]),
            ]
        case .lateN16:  // N16 倉庫から出てきた録音
            return [
                ChoiceEventChoice(id: "A", effects: [.compat(1), .stamina(-5)]),
                ChoiceEventChoice(id: "B", effects: [.ability(.メンタル, 1), .stamina(5)]),
            ]
        case .lateN17:  // N17 王者の重圧
            return [
                ChoiceEventChoice(id: "A", effects: [.ability(.発想, 1), .stamina(-10), .compat(1)]),
                ChoiceEventChoice(id: "B", effects: [.ability(.メンタル, 1), .stamina(5)]),
            ]
        case .lateN18:  // N18 王座を失った翌年
            return [
                ChoiceEventChoice(id: "A", effects: [.ability(.メンタル, 1), .stamina(-10), .ability(.発想, 1)]),
                ChoiceEventChoice(id: "B", effects: [.stamina(10), .ability(.メンタル, 1)]),
            ]
        case .lateN19:  // N19 連覇中の年の予定
            return [
                ChoiceEventChoice(id: "A", effects: [.ability(.発想, 1), .stamina(-10), .compat(1)]),
                ChoiceEventChoice(id: "B", effects: [.ability(.メンタル, 1), .stamina(5)]),
            ]
        case .lateN20:  // N20 受付の学生に聞かれる
            return [
                ChoiceEventChoice(id: "A", effects: [.compat(1), .ability(.メンタル, 1), .stamina(-5)]),
                ChoiceEventChoice(id: "B", effects: [.fame(1), .ability(.メンタル, 1), .stamina(-5)]),
            ]
        default:
            return []
        }
    }
}
