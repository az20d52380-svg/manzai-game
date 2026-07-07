// S6bView.swift
// S6b 勇退エンディング（正本: uiux_vision_reply_part2 §S6b・難度中）。全て暗転・緞帳の語彙。
// ①引退興行(残金→0・会場4段階・客電粒)→②勇退モンタージュ(手帳→車窓→ファミレス・紙芝居プレイヤー流用)
// →③年表(1年=1行)→④スタッフロール→⑤壁写真焼き付き0.8s+ピン音→緞帳→もう一度(=S1顔合わせ)。
// MVPは1年完結・優勝時の締めとして表示。hRare不使用（既定）。会場カット/写真は【仮】プレースホルダ。

import SwiftUI
import GameCore

struct S6bView: View {
    let session: GameSession
    var onFinish: () -> Void   // 緞帳→S1顔合わせ（MVPはもう一度＝新周回）

    @State private var phase: Phase = .kougyou
    private enum Phase { case kougyou, montage, nenpyou, wall }

    private var s: GameState { session.state }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch phase {
            case .kougyou: kougyou.transition(.opacity)
            case .montage:
                ReminiscencePlayer(cards: montageCards) { advance(.nenpyou) }.transition(.opacity)
            case .nenpyou: nenpyou.transition(.opacity)
            case .wall: wall.transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: phase)
    }

    private func advance(_ p: Phase) { withAnimation(.easeInOut(duration: 0.5)) { phase = p } }

    // MARK: ① 引退興行（残金→0・会場4段階・客電粒）

    @State private var counted = false
    private var kougyou: some View {
        VStack(spacing: Theme.Sp.s24) {
            Spacer()
            Text("最後の興行。").font(.maru(14)).foregroundStyle(.white.opacity(0.7))
            // 通帳様式の残金→0
            Text("¥\(counted ? 0 : max(0, s.money))")
                .font(.maru(30)).monospacedDigit().foregroundStyle(Theme.gold)
                .contentTransition(.numericText())
            venue.frame(height: 150)
            Text(venueName).font(.maru(16)).foregroundStyle(.white)
            Spacer()
            Text("タップで進む").font(.maru(11)).foregroundStyle(.white.opacity(0.45)).padding(.bottom, Theme.Sp.s24)
        }
        .contentShape(Rectangle()).onTapGesture { advance(.montage) }
        .onAppear { withAnimation(.easeInOut(duration: 0.8)) { counted = true } }
    }

    // 会場カット（客電の粒＝客席の埋まり。規模で粒数）
    private var venue: some View {
        let tier = venueTier
        let rows = 4 + tier * 2, cols = 8 + tier * 3
        return VStack(spacing: 4) {
            ForEach(0..<rows, id: \.self) { _ in
                HStack(spacing: 4) {
                    ForEach(0..<cols, id: \.self) { _ in
                        Circle().fill(Theme.gold.opacity(0.55)).frame(width: 3, height: 3)
                    }
                }
            }
        }
    }

    private var venueTier: Int {   // 残金帯4段階【仮・config化はTODO】
        switch s.money {
        case ..<0: return 0            // 町の劇場
        case ..<3_000_000: return 1    // ホール
        case ..<8_000_000: return 2    // アリーナ
        default: return 3              // ドーム
        }
    }
    private var venueName: String { ["町の劇場", "ホール", "アリーナ", "ドーム"][venueTier] }

    // MARK: ② モンタージュ用カード

    private var montageCards: [ReminiscenceCard] {
        [
            ReminiscenceCard(caption: "谷口の手帳の、最後のページ。\nコンビ名が、結成の日の日付と一緒に書いてあった。"),
            ReminiscenceCard(caption: "帰りの電車。\n窓の外を、四つの季節が、順番に流れていった。"),
            ReminiscenceCard(caption: "いつものファミレス。同じ席。\nドリンクバーだけ頼んで、二人で、何時間も喋った。"),
        ]
    }

    // MARK: ③ 年表（1年=1行）＋ ④ スタッフロール（最小）

    private var nenpyou: some View {
        VStack(spacing: Theme.Sp.s16) {
            Spacer()
            Text("年表").font(.maru(12)).tracking(2).foregroundStyle(.white.opacity(0.5))
            HStack {
                Text("\(session.year)年目").font(.maru(13)).monospacedDigit().foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(reachText).font(.maru(14)).foregroundStyle(Theme.gold)
            }
            .padding(Theme.Sp.s16).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: Theme.Rad.card))
            .padding(.horizontal, Theme.Sp.s24)

            Text("—— \(session.combiName) ——").font(.system(size: 13, design: .serif)).foregroundStyle(.white.opacity(0.8)).padding(.top, Theme.Sp.s24)
            Text("四分間で、笑わせてきた。").font(.system(size: 13, design: .serif)).foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text("タップで進む").font(.maru(11)).foregroundStyle(.white.opacity(0.45)).padding(.bottom, Theme.Sp.s24)
        }
        .contentShape(Rectangle()).onTapGesture { advance(.wall) }
    }

    private var reachText: String {
        guard let o = session.outcome else { return "——" }
        if o.champion { return "頂グランプリ 優勝" }
        if o.reachedFinal { return "決勝進出" }
        return "予選 \(o.roundsPassed)回戦"
    }

    // MARK: ⑤ 壁写真焼き付き→緞帳→もう一度

    @State private var burned = false
    private var wall: some View {
        VStack(spacing: Theme.Sp.s24) {
            Spacer()
            // 楽屋の壁に留められたコンビ写真（仮）
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.92))
                    .frame(width: 150, height: 190)
                    .overlay(
                        HStack(alignment: .bottom, spacing: 4) {
                            Capsule().fill(.black.opacity(0.5)).frame(width: 40, height: 90)
                            Capsule().fill(.black.opacity(0.55)).frame(width: 44, height: 100)
                        }.offset(y: 20)
                    )
                    .overlay(Text(session.combiName).font(.maru(11)).foregroundStyle(.black.opacity(0.6)).offset(y: 78))
                Circle().fill(Theme.verm).frame(width: 10, height: 10).offset(y: -4)   // ピン
            }
            .scaleEffect(burned ? 1 : 1.05).opacity(burned ? 1 : 0)

            Text("その写真は、袖の壁に、ピンで留められた。")
                .font(.system(size: 13, design: .serif)).foregroundStyle(.white.opacity(0.8)).opacity(burned ? 1 : 0)
            Spacer()
            Button(action: onFinish) {
                Text("また、幕が上がる ▶").font(.maru(16)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, Theme.Sp.s16)
                    .background(Theme.verm, in: RoundedRectangle(cornerRadius: Theme.Rad.btn))
            }.buttonStyle(PressableStyle()).padding(.horizontal, Theme.Sp.s32).padding(.bottom, 50)
                .opacity(burned ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { burned = true }   // 焼き付き0.8s
            Haptics.tick()   // ピンの音1つ相当（hRareは使わない）
        }
    }
}
