// イベント会話背景（Argon 作 event_backgrounds_argon_v1.md §2-§4 を取り込み）。外部画像なし・人物の顔なし。
import SwiftUI

/// イベントの場所（出現頻度順・全11種）
public enum EventPlace: String, CaseIterable, Codable, Sendable {
    case keikoba     // 1. 稽古場（ホワイトボード・パイプ椅子）
    case station     // 2. 駅（ホーム・駅名標・黄色い点字ブロック）
    case apartment   // 3. 部屋（安アパート・畳・ちゃぶ台・裸電球）
    case gakuya      // 4. 楽屋（ハリウッドミラー・香盤表めくり・暖簾）
    case train       // 5. 電車の中（車窓・吊り革・ロングシート）
    case park        // 6. 公園（ベンチ・街灯・木立・水飲み場）
    case famires     // 7. ファミレス（赤いボックス席・吊りランプ・ネタ帳）
    case sento       // 8. 銭湯（タイル壁・富士山のペンキ絵・ケロリン桶）
    case theater     // 9. 劇場（客席/ロビー・赤いモケット椅子・定式幕）
    case kissaten    // 10. 喫茶店（レンガ壁・ステンドグラス照明・サイフォン）
    case office      // 11. 事務所（ブラインド窓・稼働番付ボード・事務机）

    public var label: String {
        switch self {
        case .keikoba:   return "稽古場"
        case .station:   return "駅ホーム"
        case .apartment: return "安アパート"
        case .gakuya:    return "劇場の楽屋"
        case .train:     return "電車内"
        case .park:      return "公園"
        case .famires:   return "ファミレス"
        case .sento:     return "銭湯"
        case .theater:   return "劇場"
        case .kissaten:  return "純喫茶"
        case .office:    return "事務所"
        }
    }
}

/// イベントの時間帯（全4種）
public enum EventTimeOfDay: String, CaseIterable, Codable, Sendable {
    case morning // 朝（爽やかな朝光・淡い水色と白光）
    case day     // 昼（基準色・フィルターなし）
    case evening // 夕（茜色・琥珀の斜光）
    case night   // 夜（黒漆・濃紺の減光＋電球色の灯り）

    public var label: String {
        switch self {
        case .morning: return "朝"
        case .day:     return "昼"
        case .evening: return "夕"
        case .night:   return "夜"
        }
    }
}

/// イベントが持つ背景指定（最小構成）
public struct EventBackdrop: Equatable, Codable, Sendable {
    public let place: EventPlace
    public let time: EventTimeOfDay

    public init(_ place: EventPlace, _ time: EventTimeOfDay = .day) {
        self.place = place
        self.time = time
    }
}

public struct EventTimeTintModifier: ViewModifier {
    let time: EventTimeOfDay

    public func body(content: Content) -> some View {
        content
            .saturation(saturationAmount)
            .brightness(brightnessAmount)
            .overlay {
                ZStack {
                    // 1. 全体の色温度フィルター
                    tintOverlay
                        .blendMode(blendMode)

                    // 2. 時間帯ごとの光の演出（斜光・夜間の周辺減光）
                    lightingAccent
                }
                .allowsHitTesting(false)
            }
    }

    private var saturationAmount: Double {
        switch time {
        case .morning: return 0.95
        case .day:     return 1.00
        case .evening: return 1.12
        case .night:   return 0.78
        }
    }

    private var brightnessAmount: Double {
        switch time {
        case .morning: return 0.03
        case .day:     return 0.00
        case .evening: return -0.04
        case .night:   return -0.18
        }
    }

    private var blendMode: BlendMode {
        switch time {
        case .morning: return .screen
        case .day:     return .normal
        case .evening: return .multiply
        case .night:   return .multiply
        }
    }

    @ViewBuilder
    private var tintOverlay: some View {
        switch time {
        case .morning:
            LinearGradient(
                colors: [Color(hex: 0xCBE8F6).opacity(0.28), Color(hex: 0xFFF6D6).opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .day:
            Color.clear
        case .evening:
            LinearGradient(
                colors: [Color(hex: 0xD96B27).opacity(0.32), Color(hex: 0xF2B880).opacity(0.22)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .night:
            LinearGradient(
                colors: [Color(hex: 0x161E33).opacity(0.56), Color(hex: 0x2B221E).opacity(0.42)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    @ViewBuilder
    private var lightingAccent: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            switch time {
            case .morning:
                // 左上から差し込む爽やかな朝日の斜光
                Path { p in
                    p.move(to: CGPoint(x: w * 0.08, y: 0))
                    p.addLine(to: CGPoint(x: w * 0.36, y: 0))
                    p.addLine(to: CGPoint(x: w * 0.58, y: h))
                    p.addLine(to: CGPoint(x: w * 0.22, y: h))
                    p.closeSubpath()
                }
                .fill(Color.white.opacity(0.18))

            case .day:
                EmptyView()

            case .evening:
                // 右上から斜めに落ちる茜色の西日ハイライト
                Path { p in
                    p.move(to: CGPoint(x: w * 0.55, y: 0))
                    p.addLine(to: CGPoint(x: w * 0.88, y: 0))
                    p.addLine(to: CGPoint(x: w * 0.42, y: h))
                    p.addLine(to: CGPoint(x: w * 0.12, y: h))
                    p.closeSubpath()
                }
                .fill(Color(hex: 0xFFB042).opacity(0.22))

            case .night:
                // 中央に白熱電球の 暖かい 琥珀光を残し、上下端を黒漆で締める
                ZStack {
                    RadialGradient(
                        colors: [YoseColor.kinBright.opacity(0.24), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: w * 0.48
                    )
                    .blendMode(.screen)

                    VStack {
                        LinearGradient(colors: [YoseColor.kuroUrushi.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: 36)
                        Spacer()
                    }
                }
            }
        }
    }
}

public extension View {
    func eventTimeTint(_ time: EventTimeOfDay) -> some View {
        modifier(EventTimeTintModifier(time: time))
    }
}

/// 場所×時間帯を統合して描画するステージ背景ビュー（高さ220pt推奨）
public struct EventStageBackdropView: View {
    public let backdrop: EventBackdrop

    public init(backdrop: EventBackdrop) {
        self.backdrop = backdrop
    }

    public var body: some View {
        Group {
            switch backdrop.place {
            case .keikoba:   KeikobaBackdrop()
            case .station:   StationBackdrop()
            case .apartment: ApartmentBackdrop()
            case .gakuya:    GakuyaBackdrop()
            case .train:     TrainBackdrop()
            case .park:      ParkBackdrop()
            case .famires:   FamiresBackdrop()
            case .sento:     SentoBackdrop()
            case .theater:   TheaterBackdrop()
            case .kissaten:  KissatenBackdrop()
            case .office:    OfficeBackdrop()
            }
        }
        .eventTimeTint(backdrop.time)
        .clipped()
    }
}

// MARK: - 1. 稽古場（ホワイトボード・長机・パイプ椅子・壁時計）
private struct KeikobaBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, floorY = h * 0.68
            ZStack {
                // 砂壁とリノリウム床
                YoseColor.kinari
                Rectangle().fill(YoseColor.kiDark)
                    .frame(height: h - floorY).position(x: w / 2, y: floorY + (h - floorY) / 2)
                Rectangle().fill(YoseColor.sumi).frame(height: 2).position(x: w / 2, y: floorY)
                // 上部の長押（なげし）
                Rectangle().fill(Color(hex: 0x8C6B48)).frame(height: 8)
                    .overlay(alignment: .bottom) { Rectangle().fill(YoseColor.sumi).frame(height: 2) }
                    .position(x: w / 2, y: 18)

                // 左：高窓
                ZStack {
                    Rectangle().fill(Color(hex: 0xD8E8F0))
                    Rectangle().fill(YoseColor.sumi).frame(width: 2)
                    Rectangle().fill(YoseColor.sumi).frame(height: 2)
                }
                .frame(width: 64, height: 54).overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                .position(x: 54, y: 68)

                // 中央：稽古用ホワイトボード（ネタ構成の書き殴り線＋赤丸）
                ZStack(alignment: .bottom) {
                    Rectangle().fill(YoseColor.washi)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Rectangle().fill(YoseColor.sumi.opacity(0.6)).frame(width: 48, height: 2.5)
                            Circle().stroke(YoseColor.shu, lineWidth: 2).frame(width: 14, height: 14)
                        }
                        Rectangle().fill(YoseColor.sumi.opacity(0.45)).frame(width: 86, height: 2)
                        Rectangle().fill(YoseColor.shu.opacity(0.7)).frame(width: 62, height: 2)
                    }
                    .padding(.bottom, 18)
                    // 粉受けトレイ
                    Rectangle().fill(YoseColor.ginNezu).frame(height: 6)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                }
                .frame(width: 156, height: 82)
                .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))
                .position(x: w * 0.52, y: 84)

                // 右：壁掛け時計と「発声練習」貼り紙
                Circle().fill(YoseColor.washi).frame(width: 26, height: 26)
                    .overlay(Circle().stroke(YoseColor.sumi, lineWidth: 2))
                    .overlay(Image(systemName: "clock").font(.system(size: 16, weight: .bold)).foregroundStyle(YoseColor.sumi))
                    .position(x: w - 44, y: 52)
                Rectangle().fill(YoseColor.washi).frame(width: 24, height: 42)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                    .overlay(Rectangle().fill(YoseColor.enji).frame(width: 4, height: 28))
                    .position(x: w - 44, y: 98)

                // 手前：パイプ椅子2脚と長机（ネタ帳）
                ForEach([w * 0.30, w * 0.70], id: \.self) { cx in
                    ZStack {
                        RoundedRectangle(cornerRadius: 2).stroke(YoseColor.sumi, lineWidth: 2).frame(width: 34, height: 42)
                        Rectangle().fill(Color(hex: 0x4A5560)).frame(width: 36, height: 14).offset(y: -8)
                            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(y: -8))
                        Rectangle().fill(Color(hex: 0x4A5560)).frame(width: 38, height: 8).offset(y: 10)
                            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(y: 10))
                    }
                    .position(x: cx, y: floorY + 8)
                }
                ZStack {
                    Rectangle().fill(YoseColor.ki).frame(width: 180, height: 12)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    Rectangle().fill(YoseColor.washi).frame(width: 32, height: 10).offset(x: -24, y: -9)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(x: -24, y: -9))
                }
                .position(x: w * 0.5, y: floorY + 26)
            }
        }
    }
}

// MARK: - 2. 駅（ホーム・駅名標・柱・黄色い点字ブロック）
private struct StationBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, floorY = h * 0.68
            ZStack {
                // 空と線路向こうの遠景ビル
                LinearGradient(colors: [Color(hex: 0xC6D6E3), Color(hex: 0xE6E2D8)], startPoint: .top, endPoint: .bottom)
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach([38, 56, 44, 62, 34, 50], id: \.self) { bh in
                        Rectangle().fill(Color(hex: 0x8A949E).opacity(0.45)).frame(width: 48, height: CGFloat(bh))
                    }
                }
                .position(x: w / 2, y: floorY - 24)

                // ホーム屋根と鉄骨柱
                ForEach([w * 0.16, w * 0.84], id: \.self) { px in
                    Rectangle().fill(Color(hex: 0x5A6065)).frame(width: 16, height: floorY)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                        .position(x: px, y: floorY / 2)
                }
                Rectangle().fill(Color(hex: 0x42474C)).frame(height: 18)
                    .overlay(alignment: .bottom) { Rectangle().fill(YoseColor.sumi).frame(height: 2) }
                    .position(x: w / 2, y: 9)

                // 中央：吊り下げ駅名標（「なんば」・AIっぽい「えき」を廃止）
                ZStack(alignment: .bottom) {
                    Rectangle().fill(YoseColor.washi)
                    Rectangle().fill(YoseColor.shu).frame(height: 10)
                    VStack(spacing: 1) {
                        Text("なんば")
                            .font(YoseFont.gothic(16, weight: .black))
                            .foregroundStyle(YoseColor.sumi)
                        Text("◀ 大国町　　心斎橋 ▶")
                            .font(YoseFont.gothic(9, weight: .bold))
                            .foregroundStyle(YoseColor.haiSumi)
                    }
                    .padding(.bottom, 12)
                }
                .frame(width: 152, height: 50)
                .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))
                .position(x: w / 2, y: 56)

                // ホームのベンチ（2席）
                HStack(spacing: 6) {
                    ForEach(0..<2, id: \.self) { _ in
                        Rectangle().fill(YoseColor.ki).frame(width: 36, height: 22)
                            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    }
                }
                .position(x: w * 0.5, y: floorY - 11)

                // アスファルト床と黄色い点字ブロック
                Rectangle().fill(Color(hex: 0x6E7073))
                    .frame(height: h - floorY).position(x: w / 2, y: floorY + (h - floorY) / 2)
                Rectangle().fill(YoseColor.sumi).frame(height: 2).position(x: w / 2, y: floorY)
                HStack(spacing: 4) {
                    ForEach(0..<18, id: \.self) { _ in
                        Rectangle().fill(YoseColor.kinBright).frame(width: 16, height: 7)
                            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1))
                    }
                }
                .position(x: w / 2, y: floorY + 14)
            }
        }
    }
}

// MARK: - 3. 部屋（安アパート・四畳半・ちゃぶ台・裸電球）
private struct ApartmentBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, floorY = h * 0.66
            ZStack {
                // 砂壁と畳の床（緑みのある古畳＋臙脂の畳縁）
                Color(hex: 0xE5DEC9)
                Rectangle().fill(Color(hex: 0xB5B886))
                    .frame(height: h - floorY).position(x: w / 2, y: floorY + (h - floorY) / 2)
                Rectangle().fill(YoseColor.enji).frame(height: 5)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                    .position(x: w / 2, y: floorY + 26)
                Rectangle().fill(YoseColor.sumi).frame(height: 2).position(x: w / 2, y: floorY)

                // 左：障子窓（格子）
                ZStack {
                    Rectangle().fill(YoseColor.washi)
                    HStack(spacing: 22) {
                        ForEach(0..<3, id: \.self) { _ in Rectangle().fill(YoseColor.kiDark).frame(width: 1.5) }
                    }
                    VStack(spacing: 18) {
                        ForEach(0..<3, id: \.self) { _ in Rectangle().fill(YoseColor.kiDark).frame(height: 1.5) }
                    }
                }
                .frame(width: 96, height: 86)
                .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                .position(x: 78, y: 78)

                // 右：押し入れ襖（ふすま）とカレンダー貼り紙
                ZStack {
                    Rectangle().fill(YoseColor.ki)
                    Rectangle().fill(YoseColor.sumi).frame(width: 1.5)
                    Circle().fill(YoseColor.sumi).frame(width: 6, height: 6).offset(x: -8, y: 6)
                    Circle().fill(YoseColor.sumi).frame(width: 6, height: 6).offset(x: 8, y: 6)
                }
                .frame(width: 110, height: floorY - 24)
                .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                .position(x: w - 82, y: (floorY - 24) / 2 + 24)

                // 天井から下がる裸電球（傘つき）
                VStack(spacing: 0) {
                    Rectangle().fill(YoseColor.sumi).frame(width: 2, height: 22)
                    Path { p in
                        p.move(to: CGPoint(x: 8, y: 0)); p.addLine(to: CGPoint(x: 28, y: 0))
                        p.addLine(to: CGPoint(x: 36, y: 10)); p.addLine(to: CGPoint(x: 0, y: 10)); p.closeSubpath()
                    }
                    .fill(YoseColor.washi).frame(width: 36, height: 10)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                    Circle().fill(YoseColor.kinBright).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(YoseColor.sumi, lineWidth: 1.5))
                }
                .position(x: w * 0.48, y: 24)

                // 手前：ちゃぶ台と湯呑み2つ・みかん
                ZStack {
                    Rectangle().fill(Color(hex: 0x7A3E26)).frame(width: 12, height: 22).offset(x: -46, y: 12)
                    Rectangle().fill(Color(hex: 0x7A3E26)).frame(width: 12, height: 22).offset(x: 46, y: 12)
                    Rectangle().fill(Color(hex: 0x964B2E)).frame(width: 140, height: 14)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    // 湯呑み2個
                    Rectangle().fill(YoseColor.washi).frame(width: 12, height: 14).offset(x: -28, y: -13)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(x: -28, y: -13))
                    Rectangle().fill(YoseColor.tokiwa).frame(width: 12, height: 14).offset(x: 26, y: -13)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(x: 26, y: -13))
                }
                .position(x: w * 0.48, y: floorY + 22)
            }
        }
    }
}

// MARK: - 4. 楽屋（ハリウッドミラー・香盤表めくり・楽屋暖簾）
private struct GakuyaBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, floorY = h * 0.68
            ZStack {
                YoseColor.kinari
                Rectangle().fill(Color(hex: 0xB8AA8E))
                    .frame(height: h - floorY).position(x: w / 2, y: floorY + (h - floorY) / 2)
                Rectangle().fill(YoseColor.sumi).frame(height: 2).position(x: w / 2, y: floorY)

                // 左〜中央：電球つき楽屋鏡（ハリウッドミラー）
                ZStack {
                    Rectangle().fill(Color(hex: 0xD6E6EC)).frame(width: 148, height: 78)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    // 鏡の反射斜線
                    Path { p in
                        p.move(to: CGPoint(x: 20, y: 70)); p.addLine(to: CGPoint(x: 55, y: 12))
                        p.move(to: CGPoint(x: 34, y: 70)); p.addLine(to: CGPoint(x: 69, y: 12))
                    }
                    .stroke(Color.white.opacity(0.65), lineWidth: 3)
                    .frame(width: 148, height: 78)
                    // 上部のハリウッド電球5個
                    HStack(spacing: 18) {
                        ForEach(0..<5, id: \.self) { _ in
                            Circle().fill(YoseColor.kinBright).frame(width: 11, height: 11)
                                .overlay(Circle().stroke(YoseColor.sumi, lineWidth: 1.5))
                        }
                    }
                    .offset(y: -44)
                }
                .position(x: w * 0.32, y: 92)

                // 右：木枠の香盤表（出番めくり5枚並び・右端が朱枠＝トップ出番）
                ZStack {
                    Rectangle().fill(YoseColor.ki)
                    HStack(spacing: 5) {
                        ForEach(0..<5, id: \.self) { idx in
                            Rectangle().fill(YoseColor.washi)
                                .frame(width: 14, height: 46)
                                .overlay(Rectangle().fill(idx == 4 ? YoseColor.shu : YoseColor.sumi).frame(width: 3, height: 28))
                                .overlay(Rectangle().stroke(idx == 4 ? YoseColor.shu : YoseColor.sumi, lineWidth: 1.5))
                        }
                    }
                }
                .frame(width: 104, height: 66)
                .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))
                .position(x: w * 0.78, y: 82)

                // 手前：化粧前カウンターと差し入れ箱
                ZStack {
                    Rectangle().fill(YoseColor.kiDark).frame(width: w * 0.86, height: 24)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    Rectangle().fill(YoseColor.washi).frame(width: 34, height: 16).offset(x: -60, y: -18)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(x: -60, y: -18))
                    Rectangle().fill(YoseColor.shu).frame(width: 14, height: 20).offset(x: 40, y: -20)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(x: 40, y: -20))
                }
                .position(x: w / 2, y: floorY + 14)
            }
        }
    }
}

// MARK: - 5. 電車の中（車窓2連・吊り革・臙脂のロングシート）
private struct TrainBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, seatY = h * 0.64
            ZStack {
                // 車内化粧板の壁
                Color(hex: 0xEAE4D3)

                // 車窓2連（外の空と架線柱シルエット）
                HStack(spacing: 20) {
                    ForEach(0..<2, id: \.self) { _ in
                        ZStack(alignment: .bottom) {
                            LinearGradient(colors: [Color(hex: 0xB8D4E3), Color(hex: 0xE2DEC9)], startPoint: .top, endPoint: .bottom)
                            Rectangle().fill(YoseColor.haiSumi.opacity(0.45)).frame(height: 18)
                        }
                        .frame(width: 132, height: 68)
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(YoseColor.sumi, lineWidth: 2))
                    }
                }
                .position(x: w / 2, y: 76)

                // 上部のパイプと吊り革5個（三角持ち手）
                Rectangle().fill(YoseColor.ginNezu).frame(height: 5)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                    .position(x: w / 2, y: 18)
                HStack(spacing: 54) {
                    ForEach(0..<5, id: \.self) { _ in
                        VStack(spacing: 0) {
                            Rectangle().fill(YoseColor.sumi).frame(width: 2, height: 18)
                            Path { p in
                                p.move(to: CGPoint(x: 9, y: 0)); p.addLine(to: CGPoint(x: 18, y: 14))
                                p.addLine(to: CGPoint(x: 0, y: 14)); p.closeSubpath()
                            }
                            .stroke(YoseColor.sumi, lineWidth: 2)
                            .background(YoseColor.washi)
                            .frame(width: 18, height: 14)
                        }
                    }
                }
                .position(x: w / 2, y: 34)

                // 阪急・上方私鉄風の臙脂モケット座席と木目肘掛け
                Rectangle().fill(YoseColor.enji).frame(height: 36)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    .position(x: w / 2, y: seatY)
                Rectangle().fill(YoseColor.shu).frame(height: 16)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    .position(x: w / 2, y: seatY + 22)
                Rectangle().fill(Color(hex: 0x8C7E6A)).frame(height: h - (seatY + 30))
                    .position(x: w / 2, y: seatY + 30 + (h - (seatY + 30)) / 2)
            }
        }
    }
}

// MARK: - 6. 公園（木立シルエット・レトロ街灯・木製ベンチ）
private struct ParkBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, groundY = h * 0.68
            ZStack {
                // 空と砂利の地面
                LinearGradient(colors: [Color(hex: 0xC9E2EC), YoseColor.kinari], startPoint: .top, endPoint: .bottom)
                Rectangle().fill(Color(hex: 0xD8CCB4))
                    .frame(height: h - groundY).position(x: w / 2, y: groundY + (h - groundY) / 2)

                // 奥の生垣・木立（常磐緑）
                HStack(spacing: -14) {
                    ForEach(0..<8, id: \.self) { idx in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(idx.isMultiple(of: 2) ? YoseColor.tokiwa : Color(hex: 0x23452E))
                            .frame(width: 64, height: idx.isMultiple(of: 2) ? 54 : 42)
                            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                    }
                }
                .position(x: w / 2, y: groundY - 18)
                Rectangle().fill(YoseColor.sumi).frame(height: 2).position(x: w / 2, y: groundY)

                // 左：公園のレトロ街灯（電球が光る）
                ZStack {
                    Rectangle().fill(YoseColor.kuroUrushi).frame(width: 6, height: 120)
                    Rectangle().fill(YoseColor.kuroUrushi).frame(width: 24, height: 6).offset(y: -60)
                    Rectangle().fill(YoseColor.kinBright).frame(width: 18, height: 22).offset(y: -72)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2).offset(y: -72))
                }
                .position(x: w * 0.22, y: groundY - 46)

                // 中央〜右：公園の木製ベンチ（漫才の青空ネタ合わせ場所）
                ZStack {
                    Rectangle().fill(YoseColor.sumi).frame(width: 8, height: 38).offset(x: -54, y: 6)
                    Rectangle().fill(YoseColor.sumi).frame(width: 8, height: 38).offset(x: 54, y: 6)
                    VStack(spacing: 4) {
                        Rectangle().fill(YoseColor.ki).frame(width: 140, height: 10)
                            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                        Rectangle().fill(YoseColor.ki).frame(width: 140, height: 10)
                            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                        Rectangle().fill(YoseColor.kiDark).frame(width: 148, height: 10)
                            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    }
                }
                .position(x: w * 0.58, y: groundY + 6)
            }
        }
    }
}

// MARK: - 7. ファミレス（大窓・吊りランプ・赤ソファ・ネタ帳とカップ）
private struct FamiresBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, tableY = h * 0.72
            ZStack {
                Color(hex: 0xEFE6D4)
                // 奥の大きな窓枠
                ZStack {
                    LinearGradient(colors: [Color(hex: 0x35465E), Color(hex: 0x627388)], startPoint: .top, endPoint: .bottom)
                    Rectangle().fill(YoseColor.sumi).frame(width: 2)
                }
                .frame(width: 240, height: 78)
                .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                .position(x: w / 2, y: 68)

                // 天井から下がるファミレスの台形ペンダントランプ
                VStack(spacing: 0) {
                    Rectangle().fill(YoseColor.sumi).frame(width: 2, height: 20)
                    Path { p in
                        p.move(to: CGPoint(x: 16, y: 0)); p.addLine(to: CGPoint(x: 48, y: 0))
                        p.addLine(to: CGPoint(x: 64, y: 20)); p.addLine(to: CGPoint(x: 0, y: 20)); p.closeSubpath()
                    }
                    .fill(YoseColor.kinBright)
                    .overlay(
                        Path { p in
                            p.move(to: CGPoint(x: 16, y: 0)); p.addLine(to: CGPoint(x: 48, y: 0))
                            p.addLine(to: CGPoint(x: 64, y: 20)); p.addLine(to: CGPoint(x: 0, y: 20)); p.closeSubpath()
                        }.stroke(YoseColor.sumi, lineWidth: 2)
                    )
                    .frame(width: 64, height: 20)
                }
                .position(x: w / 2, y: 20)

                // 左右の赤いボックス席ソファ（背もたれ）
                ForEach([w * 0.18, w * 0.82], id: \.self) { sx in
                    Rectangle().fill(YoseColor.shu).frame(width: 82, height: 58)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                        .position(x: sx, y: tableY - 12)
                }

                // 手前：木目テーブル天板＋開いたネタ帳＋コーヒーカップ2つ
                ZStack {
                    Rectangle().fill(Color(hex: 0x8C583A)).frame(width: 260, height: 26)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    // 開いたネタ帳
                    Rectangle().fill(YoseColor.washi).frame(width: 44, height: 14).offset(x: -20, y: -18)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(x: -20, y: -18))
                    // ドリンクバーのカップ2個
                    Rectangle().fill(YoseColor.washi).frame(width: 14, height: 16).offset(x: 42, y: -19)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(x: 42, y: -19))
                    Rectangle().fill(YoseColor.washi).frame(width: 14, height: 16).offset(x: 64, y: -19)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(x: 64, y: -19))
                }
                .position(x: w / 2, y: tableY + 12)
            }
        }
    }
}

// MARK: - 8. 銭湯（富士山のペンキ絵・白タイル壁・黄色いケロリン桶）
private struct SentoBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, tileY = h * 0.56, floorY = h * 0.76
            ZStack {
                // 上部：銭湯の富士山ペンキ絵
                Color(hex: 0xCBE4EE)
                Path { p in
                    p.move(to: CGPoint(x: w * 0.15, y: tileY))
                    p.addLine(to: CGPoint(x: w * 0.44, y: 24))
                    p.addLine(to: CGPoint(x: w * 0.56, y: 24))
                    p.addLine(to: CGPoint(x: w * 0.85, y: tileY))
                    p.closeSubpath()
                }
                .fill(Color(hex: 0x3B668C))
                .overlay(
                    Path { p in
                        p.move(to: CGPoint(x: w * 0.40, y: 48))
                        p.addLine(to: CGPoint(x: w * 0.44, y: 24))
                        p.addLine(to: CGPoint(x: w * 0.56, y: 24))
                        p.addLine(to: CGPoint(x: w * 0.60, y: 48))
                        p.closeSubpath()
                    }.fill(YoseColor.washi)
                )

                // 中段：タイル壁とカラン（鏡3枚）
                Rectangle().fill(YoseColor.washi).frame(height: floorY - tileY)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    .position(x: w / 2, y: tileY + (floorY - tileY) / 2)
                HStack(spacing: 46) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle().fill(Color(hex: 0xD2E6EC)).frame(width: 24, height: 30)
                            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                    }
                }
                .position(x: w / 2, y: tileY + 20)

                // 下段：湯船の縁と黄色い桶（ケロリン風）2個
                Rectangle().fill(Color(hex: 0x90A8A4)).frame(height: h - floorY)
                    .position(x: w / 2, y: floorY + (h - floorY) / 2)
                Rectangle().fill(YoseColor.sumi).frame(height: 2).position(x: w / 2, y: floorY)
                HStack(spacing: 32) {
                    ForEach(0..<2, id: \.self) { _ in
                        Rectangle().fill(YoseColor.kinBright).frame(width: 32, height: 14)
                            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    }
                }
                .position(x: w / 2, y: floorY + 14)
            }
        }
    }
}

// MARK: - 9. 劇場（定式幕・寄席提灯・赤いモケット客席）
private struct TheaterBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, stageY = h * 0.64
            ZStack {
                YoseColor.kuroUrushi
                // 定式幕（黒・柿・萌黄の縦縞）
                HStack(spacing: 0) {
                    ForEach(0..<12, id: \.self) { i in
                        let c: Color = (i % 3 == 0) ? YoseColor.kuroUrushi : (i % 3 == 1 ? YoseColor.shu : YoseColor.tokiwa)
                        Rectangle().fill(c)
                    }
                }
                .frame(height: stageY)
                .position(x: w / 2, y: stageY / 2)

                // 上部の臙脂水引幕と寄席提灯2つ
                Rectangle().fill(YoseColor.enji).frame(height: 26)
                    .overlay(alignment: .bottom) { Rectangle().fill(YoseColor.kin).frame(height: 2) }
                    .position(x: w / 2, y: 13)
                ForEach([w * 0.24, w * 0.76], id: \.self) { lx in
                    ZStack {
                        Rectangle().fill(YoseColor.shu).frame(width: 28, height: 42)
                            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                        Rectangle().fill(YoseColor.kuroUrushi).frame(width: 30, height: 5).offset(y: -21)
                        Rectangle().fill(YoseColor.kuroUrushi).frame(width: 30, height: 5).offset(y: 21)
                    }
                    .position(x: lx, y: 48)
                }

                // 檜舞台の床と手前の赤い客席背もたれ4連
                Rectangle().fill(YoseColor.ki).frame(height: h - stageY)
                    .overlay(alignment: .top) { Rectangle().fill(YoseColor.sumi).frame(height: 2) }
                    .position(x: w / 2, y: stageY + (h - stageY) / 2)
                HStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2).fill(YoseColor.enji)
                            .frame(width: 68, height: 34)
                            .overlay(RoundedRectangle(cornerRadius: 2).stroke(YoseColor.sumi, lineWidth: 2))
                    }
                }
                .position(x: w / 2, y: h - 14)
            }
        }
    }
}

// MARK: - 10. 喫茶店（琥珀レンガ壁・ステンドグラス照明・純喫茶テーブル）
private struct KissatenBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, floorY = h * 0.68
            ZStack {
                // 琥珀色の腰壁と漆喰壁
                Color(hex: 0xE6DBC4)
                Rectangle().fill(Color(hex: 0x5E3826)).frame(height: h - floorY + 24)
                    .overlay(alignment: .top) { Rectangle().fill(YoseColor.sumi).frame(height: 2) }
                    .position(x: w / 2, y: floorY - 12 + (h - floorY + 24) / 2)

                // 奥のアーチ窓2枚
                HStack(spacing: 48) {
                    ForEach(0..<2, id: \.self) { _ in
                        ZStack {
                            Rectangle().fill(Color(hex: 0xF5D799))
                            Rectangle().fill(YoseColor.sumi).frame(width: 2)
                            Rectangle().fill(YoseColor.sumi).frame(height: 2)
                        }
                        .frame(width: 72, height: 68)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    }
                }
                .position(x: w / 2, y: 74)

                // ステンドグラス風ペンダント照明（朱・常磐・山吹）
                VStack(spacing: 0) {
                    Rectangle().fill(YoseColor.sumi).frame(width: 2, height: 22)
                    HStack(spacing: 0) {
                        Rectangle().fill(YoseColor.shu)
                        Rectangle().fill(YoseColor.kinBright)
                        Rectangle().fill(YoseColor.tokiwa)
                    }
                    .frame(width: 48, height: 22)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                }
                .position(x: w / 2, y: 24)

                // 手前：純喫茶の丸テーブル断面と珈琲カップ・クリームソーダ
                ZStack {
                    Rectangle().fill(Color(hex: 0x3D2214)).frame(width: 220, height: 20)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    Rectangle().fill(YoseColor.washi).frame(width: 16, height: 14).offset(x: -36, y: -17)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(x: -36, y: -17))
                    Rectangle().fill(YoseColor.tokiwa).frame(width: 14, height: 24).offset(x: 36, y: -22)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(x: 36, y: -22))
                }
                .position(x: w / 2, y: floorY + 26)
            }
        }
    }
}

// MARK: - 11. 事務所（ブラインド窓・所属芸人番付ボード・事務机）
private struct OfficeBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, floorY = h * 0.68
            ZStack {
                YoseColor.kinari
                Rectangle().fill(YoseColor.kiDark).frame(height: h - floorY)
                    .overlay(alignment: .top) { Rectangle().fill(YoseColor.sumi).frame(height: 2) }
                    .position(x: w / 2, y: floorY + (h - floorY) / 2)

                // 左：ブラインド窓（下端までストライプを完全に引き切る＋墨2pt枠）
                VStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { i in
                        Rectangle().fill(i.isMultiple(of: 2) ? Color(hex: 0xD2E3EC) : YoseColor.washi)
                    }
                }
                .frame(width: 124, height: 78)
                .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                .position(x: w * 0.26, y: 74)

                // 右：所属芸人の稼働番付ボード（木札と朱札のグリッド）
                ZStack {
                    Rectangle().fill(YoseColor.washi)
                    VStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { r in
                            HStack(spacing: 6) {
                                ForEach(0..<4, id: \.self) { c in
                                    let fill: Color = (r == 0 && c == 0) ? YoseColor.shu : ((r + c).isMultiple(of: 2) ? YoseColor.ki : YoseColor.enji)
                                    Rectangle().fill(fill).frame(width: 20, height: 14)
                                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1))
                                }
                            }
                        }
                    }
                }
                .frame(width: 124, height: 78)
                .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))
                .position(x: w * 0.74, y: 74)

                // 手前：マネージャーの事務机（幅260pt・黒電話・契約書バインダー）
                ZStack {
                    Rectangle().fill(Color(hex: 0x9C7A54)).frame(width: 260, height: 32)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    Rectangle().fill(YoseColor.kuroUrushi).frame(width: 36, height: 14).offset(x: -54, y: -22)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(x: -54, y: -22))
                    Rectangle().fill(YoseColor.washi).frame(width: 44, height: 10).offset(x: 36, y: -20)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(x: 36, y: -20))
                }
                .position(x: w / 2, y: floorY + 18)
            }
        }
    }
}
