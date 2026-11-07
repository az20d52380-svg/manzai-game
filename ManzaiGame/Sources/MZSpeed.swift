// MZSpeed.swift
// 演出の速さ（設定：ふつう／はやい）。表示の待ち時間だけを縮める。式・乱数・判定には関与しない。

import Foundation

enum MZSpeed {
    static let key = "anim_speed"   // 0=ふつう 1=はやい
    static var isFast: Bool { UserDefaults.standard.integer(forKey: key) == 1 }
    static var factor: Double { isFast ? 0.5 : 1.0 }
    /// 待ち時間を設定に合わせて縮める Task.sleep
    static func sleep(nanoseconds ns: UInt64) async throws {
        try await Task.sleep(nanoseconds: UInt64(Double(ns) * factor))
    }
}
