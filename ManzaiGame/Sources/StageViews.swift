// StageViews.swift
// 大会まわりの入口・本番前カード・笑い波形メーター（mockup SCREEN 02）。
// 判定ロジックは GameCore のまま（絶対評価ライン）。ここは表示・演出だけ。

import SwiftUI
import GameCore

// MARK: 笑い波形メーター（mockupのcanvasをCanvasで再現）

struct WaveformView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        TimelineView(.animation(minimumInterval: nil, paused: reduceMotion)) { timeline in
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
        // 場面の下端がカード列にぴたり付くよう、レイアウト上の高さは Color.clear で決め、場面は背景として上端（安全領域）まで伸ばす
        Color.clear
            .frame(minHeight: 290, maxHeight: 430)   // 看板（上58pt＋約84pt）が二人の頭に被らない高さ
            .background(alignment: .top) {
                StageScene(showPoster: false)
                    .overlay(alignment: .top) { TournamentPoster(tag: tag, name: name).padding(.top, 58) }
                    .overlay(alignment: .top) {   // ステータスバー帯は臙脂の定式幕色＋金の罫（画面最上部の黒い空きを無くす）
                        YoseColor.enji.frame(height: 52)
                            .overlay(alignment: .bottom) { Rectangle().fill(YoseColor.kin).frame(height: 1.5) }
                    }
                    .overlay(alignment: .bottom) { Rectangle().fill(YoseColor.sumi).frame(height: 2.5) }
                    .clipped()
                    .ignoresSafeArea(edges: .top)
            }
    }
}

/// 週・賞金の木札（実力の数字と通過ラインは出さない）
private struct LineBoard: View {
    let week: Int
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
        }
        .padding(.horizontal, YoseMetrics.padH).padding(.vertical, YoseMetrics.padV)
        .frame(maxWidth: .infinity)
        .yoseKifuda()
    }
}

struct TournamentEntryView: View {
    @Bindable var session: GameSession
    let spec: TournamentSpec
    @State private var hint: HintSpec?   // 初めて大会に出る時だけの説明（右上の「？」で読み返せる）

    /// 大会エントリーの用語説明（金額・体力は GameConfig から読む）
    static func hintSpec(_ cal: CalendarConfig) -> HintSpec {
        HintSpec(key: "entry", title: "大会エントリー", rows: [
            .init(term: "エントリー費", text: "出るだけで\(cal.entryFee.formatted())円かかる。足りないと出られない。"),
            .init(term: "交通費", text: "大阪の大会だけ。夜行バスは\(cal.busTravel.cost.formatted())円で体力を\(Int(-cal.busTravel.stamina))使う。新幹線は\(cal.trainTravel.cost.formatted())円で体力はそのまま。"),
            .init(term: "体力", text: "大会に出るのにも使う。0のまま出ることもできる。"),
        ])
    }

    var body: some View {
        VStack(spacing: 14) {
            EntryHeader(tag: spec.osaka ? "大阪遠征" : "エントリー", name: spec.name)
                .overlay(alignment: .topTrailing) {
                    HintMarkButton { hint = Self.hintSpec(session.config.calendar) }.padding(.trailing, 6).padding(.top, 4)
                }

            // G4: 大会結果でも同じ2つを同じ大きさで再掲する（大きくしない＝見込みに寄せない・X2-02）
            LineBoard(week: spec.week, prize: Yen.man(spec.prize))
                .padding(.horizontal, YoseMetrics.screenMargin)

            // 今夜かけるネタ（v2 §4-1補・golden非干渉＝state参照のみ・尺マッチは表示のみで合否に効かせない）
            NetaPickRow(session: session, title: "今夜かけるネタ", requiredLength: NetaCatalog.lengthForTournament,
                        selected: session.selectedNeta, onSelect: { session.selectNeta($0) })
                .padding(.horizontal, YoseMetrics.screenMargin)
                .onAppear { session.ensureStageNetaDefault() }

            Spacer(minLength: 8)
            // 出場の前に今の体力と所持金が見えるように（遠征費を払えるか・体力を使ってよいかの判断材料）
            YoseVitalMoneyBar(stamina: Int(session.state.stamina.rounded()), maxStamina: 100, money: session.state.money,
                              staminaColor: session.state.stamina <= 40 ? YoseColor.shu : Color(hex: 0x3B7A4E))
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
                    entryButton("夜行バスで出場", glyph: "bus.fill", sub: "¥\(busTotal.formatted())（交通費＋エントリー費）・体力を使う",
                                enabled: session.state.money >= busTotal) { session.decideTournament(.夜行バス) }
                    entryButton("新幹線で出場", glyph: "tram.fill", sub: "¥\(trainTotal.formatted())（交通費＋エントリー費）・体力温存",
                                enabled: session.state.money >= trainTotal) { session.decideTournament(.新幹線) }
                } else {
                    let cost = fee   // 東京開催はエントリー費のみ（WeekRunner.resolveTournament と同じ条件・監査G-05）
                    entryButton("出場する", glyph: "mic.fill", sub: "東京開催・エントリー費 ¥\(cost.formatted())",
                                enabled: session.state.money >= cost) { session.decideTournament(.夜行バス) }
                }
                Button { session.decideTournament(nil) } label: { Text("見送る") }
                    .buttonStyle(YoseButtonStyle(.secondary))
            }
            .padding(.horizontal, YoseMetrics.screenMargin).padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(YoseColor.kinari.ignoresSafeArea())
        .overlay { if let h = hint { HintModal(spec: h) { OneTimeHint.markDone(h.key); hint = nil } } }
        .overlay {   // 療養明けが大会の入口に重なった週は、体調ダウンの知らせを入口より先に出す（表示の順だけ・判定不変）
            if session.injuryNoticeWeeks > 0 {
                YoseModal(title: "体調ダウン", primaryTitle: "わかった", primaryAction: { session.clearInjuryNotice() }, cancelTitle: nil) {
                    Text("無理がたたって、体を壊した。しばらく療養で動けなかった。その間のバイト代は入らない。体力が低い時の稽古やキツいバイトは、体を壊しやすい。")
                        .font(YoseFont.gothic(15, weight: .bold)).foregroundStyle(YoseColor.sumi)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .task {
            let h = Self.hintSpec(session.config.calendar)
            if !OneTimeHint.suppressedForDebug, !OneTimeHint.isDone(h.key) {
                try? await Task.sleep(nanoseconds: 450_000_000)
                hint = h
            }
        }
    }

    /// 出場ボタン（物理ボタン。費用は交通費＋エントリー費の合計・B13）。払えない時は押せない表示で理由を出す
    private func entryButton(_ title: String, glyph: String, sub: String, enabled: Bool = true, _ action: @escaping () -> Void) -> some View {
        Button(action: { if enabled { action() } }) {
            HStack(spacing: 12) {
                Image(systemName: glyph).font(.system(size: Font.mzScaled(17), weight: .bold))
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

/// 大会名の表示変換（内部キー "GP1回戦" "GP決勝" 等は変えず、画面に出す所だけ「頂GP 1回戦」にする）
enum GPName {
    static func display(_ key: String) -> String {
        guard key.hasPrefix("GP") else { return key }
        return "頂GP " + key.dropFirst(2)
    }
    /// 狭い所用（空白なし）
    static func short(_ key: String) -> String {
        guard key.hasPrefix("GP") else { return key }
        return "頂" + key
    }
}

struct StagePreludeView: View {
    @Bindable var session: GameSession
    let title: String
    /// 決勝のみ2本目の枠も出す（v2 §4-2「決勝2本制」・表示/戦績のみ・Phase 0ではスコア非干渉）
    var isFinal: Bool = false
    /// この舞台の目安尺（v2 §4-1補・表示のみ）。nil なら尺の言及をしない
    var requiredLength: NetaLength? = nil

    /// 本番へボタンの下に出す一言＝押せるまま・結果を言葉で明示（ネタ無しは上乗せなし）
    private var goNote: String? {
        if session.selectedNeta == nil { return "ネタ無しで出る（上乗せなし）" }
        if isFinal && session.selectedNeta2 == nil { return "2本目は選ばずに進む" }
        return nil
    }

    var body: some View {
        VStack(spacing: 14) {
            EntryHeader(tag: "頂グランプリ", name: GPName.display(title))

            LineBoard(week: session.week,
                      stageTag: isFinal ? "頂GP 決勝" : (title == "敗者復活" ? "敗者復活" : "頂GP 回戦"))
                .padding(.horizontal, YoseMetrics.screenMargin)

            // 今夜かけるネタ（v2 §4-1補/§4-2・golden非干渉）
            VStack(spacing: 10) {
                NetaPickRow(session: session, title: isFinal ? "決勝・1本目" : "今夜かけるネタ",
                            requiredLength: requiredLength, selected: session.selectedNeta,
                            onSelect: { session.selectNeta($0) })
                    .onAppear { session.ensureStageNetaDefault() }
                if isFinal {
                    NetaPickRow(session: session, title: "決勝・2本目（温存の一手）",
                                requiredLength: requiredLength, selected: session.selectedNeta2,
                                onSelect: { session.selectNeta2($0) })
                }
            }
            .padding(.horizontal, YoseMetrics.screenMargin)

            Spacer(minLength: 8)
            YoseVitalMoneyBar(stamina: Int(session.state.stamina.rounded()), maxStamina: 100, money: session.state.money,
                              staminaColor: session.state.stamina <= 40 ? YoseColor.shu : Color(hex: 0x3B7A4E))
            Button {
                session.advanceAuto()
            } label: {
                VStack(spacing: 2) {
                    Text("本番へ ▶").font(YoseFont.gothic(18, weight: .heavy))
                    if let note = goNote {
                        Text(note).font(YoseFont.gothic(11, weight: .bold)).foregroundStyle(YoseColor.kinBright)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(YoseColor.kuroUrushi.opacity(0.45))
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
