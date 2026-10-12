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

    // MARK: 週頭（行動前）の状態駆動モノローグ

    /// 週頭（行動選択前）の一般セリフ。状態・状況・先週の結果だけに紐づける。
    /// 未選択の行動や、その週いない場所（楽屋等）の話はしない。
    /// 優先度: 低体力 > 金欠 > 連敗 > 直近通過 > 大会前 > 平常
    /// week: 週番号。選択は週番号で回す＝同じ状態で週を迎えても連続で同じ行にならない（監査D-03）。
    static func innerVoice(state: GameState, lossStreak: Int, justPassed: Bool, justLost: Bool,
                           nextMilestone: (name: String, weeksLeft: Int)?, weakAbility: String,
                           week: Int = 0) -> Advice {
        if state.recoveryWeeks > 0 {   // 療養中は全てに優先（体の異常＝Fable13§2）
            return Advice(name: "俺", text: pick(recovering, salt: state.recoveryWeeks))
        }
        if state.stamina < 25 {
            return Advice(name: "俺", text: pick(lowStamina, salt: week))
        }
        if state.money < 30_000 {
            return Advice(name: "俺", text: pick(lowMoney, salt: week))
        }
        // 負けた翌週の一言（温度事故の停止）＝連敗プールより先。lossStreakで単発/反復を分ける（0003・Fable13便）。
        if justLost {
            return Advice(name: "俺", text: pick(lossStreak >= 2 ? justLostRepeat : justLostSingle, salt: Int(state.fame) &+ lossStreak))
        }
        if lossStreak >= 2 {
            return Advice(name: "俺", text: pick(losing, salt: lossStreak))
        }
        if justPassed {
            return Advice(name: "俺", text: pick(passedLines, salt: Int(state.fame)))
        }
        if let m = nextMilestone, m.weeksLeft == 2 {   // 1週前は掛け合い/平常に譲る（最頻出の単一行の間引き・監査D-04）
            // 弱点が無い（全能力ほぼ同値）週は弱点句を省く（監査B-03）
            return Advice(name: "俺", text: weakAbility.isEmpty ? "そろそろ\(m.name)か。"
                                                               : "そろそろ\(m.name)か。\(weakAbility)、あと少し上げておきたい。")
        }
        if let m = nextMilestone, m.weeksLeft >= 6 {   // 本番が遠い週（週16-26の空白帯等）は仕込みの声
            return Advice(name: "俺", text: pick(midseason, salt: week))
        }
        return Advice(name: "俺", text: pick(平常, salt: week))
    }

    // 主人公「俺」は標準語（方言なし）。ツッコミ体質・心配性・計算屋の色は残す。
    // 本文は voice_corpus_v0（calibration 0be8a11）の◯行を逐語転記（§1 seed＋§8 底上げ・補充）。
    // 相方固有名は焼き込まない（innerVoice はコード上相方非依存）。数値・最終確定は実機目視。
    private static let recovering = [   // 療養中（recoveryWeeks>0）・Fable13§2・Skill採点済。発生週専用の一発告知は別途
        "今週は声を出さない。ネタ帳の直しだけ進めよう。",
    ]
    private static let lowStamina = [
        "体がもたない。今週は休みを先に入れよう。",
        "疲れが抜けてない。稽古は軽めにしておくか。",
        "このまま本番に出たら、後半で息が切れる。",
        "今週は無理しない。まず寝る。",
        "合わせの前に、少し休んでおかないとまずい。",
        "声が出にくい。今週は喉を休ませたい。",
    ]
    private static let lowMoney = [
        "金がない。今週はバイトを入れよう。",
        "稽古場代が足りない。先に稼がないと。",
        "このままだと遠征代が出ない。まずバイトだ。",
        "今月は苦しい。有料の稽古は見送るか。",
        "生活費の日が近い。今週は稼ぐ週にしよう。",
        "金のことを考えると、ネタに集中できない。",
    ]
    private static let losing = [
        "また負けた。直す場所を一つに絞ろう。",
        "講評をもう一回読もう。言われたことは同じだった。",
        "同じ段で止まってる。何が足りないのか、確かめたい。",
        "連敗はきつい。次までに一か所だけ直そう。",
        "負けた録音を聞き直そう。崩れる場所は決まってる。",
        "次の大会までに、一つだけでも直しておきたい。",
    ]
    private static let justLostSingle = [   // 負けた翌週（lossStreak==1）・谷に一滴を置かない（Fable13便・Skill採点済）
        "負けた。今週は、講評の一点を直そう。",
        "落ちたけど、やることは変わらない。いつも通りいこう。",
    ]
    private static let justLostRepeat = [   // 連敗中にまた負けた翌週（lossStreak≥2）
        "また同じところで落ちた。今年の残りの大会を数えておこう。",
        "直す場所は先週と同じだ。今週の通しで確かめる。",
    ]
    private static let passedLines = [   // 先週の大会を通過した余韻
        "通った。次の会場は客席が広い。",
        "通過できた。谷口、もう次の合わせの日を決めたがってる。",
        "一つ通った。次の稽古の日を決めよう。",
        "通った。この調子で、次も準備しよう。",
        "客席がよく沸いてた。あの感じを忘れないうちに稽古したい。",
    ]
    private static let 平常 = [            // 場面を作らない・craftと決意だけ
        "今週はネタの頭を詰めよう。",
        "直しかけの一本を、今週中に谷口に見せよう。",
        "新ネタの二本目がまだ形になってない。今週中に何とかしたい。",
        "合わせは木曜だ。それまでに直しを終わらせよう。",
        "稽古場は火曜と金曜が取れた。どう使うか決めよう。",
        "今週の段取りは決まってる。あとはやるだけだ。",
        "今週は通し二回と、頭の直し一回でいこう。",
        "新ネタは一本に絞ろう。二本同時は無理だ。",
        "金曜の合わせは、後半から始めよう。",
        "持ちネタを整理しよう。使うネタと寝かせるネタに分ける。",
        "谷口の都合が夜しか合わない。稽古は夜にしよう。",
        "来週の合わせまでに、俺の担当の直しを終わらせよう。",
    ]

    private static let midseason = [   // 本番まで≥6週の空白帯（中だるみ対策・仕込みの声）・Skill採点済（A表/B表全○）
        "次の本番まで間がある。大きい直しは今のうちだ。",
        "予定のない週が続く。だらけないように気をつけよう。",
        "本番がないと発声が雑になる。毎朝やろう。",
        "急ぎの用がない週は、やることを三つ決めておこう。",
        "客前に立たないと、感覚が鈍りそうで心配だ。",
        "じっくり新ネタを作れるのは、この時期くらいだ。",
    ]

    // MARK: 週頭の掛け合い（俺⇄谷口・タップ送り。発火は GameSession.rollWeekBanter＝UI乱数）
    //
    // 帯×プール×salt=週番号の決定的回転。1本=2〜3行（話者交互）。本文は manzai-drama-voice Skill を通す。
    // 返り値 nil=その帯の在庫なし（View は独白へフォールバック）。

    static func banter(band: BanterBand, salt: Int) -> [Advice]? {
        guard let pools = banterPools[band], !pools.isEmpty else { return nil }
        return pools[((salt % pools.count) + pools.count) % pools.count]
    }
    // 相方は谷口固定（MVP・関西弁）。2周目ガチャ相方の実装時は相方分岐に差し替える（ChoiceEventData と同じ扱い）。
    // Skill採点済（A表16項目・B表7項目・V表5項目・全○）。谷口に切り札型口癖（腹減ったな等）は置かない（感情最大点に温存）。
    private static let banterPools: [BanterBand: [[Advice]]] = [
        .plain: [
            [Advice(name: "谷口", text: "稽古場、火曜に変えといたで。金曜は取られとった"),
             Advice(name: "俺", text: "なら火曜までに、直しを二つ終わらせる")],
            [Advice(name: "俺", text: "今週の通し、何本いける"),
             Advice(name: "谷口", text: "三本やな。二本は頭から、一本は後半だけでええやろ")],
            [Advice(name: "俺", text: "昨日の通し、後半どうだった"),
             Advice(name: "谷口", text: "三分すぎ、足元見とったやろ"),
             Advice(name: "俺", text: "今日はそこを詰める")],
        ],
        .lull: [
            [Advice(name: "谷口", text: "来月まで本番なしか。長いな"),
             Advice(name: "俺", text: "そうだな。前半は作って、後半で詰めよう")],
            [Advice(name: "谷口", text: "新しいの、一本書かへんか。時間あるうちに"),
             Advice(name: "俺", text: "書きかけを先に終わらせよう。新しいのはそれからだ")],
            [Advice(name: "谷口", text: "静かな週やな"),
             Advice(name: "俺", text: "通しを二本入れてある。今のうちにやっておこう")],
        ],
        .eve: [
            [Advice(name: "谷口", text: "もうすぐやな。ネタ、どっちでいく"),
             Advice(name: "俺", text: "今のところ一本目だ。今週の通しで決める")],
            [Advice(name: "俺", text: "本番までに、後半の直しを終わらせる"),
             Advice(name: "谷口", text: "ほな今日は後半だけ、二回通そか")],
            [Advice(name: "谷口", text: "前の日、バイト入れんなよ"),
             Advice(name: "俺", text: "入れてない。組んである")],
        ],
        .streak: [
            [Advice(name: "谷口", text: "講評、もっぺん読んだで"),
             Advice(name: "俺", text: "俺も読んだ。直すところ、たぶん同じだな")],
            [Advice(name: "谷口", text: "稽古場、来週から一枠増やせるで。俺のバイト、水曜空いたし"),
             Advice(name: "俺", text: "なら水曜は通しに使う")],
            [Advice(name: "谷口", text: "今日は何時までやる"),
             Advice(name: "俺", text: "九時までにしよう。続きは明日だ")],
        ],
        .broke: [
            [Advice(name: "谷口", text: "今月、稽古場代どうすんの"),
             Advice(name: "俺", text: "先に半分入れてある。残りはバイトの後だ")],
            [Advice(name: "谷口", text: "まかない付きのバイト、まだ枠あるらしいで"),
             Advice(name: "俺", text: "入れておいてくれ。合わせは、その後でやる")],
            [Advice(name: "谷口", text: "遠征の積立、今月は無しでええか"),
             Advice(name: "俺", text: "今月は無しでいい。来月、多めに入れよう")],
        ],
        .afterPass: [
            [Advice(name: "谷口", text: "次の会場、下見行っとくか"),
             Advice(name: "俺", text: "行こう。板の広さだけ、先に見ておきたい")],
            [Advice(name: "谷口", text: "こないだの客、ようウケとったな"),
             Advice(name: "俺", text: "ウケた場所、メモしてある。次も使おう")],
            [Advice(name: "谷口", text: "祝いや。今日は俺が出したる"),
             Advice(name: "俺", text: "ありがとう。でも安い店にしよう。遠征代がいる")],
        ],
    ]

    // MARK: 選んだ変種への一言反応（Beat1 発話バブル・週送りの直前に一言）
    //
    // salt=週番号で決定的に回す（乱数不使用＝uiEventRng も消費しない＝golden不変）。
    // 話者は俺（独白）を基本に、相方が絡む行動（ネタ合わせ/相方と過ごす等）は谷口の生声を混ぜる。
    // プールの拡充は manzai-drama-voice Skill を通す（ここの本文を勝手に増やさない）。

    static func reaction(variantID: String, salt: Int) -> Advice {
        let pool = reactionPools[variantID] ?? [Advice(name: "俺", text: "よし、いくか。")]
        return pool[((salt % pool.count) + pool.count) % pool.count]
    }
    // 新規行はSkill採点済（全○）。相方名は焼き込まない（「谷口と、ネタ抜きで飯でも。」は既存・既知として残置）。
    private static let reactionPools: [String: [Advice]] = [
        "t_ネタ作り": [
            Advice(name: "俺", text: "書く日は、朝のうちに机を片づける。"),
            Advice(name: "俺", text: "昨日までの分を読み返してから、続きにかかる。"),
        ],
        "t_ネタ見せ会": [
            Advice(name: "俺", text: "客前で崩れる場所を、先に知っておく。"),
            Advice(name: "俺", text: "今日は序盤を試す。うしろは次でいい。"),
        ],
        "t_ネタ合わせ": [
            Advice(name: "俺", text: "止める場所を決めてから、頭から通す。"),
            Advice(name: "俺", text: "昨日ずれた間を、今日のうちに戻す。"),
        ],
        "t_ランニング・サウナ": [
            Advice(name: "俺", text: "今日はジム。ネタのことは考えない。"),
            Advice(name: "俺", text: "汗をかいて、今日は早く寝る。"),
        ],
        "t_フリーライブ": [
            Advice(name: "俺", text: "出番は短い。その分、頭から飛ばす。"),
            Advice(name: "俺", text: "終わったら、客の入りだけ数えておく。"),
        ],
        "job_キツい": [
            Advice(name: "俺", text: "体で稼ぐ日だ。声は使わない。"),
            Advice(name: "俺", text: "終わりの時間だけ確かめて、引き受けた。"),
        ],
        "job_標準": [
            Advice(name: "俺", text: "運びながら、頭の中でネタを回せる。"),
            Advice(name: "俺", text: "忙しい店のほうが、時間が早く過ぎる。"),
        ],
        "job_楽": [
            Advice(name: "俺", text: "座って数える仕事だ。頭は空けておける。"),
            Advice(name: "俺", text: "夕方には終わる。夜は直しに使える。"),
        ],
        "rest_完全休養": [
            Advice(name: "俺", text: "携帯を伏せて、昼まで寝る。"),
            Advice(name: "俺", text: "布団を干してから、寝直す。"),
        ],
        "rest_気分転換": [
            Advice(name: "俺", text: "一駅ぶん、歩いて帰る。"),
            Advice(name: "俺", text: "ネタ帳は持たずに出る。"),
        ],
        "rest_相方と過ごす": [
            Advice(name: "俺", text: "谷口と、ネタ抜きで飯でも。"),
            Advice(name: "俺", text: "今日はネタの話はなしにしよう。"),
            Advice(name: "俺", text: "夕方から会う。店は、向こうが決める。"),
        ],
        "offer": [
            Advice(name: "俺", text: "名前を覚えてもらえる仕事だ。受けよう。"),
            Advice(name: "俺", text: "日取りだけ確かめて、受けた。"),
        ],
    ]

    private static func pick(_ pool: [String], salt: Int) -> String {
        pool.isEmpty ? "" : pool[((salt % pool.count) + pool.count) % pool.count]
    }

    // MARK: ネタおろし（初披露＝Neta.isDown:false→true の瞬間・正典 docs/neta_system_redesign_v2.md §3-2補2）
    // 話者=俺（標準語・心の声）。manzai-drama-voice Skill 採点済（A表16項目・B表7項目・全○）。

    static func netaOroshi(salt: Int) -> String {
        pick(netaOroshiPool, salt: salt)
    }
    private static let netaOroshiPool = [
        "今夜、このネタを初めて客の前でやる。",
        "稽古では何十回もやった。客の前は今夜が初めてだ。",
        "初おろしだ。どこでウケるか、ちゃんと見ておこう。",
        "新ネタの初日だ。緊張するけど、やるしかない。",
    ]
}
