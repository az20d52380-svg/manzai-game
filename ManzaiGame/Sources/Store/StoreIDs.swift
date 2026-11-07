// StoreIDs.swift
// 課金の商品ID・値段を1か所に集約。【すべて仮】アプリ名・bundle id・値段が決まったら、ここと Configuration.storekit を直す。
// 正本: docs/iap_design_v0.md §1。

import Foundation

enum StoreIDs {
    /// 【仮】bundle id が確定したら差し替える（project.yml の PRODUCT_BUNDLE_IDENTIFIER と揃える）
    static let prefix = "com.manzaigame.mvp"

    /// 広告カット（非消耗型・仮 480円）
    static let adFree = "\(prefix).adfree"
    /// 事務所選び（非消耗型・仮 480円）。UI はまだ作らない
    static let agency = "\(prefix).agency"
    /// ガチャ券（消耗型・仮 1回100円／10回1,000円）。買ったらその場で回す＝残高は貯めない（docs/costume_gacha_v0.md）
    static let ticket1 = "\(prefix).ticket1"
    static let ticket10 = "\(prefix).ticket10"
    /// 券の商品ID → 回数
    static let ticketCounts: [String: Int] = [ticket1: 1, ticket10: 10]
    static func isTicket(_ id: String) -> Bool { ticketCounts[id] != nil }

    static var all: [String] {
        [adFree, agency, ticket1, ticket10]
    }
}
