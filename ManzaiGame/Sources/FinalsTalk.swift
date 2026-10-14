// FinalsTalk.swift
// 決勝の「声」＝司会（MC）の進行と、採点直後の審査員講評（comedy_research_v2/r1 §3・§7-2・P4/P5・オーナー 2026-10-10）。
// 役割の分担: 司会＝進行と間（点数の良し悪しは言わない）／審査員＝評価（ユーモアは審査員と司会だけに許す・オーナー判断）。
// 講評の文案は docs/judge_design_v0.md（帯×審査員＋条件フック）と judge_comments_v1.md §2 から移植。
// 「笑」の字を含む行は使わない（judge-comments の恒久規約）。表示専用・golden非干渉（UI専用の決定的な選び方）。

import Foundation
import GameCore

// MARK: 司会

enum FinalsMC {
    /// 司会の名前（架空）。名前札・顔はこの名前で引く（FaceCatalog.speaker / SpeakerStyle.tagColor）
    static let name = "鳴海 ジョー"

    /// 籤で呼ばれた組の呼び込み
    static func call(order: Int, name: String) -> String {
        switch order {
        case 1: return "トップバッターは、\(name)！"
        case 10: return "いよいよ大トリです。\(name)！"
        default: return "\(order)番目は……\(name)！"
        }
    }
    static let startScoring = "審査員のみなさん、採点をお願いします！"

    /// 審査員のボケ行（型8）を司会が拾う1拍（r6_m1_judge_comments §5-4 X1〜X4・§7 P3）。文面は GameCore/JudgeTalk.pickups。
    /// 司会は評価を言わず、戻す／復唱／切る／流すだけ。reply は審査員の言い直し（具体物を差し込み済み）。
    static func pickup(after comment: String, scene: JudgeTalk.Scene = .init(), salt: Int = 0) -> JudgeTalk.Pickup? {
        JudgeTalk.pickup(after: comment, scene: scene, salt: salt)
    }
    /// 審査員に講評を振る（高い点の人には点を言い、低い点の人には「辛め」と添える）
    static func askJudge(_ judge: String, score: Int, high: Bool) -> String {
        let family = String(judge.split(separator: " ").first ?? Substring(judge))
        return high ? "\(family)さん、\(score)点。いかがでしたか？" : "\(family)さんは\(score)点と、少し辛めでした。いかがでしたか？"
    }
    static func seated(name: String, rank: Int) -> String { "\(name)、暫定\(rank)位！ 暫定席へどうぞ！" }
    static func eliminated(name: String, rank: Int) -> String { "\(name)、暫定\(rank)位。ここで敗退です。ありがとうございました！" }
    static let firstRoundEnd = "最終決戦に進むのは、この3組です！"
    static let startVoting = "審査員のみなさん、いちばん面白かった1組に投票をお願いします！"
    static let announceWinner = "今年の頂グランプリ、優勝は……！"
}

// MARK: 審査員講評（決勝・採点直後）

/// 決勝の講評の窓口。文面・差し込み・選び方は GameCore/JudgeTalk.swift（v1 書き直し・docs/judge_comment_rewrite_v1.md）。
/// 表示専用・golden非干渉（salt 剰余の決定的な選び方）。
enum FinalsJudgeTalk {
    static func band(_ score: Int) -> Character { JudgeTalk.band(score) }

    /// 講評1本＋（ボケ行なら）司会の拾い。high=最高点の審査員／false=最低点の審査員。
    static func comment(judge: String, score: Int, high: Bool, scene: JudgeTalk.Scene, salt: Int) -> JudgeTalk.FinalComment {
        JudgeTalk.finalComment(judge: judge, score: score, high: high, scene: scene, salt: salt)
    }
}
