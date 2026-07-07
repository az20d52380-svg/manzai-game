// IntroFlow.swift
// S1 タイトル／コンビ結成（正本: uiux_vision_reply_part2 §S1）。MVP版＝非永続なので
// 初回フローに絞る: KVタイトル →「はじめる」→ 回想3カット(紙芝居) → コンビ名入力見開き →（onComplete）→ 育成メイン。
// セーブ/つづきから・顔合わせ・名鑑・排出・壁写真は永続レイヤ未実装のため本編送り（§0）。
// ReminiscencePlayer は §依頼6 の共用部品①（S6b年表・優勝エピローグでも使う）。KV/立ち絵は【仮】プレースホルダ。

import SwiftUI

// MARK: 回想紙芝居プレイヤー（共用部品・静止画+字幕+クロスフェード0.18s）

struct ReminiscenceCard: Identifiable {
    let id = UUID()
    let caption: String
    var tint: Color = Theme.ink   // 切り絵シルエットの色（過去=色が付く前＝暗色）
}

struct ReminiscencePlayer: View {
    let cards: [ReminiscenceCard]
    var onComplete: () -> Void
    @State private var index = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            // 切り絵シルエット（仮・カットごとに少しずらす）
            silhouette(for: index)
                .id(index)
                .transition(.opacity)

            VStack {
                Spacer()
                Text(cards[safe: index]?.caption ?? "")
                    .font(.system(size: 16, design: .serif)).lineSpacing(8)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Sp.s32)
                    .id("cap\(index)")
                    .transition(.opacity)
                Spacer().frame(height: 60)
                Text("タップで進む").font(.maru(11)).foregroundStyle(.white.opacity(0.45))
                    .padding(.bottom, Theme.Sp.s24)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if index + 1 < cards.count {
                withAnimation(.easeInOut(duration: 0.18)) { index += 1 }   // 紙めくりクロスフェード
            } else {
                onComplete()
            }
        }
    }

    // 切り絵シルエット（仮）: 二人の影＋スポット。カット番号で構図を少し変える。
    private func silhouette(for i: Int) -> some View {
        GeometryReader { geo in
            ZStack {
                RadialGradient(colors: [Color(hex: 0x2A2440), .black],
                               center: .center, startRadius: 20, endRadius: geo.size.height * 0.7)
                HStack(alignment: .bottom, spacing: i == 1 ? 4 : 40) {
                    Capsule().fill(Color.white.opacity(0.10)).frame(width: 60, height: 150)
                        .overlay(alignment: .top) { Circle().fill(Color.white.opacity(0.10)).frame(width: 34).offset(y: 14) }
                    if i != 0 {
                        Capsule().fill(Color.white.opacity(0.10)).frame(width: 56, height: 138)
                            .overlay(alignment: .top) { Circle().fill(Color.white.opacity(0.10)).frame(width: 32).offset(y: 14) }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, geo.size.height * 0.28)
            }
        }
    }
}

// MARK: S1 タイトル（KV＋ロゴ＋はじめる）

struct S1TitleView: View {
    var onStart: () -> Void
    @State private var lit = false     // 照明輪→ロゴの順で灯る
    @State private var showSettings = false

    var body: some View {
        ZStack {
            keyVisual
            VStack(spacing: Theme.Sp.s16) {
                Spacer().frame(height: 70)
                // ロゴ（仮）
                VStack(spacing: 4) {
                    Text("四分の夜").font(.maru(40)).foregroundStyle(.white)
                        .shadow(color: Theme.gold.opacity(lit ? 0.5 : 0), radius: 16)
                    Text("――漫才師、育成。【仮】").font(.maru(11)).tracking(2).foregroundStyle(.white.opacity(0.6))
                }
                .opacity(lit ? 1 : 0)
                .animation(.easeInOut(duration: 0.8).delay(0.4), value: lit)

                Spacer()

                Button(action: onStart) {
                    Text("はじめる").font(.maru(18)).foregroundStyle(Color(hex: 0x2A2440))
                        .frame(maxWidth: .infinity).padding(.vertical, Theme.Sp.s16)
                        .background(Theme.gold, in: RoundedRectangle(cornerRadius: Theme.Rad.btn))
                        .e2()
                }
                .buttonStyle(PressableStyle())
                .padding(.horizontal, Theme.Sp.s32)
                .padding(.bottom, 50)
                .opacity(lit ? 1 : 0).animation(.easeOut(duration: 0.5).delay(0.9), value: lit)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { showSettings = true } label: {   // Quietの歯車 → S1b設定
                Image(systemName: "gearshape.fill").font(.system(size: 18)).foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(PressableStyle()).padding(.top, 54).padding(.trailing, 20)
        }
        .sheet(isPresented: $showSettings) { SettingsView { showSettings = false } }
        .onAppear { lit = true }
    }

    // KV【仮】: 上手袖から見た夜の舞台（袖の暗部＋スポット＋二人の影＋マイク）
    private var keyVisual: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                LinearGradient(colors: [.black, Color(hex: 0x241C33), Color(hex: 0x3A2A2A)],
                               startPoint: .top, endPoint: .bottom)
                // スポットライトの輪（先に灯る）
                RadialGradient(colors: [Theme.gold.opacity(lit ? 0.22 : 0), .clear],
                               center: .init(x: 0.55, y: 0.72), startRadius: 10, endRadius: 240)
                    .animation(.easeOut(duration: 0.4), value: lit)
                // 舞台床
                Rectangle().fill(Color.white.opacity(0.04)).frame(height: 90)
                // マイク＋二人の影
                HStack(alignment: .bottom, spacing: 8) {
                    stageDuo
                    VStack(spacing: 0) {   // センターマイク
                        Circle().fill(.black.opacity(0.6)).frame(width: 12, height: 12)
                        Rectangle().fill(.black.opacity(0.5)).frame(width: 3, height: 70)
                    }
                }
                .padding(.bottom, 30).padding(.trailing, 40)
                .frame(maxWidth: .infinity, alignment: .trailing)
                // 上手袖（左端の暗部）
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 70).frame(maxWidth: .infinity, alignment: .leading)
            }
            .ignoresSafeArea()
        }
    }

    private var stageDuo: some View {
        HStack(alignment: .bottom, spacing: 3) {
            Capsule().fill(.black.opacity(0.55)).frame(width: 34, height: 78)
                .overlay(alignment: .top) { Circle().fill(.black.opacity(0.55)).frame(width: 20).offset(y: 8) }
            Capsule().fill(.black.opacity(0.6)).frame(width: 38, height: 86)
                .overlay(alignment: .top) { Circle().fill(.black.opacity(0.6)).frame(width: 22).offset(y: 8) }
        }
    }
}

// MARK: コンビ名入力（ネタ帳見開き）

struct NameEntryView: View {
    var onDecide: (String) -> Void
    @State private var name = ""
    @State private var inkWet = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.bgTop, Theme.bg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: Theme.Sp.s24) {
                Text("コンビ名を、決めよう。").font(.maru(15)).foregroundStyle(Theme.inkDim)

                // ネタ帳の見開き（白面・罫線1本＋キャレット）
                VStack(spacing: 6) {
                    TextField("コンビ名", text: $name)
                        .font(.maru(24)).foregroundStyle(inkWet ? Theme.ink : Theme.inkDim)
                        .multilineTextAlignment(.center)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit(decide)
                    Rectangle().fill(Theme.inkFaint).frame(height: 1.5)   // 罫線
                }
                .padding(Theme.Sp.s24)
                .frame(maxWidth: .infinity)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card))
                .e2()
                .padding(.horizontal, Theme.Sp.s24)

                Button(action: decide) {
                    Text("これでいく").font(.maru(16)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, Theme.Sp.s12)
                        .background(name.isEmpty ? Theme.inkFaint : Theme.verm, in: RoundedRectangle(cornerRadius: Theme.Rad.btn))
                }
                .buttonStyle(PressableStyle(enabled: !name.isEmpty))
                .disabled(name.isEmpty)
                .padding(.horizontal, Theme.Sp.s32)
            }
        }
        .onAppear { focused = true }
    }

    private func decide() {
        guard !name.isEmpty else { return }
        withAnimation(.easeOut(duration: 0.4)) { inkWet = true }   // 書いた字が乾く
        Haptics.confirm()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { onDecide(name) }
    }
}

// MARK: フロー統合（title → reminiscence → nameEntry → onComplete(name)）

struct IntroFlowView: View {
    var onComplete: (String) -> Void
    @State private var stage: Stage = .title
    private enum Stage { case title, reminiscence, nameEntry }

    private let cards = [
        ReminiscenceCard(caption: "高校の教室。窓際で、谷口が一人で喋っていた。\n誰も聞いていなかった。俺だけが、笑った。"),
        ReminiscenceCard(caption: "「コンビ、組まへんか」\n谷口はそう言った。放課後の、誰もいない廊下で。"),
        ReminiscenceCard(caption: "それから、何年。\n売れない日々の、まだ入口だった。"),
    ]

    var body: some View {
        ZStack {
            switch stage {
            case .title:
                S1TitleView { withAnimation(.easeInOut(duration: 0.4)) { stage = .reminiscence } }
                    .transition(.opacity)
            case .reminiscence:
                ReminiscencePlayer(cards: cards) { withAnimation(.easeInOut(duration: 0.4)) { stage = .nameEntry } }
                    .transition(.opacity)
            case .nameEntry:
                NameEntryView { onComplete($0) }
                    .transition(.opacity)
            }
        }
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
