// EndingViews.swift
// エンディングの画面（docs/endings_spec_v1.md §1-3・§3 の一枚絵・§6 図鑑）。
// 場面カード（ReminiscencePlayer 流用）→ 一枚絵 → 図鑑に記録 →「もう一度」。外部画像なし（Shape とグラデーションだけ）。
// #5 は S6b ①引退興行を前に、#7 は S6b のまま、#8 は S6b の後に場面1枚と一枚絵を足す。

import SwiftUI
import GameCore

// MARK: - 流れ

struct EndingFlowView: View {
    let session: GameSession?       // 図鑑からの読み返しは nil（S6b は通さない）
    let ending: EndingID
    var replay = false              // true＝図鑑の読み返し（記録しない・最後は「とじる」）
    var record = true               // DEBUG の MZ_ENDING 直行は記録しない
    var onFinish: () -> Void

    private enum Stage { case s6b, cards, art }
    @State private var stage: Stage = .cards
    @State private var recorded = false

    private var cards: [ReminiscenceCard] { ending.cards(riftChoice: session?.riftWarnChoice) }
    private var usesS6b: Bool { session != nil && !replay && [.tenYearsClose, .championRetire, .championPair].contains(ending) }

    var body: some View {
        ZStack {
            switch stage {
            case .s6b:
                if let session {
                    S6bView(session: session, kougyouOnly: ending == .tenYearsClose,
                            finishLabel: ending == .championRetire ? "また、幕が上がる ▶" : "つづき ▶",
                            onFinish: { s6bDone() })
                }
            case .cards:
                // #7 は場面カードが無い（S6b 直行）。onAppear で .s6b に替わるまでの最初の1描画で空配列を引かないよう守る
                if cards.isEmpty { Color.clear } else { ReminiscencePlayer(cards: cards, title: ending.title, onComplete: { go(.art) }) }
            case .art:
                artPage
            }
        }
        .transition(.opacity)
        .onAppear {
            guard !recorded else { return }
            recorded = true
            stage = usesS6b ? .s6b : (cards.isEmpty ? .art : .cards)
            #if DEBUG
            if ProcessInfo.processInfo.environment["MZ_ENDSTEP"] == "art" { stage = .art }   // 目視用: 一枚絵へ直行
            if ProcessInfo.processInfo.environment["MZ_ENDSTEP"] == "cards", !cards.isEmpty { stage = .cards }   // 目視用: S6b を飛ばして場面へ
            if Int(ProcessInfo.processInfo.environment["MZ_ENDSTEP"] ?? "") != nil, !cards.isEmpty { stage = .cards }   // MZ_ENDSTEP=<番号>: その場面カードを直接
            #endif
            if !replay && record { EndingBook.record(ending, partner: Names.partner) }
        }
    }

    private func go(_ s: Stage) { withAnimation(.easeInOut(duration: 0.4)) { stage = s } }

    private func s6bDone() {
        switch ending {
        case .championRetire: onFinish()                       // 既存の勇退画面のまま
        default: go(cards.isEmpty ? .art : .cards)              // #5＝興行のあと場面へ／#8＝S6b のあと追加の場面へ
        }
    }

    /// 最後の一枚絵（キャプション1行）
    private var artPage: some View {
        let finalYears: Set<Int> = Set((session?.yearHistory ?? []).filter { $0.reachedFinal }.map(\.year))
        return ZStack {
            LinearGradient(colors: [YoseColor.kuroUrushi, YoseColor.enji.opacity(0.8)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()
                EndingArt(id: ending, goldRows: finalYears.isEmpty ? EndingArt.sampleGoldRows : finalYears)
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
                    .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 3))
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1).padding(-2))
                    .padding(.horizontal, 24)
                if !ending.caption.isEmpty {
                    Text(ending.caption).font(YoseFont.mincho(16)).foregroundStyle(YoseColor.kinari)
                        .multilineTextAlignment(.center).padding(.horizontal, 28)
                }
                HStack(spacing: 8) {
                    Text("No.\(ending.number)　\(ending.title)").font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.kin)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1))   // 暗い地では濃い金文字が沈むため明るい金
                    Text(ending.kind.label).font(YoseFont.captionBold).foregroundStyle(YoseColor.kinari)
                        .padding(.horizontal, 8).padding(.vertical, 3).background(ending.kind.color)
                }
                if !replay {
                    Text("エンディング図鑑に記録しました").font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.kinari.opacity(0.65))
                }
                Spacer()
                Button(action: onFinish) { Text(replay ? "とじる" : "もう一度 ▶") }
                    .buttonStyle(YoseButtonStyle(.primary))
                    .padding(.horizontal, 14).padding(.bottom, 30)
            }
        }
    }
}

// MARK: - 一枚絵（Shape・グラデーションだけ。要素は仕様書の各エンドの欄）

struct EndingArt: View {
    let id: EndingID
    /// #5 の年表：金の縁にする行（決勝に出た年）。見本の既定は 4・8 年目
    var goldRows: Set<Int> = EndingArt.sampleGoldRows
    static let sampleGoldRows: Set<Int> = [4, 8]

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack(alignment: .topLeading) {
                switch id {
                case .nightEscape: nightEscape(w, h)
                case .breakup: breakup(w, h)
                case .gaveUp: gaveUp(w, h)
                case .keptGoing: keptGoing(w, h)
                case .tenYearsClose: tenYearsClose(w, h)
                case .tenYearsTrue: tenYearsTrue(w, h)
                case .championRetire: championRetire(w, h)
                case .championPair: championPair(w, h)
                }
            }
            .frame(width: w, height: h)
            .clipped()
        }
    }

    /// 細い影（二人の影の素材）
    private func shadow(_ w: CGFloat, _ h: CGFloat, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, opacity: Double = 0.55, tilt: Double = 0) -> some View {
        Capsule().fill(YoseColor.kuroUrushi.opacity(opacity)).frame(width: width, height: height)
            .rotationEffect(.degrees(tilt)).position(x: x * w, y: y * h)
    }

    // #1 夜明け前の駅のホーム・始発の窓の明かり・二つの影
    private func nightEscape(_ w: CGFloat, _ h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(hex: 0x1B2236), Color(hex: 0x5A4A5C), Color(hex: 0xC98A5A)], startPoint: .top, endPoint: .bottom)
            Rectangle().fill(Color(hex: 0x24272E)).frame(width: w, height: h * 0.34).offset(y: h * 0.24)          // 車体
            ForEach(0..<7, id: \.self) { i in
                Rectangle().fill(YoseColor.kinBright).frame(width: w * 0.09, height: h * 0.1)
                    .offset(x: w * (0.06 + 0.132 * CGFloat(i)), y: h * 0.32)
            }
            Rectangle().fill(Color(hex: 0x3A3A3F)).frame(width: w, height: h * 0.42).offset(y: h * 0.58)           // ホーム
            Rectangle().fill(.white.opacity(0.85)).frame(width: w, height: max(2, h * 0.016)).offset(y: h * 0.74)  // 白線
            shadow(w, h, x: 0.44, y: 0.84, width: w * 0.022, height: h * 0.3, tilt: 6)
            shadow(w, h, x: 0.52, y: 0.85, width: w * 0.024, height: h * 0.32, tilt: 8)
        }
    }

    // #2 劇場の裏口から右と左に分かれる二本の道・街灯・離れていく影
    private func breakup(_ w: CGFloat, _ h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(hex: 0x2A2F45), Color(hex: 0x6B5E6E)], startPoint: .top, endPoint: .bottom)
            Rectangle().fill(Color(hex: 0x3B2F2C)).frame(width: w * 0.2, height: h * 0.4).offset(x: w * 0.4, y: h * 0.1)   // 裏口の扉
            Circle().fill(YoseColor.kinBright).frame(width: w * 0.05).offset(x: w * 0.475, y: h * 0.04)                    // 外灯
            Path { p in
                p.move(to: CGPoint(x: w * 0.47, y: h * 0.5)); p.addLine(to: CGPoint(x: w * 0.04, y: h))
                p.move(to: CGPoint(x: w * 0.53, y: h * 0.5)); p.addLine(to: CGPoint(x: w * 0.96, y: h))
            }.stroke(YoseColor.ginNezu.opacity(0.7), style: StrokeStyle(lineWidth: max(4, w * 0.04), lineCap: .round))
            ForEach([0.14, 0.86], id: \.self) { x in                                                                         // 街灯二本
                Rectangle().fill(YoseColor.kuroUrushi).frame(width: w * 0.012, height: h * 0.3).position(x: x * w, y: h * 0.52)
                Circle().fill(YoseColor.kinBright).frame(width: w * 0.04).position(x: x * w, y: h * 0.36)
            }
            shadow(w, h, x: 0.3, y: 0.78, width: w * 0.024, height: h * 0.26, tilt: 14)
            shadow(w, h, x: 0.7, y: 0.78, width: w * 0.024, height: h * 0.26, tilt: -14)
        }
    }

    // #3 段ボール箱に立てたノート十冊（最後の1冊だけ薄い）・畳んだバイトの制服
    private func gaveUp(_ w: CGFloat, _ h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [YoseColor.ki, YoseColor.kiDark], startPoint: .top, endPoint: .bottom)
            ForEach(0..<10, id: \.self) { i in
                Rectangle().fill(i == 9 ? Color(hex: 0xE9DFC8) : Color(hex: 0x3F5A7A).opacity(0.9 - 0.04 * Double(i % 3)))
                    .frame(width: w * 0.04, height: h * 0.34)
                    .overlay(Rectangle().stroke(YoseColor.sumi.opacity(0.4), lineWidth: 1))
                    .offset(x: w * (0.27 + 0.05 * CGFloat(i)), y: h * 0.3)
            }
            Path { p in                                                                                                         // 箱（台形）
                p.move(to: CGPoint(x: w * 0.2, y: h * 0.52)); p.addLine(to: CGPoint(x: w * 0.8, y: h * 0.52))
                p.addLine(to: CGPoint(x: w * 0.76, y: h * 0.92)); p.addLine(to: CGPoint(x: w * 0.24, y: h * 0.92)); p.closeSubpath()
            }.fill(Color(hex: 0xA77D4E)).overlay(Rectangle().fill(.clear))
            Rectangle().fill(Color(hex: 0x8C6540)).frame(width: w * 0.16, height: h * 0.05).offset(x: w * 0.42, y: h * 0.6)   // 箱のテープ
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0x9FB6C9)).frame(width: w * 0.2, height: h * 0.08)               // 畳んだ制服
                .overlay(Rectangle().fill(.white.opacity(0.85)).frame(width: w * 0.05, height: h * 0.025).offset(y: -h * 0.03))
                .offset(x: w * 0.4, y: h * 0.45)
        }
    }

    // #4 来年の出番表（12マス・1月だけ印）・パイプ椅子二脚
    private func keptGoing(_ w: CGFloat, _ h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(hex: 0xCDB892), Color(hex: 0x9C8760)], startPoint: .top, endPoint: .bottom)
            let gw = w * 0.56, gh = h * 0.42, gx = w * 0.22, gy = h * 0.08
            Rectangle().fill(YoseColor.washi).frame(width: gw, height: gh).offset(x: gx, y: gy)
            Path { p in
                for c in 0...4 { p.move(to: CGPoint(x: gx + gw * CGFloat(c) / 4, y: gy)); p.addLine(to: CGPoint(x: gx + gw * CGFloat(c) / 4, y: gy + gh)) }
                for r in 0...3 { p.move(to: CGPoint(x: gx, y: gy + gh * CGFloat(r) / 3)); p.addLine(to: CGPoint(x: gx + gw, y: gy + gh * CGFloat(r) / 3)) }
            }.stroke(YoseColor.sumi, lineWidth: 1.5)
            Circle().fill(YoseColor.shu).frame(width: w * 0.045).position(x: gx + gw * 0.125, y: gy + gh * 0.17)               // 1月だけの小さな印
            ForEach([0.3, 0.62], id: \.self) { x in chair(w, h, x: x) }
        }
    }
    private func chair(_ w: CGFloat, _ h: CGFloat, x: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(YoseColor.ginNezu).frame(width: w * 0.11, height: h * 0.04).offset(x: 0, y: h * 0.12)           // 座面
            Rectangle().fill(YoseColor.ginNezu).frame(width: w * 0.11, height: h * 0.1).offset(x: 0, y: 0)                   // 背もたれ
            Rectangle().fill(YoseColor.haiSumi).frame(width: 3, height: h * 0.16).offset(x: w * 0.01, y: h * 0.16)
            Rectangle().fill(YoseColor.haiSumi).frame(width: 3, height: h * 0.16).offset(x: w * 0.096, y: h * 0.16)
        }.frame(width: w * 0.11, height: h * 0.32, alignment: .topLeading).position(x: x * w + w * 0.055, y: h * 0.78)
    }

    // #5 年表10行（決勝に出た年の行だけ金の縁）・一番下に幕の線
    private func tenYearsClose(_ w: CGFloat, _ h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            YoseColor.kinari
            ForEach(1...10, id: \.self) { y in
                let gold = goldRows.contains(y)
                Rectangle().fill(YoseColor.washi).frame(width: w * 0.7, height: h * 0.065)
                    .overlay(Rectangle().stroke(gold ? YoseColor.kin : YoseColor.sumi.opacity(0.35), lineWidth: gold ? 2.5 : 1))
                    .overlay(alignment: .leading) { Rectangle().fill(gold ? YoseColor.kin : YoseColor.sumi.opacity(0.4)).frame(width: w * 0.06, height: 3).padding(.leading, 8) }
                    .offset(x: w * 0.15, y: h * (0.04 + 0.083 * CGFloat(y - 1)))
            }
            HStack(spacing: 0) {                                                                                                // 幕の線
                ForEach(0..<12, id: \.self) { i in Rectangle().fill(i % 3 == 0 ? YoseColor.kuroUrushi : (i % 3 == 1 ? YoseColor.shu : YoseColor.tokiwa)) }
            }.frame(width: w * 0.7, height: max(4, h * 0.02)).offset(x: w * 0.15, y: h * 0.9)
        }
    }

    // #6 舞台中央のスタンドマイク・上から差す光・左右に並ぶ二つの影
    private func tenYearsTrue(_ w: CGFloat, _ h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [YoseColor.kuroUrushi, Color(hex: 0x3A2420)], startPoint: .top, endPoint: .bottom)
            Path { p in
                p.move(to: CGPoint(x: w * 0.44, y: 0)); p.addLine(to: CGPoint(x: w * 0.56, y: 0))
                p.addLine(to: CGPoint(x: w * 0.8, y: h * 0.9)); p.addLine(to: CGPoint(x: w * 0.2, y: h * 0.9)); p.closeSubpath()
            }.fill(LinearGradient(colors: [YoseColor.kinBright.opacity(0.55), YoseColor.kinBright.opacity(0.12)], startPoint: .top, endPoint: .bottom))
            Rectangle().fill(Color(hex: 0x4A332C)).frame(width: w, height: h * 0.12).offset(y: h * 0.88)                       // 舞台の床
            Rectangle().fill(YoseColor.kinari).frame(width: max(3, w * 0.012), height: h * 0.44).position(x: w * 0.5, y: h * 0.62)
            Circle().fill(YoseColor.kinari).frame(width: w * 0.05).position(x: w * 0.5, y: h * 0.38)
            Capsule().fill(YoseColor.kinari).frame(width: w * 0.1, height: h * 0.025).position(x: w * 0.5, y: h * 0.85)
            shadow(w, h, x: 0.34, y: 0.76, width: w * 0.05, height: h * 0.34, opacity: 0.8)
            shadow(w, h, x: 0.66, y: 0.76, width: w * 0.05, height: h * 0.34, opacity: 0.8)
        }
    }

    // #7 勇退：楽屋の壁に掛けた二着の衣装（ハンガーラック）・床に残った紙吹雪・ハリウッドミラーの電球
    private func championRetire(_ w: CGFloat, _ h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(hex: 0x2A2230), Color(hex: 0x4A3A3E)], startPoint: .top, endPoint: .bottom)
            Rectangle().fill(Color(hex: 0x2B2024)).frame(width: w, height: h * 0.26).offset(y: h * 0.74)               // 床
            // ミラーの電球（上辺に並ぶ）
            ForEach(0..<9, id: \.self) { i in
                Circle().fill(YoseColor.kinBright).frame(width: w * 0.03, height: w * 0.03)
                    .shadow(color: YoseColor.kinBright.opacity(0.7), radius: 6)
                    .offset(x: w * (0.14 + 0.09 * CGFloat(i)), y: h * 0.07)
            }
            // ハンガーラックの横棒
            Rectangle().fill(YoseColor.kin).frame(width: w * 0.62, height: max(3, h * 0.014)).offset(x: w * 0.19, y: h * 0.22)
            Rectangle().fill(YoseColor.kin).frame(width: max(3, h * 0.014), height: h * 0.54).offset(x: w * 0.19, y: h * 0.22)
            Rectangle().fill(YoseColor.kin).frame(width: max(3, h * 0.014), height: h * 0.54).offset(x: w * 0.81, y: h * 0.22)
            // 二着の衣装（紋付の黒と朱の羽織）
            ForEach(0..<2, id: \.self) { i in
                let x = w * (i == 0 ? 0.32 : 0.56)
                Path { p in
                    p.move(to: CGPoint(x: x + w * 0.06, y: h * 0.22)); p.addLine(to: CGPoint(x: x + w * 0.06, y: h * 0.27))
                }.stroke(YoseColor.kin, lineWidth: 2)
                Path { p in
                    p.move(to: CGPoint(x: x + w * 0.06, y: h * 0.27))
                    p.addLine(to: CGPoint(x: x + w * 0.0, y: h * 0.33)); p.addLine(to: CGPoint(x: x + w * 0.0, y: h * 0.62))
                    p.addLine(to: CGPoint(x: x + w * 0.12, y: h * 0.62)); p.addLine(to: CGPoint(x: x + w * 0.12, y: h * 0.33)); p.closeSubpath()
                }.fill(i == 0 ? YoseColor.kuroUrushi : YoseColor.shu)
                Circle().fill(YoseColor.kinari.opacity(0.85)).frame(width: w * 0.022, height: w * 0.022).offset(x: x + w * 0.049, y: h * 0.4)   // 紋
            }
            // 床の紙吹雪
            ForEach(0..<26, id: \.self) { i in
                let colors: [Color] = [YoseColor.shu, YoseColor.kinBright, YoseColor.washi, YoseColor.tokiwa]
                Rectangle().fill(colors[i % 4]).frame(width: w * 0.022, height: w * 0.012)
                    .rotationEffect(.degrees(Double((i * 53) % 180)))
                    .offset(x: w * (0.05 + 0.9 * CGFloat((i * 37) % 26) / 26), y: h * (0.78 + 0.18 * CGFloat((i * 11) % 7) / 7))
            }
        }
    }

    // #8 ファミレスの四人掛けの席・向かい合う二つの影・間の席のトロフィー
    private func championPair(_ w: CGFloat, _ h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(hex: 0xF0E3C4), Color(hex: 0xD9C397)], startPoint: .top, endPoint: .bottom)
            Rectangle().fill(Color(hex: 0xB8D4E0).opacity(0.7)).frame(width: w * 0.6, height: h * 0.28).offset(x: w * 0.2, y: h * 0.06)   // 窓
            RoundedRectangle(cornerRadius: 10).fill(YoseColor.washi).frame(width: w * 0.58, height: h * 0.2)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(YoseColor.sumi, lineWidth: 2))
                .offset(x: w * 0.21, y: h * 0.58)                                                                                       // テーブル
            shadow(w, h, x: 0.17, y: 0.58, width: w * 0.06, height: h * 0.34, opacity: 0.75)
            shadow(w, h, x: 0.83, y: 0.58, width: w * 0.06, height: h * 0.34, opacity: 0.75)
            Path { p in                                                                                                                 // トロフィー（台形＋円）
                p.move(to: CGPoint(x: w * 0.455, y: h * 0.42)); p.addLine(to: CGPoint(x: w * 0.545, y: h * 0.42))
                p.addLine(to: CGPoint(x: w * 0.52, y: h * 0.56)); p.addLine(to: CGPoint(x: w * 0.48, y: h * 0.56)); p.closeSubpath()
            }.fill(YoseColor.kinBright).overlay(Path { p in p.addEllipse(in: CGRect(x: w * 0.455, y: h * 0.38, width: w * 0.09, height: h * 0.07)) }.fill(YoseColor.kinBright))
            Rectangle().fill(YoseColor.kin).frame(width: w * 0.1, height: h * 0.02).offset(x: w * 0.45, y: h * 0.56)
        }
    }
}

// MARK: - 図鑑

struct EndingGalleryView: View {
    var onClose: () -> Void
    @State private var seen: [EndingID: EndingRecord] = EndingBook.load()
    @State private var replaying: EndingID?

    var body: some View {
        ZStack {
            YoseColor.kinari.ignoresSafeArea()
            VStack(spacing: 0) {
                YoseHeaderBar(title: "エンディング図鑑", subtitle: "\(seen.count) / \(EndingID.allCases.count)", closeAction: onClose)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(EndingID.allCases) { id in cell(id) }
                    }
                    .padding(.horizontal, YoseMetrics.screenMargin).padding(.vertical, 16)
                }
            }
        }
        .onAppear { seen = EndingBook.load() }
        .fullScreenCover(item: $replaying) { id in
            EndingFlowView(session: nil, ending: id, replay: true, onFinish: { replaying = nil })
        }
    }

    private func cell(_ id: EndingID) -> some View {
        let rec = seen[id]
        return Button { if rec != nil { replaying = id } } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    if rec != nil {
                        EndingArt(id: id)
                    } else {
                        YoseColor.ginNezu
                        EndingArt(id: id).brightness(-1).opacity(0.16)        // 影絵だけ
                        Text("？？？").font(YoseFont.mincho(22)).foregroundStyle(YoseColor.haiSumi)
                    }
                }
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .overlay(Rectangle().stroke(rec != nil ? id.kind.color : YoseColor.kiDark, lineWidth: 2.5))
                HStack(spacing: 5) {
                    Text("No.\(id.number)").font(YoseFont.captionBold).foregroundStyle(YoseColor.haiSumi)
                    if rec != nil {
                        Text(id.kind.label).font(YoseFont.gothic(12, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.85).foregroundStyle(.white)
                            .padding(.horizontal, 5).padding(.vertical, 1).background(id.kind.color)
                    }
                }
                if let rec {
                    Text(id.title).font(YoseFont.mincho(15)).foregroundStyle(YoseColor.sumi).lineLimit(1)
                    Text("\(Self.dateText(rec.firstSeenAt))　\(rec.count)回　相方：\(rec.lastPartnerName)")
                        .font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.haiSumi).lineLimit(1).minimumScaleFactor(0.7)
                } else {
                    Text("？？？").font(YoseFont.mincho(15)).foregroundStyle(YoseColor.haiSumi)
                    Text(id.hint).font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
                        .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)   // 同じ段の札の背丈をそろえる（ui_audit_1019 §1）
            .yoseHarigami()
            .contentShape(Rectangle())   // 枠の全体を押せる
        }
        .buttonStyle(.plain)
    }

    private static func dateText(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.dateFormat = "yyyy/M/d"
        return f.string(from: d)
    }
}

// MARK: - 設定の「解散」の後の別れの場面（オーナー決定 10/20・図鑑に入れない）

/// 場面カード1枚→この周の最高成績1行→タイトルへ。EndingBook には記録しない（連打で図鑑が埋まるのを防ぐ）
struct DisbandFarewellView: View {
    let bestLine: String?
    var onFinish: () -> Void
    @State private var showSummary = false

    static let card = ReminiscenceCard(
        caption: "夕方。いつもの稽古場。", mood: .after,
        talk: [Advice(name: "俺", text: "話がある。コンビは今日で終わりにしよう"),
               Advice(name: "谷口", text: "……そっか。わかった"),
               Advice(name: "谷口", text: "今までありがとう。体には気をつけてね"),
               Advice(name: "俺", text: "そっちもね。じゃあ、また")],
        together: true, backdrop: EventBackdrop(.keikoba, .evening))

    var body: some View {
        ZStack {
            if showSummary { summary } else {
                ReminiscencePlayer(cards: [Self.card], title: "解散", onComplete: {
                    withAnimation(.easeInOut(duration: 0.4)) { showSummary = true }
                })
            }
        }
        .transition(.opacity)
        #if DEBUG
        .onAppear { if ProcessInfo.processInfo.environment["MZ_ENDSTEP"] == "art" { showSummary = true } }   // 目視用: 成績の一行へ直行
        #endif
    }

    private var summary: some View {
        ZStack {
            LinearGradient(colors: [YoseColor.kuroUrushi, YoseColor.enji.opacity(0.8)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 14) {
                Spacer()
                VStack(spacing: 14) {
                    Text("この周の最高成績").font(YoseFont.gothic(13, weight: .bold)).foregroundStyle(YoseColor.kin)
                    Text(bestLine ?? "大会の記録はまだない").font(YoseFont.mincho(20)).foregroundStyle(YoseColor.kinari)
                        .multilineTextAlignment(.center).padding(.horizontal, 28)
                }
                .accessibilityElement(children: .combine)
                Spacer()
                Button(action: onFinish) { Text("タイトルへ ▶") }
                    .accessibilityLabel("タイトルへ")
                    .buttonStyle(YoseButtonStyle(.primary))
                    .padding(.horizontal, 14).padding(.bottom, 30)
            }
        }
    }
}
