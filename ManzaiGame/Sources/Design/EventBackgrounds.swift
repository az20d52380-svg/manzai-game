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
    case yakiniku    // 12. 焼肉屋（暖簾・排煙ダクト・七輪ロースター）
    case uketsuke    // 13. 稽古場の受付（ハイカウンター・飴皿）

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
        case .yakiniku:  return "焼肉屋"
        case .uketsuke:  return "稽古場受付"
        }
    }
}

extension EventPlace {
    /// 夜の暗転の強さ（屋内で灯りが点いている場所は暗くしすぎない・夜でも背景は明度12%以上）
    var nightStrength: Double {
        switch self {
        case .sento: return 0.0       // 営業中の銭湯は明るいまま（湯気と暖色灯）
        case .kissaten: return 0.7
        case .train: return 0.55      // 車内は蛍光灯
        case .park: return 0.62
        case .theater: return 0.6
        case .famires: return 0.65
        case .gakuya: return 0.8
        default: return 1
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

/// 背景の各パーツが「いま何時か」を知るための環境値（夜は窓を濃紺にする等）
private struct EventTimeKey: EnvironmentKey { static let defaultValue: EventTimeOfDay = .day }
extension EnvironmentValues {
    var eventTime: EventTimeOfDay {
        get { self[EventTimeKey.self] }
        set { self[EventTimeKey.self] = newValue }
    }
}

public struct EventTimeTintModifier: ViewModifier {
    let time: EventTimeOfDay
    /// 夜の暗転の強さ（営業中の銭湯など、屋内で明るいままの場所は弱める）
    var strength: Double = 1

    public func body(content: Content) -> some View {
        content
            .saturation(1 + (saturationAmount - 1) * strength)
            .brightness(brightnessAmount * strength)
            .overlay {
                ZStack {
                    // 1. 全体の色温度フィルター
                    tintOverlay
                        .opacity(strength)
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
                // 上から差す夕暮れのグラデーション（斜めの帯は使わない）
                LinearGradient(colors: [Color(hex: 0xD47A2A).opacity(0.22), .clear], startPoint: .top, endPoint: .bottom)

            case .night:
                // 中央に白熱電球の 暖かい 琥珀光を残し、上下端を黒漆で締める
                // （中央の一律の灯りは廃止＝光源のある所だけ EventGlowLayer が光らせる）
                ZStack {
                    VStack {
                        LinearGradient(colors: [YoseColor.kuroUrushi.opacity(0.28 * strength), .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: 20)
                        Spacer()
                    }
                }
            }
        }
    }
}

public extension View {
    func eventTimeTint(_ time: EventTimeOfDay, strength: Double = 1) -> some View {
        modifier(EventTimeTintModifier(time: time, strength: strength))
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
            case .yakiniku:  YakinikuBackdrop()
            case .uketsuke:  UketsukeBackdrop()
            }
        }
        .environment(\.eventTime, backdrop.time)
        .eventTimeTint(backdrop.time, strength: backdrop.place.nightStrength)
        .overlay { EventGlowLayer(place: backdrop.place, time: backdrop.time) }   // 夜の暗転の「上」に光源を置く
        .clipped()
    }
}

// MARK: - 共通の図形と空の色（非矩形は必ず同じ Shape で fill と stroke を掛ける）
private struct TrapezoidShape: Shape {
    var topInset: CGFloat
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + topInset, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX - topInset, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.closeSubpath()
        return p
    }
}
private struct TriangleShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.closeSubpath()
        return p
    }
}
/// 窓の外の空（昼＝水色・夜＝濃紺）
private func eventSky(_ time: EventTimeOfDay) -> LinearGradient {
    switch time {
    case .night: return LinearGradient(colors: [Color(hex: 0x141C30), Color(hex: 0x26334D)], startPoint: .top, endPoint: .bottom)
    case .evening: return LinearGradient(colors: [Color(hex: 0xF0C79A), Color(hex: 0xF7E3C4)], startPoint: .top, endPoint: .bottom)
    default: return LinearGradient(colors: [Color(hex: 0xC6E2EE), Color(hex: 0xE8F2F6)], startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - 夜の光源（暗転フィルターの「上」に重ねる。光源のある所だけが光る）
private struct EventGlowLayer: View {
    let place: EventPlace
    let time: EventTimeOfDay
    private var night: Bool { time == .night }
    private var k: Double { night ? 1 : (time == .evening ? 0.4 : 0) }

    private func halo(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ c: Color, _ a: Double) -> some View {
        RadialGradient(colors: [c.opacity(a * k), .clear], center: .center, startRadius: 2, endRadius: r)
            .frame(width: r * 2, height: r * 2).position(x: x, y: y).blendMode(.screen)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            if k > 0 {
                ZStack { lights(w, h) }
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder private func lights(_ w: CGFloat, _ h: CGFloat) -> some View {
        switch place {
        case .apartment:
            halo(w * 0.48, 60, 190, YoseColor.kinBright, 0.55)
            if night {
                Circle().fill(Color(hex: 0xFFE9A8)).frame(width: 12, height: 12)
                    .overlay(Circle().stroke(YoseColor.sumi, lineWidth: 1.5)).position(x: w * 0.48, y: 40)
            }
        case .kissaten:
            halo(w / 2, 48, 120, Color(hex: 0xFFB042), 0.5)
            halo(w / 2, 150, 90, Color(hex: 0xFFB042), 0.22)
            if night {
                // 夜はステンドグラスの傘そのものを減光の上に描き直して灯す
                ZStack {
                    HStack(spacing: 0) {
                        Rectangle().fill(YoseColor.enji); Rectangle().fill(YoseColor.kinBright); Rectangle().fill(Color(hex: 0xD96B27))
                    }
                    .clipShape(TrapezoidShape(topInset: 18))
                    TrapezoidShape(topInset: 18).stroke(YoseColor.sumi, lineWidth: 2)
                }
                .frame(width: 56, height: 22).brightness(0.12).position(x: w / 2, y: 36)
            }
        case .famires:
            halo(w / 2, 40, 110, YoseColor.kinBright, 0.45)
            Path { p in
                p.move(to: CGPoint(x: w / 2 - 24, y: 42)); p.addLine(to: CGPoint(x: w / 2 + 24, y: 42))
                p.addLine(to: CGPoint(x: w / 2 + 100, y: h * 0.72 + 4)); p.addLine(to: CGPoint(x: w / 2 - 100, y: h * 0.72 + 4)); p.closeSubpath()
            }
            .fill(LinearGradient(colors: [YoseColor.kinBright.opacity(0.3 * k), YoseColor.kinBright.opacity(0)], startPoint: .top, endPoint: .bottom))
            .blendMode(.screen)
            if night { nightWindow(w / 2, 86, 240, 56, mullions: 2, dots: 6) }
        case .gakuya:
            ForEach(0..<5, id: \.self) { i in
                halo(w * 0.32 + CGFloat(i - 2) * 29, 58, 34, YoseColor.kinBright, 0.7)
            }
            if night {
                ForEach(0..<5, id: \.self) { i in
                    Circle().fill(Color(hex: 0xFFE9A8)).frame(width: 11, height: 11)
                        .overlay(Circle().fill(YoseColor.washi).frame(width: 4, height: 4))
                        .overlay(Circle().stroke(YoseColor.sumi, lineWidth: 1.5))
                        .position(x: w * 0.32 + CGFloat(i - 2) * 29, y: 58)
                }
            }
        case .park:
            halo(w * 0.22, 32, 96, YoseColor.kinBright, 0.55)
            if night {
                Rectangle().fill(Color(hex: 0xFFE9A8)).frame(width: 18, height: 22)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2)).position(x: w * 0.22, y: 32)
            }
        case .theater:
            ForEach([w * 0.24, w * 0.76], id: \.self) { lx in
                halo(lx, 58, 74, Color(hex: 0xFF9A4A), 0.5)
                if night { TheaterLantern(lit: true).position(x: lx, y: 58) }
            }
            // 舞台の足元の灯り（客席と幕を切り分ける）
            LinearGradient(colors: [.clear, Color(hex: 0xFFC870).opacity(0.34 * k)], startPoint: .top, endPoint: .bottom)
                .frame(height: 46).position(x: w / 2, y: h * 0.64 - 23).blendMode(.screen)
        case .station:
            halo(w / 2, 56, 110, .white, 0.22)
            if night {
                // 遠景ビルの窓明かり（柱に隠れる所は置かない）
                let hs: [CGFloat] = [38, 56, 44, 62, 34, 50]
                ForEach(0..<6, id: \.self) { i in
                    let x0 = w / 2 - 159 + CGFloat(i) * 54, base = h * 0.68 - 24 + 31
                    ForEach(0..<3, id: \.self) { k in
                        let dx = x0 + 10 + CGFloat(k) * 14
                        if abs(dx - w * 0.16) > 14 && abs(dx - w * 0.84) > 14 {
                            Rectangle().fill(YoseColor.kinBright.opacity(0.6)).frame(width: 3, height: 3)
                                .position(x: dx, y: base - hs[i] + 8 + CGFloat((i + k) % 3) * 9)
                        }
                    }
                }
                StationSign().position(x: w / 2, y: 56)
            }
        case .train:
            // 蛍光灯の光は固定幅の箱にせず放射状に減衰（左右に縦の切れ目を出さない）。窓はその上に描く
            RadialGradient(colors: [Color.white.opacity(0.26 * k), .clear], center: UnitPoint(x: 0.5, y: 0.08), startRadius: 6, endRadius: 230)
                .frame(width: w, height: h).position(x: w / 2, y: h / 2).blendMode(.screen)
            if night {
                ForEach([-76.0, 76.0], id: \.self) { dx in
                    nightWindow(w / 2 + CGFloat(dx), 88, 132, 68, mullions: 0, dots: 6)
                }
                Rectangle().fill(Color(hex: 0xFFFBEA)).frame(width: w * 0.62, height: 6)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5)).position(x: w / 2, y: 8)
            }
        case .sento:
            halo(w / 2, 20, 260, Color(hex: 0xFFC870), 0.28)
        case .yakiniku:
            halo(w / 2, h * 0.72 - 14, 84, Color(hex: 0xFF6B2B), 0.5)
            halo(w / 2, 50, 120, YoseColor.kinBright, 0.28)
        case .keikoba, .uketsuke:
            halo(w / 2, 6, 200, Color(hex: 0xFFF1C8), 0.30)
            if place == .keikoba {
                // 夜の稽古場：蛍光灯がホワイトボードと長机を照らす
                halo(w * 0.52, 84, 120, Color(hex: 0xFFF6DA), 0.40)
                halo(w * 0.5, h * 0.68 + 20, 100, Color(hex: 0xFFE9B0), 0.22)
                Rectangle().fill(Color(hex: 0xFFFBEA)).frame(width: 110, height: 5)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5)).position(x: w * 0.52, y: 28)
            }
            if place == .uketsuke {
                // 夜の受付：看板とカウンター手元を暖色のスポットで照らす
                halo(w * 0.55, 100, 140, YoseColor.kinBright, 0.34)
                halo(w * 0.45, h - 70, 110, YoseColor.kinBright, 0.22)
            }
        case .office:
            halo(w / 2, h * 0.25, 170, Color(hex: 0xFFF1C8), 0.34)
            halo(w / 2, h * 0.68 - 6, 100, YoseColor.kinBright, 0.26)
        }
    }

    /// 夜の窓（濃紺の空＋街の灯り）。暗転の上に描き直して「窓の外だけ別世界」にする
    private func nightWindow(_ cx: CGFloat, _ cy: CGFloat, _ ww: CGFloat, _ hh: CGFloat, mullions: Int, dots: Int) -> some View {
        ZStack {
            eventSky(.night)
            Rectangle().fill(Color(hex: 0x0C1220)).frame(height: 16).frame(maxHeight: .infinity, alignment: .bottom)
            if mullions > 0 {
                HStack(spacing: 0) { Spacer(); Rectangle().fill(YoseColor.sumi).frame(width: 2); Spacer(); Rectangle().fill(YoseColor.sumi).frame(width: 2); Spacer() }
            }
            ForEach(0..<dots, id: \.self) { i in
                Rectangle().fill(YoseColor.kinBright.opacity(0.8)).frame(width: 4, height: 4)
                    .position(x: ww * (0.10 + 0.16 * CGFloat(i)) + CGFloat((i * 7) % 5), y: hh * (i.isMultiple(of: 2) ? 0.72 : 0.50))
            }
        }
        .frame(width: ww, height: hh)
        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
        .position(x: cx, y: cy)
    }
}

/// 駅名標（夜は暗転の上に描き直して、看板だけ蛍光灯で光る）
private struct StationSign: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(YoseColor.washi)
            Rectangle().fill(YoseColor.shu).frame(height: 10)
            VStack(spacing: 1) {
                Text("なんば").font(YoseFont.gothic(16, weight: .black)).foregroundStyle(YoseColor.sumi)
                Text("◀ 大国町　　心斎橋 ▶").font(YoseFont.gothic(9, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
            }
            .padding(.bottom, 12)
        }
        .frame(width: 152, height: 50)
        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
        .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))
    }
}

// MARK: - 1. 稽古場（ホワイトボード・長机・パイプ椅子・壁時計）
private struct KeikobaBackdrop: View {
    @Environment(\.eventTime) private var time
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

                // 天井の蛍光灯
                Rectangle().fill(YoseColor.washi).frame(width: 110, height: 5)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                    .position(x: w * 0.52, y: 28)

                // 左：高窓
                ZStack {
                    Rectangle().fill(time == .night ? Color(hex: 0x1E293B) : Color(hex: 0xD8E8F0))
                    Rectangle().fill(time == .night ? Color(hex: 0x3A3F47) : YoseColor.sumi).frame(width: 2)
                    Rectangle().fill(time == .night ? Color(hex: 0x3A3F47) : YoseColor.sumi).frame(height: 2)
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

                // 右：寄席のめくり札（木札に太い縦線）と定式幕の垂れ幕
                ZStack {
                    Rectangle().fill(YoseColor.ki)
                    Rectangle().fill(YoseColor.sumi).frame(width: 7, height: 26).offset(y: 3)
                    Rectangle().fill(YoseColor.shu).frame(width: 14, height: 4).offset(y: -15)
                }
                .frame(width: 28, height: 42)
                .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))
                .position(x: w - 44, y: 56)
                VStack(spacing: 0) {
                    Rectangle().fill(YoseColor.kin).frame(width: 40, height: 4)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                    HStack(spacing: 0) {
                        Rectangle().fill(YoseColor.kuroUrushi)
                        Rectangle().fill(YoseColor.shu)
                        Rectangle().fill(YoseColor.tokiwa)
                    }
                    .frame(width: 34, height: 34)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                }
                .position(x: w - 44, y: 106)

                // 手前：パイプ椅子2脚と長机（ネタ帳）
                ForEach([w * 0.30, w * 0.70], id: \.self) { cx in
                    ZStack {
                        RoundedRectangle(cornerRadius: 2).stroke(YoseColor.sumi, lineWidth: 2).frame(width: 34, height: 42)
                        Rectangle().fill(Color(hex: 0x4A5560)).frame(width: 36, height: 14).offset(y: -8)
                            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(y: -8))
                        Rectangle().fill(Color(hex: 0x4A5560)).frame(width: 38, height: 8).offset(y: 10)
                            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(y: 10))
                    }
                    .position(x: cx, y: floorY + 2)
                }
                ZStack {
                    Rectangle().fill(YoseColor.kiDark).frame(width: 6, height: 26).offset(x: -78, y: 16).overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).frame(width: 6, height: 26).offset(x: -78, y: 16))
                    Rectangle().fill(YoseColor.kiDark).frame(width: 6, height: 26).offset(x: 78, y: 16).overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).frame(width: 6, height: 26).offset(x: 78, y: 16))
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

                // 屋根から駅名標を吊る2本の棒
                ForEach([-50.0, 50.0], id: \.self) { dx in
                    Rectangle().fill(YoseColor.sumi).frame(width: 2, height: 14).position(x: w / 2 + CGFloat(dx), y: 25)
                }
                // 中央：吊り下げ駅名標（「なんば」）
                StationSign().position(x: w / 2, y: 56)

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
    @Environment(\.eventTime) private var time
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

                // 上部の長押（他の室内と揃える）
                Rectangle().fill(Color(hex: 0x8C6B48)).frame(height: 6)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                    .position(x: w / 2, y: 14)

                // 左：障子窓（桟は細く・夜は外の闇で青み）
                ZStack {
                    Rectangle().fill(time == .night ? Color(hex: 0x2C3545) : YoseColor.washi)
                    HStack(spacing: 22) {
                        ForEach(0..<3, id: \.self) { _ in Rectangle().fill(time == .night ? Color(hex: 0x1E2430) : YoseColor.kiDark).frame(width: 1.5) }
                    }
                    VStack(spacing: 18) {
                        ForEach(0..<3, id: \.self) { _ in Rectangle().fill(time == .night ? Color(hex: 0x1E2430) : YoseColor.kiDark).frame(height: 1.5) }
                    }
                }
                .frame(width: 96, height: 86)
                .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                .position(x: 78, y: 78)

                // 右：押し入れ襖（ふすま）とカレンダー貼り紙
                ZStack {
                    Rectangle().fill(YoseColor.ki)
                    Rectangle().fill(YoseColor.sumi).frame(width: 1.5)
                    Capsule().fill(YoseColor.sumi).frame(width: 5, height: 8).offset(x: -8, y: 28)
                    Capsule().fill(YoseColor.sumi).frame(width: 5, height: 8).offset(x: 8, y: 28)
                    // 襖の左の戸に貼ったカレンダー（日めくり）
                    VStack(spacing: 0) {
                        Rectangle().fill(YoseColor.shu).frame(height: 9)
                        Rectangle().fill(YoseColor.washi)
                            .overlay(VStack(spacing: 4) {
                                Rectangle().fill(YoseColor.sumi.opacity(0.55)).frame(width: 18, height: 1.5)
                                Rectangle().fill(YoseColor.sumi.opacity(0.55)).frame(width: 18, height: 1.5)
                                Rectangle().fill(YoseColor.sumi.opacity(0.55)).frame(width: 12, height: 1.5)
                            })
                    }
                    .frame(width: 28, height: 38)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                    .offset(x: -27, y: -28)
                }
                .frame(width: 110, height: floorY - 24)
                .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                .position(x: w - 82, y: (floorY - 24) / 2 + 24)

                // 天井から下がる裸電球（傘つき）。傘は同じ台形で fill と stroke
                VStack(spacing: 0) {
                    Rectangle().fill(YoseColor.sumi).frame(width: 2, height: 22)
                    ZStack {
                        TrapezoidShape(topInset: 8).fill(YoseColor.washi)
                        TrapezoidShape(topInset: 8).stroke(YoseColor.sumi, lineWidth: 1.5)
                    }
                    .frame(width: 36, height: 10)
                    Circle().fill(YoseColor.kinBright).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(YoseColor.sumi, lineWidth: 1.5))
                }
                .position(x: w * 0.48, y: 24)

                // 手前：ちゃぶ台（脚にも墨枠）と湯呑み2つ・みかん
                ZStack {
                    Rectangle().fill(Color(hex: 0x7A3E26)).frame(width: 12, height: 22).offset(x: -46, y: 12)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(x: -46, y: 12))
                    Rectangle().fill(Color(hex: 0x7A3E26)).frame(width: 12, height: 22).offset(x: 46, y: 12)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(x: 46, y: 12))
                    Rectangle().fill(Color(hex: 0x964B2E)).frame(width: 140, height: 14)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    Rectangle().fill(YoseColor.washi).frame(width: 12, height: 14).offset(x: -28, y: -13)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(x: -28, y: -13))
                    Rectangle().fill(YoseColor.tokiwa).frame(width: 12, height: 14).offset(x: 26, y: -13)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(x: 26, y: -13))
                    // みかん
                    Circle().fill(Color(hex: 0xE57C23)).frame(width: 10, height: 10)
                        .overlay(Circle().stroke(YoseColor.sumi, lineWidth: 1.5))
                        .offset(x: 0, y: -12)
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
                // 上部の長押（なげし）
                Rectangle().fill(Color(hex: 0x8C6B48)).frame(height: 8)
                    .overlay(alignment: .bottom) { Rectangle().fill(YoseColor.sumi).frame(height: 2) }
                    .position(x: w / 2, y: 18)

                // 左〜中央：電球つき楽屋鏡（木枠の上辺に電球5個が収まる）
                ZStack {
                    Rectangle().fill(YoseColor.kiDark).frame(width: 156, height: 92)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    Rectangle().fill(Color(hex: 0xD6E6EC)).frame(width: 140, height: 66).offset(y: 10)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(y: 10))
                    // 鏡の反射斜線
                    Path { p in
                        p.move(to: CGPoint(x: 20, y: 66)); p.addLine(to: CGPoint(x: 52, y: 12))
                        p.move(to: CGPoint(x: 33, y: 66)); p.addLine(to: CGPoint(x: 65, y: 12))
                    }
                    .stroke(Color.white.opacity(0.65), lineWidth: 3)
                    .frame(width: 140, height: 66).offset(y: 10)
                    // 上枠のハリウッド電球5個（芯に白いハイライト）
                    HStack(spacing: 18) {
                        ForEach(0..<5, id: \.self) { _ in
                            Circle().fill(YoseColor.kinBright).frame(width: 11, height: 11)
                                .overlay(Circle().fill(YoseColor.washi).frame(width: 4, height: 4))
                                .overlay(Circle().stroke(YoseColor.sumi, lineWidth: 1.5))
                        }
                    }
                    .offset(y: -38)
                }
                .position(x: w * 0.32, y: 96)

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

                // 手前：化粧前カウンター（壁から壁まで全幅）と差し入れ箱（下辺を天板の上辺に接地）
                ZStack {
                    Rectangle().fill(YoseColor.kiDark).frame(width: w + 4, height: 24)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    Rectangle().fill(YoseColor.washi).frame(width: 34, height: 16).offset(x: -60, y: -20)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(x: -60, y: -20))
                    Rectangle().fill(YoseColor.shu).frame(width: 14, height: 20).offset(x: 40, y: -22)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(x: 40, y: -22))
                }
                .position(x: w / 2, y: floorY + 14)
            }
        }
    }
}

// MARK: - 5. 電車の中（車窓2連・吊り革・臙脂のロングシート）
private struct TrainBackdrop: View {
    @Environment(\.eventTime) private var time
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, seatY = h * 0.64
            ZStack {
                // 車内化粧板の壁
                Color(hex: 0xEAE4D3)

                // 車窓2連（昼＝空と架線柱／夜＝濃紺と街の灯り）
                HStack(spacing: 20) {
                    ForEach(0..<2, id: \.self) { _ in
                        ZStack(alignment: .bottom) {
                            eventSky(time)
                            Rectangle().fill(time == .night ? Color(hex: 0x0C1220) : YoseColor.haiSumi.opacity(0.45)).frame(height: 18)
                        }
                        .frame(width: 132, height: 68)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    }
                }
                .position(x: w / 2, y: 88)

                // 上部の蛍光灯とパイプ、吊り革5個（三角の持ち手＝同じ三角で fill と stroke・窓にめり込まない）
                Rectangle().fill(YoseColor.washi).frame(width: w * 0.62, height: 6)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                    .position(x: w / 2, y: 8)
                Rectangle().fill(YoseColor.ginNezu).frame(height: 5)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                    .position(x: w / 2, y: 24)
                HStack(spacing: 54) {
                    ForEach(0..<5, id: \.self) { _ in
                        VStack(spacing: 0) {
                            Rectangle().fill(YoseColor.sumi).frame(width: 2, height: 10)
                            ZStack {
                                TriangleShape().fill(YoseColor.washi)
                                TriangleShape().stroke(YoseColor.sumi, lineWidth: 2)
                            }
                            .frame(width: 18, height: 14)
                        }
                    }
                }
                .position(x: w / 2, y: 38)

                // 阪急・上方私鉄風の臙脂モケット座席と木目肘掛け
                Rectangle().fill(YoseColor.enji).frame(height: 36)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    .position(x: w / 2, y: seatY)
                ForEach([0.25, 0.5, 0.75], id: \.self) { f in
                    Rectangle().fill(YoseColor.kuroUrushi.opacity(0.45)).frame(width: 1.5, height: 32)
                        .position(x: w * f, y: seatY)
                }
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
    @Environment(\.eventTime) private var time
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, groundY = h * 0.68
            ZStack {
                // 空と砂利の地面
                (time == .night
                    ? LinearGradient(colors: [Color(hex: 0x1C2640), Color(hex: 0x3A4666)], startPoint: .top, endPoint: .bottom)
                    : LinearGradient(colors: [Color(hex: 0xC9E2EC), YoseColor.kinari], startPoint: .top, endPoint: .bottom))
                Rectangle().fill(Color(hex: 0xD8CCB4))
                    .frame(height: h - groundY).position(x: w / 2, y: groundY + (h - groundY) / 2)

                // 左：公園のレトロ街灯（生垣の奥に立つ＝柱が植え込みを突き抜けない）
                ZStack {
                    Rectangle().fill(YoseColor.kuroUrushi).frame(width: 6, height: 106).offset(y: -7)
                    Rectangle().fill(YoseColor.kuroUrushi).frame(width: 24, height: 6).offset(y: -60)
                    Rectangle().fill(YoseColor.kinBright).frame(width: 18, height: 22).offset(y: -72)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2).offset(y: -72))
                }
                .position(x: w * 0.22, y: groundY - 46)

                // 奥の生垣（丸い茂み・不透明・地面線で止める。外形線は下に敷いて重なり目に縞を出さない）
                ZStack(alignment: .bottom) {
                    HStack(alignment: .bottom, spacing: -14) {
                        ForEach(0..<8, id: \.self) { idx in
                            UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 24)
                                .stroke(YoseColor.sumi, lineWidth: 3.5)
                                .frame(width: 64, height: idx.isMultiple(of: 2) ? 54 : 42)
                        }
                    }
                    HStack(alignment: .bottom, spacing: -14) {
                        ForEach(0..<8, id: \.self) { idx in
                            UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 24)
                                .fill(idx.isMultiple(of: 2) ? Color(hex: 0x2E583C) : Color(hex: 0x23452E))
                                .frame(width: 64, height: idx.isMultiple(of: 2) ? 54 : 42)
                        }
                    }
                }
                .frame(height: 54)
                .position(x: w / 2, y: groundY - 27)
                Rectangle().fill(YoseColor.sumi).frame(height: 2).position(x: w / 2, y: groundY)

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
    @Environment(\.eventTime) private var time
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, tableY = h * 0.72
            ZStack {
                Color(hex: 0xEFE6D4)
                // 奥の大きな窓枠（昼は空色・夜は濃紺に街の灯り）
                ZStack {
                    eventSky(time)
                    HStack(spacing: 0) {
                        Spacer(); Rectangle().fill(YoseColor.sumi).frame(width: 2); Spacer()
                        Rectangle().fill(YoseColor.sumi).frame(width: 2); Spacer()
                    }
                    if time == .night {
                        ForEach(Array([(0.10, 0.62), (0.22, 0.30), (0.40, 0.70), (0.58, 0.40), (0.74, 0.66), (0.90, 0.34)].enumerated()), id: \.offset) { _, d in
                            Rectangle().fill(YoseColor.kinBright.opacity(0.7)).frame(width: 4, height: 4)
                                .position(x: 240 * d.0, y: 56 * d.1)
                        }
                    }
                }
                .frame(width: 240, height: 56)
                .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                .position(x: w / 2, y: 86)

                // 腰壁と床（テーブルの下まで敷き切る）
                Rectangle().fill(Color(hex: 0x5A3E2B)).frame(height: h - (tableY - 10))
                    .overlay(alignment: .top) { Rectangle().fill(YoseColor.sumi).frame(height: 2) }
                    .position(x: w / 2, y: (tableY - 10) + (h - (tableY - 10)) / 2)

                // 天井から下がるペンダントランプ（コードを長く・窓より手前）
                VStack(spacing: 0) {
                    Rectangle().fill(YoseColor.sumi).frame(width: 2, height: 24)
                    ZStack {
                        TrapezoidShape(topInset: 16).fill(YoseColor.kinBright)
                        TrapezoidShape(topInset: 16).stroke(YoseColor.sumi, lineWidth: 2)
                    }
                    .frame(width: 64, height: 20)
                }
                .position(x: w / 2, y: 22)

                // 左右の赤いボックス席ソファ（背もたれの区切りと座面）
                ForEach([w * 0.18, w * 0.82], id: \.self) { sx in
                    ZStack {
                        Rectangle().fill(YoseColor.shu)
                        Rectangle().fill(YoseColor.sumi.opacity(0.7)).frame(height: 1.5).offset(y: -8)
                        Rectangle().fill(Color(hex: 0xA82E22)).frame(height: 16).frame(maxHeight: .infinity, alignment: .bottom)
                            .overlay(alignment: .top) { Rectangle().fill(YoseColor.sumi).frame(height: 1.5) }
                    }
                    .frame(width: 82, height: 58)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    .position(x: sx, y: tableY - 12)
                }

                // テーブルの中央支柱（天板から床へ）
                Rectangle().fill(Color(hex: 0x6E4630)).frame(width: 24, height: max(0, h - (tableY + 25)))
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    .position(x: w / 2, y: (tableY + 25) + max(0, h - (tableY + 25)) / 2)

                // 手前：木目テーブル天板＋開いたネタ帳（中央の綴じ線）＋コーヒーカップ2つ
                ZStack {
                    Rectangle().fill(Color(hex: 0x8C583A)).frame(width: 260, height: 26)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    Rectangle().fill(YoseColor.washi).frame(width: 44, height: 14).offset(x: -20, y: -18)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(x: -20, y: -18))
                        .overlay(Rectangle().fill(YoseColor.sumi).frame(width: 1.5, height: 14).offset(x: -20, y: -18))
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
private struct FujiShape: Shape {
    var tileY: CGFloat
    func path(in r: CGRect) -> Path {
        let w = r.width
        var p = Path()
        p.move(to: CGPoint(x: w * 0.15, y: tileY)); p.addLine(to: CGPoint(x: w * 0.44, y: 24))
        p.addLine(to: CGPoint(x: w * 0.56, y: 24)); p.addLine(to: CGPoint(x: w * 0.85, y: tileY)); p.closeSubpath()
        return p
    }
}
private struct FujiCapShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width
        var p = Path()
        p.move(to: CGPoint(x: w * 0.40, y: 48)); p.addLine(to: CGPoint(x: w * 0.44, y: 24))
        p.addLine(to: CGPoint(x: w * 0.56, y: 24)); p.addLine(to: CGPoint(x: w * 0.60, y: 48)); p.closeSubpath()
        return p
    }
}
private struct SentoBackdrop: View {
    @Environment(\.eventTime) private var time
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, tileY = h * 0.56, floorY = h * 0.76
            ZStack {
                // 上部：銭湯の富士山ペンキ絵（山にも墨枠）
                (time == .night ? Color(hex: 0x4A5F82) : Color(hex: 0xCBE4EE))
                FujiShape(tileY: tileY).fill(time == .night ? Color(hex: 0x2A4468) : Color(hex: 0x3B668C))
                FujiCapShape().fill(YoseColor.washi)
                FujiCapShape().stroke(YoseColor.sumi, lineWidth: 1.5)
                FujiShape(tileY: tileY).stroke(YoseColor.sumi, lineWidth: 2)

                // 中段：タイル壁（目地つき）とカラン（鏡3枚）
                ZStack {
                    Rectangle().fill(YoseColor.washi)
                    Path { p in
                        var y: CGFloat = 0
                        while y < floorY - tileY { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: w, y: y)); y += 14 }
                        var x: CGFloat = 0
                        while x < w { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: floorY - tileY)); x += 14 }
                    }
                    .stroke(Color(hex: 0x9FB6BC).opacity(0.55), lineWidth: 1)
                }
                .frame(height: floorY - tileY).clipped()
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
                        SentoBucketShape().fill(YoseColor.kinBright).frame(width: 34, height: 14)
                            .overlay(SentoBucketShape().stroke(YoseColor.sumi, lineWidth: 2))
                    }
                }
                .position(x: w / 2, y: floorY + 14)
                // 鏡の下のカラン（蛇口）
                HStack(spacing: 60) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle().fill(YoseColor.ginNezu).frame(width: 10, height: 5)
                            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1))
                    }
                }
                .position(x: w / 2, y: floorY - 7)

                if time == .night {
                    // 夜：電球色の乗算フィルター＋上部の紺の暗転＋天井灯2つ（昼の青白い自然光と明確に分ける）
                    Color(hex: 0xD9822B).opacity(0.28).blendMode(.multiply)
                    VStack(spacing: 0) {
                        LinearGradient(colors: [Color(hex: 0x1E293B).opacity(0.45), .clear], startPoint: .top, endPoint: .bottom).frame(height: 60)
                        Spacer()
                    }
                    ForEach([w * 0.16, w * 0.84], id: \.self) { lx in
                        RadialGradient(colors: [YoseColor.kinBright.opacity(0.7), .clear], center: .center, startRadius: 2, endRadius: 46)
                            .frame(width: 92, height: 92).position(x: lx, y: 18).blendMode(.screen)
                        Circle().fill(YoseColor.kinBright).frame(width: 14, height: 14)
                            .overlay(Circle().stroke(YoseColor.sumi, lineWidth: 1.5)).position(x: lx, y: 14)
                    }
                    // 湯船から立ち上る湯気（夜は高く濃く）
                    LinearGradient(colors: [.clear, Color.white.opacity(0.40)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 90).position(x: w / 2, y: floorY - 45)
                }
                // 湯気（夜は濃いめ＝営業中の明るさ）
                ForEach(0..<3, id: \.self) { i in
                    Ellipse().fill(Color.white.opacity(time == .night ? 0.34 : 0.22))
                        .frame(width: 90, height: 26).blur(radius: 7)
                        .position(x: w * (0.22 + 0.28 * CGFloat(i)), y: floorY - 26 - CGFloat(i % 2) * 14)
                }
            }
        }
    }
}

/// 銭湯の湯桶（上が広い逆台形）
private struct SentoBucketShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - 4, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX + 4, y: r.maxY)); p.closeSubpath()
        return p
    }
}

// MARK: - 9. 劇場（定式幕・寄席提灯・赤いモケット客席）
private struct TheaterBackdrop: View {
    @Environment(\.eventTime) private var time
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

                // 上部の臙脂水引幕
                Rectangle().fill(YoseColor.enji).frame(height: 26)
                    .overlay(alignment: .bottom) { Rectangle().fill(YoseColor.kin).frame(height: 2) }
                    .position(x: w / 2, y: 13)
                // 寄席提灯2つ（和紙色の胴＝縞と混ざらない）
                ForEach([w * 0.24, w * 0.76], id: \.self) { lx in
                    VStack(spacing: 0) {
                        Rectangle().fill(YoseColor.sumi).frame(width: 2, height: 8)
                        TheaterLantern(lit: false)
                    }
                    .position(x: lx, y: 54)
                }

                // 檜舞台の床と手前の赤い客席背もたれ4連
                Rectangle().fill(YoseColor.ki).frame(height: h - stageY)
                    .overlay(alignment: .top) { Rectangle().fill(YoseColor.sumi).frame(height: 2) }
                    .position(x: w / 2, y: stageY + (h - stageY) / 2)
                HStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2).fill(YoseColor.enji)
                            .frame(width: 68, height: 34)
                            .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.22)).frame(height: 3).padding(.horizontal, 4).padding(.top, 3) }
                            .overlay(RoundedRectangle(cornerRadius: 2).stroke(YoseColor.sumi, lineWidth: 2))
                    }
                }
                .position(x: w / 2, y: h - 14)
            }
        }
    }
}
/// 寄席提灯。lit=true は夜の灯り（暗転の上に重ねる）
private struct TheaterLantern: View {
    let lit: Bool
    var body: some View {
        ZStack {
            Rectangle().fill(lit ? Color(hex: 0xFFE3A0) : YoseColor.washi).frame(width: 28, height: 40)
                .overlay(Rectangle().fill(YoseColor.shu).frame(width: 6))
                .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
            Rectangle().fill(YoseColor.kuroUrushi).frame(width: 30, height: 5).offset(y: -20)
            Rectangle().fill(YoseColor.kuroUrushi).frame(width: 30, height: 5).offset(y: 20)
        }
        .frame(width: 30, height: 46)
    }
}

// MARK: - 10. 喫茶店（琥珀レンガ壁・ステンドグラス照明・純喫茶テーブル）
private struct KissatenBackdrop: View {
    @Environment(\.eventTime) private var time
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, floorY = h * 0.68
            ZStack {
                // 漆喰壁と琥珀レンガの腰壁（目地つき・暗くなりすぎない色）
                Color(hex: 0xE6DBC4)
                ZStack {
                    Rectangle().fill(Color(hex: 0x7A4B32))
                    Path { p in
                        for r in 0..<8 {
                            let y = CGFloat(r) * 10
                            p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: w, y: y))
                            var x: CGFloat = (r % 2 == 0) ? 0 : 14
                            while x < w { p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x, y: y + 10)); x += 28 }
                        }
                    }
                    .stroke(Color(hex: 0x4A2C1E).opacity(0.55), lineWidth: 1)
                }
                .frame(height: h - floorY + 24).clipped()
                .overlay(alignment: .top) { Rectangle().fill(YoseColor.sumi).frame(height: 2) }
                .position(x: w / 2, y: floorY - 12 + (h - floorY + 24) / 2)

                // 奥の窓2枚（照明と角が触れないよう間を広げる）
                HStack(spacing: 96) {
                    ForEach(0..<2, id: \.self) { _ in
                        ZStack {
                            Rectangle().fill(time == .night ? Color(hex: 0x24304A) : Color(hex: 0xF5D799))
                            Rectangle().fill(time == .night ? Color(hex: 0x4A3B32) : YoseColor.sumi).frame(width: 2.5)
                            Rectangle().fill(time == .night ? Color(hex: 0x4A3B32) : YoseColor.sumi).frame(height: 2.5)
                        }
                        .frame(width: 72, height: 68)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    }
                }
                .position(x: w / 2, y: 84)

                // ステンドグラス風ペンダント（傘型・臙脂／山吹／琥珀）
                VStack(spacing: 0) {
                    Rectangle().fill(YoseColor.sumi).frame(width: 2, height: 22)
                    ZStack {
                        HStack(spacing: 0) {
                            Rectangle().fill(YoseColor.enji)
                            Rectangle().fill(YoseColor.kinBright)
                            Rectangle().fill(Color(hex: 0xD96B27))
                        }
                        .clipShape(TrapezoidShape(topInset: 18))
                        TrapezoidShape(topInset: 18).stroke(YoseColor.sumi, lineWidth: 2)
                    }
                    .frame(width: 56, height: 22)
                }
                .position(x: w / 2, y: 25)

                // 手前：純喫茶のテーブル（天板に消金の縁・脚つき）とカップ＆ソーサー・クリームソーダ
                ZStack {
                    Rectangle().fill(Color(hex: 0x3D2214)).frame(width: 14, height: 40).offset(y: 30)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2).offset(y: 30))
                    Rectangle().fill(Color(hex: 0x965A38)).frame(width: 220, height: 20)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                        .overlay(alignment: .top) { Rectangle().fill(YoseColor.kin).frame(height: 1).padding(.horizontal, 2).padding(.top, 2) }
                    // カップ＆ソーサー
                    Rectangle().fill(YoseColor.washi).frame(width: 24, height: 4).offset(x: -36, y: -12)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(x: -36, y: -12))
                    Rectangle().fill(YoseColor.washi).frame(width: 16, height: 14).offset(x: -36, y: -21)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(x: -36, y: -21))
                    // クリームソーダ
                    Rectangle().fill(Color(hex: 0x389E72)).frame(width: 14, height: 24).offset(x: 36, y: -22)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(x: 36, y: -22))
                    Circle().fill(YoseColor.washi).frame(width: 9, height: 9).offset(x: 36, y: -36)
                        .overlay(Circle().stroke(YoseColor.sumi, lineWidth: 1.2).offset(x: 36, y: -36))
                }
                .position(x: w / 2, y: floorY + 26)
            }
        }
    }
}

// MARK: - 12. 焼肉屋（暖簾・品書き札・排煙ダクト・七輪ロースター）
private struct YakinikuBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, tableY = h * 0.72
            ZStack {
                Color(hex: 0xE8D9BC)
                // 上部の暖簾（臙脂に切れ込み）
                HStack(spacing: 0) {
                    ForEach(0..<6, id: \.self) { i in
                        Rectangle().fill(YoseColor.enji)
                            .overlay(alignment: .trailing) { Rectangle().fill(YoseColor.sumi.opacity(0.7)).frame(width: 1.5) }
                            .frame(height: i.isMultiple(of: 2) ? 30 : 26).frame(maxHeight: 30, alignment: .top)
                    }
                }
                .frame(height: 30).overlay(alignment: .top) { Rectangle().fill(YoseColor.kuroUrushi).frame(height: 5) }
                .position(x: w / 2, y: 15)

                // 壁の品書き札（縦長の木札3枚）
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Rectangle().fill(YoseColor.ki).frame(width: 22, height: 54)
                            .overlay(Rectangle().fill(i == 0 ? YoseColor.shu : YoseColor.sumi).frame(width: 4, height: 34))
                            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                    }
                }
                .position(x: 80, y: 80)
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Rectangle().fill(YoseColor.ki).frame(width: 22, height: 54)
                            .overlay(Rectangle().fill(i == 2 ? YoseColor.shu : YoseColor.sumi).frame(width: 4, height: 34))
                            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                    }
                }
                .position(x: w - 80, y: 80)

                // 腰壁と床
                Rectangle().fill(Color(hex: 0x5A3E2B)).frame(height: h - (tableY - 14))
                    .overlay(alignment: .top) { Rectangle().fill(YoseColor.sumi).frame(height: 2) }
                    .position(x: w / 2, y: (tableY - 14) + (h - (tableY - 14)) / 2)

                // 天井から降りる排煙ダクト（黒い筒＋つば）
                ZStack(alignment: .bottom) {
                    Rectangle().fill(Color(hex: 0x3A3632)).frame(width: 28, height: 110)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    Rectangle().fill(Color(hex: 0x4A453F)).frame(width: 52, height: 9)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                }
                .frame(width: 52, height: 110)
                .position(x: w / 2, y: 30 + 42 - 13)

                // 手前：木のテーブルと七輪ロースター（炭火のスリット）・皿の肉
                ZStack {
                    Rectangle().fill(Color(hex: 0x8C583A)).frame(width: 340, height: 26)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    // 七輪（黒漆の台＋炭火のスリット）
                    Rectangle().fill(Color(hex: 0x1E1916)).frame(width: 74, height: 24).offset(y: -25)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2).offset(y: -25))
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { _ in Rectangle().fill(Color(hex: 0xE2552E)).frame(width: 14, height: 4) }
                    }
                    .offset(y: -30)
                    // 金網
                    Rectangle().fill(YoseColor.ginNezu).frame(width: 74, height: 2).offset(y: -37)
                    // 皿の肉（左右）
                    ForEach([-96.0, 92.0], id: \.self) { dx in
                        Ellipse().fill(YoseColor.washi).frame(width: 44, height: 10).offset(x: dx, y: -17)
                            .overlay(Ellipse().stroke(YoseColor.sumi, lineWidth: 1.5).frame(width: 44, height: 10).offset(x: dx, y: -17))
                        Rectangle().fill(YoseColor.shu).frame(width: 12, height: 4).rotationEffect(.degrees(-6)).offset(x: dx - 8, y: -21)
                        Rectangle().fill(Color(hex: 0xD2563F)).frame(width: 12, height: 4).rotationEffect(.degrees(5)).offset(x: dx + 6, y: -22)
                    }
                }
                .position(x: w / 2, y: tableY + 12)
                // テーブルの前板と中央の太い脚（天板を床まで接地させる）
                Rectangle().fill(Color(hex: 0x6E4630)).frame(width: 340, height: max(0, h - (tableY + 25)))
                    .overlay(alignment: .top) { Rectangle().fill(YoseColor.sumi).frame(height: 2) }
                    .position(x: w / 2, y: (tableY + 25) + max(0, h - (tableY + 25)) / 2)
            }
        }
    }
}

// MARK: - 13. 稽古場の受付（ハイカウンター・飴皿・呼び鈴・予約札）
private struct UketsukeBackdrop: View {
    @Environment(\.eventTime) private var time
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, floorY = h * 0.68
            ZStack {
                YoseColor.kinari
                Rectangle().fill(YoseColor.kiDark).frame(height: h - floorY)
                    .position(x: w / 2, y: floorY + (h - floorY) / 2)
                Rectangle().fill(YoseColor.sumi).frame(height: 2).position(x: w / 2, y: floorY)
                Rectangle().fill(Color(hex: 0x8C6B48)).frame(height: 8)
                    .overlay(alignment: .bottom) { Rectangle().fill(YoseColor.sumi).frame(height: 2) }
                    .position(x: w / 2, y: 18)

                // 左：高窓
                ZStack {
                    Rectangle().fill(time == .night ? Color(hex: 0x1E293B) : Color(hex: 0xD8E8F0))
                    Rectangle().fill(YoseColor.sumi).frame(width: 2)
                    Rectangle().fill(YoseColor.sumi).frame(height: 2)
                }
                .frame(width: 64, height: 54).overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                .position(x: 54, y: 70)

                // 奥の壁：「受付」の看板札と予約の貼り紙
                ZStack {
                    Rectangle().fill(YoseColor.ki)
                    Rectangle().stroke(YoseColor.kiDark, lineWidth: 1).padding(4)
                    Text("受付").font(YoseFont.mincho(20)).foregroundStyle(YoseColor.sumi)
                }
                .frame(width: 84, height: 40)
                .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))
                .position(x: w * 0.56, y: 62)
                ForEach(0..<3, id: \.self) { i in
                    Rectangle().fill(YoseColor.washi).frame(width: 20, height: 28)
                        .overlay(Rectangle().fill(YoseColor.sumi.opacity(0.6)).frame(width: 2, height: 16))
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.2))
                        .position(x: w * 0.56 + 62 + CGFloat(i) * 26, y: 62)
                }

                // 手前：ハイカウンター（高さ90・天板の厚み）と飴皿・呼び鈴・名簿
                ZStack(alignment: .top) {
                    Rectangle().fill(Color(hex: 0x7A5A3A))
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    Rectangle().fill(YoseColor.ki).frame(height: 8)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    // 前板の縦羽目
                    HStack(spacing: 18) {
                        ForEach(0..<14, id: \.self) { _ in Rectangle().fill(YoseColor.sumi.opacity(0.35)).frame(width: 1.5) }
                    }
                    .padding(.top, 12).clipped()
                }
                .frame(width: w * 0.80, height: 90)
                .position(x: w / 2, y: h - 45 + 4)
                // 天板の上の小物（下辺を天板の上辺に接地）
                let topY = h - 90 + 4
                // エントリー番号札の束（白和紙＋朱の帯）と名簿バインダー
                Rectangle().fill(YoseColor.washi).frame(width: 36, height: 16)
                    .overlay(alignment: .top) { Rectangle().fill(YoseColor.shu).frame(height: 4) }
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                    .position(x: w * 0.30, y: topY - 8)
                Rectangle().fill(Color(hex: 0x8C6B48)).frame(width: 44, height: 10)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                    .position(x: w * 0.30 + 46, y: topY - 5)
                // 呼び鈴
                Circle().trim(from: 0.5, to: 1).fill(YoseColor.kinBright).frame(width: 22, height: 22)
                    .overlay(Circle().trim(from: 0.5, to: 1).stroke(YoseColor.sumi, lineWidth: 1.5).frame(width: 22, height: 22))
                    .position(x: w * 0.60, y: topY - 5)
                Rectangle().fill(YoseColor.sumi).frame(width: 26, height: 3).position(x: w * 0.60, y: topY - 1.5)
                Circle().fill(YoseColor.kinBright).frame(width: 4, height: 4)
                    .overlay(Circle().stroke(YoseColor.sumi, lineWidth: 1)).position(x: w * 0.60, y: topY - 17)
                // 名簿
                Rectangle().fill(YoseColor.washi).frame(width: 40, height: 6)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                    .position(x: w * 0.70, y: topY - 3)
            }
        }
    }
}

// MARK: - 11. 事務所（ブラインド窓・所属芸人番付ボード・事務机）
private struct OfficeBackdrop: View {
    @Environment(\.eventTime) private var time
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, floorY = h * 0.68
            ZStack {
                YoseColor.kinari
                Rectangle().fill(YoseColor.kiDark).frame(height: h - floorY)
                    .overlay(alignment: .top) { Rectangle().fill(YoseColor.sumi).frame(height: 2) }
                    .position(x: w / 2, y: floorY + (h - floorY) / 2)
                // 上部の梁（長押）
                Rectangle().fill(YoseColor.kiDark).frame(height: 6)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    .position(x: w / 2, y: 17)

                // 左：ブラインド窓（細いスラット・夜は隙間が濃紺の夜空）
                VStack(spacing: 0) {
                    ForEach(0..<13, id: \.self) { i in
                        Rectangle().fill(i.isMultiple(of: 2) ? (time == .night ? Color(hex: 0x24344D) : Color(hex: 0xD2E3EC)) : (time == .night ? Color(hex: 0xB8B4A6) : YoseColor.washi))
                    }
                }
                .frame(width: 124, height: 78)
                .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                .position(x: w * 0.26, y: 76)

                // 右：所属芸人の番付ボード（縦長の木札を2段×8列・先頭だけ朱）
                ZStack {
                    Rectangle().fill(YoseColor.washi)
                    VStack(spacing: 6) {
                        ForEach(0..<2, id: \.self) { r in
                            HStack(spacing: 2) {
                                ForEach(0..<8, id: \.self) { c in
                                    Rectangle().fill((r == 0 && c == 0) ? YoseColor.shu : YoseColor.ki)
                                        .frame(width: 11, height: 28)
                                        .overlay(Rectangle().fill(YoseColor.sumi.opacity(0.75)).frame(width: 2, height: 16))
                                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1))
                                }
                            }
                        }
                    }
                }
                .frame(width: 124, height: 78)
                .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))
                .position(x: w * 0.74, y: 76)

                // 事務机の左右の脚
                ForEach([w / 2 - 112, w / 2 + 112], id: \.self) { lx in
                    Rectangle().fill(Color(hex: 0x7A5C3C)).frame(width: 12, height: h - (floorY + 34))
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                        .position(x: lx, y: (floorY + 34) + (h - (floorY + 34)) / 2)
                }
                // 手前：事務机（天板に厚み）・黒電話（受話器とダイヤル）・台本束・契約書バインダー
                ZStack {
                    Rectangle().fill(Color(hex: 0x9C7A54)).frame(width: 260, height: 32)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                        .overlay(alignment: .top) { Rectangle().fill(YoseColor.ki).frame(height: 6).padding(2) }
                    // 黒電話
                    Rectangle().fill(YoseColor.kuroUrushi).frame(width: 36, height: 14).offset(x: -64, y: -23)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(x: -64, y: -23))
                    Rectangle().fill(YoseColor.kuroUrushi).frame(width: 42, height: 6).offset(x: -64, y: -33)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.2).offset(x: -64, y: -33))
                    Circle().fill(YoseColor.washi).frame(width: 6, height: 6).offset(x: -64, y: -23)
                    // 台本束（斜め重ね）
                    Rectangle().fill(YoseColor.washi).frame(width: 30, height: 8).rotationEffect(.degrees(-5)).offset(x: -6, y: -20)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.2).frame(width: 30, height: 8).rotationEffect(.degrees(-5)).offset(x: -6, y: -20))
                    Rectangle().fill(YoseColor.ki).frame(width: 30, height: 8).rotationEffect(.degrees(4)).offset(x: -4, y: -27)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.2).frame(width: 30, height: 8).rotationEffect(.degrees(4)).offset(x: -4, y: -27))
                    // 契約書バインダー
                    Rectangle().fill(YoseColor.washi).frame(width: 44, height: 10).offset(x: 48, y: -21)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5).offset(x: 48, y: -21))
                }
                .position(x: w / 2, y: floorY + 18)
            }
        }
    }
}
