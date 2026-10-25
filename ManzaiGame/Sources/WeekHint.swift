// WeekHint.swift
// 週メインの目標の帯の下に出す「今週はこれ」の理由の一行（表示専用・GameCoreの式・乱数には触れない）。
// 優先順で最初に当てはまる1つだけ。％・見込み・通過の可能性は出さない。台詞ではなく画面の案内の文。

import Foundation
import GameCore

enum WeekHint {
    struct Input {
        var netaCount: Int
        /// 撮影などで今週は稽古に出られない（preoccupiedWeeks>0）。この週は「ネタを書こう」と促さない（playtest_v13 §2-3）
        var preoccupied: Bool = false
        /// 次の大会までの週数と、その舞台の尺。次の大会が無ければ nil
        var stageWeeksLeft: Int? = nil
        var stageLength: NetaLength? = nil
        /// 選んでいるネタ（無ければ一番良いネタ）の尺が舞台の尺に合うか。ネタが無ければ nil
        var netaFitsStage: Bool? = nil
        var stamina: Double
        var livingThisWeek: Bool
        /// 再来週が生活費の週（予告用）
        var livingInTwoWeeks: Bool = false
        var money: Int
        var livingCost: Int
        var weeksWithoutPartner: Int
        /// 能力アップで押せる＋が1つ以上ある
        var plusAvailable: Bool
        /// 「経験点が残ってる」の朱の帯が出ている（出ているなら6は重ねない）
        var expBannerShown: Bool
    }

    static let staminaLow = 30.0
    static let injuryWarn = GameConfig().injuryThreshold   // 体調ダウンの対象線（GameConfig から取る＝直書きで別管理にしない・code_review_2026-10-19b §2-8）。％は出さない
    static let stageNearWeeks = 4
    static let partnerGapWeeks = 6

    static func line(_ i: Input) -> String? {
        if i.money < 0 { return "所持金はマイナス。今月の家賃のめどが立っていない。" }   // 借金の週は地の文で（谷口の台詞は出さない）
        #if DEBUG
        let dedupTop = ProcessInfo.processInfo.environment["MZ_DEDUP"] == "top"   // キュー111 の見本：上の一言の方を出さない
        #else
        let dedupTop = false
        #endif
        if i.preoccupied {   // 撮影の週でも家賃の不足は隠さない（code_review_2026-10-25b §2-1）
            if i.livingThisWeek, i.money < i.livingCost { return "今週末に生活費。所持金が足りない。" }
            return "今週は撮影の仕事で、稽古には出られない。"
        }
        if i.netaCount == 0, !dedupTop { return "まだネタが無い。まずはネタを書こう。" }
        if i.livingThisWeek, i.money < i.livingCost { return "今週末に生活費。所持金が足りない。" }
        if i.stamina <= staminaLow { return "体力が少ない。今週は休むのも手だ。" }
        if i.stamina < injuryWarn { return "谷口：無理すると倒れるぞ。" }
        if i.livingInTwoWeeks { return "再来週は月末の支払い（家賃など）\(i.livingCost / 10_000)万円。" }
        if i.weeksWithoutPartner >= partnerGapWeeks { return "最近、相方とゆっくり話していない。" }
        if i.plusAvailable, !i.expBannerShown { return "経験点で上げられる能力がある。" }
        return nil
    }
}
