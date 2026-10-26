// S6bView.swift
// S6b 勇退エンディング（正本: uiux_vision_reply_part2 §S6b・難度中）。全て暗転・緞帳の語彙。
// ①引退興行(残金→0・会場4段階・客電粒)→②勇退モンタージュ(手帳→車窓→ファミレス・紙芝居プレイヤー流用)
// →③年表(1年=1行)→④スタッフロール→⑤壁写真焼き付き0.8s+ピン音→緞帳→もう一度(=S1顔合わせ)。
// MVPは1年完結・優勝時の締めとして表示。hRare不使用（既定）。会場カット/写真は【仮】プレースホルダ。

import SwiftUI
import GameCore

struct S6bView: View {
    let session: GameSession
    var kougyouOnly = false    // #5 十年で区切り：①引退興行だけ（あとは endings_spec の場面へ）
    var finishLabel = "また、幕が上がる ▶"
    var onFinish: () -> Void   // 緞帳→S1顔合わせ（MVPはもう一度＝新周回）

    @State private var phase: Phase = {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["MZ_S6B_PHASE"] {   // 目視用: montage / nenpyou / wall から始める
        case "montage": return .montage
        case "nenpyou": return .nenpyou
        case "wall": return .wall
        default: break
        }
        #endif
        return .kougyou
    }()
    private enum Phase { case kougyou, montage, nenpyou, wall }

    private var s: GameState { session.state }

    var body: some View {
        ZStack {
            LinearGradient(colors: [YoseColor.enji, YoseColor.kuroUrushi], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            if phase == .kougyou {   // 客席の幕（縦縞）を暗く重ねて上下の空白を寄席の壁にする
                HStack(spacing: 0) {
                    ForEach(0..<10, id: \.self) { i in (i % 2 == 0 ? Color.black.opacity(0.22) : Color.clear) }
                }.ignoresSafeArea()
            }
            switch phase {
            case .kougyou: kougyou.transition(.opacity)
            case .montage:
                ReminiscencePlayer(cards: montageCards, title: "これまでの話") { advance(.nenpyou) }   // 既定の「はじまりの話」は導入の題＝エンディングの振り返りには合わない.transition(.opacity)
            case .nenpyou: nenpyou.transition(.opacity)
            case .wall: wall.transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: phase)
    }

    private func advance(_ p: Phase) { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.5)) { phase = p } }

    // MARK: ① 引退興行（残金→0・会場4段階・客電粒）

    @State private var counted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion   // 演出ひかえめ＝切替・数字・焼き付きを即時に（a11y_check_1026_voiceover_v0 #8）
    private var kougyou: some View {
        VStack(spacing: 0) {
            YoseHeaderBar(title: "最終興行・千秋楽")
            // 定式幕（黒・柿・萌黄）で上を締める
            HStack(spacing: 0) {
                ForEach(0..<12, id: \.self) { i in
                    Rectangle().fill(i % 3 == 0 ? YoseColor.kuroUrushi : (i % 3 == 1 ? YoseColor.shu : YoseColor.tokiwa))
                }
            }
            .frame(height: 24).overlay(alignment: .bottom) { Rectangle().fill(YoseColor.kin).frame(height: 2) }
            .background(alignment: .bottom) { Rectangle().fill(YoseColor.sumi).frame(height: 2).offset(y: 2) }
            Spacer(minLength: 0)
            // 千秋楽の興行ビラ（和紙の地・金と朱の二重枠・墨のハードシャドウ）
            VStack(spacing: 12) {
                Text("千 秋 楽").font(YoseFont.mincho(44)).foregroundStyle(YoseColor.sumi)
                    .shadow(color: YoseColor.kin, radius: 0, x: 2, y: 2)
                HStack(spacing: 8) {
                    Rectangle().fill(YoseColor.shu).frame(height: 2)
                    Rectangle().fill(YoseColor.shu).frame(width: 6, height: 6).rotationEffect(.degrees(45))
                    Rectangle().fill(YoseColor.shu).frame(height: 2)
                }
                .padding(.horizontal, 20)
                Text("\(session.combiName)　最後の舞台").font(YoseFont.mincho(18)).foregroundStyle(YoseColor.sumi)
                    .lineLimit(1).minimumScaleFactor(0.6)
                // 最終到達舞台（4段階のうち、どこまで来たか）
                VStack(spacing: 6) {
                    Text("最終到達舞台").font(YoseFont.captionBold).foregroundStyle(YoseColor.enji)
                    Text(venueName).font(YoseFont.bannerTitle).tracking(3).foregroundStyle(YoseColor.shu)
                    HStack(spacing: 4) {
                        ForEach(0..<4, id: \.self) { t in
                            if t > 0 { Text("▶").font(.system(size: Font.mzScaled(8))).foregroundStyle(YoseColor.haiSumi) }
                            YoseTag(text: Self.venueNames[t], style: t == venueTier ? .solidEnji : .outlineSumi)
                                .opacity(t <= venueTier ? 1 : 0.5)
                        }
                    }
                }
                .padding(.vertical, 12).frame(maxWidth: .infinity)
                .yoseKifuda()
                // 所持金を舞台に懸ける＝残金が減って0になる（元の額を一拍見せてから）
                VStack(spacing: 4) {
                    Text("所持金を全額、最後の舞台に懸ける").font(YoseFont.captionBold).foregroundStyle(YoseColor.haiSumi).lineLimit(2).minimumScaleFactor(0.7).multilineTextAlignment(.center)
                    HStack(spacing: 10) {
                        VStack(spacing: 0) {
                            Text("所持金").font(YoseFont.captionBold).foregroundStyle(YoseColor.haiSumi)
                            Text(Yen.text(max(0, s.money))).font(YoseFont.number(20, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                                .lineLimit(1).minimumScaleFactor(0.6)
                        }
                        Image(systemName: "arrowtriangle.right.fill").font(.system(size: Font.mzScaled(14))).foregroundStyle(YoseColor.shu).accessibilityHidden(true)
                        VStack(spacing: 0) {
                            Text("残金").font(YoseFont.captionBold).foregroundStyle(YoseColor.enji)
                            Text(Yen.text(counted ? 0 : max(0, s.money)))
                                .font(YoseFont.number(26, weight: .black)).monospacedDigit().foregroundStyle(YoseColor.shu)
                                .contentTransition(.numericText())
                        }
                    }
                    .padding(.vertical, 8).padding(.horizontal, 14)
                    .frame(maxWidth: .infinity)
                    .background(YoseColor.ki.opacity(0.55))
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                    .overlay(alignment: .topTrailing) { YoseHankoStamp(text: "全額投入", angle: -6).offset(x: 6, y: -16) }
                }
            }
            .padding(.vertical, 36).padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(YoseColor.washi)
            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2.5))
            .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 3).padding(2.5))
            .overlay(Rectangle().stroke(YoseColor.shu, lineWidth: 1.5).padding(6))
            .background(alignment: .bottom) { Rectangle().fill(YoseColor.kuroUrushi).offset(y: 5) }
            .padding(.horizontal, 20)
            Spacer(minLength: 0)
            Button { if kougyouOnly { onFinish() } else { advance(.montage) } } label: { Text("最後の舞台へ上がる ▶") }
                .buttonStyle(YoseButtonStyle(.primary))
                .padding(.horizontal, 14).padding(.bottom, 30)
        }
        // 元の残金を一拍見せてから減らす（0.8秒で0になると元の額が読めず「0円なのにドーム」に見えた）
        .onAppear { withAnimation(reduceMotion ? nil : .easeInOut(duration: 1.8).delay(1.0)) { counted = true } }
    }

    private static let venueNames = ["町の劇場", "ホール", "アリーナ", "ドーム"]

    private var venueTier: Int {   // 残金帯4段階（GameConfig集約・数値は全て【仮】）
        let c = session.config
        switch s.money {
        case ..<c.venueTier1Money: return 0    // 町の劇場
        case ..<c.venueTier2Money: return 1    // ホール
        case ..<c.venueTier3Money: return 2    // アリーナ
        default: return 3                      // ドーム
        }
    }
    private var venueName: String { Self.venueNames[venueTier] }

    // MARK: ② モンタージュ用カード

    private var montageCards: [ReminiscenceCard] {
        [
            ReminiscenceCard(caption: "組んだばかりの頃。谷口の部屋。",   // 字幕どおりの場所の絵（code_review_2026-10-19m §1-3・時間帯は「終電なくなった」から夜）
                             talk: [Advice(name: "俺", text: "終電なくなった。今日はここで寝る"),
                                    Advice(name: "谷口", text: "いいよ。押し入れに毛布がある")],
                             backdrop: .init(.apartment, .night)),
            ReminiscenceCard(caption: "大会の帰り。夜の電車。",
                             talk: [Advice(name: "谷口", text: "終電、間に合ってよかったね"),
                                    Advice(name: "俺", text: "うん。来年も、また出よう")],
                             backdrop: .init(.train, .night)),
            ReminiscenceCard(caption: "いつものファミレス。同じ席。",   // 推定: 時間帯の記述なし→夕
                             talk: [Advice(name: "谷口", text: "いつもの、ドリンクバーでいい？"),
                                    Advice(name: "俺", text: "うん。今日は長くなりそうだし"),
                                    Advice(name: "谷口", text: "じゃあ、二つ頼むよ")],
                             backdrop: .init(.famires, .evening)),
        ]
    }

    // MARK: ③ 年表（1年=1行）＋ ④ スタッフロール（最小）

    private var nenpyou: some View {
        VStack(spacing: Theme.Sp.s16) {
            Spacer()
            Text("年表").font(.maru(12)).tracking(2).foregroundStyle(.white.opacity(0.75))   // 暗い地で読める濃さに（0.5 は沈んだ）
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

            Text("—— \(session.combiName) ——").font(.system(size: Font.mzScaled(13), design: .serif)).foregroundStyle(.white.opacity(0.8)).padding(.top, Theme.Sp.s24)
            Text("結成からの記録").font(.system(size: Font.mzScaled(13), design: .serif)).foregroundStyle(.white.opacity(0.75))
            Spacer()
            Text("タップで進む").font(.maru(12)).foregroundStyle(.white.opacity(0.7))   // 12pt 未満は使わない（TypeStep の決まり）.padding(.bottom, Theme.Sp.s24)
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
                    .overlay(Text(session.combiName).font(.maru(12)).foregroundStyle(.black.opacity(0.7)).offset(y: 78))
                Circle().fill(Theme.verm).frame(width: 10, height: 10).offset(y: -4)   // ピン
            }
            .scaleEffect(burned ? 1 : 1.05).opacity(burned ? 1 : 0)

            Text("楽屋の壁。最後の舞台の夜。")
                .font(.system(size: Font.mzScaled(13), design: .serif)).foregroundStyle(.white.opacity(0.8)).opacity(burned ? 1 : 0)
            Spacer()
            Button(action: onFinish) {
                Text(finishLabel).font(.maru(16)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, Theme.Sp.s16)
                    .background(Theme.verm, in: RoundedRectangle(cornerRadius: Theme.Rad.btn))
            }.buttonStyle(PressableStyle()).padding(.horizontal, Theme.Sp.s32).padding(.bottom, 50)
                .opacity(burned ? 1 : 0)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.8)) { burned = true }   // 焼き付き0.8s
            Haptics.tick()   // ピンの音1つ相当（hRareは使わない）
        }
    }
}
