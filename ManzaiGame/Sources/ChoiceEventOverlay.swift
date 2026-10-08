// ChoiceEventOverlay.swift
// 選択肢イベントの全画面オーバーレイ（正典: proposals/0024ピース3・見た目は docs/visual_genre_overhaul_v1.md §6 E1）。
// 構成: 上＝題の札＋場面（昼の稽古場／夕景）に二人／下＝読み物（地の文は紙・台詞は顔＋名前札＋吹き出し・▼）＋
//      親指の帯（選択肢カード／閉じる）。セットアップ（タップで1つずつ送る）→ 選択肢 → session.applyEventChoice
//      → 選択後の会話（タップで送る）→ 閉じる。RNG非消費・golden不変（session.applyEventChoiceが呼ぶ
//      runner.applyEventEffects と同じ規律）。UIは swift test で検証不可＝simulator目視まで込みで完了（規律D-10）。

import SwiftUI
import GameCore

extension ChoiceEventKind: @retroactive Identifiable {
    public var id: String { rawValue }
}

struct ChoiceEventOverlay: View {
    @Bindable var session: GameSession
    let kind: ChoiceEventKind
    var onClose: () -> Void

    private var text: ChoiceEventText { ChoiceEventData.text(for: kind) }
    private var scene: EventScene { ChoiceEventData.scene(for: kind) }

    /// セットアップの何行目まで表示済みか。setup.count に達したら選択肢ボタンを出す。
    @State private var setupShown = 1
    /// 選ばれた選択肢ID（nil=まだ選んでいない＝セットアップ表示中）
    @State private var chosenID: String?
    /// 選択後会話の何行目まで表示済みか
    @State private var afterShown = 0
    /// 選択肢・閉じるの出現を最後の行から0.4秒遅らせる（送りの連打が選択に化けない・K5/X3-06）
    @State private var footerReady = false

    /// 読み物の1件（地の文 or 台詞）。古いものは薄く残して読み戻せる。
    private struct Line: Identifiable { let id: Int; let advice: Advice }

    private var lines: [Line] {
        var out = text.setup.prefix(setupShown).enumerated().map { Line(id: $0.offset, advice: $0.element) }
        if let chosenID {
            let after = (text.afterChoice[chosenID] ?? []).prefix(afterShown)
            out += after.enumerated().map { Line(id: 1000 + $0.offset, advice: $0.element) }
        }
        return out
    }
    private var setupDone: Bool { setupShown >= text.setup.count }
    private var afterDone: Bool {
        guard let chosenID else { return false }
        return afterShown >= (text.afterChoice[chosenID]?.count ?? 0)
    }
    /// まだ送れる行が残っているか（▼を出す）
    private var hasMore: Bool { chosenID == nil ? !setupDone : !afterDone }

    var body: some View {
        VStack(spacing: 0) {
            sceneHeader
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(Array(lines.enumerated()), id: \.element.id) { i, line in
                            lineView(line.advice, isLatest: i == lines.count - 1)
                                .opacity(i >= lines.count - 2 ? 1 : 0.55)   // 直近2件以外は薄く（読み戻せる）
                                .id(line.id)
                                .transition(.opacity.combined(with: .offset(y: 8)))
                            if line.id == text.setup.count - 1, let chosenID {
                                chosenTag(text.choiceLabels[chosenID] ?? chosenID)
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 18).padding(.bottom, 12)
                }
                .scrollIndicators(.hidden)
                .onChange(of: lines.count) { _, _ in scrollToLast(proxy) }
                // 選択肢の帯が出ると読み物の欄が縮む＝最後の行が帯の下に隠れないよう、出た後にもう一度送る
                .onChange(of: footerReady) { _, _ in
                    Task {
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        scrollToLast(proxy)
                    }
                }
            }
            footer
        }
        .background(background.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .onAppear {
            Sound.play(.event)   // イベント発生の一音
            armFooterIfNeeded()
        }
    }

    private func scrollToLast(_ proxy: ScrollViewProxy) {
        if let last = lines.last?.id {
            withAnimation(Theme.Motion.appear) { proxy.scrollTo(last, anchor: .bottom) }
        }
    }

    // MARK: 上＝題の札＋場面

    private var sceneHeader: some View {
        EventSceneView(scene: scene)
            .frame(height: 250)
            .overlay(alignment: .top) {
                Text(text.title).font(.maru(.title)).foregroundStyle(Theme.onGold)
                    .padding(.horizontal, 20).padding(.vertical, 7)
                    .background(LinearGradient(colors: [Color(hex: 0xFFF3C8), Theme.gold, Theme.goldD],
                                               startPoint: .top, endPoint: .bottom), in: Capsule())
                    .overlay(Capsule().stroke(.white, lineWidth: 2.5))
                    .shadow(color: Theme.goldD.opacity(0.55), radius: 0, y: 3)
                    .padding(.top, 8)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.line).frame(height: 2.5)   // 場面と読み物の境（週メインの縁と同じ）
            }
            .clipped()
    }

    private var background: some View {
        switch scene {
        case .keiko: return LinearGradient(colors: [Theme.bgTop, Theme.bg2, Theme.bgBottom], startPoint: .top, endPoint: .bottom)
        case .dusk: return LinearGradient(colors: [Color(hex: 0xFCE3CF), Color(hex: 0xF4D2C4)], startPoint: .top, endPoint: .bottom)
        }
    }

    // MARK: 下＝読み物

    @ViewBuilder private func lineView(_ a: Advice, isLatest: Bool) -> some View {
        let cue = isLatest && hasMore
        if a.name == nil {
            NarrationCard(text: a.text, showCue: cue)
        } else {
            TalkBubble(advice: a, showCue: cue)
        }
    }

    /// 選んだ札（選択肢の後に残す・B-10）
    private func chosenTag(_ label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.goldDeep)
            Text(label).font(.maru(.sub)).foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(.white, in: Capsule())
        .overlay(Capsule().stroke(Theme.gold, lineWidth: 2))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 親指の帯

    @ViewBuilder private var footer: some View {
        VStack(spacing: 10) {
            if footerReady {
                if chosenID == nil, setupDone {
                    // 選択肢なしフレーバー（0028等）は会話を送り切ったら「閉じる」、選択肢ありは選択肢カード
                    if session.availableEventChoices().isEmpty {
                        closeButton
                    } else {
                        ForEach(session.availableEventChoices(), id: \.id) { choice in
                            ChoiceCard(label: text.choiceLabels[choice.id] ?? choice.id) { choose(choice.id) }
                        }
                    }
                } else if afterDone {
                    closeButton
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 18)
        .frame(minHeight: 40)
        .animation(Theme.Motion.appear, value: footerReady)
    }

    private var closeButton: some View {
        Button {
            session.dismissChoiceEvent()
            onClose()
        } label: {
            Text("閉じる").font(.maru(.body)).foregroundStyle(Theme.onGold)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Theme.gold, in: RoundedRectangle(cornerRadius: Theme.Rad.btn))
                .shadow(color: Theme.goldD, radius: 0, y: 3)
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: 進行

    private func advance() {
        guard hasMore else { return }
        Sound.play(.cursor)
        withAnimation(Theme.Motion.appear) {
            if chosenID == nil { setupShown += 1 } else { afterShown += 1 }
        }
        armFooterIfNeeded()
    }

    private func choose(_ id: String) {
        session.applyEventChoice(id)
        footerReady = false
        // 選んだ瞬間に返事の1行目を出す（0 だと区切りの下が空のまま＝壊れて見えた・audit_intro_event B-01）
        withAnimation(Theme.Motion.appear) { chosenID = id; afterShown = min(1, text.afterChoice[id]?.count ?? 0) }
        armFooterIfNeeded()
    }

    /// 送り切ったら0.4秒置いて帯（選択肢／閉じる）を出す
    private func armFooterIfNeeded() {
        guard !hasMore, !footerReady else { return }
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            footerReady = true
        }
    }
}

// MARK: 場面（昼の稽古場／夕景）

struct EventSceneView: View {
    let scene: EventScene
    var body: some View {
        switch scene {
        case .keiko:
            StageScene().ignoresSafeArea(edges: .top)
        case .dusk:
            DuskScene().ignoresSafeArea(edges: .top)
        }
    }
}

/// 夕景の場面: 橙→宵の明るい暖色（黒にしない）＋窓の光＋板の床＋色付きの二人（夜の日常・§4-1）。
struct DuskScene: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let horizon = h * 0.62
            let figH = max(130, h * 0.46)
            ZStack {
                LinearGradient(colors: Theme.duskEve, startPoint: .top, endPoint: .bottom)
                // 窓の光（3枚）
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 5)
                            .fill(LinearGradient(colors: [Color(hex: 0xFFE9C2), Color(hex: 0xF6C38E)], startPoint: .top, endPoint: .bottom))
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(hex: 0xC97A6A).opacity(0.5), lineWidth: 4))
                    }
                }
                .frame(width: w * 0.62, height: h * 0.34)
                .position(x: w * 0.36, y: h * 0.30)
                // 床
                LinearGradient(colors: [Color(hex: 0xC98E6E), Color(hex: 0xA8705A)], startPoint: .top, endPoint: .bottom)
                    .frame(height: h - horizon)
                    .position(x: w / 2, y: horizon + (h - horizon) / 2)
                // 二人（色付き・夕方の光で少し温める）
                ManzaiFigure(height: figH * 0.9, tilt: 2.2, accent: Color(hex: 0x2E55B0), breathe: 3.1,
                             bodyColors: [Color(hex: 0x4A7BE8), Color(hex: 0x2E55B0)],
                             headColor: Color(hex: 0xFFDFC2), hairColor: Color(hex: 0x40394F))
                    .position(x: w * 0.40, y: h - h * 0.06 - figH * 0.45)
                ManzaiFigure(height: figH, tilt: -2.6, accent: Color(hex: 0xB02318), breathe: 2.4,
                             bodyColors: [Color(hex: 0xF0533E), Color(hex: 0xC22E1D)],
                             headColor: Color(hex: 0xFFDFC2), hairColor: Color(hex: 0x2E2838))
                    .position(x: w * 0.66, y: h - h * 0.06 - figH * 0.50)
                // 夕方の色かぶり
                LinearGradient(colors: [Color(hex: 0xFFB27A).opacity(0.18), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .allowsHitTesting(false)
            }
        }
    }
}
