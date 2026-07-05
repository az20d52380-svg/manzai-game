// DialogueData.swift
// 谷口（相方・ボケ・関西弁）の掛け合いフレーバー。逐語は docs/dialogue_design_v0.md（UI層が保持・GameCore非依存）。
// 行動別2-3種ローテ／ネタ合わせは相性帯4段で変化／所持金<5万・体力<20は条件差し替え。全て【仮】。

import Foundation
import GameCore

/// 吹き出しに出す一言。name=話者名（nilは主人公の独白＝地の文表示）
struct Advice {
    let name: String?
    let text: String
}

enum DialogueData {

    // MARK: 行動別フレーバー（逐語）

    static let netaZukuri = [
        "谷口「お題ちょうだい。なんでもボケるから」／俺「じゃあ『留守番電話』」／谷口「……もしもし？」／俺「出るな。留守番の意味よ」",
        "俺「昨日の客、どこで笑ったか全部メモしてある」／谷口「お前のそういうとこ、俺は好きやで。モテへんと思うけど」",
    ]

    // 舞台稽古（ネタ見せ会/フリーライブ/ランニング等の稽古枠で共用）
    static let butaiGeiko = [
        "俺「8万。今月の稽古場代」／谷口「俺らの4分、時給に直したらエグいことなってんな」／俺「だから今日で回収すんの」",
        "谷口「鏡の前でやると、俺のボケ、思ったより顔うるさいな」／俺「客席からは、それがちょうどいい」",
    ]

    static let baito = [
        "谷口「引越し屋のバイト、今日で通算タンス200棹目」／俺「その数え方やめろ。悲しくなる」",
        "俺「……手、マメだらけだな」／谷口「センターマイク握るための予行演習よ」",
    ]

    static let yasumu = [
        "谷口「今日は寝る。プロとして寝る」／俺「その言い方だと寝るのが本業みたいだろ」",
    ]

    static let aikata = [
        "銭湯。壁のペンキ絵を見ながら谷口が言う。「売れたら、こういう仕事もすんのかな」／「ペンキ屋を？」／「営業の話よ」",
        "ファミレス。ネタの話を一度もしなかった。それでいて、帰り道に二人ともネタ帳を開いた。",
    ]

    static let offer = [
        "谷口「ギャラ聞いた？ 俺、ゼロ一個数え間違えたかと思った」／俺「営業スマイルの練習しとけ」／谷口「（満面）」／俺「本番でそれ出すな」",
    ]

    // MARK: ネタ合わせ＝相性帯4段（逐語）

    static func netaAwase(compat: Double) -> String {
        switch compat {
        case ..<8:
            return "谷口「……今日、こんなもんかな」／俺「ああ。……じゃあ、また明日」（沈黙が長い。まだ、お互いの笑いのツボを探り合っている）"
        case ..<15:
            return "谷口「3つ目のボケ、順番変えたら跳ねる気がすんねんな」／俺「俺も同じとこ引っかかってた。……先言うなよ」／谷口「それ、ネタになるな」"
        case ..<21:
            return "谷口「なあ、あそこさ——」／俺「変えた。もう直してある」／谷口「……こわ。俺ら、そのうち喋らんでよくなるで」"
        default:
            return "（谷口が目配せ。俺が頷く。修正箇所の共有、以上）／谷口「腹減ったな」／俺「それは口に出すんかい」"
        }
    }

    // MARK: 条件差し替え（逐語）

    static let lowMoney = "谷口「腹減って集中でけへん」／俺「ネタ帳食う勢いでやれ」／谷口「紙は流石に……いや、天ぷらにしたら？」／俺「書け」"
    static let lowStamina = "久しぶりに夢も見ずに眠った。起きたら昼で、少し泣きそうになるくらい体が軽かった。"   // 俺の独白

    // MARK: 週頭（行動前）の掛け合い

    static let intro = "谷口「さ、今週はどうする？」／俺「……お前が決めろって顔で見るな」"

    // MARK: セレクタ（行動＋状態＋週saltでローテ）

    /// 直前の行動に対する谷口の反応。lastAction=nil は週頭のイントロ。
    static func advice(for action: WeekAction?, state: GameState, salt: Int) -> Advice {
        guard let action else { return Advice(name: "谷口", text: intro) }

        // 条件差し替えを優先（体力<20の独白 → 所持金<5万）
        if state.stamina < 20 {
            return Advice(name: nil, text: lowStamina)
        }
        if state.money < 50_000 {
            return Advice(name: "谷口", text: lowMoney)
        }

        switch action {
        case .train(.ネタ作り):
            return Advice(name: "谷口", text: pick(netaZukuri, salt))
        case .train(.ネタ合わせ):
            return Advice(name: "谷口", text: netaAwase(compat: state.compat))
        case .train:   // ネタ見せ会 / ランニング・サウナ / フリーライブ
            return Advice(name: "谷口", text: pick(butaiGeiko, salt))
        case .job:
            return Advice(name: "谷口", text: pick(baito, salt))
        case .rest(.相方と過ごす):
            return Advice(name: "谷口", text: pick(aikata, salt))
        case .rest:    // 完全休養 / 気分転換
            return Advice(name: "谷口", text: pick(yasumu, salt))
        case .acceptOffer:
            return Advice(name: "谷口", text: pick(offer, salt))
        }
    }

    private static func pick(_ pool: [String], _ salt: Int) -> String {
        pool.isEmpty ? "" : pool[((salt % pool.count) + pool.count) % pool.count]
    }
}
