// YoseGameParts.swift  §5 ⑦ 数値表示 ⑩ タブ ⑪ モーダル ⑫ トースト

import SwiftUI

// MARK: ⑦ 数値表示（実力・お金・体力・知名度）
struct YosePowerBadge: View {
    let power: Int
    var delta: Int? = nil
    var compact = false
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("実力").font(YoseFont.gothic(compact ? 11 : 12, weight: .heavy)).foregroundStyle(YoseColor.enji)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(YoseColor.enji.opacity(0.12))
                .overlay(Rectangle().stroke(YoseColor.enji, lineWidth: 1))
            Text("\(power)").font(YoseFont.number(compact ? 24 : 30, weight: .black))
                .foregroundStyle(YoseColor.sumi)
                .yoseNumberBounce(Double(power))
            if let delta, delta > 0 {
                Text("+\(delta)").font(YoseFont.number(14, weight: .heavy)).foregroundStyle(YoseColor.shu)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .yoseKifuda()
    }
}

/// 体力・知名度・所持金の黒帯（体力は筆太ゲージ＋数字）
struct YoseVitalMoneyBar: View {
    let stamina: Int
    let maxStamina: Int
    let money: Int
    var fame: Int? = nil
    var fameDelta: Int? = nil
    var staminaColor: Color = YoseColor.tokiwa

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Text("体力").font(YoseFont.gothic(11, weight: .heavy)).foregroundStyle(YoseColor.kin)
                YoseGauge(value: Double(stamina), total: Double(maxStamina), fill: staminaColor, height: 12)
                    .frame(width: 76)
                (Text("\(stamina)").font(YoseFont.number(15, weight: .heavy)).foregroundStyle(YoseColor.kinari)
                + Text("/\(maxStamina)").font(YoseFont.number(11, weight: .bold)).foregroundStyle(YoseColor.ginNezu))
                    .lineLimit(1).fixedSize()
            }
            Spacer(minLength: 0)
            if let fame {
                HStack(spacing: 3) {
                    Text("知名度").font(YoseFont.gothic(10, weight: .bold)).foregroundStyle(YoseColor.kinari.opacity(0.8))
                    Text("\(fame)").font(YoseFont.number(15, weight: .heavy)).foregroundStyle(YoseColor.kinari)
                    if let fameDelta, fameDelta > 0 {
                        Text("↑+\(fameDelta)").font(YoseFont.number(11, weight: .heavy)).foregroundStyle(YoseColor.kinBright)
                    }
                }
            }
            Text("¥\(money.formatted(.number))").font(YoseFont.number(17, weight: .heavy))
                .foregroundStyle(YoseColor.kinBright)
        }
        .padding(.horizontal, YoseMetrics.screenMargin)
        .frame(height: 36)
        .background(YoseColor.kuroUrushi)
        .overlay(alignment: .top) { Rectangle().fill(YoseColor.sumi).frame(height: 2) }
    }
}

// MARK: ⑩ タブ
struct YoseTopTabBar: View {
    let tabs: [String]
    @Binding var selectedIndex: Int
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { idx in
                let sel = idx == selectedIndex
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { selectedIndex = idx }
                } label: {
                    Text(tabs[idx]).font(YoseFont.gothic(15, weight: .heavy))
                        .foregroundStyle(sel ? YoseColor.sumi : YoseColor.haiSumi)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(sel ? YoseColor.washi : YoseColor.ki)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(sel ? YoseColor.shu : YoseColor.sumi).frame(height: sel ? 4 : 1.5)
                        }
                        .overlay(alignment: .trailing) {
                            if idx < tabs.count - 1 { Rectangle().fill(YoseColor.sumi).frame(width: 1.5) }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 42)
    }
}

struct YoseFooterItem {
    let title: String
    let symbol: String
    let action: () -> Void
}

struct YoseFooterTabBar: View {
    let items: [YoseFooterItem]
    var body: some View {
        HStack(spacing: 8) {
            ForEach(items.indices, id: \.self) { idx in
                Button(action: items[idx].action) {
                    HStack(spacing: 6) {
                        Image(systemName: items[idx].symbol).font(.system(size: 13, weight: .black))
                            .foregroundStyle(YoseColor.enji)
                        Text(items[idx].title).font(YoseFont.gothic(16, weight: .heavy))
                            .foregroundStyle(YoseColor.sumi)
                    }
                    .frame(maxWidth: .infinity).frame(height: 44)
                }
                .buttonStyle(YoseButtonStyle(.kifuda))
            }
        }
        .padding(.horizontal, YoseMetrics.screenMargin).padding(.vertical, 8)
        .background(YoseColor.kuroUrushi)
        .overlay(alignment: .top) { Rectangle().fill(YoseColor.kin).frame(height: 1.5) }
    }
}

// MARK: ⑪ モーダル
struct YoseModal<Content: View>: View {
    let title: String
    let primaryTitle: String
    let primaryAction: () -> Void
    var cancelTitle: String? = "やめる"
    var cancelAction: (() -> Void)? = nil
    let content: Content

    init(title: String, primaryTitle: String, primaryAction: @escaping () -> Void,
         cancelTitle: String? = "やめる", cancelAction: (() -> Void)? = nil,
         @ViewBuilder content: () -> Content) {
        self.title = title; self.primaryTitle = primaryTitle; self.primaryAction = primaryAction
        self.cancelTitle = cancelTitle; self.cancelAction = cancelAction; self.content = content()
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 0) {
                Text(title).font(YoseFont.gothic(17, weight: .heavy)).foregroundStyle(YoseColor.kin)
                    .frame(maxWidth: .infinity).frame(height: 40).background(YoseColor.enji)
                    .overlay(alignment: .bottom) { Rectangle().fill(YoseColor.kin).frame(height: 1.5) }
                VStack(spacing: 16) {
                    content
                    HStack(spacing: 10) {
                        if let cancelTitle, let cancelAction {
                            Button(cancelTitle, action: cancelAction)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .buttonStyle(YoseButtonStyle(.secondary))
                        }
                        Button(primaryTitle, action: primaryAction)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .buttonStyle(YoseButtonStyle(.primary))
                    }
                }
                .padding(16).background(YoseColor.washi)
            }
            .clipShape(RoundedRectangle(cornerRadius: YoseMetrics.radius))
            .overlay(RoundedRectangle(cornerRadius: YoseMetrics.radius).stroke(YoseColor.sumi, lineWidth: 2.5))
            .background(RoundedRectangle(cornerRadius: YoseMetrics.radius).fill(YoseColor.sumi).offset(y: 4))
            .padding(.horizontal, 24)
        }
    }
}

// MARK: ⑫ トースト（ヘッダー直下から1.8秒）
struct YoseToast: View {
    let message: String
    var body: some View {
        HStack(spacing: 8) {
            Rectangle().fill(YoseColor.shu).frame(width: 4, height: 20)
            Text(message).font(YoseFont.gothic(14, weight: .heavy)).foregroundStyle(YoseColor.kinari)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(YoseColor.kuroUrushi)
        .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1.5))
        .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))
    }
}

/// 使い方: .yoseToast($message)  message を入れると上からスライドインして 1.8 秒で消える
private struct YoseToastModifier: ViewModifier {
    @Binding var message: String?
    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let m = message {
                YoseToast(message: m).padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: m) {
                        try? await Task.sleep(nanoseconds: 1_800_000_000)
                        withAnimation(.easeOut(duration: 0.18)) { message = nil }
                    }
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: message)
    }
}
extension View {
    func yoseToast(_ message: Binding<String?>) -> some View { modifier(YoseToastModifier(message: message)) }
}
