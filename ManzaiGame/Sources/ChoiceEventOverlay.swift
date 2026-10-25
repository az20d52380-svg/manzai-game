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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var text: ChoiceEventText { ChoiceEventData.text(for: kind) }
    private var scene: EventScene { ChoiceEventData.scene(for: kind) }
    private var backdrop: EventBackdrop { EventBackdrop.forEvent(kind) }

    /// セットアップの何行目まで表示済みか。setup.count に達したら選択肢ボタンを出す。
    @State private var setupShown = 1
    /// 選ばれた選択肢ID（nil=まだ選んでいない＝セットアップ表示中）
    @State private var chosenID: String?
    /// 選択後会話の何行目まで表示済みか
    @State private var afterShown = 0
    /// 選択肢・閉じるの出現を最後の行から0.4秒遅らせる（送りの連打が選択に化けない・K5/X3-06）
    @State private var footerReady = false
    /// 選んだ結果の効果チップ（方向だけ・数字なし＝選択肢イベント規約「効果は方向だけ」と揃える・E2）。閉じるまで残す
    @State private var effectChips: [EffectChip] = []

    private struct EffectChip: Identifiable { let id: Int; let text: String; let up: Bool; let color: Color }

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
    /// 効果の無い会話だけの出来事（選択肢なしフレーバー）＝台詞を全部1枚に並べ、1回のタップで閉じる
    private var isFlavor: Bool { session.availableEventChoices().isEmpty }
    /// 1タップで出す行数のまとめ方：shown 行目の続きから最大3行・合計約80字まで（少なくとも1行）。
    /// 台詞の中身・順序・選択肢の出る位置（setup 末尾）は変えず、見せる粒度だけ粗くする。
    private func chunkEnd(_ items: [Advice], from shown: Int) -> Int {
        guard shown < items.count else { return items.count }
        var end = shown + 1, chars = items[shown].text.count
        while end < items.count, end - shown < 3, chars + items[end].text.count <= 80 {
            chars += items[end].text.count; end += 1
        }
        return end
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
            YoseHeaderBar(title: text.title, subtitle: "\(session.year)年目　第\(session.week)週 ・ 日常イベント")
            sceneHeader
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(Array(lines.enumerated()), id: \.element.id) { i, line in
                            lineView(line.advice, isLatest: i == lines.count - 1)
                                .opacity(i >= lines.count - 3 || isFlavor ? 1 : 0.72)   // 直近2件以外は薄く（読み戻せる）
                                .id(line.id)
                                .transition(.opacity.combined(with: .offset(y: 8)))
                            if line.id == text.setup.count - 1, let chosenID {
                                chosenTag(text.choiceLabels[chosenID] ?? chosenID)
                            }
                        }
                        Color.clear.frame(height: 0).id(Self.endAnchor)   // 送り先＝最後の行の下に余白を残す（行に合わせると選択肢の札と詰まる）
                    }
                    .padding(.horizontal, YoseMetrics.screenMargin).padding(.top, 14).padding(.bottom, 12)
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
            // 体力・知名度・所持金の黒帯（選んだ結果がどこに効くかの基準を常に見せる）
            YoseVitalMoneyBar(stamina: Int(session.state.stamina.rounded()), maxStamina: 100, money: session.state.money,
                              fame: Int(session.state.fame.rounded()))
                .background(YoseColor.kuroUrushi.ignoresSafeArea(edges: .bottom))
        }
        .background(YoseColor.kinari.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .onAppear {
            Sound.play(.event)   // イベント発生の一音
            setupShown = chunkEnd(text.setup, from: 0)   // 最初の場面もまとめて出す
            if isFlavor { setupShown = text.setup.count }   // 選択肢なし＝全部並べる
            #if DEBUG
            // 目視フック: MZ_EVSTEP=99 で地の文を送り切る／MZ_EVPICK=1 で最初の選択肢を選んで返事まで送り切る
            if ProcessInfo.processInfo.environment["MZ_EVSTEP"] != nil { setupShown = text.setup.count }
            if ProcessInfo.processInfo.environment["MZ_EVPICK"] != nil, let c = session.availableEventChoices().first {
                choose(c.id); afterShown = text.afterChoice[c.id]?.count ?? 0
            }
            #endif
            armFooterIfNeeded()
        }
    }

    /// 場面の絵の高さ。選択肢の帯が出る間は読み物の欄を広げる（地の文が5行・6行以上なら段階的に縮めて、最初のト書きが絵の下に半分隠れないように）。
    /// 文字を大きくした設定では行が増えるので、さらに絵を縮めて本文の欄を広げる（dynamic_type_audit_1019 M1）
    private var backdropHeight: CGFloat {
        var h: CGFloat = footerReady && !session.availableEventChoices().isEmpty ? (text.setup.count >= 6 ? 196 : text.setup.count >= 5 ? 216 : 262) : 320
        if dynamicTypeSize.isAccessibilitySize { h = min(h, 130) } else if dynamicTypeSize >= .xxLarge { h = min(h, 170) }
        return h
    }

    private static let endAnchor = "eventLinesEnd"

    private func scrollToLast(_ proxy: ScrollViewProxy) {
        guard !lines.isEmpty else { return }
        withAnimation(Theme.Motion.appear) { proxy.scrollTo(Self.endAnchor, anchor: .bottom) }
    }

    // MARK: 上＝題の札＋場面

    private var sceneHeader: some View {
        EventStageBackdropView(backdrop: backdrop)
            .frame(height: backdropHeight)
            .animation(Theme.Motion.appear, value: footerReady)
            .overlay(alignment: .topLeading) {
                // 場所・時間帯の木札（背景が何色でも読める）
                HStack(spacing: 6) {
                    Text(backdrop.place.label).font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                    Rectangle().fill(YoseColor.sumi).frame(width: 1, height: 10)
                    Text(backdrop.time.label).font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.enji)
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .yoseKifuda()
                .padding(.top, 10).padding(.leading, 14)
                .allowsHitTesting(false)
            }
            .overlay(alignment: .topTrailing) {
                // 選んだ結果＝二人の頭上に効果チップ（伸び＝濃い色の塗り／減り＝白地で祝わない）
                VStack(alignment: .trailing, spacing: 6) {
                    ForEach(Array(effectChips.enumerated()), id: \.element.id) { i, c in
                        eventChip(c)
                            .transition(.scale(scale: 0.6, anchor: .bottomTrailing).combined(with: .opacity))
                            .animation(Theme.Motion.emphSpring.delay(Double(i) * 0.08), value: effectChips.count)
                    }
                }
                .padding(.top, 12).padding(.trailing, 14)
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomTrailing) {
                // 調子のいい日の朱印（選んだ結果のチップが出たら譲る）
                if kind == .luckyThirdLine, effectChips.isEmpty {
                    YoseHankoStamp(text: "好調", isSquare: true, angle: -8)
                        .padding(.bottom, 16).padding(.trailing, 16).allowsHitTesting(false)
                }
            }
            .overlay { moodOverlay.allowsHitTesting(false) }
            .overlay(alignment: .bottom) {
                VStack(spacing: 0) {   // 場面と読み物の境（二重線）
                    Rectangle().fill(YoseColor.kin).frame(height: 1.5)
                    Rectangle().fill(YoseColor.sumi).frame(height: 2)
                }
            }
            .clipped()
    }

    /// 出来事の空気（表示だけ）。哀しい日は周辺を落とし、調子のいい日は上から明るい光を差す
    @ViewBuilder private var moodOverlay: some View {
        switch kind {
        case .peerFoldedChair:
            RadialGradient(colors: [.clear, YoseColor.kuroUrushi.opacity(0.32)], center: .center, startRadius: 60, endRadius: 260)
        case .luckyThirdLine:
            LinearGradient(colors: [YoseColor.kinBright.opacity(0.22), .clear], startPoint: .top, endPoint: .bottom)
        default:
            EmptyView()
        }
    }

    /// 効果チップ（方向だけ）。伸び＝濃色の角札／減り＝和紙の角札。丸カプセルは使わない
    private func eventChip(_ c: EffectChip) -> some View {
        Text(c.text).font(YoseFont.gothic(15, weight: .heavy))
            .foregroundStyle(c.up ? YoseColor.kinari : YoseColor.sumi)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(c.up ? YoseColor.enji : YoseColor.washi)
            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
            .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))
            .fixedSize()
            .accessibilityLabel(c.text.replacingOccurrences(of: " ↑", with: "が上がった").replacingOccurrences(of: " ↓", with: "が下がった"))
    }

    // MARK: 下＝読み物

    @ViewBuilder private func lineView(_ a: Advice, isLatest: Bool) -> some View {
        let cue = isLatest && hasMore
        if a.name == nil {
            HStack(alignment: .bottom, spacing: 6) {
                Text(a.text).font(YoseFont.mincho(15)).lineSpacing(6).foregroundStyle(YoseColor.sumi)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if cue { AdvanceCue(color: YoseColor.shu) }
            }
            .padding(.leading, 20).padding(.trailing, 12).padding(.vertical, 12)
            .frame(minHeight: 72, alignment: .leading)
            // ト書き板：木札色の薄い地・墨の枠・左端に隙間なしの臙脂の帯（台詞の吹き出しと形で区別）
            .background(YoseColor.ki.opacity(0.45))
            .overlay(alignment: .leading) { Rectangle().fill(YoseColor.enji).frame(width: 6) }
            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
        } else {
            YoseSpeechBox(speaker: a.name ?? "俺", text: a.text, showCue: cue)
        }
    }

    /// 選んだ札（選択肢の後に残す・B-10）
    private func chosenTag(_ label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark").font(.system(size: Font.mzScaled(12), weight: .black)).foregroundStyle(YoseColor.shu).accessibilityHidden(true)
            Text(label).font(YoseFont.gothic(14, weight: .heavy)).foregroundStyle(YoseColor.sumi)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .yoseKifuda()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 親指の帯

    @ViewBuilder private var footer: some View {
        VStack(spacing: 10) {
            if hasMore {
                // タップで進むことを示す（下半分が空いて「選択肢が消えた」と迷わない）
                // 押せる木札（画面のどこをタップしても進む＝この札は同じ動作・進み方は変えない）
                Button { advance() } label: {
                    Text("次へ 進む ▶").frame(maxWidth: .infinity)
                }
                .buttonStyle(YoseButtonStyle(.primary))
            }
            if footerReady {
                if chosenID == nil, setupDone {
                    // 選択肢なしフレーバー（0028等）は会話を送り切ったら「閉じる」、選択肢ありは選択肢カード
                    if session.availableEventChoices().isEmpty {
                        closeButton
                    } else {
                        ForEach(session.availableEventChoices(), id: \.id) { choice in
                            Button { choose(choice.id) } label: {
                                Text(text.choiceLabels[choice.id] ?? choice.id)
                                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                            }
                            .buttonStyle(YoseButtonStyle(.secondary))
                        }
                    }
                } else if afterDone {
                    closeButton
                }
            }
        }
        .padding(.horizontal, YoseMetrics.screenMargin).padding(.top, 14).padding(.bottom, 14)   // 上 6→14：会話5行の札で最後の吹き出しと選択肢がくっつかない（event_card_audit_1019 §1）
        .frame(minHeight: 40)
        .animation(Theme.Motion.appear, value: footerReady)
    }

    private var closeButton: some View {
        Button {
            session.dismissChoiceEvent()
            onClose()
        } label: { Text("とじる") }
        .buttonStyle(YoseButtonStyle(.primary))
    }

    // MARK: 進行

    private func advance() {
        if isFlavor && footerReady && !hasMore && chosenID == nil {   // 並べた1枚は、1回のタップで閉じる
            session.dismissChoiceEvent(); onClose(); return
        }
        guard hasMore else { return }
        Sound.play(.cursor)
        withAnimation(Theme.Motion.appear) {
            if chosenID == nil { setupShown = chunkEnd(text.setup, from: setupShown) }
            else { afterShown = chunkEnd(text.afterChoice[chosenID ?? ""] ?? [], from: afterShown) }
        }
        armFooterIfNeeded()
    }

    private func choose(_ id: String) {
        let before = session.state
        session.applyEventChoice(id)
        showEffects(before: before, after: session.state, choice: id)
        footerReady = false
        // 選んだ瞬間に返事の1行目を出す（0 だと区切りの下が空のまま＝壊れて見えた・audit_intro_event B-01）
        withAnimation(Theme.Motion.appear) { chosenID = id; afterShown = chunkEnd(text.afterChoice[id] ?? [], from: 0) }
        armFooterIfNeeded()
    }

    /// 選択の前後の差から効果チップを組む（表示専用・RNG非消費）。伸びを先に、最大3枚。
    private func showEffects(before b: GameState, after a: GameState, choice: String) {
        var ups: [(String, Color)] = [], downs: [(String, Color)] = []
        func add(_ name: String, _ d: Double, _ c: Color) {
            if d > 0.001 { ups.append(("\(name) ↑", c)) } else if d < -0.001 { downs.append(("\(name) ↓", c)) }
        }
        for ab in Ability.allCases { add("\(ab)", a[ab] - b[ab], Theme.abilityDeep(ab)) }
        add("相性", a.compat - b.compat, Theme.vermD)
        add("知名度", a.fame - b.fame, Theme.goldDeep)
        add("体力", a.stamina - b.stamina, Theme.mentalDeep)
        add("所持金", Double(a.money - b.money), Theme.moneyDeep)
        var all = Array((ups.map { ($0.0, true, $0.1) } + downs.map { ($0.0, false, $0.1) }).prefix(3))
        // 数字に出ない効果（来週の効き・余力・拘束・空気）は一言の札で添える（効果自体は不変・数字なし）
        if let note = ChoiceEventData.hiddenEffectNote(for: kind, choice: choice) { all.append((note, false, Theme.mentalDeep)) }
        guard !all.isEmpty else { return }
        Sound.play(ups.isEmpty ? .pop : .grain)
        withAnimation(Theme.Motion.emphSpring) {
            effectChips = all.enumerated().map { EffectChip(id: $0.offset, text: $0.element.0, up: $0.element.1, color: $0.element.2) }
        }
        // 頭上のチップは押せない overlay＝VoiceOver では気づけない。札と同じ言い方で読み上げる（a11y_check_1026 中3）
        UIAccessibility.post(notification: .announcement, argument: all.map {
            $0.0.replacingOccurrences(of: " ↑", with: "が上がった").replacingOccurrences(of: " ↓", with: "が下がった")
        }.joined(separator: "、"))
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
        case .gakuya, .yakiniku, .station, .famires, .office:
            PlaceScene(scene: scene).ignoresSafeArea(edges: .top)
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
                ManzaiFigure(height: figH * 0.9, tilt: 2.2, breathe: 3.1, colors: StageOutfit.standard.ore(rival: false))
                    .position(x: w * 0.40, y: h - h * 0.06 - figH * 0.45)
                ManzaiFigure(height: figH, tilt: -2.6, breathe: 2.4, colors: StageOutfit.standard.taniguchi(rival: false))
                    .position(x: w * 0.66, y: h - h * 0.06 - figH * 0.50)
                // 夕方の色かぶり
                LinearGradient(colors: [Color(hex: 0xFFB27A).opacity(0.18), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: 場所つきの場面（楽屋・焼肉屋・駅のホーム・ファミレス・事務所）
// ト書きの場所を背景の小物で見せる。墨・生成り・朱＋臙脂/金に寄せる。表示だけ（効果・数値は触らない）。

struct PlaceScene: View {
    let scene: EventScene

    private var wall: [Color] {
        switch scene {
        case .gakuya:   return [Color(hex: 0xFFF6E4), Color(hex: 0xF3E1C4)]
        case .yakiniku: return [Color(hex: 0x5A3A30), Color(hex: 0x3A2622)]
        case .station:  return [Color(hex: 0xE4E0D8), Color(hex: 0xB9B4B0)]
        case .famires:  return [Color(hex: 0x4A3A44), Color(hex: 0x2F2630)]
        default:        return [Color(hex: 0xFFF6E4), Color(hex: 0xF0DFC0)]
        }
    }
    private var floor: [Color] {
        switch scene {
        case .gakuya:   return [Color(hex: 0xB98B5E), Color(hex: 0x8F6642)]
        case .yakiniku: return [Color(hex: 0x6B4A3A), Color(hex: 0x4A3028)]
        case .station:  return [Color(hex: 0x8C8A8E), Color(hex: 0x6A686E)]
        case .famires:  return [Color(hex: 0x6A4A44), Color(hex: 0x472F30)]
        default:        return [Color(hex: 0xC8B8A0), Color(hex: 0xA8967C)]
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let horizon = h * 0.62
            let figH = max(130, h * 0.42)
            ZStack {
                LinearGradient(colors: wall, startPoint: .top, endPoint: .bottom)
                LinearGradient(colors: floor, startPoint: .top, endPoint: .bottom)
                    .frame(height: h - horizon)
                    .position(x: w / 2, y: horizon + (h - horizon) / 2)
                props(w: w, h: h, horizon: horizon)
                ManzaiFigure(height: figH * 0.9, tilt: 2.2, breathe: 3.1, colors: StageOutfit.standard.ore(rival: false))
                    .position(x: w * 0.40, y: h - h * 0.07 - figH * 0.45)
                ManzaiFigure(height: figH, tilt: -2.6, breathe: 2.4, colors: StageOutfit.standard.taniguchi(rival: false))
                    .position(x: w * 0.66, y: h - h * 0.07 - figH * 0.50)
                foreground(w: w, h: h)
            }
            .clipped()
        }
    }

    @ViewBuilder private func props(w: CGFloat, h: CGFloat, horizon: CGFloat) -> some View {
        switch scene {
        case .gakuya:
            // 楽屋: 電球つきの大きな鏡＋衣装掛け
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0xD9E6EA))
                    .overlay(LinearGradient(colors: [.white.opacity(0.55), .clear], startPoint: .topLeading, endPoint: .center))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.goldLeafMid, lineWidth: 5))
                HStack(spacing: 0) {
                    ForEach(0..<6, id: \.self) { _ in
                        Circle().fill(Color(hex: 0xFFE9A0)).frame(width: 9, height: 9)
                            .shadow(color: Theme.gold.opacity(0.8), radius: 4)
                            .frame(maxWidth: .infinity)
                    }
                }.frame(maxHeight: .infinity, alignment: .top).padding(.top, -5)
            }
            .frame(width: w * 0.46, height: h * 0.40)
            .position(x: w * 0.40, y: h * 0.33)
            ZStack {
                Rectangle().fill(Theme.ink.opacity(0.7)).frame(width: w * 0.20, height: 3).offset(y: -h * 0.12)
                Rectangle().fill(Theme.ink.opacity(0.7)).frame(width: 3, height: h * 0.34).offset(x: -w * 0.10)
                Rectangle().fill(Theme.ink.opacity(0.7)).frame(width: 3, height: h * 0.34).offset(x: w * 0.10)
                HStack(spacing: 6) {
                    ForEach([Theme.verm, Color(hex: 0x8E2A34), Theme.gold], id: \.self) { c in
                        RoundedRectangle(cornerRadius: 3).fill(c).frame(width: w * 0.050, height: h * 0.17)
                    }
                }.offset(y: -h * 0.03)
            }
            .position(x: w * 0.84, y: h * 0.44)
        case .yakiniku:
            // 焼肉屋: 提灯＋のれん
            ForEach(0..<3, id: \.self) { i in
                VStack(spacing: 0) {
                    Rectangle().fill(Color.black.opacity(0.6)).frame(width: 2, height: h * 0.05)
                    Ellipse().fill(LinearGradient(colors: [Theme.verm, Color(hex: 0x9E2418)], startPoint: .top, endPoint: .bottom))
                        .frame(width: w * 0.10, height: h * 0.15)
                        .overlay(Rectangle().fill(Theme.gold.opacity(0.9)).frame(height: 2).offset(y: -h * 0.045))
                        .overlay(Rectangle().fill(Theme.gold.opacity(0.9)).frame(height: 2).offset(y: h * 0.045))
                }
                .position(x: w * (0.18 + 0.32 * CGFloat(i)), y: h * 0.14)
            }
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { i in
                    Rectangle().fill(i % 2 == 0 ? Color(hex: 0x8E2A34) : Color(hex: 0xF3E6CC))
                        .frame(height: h * 0.20)
                }
            }
            .frame(width: w * 0.62).position(x: w * 0.5, y: h * 0.42)
            .opacity(0.9)
        case .station:
            // 駅のホーム: 駅名標＋柱＋黄色い点字ブロックの線
            Rectangle().fill(Color(hex: 0x6E6A70)).frame(width: w * 0.06, height: horizon)
                .position(x: w * 0.12, y: horizon / 2)
            Rectangle().fill(Color(hex: 0x6E6A70)).frame(width: w * 0.06, height: horizon)
                .position(x: w * 0.90, y: horizon / 2)
            VStack(spacing: 2) {
                Text("えき").font(.system(size: Font.mzScaled(20), weight: .black)).foregroundStyle(Theme.ink)
                Rectangle().fill(Theme.verm).frame(width: 64, height: 4)
            }
            .padding(.horizontal, 18).padding(.vertical, 6)
            .background(Color(hex: 0xFFF8EA), in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.ink.opacity(0.6), lineWidth: 2))
            .position(x: w * 0.5, y: h * 0.40)
            Rectangle().fill(Color(hex: 0xE6B422)).frame(height: 7)
                .position(x: w / 2, y: horizon + (h - horizon) * 0.78)
            Rectangle().fill(Theme.ink.opacity(0.55)).frame(height: h * 0.05)
                .position(x: w / 2, y: horizon - h * 0.025)
        case .famires:
            // ファミレス: 夜の窓＋吊りランプ＋ボックス席の背もたれ
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(colors: [Color(hex: 0x1F2A4A), Color(hex: 0x3B3A66)], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: 0xE8D9B8), lineWidth: 4))
                .overlay(Rectangle().fill(Color(hex: 0xE8D9B8)).frame(width: 4))
                .frame(width: w * 0.60, height: h * 0.24).position(x: w * 0.5, y: h * 0.42)
            ForEach(0..<3, id: \.self) { i in
                VStack(spacing: 0) {
                    Rectangle().fill(Color.black.opacity(0.6)).frame(width: 2, height: h * 0.05)
                    Path { p in
                        p.move(to: CGPoint(x: 4, y: 0)); p.addLine(to: CGPoint(x: 24, y: 0))
                        p.addLine(to: CGPoint(x: 30, y: 14)); p.addLine(to: CGPoint(x: -2, y: 14)); p.closeSubpath()
                    }.fill(Theme.gold).frame(width: 28, height: 14)
                        .shadow(color: Theme.gold.opacity(0.7), radius: 8, y: 6)
                }.position(x: w * (0.22 + 0.28 * CGFloat(i)), y: h * 0.05)
            }
            RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0x8E2A34))
                .frame(width: w * 0.92, height: h * 0.20).position(x: w * 0.5, y: horizon - h * 0.02)
        default:
            // 事務所: ブラインドの窓＋予定表
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0xCFE3EE))
                VStack(spacing: 5) {
                    ForEach(0..<7, id: \.self) { _ in Rectangle().fill(Color(hex: 0xF3E6CC)).frame(height: 5) }
                }.padding(.top, 6).frame(maxHeight: .infinity, alignment: .top)
                RoundedRectangle(cornerRadius: 3).stroke(Theme.ink.opacity(0.6), lineWidth: 3)
            }.frame(width: w * 0.30, height: h * 0.36).position(x: w * 0.22, y: h * 0.32)
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0xF3E6CC))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.ink.opacity(0.6), lineWidth: 3))
                VStack(spacing: h * 0.045) {
                    ForEach(0..<3, id: \.self) { r in
                        HStack(spacing: 4) {
                            ForEach([Theme.verm, Theme.ink, Color(hex: 0x8E2A34), Theme.gold], id: \.self) { c in
                                RoundedRectangle(cornerRadius: 1.5).fill(c.opacity(r == 1 ? 0.55 : 0.85)).frame(width: w * 0.038, height: h * 0.06)
                            }
                        }
                    }
                }
            }.frame(width: w * 0.30, height: h * 0.40).position(x: w * 0.80, y: h * 0.31)
        }
    }

    /// 人物より手前の小物（焼肉の網つきテーブル／事務所の机）
    @ViewBuilder private func foreground(w: CGFloat, h: CGFloat) -> some View {
        switch scene {
        case .yakiniku:
            ZStack {
                Rectangle().fill(Color(hex: 0x2A1C18)).frame(width: w, height: h * 0.12)
                Ellipse().fill(Color(hex: 0x1E1614)).frame(width: w * 0.30, height: h * 0.07)
                    .overlay(Ellipse().fill(RadialGradient(colors: [Color(hex: 0xFFB24A), Theme.verm.opacity(0.7), .clear], center: .center, startRadius: 1, endRadius: w * 0.12)).frame(width: w * 0.24, height: h * 0.05))
                    .overlay(HStack(spacing: 6) { ForEach(0..<8, id: \.self) { _ in Rectangle().fill(Color.black.opacity(0.7)).frame(width: 1.5) } }.frame(width: w * 0.26, height: h * 0.05))
                    .offset(x: -w * 0.18, y: -h * 0.005)
            }.position(x: w / 2, y: h * 0.94)
        case .office:
            RoundedRectangle(cornerRadius: 4).fill(LinearGradient(colors: [Color(hex: 0xA8764A), Color(hex: 0x7C5232)], startPoint: .top, endPoint: .bottom))
                .frame(width: w * 0.56, height: h * 0.10)
                .overlay(alignment: .top) {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 2).fill(Theme.ink.opacity(0.85)).frame(width: w * 0.10, height: h * 0.05)
                        RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0xF3E6CC)).frame(width: w * 0.07, height: h * 0.022)
                    }.offset(y: -h * 0.04)
                }
                .position(x: w * 0.5, y: h * 0.95)
        default:
            EmptyView()
        }
    }
}
