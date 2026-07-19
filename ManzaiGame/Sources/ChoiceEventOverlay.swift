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
                if chosenID == nil, setupShown >= text.setup.count {
                    choiceButtons
                }
                if let chosenID, afterShown >= (text.afterChoice[chosenID]?.count ?? 0) {
                    Button {
                        session.dismissChoiceEvent()
                        onClose()
                    } label: {
                        Text("閉じる").font(.maru(14)).foregroundStyle(Color(hex: 0x5A3A06))
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Theme.gold, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain).padding(.horizontal, 30)
                } else if setupShown < text.setup.count || (chosenID != nil && afterShown < (text.afterChoice[chosenID!]?.count ?? 0)) {
                    Text("タップで進む").font(.maru(10)).foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.vertical, 34)
        }
        .contentShape(Rectangle())
        .onTapGesture { advance() }
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

    private var choiceButtons: some View {
        VStack(spacing: 10) {
            ForEach(session.availableEventChoices(), id: \.id) { choice in
                Button {
                    session.applyEventChoice(choice.id)
                    withAnimation(Theme.Motion.appear) { chosenID = choice.id; afterShown = 0 }
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
