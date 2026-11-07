// AdProvider.swift
// 広告の差し込み口（iap_design_v0 §3-6）。広告会社が決まるまでは「何も出さない」実装だけ。
// 画面からは AdGate.shared.showInterstitial(at:) を呼ぶ。広告カット（StoreIDs.adFree）を持っていれば呼ばない。
// どの場面で出すか・広告会社・ATT の要否はオーナー判断待ち＝まだどの画面にもつないでいない。

import Foundation

/// 広告を出せる場面（どこで出すかは未定。名前は差し込み口の目印だけ）
enum AdPlacement: String, CaseIterable {
    case yearEnd      // 年末総決算のあと
    case tournament   // 大会の結果のあと
}

/// 広告会社の SDK を包む口。決まったらこれに合わせた実装を1つ足す
protocol AdProvider {
    func showInterstitial(at placement: AdPlacement, completion: @escaping () -> Void)
}

/// 何も出さない（広告会社が決まるまでの既定）。すぐ completion を呼ぶ
struct NoAdProvider: AdProvider {
    func showInterstitial(at placement: AdPlacement, completion: @escaping () -> Void) { completion() }
}

/// 広告を出すかの関所：広告カットを持っていれば provider を呼ばずに先へ進める
@MainActor
final class AdGate {
    static let shared = AdGate()
    var provider: AdProvider = NoAdProvider()
    /// 広告カットを持っているか（既定は StoreManager。テストでは差し替える）
    var isAdFree: () -> Bool = { StoreManager.shared.isAdFree }
    private(set) var shownCount = 0

    func showInterstitial(at placement: AdPlacement, completion: @escaping () -> Void) {
        guard !isAdFree() else { completion(); return }
        shownCount += 1
        provider.showInterstitial(at: placement, completion: completion)
    }
}
