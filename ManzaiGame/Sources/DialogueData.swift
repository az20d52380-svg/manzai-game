// DialogueData.swift
// 会話＝主人公「俺」の心の声（内心モノローグ）。mvp_ui_build_prompt_v1 §3-4：
// 常時出るのは俺の独白（助言・嘆き・人間味）。ボケない。谷口/先輩の会話は将来レアイベントで（毎週は出さない）。
// 状態駆動：大会前=助言／低体力／金欠／連敗。加えて選んだ行動への一言反応。全て【仮】。

import Foundation
import GameCore

struct Advice {
    let name: String?     // "俺"（独白）。将来のレアイベントで谷口等に切替
    let text: String
}

enum DialogueData {

    // MARK: 週頭（行動前）の状態駆動モノローグ

    /// 週頭（行動選択前）の一般セリフ。状態・状況・先週の結果だけに紐づける。
    /// 未選択の行動や、その週いない場所（楽屋等）の話はしない。
    /// 優先度: 低体力 > 金欠 > 連敗 > 直近通過 > 大会前 > 平常
    static func innerVoice(state: GameState, lossStreak: Int, justPassed: Bool,
                           nextMilestone: (name: String, weeksLeft: Int)?, weakAbility: String) -> Advice {
        if state.stamina < 25 {
            return Advice(name: "俺", text: pick(lowStamina, salt: Int(state.stamina)))
        }
        if state.money < 30_000 {
            return Advice(name: "俺", text: pick(lowMoney, salt: state.money))
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
        return Advice(name: "俺", text: pick(平常, salt: Int(state.fame) + Int(state.compat) + Int(state.stamina)))
    }

    // 主人公「俺」は標準語（方言なし）。ツッコミ体質・心配性・計算屋の色は残す。
    // 本文は voice_corpus_v0（calibration 0be8a11）の◯行を逐語転記（§1 seed＋§8 底上げ・補充）。
    // 相方固有名は焼き込まない（innerVoice はコード上相方非依存）。数値・最終確定は実機目視。
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

    // MARK: 選んだ変種への一言反応（mockup準拠・ボケない内心）

    static func reaction(variantID: String) -> String {
        reactions[variantID] ?? "よし、いくか。"
    }
    private static let reactions: [String: String] = [
        "t_ネタ作り": "家で書くか。集中がもつかどうか。",
        "t_ネタ見せ会": "人前で試すのが一番効く。",
        "t_ネタ合わせ": "合わせは、声を出してこそだ。",
        "t_ランニング・サウナ": "整える。心と体からだ。",
        "t_フリーライブ": "客は少ないけど、場数だ。",
        "job_キツい": "引越しはキツいけど、背に腹は代えられない。",
        "job_標準": "居酒屋、まあ無難だ。",
        "job_楽": "今日は楽して稼ぐか。",
        "rest_完全休養": "今日はちゃんと寝よう。",
        "rest_気分転換": "少し気晴らしを。",
        "rest_相方と過ごす": "谷口と、ネタ抜きで飯でも。",
        "offer": "受けておくか。金は要る。",
    ]

    private static func pick(_ pool: [String], salt: Int) -> String {
        pool.isEmpty ? "" : pool[((salt % pool.count) + pool.count) % pool.count]
    }
}
