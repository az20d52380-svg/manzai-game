// StageViews.swift
// 大会まわりの入口・本番前カード・笑い波形メーター（mockup SCREEN 02）。
// 判定ロジックは GameCore のまま（絶対評価ライン）。ここは表示・演出だけ。

import SwiftUI
import GameCore

// MARK: 笑い波形メーター（mockupのcanvasをCanvasで再現）

struct WaveformView: View {
    /// 結果連動: 通過=暖色で大きく育ちオチで跳ねる／敗退=寒色でフラット・疎ら（mvp §7）
    var passed: Bool = true
    /// 敗退時の"惜しさ" 0..1（1＝あと一歩）。負けの波形を距離で変える（監査E-03）
    var nearMiss: Double = 0
    /// 判の後に小さく出す客席メーター（舞台の上・見た目の作り直し v1 §6 R1）
    var compact: Bool = false
    /// ハマった夜（見える運・canonical_v2 §1「ハマは波形で必ず可視化」）：中盤に客席のスイッチが入った山が立つ。勝敗とも
    var burst: Bool = false
    /// 左から右へ走り込む進み（compact のみ・登場時0.6秒）
    @State private var runIn: CGFloat = 1

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let W = size.width, H = size.height, mid = H / 2
                if compact { ctx.clip(to: Path(CGRect(x: 0, y: 0, width: W * runIn, height: H))) }
                // 中心線
                var base = Path()
                base.move(to: CGPoint(x: 0, y: mid)); base.addLine(to: CGPoint(x: W, y: mid))
                ctx.stroke(base, with: .color(compact ? Theme.ink.opacity(0.12) : .white.opacity(0.10)), lineWidth: 1)

                let warm = [Theme.gold, Theme.cExpr, Theme.verm]
                let cold = [Color(hex: 0xAEB4C4), Color(hex: 0x8890A4)]
                let grad = GraphicsContext.Shading.linearGradient(
                    Gradient(colors: compact && passed ? [Color(hex: 0xE04028)] : (passed ? warm : cold)),
                    startPoint: .zero, endPoint: CGPoint(x: W, y: 0))

                func env(_ x: Double) -> Double {
                    let surge = burst ? exp(-pow((x - 0.45) / 0.07, 2)) * 0.7 : 0   // ハマった夜の中盤の山
                    if !passed { return min(1, 0.10 + 0.30 * nearMiss * x + 0.06 * sin(x * 8) + surge) }   // 敗退: 惜しいほど後半が盛り上がる（監査E-03）
                    let b = 0.16 + 0.5 * x
                    let punch = exp(-pow((x - 0.83) / 0.06, 2)) * 0.95
                    return min(1, b + punch + surge)
                }
                var top = Path()
                var i: CGFloat = 0
                while i <= W {
                    let x = Double(i / W)
                    let a = env(x)
                    let jit = sin(Double(i) * 0.5 + t * 6) * a * 3
                    let y = Double(mid) - (a * Double(mid - 10)) * (0.5 + 0.5 * abs(sin(Double(i) * 0.4 + t * 5))) - jit
                    let p = CGPoint(x: i, y: y)
                    if i == 0 { top.move(to: p) } else { top.addLine(to: p) }
                    i += 3
                }
                ctx.stroke(top, with: grad, style: StrokeStyle(lineWidth: 3, lineJoin: .round))

                var bottom = Path()
                i = 0
                while i <= W {
                    let x = Double(i / W)
                    let a = env(x)
                    let y = Double(mid) + (a * Double(mid - 10)) * (0.5 + 0.5 * abs(sin(Double(i) * 0.4 + t * 5)))
                    let p = CGPoint(x: i, y: y)
                    if i == 0 { bottom.move(to: p) } else { bottom.addLine(to: p) }
                    i += 3
                }
                ctx.opacity = 0.4
                ctx.stroke(bottom, with: grad, style: StrokeStyle(lineWidth: 3, lineJoin: .round))
            }
        }
        .frame(height: compact ? 44 : 104)
        .overlay(alignment: .bottom) {
            if !compact {
                HStack {
                    Text("ツカミ"); Spacer(); Text("中盤"); Spacer(); Text("オチ")
                }
                .font(.maru(10)).foregroundStyle(.white.opacity(0.45)).offset(y: 14)
            }
        }
        .padding(compact ? 2 : 12)
        // compact（結果画面）は枠も地も無し＝波形を舞台床に直接走らせる。大きい版は暖色のダークガラス
        .background(compact ? AnyShapeStyle(Color.clear) : AnyShapeStyle(Theme.lowerThird.opacity(0.85)),
                    in: RoundedRectangle(cornerRadius: 18))
        .overlay { if !compact { RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.14), lineWidth: 1.5) } }
        .shadow(color: .black.opacity(compact ? 0 : 0.30), radius: compact ? 0 : 12, y: compact ? 0 : 8)
        .onAppear {
            guard compact else { return }
            runIn = 0
            withAnimation(.easeOut(duration: 0.6)) { runIn = 1 }
        }
    }
}

// MARK: 大会入口（遠征選択・道中大会）
// 見た目の作り直し v1 §6 T1：楽屋（昼の稽古場）に大会の張り紙＝本番の前の明るい時間。ピンク地の入力フォームをやめる。

/// 大会看板（黒漆の地・消金の二重枠・墨のハードシャドウ＝design_system_argon_v1 §7-型D）
struct TournamentPoster: View {
    let tag: String
    let name: String
    var body: some View {
        VStack(spacing: 6) {
            YoseTag(text: tag, style: .solidEnji)
            Text(name).font(YoseFont.bannerTitle).foregroundStyle(YoseColor.kin)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 26).padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(YoseColor.kuroUrushi)
        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
        .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1.5).padding(3))
        .background(alignment: .bottom) { Rectangle().fill(YoseColor.sumi).offset(y: 3) }
        .padding(.horizontal, 32)
    }
}

/// 入口・本番前の共通の上段＝稽古場の場面＋張り紙
private struct EntryHeader: View {
    let tag: String
    let name: String
    var body: some View {
        StageScene(showPoster: false)
            .frame(minHeight: 344, maxHeight: 400)   // 看板（上64pt＋約84pt）が二人の頭に被らない高さ
            .overlay(alignment: .top) { TournamentPoster(tag: tag, name: name).padding(.top, 58) }
            .overlay(alignment: .bottom) { Rectangle().fill(YoseColor.sumi).frame(height: 2.5) }
            .clipped()
            .ignoresSafeArea(edges: .top)
    }
}

/// 通過ライン ▶ いまの実力 の対比木札（％は出さない・賞金と週は角札）
private struct LineBoard: View {
    let week: Int
    let line: Int
    let power: Int
    var prize: String? = nil
    /// 左端の朱札（GP本番前は「頂GP 決勝」等）。nil なら出さない
    var stageTag: String? = nil
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                if let stageTag { YoseTag(text: stageTag, style: .solidEnji) }
                YoseTag(text: "第\(week)週", style: .outlineSumi)
                Spacer()
                if let prize { YoseTag(text: "賞金 \(prize)", style: .outlineKin) }
            }
            HStack(alignment: .center, spacing: 12) {
                Spacer(minLength: 0)
                Text("通過ライン").font(YoseFont.bodyBold).foregroundStyle(YoseColor.sumi)
                Text("\(line)").font(YoseFont.numLarge).foregroundStyle(YoseColor.sumi)
                Text("▶").font(YoseFont.gothic(14, weight: .black)).foregroundStyle(YoseColor.haiSumi)
                // 木札の中に木札を入れない：実力は平らな角札ラベル＋大きな数字を同じ札の上に直接並べる
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("実力").font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.enji)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(YoseColor.enji.opacity(0.12))
                        .overlay(Rectangle().stroke(YoseColor.enji, lineWidth: 1))
                    Text("\(power)").font(YoseFont.number(30, weight: .black)).foregroundStyle(YoseColor.sumi)
                }
                if power < line { YoseTag(text: "あと\(line - power)不足", style: .outlineShu) }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, YoseMetrics.padH).padding(.vertical, YoseMetrics.padV)
        .frame(maxWidth: .infinity)
        .yoseKifuda()
    }
}

struct TournamentEntryView: View {
    @Bindable var session: GameSession
    let spec: TournamentSpec

    var body: some View {
        VStack(spacing: 14) {
            EntryHeader(tag: spec.osaka ? "大阪遠征" : "エントリー", name: spec.name)

            // 監査B-04: 通過ラインと同じ単位（実力値＋相性）で「いまの実力」を並べる。ブレ・ネタ補正は出さない。
            // G4: 大会結果でも同じ2つを同じ大きさで再掲する（大きくしない＝見込みに寄せない・X2-02）
            LineBoard(week: spec.week, line: Int(spec.line),
                      power: Int((GameEngine.jitsuryoku(session.state, config: session.config) + session.state.compat).rounded()),
                      prize: Yen.man(spec.prize))
                .padding(.horizontal, YoseMetrics.screenMargin)

            // 今夜かけるネタ（v2 §4-1補・golden非干渉＝state参照のみ・尺マッチは表示のみで合否に効かせない）
            NetaPickRow(session: session, title: "今夜かけるネタ", requiredLength: NetaCatalog.lengthForTournament,
                        selected: session.selectedNeta, onSelect: { session.selectNeta($0) })
                .padding(.horizontal, YoseMetrics.screenMargin)

            Spacer(minLength: 8)
            // 出場の前に今の体力と所持金が見えるように（遠征費を払えるか・体力を使ってよいかの判断材料）
            YoseVitalMoneyBar(stamina: Int(session.state.stamina.rounded()), maxStamina: 100, money: session.state.money,
                              staminaColor: session.state.stamina <= 40 ? YoseColor.shu : YoseColor.tokiwa)
            VStack(spacing: 10) {
                // 押せるまま・結果を言葉で明示（ネタ無しでも出られる決まり）
                if session.selectedNeta == nil || session.state.stamina <= 0 {
                    Text([session.selectedNeta == nil ? "ネタ無しで出る（上乗せなし）" : nil,
                          session.state.stamina <= 0 ? "体力が尽きた状態で出る" : nil].compactMap { $0 }.joined(separator: "・"))
                        .font(YoseFont.captionBold).foregroundStyle(YoseColor.shu)
                        .frame(maxWidth: .infinity).padding(.vertical, 5)
                        .background(YoseColor.shu.opacity(0.12))
                        .overlay(Rectangle().stroke(YoseColor.shu, lineWidth: 1.5))
                }
                let fee = session.config.calendar.entryFee   // 13§3: 交通費＋エントリー費を払えない遠征は無効化＝無言落ちを止める
                if spec.osaka {
                    let busTotal = session.config.calendar.busTravel.cost + fee
                    let trainTotal = session.config.calendar.trainTravel.cost + fee
                    entryButton("夜行バスで出場", glyph: "bus.fill", sub: "¥\(busTotal.formatted())（交通費＋参加費）・体力を使う",
                                enabled: session.state.money >= busTotal) { session.decideTournament(.夜行バス) }
                    entryButton("新幹線で出場", glyph: "tram.fill", sub: "¥\(trainTotal.formatted())（交通費＋参加費）・体力温存",
                                enabled: session.state.money >= trainTotal) { session.decideTournament(.新幹線) }
                } else {
                    let cost = fee   // 東京開催は参加費のみ（WeekRunner.resolveTournament と同じ条件・監査G-05）
                    entryButton("出場する", glyph: "mic.fill", sub: "東京開催・参加費 ¥\(cost.formatted())",
                                enabled: session.state.money >= cost) { session.decideTournament(.夜行バス) }
                }
                Button { session.decideTournament(nil) } label: { Text("見送る") }
                    .buttonStyle(YoseButtonStyle(.secondary)).frame(width: 150)
            }
            .padding(.horizontal, YoseMetrics.screenMargin).padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(YoseColor.kinari.ignoresSafeArea())
    }

    /// 出場ボタン（物理ボタン。費用は交通費＋参加費の合計・B13）。払えない時は押せない表示で理由を出す
    private func entryButton(_ title: String, glyph: String, sub: String, enabled: Bool = true, _ action: @escaping () -> Void) -> some View {
        Button(action: { if enabled { action() } }) {
            HStack(spacing: 12) {
                Image(systemName: glyph).font(.system(size: 17, weight: .bold))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(YoseFont.buttonMain)
                    Text(enabled ? sub : "残高不足で出られない").font(YoseFont.captionBold)
                        .foregroundStyle(enabled ? YoseColor.haiSumi : YoseColor.shu)
                        .lineLimit(2).minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 40)
        }
        .buttonStyle(YoseButtonStyle(.secondary))
        .disabled(!enabled)
    }
}

// MARK: GP本番前カード（回戦・敗者復活・決勝の「本番へ」）

struct StagePreludeView: View {
    @Bindable var session: GameSession
    let title: String
    /// 決勝のみ2本目の枠も出す（v2 §4-2「決勝2本制」・表示/戦績のみ・Phase 0ではスコア非干渉）
    var isFinal: Bool = false
    /// この舞台の目安尺（v2 §4-1補・表示のみ）。nil なら尺の言及をしない
    var requiredLength: NetaLength? = nil

    /// 表示用の通過ライン（名目値。結果画面と同じ単位）。回戦＝その週／敗者復活／決勝。見つからなければ出さない
    private var nominalLine: Int? {
        let cal = session.config.calendar
        if isFinal { return Int(cal.gpFinalLine) }
        if title == "敗者復活" { return Int(cal.gpRevivalLine) }
        return cal.gpRounds.first { $0.week == session.week }.map { Int($0.line) }
    }
    /// 本番へボタンの下に出す一言＝押せるまま・結果を言葉で明示（ネタ無しは上乗せなし）
    private var goNote: String? {
        if session.selectedNeta == nil { return "ネタ無しで出る（上乗せなし）" }
        if isFinal && session.selectedNeta2 == nil { return "2本目は選ばずに進む" }
        return nil
    }

    var body: some View {
        VStack(spacing: 14) {
            EntryHeader(tag: "頂 グランプリ", name: title)

            // ゲームが持っている事実だけ：通過ライン▶いまの実力（審査傾向のような元データの無い物は置かない・％なし）
            if let line = nominalLine {
                LineBoard(week: session.week, line: line,
                          power: Int((GameEngine.jitsuryoku(session.state, config: session.config) + session.state.compat).rounded()),
                          stageTag: isFinal ? "頂GP 決勝" : (title == "敗者復活" ? "敗者復活" : "頂GP 回戦"))
                    .padding(.horizontal, YoseMetrics.screenMargin)
            }

            // 今夜かけるネタ（v2 §4-1補/§4-2・golden非干渉）
            VStack(spacing: 10) {
                NetaPickRow(session: session, title: isFinal ? "決勝・1本目" : "今夜かけるネタ",
                            requiredLength: requiredLength, selected: session.selectedNeta,
                            onSelect: { session.selectNeta($0) })
                if isFinal {
                    NetaPickRow(session: session, title: "決勝・2本目（温存の一手）",
                                requiredLength: requiredLength, selected: session.selectedNeta2,
                                onSelect: { session.selectNeta2($0) })
                }
            }
            .padding(.horizontal, YoseMetrics.screenMargin)

            Spacer(minLength: 8)
            YoseVitalMoneyBar(stamina: Int(session.state.stamina.rounded()), maxStamina: 100, money: session.state.money,
                              staminaColor: session.state.stamina <= 40 ? YoseColor.shu : YoseColor.tokiwa)
            Button {
                session.advanceAuto()
            } label: {
                VStack(spacing: 2) {
                    Text("本番へ ▶").font(YoseFont.gothic(18, weight: .heavy))
                    if let note = goNote {
                        Text(note).font(YoseFont.captionBold).foregroundStyle(YoseColor.kinari.opacity(0.9))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(YoseButtonStyle(.primary)).padding(.horizontal, YoseMetrics.screenMargin).padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(YoseColor.kinari.ignoresSafeArea())
    }
}
