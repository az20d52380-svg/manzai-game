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
            .animation(Theme.Motion.r(.spring(response: 0.22, dampingFraction: 0.55)), value: isStamped)
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
            .animation(Theme.Motion.r(.spring(response: 0.28, dampingFraction: 0.72)), value: value)
            .animation(Theme.Motion.r(.spring(response: 0.28, dampingFraction: 0.72)), value: bump)
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
                withAnimation(Theme.Motion.r(.easeOut(duration: 0.28))) { glow = false }
            }
    }
}

/// 経験点の丸アイコン：増えた瞬間に 1.35→1.0 で跳ね、同色の細い輪が 1.0→1.6 倍に広がって消える（0.3秒）。
/// 視差を減らす時は跳ねも輪も止め、丸を0.25秒だけ白く光らせる。減った時は何もしない（Gemini R7 §2-D）。
struct YoseExpPingModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: Int
    let color: Color
    @State private var bump = false
    @State private var ring = false
    @State private var ringOn = false
    @State private var glow = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(bump ? 1.35 : 1.0)
            .overlay { Circle().fill(Color.white).opacity(glow ? 0.55 : 0).allowsHitTesting(false) }
            .overlay {
                Circle().stroke(color, lineWidth: 1.5)
                    .scaleEffect(ring ? 1.6 : 1.0).opacity(ringOn ? 0.9 : 0)
                    .allowsHitTesting(false)
            }
            .onChange(of: value) { old, new in
                guard new > old else { return }
                if reduceMotion {
                    glow = true
                    DispatchQueue.main.async { withAnimation(.easeOut(duration: 0.25)) { glow = false } }
                    return
                }
                ring = false; ringOn = true
                withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) { bump = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) { bump = false } }
                DispatchQueue.main.async { withAnimation(.easeOut(duration: 0.3)) { ring = true; ringOn = false } }
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
                withAnimation(Theme.Motion.r(.spring(response: 0.25, dampingFraction: 0.8).delay(delay))) { shown = true }
            }
    }
}

enum YoseHaptic {
    static func press() { Haptics.rigid(0.8) }   // 共通口（0.08秒以内の次は捨てる・強さ0.8＝Gemini R7 §2-B）
}

extension View {
    func yoseStampImpact(_ isStamped: Bool) -> some View { modifier(YoseStampImpactModifier(isStamped: isStamped)) }
    func yoseNumberBounce(_ value: Double) -> some View { modifier(YoseNumberBounceModifier(value: value)) }
    func yoseExpPing(_ value: Int, color: Color) -> some View { modifier(YoseExpPingModifier(value: value, color: color)) }
    func yoseRowGlow(trigger: Int) -> some View { modifier(YoseRowGlowModifier(trigger: trigger)) }
    func yoseAppear(delay: Double = 0) -> some View { modifier(YoseAppearModifier(delay: delay)) }
}
