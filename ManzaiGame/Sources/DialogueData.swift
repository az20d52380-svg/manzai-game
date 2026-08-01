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
    static func innerVoice(state: GameState, lossStreak: Int, justPassed: Bool, justLost: Bool,
                           nextMilestone: (name: String, weeksLeft: Int)?, weakAbility: String) -> Advice {
        if state.recoveryWeeks > 0 {   // 療養中は全てに優先（体の異常＝Fable13§2）
            return Advice(name: "俺", text: pick(recovering, salt: state.recoveryWeeks))
        }
        if state.stamina < 25 {
            return Advice(name: "俺", text: pick(lowStamina, salt: Int(state.stamina)))
        }
        if state.money < 30_000 {
            return Advice(name: "俺", text: pick(lowMoney, salt: state.money))
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
        if let m = nextMilestone, m.weeksLeft <= 2 {
            return Advice(name: "俺", text: "そろそろ\(m.name)か。\(weakAbility)、あと少し上げておきたい。")
        }
        if let m = nextMilestone, m.weeksLeft >= 6 {   // 本番が遠い週（週16-26の空白帯等）は仕込みの声
            return Advice(name: "俺", text: pick(midseason, salt: Int(state.fame) &+ m.weeksLeft))
        }
        return Advice(name: "俺", text: pick(平常, salt: Int(state.fame) + Int(state.compat) + Int(state.stamina)))
    }

    // 主人公「俺」は標準語（方言なし）。ツッコミ体質・心配性・計算屋の色は残す。
    // 本文は voice_corpus_v0（calibration 0be8a11）の◯行を逐語転記（§1 seed＋§8 底上げ・補充）。
    // 相方固有名は焼き込まない（innerVoice はコード上相方非依存）。数値・最終確定は実機目視。
    private static let recovering = [   // 療養中（recoveryWeeks>0）・Fable13§2・Skill採点済。発生週専用の一発告知は別途
        "今週も、声は出さない。ネタ帳の直しだけ、膝の上で進める。",
    ]
    private static let lowStamina = [
        "稽古場の三階まで、今日は二回、踊り場で止まった。",
        "昨日の合わせ、三分目から声が薄くなった。",
        "稽古の帰り、座れる電車を一本待った。",
        "合わせは一本ごとに、休みを長めに挟んだ。今週は、そこは削らない。",
        "稽古の前に、一度横になった。そうしないと、体が動かなかった。",
        "発声は、今日は座ったままやった。立ってやる分は、本番に取っておく。",
    ]
    private static let lowMoney = [
        "稽古場代の缶が軽い。今月は、入れる方が少なかった。",
        "二人で買った中古のマイクスタンドの相場を、調べかけて、やめた。",
        "今週はバイトを入れる。合わせは、引越しの荷台を降りてからでもできる。",
        "去年の遠征の領収書を、輪ゴムでひと束にして取ってある。今年の分は、まだ薄い。",
        "先週の営業でもらった袋は、封を切る前に、半分の行き先が決まっていた。",
        "二人で通う定食屋に、少しだけ、つけがたまっていた。今月は、そこから先に払った。",
    ]
    private static let losing = [
        "来年の予定表の同じ週に、丸をつけた。二重にした。",
        "講評を二回読んで、ネタ帳に挟んだ。直しの順番を、先に決めた。",
        "去年の敗因の書き出しを、机に戻した。半分は、まだ直っていない。",
        "詰める場所は、今年も一つに絞れた。四分の後半、その一点だけだ。前も、そこだった。",
        "負けた回の録音を、続けて聞いた。声が細る場所が、どれも同じだった。",
        "先に名前を呼ばれた組を、何組か続けて客席から見た。ネタの出来より先に、板に出た一秒の掴みが違う。",
    ]
    private static let justLostSingle = [   // 負けた翌週（lossStreak==1）・谷に一滴を置かない（Fable13便・Skill採点済）
        "洗濯物が、二日ぶんまとまっていた。先にそれを片づけてから、今週を始めた。",
        "負けた週の次の週も、起きる時間は変えなかった。",
    ]
    private static let justLostRepeat = [   // 連敗中にまた負けた翌週（lossStreak≥2）
        "また同じ段で終わった。今年の残りの大会を、指で数えた。",
        "直すべき場所の見当は、先週と同じところについた。当たっているかどうかは、今週の通しで確かめる。",
    ]
    private static let passedLines = [   // 先週の大会を通過した余韻
        "名簿に残った。次の会場は、客席が少し多い。",
        "通った週の相方は、朝が早い。今朝はもう、次の合わせの日どりを聞いてきた。",
        "通過ひとつで歩幅が変わるのは、我ながら安い。今週は、普通に歩く。",
        "通った週も、稽古の組み方は先週のままにした。変えるのは、通過が続いてからでいい。",
        "通った日の客席のざわめきが、しばらく耳に残っていた。次の稽古の初日まで、それで足りた。",
    ]
    private static let 平常 = [            // 場面を作らない・craftと決意だけ
        "四分の頭の十五秒を、今週は詰める。",
        "先週から直している一本を、今週のうちに相方へ見せるところまで持っていく。",
        "新ネタの二本目が、まだ立っていない。今週中に立たせる。",
        "相方との合わせは木曜。それまでに直しを終わらせておく。",
        "稽古場は火曜と金曜が取れた。配分は、あとで考える。",
        "今週ぶんの段取りは、日曜の夜に決めてある。",
        "今週は稽古を三回に分ける。二回は通し、一回は頭の直しだけにする。",
        "新ネタは一本に絞った。二本並行はやめて、今月はこれだけ回す。",
        "金曜の合わせは、後半の四十秒から始める。前半は各自でやってくる。",
        "通しの録音は、週の頭に一本だけ残して、古いのは消しておく。",
        "持ちネタの棚卸しを、今週のうちにやる。使う三本と、寝かせる分に分ける。",
        "相方の入りが遅い週は、稽古を夜に寄せる。今週がそれだ。",
        "来週の合わせまでに、俺のぶんの直しを二箇所、終わらせておく。",
    ]

    private static let midseason = [   // 本番まで≥6週の空白帯（中だるみ対策・仕込みの声）・Skill採点済（A表/B表全○）
        "次の本番まで、まだ間がある。大きい直しは、今のうちだ。",
        "白い週が続く。稽古場の鍵当番だけが、週の区切りになっている。",
        "客前の予定がない週は、朝の発声から崩れやすい。時間だけは変えない。",
        "急ぎの用がない週は、やることを先に三つ決める。",
        "本番が遠い週の通しは、客がいない分、粗が全部こっちに聞こえる。",
        "急がずに一本作れるのは、年のうちでこの辺りだけだ。",
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
             Advice(name: "俺", text: "長いと思って組む。前半は作る、後半は詰める")],
            [Advice(name: "谷口", text: "新しいの、一本書かへんか。時間あるうちに"),
             Advice(name: "俺", text: "書きかけを先に片す。新しいのはその後だ")],
            [Advice(name: "谷口", text: "静かな週やな"),
             Advice(name: "俺", text: "通しを二本入れてある。静かなうちに回す")],
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
             Advice(name: "俺", text: "俺もだ。線を引いた行が、二人とも同じだった")],
            [Advice(name: "谷口", text: "稽古場、来週から一枠増やせるで。俺のバイト、水曜空いたし"),
             Advice(name: "俺", text: "なら水曜は通しに使う")],
            [Advice(name: "谷口", text: "今日は何時までやる"),
             Advice(name: "俺", text: "九時までだ。それより先は、明日に回す")],
        ],
        .broke: [
            [Advice(name: "谷口", text: "今月、稽古場代どうすんの"),
             Advice(name: "俺", text: "先に半分入れてある。残りはバイトの後だ")],
            [Advice(name: "谷口", text: "まかない付きのバイト、まだ枠あるらしいで"),
             Advice(name: "俺", text: "入れておいてくれ。合わせは、その後でやる")],
            [Advice(name: "谷口", text: "遠征の積立、今月は無しでええか"),
             Advice(name: "俺", text: "無しだ。来月、倍にする")],
        ],
        .afterPass: [
            [Advice(name: "谷口", text: "次の会場、下見行っとくか"),
             Advice(name: "俺", text: "行こう。板の広さだけ、先に見ておきたい")],
            [Advice(name: "谷口", text: "こないだの客、ようウケとったな"),
             Advice(name: "俺", text: "どこでウケたかは、控えてある")],
            [Advice(name: "谷口", text: "祝いや。今日は俺が出したる"),
             Advice(name: "俺", text: "なら安い方の店にしよう。遠征代が要る")],
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
            Advice(name: "俺", text: "家で書くか。集中がもつかどうか。"),
            Advice(name: "俺", text: "書く日は、朝のうちに机を片づける。"),
            Advice(name: "俺", text: "昨日までの分を読み返してから、続きにかかる。"),
        ],
        "t_ネタ見せ会": [
            Advice(name: "俺", text: "人前で試すのが一番効く。"),
            Advice(name: "俺", text: "客前で崩れる場所を、先に知っておく。"),
            Advice(name: "俺", text: "今日は序盤を試す。うしろは次でいい。"),
        ],
        "t_ネタ合わせ": [
            Advice(name: "俺", text: "合わせは、声を出してこそだ。"),
            Advice(name: "俺", text: "止める場所を決めてから、頭から通す。"),
            Advice(name: "俺", text: "昨日ずれた間を、今日のうちに戻す。"),
        ],
        "t_ランニング・サウナ": [
            Advice(name: "俺", text: "整える。心と体からだ。"),
            Advice(name: "俺", text: "走る日は、ネタのことは考えない。"),
            Advice(name: "俺", text: "汗をかいて、今日は早く寝る。"),
        ],
        "t_フリーライブ": [
            Advice(name: "俺", text: "客は少ないけど、場数だ。"),
            Advice(name: "俺", text: "出番は短い。その分、頭から飛ばす。"),
            Advice(name: "俺", text: "終わったら、客の入りだけ数えておく。"),
        ],
        "job_キツい": [
            Advice(name: "俺", text: "引越しはキツいけど、背に腹は代えられない。"),
            Advice(name: "俺", text: "体で稼ぐ日だ。声は使わない。"),
            Advice(name: "俺", text: "終わりの時間だけ確かめて、引き受けた。"),
        ],
        "job_標準": [
            Advice(name: "俺", text: "居酒屋、まあ無難だ。"),
            Advice(name: "俺", text: "運びながら、頭の中でネタを回せる。"),
            Advice(name: "俺", text: "店は忙しい方が、時間が早い。"),
        ],
        "job_楽": [
            Advice(name: "俺", text: "今日は楽して稼ぐか。"),
            Advice(name: "俺", text: "座って数える仕事だ。頭は空けておける。"),
            Advice(name: "俺", text: "夕方には終わる。夜は直しに使える。"),
        ],
        "rest_完全休養": [
            Advice(name: "俺", text: "今日はちゃんと寝よう。"),
            Advice(name: "俺", text: "携帯を伏せて、昼まで寝る。"),
            Advice(name: "俺", text: "布団を干してから、寝直す。"),
        ],
        "rest_気分転換": [
            Advice(name: "俺", text: "少し気晴らしを。"),
            Advice(name: "俺", text: "一駅ぶん、歩いて帰る。"),
            Advice(name: "俺", text: "ネタ帳は持たずに出る。"),
        ],
        "rest_相方と過ごす": [
            Advice(name: "俺", text: "谷口と、ネタ抜きで飯でも。"),
            Advice(name: "俺", text: "ネタの話はなしで行く。たぶん、途中までだが。"),
            Advice(name: "俺", text: "夕方から会う。店は、向こうが決める。"),
        ],
        "offer": [
            Advice(name: "俺", text: "受けておくか。金は要る。"),
            Advice(name: "俺", text: "名前を覚えてもらう仕事だ。断る理由が薄い。"),
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
        "稽古場では、台本を横に置いていた。今夜は、それを持たずに立つ。",
        "このネタを、俺たちは何十回も読んだ。今夜の客には、初耳だ。",
        "板の上に立つ位置は、テープの印で決まっている。それを自分の足で踏むのは、これが最初だ。",
        "客は八人。全員、このネタを聞くのは今夜が初めてだった。俺たちだけが、先に結末を知っていた。",
    ]
}
