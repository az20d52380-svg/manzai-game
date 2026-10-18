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
    /// 舞台衣装（非消耗型・仮 1着 120円）。名前は StageOutfit の rawValue
    static func costume(_ name: String) -> String { "\(prefix).costume.\(name)" }

    /// 仮の衣装名（StageOutfit.standard は無料の既定＝商品なし）
    static let costumeNames = ["hakama", "leopard"]

    static var all: [String] {
        [adFree, agency] + costumeNames.map(costume)
    }
}
