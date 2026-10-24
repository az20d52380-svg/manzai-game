// StageOutfit.swift
// 舞台衣装の色（見た目だけ・GameCore 非接触）。standard は従来の直書き色と完全に同じ。
// 着ている衣装は UserDefaults（セーブとは別キー＝周回リセットで消さない）。所有は StoreManager が正。

import SwiftUI

struct OutfitColors {
    var accent: Color
    var body: [Color]
    var head: Color
    var hair: Color
    var hairStyle: HairStyle = .short   // 女性は .long/.bun（仮・ComboKind で切替）
}

/// 【仮】衣装の種類・色はオーナー判断待ち。standard 以外は差し替え口の動作確認用。
enum StageOutfit: String, CaseIterable {
    case standard, hakama, leopard

    static let defaultsKey = "stage_outfit"

    /// 今着ている衣装（未所有の物は standard に戻す。DEBUG は MZ_COSTUME で強制）
    static var current: StageOutfit {
        #if DEBUG
        if let s = ProcessInfo.processInfo.environment["MZ_COSTUME"], let o = StageOutfit(rawValue: s) { return o }
        #endif
        guard let s = UserDefaults.standard.string(forKey: defaultsKey), let o = StageOutfit(rawValue: s) else { return .standard }
        if o == .standard { return o }
        return MainActor.assumeIsolated { StoreManager.shared.owns(StoreIDs.costume(o.rawValue)) } ? o : .standard
    }

    /// 俺（左・青系）
    func ore(rival: Bool, kind: ComboKind = Names.kind) -> OutfitColors {
        var c = oreBase(rival: rival)
        if kind.meIsFemale && !rival {
            c.hairStyle = .long
            if self == .standard { c.accent = Color(hex: 0x5A4CB0); c.body = [Color(hex: 0x8A7BE8), Color(hex: 0x5A4CB0)] }
        }
        return c
    }
    private func oreBase(rival: Bool) -> OutfitColors {
        if rival { return OutfitColors(accent: YoseColor.tokiwa, body: [Color(hex: 0x3F7A55), YoseColor.tokiwa],
                                       head: Color(hex: 0xFFDFC2), hair: Color(hex: 0x40394F)) }
        switch self {
        case .standard: return OutfitColors(accent: Color(hex: 0x2E55B0), body: [Color(hex: 0x4A7BE8), Color(hex: 0x2E55B0)],
                                            head: Color(hex: 0xFFDFC2), hair: Color(hex: 0x40394F))
        case .hakama:   return OutfitColors(accent: Color(hex: 0x1F2A44), body: [Color(hex: 0x3A4A72), Color(hex: 0x1F2A44)],
                                            head: Color(hex: 0xFFDFC2), hair: Color(hex: 0x40394F))
        case .leopard:  return OutfitColors(accent: Color(hex: 0x7A4A12), body: [Color(hex: 0xD9A441), Color(hex: 0x7A4A12)],
                                            head: Color(hex: 0xFFDFC2), hair: Color(hex: 0x40394F))
        }
    }

    /// 谷口（右・赤系）
    func taniguchi(rival: Bool, kind: ComboKind = Names.kind) -> OutfitColors {
        var c = taniguchiBase(rival: rival)
        if kind.partnerIsFemale && !rival {
            c.hairStyle = .bun
            if self == .standard { c.accent = Color(hex: 0xC24B72); c.body = [Color(hex: 0xF07FA0), Color(hex: 0xC24B72)] }
        }
        return c
    }
    private func taniguchiBase(rival: Bool) -> OutfitColors {
        if rival { return OutfitColors(accent: YoseColor.kuroUrushi, body: [Color(hex: 0x5A504A), YoseColor.kuroUrushi],
                                       head: Color(hex: 0xFFDFC2), hair: Color(hex: 0x2E2838)) }
        switch self {
        case .standard: return OutfitColors(accent: Color(hex: 0xB02318), body: [Color(hex: 0xF0533E), Color(hex: 0xC22E1D)],
                                            head: Color(hex: 0xFFDFC2), hair: Color(hex: 0x2E2838))
        case .hakama:   return OutfitColors(accent: Color(hex: 0x4A1F3A), body: [Color(hex: 0x8A3A66), Color(hex: 0x4A1F3A)],
                                            head: Color(hex: 0xFFDFC2), hair: Color(hex: 0x2E2838))
        case .leopard:  return OutfitColors(accent: Color(hex: 0x2A2018), body: [Color(hex: 0x6A5238), Color(hex: 0x2A2018)],
                                            head: Color(hex: 0xFFDFC2), hair: Color(hex: 0x2E2838))
        }
    }
}
