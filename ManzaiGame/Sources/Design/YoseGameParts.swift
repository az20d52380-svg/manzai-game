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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("実力 \(power)\(delta.map { $0 > 0 ? "、\($0)上がった" : "" } ?? "")")
    }
}

/// 体力・知名度・所持金の黒帯（体力は筆太ゲージ＋数字）
struct YoseVitalMoneyBar: View {
    let stamina: Int
    let maxStamina: Int
    let money: Int
    var fame: Int? = nil
    var fameDelta: Int? = nil
    var staminaColor: Color = Color(hex: 0x3E8E57)   // 黒帯の上でも満タンが読める若竹色

    var body: some View {
        let big = Font.mzScaled(10) > 11   // 大きい文字サイズでは体力ゲージを縮めて、知名度・借金・所持金を潰さない
        HStack(spacing: big ? 8 : 12) {
            HStack(spacing: 6) {
                Text("体力").font(YoseFont.gothic(11, weight: .heavy)).foregroundStyle(YoseColor.kin).fixedSize()
                YoseGauge(value: Double(stamina), total: Double(maxStamina), fill: staminaColor, height: 12)
                    .frame(width: big && fame != nil ? (money < 0 ? 22 : 34) : (fame == nil ? 76 : 60))   // 知名度も並ぶ黒帯では、ラベルを潰さないよう少し短く
                (Text("\(stamina)").font(YoseFont.number(15, weight: .heavy)).foregroundStyle(YoseColor.kinari)
                + Text("/\(maxStamina)").font(YoseFont.number(11, weight: .bold)).foregroundStyle(YoseColor.ginNezu))
                    .lineLimit(1).fixedSize()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("体力 \(maxStamina)のうち\(stamina)")
            Spacer(minLength: 0)
            if let fame {
                HStack(spacing: 3) {
                    Text("知名度").font(YoseFont.gothic(11, weight: .bold)).lineLimit(1).fixedSize().foregroundStyle(YoseColor.kinari.opacity(0.8))
                    Text("\(fame)").font(YoseFont.number(15, weight: .heavy)).foregroundStyle(YoseColor.kinari)
                    if let fameDelta, fameDelta > 0 {
                        Text("↑+\(fameDelta)").font(YoseFont.number(11, weight: .heavy)).foregroundStyle(YoseColor.kinBright)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("知名度 \(fame)\((fameDelta ?? 0) > 0 ? "、\(fameDelta ?? 0)上がった" : "")")
            }
            if money < 0 { YoseTag(text: "借金", style: .outlineShu).fixedSize() }   // 所持金マイナスの間だけ（表示のみ）
            Text("¥\(money.formatted(.number))").font(YoseFont.number(17, weight: .heavy))
                .foregroundStyle(money < 0 ? YoseColor.shu : YoseColor.kinBright)
                .lineLimit(1).fixedSize()
                .accessibilityLabel(money < 0 ? "所持金 マイナス\(-money)円、借金" : "所持金 \(money)円")
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
                        Image(systemName: items[idx].symbol).font(.system(size: Font.mzScaled(13), weight: .black))
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

// MARK: 初回だけの短い説明（⑪モーダルの一種・UserDefaults で一度きり・タップで閉じる）
/// 初めて遊ぶ人向けの一言説明の「見た」記録。キーは "mz.hint.<key>"。`？` から開き直す時は記録を見ない。
enum OneTimeHint {
    static func isDone(_ key: String) -> Bool { UserDefaults.standard.bool(forKey: "mz.hint.\(key)") }
    static func markDone(_ key: String) { UserDefaults.standard.set(true, forKey: "mz.hint.\(key)") }
    /// DEBUG の目視・スモーク（MZ_UI / MZ_SMOKE）では出さない（他の目視を邪魔しない）。MZ_HINT=1 で強制表示。
    static var suppressedForDebug: Bool {
        #if DEBUG
        let e = ProcessInfo.processInfo.environment
        if e["MZ_HINT"] != nil { return false }
        return e["MZ_UI"] != nil || e["MZ_SMOKE"] != nil || e["MZ_ENDING"] != nil
        #else
        return false
        #endif
    }
}

struct HintSpec: Identifiable, Equatable {
    let key: String
    let title: String
    let rows: [Row]
    var note: String? = nil
    var id: String { key }
    struct Row: Equatable { let term: String; let text: String }
}

/// 用語＋ひとこと説明を並べたモーダル。ボタンは「わかった」1つだけ（押すまで他は触れない＝1画面1回きり）。
struct HintModal: View {
    let spec: HintSpec
    let onClose: () -> Void
    var body: some View {
        YoseModal(title: spec.title, primaryTitle: "わかった", primaryAction: onClose, cancelTitle: nil) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(spec.rows, id: \.term) { r in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(r.term).font(YoseFont.gothic(13, weight: .heavy)).foregroundStyle(YoseColor.kinari)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .frame(minWidth: 56)
                            .background(YoseColor.enji)
                            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                        Text(r.text).font(YoseFont.gothic(14, weight: .bold)).foregroundStyle(YoseColor.sumi)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if let n = spec.note {
                    Text(n).font(YoseFont.gothic(13, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// 用語の小さな「？」ボタン（押すと説明を開き直す）。44pt の当たり判定。
struct HintMarkButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text("？").font(YoseFont.gothic(15, weight: .black)).foregroundStyle(YoseColor.sumi)
                .frame(width: 26, height: 26)
                .background(YoseColor.kinari)
                .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("説明を見る")
    }
}
