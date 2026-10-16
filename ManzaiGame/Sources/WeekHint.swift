// WeekHint.swift
// 週メインの目標の帯の下に出す「今週はこれ」の理由の一行（表示専用・GameCoreの式・乱数には触れない）。
// 優先順で最初に当てはまる1つだけ。％・見込み・通過の可能性は出さない。台詞ではなく画面の案内の文。

import GameCore

enum WeekHint {
    struct Input {
        var netaCount: Int
        /// 次の大会までの週数と、その舞台の尺。次の大会が無ければ nil
        var stageWeeksLeft: Int? = nil
        var stageLength: NetaLength? = nil
        /// 選んでいるネタ（無ければ一番良いネタ）の尺が舞台の尺に合うか。ネタが無ければ nil
        var netaFitsStage: Bool? = nil
        var stamina: Double
        var livingThisWeek: Bool
        var money: Int
        var livingCost: Int
        var weeksWithoutPartner: Int
        /// 能力アップで押せる＋が1つ以上ある
        var plusAvailable: Bool
        /// 「経験点が残ってる」の朱の帯が出ている（出ているなら6は重ねない）
        var expBannerShown: Bool
    }

    static let staminaLow = 30.0
    static let stageNearWeeks = 4
    static let partnerGapWeeks = 6

    static func line(_ i: Input) -> String? {
        if i.netaCount == 0 { return "まだネタが無い。まずはネタを書こう。" }
        if let w = i.stageWeeksLeft, w <= stageNearWeeks, let len = i.stageLength, i.netaFitsStage == false {
            return "次の大会は尺『\(NetaCatalog.displayName(len))』。合うネタがまだ無い。"
        }
        if i.stamina <= staminaLow { return "体力が少ない。今週は休むのも手だ。" }
        if i.livingThisWeek, i.money < i.livingCost { return "今週末に生活費。所持金が足りない。" }
        if i.weeksWithoutPartner >= partnerGapWeeks { return "最近、相方とゆっくり話していない。" }
        if i.plusAvailable, !i.expBannerShown { return "経験点で上げられる能力がある。" }
        return nil
    }
}
