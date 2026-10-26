// MeetingKind.swift
// 相方との出会い方（導入の回想の型）。名前決め（結成届）で選び、決めた後の回想をその型で流す（キュー63・オーナー決定 10/20）。
// 表示専用：能力・相性・乱数・GameCore には触れない（golden 非対象）。旧セーブ（nil）＝①高校の同級生。
// 台詞は docs/intro_meeting_variants_v0.md §5（谷口版を v3 の決まり・男女どちらでも通る語尾へ）。①は今の回想の文のまま。

import Foundation

enum MeetingKind: String, Codable, CaseIterable {
    case highSchool, school, partTime, afterBreakup

    static func from(_ raw: String?) -> MeetingKind { raw.flatMap { MeetingKind(rawValue: $0) } ?? .highSchool }

    /// 結成届の「出会い」欄に出す名前
    var label: String {
        switch self {
        case .highSchool: return "高校の同級生"
        case .school: return "養成所の同期"
        case .partTime: return "バイト先"
        case .afterBreakup: return "前のコンビの解散後"
        }
    }

    #if DEBUG
    /// 目視用: MZ_MEET=1〜4 で回想をその型で直接流す（1＝高校の同級生 … 4＝前のコンビの解散後）
    static var debugForced: MeetingKind? {
        guard let n = Int(ProcessInfo.processInfo.environment["MZ_MEET"] ?? ""), allCases.indices.contains(n - 1) else { return nil }
        return allCases[n - 1]
    }
    #endif

    /// 回想の3枚（形は①に揃える：吹き出し3／1／3・3枚目は楽屋）
    var cards: [ReminiscenceCard] {
        let gakuya = "数年後。吉竹興行に所属して、小さな劇場の楽屋。"
        switch self {
        case .highSchool:
            // 文言は既存のまま（2枚目の台詞だけ谷口の吹き出しへ分けた）。10/25 語尾だけ男女どちらでも通る形に（combo_gender_v0 §8）
            return [
                ReminiscenceCard(caption: "高校の教室。休み時間。",
                                 mood: .noon,
                                 talk: [Advice(name: "谷口", text: "その消しゴム、落としたよ"),
                                        Advice(name: "俺", text: "あ、ありがとう。隣のクラスの？"),
                                        Advice(name: "谷口", text: "谷口っていうんだ。購買、一緒に行かない？")],
                                 together: false),
                ReminiscenceCard(caption: "放課後の廊下。",
                                 mood: .after, speaker: "谷口", line: "コンビ、組まない？"),
                ReminiscenceCard(caption: gakuya, mood: .eve,
                                 talk: [Advice(name: "谷口", text: "緊張してきた。手、冷たいんだ"),
                                        Advice(name: "俺", text: "水、飲んどきなよ。次が出番だよ"),
                                        Advice(name: "谷口", text: "そうだね。じゃあ、行こうか")],
                                 backdrop: .init(.gakuya, .evening)),   // 字幕どおり楽屋の絵（教室・廊下は絵が無いので夕景のまま）
            ]
        case .school:
            return [
                ReminiscenceCard(caption: "養成所の教室。昼休み。",
                                 mood: .noon,
                                 talk: [Advice(name: "谷口", text: "ここ、空いてる？ 同じクラスの谷口っていうんだ"),
                                        Advice(name: "俺", text: "どうぞ。入学式で隣だったよね"),
                                        Advice(name: "谷口", text: "そうそう。帰りに、牛丼でも食べていかない？")],
                                 together: false),
                ReminiscenceCard(caption: "夜の帰り道。",
                                 mood: .night, speaker: "谷口", line: "コンビ、組まない？",
                                 backdrop: .init(.street, .night)),
                ReminiscenceCard(caption: gakuya, mood: .eve,
                                 talk: [Advice(name: "谷口", text: "同期がみんな見に来てるって。手、冷たいんだ"),
                                        Advice(name: "俺", text: "水、飲んどきなよ。次が出番だよ"),
                                        Advice(name: "谷口", text: "そうだね。じゃあ、行こうか")],
                                 backdrop: .init(.gakuya, .evening)),
            ]
        case .partTime:
            return [
                ReminiscenceCard(caption: "ファミレスの休憩室。昼すぎ。",
                                 mood: .noon,
                                 talk: [Advice(name: "谷口", text: "新しい人？ 谷口っていうんだ、よろしくね"),
                                        Advice(name: "俺", text: "よろしく。今日から昼のシフトに入るよ"),
                                        Advice(name: "谷口", text: "まかないのカレー、おいしいよ。一緒に食べよう")],
                                 together: false),
                ReminiscenceCard(caption: "閉店後の駐車場。",
                                 mood: .night, speaker: "谷口", line: "コンビ、組まない？",
                                 backdrop: .init(.street, .night)),
                ReminiscenceCard(caption: gakuya, mood: .eve,
                                 talk: [Advice(name: "谷口", text: "バイト、休みが取れたよ。店長に頭を下げたんだ"),
                                        Advice(name: "俺", text: "{me}も代わってもらった。次が出番だよ"),
                                        Advice(name: "谷口", text: "そうだね。じゃあ、行こうか")],
                                 backdrop: .init(.gakuya, .evening)),
            ]
        case .afterBreakup:
            return [
                ReminiscenceCard(caption: "駅前の喫茶店。昼すぎ。",
                                 mood: .noon,
                                 talk: [Advice(name: "谷口", text: "紹介で来た谷口です。座ってもいい？"),
                                        Advice(name: "俺", text: "どうぞ。前のコンビのこと、聞いてるよ"),
                                        Advice(name: "谷口", text: "じゃあ話が早いね。コーヒー、何にする？")],
                                 together: false, backdrop: .init(.kissaten, .day)),
                ReminiscenceCard(caption: "夕方の駅のホーム。",
                                 mood: .after, speaker: "谷口", line: "コンビ、組まない？",
                                 backdrop: .init(.station, .evening)),
                ReminiscenceCard(caption: gakuya, mood: .eve,
                                 talk: [Advice(name: "谷口", text: "前の相方、客席に来てるらしいんだ"),
                                        Advice(name: "俺", text: "気にしないで。次が出番だよ"),
                                        Advice(name: "谷口", text: "そうだね。じゃあ、行こうか")],
                                 backdrop: .init(.gakuya, .evening)),
            ]
        }
    }
}
