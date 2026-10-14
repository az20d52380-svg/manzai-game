// JudgeData.swift
// 紙講評（予選1行講評）の窓口。文面と差し込みは GameCore/JudgeTalk.swift（v1 書き直し・docs/judge_comment_rewrite_v1.md）。
// 方針: 必ず「そのネタ・その本番の具体物」を1つ入れる・良かった点→直す点・人格/才能/容姿否定は禁止。乱数非消費。
// 星は原典に無いため能力から導出する【UI導出・仮】。

import Foundation
import GameCore

enum JudgeData {

    // 審査員名（決勝の顔付き7名・紙講評の署名にローテ使用）
    static let judgeNames = JudgeTalk.judgeNames

    /// 紙講評1件。その本番にかけたネタ（state.selectedNetaID）・点差・ハマった夜を差し込む。salt 剰余＝乱数非消費・golden不変。
    static func review(passed: Bool, state: GameState, salt: Int, config: GameConfig, year: Int,
                       margin: Double?, burst: Bool) -> (text: String, judge: String) {
        let neta = state.netas.first { $0.id == state.selectedNetaID }
        let scene = JudgeTalk.Scene.from(state: state, neta: neta, config: config, year: year, burst: burst, margin: margin)
        return JudgeTalk.paperReview(passed: passed, scene: scene, salt: salt)
    }

    /// 星（★）を能力から導出【UI導出・仮】。構成←発想・間←センス・熱量←表現/華 の平均。0..5。
    static func stars(_ state: GameState) -> [(String, Int)] {
        func toStar(_ v: Double) -> Int { max(1, min(5, Int((v / 120.0 * 5).rounded()) + 1)) }
        let netsu = (state.表現 + state.華) / 2
        return [("構成", toStar(state.発想)), ("間", toStar(state.センス)), ("熱量", toStar(netsu))]
    }
}
