// Endings.swift
// マルチエンディング（docs/endings_spec_v1.md）のデータ・判定・図鑑の保存。文章は仕様書の逐語（一字も変えない）。
// 判定は乱数を使わない（GameCore の式は不変・golden 非経路）。表示専用の層。

import SwiftUI
import GameCore

/// エンディング8種（番号は仕様書の #）。rawValue は図鑑の保存キー（変えない）
enum EndingID: String, Codable, CaseIterable, Identifiable {
    case nightEscape, breakup, gaveUp, keptGoing, tenYearsClose, tenYearsTrue, championRetire, championPair
    var id: String { rawValue }

    var number: Int {
        switch self {
        case .nightEscape: 1
        case .breakup: 2
        case .gaveUp: 3
        case .keptGoing: 4
        case .tenYearsClose: 5
        case .tenYearsTrue: 6
        case .championRetire: 7
        case .championPair: 8
        }
    }
    static func from(number n: Int) -> EndingID? { allCases.first { $0.number == n } }

    /// 図鑑の表記（題名）
    var title: String {
        switch self {
        case .nightEscape: "始発の駅"
        case .breakup: "右と左"
        case .gaveUp: "十冊目のノート"
        case .keptGoing: "来年の出番表"
        case .tenYearsClose: "十年分の年表"
        case .tenYearsTrue: "同じ劇場"
        case .championRetire: "勇退"
        case .championPair: "間の席"
        }
    }
    /// 区分（図鑑に小さく出す）
    enum Kind { case bad, bitter, normal, good, truth
        var label: String { switch self { case .bad: "バッド"; case .bitter: "ビター"; case .normal: "ノーマル"; case .good: "グッド"; case .truth: "トゥルー" } }
        /// バッド=灰／ビター=藍／ノーマル=生成り／グッド=金／トゥルー=朱
        var color: Color { switch self { case .bad: YoseColor.haiSumi; case .bitter: YoseColor.expTan; case .normal: YoseColor.kiDark; case .good: YoseColor.kin; case .truth: YoseColor.shu } }
    }
    var kind: Kind {
        switch self {
        case .nightEscape, .breakup: .bad
        case .gaveUp, .keptGoing: .bitter
        case .tenYearsClose: .normal
        case .championRetire: .good
        case .tenYearsTrue, .championPair: .truth
        }
    }
    /// 見ていない時のヒント1行（％・条件の数字は出さない）
    var hint: String {
        switch self {
        case .nightEscape: "お金が尽きた先にある終わり"
        case .breakup: "相方と会わない日が続いた先にある終わり"
        case .gaveUp: "決勝を知らないまま十年が過ぎ、二人が離れていた"
        case .keptGoing: "決勝を知らないまま十年。それでも二人は近くにいた"
        case .tenYearsClose: "決勝の舞台を知って、十年で区切った"
        case .tenYearsTrue: "決勝の舞台を知って、十年、二人は近くにいた"
        case .championRetire: "頂に立つ"
        case .championPair: "頂に立ち、二人は近くにいた"
        }
    }
    /// 一枚絵のキャプション（#7 は仕様に無い＝空）
    var caption: String {
        switch self {
        case .nightEscape: "始発は五時十二分に出た。"
        case .breakup: "楽屋口を出て、右と左に分かれた。"
        case .gaveUp: "十冊目のノートは、半分が白いままだった。"
        case .keptGoing: "来年の一月の欄に、もう二人の名前が書いてあった。"
        case .tenYearsClose: "十年分の行が、全部埋まった。"
        case .tenYearsTrue: "十一年目の一月も、同じ劇場の出番から始まる。"
        case .championRetire: ""
        case .championPair: "トロフィーは、二人の間の席に置いた。"
        }
    }

    // MARK: 判定（§1-1・§1-2。上から最初に当たったもの）

    /// 年末（解散・夜逃げはその週末）の結果から終わりを決める。まだ続くなら nil。乱数なし
    static func judge(outcome o: YearOutcome, compat: Double, history: [GameSession.YearRecord], year: Int, careerYears: Int) -> EndingID? {
        if o.bankrupt { return .nightEscape }                                          // #1
        if o.dissolved { return .breakup }                                             // #2
        if o.champion { return compat >= 15 ? .championPair : .championRetire }        // #8 / #7
        guard year >= careerYears else { return nil }                                  // まだ続く
        let finals = history.filter { $0.reachedFinal }.count
        switch (finals >= 1, compat >= 15) {
        case (true, true): return .tenYearsTrue                                        // #6
        case (true, false): return .tenYearsClose                                      // #5
        case (false, true): return .keptGoing                                          // #4
        case (false, false): return .gaveUp                                            // #3
        }
    }

    // MARK: 場面の文章（§3 逐語）

    /// 場面カード（S6b を通る #5・#7・#8 は S6b の後／前に付く分だけ。#7 は無し）。
    /// riftChoice＝予告で選んだもの（"A"/"B"/nil）。#2 場面1 の最後の一行が変わる
    func cards(riftChoice: String? = nil) -> [ReminiscenceCard] {
        func c(_ caption: String, mood: DuskMood = .eve, together: Bool = true, _ talk: [(String, String)]) -> ReminiscenceCard {
            ReminiscenceCard(caption: caption, mood: mood, talk: talk.map { Advice(name: $0.0, text: $0.1) }, together: together)
        }
        switch self {
        case .nightEscape:
            return [
                c("深夜二時。俺のアパート。", [("谷口", "電話出えへんから来たで。電気、止まってるやん"), ("俺", "払えるあてがない。朝までにここを出る"),
                                        ("谷口", "ほんまに行くんか。どこ行くん"), ("俺", "田舎に戻る。親戚の畑で働かせてもらう")]),
                c("午前四時。アパートの前。", [("谷口", "荷物、それだけか"), ("俺", "段ボール二つ。残りは置いていく"),
                                        ("谷口", "借金、少しなら俺も払えるで"), ("俺", "いい。それはお前の分じゃない")]),
                c("始発の前。駅のホーム。", together: false, [("谷口", "着いたら連絡してな。絶対やで"), ("俺", "わかった。向こうの番号もあとで送る")]),
            ]
        case .breakup:
            var first: [(String, String)] = [("谷口", "今日は俺から話あるねん。座って聞いてくれるか"), ("俺", "うん。聞く"),
                                             ("谷口", "もう一緒にやるの、やめよか。最近ほとんど会うてへんやろ"), ("俺", "……そうだな。俺もそう思ってた")]
            if riftChoice == "A" { first.append(("谷口", "前に話した夜のこと、ちゃんと覚えてるで")) }
            else if riftChoice == "B" { first.append(("谷口", "前に一回、言いかけたんやけどな")) }
            return [
                c("夜。谷口の部屋。", together: false, first),
                c("翌日の昼。事務所の応接室。", mood: .noon, [("真壁", "あなたたちが決めたなら、止めません。書類はこちらで出します"),
                                                    ("俺", "お願いします。今月の劇場の出番までは出ます"), ("谷口", "俺もそれは出ますわ")]),
                c("最後の出番の後。劇場の楽屋口。", together: false, [("谷口", "ロッカーの鍵、二本とも返しといたで"), ("俺", "ありがとう。お前はこれからどうする"),
                                                          ("谷口", "しばらくは工場のバイト増やすわ。そっちは"), ("俺", "まだ決めてない。決めたら連絡する")]),
            ]
        case .gaveUp:
            return [
                c("十二月の終わり。俺のアパート。", [("谷口", "来年のグランプリの申し込み、締め切り来週やで"), ("俺", "出さない。今年で終わりにする"), ("谷口", "……そうか。十年やもんな")]),
                c("年明け。バイト先の休憩室。", mood: .noon, [("布施店長", "……昼のシフト、一人辞めたんだよ。お前、来月から入れるか"),
                                                    ("俺", "入ります。夜はもう空けなくていいので"), ("布施店長", "……じゃあ名札、作り直しとく。遅れんなよ")]),
                c("三月。駅の改札前。", mood: .after, together: false, [("谷口", "俺、地元の役所の試験、受かってん。来週帰るわ"),
                                                          ("俺", "よかったな。向こうでも体に気をつけて"), ("谷口", "お前もな。たまには電話してや")]),
            ]
        case .keptGoing:
            return [
                c("年末。小さな劇場の楽屋。", [("谷口", "来年のグランプリ、また出すやろ"), ("俺", "出す。申し込みは俺がやっておく"), ("谷口", "ほな、来年もよろしく頼むわ")]),
                c("同じ夜。劇場の事務室。", [("支配人", "来年も月一で出とけ。同じ曜日や"), ("俺", "はい。お願いします"), ("谷口", "最前列のおばちゃん、来年も来てくれるかな")]),
                c("終電の前。駅までの道。", [("谷口", "バイト、来年も今のとこで続けるわ"), ("俺", "俺も。土日だけは空けてもらう"), ("谷口", "ほな、また一年、同じ感じでいこか")]),
            ]
        case .tenYearsClose:
            return [
                c("十二月。事務所の会議室。", mood: .noon, [("真壁", "来年も続けるなら、枠は取ります。どうしますか"), ("俺", "今年で区切ります。二人で話して決めました"),
                                                    ("谷口", "決勝に出られたんは、ほんまにありがたかったです")]),
                c("一月。最後の単独ライブの日。", [("谷口", "客席、思ったより埋まってるで"), ("俺", "来てくれた人に、帰りにちゃんと挨拶しよう")]),
                c("終演の後。劇場の前。", mood: .after, [("谷口", "俺、テレビの裏方の仕事、紹介してもろてん"), ("俺", "そうか。俺は春から運送の会社で働く"),
                                                 ("谷口", "ほな、どっちも朝早いな。たまに飯行こ")]),
            ]
        case .tenYearsTrue:
            return [
                c("年末。最初に二人で出た劇場。", [("谷口", "ここ、最初に二人で出たとこやな"), ("俺", "うん。今日の出番、ここで頼んだ")]),
                c("出番の前。舞台の袖。", [("谷口", "十年、ずっと隣におったな"), ("俺", "そうだな。出番、そろそろだ"), ("谷口", "せやな。ほな行こか")]),
                c("終演の後。劇場の前。", mood: .after, [("谷口", "来年のグランプリ、もう一回決勝行こな"), ("俺", "行こう。一月から週二で練習を入れる"),
                                                 ("谷口", "よっしゃ。体だけは壊さんとこな")]),
            ]
        case .championRetire:
            return []   // 既存の S6bView のまま（新しい文章なし）
        case .championPair:
            return [c("翌朝。ファミレスの前。", mood: .after, [("谷口", "明日から、ちょっと休もか"), ("俺", "うん。休んで、それから次のことを二人で決めよう"),
                                                       ("谷口", "ほな、来週また連絡するわ")])]
        }
    }
}

extension GameSession {
    /// 今の年末で決まる終わり（まだ続く年末は nil）
    var endingID: EndingID? {
        guard finished, let o = outcome else { return nil }
        return EndingID.judge(outcome: o, compat: state.compat, history: yearHistory, year: year, careerYears: config.careerYears)
    }
}

// MARK: 図鑑（周回をまたぐ・UserDefaults `mz.endingsSeen`）

struct EndingRecord: Codable, Equatable {
    var count: Int
    var firstSeenAt: Date
    var lastPartnerName: String
}

enum EndingBook {
    static let key = "mz.endingsSeen"

    static func load() -> [EndingID: EndingRecord] {
        #if DEBUG
        // 目視用：MZ_BOOKSEEN=1,3,7（エンド番号）で「見た」扱いの見本を出す（保存はしない）
        if let s = ProcessInfo.processInfo.environment["MZ_BOOKSEEN"] {
            var d: [EndingID: EndingRecord] = [:]
            for n in s.split(separator: ",").compactMap({ Int($0) }) {
                if let id = EndingID.from(number: n) { d[id] = EndingRecord(count: n, firstSeenAt: Date(), lastPartnerName: Names.partner) }
            }
            return d
        }
        #endif
        guard let data = UserDefaults.standard.data(forKey: key),
              let raw = try? JSONDecoder().decode([String: EndingRecord].self, from: data) else { return [:] }
        var out: [EndingID: EndingRecord] = [:]
        for (k, v) in raw { if let id = EndingID(rawValue: k) { out[id] = v } }
        return out
    }

    /// 見た終わりを記録（初回は日付を残し、以降は回数と相方の名前を更新）
    static func record(_ id: EndingID, partner: String) {
        var all = load()
        if var r = all[id] { r.count += 1; r.lastPartnerName = partner; all[id] = r }
        else { all[id] = EndingRecord(count: 1, firstSeenAt: Date(), lastPartnerName: partner) }
        let raw = Dictionary(uniqueKeysWithValues: all.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(raw) { UserDefaults.standard.set(data, forKey: key) }
    }
}
