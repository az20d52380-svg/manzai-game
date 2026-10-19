// DialogueData.swift
// 会話＝主人公「俺」の心の声（内心モノローグ）。mvp_ui_build_prompt_v1 §3-4：
// 常時出るのは俺の独白（助言・嘆き・人間味）。ボケない。谷口/先輩の会話は将来レアイベントで（毎週は出さない）。
// 状態駆動：大会前=助言／低体力／金欠／連敗。加えて選んだ行動への一言反応。全て【仮】。

import Foundation
import GameCore

struct Advice: Codable {   // Codable=中断セーブ（週頭の掛け合いの復元）用
    let name: String?     // "俺"（独白）。将来のレアイベントで谷口等に切替
    let text: String
}

/// 週頭の掛け合いの帯（GameSession.banterBand が状態から決める。innerVoice の優先順位と同じ並び）
enum BanterBand { case plain, lull, eve, streak, broke, afterPass }

enum DialogueData {

    /// 「直近に出た文を避ける」選び方の差し込み口。(場面名, 候補数, salt) → 候補の番号。nil なら従来どおり salt の剰余。
    /// 乱数は使わない（salt の剰余とずらしだけ）。直近の記録は GameSession が持つ。
    typealias Picker = (_ scene: String, _ count: Int, _ salt: Int) -> Int

    /// 同じキャリアで使った番号 used（古い順）を避ける。salt の剰余の位置から順に、未使用の最初の番号を返す。
    /// 全部使い済み（プールが尽きた）なら最も古く使った番号（used の先頭）から使い回す。乱数は使わない。
    static func indexAvoidingUsed(count: Int, salt: Int, used: [Int]) -> Int {
        guard count > 0 else { return 0 }
        let start = ((salt % count) + count) % count
        for d in 0..<count {
            let i = (start + d) % count
            if !used.contains(i) { return i }
        }
        return used.first(where: { $0 >= 0 && $0 < count }) ?? start
    }

    // MARK: 週頭（行動前）の状態駆動モノローグ

    /// 週頭（行動選択前）の一般セリフ。状態・状況・先週の結果だけに紐づける。
    /// 未選択の行動や、その週いない場所（楽屋等）の話はしない。
    /// 優先度: 低体力 > 金欠 > 連敗 > 直近通過 > 大会前 > 平常
    /// week: 選択の salt（呼び出し側は 年×131＋週）。選択は週で回す＝同じ状態で週を迎えても連続で同じ行にならない（監査D-03）。
    static func innerVoice(state: GameState, lossStreak: Int, justPassed: Bool, justLost: Bool,
                           nextMilestone: (name: String, weeksLeft: Int)?, weakAbility: String,
                           week: Int = 0, picker: Picker? = nil) -> Advice {
        if state.recoveryWeeks > 0 {   // 療養中は全てに優先（体の異常＝Fable13§2）
            return Advice(name: "俺", text: pick(recovering, salt: state.recoveryWeeks, scene: "mono.recovering", picker))
        }
        if state.stamina < 25 {
            return Advice(name: "俺", text: pick(lowStamina, salt: week, scene: "mono.lowStamina", picker))
        }
        if state.money < 30_000 {
            return Advice(name: "俺", text: pick(lowMoney, salt: week, scene: "mono.lowMoney", picker))
        }
        // 負けた翌週の一言（温度事故の停止）＝連敗プールより先。lossStreakで単発/反復を分ける（0003・Fable13便）。
        if justLost {
            return Advice(name: "俺", text: pick(lossStreak >= 2 ? justLostRepeat : justLostSingle, salt: Int(state.fame.isFinite ? state.fame : 0) &+ lossStreak &+ week,
                                                scene: lossStreak >= 2 ? "mono.justLostRepeat" : "mono.justLostSingle", picker))
        }
        if lossStreak >= 2 {
            return Advice(name: "俺", text: pick(losing, salt: lossStreak &+ week, scene: "mono.losing", picker))
        }
        if justPassed {
            return Advice(name: "俺", text: pick(passedLines, salt: Int(state.fame.isFinite ? state.fame : 0) &+ week, scene: "mono.passed", picker))
        }
        if let m = nextMilestone, m.weeksLeft == 2 {   // 1週前は掛け合い/平常に譲る（最頻出の単一行の間引き・監査D-04）
            // 弱点が無い（全能力ほぼ同値）週は弱点句を省く（監査B-03）
            return Advice(name: "俺", text: weakAbility.isEmpty ? "そろそろ\(m.name)か。"
                                                               : "そろそろ\(m.name)か。\(weakAbility)、あと少し上げておきたい。")
        }
        if let m = nextMilestone, m.weeksLeft >= 6 {   // 本番が遠い週（週16-26の空白帯等）は仕込みの声
            return Advice(name: "俺", text: pick(midseason, salt: week, scene: "mono.midseason", picker))
        }
        return Advice(name: "俺", text: pick(平常, salt: week, scene: "mono.plain", picker))
    }

    // 主人公「俺」は標準語（方言なし）。ツッコミ体質・心配性・計算屋の色は残す。
    // 本文は voice_corpus_v0（calibration 0be8a11）の◯行を逐語転記（§1 seed＋§8 底上げ・補充）。
    // 相方固有名は焼き込まない（innerVoice はコード上相方非依存）。数値・最終確定は実機目視。
    private static let recovering = [   // 療養中（recoveryWeeks>0）・Fable13§2・Skill採点済。発生週専用の一発告知は別途
        "まだ体が本調子じゃない。今週は家でおとなしくしていよう。",
    ]
    private static let lowStamina = [
        "体がもたない。今週は休みを先に入れよう。",
        "疲れが抜けてない。稽古は軽めにしておくか。",
        "階段を上がるだけで息が切れる。今週は休もう。",
        "今週は無理しない。まず寝る。",
        "朝起きるのがつらい。少し休んでおかないとまずい。",
        "声が出にくい。今週は喉を休ませたい。",
        "肩がこって眠れない。今週は風呂にゆっくり入ろう。",
        "足が重い。今週は歩く量を減らそう。",
        "体がだるい。今週は夜更かしをやめよう。",
        "目の奥が痛い。今夜は携帯を見ないで寝よう。",
    ]
    private static let lowMoney = [
        "金がない。今週はバイトを入れよう。",
        "稽古場代が足りない。先に稼がないと。",
        "このままだと遠征代が出ない。まずバイトだ。",
        "今月は苦しい。しばらく自炊でしのごう。",
        "生活費の日が近い。今週は稼ぐ週にしよう。",
        "家賃の振り込みが近い。財布の中身が心配だ。",
        "靴下が破れた。縫って使えるうちは買わずにいこう。",
        "交通費も惜しい。近くなら歩いていこう。",
        "携帯代の引き落としが近い。バイトを一日足そう。",
        "米だけは切らさないようにしよう。",
    ]
    private static let losing = [
        "また負けた。今週はちゃんと食べて、ちゃんと寝よう。",
        "負けが続くと、飯がのどを通らない。",
        "勝てない週が続く。相方の顔色が心配だ。",
        "連敗はきつい。気分を変えに、どこか出かけたい。",
        "負けた日から、よく眠れていない。",
        "大会が近い。体調だけは気をつけよう。",
        "負けが続いてる。まず、生活を立て直そう。",
        "最近、昼飯を抜きがちだ。今週は三食とろう。",
        "次の大会まで、毎日同じ時間に起きよう。",
        "負けが続いてる。次の大会の申込締切だけは確かめておこう。",
        "連敗中だ。今週は、銭湯で足を伸ばそう。",
        "続けて落ちてる。稽古の日を一日増やそう。",
    ]
    private static let justLostSingle = [   // 負けた翌週（lossStreak==1）・谷に一滴を置かない（Fable13便・Skill採点済）
        "負けた。今週は、うまいものでも食べて切り替えよう。",
        "落ちたけど、いつも通り過ごそう。",
        "落ちた。今週は、いつもより早く寝よう。",
        "負けた。まず、部屋を片づけて気分を変えよう。",
        "落ちた。次の大会がいつか、確かめておこう。",
    ]
    private static let justLostRepeat = [   // 連敗中にまた負けた翌週（lossStreak≥2）
        "また落ちた。今年の残りの大会を数えておこう。",
        "また負けた。今週は相方と飯でも食いに行こう。",
        "また落ちた。今週は、溜まった洗い物から片づけよう。",
        "また負けた。次に出る大会を、相方と決め直そう。",
        "続けて落ちた。今週は、バイトの量を見直そう。",
    ]
    private static let passedLines = [   // 先週の大会を通過した余韻
        "通った。次の会場は客席が広い。",
        "通過できた。今夜はぐっすり眠れそうだ。",
        "一つ通った。次の稽古の日を決めよう。",
        "通った。この調子で、次も準備しよう。",
        "通過の夜くらい、少しいいものを食べよう。",
        "通った。次の会場の場所を調べておこう。",
        "通過できた。相方にも、ちゃんと礼を言おう。",
        "通った。今週もバイトに出よう。",
    ]
    private static let 平常 = [            // 場面を作らない・craftと決意だけ
        "今週は、バイトと稽古をちゃんと両立させよう。",
        "相方に借りた本、今週中に返そう。",
        "冷蔵庫が空っぽだ。今週はちゃんと買い物に行こう。",
        "最近、寝る時間が遅い。今週は早めに寝よう。",
        "洗濯物がたまってる。晴れたら干そう。",
        "今週も、ちゃんと朝飯を食べよう。",
        "最近、相方とゆっくり話せてないな。",
        "バイトのシフト、今週中に出しておこう。",
        "財布の中身を、一度ちゃんと数えておこう。",
        "部屋が散らかってきた。今週こそ片づけよう。",
        "たまには実家に電話しよう。",
        "髪が伸びてきた。そろそろ切りに行こうか。",
        "傘を一本、買い足しておこう。",
        "電球が切れかけてる。今週中に替えよう。",
        "靴ひもが切れそうだ。替えを買っておこう。",
        "最近、野菜を食べてない。今週は鍋にしよう。",
        "郵便受けがいっぱいだ。今日のうちに見ておこう。",
        "携帯の画面が割れたままだ。そのうち直そう。",
        "週に一回は、体重を量っておこう。",
        "朝、少し歩く習慣をつけよう。",
        "バイトの制服、洗っておかないと。",
        "歯医者の予約、そろそろ入れよう。",
        "爪が伸びてる。人前に出る前に切っておこう。",
        "通帳の記帳に行っておこう。",
        "布団のシーツ、今週は替えよう。",
        "ゴミの日を、また忘れないようにしよう。",
        "実家から届いた荷物、今夜こそ開けよう。",
        "今週は、少し早めに家を出よう。",
        "メールの返事、ためないようにしよう。",
        "たまには窓を開けて、部屋に風を入れよう。",
        "電気代の請求、ちゃんと確かめておこう。",
        "ズボンの裾がほつれてきた。今週、縫っておこう。",
    ]

    private static let midseason = [   // 本番まで≥6週の空白帯（中だるみ対策・仕込みの声）・Skill採点済（A表/B表全○）
        "次の本番まで、しばらくある。今のうちに体を整えよう。",
        "予定のない週が続く。だらけないように気をつけよう。",
        "本番がない週は、つい朝寝坊してしまう。",
        "急ぎの用がない週だ。図書館で本でも借りてこよう。",
        "人前に出ない週が続くと、少し不安になる。",
        "時間があるうちに、自転車を直しておこう。",
        "本番はだいぶ先だ。今のうちに部屋の模様替えをしよう。",
        "空いてる週に、実家へ顔を出しておこう。",
        "しばらく本番がない。毎晩、少しだけ体を動かそう。",
        "急がない週だ。早く寝て、体を戻そう。",
        "予定の少ない週だ。古い服を整理しよう。",
        "本番のない週は、相方と会う日を決めておこう。",
        "次の本番の日を、カレンダーに書いておこう。",
        "落ち着いた週だ。たまっていた手紙の返事を書こう。",
    ]

    // MARK: 週頭の掛け合い（俺⇄谷口・タップ送り。発火は GameSession.rollWeekBanter＝UI乱数）
    //
    // 帯×プール×salt=週番号の決定的回転。1本=2〜3行（話者交互）。本文は manzai-drama-voice Skill を通す。
    // 返り値 nil=その帯の在庫なし（View は独白へフォールバック）。

    static func banter(band: BanterBand, salt: Int, picker: Picker? = nil) -> [Advice]? {
        guard let pools = banterPools[band], !pools.isEmpty else { return nil }
        if let picker { return pools[picker("banter.\(band)", pools.count, salt)] }
        return pools[((salt % pools.count) + pools.count) % pools.count]
    }
    // 相方は谷口固定（MVP・関西弁）。2周目ガチャ相方の実装時は相方分岐に差し替える（ChoiceEventData と同じ扱い）。
    // Skill採点済（A表16項目・B表7項目・V表5項目・全○）。谷口に切り札型口癖（腹減ったな等）は置かない（感情最大点に温存）。
    private static let banterPools: [BanterBand: [[Advice]]] = [
        .plain: [
            [Advice(name: "谷口", text: "この前の雨で、傘なくしてもうた"),
             Advice(name: "俺", text: "そうか。風邪ひかないようにな")],
            [Advice(name: "谷口", text: "実家から米が届いたんや。半分持っていき"),
             Advice(name: "俺", text: "助かる。ちょうど切らしてたんだ")],
            [Advice(name: "俺", text: "目が赤いぞ。寝てないのか"),
             Advice(name: "谷口", text: "隣の部屋がうるさくてな。夜中まで眠れんかった"),
             Advice(name: "俺", text: "今日は早めに切り上げよう")],
            [Advice(name: "谷口", text: "自転車のブレーキ、きかんようになってん"),
             Advice(name: "俺", text: "危ないな。今週中に直しに行けよ")],
            [Advice(name: "谷口", text: "最近、自炊始めてん。外で食うより安いわ"),
             Advice(name: "俺", text: "いいじゃないか。野菜も食べろよ")],
            [Advice(name: "俺", text: "その咳、まだ治らないのか"),
             Advice(name: "谷口", text: "もう治りかけや。薬も飲んどる"),
             Advice(name: "俺", text: "ならいい。今日は無理するなよ")],
            [Advice(name: "谷口", text: "妹が今度こっち来るねん。一日、案内してくるわ"),
             Advice(name: "俺", text: "わかった。その日は休みにしよう")],
            [Advice(name: "谷口", text: "部屋の更新、来月やねん"),
             Advice(name: "俺", text: "更新料がかかるな。今月は無駄遣いを控えよう")],
            [Advice(name: "谷口", text: "バイト先の店長、腰いわして休んどるねん"),
             Advice(name: "俺", text: "大変だな。お前のシフトも増えそうか"),
             Advice(name: "谷口", text: "ちょっとな。でも稽古の日は空けとくで")],
            [Advice(name: "俺", text: "靴、底がすり減ってるぞ"),
             Advice(name: "谷口", text: "ほんまや。今度の休みに買いに行くわ")],
            [Advice(name: "谷口", text: "地元の友だちが結婚したって連絡来てん"),
             Advice(name: "俺", text: "そうか。お祝い、何か送らないとな")],
            [Advice(name: "谷口", text: "駅前に新しい定食屋できとったで"),
             Advice(name: "俺", text: "行ってみるか。今日の帰りに寄ろう")],
        ],
        .lull: [
            [Advice(name: "谷口", text: "来月まで本番なしやて。長いな"),
             Advice(name: "俺", text: "そうだな。バイトを多めに入れておくか")],
            [Advice(name: "谷口", text: "今度の休み、銭湯でも行かへんか"),
             Advice(name: "俺", text: "いいな。たまには、ゆっくり浸かろう")],
            [Advice(name: "谷口", text: "静かな週やな"),
             Advice(name: "俺", text: "そうだな。たまには早く帰って寝るか")],
            [Advice(name: "谷口", text: "時間あるうちに、免許の更新行っとくわ"),
             Advice(name: "俺", text: "そうしろ。本番の前だと慌てるからな")],
            [Advice(name: "谷口", text: "実家に二、三日帰ってきてもええか"),
             Advice(name: "俺", text: "いいよ。戻ったら連絡くれ")],
            [Advice(name: "俺", text: "部屋の片づけ、手伝ってくれないか"),
             Advice(name: "谷口", text: "ええよ。そのかわり昼飯おごってな"),
             Advice(name: "俺", text: "わかった。安いところでな")],
            [Advice(name: "谷口", text: "ジムの体験、一緒に行かへんか"),
             Advice(name: "俺", text: "いいな。体力はつけておきたい")],
            [Advice(name: "谷口", text: "この前の古着屋、また行かへん？"),
             Advice(name: "俺", text: "いいよ。週末なら空いてる")],
            [Advice(name: "俺", text: "次の本番まで、体を作っておこう"),
             Advice(name: "谷口", text: "せやな。毎朝、近所を走ることにするわ")],
            [Advice(name: "谷口", text: "おとんの誕生日やねん。何送ったらええと思う"),
             Advice(name: "俺", text: "電話してやれよ。それがいちばん喜ぶ")],
            [Advice(name: "谷口", text: "先輩の引っ越し、手伝い頼まれてん"),
             Advice(name: "俺", text: "行ってこい。こっちは一人で書いておく")],
        ],
        .eve: [
            [Advice(name: "谷口", text: "もうすぐやな。当日の電車、調べといたで"),
             Advice(name: "俺", text: "ありがとう。当日は早めに出よう")],
            [Advice(name: "俺", text: "本番前に風邪ひくなよ"),
             Advice(name: "谷口", text: "わかっとる。毎晩うがいしとるわ")],
            [Advice(name: "谷口", text: "前の日、バイト入れたらあかんで"),
             Advice(name: "俺", text: "入れてない。大丈夫だ")],
            [Advice(name: "谷口", text: "当日の衣装、クリーニング出しといたで"),
             Advice(name: "俺", text: "助かる。受け取りは前の日にしよう")],
            [Advice(name: "谷口", text: "髪、本番前に切っといたほうがええかな"),
             Advice(name: "俺", text: "そうだな。前の週に切っておこう")],
            [Advice(name: "谷口", text: "エントリーの紙、ちゃんと出したよな"),
             Advice(name: "俺", text: "出した。控えも取ってある")],
            [Advice(name: "谷口", text: "本番の前の日は、何食べたらええやろ"),
             Advice(name: "俺", text: "いつも通りでいい。生ものだけはやめておこう")],
            [Advice(name: "谷口", text: "靴、新しいの下ろそうか迷っとる"),
             Advice(name: "俺", text: "やめておけ。履き慣れたほうがいい")],
            [Advice(name: "谷口", text: "おかんが、本番見に来たい言うてんねん"),
             Advice(name: "俺", text: "いいじゃないか。席の場所を教えておけよ")],
            [Advice(name: "谷口", text: "当日の昼、どこで食べるか決めとこか"),
             Advice(name: "俺", text: "会場の近くで探しておくよ")],
            [Advice(name: "俺", text: "本番の前の晩は、早めに解散しよう"),
             Advice(name: "谷口", text: "せやな。ゆっくり寝たいわ")],
        ],
        .streak: [
            [Advice(name: "谷口", text: "最近、飯ちゃんと食うてるか"),
             Advice(name: "俺", text: "あんまり。お前こそ、痩せたんじゃないか")],
            [Advice(name: "谷口", text: "負けが続くと、地元の連れに連絡しづらいねん"),
             Advice(name: "俺", text: "わかる。俺もしばらく返事してない")],
            [Advice(name: "谷口", text: "今日はもう帰ろか。顔、疲れとるで"),
             Advice(name: "俺", text: "そうだな。今日は帰って休もう")],
            [Advice(name: "谷口", text: "親から、ちゃんと食べとるかって電話あったわ"),
             Advice(name: "俺", text: "心配かけてるな。今度、顔を見せに行けよ")],
            [Advice(name: "俺", text: "最近、眠れてるか"),
             Advice(name: "谷口", text: "あんまりやな。夜中に目え覚めてまう"),
             Advice(name: "俺", text: "今週は稽古を短くしよう")],
            [Advice(name: "谷口", text: "次の大会、いつやったっけ"),
             Advice(name: "俺", text: "調べておく。それまで体を休めておこう")],
            [Advice(name: "谷口", text: "今日、うちで鍋せえへんか"),
             Advice(name: "俺", text: "行く。材料は俺が買っていく")],
            [Advice(name: "谷口", text: "同期のコンビ、一組やめたらしいわ"),
             Advice(name: "俺", text: "そうか。今度、飯でも誘ってみよう")],
            [Advice(name: "谷口", text: "最近、散歩するようにしてんねん。頭がすっきりするわ"),
             Advice(name: "俺", text: "いいな。今度、俺も一緒に歩くよ")],
            [Advice(name: "谷口", text: "この前の帰り、電車で寝過ごしてもうた"),
             Advice(name: "俺", text: "疲れてるんだよ。今日は駅まで一緒に行こう")],
            [Advice(name: "谷口", text: "バイト先の人が、次も見に行く言うてくれてん"),
             Advice(name: "俺", text: "ありがたいな。ちゃんと礼を言っておこう")],
            [Advice(name: "俺", text: "部屋、ちゃんと片づけてるか"),
             Advice(name: "谷口", text: "散らかり放題や。今週、片づけるわ")],
        ],
        .broke: [
            [Advice(name: "谷口", text: "今月、電気代がえらい高かったわ"),
             Advice(name: "俺", text: "うちもだ。しばらく節約しよう")],
            [Advice(name: "谷口", text: "まかない付きのバイト、まだ枠あるらしいで"),
             Advice(name: "俺", text: "入れておいてくれ。晩飯代が浮く")],
            [Advice(name: "谷口", text: "バイト先で、余った弁当もろてきた。一個いるか"),
             Advice(name: "俺", text: "助かる。今日の晩飯にする")],
            [Advice(name: "谷口", text: "スーパーの見切り品、夜八時過ぎが狙い目やで"),
             Advice(name: "俺", text: "助かる。今日の帰りに寄ってみよう")],
            [Advice(name: "谷口", text: "電車やめて、自転車で来たわ"),
             Advice(name: "俺", text: "えらいな。俺もしばらくそうする")],
            [Advice(name: "俺", text: "カラオケ代、今週は割り勘で頼む"),
             Advice(name: "谷口", text: "ええよ。公園で合わせる日も増やそか"),
             Advice(name: "俺", text: "そうしよう。晴れた日は公園にしよう")],
            [Advice(name: "谷口", text: "交通量調査の単発、夜の分が空いとるで"),
             Advice(name: "俺", text: "入れてくれ。次の日は寝ておく")],
            [Advice(name: "谷口", text: "携帯、安いプランに変えたら楽になったわ"),
             Advice(name: "俺", text: "そうか。俺も今度見てもらおう")],
            [Advice(name: "谷口", text: "コインランドリーやめて、手洗いにしたわ"),
             Advice(name: "俺", text: "大変だな。雨の日は部屋干しになるぞ")],
            [Advice(name: "俺", text: "今月、家賃は払えそうか"),
             Advice(name: "谷口", text: "ぎりぎりや。バイトのシフト増やしてもろた"),
             Advice(name: "俺", text: "無理はするなよ。稽古の日は調整しよう")],
            [Advice(name: "谷口", text: "先輩が、飯おごったる言うてくれてん。一緒に行こ"),
             Advice(name: "俺", text: "行く。お礼は、ちゃんと言おう")],
            [Advice(name: "谷口", text: "水筒持ってきたら、飲み物代が浮くで"),
             Advice(name: "俺", text: "そうだな。明日から持ってこよう")],
        ],
        .afterPass: [
            [Advice(name: "谷口", text: "次の会場、下見行っとくか"),
             Advice(name: "俺", text: "行こう。駅からの道だけ、先に覚えておきたい")],
            [Advice(name: "谷口", text: "おかんに通ったって電話したら、泣いとったわ"),
             Advice(name: "俺", text: "よかったな。俺も実家に連絡しておこう")],
            [Advice(name: "谷口", text: "祝いや。今日は俺が出したる"),
             Advice(name: "俺", text: "ありがとう。でも遠征代がいるから、安い店にしよう")],
            [Advice(name: "谷口", text: "バイト先で、通ったん話したら拍手されたわ"),
             Advice(name: "俺", text: "よかったな。店長にもよろしく言っておいてくれ")],
            [Advice(name: "谷口", text: "次まで、何週あるんやったっけ"),
             Advice(name: "俺", text: "あとで数えておく。体調だけは気をつけろよ")],
            [Advice(name: "谷口", text: "次の会場までの交通費、調べといたで"),
             Advice(name: "俺", text: "ありがとう。その分は先に封筒に分けておこう")],
            [Advice(name: "谷口", text: "通った日の夜、あんまり眠れんかったわ"),
             Advice(name: "俺", text: "俺もだ。今夜は早く寝よう")],
            [Advice(name: "谷口", text: "通った日のこと、日記に書いといた"),
             Advice(name: "俺", text: "そうか。俺も手帳に書いておくよ")],
            [Advice(name: "俺", text: "通ったからって、バイトは減らせないな"),
             Advice(name: "谷口", text: "せやな。いつも通りいこ")],
            [Advice(name: "谷口", text: "今日は寄り道せんと、まっすぐ帰ろか"),
             Advice(name: "俺", text: "そうしよう。疲れが出る前に休もう")],
            [Advice(name: "谷口", text: "次の本番用に、シャツ一枚買おかな"),
             Advice(name: "俺", text: "いいと思う。安いので十分だ")],
        ],
    ]

    // MARK: 選んだ変種への一言反応（Beat1 発話バブル・週送りの直前に一言）
    //
    // salt=週番号で決定的に回す（乱数不使用＝uiEventRng も消費しない＝golden不変）。
    // 話者は俺（独白）を基本に、相方が絡む行動（ネタ合わせ/相方と過ごす等）は谷口の生声を混ぜる。
    // プールの拡充は manzai-drama-voice Skill を通す（ここの本文を勝手に増やさない）。

    static func reaction(variantID: String, salt: Int, picker: Picker? = nil) -> Advice {
        let pool = reactionPools[variantID] ?? [Advice(name: "俺", text: "よし、いくか。")]
        if let picker { return pool[picker("reaction.\(variantID)", pool.count, salt)] }
        return pool[((salt % pool.count) + pool.count) % pool.count]
    }
    // 新規行はSkill採点済（全○）。相方名は焼き込まない（「谷口と、ネタ抜きで飯でも。」は既存・既知として残置）。
    private static let reactionPools: [String: [Advice]] = [
        "t_ネタ作り": [
            Advice(name: "俺", text: "書く日は、携帯の電源を切っておく。"),
            Advice(name: "俺", text: "コーヒーを一杯飲んでから、書き始める。"),
            Advice(name: "俺", text: "書く前に、机の上を片づける。"),
            Advice(name: "俺", text: "今夜は遅くなる。お茶を多めにいれておく。"),
        ],
        "t_ネタ見せ会": [
            Advice(name: "俺", text: "作家さんの前は、何回やっても緊張する。"),
            Advice(name: "俺", text: "終わったら、駅前で何か食べて帰ろう。"),
            Advice(name: "俺", text: "作家さんの話は、手帳に書き留めておこう。"),
            Advice(name: "俺", text: "会場には、少し早めに着いておこう。"),
        ],
        "t_ネタ合わせ": [
            Advice(name: "俺", text: "相方に、差し入れのパンを買っていこう。"),
            Advice(name: "俺", text: "稽古のあとは、二人で安い定食屋に寄ろう。"),
            Advice(name: "俺", text: "今日は公園で合わせる。雨が降らなければいいが。"),
            Advice(name: "俺", text: "カラオケの部屋代は、割り勘にしよう。"),
        ],
        "t_ランニング・サウナ": [
            Advice(name: "俺", text: "今日はエントリーライブだ。知らない人ばかりで緊張する。"),
            Advice(name: "俺", text: "ライブの帰りに、本屋に寄っていこう。"),
            Advice(name: "俺", text: "出番の前に、のど飴を買っておこう。"),
            Advice(name: "俺", text: "今日は、隣の人に自分から話しかけてみよう。"),
        ],
        "t_フリーライブ": [
            Advice(name: "俺", text: "人前に出る日だ。朝飯はしっかり食べた。"),
            Advice(name: "俺", text: "終わったら、相方と駅まで歩いて帰ろう。"),
            Advice(name: "俺", text: "出番の前に、トイレの場所を確かめておこう。"),
            Advice(name: "俺", text: "終わったら、店の人にちゃんと挨拶しよう。"),
        ],
        "job_キツい": [
            Advice(name: "俺", text: "体で稼ぐ日だ。腰を痛めないようにしよう。"),
            Advice(name: "俺", text: "終わりの時間だけ確かめて、引き受けよう。"),
            Advice(name: "俺", text: "軍手を二組、持っていこう。"),
            Advice(name: "俺", text: "昼飯は、多めに持っていこう。"),
        ],
        "job_標準": [
            Advice(name: "俺", text: "まかないが出るのはありがたい。"),
            Advice(name: "俺", text: "忙しい店のほうが、時間が早く過ぎる。"),
            Advice(name: "俺", text: "夜の仕事だ。帰りは遅くなる。"),
            Advice(name: "俺", text: "閉店の片づけまでやったら、明日は少し寝坊しよう。"),
        ],
        "job_楽": [
            Advice(name: "俺", text: "座って数える仕事だ。頭は空けておける。"),
            Advice(name: "俺", text: "夕方には終わる。夜はゆっくりできる。"),
            Advice(name: "俺", text: "帰りに寄る店を一つ決めておこう。"),
            Advice(name: "俺", text: "数え間違えないように、前の晩は早く寝よう。"),
        ],
        "rest_完全休養": [
            Advice(name: "俺", text: "携帯を伏せて、昼まで寝る。"),
            Advice(name: "俺", text: "布団を干してから、寝直す。"),
            Advice(name: "俺", text: "今日は目覚ましをかけない。"),
            Advice(name: "俺", text: "起きたら、まず米を炊く。"),
        ],
        "rest_気分転換": [
            Advice(name: "俺", text: "一駅ぶん、歩いて帰る。"),
            Advice(name: "俺", text: "財布だけ持って、ふらっと出かける。"),
            Advice(name: "俺", text: "知らない駅で降りてみる。"),
            Advice(name: "俺", text: "古本屋を何軒か、のぞいて帰る。"),
        ],
        "rest_相方と過ごす": [
            Advice(name: "俺", text: "相方と、のんびり昼飯でも。"),
            Advice(name: "俺", text: "今日は仕事の話はなしにしよう。"),
            Advice(name: "俺", text: "夕方から会う。店は、向こうが決める。"),
            Advice(name: "俺", text: "相方の家で、鍋でもやろう。"),
            Advice(name: "俺", text: "相方と、近所を散歩するだけの日だ。"),
        ],
        // 練習の場所・お金を払う練習/休み（未登録で「よし、いくか。」に落ちていた分・text_repeat_rate §4-A-3）
        "t_喫茶店で書く": [
            Advice(name: "俺", text: "窓ぎわの席が空いていればいいが。"),
            Advice(name: "俺", text: "コーヒー一杯で、夕方まで粘ろう。"),
        ],
        "t_ファミレスで書く": [
            Advice(name: "俺", text: "ドリンクバーで朝までだ。明日はしっかり寝よう。"),
            Advice(name: "俺", text: "ファミレスの隅の席で、黙って書こう。"),
        ],
        "t_作家の勉強会": [
            Advice(name: "俺", text: "出演料は安くない。お題はちゃんとメモを取ろう。"),
            Advice(name: "俺", text: "知らない人ばかりだ。早めに楽屋入りしよう。"),
        ],
        "t_ボイトレ": [
            Advice(name: "俺", text: "声を出す日だ。のどを冷やさないようにしよう。"),
            Advice(name: "俺", text: "安い部屋だ。時間いっぱい声を通そう。"),
        ],
        "rest_サウナ": [
            Advice(name: "俺", text: "サウナのあとは、水をたくさん飲もう。"),
            Advice(name: "俺", text: "久しぶりに、汗を流してすっきりしよう。"),
        ],
        "rest_温泉に一泊": [
            Advice(name: "俺", text: "温泉に一泊だ。携帯は鞄にしまっておこう。"),
            Advice(name: "俺", text: "宿に着いたら、まず風呂に入ろう。"),
        ],
        "offer": [
            Advice(name: "俺", text: "名前を覚えてもらえる仕事だ。受けよう。"),
            Advice(name: "俺", text: "日取りだけ確かめて、受けよう。"),
            Advice(name: "俺", text: "どんな仕事でも、遅れずに行こう。"),
            Advice(name: "俺", text: "知らない現場だ。早めに着いておこう。"),
        ],
    ]

    private static func pick(_ pool: [String], salt: Int, scene: String? = nil, _ picker: Picker? = nil) -> String {
        guard !pool.isEmpty else { return "" }
        if let scene, let picker { return pool[picker(scene, pool.count, salt)] }
        return pool[((salt % pool.count) + pool.count) % pool.count]
    }
    /// 年末の独白など外部から使う用（直近避けつき）。
    static func choose(_ pool: [String], salt: Int, scene: String, picker: Picker?) -> String? {
        guard !pool.isEmpty else { return nil }
        return pick(pool, salt: salt, scene: scene, picker)
    }

    // MARK: ネタおろし（初披露＝Neta.isDown:false→true の瞬間・正典 docs/neta_system_redesign_v2.md §3-2補2）
    // 話者=俺（標準語・心の声）。manzai-drama-voice Skill 採点済（A表16項目・B表7項目・全○）。

    static func netaOroshi(salt: Int) -> String {
        pick(netaOroshiPool, salt: salt)
    }
    private static let netaOroshiPool = [
        "これを人前でやるのは、今日が初めてだ。",
        "稽古では何十回もやった。人前では今日が初めてだ。",
        "初めて人前でやる日は、朝から落ち着かない。",
        "初めての日だ。帰りに何かうまいものを食べよう。",
    ]
}
