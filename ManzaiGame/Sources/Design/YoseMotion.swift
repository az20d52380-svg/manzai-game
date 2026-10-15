// YoseMotion.swift  §6 動き（物理的な重さ。長い easeInOut は使わない）

import SwiftUI
import UIKit

/// 判子叩きつけ：scale 2.2→1.0 + opacity。着地で success ハプティクス＋画面微振動用の値を返す。
struct YoseStampImpactModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isStamped: Bool
    func body(content: Content) -> some View {
        content
            .scaleEffect(isStamped || reduceMotion ? 1.0 : 2.2)
            .opacity(isStamped ? 1.0 : 0.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.55), value: isStamped)
            .onChange(of: isStamped) { _, v in
                if v { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            }
    }
}

/// 数値の増減：numericText＋値が変わった瞬間に 1.2→1.0 で跳ねる
struct YoseNumberBounceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: Double
    @State private var bump = false
    func body(content: Content) -> some View {
        content
            .contentTransition(.numericText(value: value))
            .scaleEffect(bump && !reduceMotion ? 1.2 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: value)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: bump)
            .onChange(of: value) { _, _ in
                bump = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { bump = false }
            }
    }
}

/// 行の一瞬の山吹光り（[+] を押した行用）。trigger が変わるたびに光る。
struct YoseRowGlowModifier: ViewModifier {
    let trigger: Int
    @State private var glow = false
    func body(content: Content) -> some View {
        content
            .background(YoseColor.kinBright.opacity(glow ? 0.35 : 0))
            .onChange(of: trigger) { _, _ in
                glow = true
                withAnimation(.easeOut(duration: 0.28)) { glow = false }
            }
    }
}

/// 要素の出現：下から10pt せり上がる（delay で順送り。講評→結果は 0.12 秒差）
struct YoseAppearModifier: ViewModifier {
    var delay: Double = 0
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .offset(y: shown ? 0 : 10)
            .opacity(shown ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8).delay(delay)) { shown = true }
            }
    }
}

enum YoseHaptic {
    static func press() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
}

extension View {
    func yoseStampImpact(_ isStamped: Bool) -> some View { modifier(YoseStampImpactModifier(isStamped: isStamped)) }
    func yoseNumberBounce(_ value: Double) -> some View { modifier(YoseNumberBounceModifier(value: value)) }
    func yoseRowGlow(trigger: Int) -> some View { modifier(YoseRowGlowModifier(trigger: trigger)) }
    func yoseAppear(delay: Double = 0) -> some View { modifier(YoseAppearModifier(delay: delay)) }
}
