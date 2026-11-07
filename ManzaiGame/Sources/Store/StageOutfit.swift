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

/// 衣装（見た目だけ）。standard=最初の1着、kuromontsuki=広告カットに付く1着、残り12着がガチャ。名前・色はすべて【仮】。
enum StageOutfit: String, CaseIterable {
    case standard, kuromontsuki
    case kon, gray, azuki, wakakusa, karashi            // 色替え
    case stripe, check, garashirt, jersey               // 柄
    case hakama, leopard, kira                          // 特別

    static let defaultsKey = "stage_outfit"

    /// ガチャでの段（nil=ガチャの対象外）
    var rarity: OutfitRarity? {
        switch self {
        case .standard, .kuromontsuki: return nil
        case .kon, .gray, .azuki, .wakakusa, .karashi: return .iro
        case .stripe, .check, .garashirt, .jersey: return .gara
        case .hakama, .leopard, .kira: return .tokubetsu
        }
    }

    var displayName: String {
        switch self {
        case .standard: return "標準"
        case .kuromontsuki: return "黒紋付"
        case .kon: return "紺スーツ"
        case .gray: return "グレースーツ"
        case .azuki: return "小豆スーツ"
        case .wakakusa: return "若草スーツ"
        case .karashi: return "からし色スーツ"
        case .stripe: return "ストライプ"
        case .check: return "チェック"
        case .garashirt: return "柄シャツ"
        case .jersey: return "ジャージ"
        case .hakama: return "袴"
        case .leopard: return "豹柄"
        case .kira: return "きらきらジャケット"
        }
    }

    /// 今持っているか（standard は常に・黒紋付は広告カット購入で・残りはガチャで）
    @MainActor var isOwned: Bool { GachaStore.shared.owns(self) }

    /// 今着ている衣装（未所有の物は standard に戻す。DEBUG は MZ_COSTUME で強制）
    static var current: StageOutfit {
        #if DEBUG
        if let s = ProcessInfo.processInfo.environment["MZ_COSTUME"], let o = StageOutfit(rawValue: s) { return o }
        #endif
        guard let s = UserDefaults.standard.string(forKey: defaultsKey), let o = StageOutfit(rawValue: s) else { return .standard }
        if o == .standard { return o }
        return MainActor.assumeIsolated { o.isOwned } ? o : .standard
    }

    static func wear(_ o: StageOutfit) { UserDefaults.standard.set(o.rawValue, forKey: defaultsKey) }

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
        let p = palette.ore
        return OutfitColors(accent: Color(hex: p.0), body: [Color(hex: p.1), Color(hex: p.2)],
                            head: Color(hex: 0xFFDFC2), hair: Color(hex: 0x40394F))
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
        let p = palette.tan
        return OutfitColors(accent: Color(hex: p.0), body: [Color(hex: p.1), Color(hex: p.2)],
                            head: Color(hex: 0xFFDFC2), hair: Color(hex: 0x2E2838))
    }

    /// 【仮】色替え。(accent, 胴の上, 胴の下) を俺・相方で。standard/hakama/leopard は従来と同じ値
    private typealias Hex3 = (UInt, UInt, UInt)
    private var palette: (ore: Hex3, tan: Hex3) {
        switch self {
        case .standard:     return ((0x2E55B0, 0x4A7BE8, 0x2E55B0), (0xB02318, 0xF0533E, 0xC22E1D))
        case .kuromontsuki: return ((0x1E1916, 0x3A3532, 0x1E1916), (0x1E1916, 0x4A4440, 0x1E1916))
        case .kon:          return ((0x1B2B55, 0x2C447F, 0x1B2B55), (0x24334F, 0x3C5278, 0x24334F))
        case .gray:         return ((0x5A5E66, 0x9096A0, 0x5A5E66), (0x66605A, 0xA39C94, 0x66605A))
        case .azuki:        return ((0x5A2A22, 0x8A4A3C, 0x5A2A22), (0x4A2A30, 0x7C4650, 0x4A2A30))
        case .wakakusa:     return ((0x3C7A38, 0x74B860, 0x3C7A38), (0x2F6A44, 0x5FA578, 0x2F6A44))
        case .karashi:      return ((0x8A7418, 0xCDB64A, 0x8A7418), (0x7A5E18, 0xBE9C44, 0x7A5E18))
        case .stripe:       return ((0x2A2E3A, 0x6A7084, 0x2A2E3A), (0x3A2A2E, 0x84666C, 0x3A2A2E))
        case .check:        return ((0x6A3A18, 0xC47A3C, 0x6A3A18), (0x3A4A2A, 0x749058, 0x3A4A2A))
        case .garashirt:    return ((0xB0306A, 0xF07AB0, 0xB0306A), (0x1E7A8A, 0x5CC4D4, 0x1E7A8A))
        case .jersey:       return ((0x1A5A8A, 0x3C96D0, 0x1A5A8A), (0xA02A2A, 0xDC5A5A, 0xA02A2A))
        case .hakama:       return ((0x1F2A44, 0x3A4A72, 0x1F2A44), (0x4A1F3A, 0x8A3A66, 0x4A1F3A))
        case .leopard:      return ((0x7A4A12, 0xD9A441, 0x7A4A12), (0x2A2018, 0x6A5238, 0x2A2018))
        case .kira:         return ((0x6A6A7A, 0xD8DAE8, 0x8A8AA0), (0x7A5A8A, 0xCDB4E0, 0x7A5A8A))
        }
    }
}
