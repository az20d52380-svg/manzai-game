// FirstStageView.swift
// 導入の回想の直後に入る「初舞台」（約25秒・必ずウケる・勝ち負けなし・ゲームの数値は一切変わらない）。
// 設計: docs/first3min_hook_v0.md 案a／docs/gemini_design_r7_feel_1102_v0.md §2-F（台詞は採用せず、標準語の地の文）。
// 流れ: 板付き → 大きな赤いボタンを1回押す（押さなくても一定時間で進む）→ どっと沸く → 判子 → 現実（まばらな拍手）→ 苦い一言 →「第1週へ」。
// 音は既存SEのみ。「視差効果を減らす」時は揺れ・波紋・縮小を止め、明暗差と音の落差だけで見せる。

import SwiftUI

struct FirstStageView: View {
    let combiName: String
    var onSkip: (() -> Void)? = nil   // 2周目以降だけ「とばす ▶」を出す
    var onComplete: () -> Void

    private enum Phase { case enter, ready, burst, stamped, reality, bitter }
    @State private var phase: Phase = .enter
    @State private var flash = 0
    @State private var shake = 0
    @State private var burstTick = 0
    @State private var pressed = false
    @State private var ripple = false
    @State private var task: Task<Void, Never>? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var warm: Bool { phase == .burst || phase == .stamped }
    private var cold: Bool { phase == .reality || phase == .bitter }

    var body: some View {
        ZStack {
            Theme.house.ignoresSafeArea()   // 縮小した時の周りを暗く保つ
            StageFrame(mode: cold ? .loser : .lit, performers: true, floorTop: 0.52)
                .scaleEffect(cold && !reduceMotion ? 0.94 : 1)
                .animation(Theme.Motion.r(.easeInOut(duration: 0.5)), value: cold)
            // 山吹の光（沸いた間だけ）／蛍光灯色（現実）。動きが無くても明暗差で伝わる
            Rectangle().fill(Theme.gold.opacity(warm ? 0.22 : 0)).ignoresSafeArea().allowsHitTesting(false)
                .animation(.easeOut(duration: reduceMotion ? 0.4 : 0.15), value: warm)
            Rectangle().fill(Color(hex: 0xB8C4CC).opacity(cold ? 0.20 : 0)).ignoresSafeArea().allowsHitTesting(false)
                .animation(.easeIn(duration: 0.15), value: cold)
            if warm && !reduceMotion {
                GeometryReader { geo in
                    Circle().stroke(Theme.gold.opacity(ripple ? 0 : 0.8), lineWidth: 6)
                        .frame(width: 80, height: 80).scaleEffect(ripple ? 9 : 0.3)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
                }
                .allowsHitTesting(false)
            }
            ParticleBurst(trigger: burstTick, colors: [Theme.gold, YoseColor.shu, YoseColor.kinBright], count: 30,
                          origin: UnitPoint(x: 0.5, y: 0.45)).allowsHitTesting(false)

            VStack(spacing: 0) {
                StageSign(title: combiName, subtitle: "初舞台").padding(.top, 54)
                Spacer()
                if warm || phase == .reality {
                    WaveformView(passed: phase != .reality, compact: true)
                        .frame(height: 44).padding(.horizontal, 36)
                        .opacity(phase == .reality ? 0.35 : 1)
                        .accessibilityHidden(true)
                }
                Spacer().frame(height: 12)
                bottomPanel
            }
            if phase == .stamped {
                GeometryReader { geo in
                    YoseHankoStamp(text: "ウケた", isSquare: true, angle: -8)
                        .scaleEffect(2.2).position(x: geo.size.width / 2 + 70, y: geo.size.height * 0.34)
                }
                .transition(.scale(scale: 1.8).combined(with: .opacity))
                .allowsHitTesting(false)
            }
            if let onSkip {
                VStack { HStack { Spacer()
                    Button("とばす ▶") { task?.cancel(); Sound.play(.cursor); onSkip() }
                        .buttonStyle(YoseButtonStyle(.secondary)).padding(.trailing, 12).padding(.top, 6)
                        .accessibilityLabel("とばす")
                }; Spacer() }
            }
        }
        .screenFlash(trigger: flash, color: Theme.gold, strength: 0.4)
        .screenShake(trigger: shake, intensity: 8)
        .onAppear { start() }
        .onDisappear { task?.cancel() }
    }

    @ViewBuilder private var bottomPanel: some View {
        VStack(spacing: 14) {
            switch phase {
            case .enter:
                YoseNarration(text: "幕が上がる。客席は、まだ静かだ。").transition(.opacity)
            case .ready:
                YoseNarration(text: "最初のツッコミ。ここだ。").transition(.opacity)
                Button(action: press) {
                    Text("ツッコむ！").font(YoseFont.gothic(30, weight: .black)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 84)
                        .background(YoseColor.shu)
                        .overlay(Rectangle().stroke(YoseColor.kinBright, lineWidth: 3))
                }
                .buttonStyle(.plain).padding(.horizontal, 28)
                .accessibilityLabel("ツッコむ")
            case .burst, .stamped:
                YoseNarration(text: "客席が、どっと沸いた。").transition(.opacity)
            case .reality:
                YoseNarration(text: "お辞儀をして、顔を上げる。").transition(.opacity)
            case .bitter:
                Text("ウケた。でも、客は十人だった。")
                    .font(YoseFont.mincho(14)).foregroundStyle(YoseColor.sumi)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .yoseHarigami(isFeatured: false).padding(.horizontal, 6)
                    .transition(.opacity)
                Button("第1週へ") { task?.cancel(); Sound.play(.tap); Haptics.rigid(0.7); onComplete() }
                    .buttonStyle(YoseButtonStyle(.primary)).padding(.horizontal, 60)
            }
        }
        .padding(.horizontal, 14).padding(.bottom, 34)
        .animation(.easeOut(duration: 0.25), value: phase)
        .onChange(of: phase) { _, p in   // 画面が自動で進む場面＝変わった文を読み上げる（stamped は burst と同じ文）
            let line: String? = switch p {
            case .enter, .stamped: nil
            case .ready: "最初のツッコミ。ここだ。"
            case .burst: "客席が、どっと沸いた。"
            case .reality: "お辞儀をして、顔を上げる。"
            case .bitter: "ウケた。でも、客は十人だった。"
            }
            if let line { UIAccessibility.post(notification: .announcement, argument: line) }
        }
    }

    // MARK: 時間軸

    private func start() {
        task = Task { @MainActor in
            await wait(1.6); phase = .ready; Sound.play(.pop); Haptics.soft(0.5)
            // 押さなくても約6.5秒で進む
            await wait(6.5); if !UIAccessibility.isVoiceOverRunning { press() }   // 読み上げ中はボタンを探す時間が要る＝自動で押さない
        }
    }

    private func press() {
        guard phase == .ready, !pressed else { return }
        pressed = true
        task?.cancel()
        Sound.play(.don); Haptics.rigid(0.9)
        task = Task { @MainActor in
            await wait(0.1)
            phase = .burst; Sound.play(.cheerBig); Haptics.confirm(); flash += 1; burstTick += 1
            withAnimation(Theme.Motion.r(.easeOut(duration: 0.8))) { ripple = true }
            await wait(0.9)
            shake += 1; burstTick += 1; Haptics.tick()
            await wait(1.1)
            withAnimation(Theme.Motion.r(.spring(response: 0.25, dampingFraction: 0.6))) { phase = .stamped }
            Sound.play(.taiko); Haptics.rare(); shake += 1
            await wait(2.0)
            phase = .reality; Sound.play(.applauseSmall)   // 振動・光は出さない
            await wait(2.6)
            phase = .bitter; Sound.play(.pop)
        }
    }

    private func wait(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }
}
