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
            LinearGradient(colors: [Theme.curtain, Theme.curtainShade], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
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
            // 名ビラ＝生成りの紙に墨の寄席文字。金の二重縁
            VStack(spacing: 14) {
                Text("千秋楽").font(.maru(52, weight: .black)).tracking(8).foregroundStyle(Theme.sumi)
                    .shadow(color: Theme.goldLeafHi, radius: 0, x: 2, y: 2)
                Rectangle().fill(Theme.verm).frame(height: 3).padding(.horizontal, 24)
                Text("\(session.combiName)　最後の舞台").font(.maru(14, weight: .bold)).foregroundStyle(Theme.sumi.opacity(0.8))
                VStack(spacing: 2) {
                    Text("残　金").font(.maru(11, weight: .bold)).tracking(4).foregroundStyle(Theme.inkDim)
                    Text("¥\(counted ? 0 : max(0, s.money))")
                        .font(.maru(34, weight: .black)).monospacedDigit().foregroundStyle(Theme.curtain)
                        .contentTransition(.numericText())
                }
                Text(venueName).font(.maru(22, weight: .black)).tracking(3).foregroundStyle(.white)
                    .padding(.horizontal, 22).padding(.vertical, 6)
                    .background(Theme.verm)
                    .overlay(Rectangle().stroke(Theme.sumi, lineWidth: 1.5))
            }
            .padding(.vertical, 28).padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(Color(hex: 0xFBF3E2))
            .overlay(Rectangle().stroke(Theme.goldLeafHi, lineWidth: 3))
            .overlay(Rectangle().stroke(Theme.goldLeafMid, lineWidth: 1).padding(7))
            .padding(.horizontal, 28)
            venue.frame(height: 110)
            Spacer()
            Text("タップで進む").font(.maru(11)).foregroundStyle(Theme.goldLeafHi.opacity(0.8)).padding(.bottom, Theme.Sp.s24)
        }
        .contentShape(Rectangle()).onTapGesture { advance(.montage) }
        // 元の残金を一拍見せてから減らす（0.8秒で0になると元の額が読めず「0円なのにドーム」に見えた）
        .onAppear { withAnimation(.easeInOut(duration: 1.8).delay(1.0)) { counted = true } }
    }

    // 会場カット（客電の粒＝客席の埋まり。規模で粒数）
    private var venue: some View {
        let tier = venueTier
        let rows = 4 + tier * 2, cols = 8 + tier * 3
        return VStack(spacing: 4) {
            ForEach(0..<rows, id: \.self) { _ in
                HStack(spacing: 4) {
                    ForEach(0..<cols, id: \.self) { _ in
                        Circle().fill(Theme.goldLeafHi.opacity(0.7)).frame(width: 3, height: 3)
                    }
                }
            }
        }
    }

    private var venueTier: Int {   // 残金帯4段階（GameConfig集約・数値は全て【仮】）
        let c = session.config
        switch s.money {
        case ..<c.venueTier1Money: return 0    // 町の劇場
        case ..<c.venueTier2Money: return 1    // ホール
        case ..<c.venueTier3Money: return 2    // アリーナ
        default: return 3                      // ドーム
        }
    }
    private var venueName: String { ["町の劇場", "ホール", "アリーナ", "ドーム"][venueTier] }

    // MARK: ② モンタージュ用カード

    private var montageCards: [ReminiscenceCard] {
        [
            ReminiscenceCard(caption: "組んだばかりの頃。谷口の部屋。",
                             talk: [Advice(name: "俺", text: "終電なくなった。今日はここで寝る"),
                                    Advice(name: "谷口", text: "ええよ。毛布、一枚しかないけどな")]),
            ReminiscenceCard(caption: "大会の帰り。夜の電車。",
                             talk: [Advice(name: "谷口", text: "終電、間に合うてよかったな"),
                                    Advice(name: "俺", text: "ああ。来年も、また出よう")]),
            ReminiscenceCard(caption: "いつものファミレス。同じ席。",
                             talk: [Advice(name: "谷口", text: "いつもの、ドリンクバーでええ？"),
                                    Advice(name: "俺", text: "うん。今日は長くなりそうだし"),
                                    Advice(name: "谷口", text: "ほな、二つ頼むわ")]),
        ]
    }

    // MARK: ③ 年表（1年=1行）＋ ④ スタッフロール（最小）

    private var nenpyou: some View {
        VStack(spacing: Theme.Sp.s16) {
            Spacer()
            Text("年表").font(.maru(12)).tracking(2).foregroundStyle(.white.opacity(0.5))
            // 1年＝1行（結成からの頂グランプリの到達）。最後の行が優勝の年
            VStack(spacing: 6) {
                ForEach(session.yearHistory, id: \.year) { r in
                    HStack {
                        Text("\(r.year)年目").font(.maru(13)).monospacedDigit().foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        Text(r.champion ? "頂グランプリ 優勝" : YearResultView.reachLabel(r, names: session.config.calendar.gpRoundNames))
                            .font(.maru(14)).foregroundStyle(r.champion ? Theme.gold : .white.opacity(0.85))
                    }
                }
            }
            .padding(Theme.Sp.s16).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: Theme.Rad.card))
            .padding(.horizontal, Theme.Sp.s24)

            Text("—— \(session.combiName) ——").font(.system(size: 13, design: .serif)).foregroundStyle(.white.opacity(0.8)).padding(.top, Theme.Sp.s24)
            Text("結成からの記録").font(.system(size: 13, design: .serif)).foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text("タップで進む").font(.maru(11)).foregroundStyle(.white.opacity(0.45)).padding(.bottom, Theme.Sp.s24)
        }
        .contentShape(Rectangle()).onTapGesture { advance(.wall) }
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

            Text("楽屋の壁。最後の舞台の夜。")
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
