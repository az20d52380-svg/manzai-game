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
    private static let lowStamina = [
        "さすがに体が重い。無理はきかない。",
        "疲れが抜けていない。今日は無理しないでおこう。",
    ]
    private static let lowMoney = [
        "今月はきつい…バイトを挟むか。",
        "財布が軽い。ネタより先に、家賃だ。",
    ]
    private static let losing = [
        "何が足りないんだ…。",
        "同じ壁の前で、また止まっている気がする。",
    ]
    private static let passedLines = [   // 先週の大会を通過した余韻
        "先週の通過、悪くなかった。次に行こう。",
        "手応えはあった。ここで気を抜くなよ、俺。",
    ]
    private static let 平常 = [            // 場面を作らない・craftと決意だけ
        "今週も、一歩だけ前に。",
        "焦らず、四分をよくするだけだ。",
        "調子は悪くない。このまま積み上げよう。",
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
