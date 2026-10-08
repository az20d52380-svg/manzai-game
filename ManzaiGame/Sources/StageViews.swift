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

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let W = size.width, H = size.height, mid = H / 2
                // 中心線
                var base = Path()
                base.move(to: CGPoint(x: 0, y: mid)); base.addLine(to: CGPoint(x: W, y: mid))
                ctx.stroke(base, with: .color(compact ? Theme.ink.opacity(0.12) : .white.opacity(0.10)), lineWidth: 1)

                let warm = [Theme.gold, Theme.cExpr, Theme.verm]
                let cold = [Color(hex: 0xAEB4C4), Color(hex: 0x8890A4)]
                let grad = GraphicsContext.Shading.linearGradient(
                    Gradient(colors: passed ? warm : cold),
                    startPoint: .zero, endPoint: CGPoint(x: W, y: 0))

                func env(_ x: Double) -> Double {
                    if !passed { return 0.10 + 0.30 * nearMiss * x + 0.06 * sin(x * 8) }   // 敗退: 惜しいほど後半が盛り上がる（監査E-03）
                    let b = 0.16 + 0.5 * x
                    let punch = exp(-pow((x - 0.83) / 0.06, 2)) * 0.95
                    return min(1, b + punch)
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
        .padding(compact ? 8 : 12)
        // 舞台の上の小さい客席メーター（compact）は明るい紙の地＝舞台の光の中で読める（紫のガラスはやめる・§4-1）。
        // 従来の大きい版は暖色のダークガラス（暗転画面の「客席モニタ」）
        .background(compact ? AnyShapeStyle(Theme.paperTop.opacity(0.95)) : AnyShapeStyle(Theme.lowerThird.opacity(0.85)),
                    in: RoundedRectangle(cornerRadius: compact ? 14 : 18))
        .overlay(RoundedRectangle(cornerRadius: compact ? 14 : 18)
            .stroke(compact ? Theme.paperEdge : .white.opacity(0.14), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.30), radius: compact ? 6 : 12, y: compact ? 4 : 8)
    }
}

// MARK: 大会入口（遠征選択・道中大会）
// 見た目の作り直し v1 §6 T1：楽屋（昼の稽古場）に大会の張り紙＝本番の前の明るい時間。ピンク地の入力フォームをやめる。

/// 稽古場の壁に貼られた大会の張り紙（めくり札の白紙＋墨・朱の札）
struct TournamentPoster: View {
    let tag: String
    let name: String
    var body: some View {
        VStack(spacing: 6) {
            Text(tag).font(.maru(.sub)).foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 3)
                .background(Theme.vermD, in: Capsule())
            Text(name).font(.maru(28, weight: .black)).foregroundStyle(Theme.sumi)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 26).padding(.vertical, 14)
        .background(Theme.mekuri, in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.paperEdge, lineWidth: 1.5))
        .overlay(alignment: .top) {
            // 画鋲2つ
            HStack(spacing: 120) { pin; pin }.offset(y: -5)
        }
        .rotationEffect(.degrees(-1.5))
        .shadow(color: Theme.ink.opacity(0.18), radius: 8, y: 4)
    }
    private var pin: some View {
        Circle().fill(Theme.verm).frame(width: 11, height: 11).overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1.5))
    }
}

/// 入口・本番前の共通の上段＝稽古場の場面＋張り紙
private struct EntryHeader: View {
    let tag: String
    let name: String
    var body: some View {
        StageScene()
            .frame(height: 300)
            .overlay(alignment: .top) { TournamentPoster(tag: tag, name: name).padding(.top, 64) }
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 2.5) }
            .clipped()
            .ignoresSafeArea(edges: .top)
    }
}

/// 情報の札（読める色＝ink on 白・sub 13）
private struct InfoPill: View {
    let text: String
    var body: some View {
        Text(text).font(.maru(.sub)).foregroundStyle(Theme.ink)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.white, in: Capsule())
            .overlay(Capsule().stroke(Theme.lineStrong, lineWidth: 1.5))
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
            HStack(spacing: 8) {
                InfoPill(text: "第\(spec.week)週")
                InfoPill(text: "通過ライン \(Int(spec.line)) ／ いまの実力 \(Int((GameEngine.jitsuryoku(session.state, config: session.config) + session.state.compat).rounded()))")
                InfoPill(text: "賞金 \(spec.prize / 10000)万")
            }
            .padding(.horizontal, 12)

            // 今夜かけるネタ（v2 §4-1補・golden非干渉＝state参照のみ・尺マッチは表示のみで合否に効かせない）
            NetaPickRow(session: session, title: "今夜かけるネタ", requiredLength: NetaCatalog.lengthForTournament,
                        selected: session.selectedNeta, onSelect: { session.selectNeta($0) })
                .padding(.horizontal, 20)

            Spacer(minLength: 8)
            VStack(spacing: 10) {
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
                Button { session.decideTournament(nil) } label: {
                    Text("見送る").font(.maru(.body)).foregroundStyle(Theme.inkSub).frame(minWidth: 120, minHeight: 44)
                }
                .buttonStyle(PressableStyle())
            }
            .padding(.horizontal, 20).padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bgGradient.ignoresSafeArea())
    }

    /// 出場カード（行動カードと同じ顔＝白・朱の縁・ハード影）。費用は交通費＋参加費の合計（B13）
    private func entryButton(_ title: String, glyph: String, sub: String, enabled: Bool = true, _ action: @escaping () -> Void) -> some View {
        Button(action: { if enabled { action() } }) {
            HStack(spacing: 12) {
                Image(systemName: glyph).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(enabled ? Theme.verm : Theme.inkFaint, in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.maru(.body)).foregroundStyle(enabled ? Theme.ink : Theme.inkSub)
                    Text(enabled ? sub : "残高不足で出られない").font(.maru(.sub)).foregroundStyle(enabled ? Theme.inkSub : Theme.vermD)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.inkSub)
            }
            .padding(.horizontal, 14).frame(maxWidth: .infinity, minHeight: 64)
            .background(enabled ? Theme.card : Color(hex: 0xF3EFE7), in: RoundedRectangle(cornerRadius: Theme.Rad.card))
            .overlay(RoundedRectangle(cornerRadius: Theme.Rad.card).stroke(enabled ? Theme.verm.opacity(0.75) : Theme.line, lineWidth: 3))
            .hardShadow()
        }
        .buttonStyle(PressableStyle(enabled: enabled))
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

    var body: some View {
        VStack(spacing: 14) {
            EntryHeader(tag: "頂 グランプリ", name: title)

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
            .padding(.horizontal, 20)

            Spacer(minLength: 8)
            Button {
                session.advanceAuto()
            } label: {
                Text("本番へ ▶").font(.maru(.title)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Theme.verm, in: RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Theme.vermD, radius: 0, y: 4)
            }
            .buttonStyle(PressableStyle()).padding(.horizontal, 32).padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bgGradient.ignoresSafeArea())
    }
}
