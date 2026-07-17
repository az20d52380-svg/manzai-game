// JudgeData.swift
// 紙講評（予選1行講評）。逐語は docs/judge_comments_v1.md / judge_design_v0.md §8/§10（UI層が保持）。
// 方針: 必ず「直せる一点」を含む・人格/才能/容姿否定は禁止。状態フック（体力低/メンタル低/相性高）優先。
// 星は原典に無いため能力から導出する【UI導出・仮】。

import Foundation
import GameCore

enum JudgeData {

    // 審査員名（決勝の顔付き7名・紙講評の署名にローテ使用）
    static let judgeNames = ["音羽 ルリ", "白波 剛", "卯月 走太", "花園 千代", "目白 慧", "神楽坂 とんぼ", "天堂寺 銀郎"]

    /// 紙講評1行。speaker=nil は事務的短文（署名ローテ可）／固定は必ずその審査員の筆（Fable09便）。
    struct PaperReview {
        let text: String
        let speaker: String?
        init(_ text: String, _ speaker: String? = nil) { self.text = text; self.speaker = speaker }
    }

    // 通過（見どころを一つ拾う）。無記名短文＋corpus §8署名付き（0be8a11・逐語）。
    static let pass: [PaperReview] = [
        PaperReview("つかみ良し。次はネタの後半に山をもう一つ。"),
        PaperReview("声が会場サイズに合っていた。この調子で。"),
        PaperReview("設定の発明あり。磨けば武器になる。"),
        PaperReview("ツッコミの語彙が良い。もっと聞きたい。"),
        PaperReview("掛け合いのリズムが既に商品。ネタが追いつけば化ける。"),
        PaperReview("客の年齢層を見て間を変えていた。通過。"),
        PaperReview("導入の三十秒に無駄がない。中盤に息継ぎを一つ足せば、後半が立つ。"),
        PaperReview("二人の声量の差が武器になっていた。次は偶然でなく設計で出すこと。"),
        PaperReview("ボケの前の静けさが作れている。オチの直前だけ、まだ急いでいる。"),
        PaperReview("この回戦を通る技術は既にある。次の壁は、四分の後半で二人が何者かまで見せられるか。"),
        PaperReview("二本目に入った瞬間ね、客席の背筋がいっせいに伸びたの。あそこで会場の目が、ふっと全部こっちに集まった。てか、その一回を次は前半のうちに作れたら、もっと強くなる。通過、おめでとう。", "音羽 ルリ"),
        PaperReview("前半でさりげなく配った三つ、後半で全部戻ってきましたね。取りこぼしゼロ。この設計ができる組は予選だと珍しいんですよ。あと一個、戻し方に『そう来たか』って角度が乗れば、決勝でも武器になります。通過です。", "卯月 走太"),
    ]

    // 敗退（直せる一点を必ず指す）。無記名短文＋corpus §8署名付き。
    static let fail: [PaperReview] = [
        PaperReview("4分の配分に難。前半に詰め込みすぎ。"),
        PaperReview("ボケの手数不足。テンポは良い。"),
        PaperReview("二人の関係がネタに乗っていない。"),
        PaperReview("設定説明に1分は長い。30秒で入って。"),
        PaperReview("ツッコミが全部同じ角度。3種類は欲しい。", "卯月 走太"),   // 計測型=卯月固定（09便§2）
        PaperReview("オチが2分地点で見えた。隠し方の問題、面白さの問題ではない。"),
        PaperReview("ネタの尺が三十秒足りていない。延ばした場所が、客席から見えていた。"),
        PaperReview("出だしの二分は客がついて来ていた。折り返しの一拍が長く、そこで降りた。"),
        PaperReview("設定は新しい。運びが借り物。自分たちの速度を決めてから、もう一度。"),
        PaperReview("ネタそのものは、ちゃんと通ってたで。けどな、二人ともずうっと客の方だけ向いて喋っとったなぁ。仲のええ二人て、ふっと相方の方を見てまう瞬間があるもんや。どこか一箇所、相方に体ごと向く間ぁこしらえてみ。それだけで、このコンビの温度が客まで届くわ。惜しいのは、そこだけやで。", "花園 千代"),
        PaperReview("熱はある! だがよ、ツッコミが一個一個なげえんだ! 全部きっちり説明しちまってるだろ! いいか、怒りってのはな、短ェから刺さるんだよ! どれか一つでいい、いらねえ言葉ぜんぶ削って、ひと言で斬ってみろ! そこだけで客の首がびくっと前に出る! ……それができりゃ、お前ら化けるぞ!", "白波 剛"),
    ]

    // 状態フック（発火時は上記より優先）。無記名＋corpus §8署名付き。
    static let failStaminaLow: [PaperReview] = [
        PaperReview("後半、声の圧が落ちた。体力も4分の一部です。", "目白 慧"),   // 敬体の講釈=目白固定（09便§2）
        PaperReview("3分過ぎでテンポが緩んだ。走り切る足を先に作って。"),
        PaperReview("息が上がってオチが急いだ。整えれば化ける。"),
    ]
    static let passStaminaLow: [PaperReview] = [
        PaperReview("終盤の失速だけが惜しい。中身は残す価値がある。"),
        PaperReview("前半の畳みかけは通用していました。ただ後半に入ってボケの入りが半拍ずつ遅れて、そこで客が一度待った。通ったのは前半の貯金です。", "卯月 走太"),
        PaperReview("後半、火鉢の炭が小さくなるみたいに、だんだん細ってきましてね。それでも客は、最後まで手をかざしてました。通しましたよ。", "神楽坂 とんぼ"),
    ]
    static let failMentalLow: [PaperReview] = [
        PaperReview("目が客でなく床を見ていた。次は前を。中身は良い。"),
        PaperReview("つかみで喉が締まっていた。ほぐれた後半が本来の力。"),
        PaperReview("緊張で間が全部詰まった。緩める勇気を一つだけ。"),
        PaperReview("最初の一言、喉から出しきる前に飲んじまったろ! つかみの第一声だけは、考える前に声にしろ! そこ直せば、次は一発目から客が乗る!", "白波 剛"),
        PaperReview("冒頭の一本目、語尾が二度、飲み込まれました。フリの最後の音だけ、置きにいかず言い切る。直すのはそこです。", "目白 慧"),
        PaperReview("出だしの間が、固かった。客を待たせたんやない、自分が固まっとっただけや。最初の礼を、ひと呼吸ゆっくりせえ。それで解ける。", "天堂寺 銀郎"),
    ]
    static let passMentalLow: [PaperReview] = [
        PaperReview("震えたまま最後まで立った。それは通過に足る強さだ。", "白波 剛"),   // 熱の承認=白波固定（09便§2）
    ]
    static let passChemistryHigh: [PaperReview] = [
        PaperReview("二人の呼吸だけで一場面もった。関係が武器になってきた。"),
        PaperReview("相方の失言を拾う速さが良い。その反射は資産です。"),
        PaperReview("掛け合いの往復が既に商品。ネタが追えば決勝が見える。"),
        PaperReview("掛け合いの継ぎ目が、どこにも見えへんかった。どっちが先に決めたわけでもない拍で、二人そろて動いてたわぁ。", "花園 千代"),
        PaperReview("返しの一拍に、迷いがない。長いこと組んどる二人や。今日はそこだけ、はっきり見えた。", "天堂寺 銀郎"),
        PaperReview("喋っていない側の相槌が、全て正しい位置にありました。あれは合わせた数だけ出るものです。", "目白 慧"),
    ]

    /// 紙講評1件を選ぶ。passed と状態から。salt でローテ＝乱数非消費・golden不変（Fable09便）。
    /// 話者固定行は必ずその署名／nil行だけ従来の署名ローテ。契約(text, judge)は不変。
    static func review(passed: Bool, state: GameState, salt: Int) -> (text: String, judge: String) {
        let pool: [PaperReview]
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
        guard !pool.isEmpty else { return ("", judgeNames[0]) }
        let entry = pool[((salt % pool.count) + pool.count) % pool.count]
        let judge = entry.speaker ?? judgeNames[((salt % judgeNames.count) + judgeNames.count) % judgeNames.count]
        return (entry.text, judge)
    }

    /// 星（★）を能力から導出【UI導出・仮】。構成←発想・間←センス・熱量←表現/華 の平均。0..5。
    static func stars(_ state: GameState) -> [(String, Int)] {
        func toStar(_ v: Double) -> Int { max(1, min(5, Int((v / 120.0 * 5).rounded()) + 1)) }
        let netsu = (state.表現 + state.華) / 2
        return [("構成", toStar(state.発想)), ("間", toStar(state.センス)), ("熱量", toStar(netsu))]
    }
}
