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
    @State private var revealedJudges = 0  // 見せ札を1人ずつ開示（M-1式・0..7）
    @State private var revealVotes = 0     // 最終決戦のめくり票数
    @State private var celebrate = false   // 優勝の紙吹雪・スタンプ
    @State private var slamFire = 0        // 開示のたびの衝撃（フラッシュ＋シェイク・Juice.swift）
    @State private var burstFire = 0       // 決着の紙吹雪バースト

    private var s: GameState { session.state }
    private var d: FinalsData { FinalsData(state: s, champion: session.outcome?.champion ?? true) }

    var body: some View {
        ZStack {
            // 番組の黒（M-1中継の暗転スタジオ）＋足元から金赤の照り＋ビネット
            LinearGradient(colors: [Color(hex: 0x080610), Color(hex: 0x140E1E), Color(hex: 0x241118)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            RadialGradient(colors: [Theme.gold.opacity(0.13), .clear],
                           center: UnitPoint(x: 0.5, y: 1.05), startRadius: 40, endRadius: 520)
                .ignoresSafeArea()
            if celebrate {
                RaysView().ignoresSafeArea().allowsHitTesting(false)   // 優勝の放射光
                ConfettiView().ignoresSafeArea().allowsHitTesting(false)
            }

            VStack(spacing: 18) {
                broadcastTitle

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
                    Text(beat == 1 && revealedJudges < 7 ? "タップで1人ずつ発表" : "タップで進む")
                        .font(.maru(10)).foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 34)

            // 下部テロップ（番組の下三分帯・コンビ名）
            VStack { Spacer()
                lowerThird
            }.ignoresSafeArea(edges: .bottom).allowsHitTesting(false)
        }
        .overlay {
            ParticleBurst(trigger: burstFire, colors: [Theme.gold, Color(hex: 0xFFE07A), Theme.verm, .white],
                          style: .confetti, count: 60, origin: UnitPoint(x: 0.5, y: 0.42))
        }
        .screenShake(trigger: slamFire, intensity: 8)
        .screenFlash(trigger: slamFire, color: Color(hex: 0xFFE9C4), strength: 0.30)
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .onAppear {
            #if DEBUG
            // 目視用: MZ_FIN=open/duel/win で各ビートへ直行（タップ注入できないCLI検証のため）
            switch ProcessInfo.processInfo.environment["MZ_FIN"] {
            case "open": beat = 1; revealedJudges = 5
            case "duel": beat = 3; revealVotes = 5
            case "win": beat = 4
            default: break
            }
            #endif
        }
    }

    /// 番組タイトル（黒×金の中継グラフィック）
    private var broadcastTitle: some View {
        VStack(spacing: 5) {
            Text("頂 グランプリ")
                .font(.system(size: 24, weight: .black, design: .serif)).tracking(6)
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFE9A8), Theme.gold, Color(hex: 0xB8860B)],
                                                startPoint: .top, endPoint: .bottom))
                .shadow(color: Theme.gold.opacity(0.55), radius: 10)
            Text("決 勝").font(.maru(11)).tracking(8).foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 3)
                .background(LinearGradient(colors: [Theme.verm, Theme.vermD], startPoint: .top, endPoint: .bottom),
                            in: Capsule())
                .overlay(Capsule().stroke(Theme.gold.opacity(0.8), lineWidth: 1))
        }
    }

    /// 下部テロップ帯（コンビ名・M-1の下三分）
    private var lowerThird: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Theme.verm).frame(width: 5)
            Text(session.combiName).font(.maru(14)).foregroundStyle(.white)
            Spacer()
            Text("結成1年").font(.maru(10)).foregroundStyle(Theme.gold.opacity(0.9))
        }
        .padding(.horizontal, 16).frame(height: 40)
        .background(LinearGradient(colors: [Color(hex: 0x1A1424).opacity(0.96), Color(hex: 0x241A30).opacity(0.96)],
                                   startPoint: .top, endPoint: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Theme.gold.opacity(0.85)).frame(height: 1.5) }
        .padding(.bottom, 0)
    }

    private func advance() {
        switch beat {
        case 1 where revealedJudges < 7:
            withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) { revealedJudges += 1 }   // 1人ずつ開示（M-1式・天堂寺がトリ）
            slamFire += 1                                             // 開示のたび衝撃（テレビのドン）
            Haptics.confirm()
        case 3 where revealVotes < 7:
            withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) { revealVotes += 1 } // めくり1枚
            slamFire += 1
            let usCount = d.voteOrder.prefix(revealVotes).filter { $0 == 0 }.count
            if usCount == 4 {                                          // 過半数到達＝その瞬間に決着
                Haptics.rare(); burstFire += 1
            } else {
                Haptics.confirm()
            }
        default:
            if beat == 3 && d.champion && !celebrate {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { celebrate = true }
                Haptics.rare(); burstFire += 1
            }
            withAnimation(.easeInOut(duration: 0.4)) { beat = min(beat + 1, 4) }
        }
    }

    // MARK: Beat 0 — 籤（出順）
    private var lotBeat: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 16)
            Text("出 順 発 表").font(.maru(12)).tracking(6).foregroundStyle(.white.opacity(0.7))
            // 金縁の出順プレート（テレビの札）
            VStack(spacing: 0) {
                Text("\(d.order)").font(.system(size: 74, weight: .black, design: .rounded)).monospacedDigit()
                    .foregroundStyle(LinearGradient(colors: [.white, Color(hex: 0xFFE9A8)],
                                                    startPoint: .top, endPoint: .bottom))
                Text("番目 ／ 全10組").font(.maru(12)).foregroundStyle(Theme.gold.opacity(0.9))
                    .padding(.bottom, 12)
            }
            .frame(width: 190)
            .background(LinearGradient(colors: [Color(hex: 0x231B33), Color(hex: 0x120D1E)],
                                       startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(
                LinearGradient(colors: [Color(hex: 0xFFE9A8), Theme.gold, Color(hex: 0x8A6508)],
                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2.5))
            .shadow(color: Theme.gold.opacity(0.35), radius: 16, y: 6)
            Text(d.order == 1 ? "トップバッター。会場はまだ温まっていない。"
                 : d.order >= 9 ? "大トリ。ここまでの空気を、全部ひっくり返す番だ。"
                 : "中盤。沸いた流れに、どう乗るか。")
                .font(.system(size: 13, design: .serif)).foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
            Spacer(minLength: 16)
        }
    }

    // MARK: Beat 1 — 7審査員 一斉オープン（見せ札）
    private var openBeat: some View {
        let running = d.judges.prefix(revealedJudges).reduce(0) { $0 + $1.score }
        let allShown = revealedJudges >= 7
        // 見せ札の型ラベル（v2 §4-3補2）: FinalsData（Σ=S補正・rng.int等）の計算には一切関与しない、
        // 既に確定済みの点数・出順の上に、選択中ネタの型を審査員の固定嗜好表で引いて添えるだけの純表示。
        let kata = session.selectedNeta?.kata
        return VStack(spacing: 14) {
            Text(allShown ? "採点" : revealedJudges == 0 ? "採点発表" : "\(revealedJudges) / 7 人")
                .font(.maru(12)).foregroundStyle(.white.opacity(0.7))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(Array(d.judges.enumerated()), id: \.offset) { i, j in
                    judgeCard(j, shown: i < revealedJudges, kata: kata)
                }
            }
            VStack(spacing: 2) {
                Text("\(running)")
                    .font(.system(size: 58, weight: .black, design: .rounded)).monospacedDigit()
                    .foregroundStyle(allShown
                        ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFF3C8), Theme.gold, Color(hex: 0xC8971A)],
                                                       startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(Color.white.opacity(0.92)))
                    .shadow(color: allShown ? Theme.gold.opacity(0.6) : .clear, radius: 14)
                    .contentTransition(.numericText())
                    .punch(on: running, peak: 1.16)   // 1人開くたび合計がドンと跳ねる
                Text(allShown ? "/ 700" : "……").font(.maru(12)).foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 2)
            if let kata, allShown {
                Text("\(NetaCatalog.displayName(kata))で挑んだ一本。")
                    .font(.system(size: 11.5, design: .serif)).foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private func judgeCard(_ j: JudgeScore, shown: Bool, kata: NetaKata?) -> some View {
        // M-1の採点開示＝審査員の「顔」の上に点数が出る（番組の画）。
        VStack(spacing: 2) {
            if shown {
                Text("\(j.score)")
                    .font(.system(size: 24, weight: .black, design: .rounded)).monospacedDigit()
                    .foregroundStyle(LinearGradient(colors: [.white, Color(hex: 0xFFEDC0)],
                                                    startPoint: .top, endPoint: .bottom))
                    .shadow(color: j.axisColor.opacity(0.7), radius: 6)
            } else {
                Text("？").font(.maru(20)).foregroundStyle(.white.opacity(0.3)).frame(height: 29)
            }
            CharacterFace(spec: FaceCatalog.judge(j.name), size: 34)
                .overlay(Circle().stroke(shown ? j.axisColor : .white.opacity(0.2), lineWidth: 1.5))
                .saturation(shown ? 1 : 0.3)
            Text(j.name).font(.maru(8.5)).foregroundStyle(.white.opacity(0.75)).lineLimit(1).minimumScaleFactor(0.7)
            if shown, let kata {
                Text(NetaCatalog.affinity(kata, judge: j.name))
                    .font(.maru(9, weight: .bold)).foregroundStyle(Theme.gold.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity).frame(height: kata != nil ? 104 : 92)
        .background(LinearGradient(colors: shown ? [Color(hex: 0x2A2040), Color(hex: 0x171126)]
                                                 : [Color(hex: 0x171126), Color(hex: 0x100B1B)],
                                   startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(shown ? j.axisColor.opacity(0.85) : Theme.gold.opacity(0.22), lineWidth: shown ? 1.8 : 1))
        .shadow(color: shown ? j.axisColor.opacity(0.35) : .clear, radius: 8, y: 3)
        .rotation3DEffect(.degrees(shown ? 0 : 180), axis: (x: 0, y: 1, z: 0))
        .scaleEffect(shown ? 1 : 0.94)
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: shown)
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

    // MARK: Beat 3 — 最終決戦（M-1式＝3組・審査員7人が顔の上に組名札を掲げる）
    private var finalDuelBeat: some View {
        let names = [session.combiName] + d.rivalNames
        let counts = (0..<3).map { k in d.voteOrder.prefix(revealVotes).filter { $0 == k }.count }
        return VStack(spacing: 14) {
            Text("最 終 決 戦").font(.maru(15)).tracking(6)
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFE9A8), Theme.gold],
                                                startPoint: .top, endPoint: .bottom))
                .shadow(color: Theme.gold.opacity(0.5), radius: 8)
            Text("勝ち残った3組。審査員は、面白かった方の名を書く。")
                .font(.system(size: 12, design: .serif)).foregroundStyle(.white.opacity(0.75))

            // 3組の得票カウンタ（番組のスコア表示・自組は金）
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { k in
                    trioCounter(name: names.count > k ? names[k] : "—", count: counts[k], mine: k == 0)
                }
            }

            // 審査員7人: 顔の上に票札（組名）が掲がる（M-1の票開示）
            HStack(spacing: 5) {
                ForEach(0..<7, id: \.self) { i in
                    let shown = i < revealVotes
                    let vote = d.voteOrder[i]
                    VStack(spacing: 3) {
                        votePlate(shown: shown, voteName: names.count > vote ? names[vote] : "—", forUs: vote == 0)
                        CharacterFace(spec: FaceCatalog.judge(d.judges[i].name), size: 38)
                            .overlay(Circle().stroke(shown ? (vote == 0 ? Theme.gold : .white.opacity(0.4))
                                                           : .white.opacity(0.18), lineWidth: 1.5))
                        Text(String(d.judges[i].name.prefix(2)))
                            .font(.maru(8)).foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            Text(revealVotes < 7 ? "タップで札をめくる（\(revealVotes)/7）" : "——開票、出揃った。")
                .font(.maru(12)).foregroundStyle(revealVotes < 7 ? .white.opacity(0.6) : Theme.gold)
        }
    }

    private func trioCounter(name: String, count: Int, mine: Bool) -> some View {
        VStack(spacing: 1) {
            Text(name).font(.maru(10)).lineLimit(1).minimumScaleFactor(0.6)
                .foregroundStyle(mine ? .white : .white.opacity(0.65))
            Text("\(count)")
                .font(.system(size: 30, weight: .black, design: .rounded)).monospacedDigit()
                .foregroundStyle(mine ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFF3C8), Theme.gold],
                                                                     startPoint: .top, endPoint: .bottom))
                                      : AnyShapeStyle(Color.white.opacity(0.8)))
                .contentTransition(.numericText())
                .punch(on: count, peak: 1.3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.white.opacity(mine ? 0.08 : 0.04), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(mine ? Theme.gold.opacity(0.6) : .white.opacity(0.15), lineWidth: mine ? 1.5 : 1))
    }

    /// 票札1枚: 組名が書かれた札が審査員の頭上に掲がる。自組＝朱地に金縁。めくりは3D回転＋バネ着地。
    private func votePlate(shown: Bool, voteName: String, forUs: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(shown ? (forUs ? AnyShapeStyle(LinearGradient(colors: [Theme.verm, Theme.vermD],
                                                                    startPoint: .top, endPoint: .bottom))
                                     : AnyShapeStyle(Color(hex: 0xF2EDE0)))
                            : AnyShapeStyle(Color(hex: 0x1B1526)))
            if shown {
                Text(voteName)
                    .font(.system(size: 8.5, weight: .black))
                    .foregroundStyle(forUs ? Color(hex: 0xFFF3C8) : Color(hex: 0x2C2740))
                    .lineLimit(2).minimumScaleFactor(0.5)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 2)
            } else {
                Text("？").font(.maru(13)).foregroundStyle(.white.opacity(0.25))
            }
        }
        .frame(width: 46, height: 34)
        .overlay(RoundedRectangle(cornerRadius: 6)
            .stroke(shown ? (forUs ? Theme.gold : Color(hex: 0xC8C0A8)) : .white.opacity(0.15),
                    lineWidth: shown && forUs ? 1.8 : 1))
        .shadow(color: shown && forUs ? Theme.verm.opacity(0.5) : .clear, radius: 6, y: 2)
        .rotation3DEffect(.degrees(shown ? 0 : 180), axis: (x: 0, y: 1, z: 0))
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: shown)
    }

    // MARK: Beat 4 — 優勝発表（3組から名前をコール）
    private var resultBeat: some View {
        let names = [session.combiName] + d.rivalNames
        let winnerName = names.count > d.winnerIndex ? names[d.winnerIndex] : session.combiName
        return VStack(spacing: 16) {
            Text("優 勝 は ——").font(.maru(13)).tracking(4).foregroundStyle(.white.opacity(0.8))
            Text(winnerName)
                .font(.system(size: 30, weight: .black)).lineLimit(1).minimumScaleFactor(0.6)
                .foregroundStyle(d.champion
                    ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFF3C8), Theme.gold],
                                                   startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(Color.white.opacity(0.9)))
                .shadow(color: d.champion ? Theme.gold.opacity(0.6) : .clear, radius: 12)
                .padding(.horizontal, 22).padding(.vertical, 10)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(d.champion ? Theme.gold.opacity(0.8) : .white.opacity(0.2), lineWidth: 1.5))
                .scaleEffect(celebrate || !d.champion ? 1 : 1.8)
            if d.champion {
                Text("優勝").font(.system(size: 44, weight: .black)).foregroundStyle(Color(hex: 0x5A3A06))
                    .frame(width: 160, height: 160)
                    .background(RadialGradient(colors: [Color(hex: 0xFFE07A), Theme.gold], center: .topLeading, startRadius: 5, endRadius: 170), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 4))
                    .overlay(Circle().stroke(Theme.gold.opacity(0.5), lineWidth: 10).blur(radius: 8))
                    .rotationEffect(.degrees(-8)).shadow(color: Theme.gold.opacity(0.8), radius: 28, y: 8)
                    .scaleEffect(celebrate ? 1 : 2.0)
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
    /// 最終決戦に残るライバル2組（暫定ボード上位のNPC・M-1式＝3組で争う）
    var rivalNames: [String] = []
    /// 票札のめくり順（0=自組/1=ライバルA/2=ライバルB）。表示専用のシャッフル。
    var voteOrder: [Int] = []
    /// 優勝コンビ（0=自組/1=A/2=B）
    var winnerIndex: Int = 0

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
        let raw = specs.map { base + $0.bias + tilt($0.axis) + Double(rng.int(-$0.noise...$0.noise)) }
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
        for _ in 0..<9 { npc.append(total + spread * rng.int(1...30) - rng.int(2...45) + (champion ? 0 : rng.int(-8...12))) }
        var rows = npc.enumerated().map { BoardRow(name: FinalsData.npcNames[$0.offset % FinalsData.npcNames.count], total: max(520, min(695, $0.element)), isSelf: false) }
        rows.append(BoardRow(name: "あなたたち", total: total, isSelf: true))
        rows.sort { $0.total > $1.total }
        self.board = rows
        self.boardRank = (rows.firstIndex { $0.isSelf } ?? 0) + 1

        // 最終決戦（M-1式＝3組で争う・7票中）: 圧勝6〜7/接戦4〜5/敗北1〜3
        let votes = champion ? rng.int(5...7) : rng.int(1...3)
        self.finalVotes = votes

        // ライバル2組＝暫定ボード上位のNPC（自分を除く上から2組）
        let rivals = rows.filter { !$0.isSelf }.prefix(2).map { $0.name }
        self.rivalNames = Array(rivals)

        // 残票をライバル2組へ配分（A>=B・非優勝時はAが必ず自組を上回る＝Aが優勝）
        let remaining = 7 - votes
        let aLow = champion ? (remaining + 1) / 2 : max((remaining + 1) / 2, votes + 1)
        let a = remaining == 0 ? 0 : rng.int(min(aLow, remaining)...remaining)
        let b = remaining - a
        self.winnerIndex = champion ? 0 : 1

        // めくり順のシャッフル（表示専用・既存drawの後に追加＝これまでの数値は不変）。
        var order = Array(repeating: 0, count: votes) + Array(repeating: 1, count: a) + Array(repeating: 2, count: b)
        for i in stride(from: 6, through: 1, by: -1) {
            let j = rng.int(0...i)
            order.swapAt(i, j)
        }
        self.voteOrder = order
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

/// 優勝の放射光（金の光条がゆっくり回る・テレビの優勝カットの背景）
private struct RaysView: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height * 0.42)
                let r = max(size.width, size.height)
                for i in 0..<14 {
                    let a = Double(i) / 14 * 2 * .pi + t * 0.12
                    let w = 0.10   // 光条の半幅(rad)
                    var p = Path()
                    p.move(to: c)
                    p.addLine(to: CGPoint(x: c.x + cos(a - w) * r, y: c.y + sin(a - w) * r))
                    p.addLine(to: CGPoint(x: c.x + cos(a + w) * r, y: c.y + sin(a + w) * r))
                    p.closeSubpath()
                    ctx.fill(p, with: .color(Theme.gold.opacity(i.isMultiple(of: 2) ? 0.10 : 0.05)))
                }
            }
        }
    }
}

/// 決勝の紙吹雪（決定的な位置）
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
