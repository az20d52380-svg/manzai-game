// ComboKind.swift
// コンビの形（男コンビ／女コンビ／男女コンビ）。表示・見た目専用で golden 非対象（docs/combo_gender_v0.md §2）。
// 後ろ2つは男女コンビで「自分が男／自分が女」。旧セーブ（nil）＝男コンビ。

import Foundation

enum ComboKind: String, Codable, CaseIterable {
    case maleMale, femaleFemale, maleFemale, femaleMale

    static func from(_ raw: String?) -> ComboKind { raw.flatMap { ComboKind(rawValue: $0) } ?? .maleMale }

    /// 自分（主人公）が女か
    var meIsFemale: Bool { self == .femaleFemale || self == .femaleMale }
    /// 相方が女か
    var partnerIsFemale: Bool { self == .femaleFemale || self == .maleFemale }

    /// 自分の一人称
    var meFirstPerson: String { meIsFemale ? "私" : "俺" }
    /// 相方の一人称
    var partnerFirstPerson: String { partnerIsFemale ? "私" : "俺" }

    /// 選ぶ画面のカード見出し
    var cardTitle: String {
        switch self {
        case .maleMale: return "男コンビ"
        case .femaleFemale: return "女コンビ"
        case .maleFemale: return "男女コンビ"
        case .femaleMale: return "男女コンビ"
        }
    }
    var cardSub: String {
        switch self {
        case .maleMale: return "二人とも男"
        case .femaleFemale: return "二人とも女"
        case .maleFemale: return "自分が男・相方が女"
        case .femaleMale: return "自分が女・相方が男"
        }
    }
}
