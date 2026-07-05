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
            return Advice(name: "俺", text: "そろそろ\(m.name)か。\(weakAbility)、あと少し上げときたいな。")
        }
        return Advice(name: "俺", text: pick(平常, salt: Int(state.fame) + Int(state.compat) + Int(state.stamina)))
    }

    private static let lowStamina = [
        "さすがに体が重い。無理はきかんな。",
        "疲れが抜けてへん。今日は無理せんとこ。",
    ]
    private static let lowMoney = [
        "今月きついな…バイト挟むか。",
        "財布が軽い。ネタより先に、家賃や。",
    ]
    private static let losing = [
        "何が足りないんだ…。",
        "同じ壁の前で、また止まってる気がする。",
    ]
    private static let passedLines = [   // 先週の大会を通過した余韻
        "先週の通過、悪くなかった。次いこ。",
        "手応えはあった。ここで気ぃ抜くなよ、俺。",
    ]
    private static let 平常 = [            // 場面を作らない・craftと決意だけ
        "今週も、一歩だけ前に。",
        "焦らず、四分をよくするだけや。",
        "調子は悪ない。このまま積も。",
    ]

    // MARK: 選んだ変種への一言反応（mockup準拠・ボケない内心）

    static func reaction(variantID: String) -> String {
        reactions[variantID] ?? "よし、いくか。"
    }
    private static let reactions: [String: String] = [
        "t_ネタ作り": "家で書くか。集中、もつかな。",
        "t_ネタ見せ会": "人前で試すのが一番効く。",
        "t_ネタ合わせ": "合わせは声を出してなんぼや。",
        "t_ランニング・サウナ": "整える。心と体からや。",
        "t_フリーライブ": "客は少ないけど、場数や。",
        "job_キツい": "引越しはキツいけど、背に腹はな。",
        "job_標準": "居酒屋、まあ無難や。",
        "job_楽": "今日は楽して稼ぐか。",
        "rest_完全休養": "今日はちゃんと寝よう。",
        "rest_気分転換": "少し気晴らしを。",
        "rest_相方と過ごす": "谷口と、ネタ抜きで飯でも。",
        "offer": "受けとくか。金は要る。",
    ]

    private static func pick(_ pool: [String], salt: Int) -> String {
        pool.isEmpty ? "" : pool[((salt % pool.count) + pool.count) % pool.count]
    }
}
