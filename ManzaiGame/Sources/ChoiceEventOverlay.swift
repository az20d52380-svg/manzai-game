// ChoiceEventOverlay.swift
// 選択肢イベントの全画面オーバーレイ（正典: proposals/0024ピース3）。
// 構成: セットアップ地の文＋導入会話（タップで1つずつ送る）→ 2-3択ボタン → session.applyEventChoice
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

    /// セットアップの何行目まで表示済みか。setup.count に達したら選択肢ボタンを出す。
    @State private var setupShown = 1
    /// 選ばれた選択肢ID（nil=まだ選んでいない＝セットアップ表示中）
    @State private var chosenID: String?
    /// 選択後会話の何行目まで表示済みか
    @State private var afterShown = 0
    // --- 入場カットイン（暗転→タイトル判→会話・パワプロのイベントカットインの文法） ---
    /// 0=暗転 1=タイトル判 2=会話（既存フロー解禁）。カットイン中のタップは cutinTask.cancel()＝即スキップ。
    @State private var cutinStage = 0
    @State private var cutinTask: Task<Void, Never>?
    @State private var slamFire = 0
    // --- 選択結果の効果ポップ（before/after の状態差分＝表示が嘘をつかない・RNG非消費） ---
    @State private var effectChips: [BurstChip] = []
    @State private var chipsVisible = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x241C33), Color(hex: 0x2F2540)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 18) {
                Text(text.title).font(.maru(12)).tracking(2).foregroundStyle(Theme.gold)
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(text.setup.prefix(setupShown).enumerated()), id: \.offset) { _, line in
                            adviceLine(line)
                        }
                        if let chosenID {
                            Divider().overlay(Theme.gold.opacity(0.3)).padding(.vertical, 4)
                            ForEach(Array((text.afterChoice[chosenID] ?? []).prefix(afterShown).enumerated()), id: \.offset) { _, line in
                                adviceLine(line)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                if chosenID != nil, !effectChips.isEmpty {
                    effectChipsRow   // 選んだ結果の効果（会話の下・閉じるの上）
                }
                if chosenID == nil, setupShown >= text.setup.count {
                    // 選択肢なしフレーバー（0028等）は会話を送り切ったら「閉じる」、選択肢ありは選択肢ボタン
                    if session.availableEventChoices().isEmpty {
                        closeButton
                    } else {
                        choiceButtons
                    }
                }
                if let chosenID, afterShown >= (text.afterChoice[chosenID]?.count ?? 0) {
                    closeButton
                } else if setupShown < text.setup.count || (chosenID != nil && afterShown < (text.afterChoice[chosenID!]?.count ?? 0)) {
                    Text("タップで進む").font(.maru(10)).foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.vertical, 34)
            .opacity(cutinStage >= 2 ? 1 : 0)   // カットインが引けてから会話が入る

            if cutinStage < 2 {
                cutinOverlay.transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if cutinStage < 2 { cutinTask?.cancel() }   // カットイン中のタップ＝即スキップ（残りの間が即返る）
            else { advance() }
        }
        .onAppear {
            cutinTask = Task {
                try? await Task.sleep(nanoseconds: 250_000_000)   // 暗転の溜め
                withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) { cutinStage = 1 }   // 判の叩きつけ
                slamFire += 1
                Haptics.confirm()
                try? await Task.sleep(nanoseconds: 800_000_000)
                withAnimation(Theme.Motion.appear) { cutinStage = 2 }   // 会話へ
            }
        }
    }

    // MARK: 入場カットイン（暗転→朱帯が走る→タイトル判・TournamentResultView.stamp の文法）

    private var cutinOverlay: some View {
        ZStack {
            Color(hex: 0x14121C).ignoresSafeArea()
            VStack(spacing: 16) {
                cutinBand(fromLeading: true)
                Text(text.title)
                    .font(.maru(20)).tracking(4).foregroundStyle(.white)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(Theme.verm, in: RoundedRectangle(cornerRadius: Theme.Rad.stamp))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Rad.stamp)
                        .stroke(.white.opacity(0.55), lineWidth: 2).padding(4))
                    .rotationEffect(.degrees(-3))
                    .scaleEffect(cutinStage >= 1 ? 1 : 1.8)
                    .opacity(cutinStage >= 1 ? 1 : 0)
                cutinBand(fromLeading: false)
            }
        }
        .screenShake(trigger: slamFire, intensity: 7)
    }

    private func cutinBand(fromLeading: Bool) -> some View {
        Rectangle().fill(Theme.verm.opacity(0.85)).frame(height: 3)
            .padding(.horizontal, 44)
            .offset(x: cutinStage >= 1 ? 0 : (fromLeading ? -430 : 430))
            .opacity(cutinStage >= 1 ? 1 : 0)
    }

    // MARK: 効果ポップ（数値は状態差分・持続効果は「方向」の言葉チップ＝数字で刺さない）

    private var effectChipsRow: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 6)], spacing: 6) {
            ForEach(Array(effectChips.enumerated()), id: \.element.id) { i, chip in
                BurstChipView(chip: chip, style: .compact)
                    .opacity(chipsVisible ? 1 : 0)
                    .offset(y: chipsVisible ? 0 : 10)
                    .animation(Theme.Motion.emphSpring.delay(Double(i) * 0.07), value: chipsVisible)
            }
        }
        .padding(.horizontal, 30)
    }

    /// 選択の効果チップを組む（純表示・RNG非消費）。数値効果は before/after 差分（clamp後の実効値＝嘘をつかない）、
    /// 持続効果（凍結/ブースト/拘束/器）は言葉チップ【仮】＝「効果は方向だけ言葉に」の規約（manzai-choice-events）。
    private func makeEffectChips(before: GameState, after: GameState, effects: [EventEffect]) -> [BurstChip] {
        var chips: [BurstChip] = []
        var id = 0
        func add(_ text: String, fg: Color, bg: Color) {
            chips.append(BurstChip(id: id, text: text, fg: fg, bg: bg)); id += 1
        }
        for a in Ability.allCases {
            let d = Int((after[a] - before[a]).rounded())
            guard d != 0 else { continue }
            add("\(a) \(d > 0 ? "+" : "")\(d)",
                fg: d > 0 ? .white : Theme.inkDim, bg: d > 0 ? Theme.abilityColor(a) : Theme.card2)
        }
        let cd = Int((after.compat - before.compat).rounded())
        if cd != 0 {
            add("相性 \(cd > 0 ? "+" : "")\(cd)", fg: cd > 0 ? .white : Theme.inkDim,
                bg: cd > 0 ? Theme.cCompat : Theme.card2)
        }
        let sd = Int(after.stamina.rounded()) - Int(before.stamina.rounded())
        if sd != 0 {
            add("体力 \(sd > 0 ? "+" : "")\(sd)", fg: sd > 0 ? .white : Theme.inkDim,
                bg: sd > 0 ? Theme.cMental : Theme.card2)
        }
        let fd = Int(after.fame.rounded()) - Int(before.fame.rounded())
        if fd != 0 {
            add("知名度 \(fd > 0 ? "+" : "")\(fd)", fg: fd > 0 ? .white : Theme.inkDim,
                bg: fd > 0 ? Theme.cChara : Theme.card2)
        }
        let md = after.money - before.money
        if md != 0 {
            let man = Double(abs(md)) / 10000
            let txt = man == man.rounded() ? String(Int(man)) : String(format: "%.1f", man)
            add("\(md > 0 ? "+" : "-")¥\(txt)万", fg: md > 0 ? .white : Theme.verm,
                bg: md > 0 ? Theme.cMoney : Theme.verm.opacity(0.14))
        }
        for e in effects {
            switch e {
            case .compatFreeze:      add("相性は、しばらく動かない", fg: Theme.inkDim, bg: Theme.card2)
            case .netaBoostNextWeek: add("次の合わせが効く", fg: Theme.goldD, bg: Color(hex: 0xFFF3D6))
            case .preoccupyNextWeek: add("今週は撮影で埋まる", fg: Theme.inkDim, bg: Theme.card2)
            case .growthCeiling(let d):
                add(d < 0 ? "今年の器が縮む" : "今年の器が広がる", fg: Theme.inkDim, bg: Theme.card2)
            default: break
            }
        }
        return chips
    }

    private func adviceLine(_ a: Advice) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if let name = a.name {
                Text(name).font(.maru(10)).tracking(1).foregroundStyle(Theme.gold.opacity(0.8))
                Text(a.text).font(.system(size: 14, design: .serif)).foregroundStyle(.white.opacity(0.92))
            } else {
                Text(a.text).font(.system(size: 13, design: .serif)).foregroundStyle(.white.opacity(0.75)).lineSpacing(4)
            }
        }
    }

    private func advance() {
        if chosenID == nil {
            if setupShown < text.setup.count { setupShown += 1 }
        } else if let id = chosenID, afterShown < (text.afterChoice[id]?.count ?? 0) {
            afterShown += 1
        }
    }

    private var closeButton: some View {
        Button {
            session.dismissChoiceEvent()
            onClose()
        } label: {
            Text("閉じる").font(.maru(14)).foregroundStyle(Color(hex: 0x5A3A06))
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(Theme.gold, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain).padding(.horizontal, 30)
    }

    private var choiceButtons: some View {
        VStack(spacing: 10) {
            ForEach(session.availableEventChoices(), id: \.id) { choice in
                Button {
                    let before = session.state
                    session.applyEventChoice(choice.id)
                    effectChips = makeEffectChips(before: before, after: session.state, effects: choice.effects)
                    withAnimation(Theme.Motion.appear) { chosenID = choice.id; afterShown = 0 }
                    chipsVisible = false
                    withAnimation(Theme.Motion.emphSpring) { chipsVisible = true }
                    if !effectChips.isEmpty { Haptics.tick() }
                } label: {
                    Text(text.choiceLabels[choice.id] ?? choice.id).font(.maru(14)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.gold.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 30)
    }
}
