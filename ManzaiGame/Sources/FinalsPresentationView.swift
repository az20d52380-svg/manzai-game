// FinalsPresentationView.swift
// M-1本家型 決勝演出（uiux_vision_reply_part1 §4-2b/c/d ＋ Fable doc03 の7審査員）。
// 籤(出順) → 7審査員一斉オープン(見せ札＝各点＋審査員名＋重視軸の色＋合計) → 暫定ボード順位 → 最終決戦めくり(票) → 優勝。
// ★絶対制約: 全て「単一の内部結果(outcome)」からの演出的合成。GameCoreの判定・乱数列には一切触れない＝golden不変。
// 数値は全て【仮・実機目視で調整】。表示用RNGは state から決定的に seed（再現可・GameCore非消費）。

import SwiftUI
import GameCore

struct FinalsPresentationView: View {
    let session: GameSession

    @State private var beat = 0            // 0籤 1一斉オープン 2ボード 3最終決戦 4結果
    @State private var flipped = false     // 一斉オープンの7札
    @State private var revealVotes = 0     // 最終決戦のめくり票数
    @State private var celebrate = false   // 優勝の紙吹雪・スタンプ

    private var s: GameState { session.state }
    private var d: FinalsData { FinalsData(state: s, champion: session.outcome?.champion ?? true) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1B1630), Color(hex: 0x3A2340), Color(hex: 0x4A2F18)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            if celebrate { ConfettiView().ignoresSafeArea().allowsHitTesting(false) }

            VStack(spacing: 18) {
                Text("頂 グランプリ ・ 決勝").font(.maru(12)).tracking(3).foregroundStyle(Theme.gold)

                Group {
                    switch beat {
                    case 0: lotBeat
                    case 1: openBeat
                    case 2: boardBeat
                    case 3: finalDuelBeat
                    default: resultBeat
                    }
                }
                .frame(maxWidth: .infinity)

                if beat < 4 {
                    Text(beat == 1 && !flipped ? "" : "タップで進む")
                        .font(.maru(10)).foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 34)
        }
        .contentShape(Rectangle())
        .onTapGesture { advance() }
    }

    private func advance() {
        switch beat {
        case 1 where !flipped:
            withAnimation(.easeOut(duration: 0.35)) { flipped = true }   // 一斉オープン
            Haptics.confirm()
        case 3 where revealVotes < 7:
            withAnimation(.easeInOut(duration: 0.3)) { revealVotes += 1 } // めくり1枚
            if revealVotes == d.finalVotes { Haptics.confirm() }
        default:
            if beat == 3 && d.finalVotes >= 4 && !celebrate {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { celebrate = true }
                Haptics.rare()
            }
            withAnimation(.easeInOut(duration: 0.4)) { beat = min(beat + 1, 4) }
        }
    }

    // MARK: Beat 0 — 籤（出順）
    private var lotBeat: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 20)
            Text("出囃子").font(.maru(11)).foregroundStyle(.white.opacity(0.6))
            Text("全10組中、\(d.order)番目").font(.maru(26)).foregroundStyle(.white)
            Text(d.order == 1 ? "トップバッター。会場はまだ温まっていない。"
                 : d.order >= 9 ? "大トリ。ここまでの空気を、全部ひっくり返す番だ。"
                 : "中盤。沸いた流れに、どう乗るか。")
                .font(.system(size: 13, design: .serif)).foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
            Spacer(minLength: 20)
        }
    }

    // MARK: Beat 1 — 7審査員 一斉オープン（見せ札）
    private var openBeat: some View {
        VStack(spacing: 14) {
            Text(flipped ? "採点" : "採点中…").font(.maru(12)).foregroundStyle(.white.opacity(0.7))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(Array(d.judges.enumerated()), id: \.offset) { i, j in
                    judgeCard(j, index: i)
                }
            }
            if flipped {
                VStack(spacing: 2) {
                    Text("\(d.total)").font(.maru(40)).monospacedDigit().foregroundStyle(Theme.gold)
                        .contentTransition(.numericText())
                    Text("/ 700").font(.maru(12)).foregroundStyle(.white.opacity(0.5))
                }
                .padding(.top, 4).transition(.opacity)
            }
        }
    }

    private func judgeCard(_ j: JudgeScore, index: Int) -> some View {
        VStack(spacing: 3) {
            if flipped {
                Text("\(j.score)").font(.maru(22)).monospacedDigit().foregroundStyle(.white)
                Circle().fill(j.axisColor).frame(width: 6, height: 6)
                Text(j.name).font(.maru(8.5)).foregroundStyle(.white.opacity(0.7)).lineLimit(1).minimumScaleFactor(0.7)
            } else {
                Text("？").font(.maru(22)).foregroundStyle(.white.opacity(0.3))
            }
        }
        .frame(maxWidth: .infinity).frame(height: 70)
        .background((flipped ? Color.white.opacity(0.10) : Color.white.opacity(0.05)), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(flipped ? j.axisColor.opacity(0.6) : .white.opacity(0.12), lineWidth: 1))
        .rotation3DEffect(.degrees(flipped ? 0 : 180), axis: (x: 0, y: 1, z: 0))
        .animation(.easeOut(duration: 0.35).delay(Double(index) * 0.03), value: flipped)
    }

    // MARK: Beat 2 — 暫定ボード（全10組順位）
    private var boardBeat: some View {
        VStack(spacing: 6) {
            Text("暫定ボード").font(.maru(12)).foregroundStyle(.white.opacity(0.7)).padding(.bottom, 2)
            ForEach(Array(d.board.enumerated()), id: \.offset) { rank, row in
                HStack(spacing: 10) {
                    Text("\(rank + 1)").font(.maru(13)).monospacedDigit()
                        .foregroundStyle(rank < 3 ? Theme.gold : .white.opacity(0.6)).frame(width: 22)
                    Text(row.isSelf ? "あなたたち" : row.name).font(.maru(12))
                        .foregroundStyle(row.isSelf ? .white : .white.opacity(0.75))
                    Spacer()
                    Text("\(row.total)").font(.maru(13)).monospacedDigit().foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(row.isSelf ? Theme.verm.opacity(0.22) : Color.white.opacity(0.04),
                            in: RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .leading) {
                    if rank < 3 { Rectangle().fill(Theme.gold).frame(width: 3).clipShape(RoundedRectangle(cornerRadius: 2)) }
                }
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(row.isSelf ? Theme.verm.opacity(0.7) : .clear, lineWidth: 1.5))
            }
            Text(d.champion || d.boardRank <= 3 ? "——上位3組。もう一本、最終決戦へ。" : "——決勝の舞台には立った。")
                .font(.system(size: 12, design: .serif)).foregroundStyle(.white.opacity(0.7)).padding(.top, 6)
        }
    }

    // MARK: Beat 3 — 最終決戦（めくり・7票）
    private var finalDuelBeat: some View {
        VStack(spacing: 14) {
            Text("最終決戦").font(.maru(13)).foregroundStyle(Theme.gold)
            Text("「もう一本。」").font(.system(size: 14, design: .serif)).foregroundStyle(.white.opacity(0.85))
            HStack(spacing: 7) {
                ForEach(0..<7, id: \.self) { i in
                    let shown = i < revealVotes
                    let forUs = i < d.finalVotes
                    Text(shown ? (forUs ? "◯" : "・") : "？")
                        .font(.maru(18)).foregroundStyle(shown ? (forUs ? Theme.gold : .white.opacity(0.4)) : .white.opacity(0.25))
                        .frame(width: 34, height: 46)
                        .background(Color.white.opacity(shown && forUs ? 0.12 : 0.05), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(shown && forUs ? Theme.gold.opacity(0.7) : .white.opacity(0.12), lineWidth: 1))
                }
            }
            Text(revealVotes < 7 ? "タップで札をめくる（\(revealVotes)/7）"
                 : d.finalVotes >= 4 ? "——\(d.finalVotes)票。決着。" : "——及ばず。")
                .font(.maru(11)).foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: Beat 4 — 結果（優勝）
    private var resultBeat: some View {
        VStack(spacing: 16) {
            if d.champion {
                Text("優勝").font(.maru(36)).foregroundStyle(Color(hex: 0x5A3A06))
                    .frame(width: 130, height: 130)
                    .background(RadialGradient(colors: [Color(hex: 0xFFE07A), Theme.gold], center: .topLeading, startRadius: 5, endRadius: 140), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 3))
                    .rotationEffect(.degrees(-8)).shadow(color: Theme.gold.opacity(0.7), radius: 20, y: 8)
                    .scaleEffect(celebrate ? 1 : 1.6)
                Text("谷口が、そっと耳打ちした。\n「……なあ、腹減ったな」")
                    .font(.system(size: 14, design: .serif)).lineSpacing(6).foregroundStyle(Color(hex: 0xEDE3FF))
                    .multilineTextAlignment(.center).padding(14).frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            } else {
                Text("決勝").font(.maru(30)).foregroundStyle(.white)
                Text("届かなかった。だが、この夜の舞台には立った。")
                    .font(.system(size: 14, design: .serif)).foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center)
            }
            Button {
                if d.champion { session.acknowledgeWin() } else { session.acknowledgeResult() }
            } label: {
                Text("結果を見る ▶").font(.maru(16)).foregroundStyle(Color(hex: 0x5A3A06))
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(Theme.gold, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain).padding(.horizontal, 30).padding(.top, 4)
        }
        .onAppear { withAnimation(.spring(response: 0.55, dampingFraction: 0.55).delay(0.2)) { celebrate = true } }
    }
}

// MARK: - 見せ札の合成（単一結果→7審査員の点・順位・票。GameCore非消費・UI専用の決定的RNG）

struct JudgeScore { let name: String; let score: Int; let axisColor: Color }
struct BoardRow { let name: String; let total: Int; let isSelf: Bool }

struct FinalsData {
    let order: Int
    let total: Int
    let judges: [JudgeScore]
    let board: [BoardRow]
    let boardRank: Int
    let finalVotes: Int
    let champion: Bool

    init(state s: GameState, champion: Bool) {
        self.champion = champion
        // UI専用RNG（能力から決定的にseed＝再現可・GameCoreの乱数列に非干渉）
        var rng = SeededRng(seed: UInt64(bitPattern: Int64(
            Int(s.発想) &* 131 &+ Int(s.センス) &* 197 &+ Int(s.表現) &* 251 &+
            Int(s.華) &* 313 &+ Int(s.メンタル) &* 389 &+ Int(s.compat) &* 457 &+ 0x1F17)))

        // 表示合計S（/700・帯写像＝内部式の逆算防止のため帯内ジッタ）【仮】
        let total = champion ? rng.int(632...668) : rng.int(600...631)
        self.total = total
        self.order = rng.int(1...10)

        // 7審査員: raw = S/7 + 人格bias + 重視軸tilt + ノイズ → Σ=S補正 → [50,99]クランプ
        let base = Double(total) / 7.0
        let perfAvg = (Double(s.発想) + Double(s.センス) + Double(s.表現) + Double(s.華)) / 4.0
        func tilt(_ v: Double) -> Double { max(-3, min(3, (v - perfAvg) / 10.0)) }
        struct Spec { let name: String; let bias: Double; let axis: Double; let color: Color; let noise: Int }
        // 固定嗜好: 振れ幅は審査員ごとに固定（神楽坂=変わり者好き±3・天堂寺=辛口で最小±1・他±2）＝統合設計 §2-5
        let specs: [Spec] = [
            Spec(name: "音羽 ルリ",      bias: 1,  axis: Double(s.華),            color: Theme.cChara,  noise: 2),
            Spec(name: "白波 剛",        bias: 2,  axis: Double(s.表現),          color: Theme.cExpr,   noise: 2),
            Spec(name: "卯月 走太",      bias: 0,  axis: Double(s.発想),          color: Theme.cIdea,   noise: 2),
            Spec(name: "花園 千代",      bias: 1,  axis: Double(s.compat) * 6,     color: Theme.verm,    noise: 2),
            Spec(name: "目白 慧",        bias: -1, axis: Double(s.発想),          color: Theme.cIdea,   noise: 2),
            Spec(name: "神楽坂 とんぼ",  bias: 0,  axis: Double(s.メンタル),      color: Theme.cMental, noise: 3),
            Spec(name: "天堂寺 銀郎",    bias: -2, axis: Double(s.センス),        color: Theme.cSense,  noise: 1),
        ]
        var raw = specs.map { base + $0.bias + tilt($0.axis) + Double(rng.int(-$0.noise...$0.noise)) }
        // Σ=S へ丸め補正
        var ints = raw.map { Int($0.rounded()) }
        var diff = total - ints.reduce(0, +)
        var idx = 0
        while diff != 0 && idx < 100 { let k = idx % 7; ints[k] += diff > 0 ? 1 : -1; diff += diff > 0 ? -1 : 1; idx += 1 }
        ints = ints.map { max(50, min(99, $0)) }
        self.judges = zip(specs, ints).map { JudgeScore(name: $0.name, score: $1, axisColor: $0.color) }

        // 暫定ボード: 自組totalを基準にNPC9組を後方生成（champion=1位／それ以外は帯内）
        var npc: [Int] = []
        let spread = champion ? -1 : 0
        for i in 0..<9 { npc.append(total + spread * rng.int(1...30) - rng.int(2...45) + (champion ? 0 : rng.int(-8...12))) }
        var rows = npc.enumerated().map { BoardRow(name: FinalsData.npcNames[$0.offset % FinalsData.npcNames.count], total: max(520, min(695, $0.element)), isSelf: false) }
        rows.append(BoardRow(name: "あなたたち", total: total, isSelf: true))
        rows.sort { $0.total > $1.total }
        self.board = rows
        self.boardRank = (rows.firstIndex { $0.isSelf } ?? 0) + 1

        // 最終決戦の得票（TOP3のみ・7票中）: 圧勝6〜7/接戦4/敗北1〜3
        self.finalVotes = champion ? rng.int(5...7) : rng.int(1...3)
    }

    /// NPCコンビ名（架空・プレースホルダ枠。本来は name_generator が毎周生成）
    static let npcNames = ["紺屋", "夜明けの犬", "サーカス", "青写真", "十三", "静物画", "テレフォン", "北緯", "帰り道"]
}

/// UI専用の決定的PRNG（SplitMix系・GameCoreのRandomSourceとは別物＝乱数列に非干渉）
private struct SeededRng {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        var x = state; x ^= x >> 30; x = x &* 0xBF58476D1CE4E5B9; x ^= x >> 27; return x
    }
    mutating func int(_ r: ClosedRange<Int>) -> Int {
        let span = UInt64(r.upperBound - r.lowerBound + 1)
        return r.lowerBound + Int(next() % span)
    }
}

/// 決勝の紙吹雪（WinFinaleView と同型・決定的な位置）
private struct ConfettiView: View {
    private let pieces = 30
    private let palette: [Color] = [Theme.gold, Theme.verm, Theme.cSense, Theme.cChara, Theme.cMental, Theme.cIdea]
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                for i in 0..<pieces {
                    let seed = Double(i)
                    let x = (sin(seed * 12.9898) * 0.5 + 0.5) * size.width
                    let speed = 42 + (i % 5) * 14
                    let y = (Double(speed) * t + seed * 47).truncatingRemainder(dividingBy: Double(size.height + 40)) - 20
                    let rot = t * 2 + seed
                    let c = palette[i % palette.count]
                    var rect = Path(CGRect(x: -4, y: -6, width: 8, height: 12))
                    rect = rect.applying(CGAffineTransform(rotationAngle: rot)).applying(CGAffineTransform(translationX: x, y: y))
                    ctx.fill(rect, with: .color(c.opacity(0.9)))
                }
            }
        }
    }
}
