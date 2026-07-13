// JudgeData.swift
// 紙講評（予選1行講評）。逐語は docs/judge_comments_v1.md / judge_design_v0.md §8/§10（UI層が保持）。
// 方針: 必ず「直せる一点」を含む・人格/才能/容姿否定は禁止。状態フック（体力低/メンタル低/相性高）優先。
// 星は原典に無いため能力から導出する【UI導出・仮】。

import Foundation
import GameCore

enum JudgeData {

    // 審査員名（決勝の顔付き7名・紙講評の署名にローテ使用）
    static let judgeNames = ["音羽 ルリ", "白波 剛", "卯月 走太", "花園 千代", "目白 慧", "神楽坂 とんぼ", "天堂寺 銀郎"]

    // 通過（見どころを一つ拾う）
    static let pass = [
        "つかみ良し。次はネタの後半に山をもう一つ。",
        "声が会場サイズに合っていた。この調子で。",
        "設定の発明あり。磨けば武器になる。",
        "ツッコミの語彙が良い。もっと聞きたい。",
        "掛け合いのリズムが既に商品。ネタが追いつけば化ける。",
        "客の年齢層を見て間を変えていた。通過。",
        // ↓ voice_corpus_v0 §2（無記名・calibration 0be8a11）逐語追加。話者は既存の署名ローテに委ねる。
        "導入の三十秒に無駄がない。中盤に息継ぎを一つ足せば、後半が立つ。",
        "二人の声量の差が武器になっていた。次は偶然でなく設計で出すこと。",
        "ボケの前の静けさが作れている。オチの直前だけ、まだ急いでいる。",
        "この回戦を通る技術は既にある。次の壁は、四分の後半で二人が何者かまで見せられるか。",
    ]

    // 敗退（直せる一点を必ず指す）
    static let fail = [
        "4分の配分に難。前半に詰め込みすぎ。",
        "ボケの手数不足。テンポは良い。",
        "二人の関係がネタに乗っていない。",
        "設定説明に1分は長い。30秒で入って。",
        "ツッコミが全部同じ角度。3種類は欲しい。",
        "オチが2分地点で見えた。隠し方の問題、面白さの問題ではない。",
        // ↓ voice_corpus_v0 §2（無記名・calibration 0be8a11）逐語追加。話者は既存の署名ローテに委ねる。
        "ネタの尺が三十秒足りていない。延ばした場所が、客席から見えていた。",
        "出だしの二分は客がついて来ていた。折り返しの一拍が長く、そこで降りた。",
        "設定は新しい。運びが借り物。自分たちの速度を決めてから、もう一度。",
    ]

    // 状態フック（発火時は上記より優先）
    static let failStaminaLow = [
        "後半、声の圧が落ちた。体力も4分の一部です。",
        "3分過ぎでテンポが緩んだ。走り切る足を先に作って。",
        "息が上がってオチが急いだ。整えれば化ける。",
    ]
    static let passStaminaLow = ["終盤の失速だけが惜しい。中身は残す価値がある。"]
    static let failMentalLow = [
        "目が客でなく床を見ていた。次は前を。中身は良い。",
        "つかみで喉が締まっていた。ほぐれた後半が本来の力。",
        "緊張で間が全部詰まった。緩める勇気を一つだけ。",
    ]
    static let passMentalLow = ["震えたまま最後まで立った。それは通過に足る強さだ。"]
    static let passChemistryHigh = [
        "二人の呼吸だけで一場面もった。関係が武器になってきた。",
        "相方の失言を拾う速さが良い。その反射は資産です。",
        "掛け合いの往復が既に商品。ネタが追えば決勝が見える。",
    ]

    /// 紙講評1件を選ぶ。passed と状態から。salt でローテ。
    static func review(passed: Bool, state: GameState, salt: Int) -> (text: String, judge: String) {
        var pool: [String]
        if passed {
            if state.compat >= 18 { pool = passChemistryHigh }
            else if state.stamina < 30 { pool = passStaminaLow }
            else if state.メンタル < 40 { pool = passMentalLow }
            else { pool = pass }
        } else {
            if state.stamina < 30 { pool = failStaminaLow }
            else if state.メンタル < 40 { pool = failMentalLow }
            else { pool = fail }
        }
        let text = pool.isEmpty ? "" : pool[((salt % pool.count) + pool.count) % pool.count]
        let judge = judgeNames[((salt % judgeNames.count) + judgeNames.count) % judgeNames.count]
        return (text, judge)
    }

    /// 星（★）を能力から導出【UI導出・仮】。構成←発想・間←センス・熱量←表現/華 の平均。0..5。
    static func stars(_ state: GameState) -> [(String, Int)] {
        func toStar(_ v: Double) -> Int { max(1, min(5, Int((v / 120.0 * 5).rounded()) + 1)) }
        let netsu = (state.表現 + state.華) / 2
        return [("構成", toStar(state.発想)), ("間", toStar(state.センス)), ("熱量", toStar(netsu))]
    }
}
