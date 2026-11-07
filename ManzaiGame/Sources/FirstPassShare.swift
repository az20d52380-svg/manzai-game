// FirstPassShare.swift
// 共有カードの出口 B-6：「初めての大会の通過」の祝いにだけ共有ボタンを1回出す。
// 端末に「出した」印を1つだけ持つ（セーブ本体は変えない＝SaveDataConventionTests の対象外）。入れるのはコンビ名・結果・アプリ名だけ（％なし）。

import SwiftUI

enum FirstPassShare {
    static let offeredKey = "manzai.firstPassShareOffered.v1"

    /// まだ一度も出していない時だけ真。
    static func shouldOffer(_ d: UserDefaults = .standard) -> Bool { !d.bool(forKey: offeredKey) }
    static func markOffered(_ d: UserDefaults = .standard) { d.set(true, forKey: offeredKey) }

    static let headline = "初めての通過"
    static func detail(roundName: String, year: Int) -> String { "\(roundName)　結成\(year)年目" }
}
