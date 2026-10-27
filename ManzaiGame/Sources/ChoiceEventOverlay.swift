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

    private var text: ChoiceEventText { ChoiceEventData.text(for: kind, year: session.year, week: session.week) }
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
        withAnimation(Theme.Motion.r(Theme.Motion.appear)) { proxy.scrollTo(Self.endAnchor, anchor: .bottom) }
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
        withAnimation(Theme.Motion.r(Theme.Motion.appear)) { chosenID = id; afterShown = chunkEnd(text.afterChoice[id] ?? [], from: 0) }
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

// MARK: 場所つきの場面（楽屋・焼肉屋・駅のホーム・ファミレス・事務所）
// ト書きの場所を背景の小物で見せる。墨・生成り・朱＋臙脂/金に寄せる。表示だけ（効果・数値は触らない）。
