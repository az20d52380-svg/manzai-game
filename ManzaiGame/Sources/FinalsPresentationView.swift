// FinalsPresentationView.swift
// M-1本家型 決勝演出（uiux_vision_reply_part1 §4-2b/c/d ＋ Fable doc03 の7審査員）。
// 籤(出順) → 7審査員を1人ずつ開く(見せ札＝各点＋審査員名＋重視軸の色。合計は全員の後) → 暫定ボード順位 → 最終決戦めくり(票) → 優勝。
// ★絶対制約: 全て「単一の内部結果(outcome)」からの演出的合成。GameCoreの判定・乱数列には一切触れない＝golden不変。
// 数値は全て【仮・実機目視で調整】。表示用RNGは state から決定的に seed（再現可・GameCore非消費）。

import SwiftUI
import GameCore

/// 決勝のビート（順に進む・飛ばさない）。旧 Int の beat 0..4 と同じ順序。
enum FinalsBeat: Int, Comparable {
    case lot = 0      // 籤（出順）
    case open = 1     // 7審査員の採点（1人ずつ開く＝オーナー判断 2026-10-09）
    case board = 2    // 暫定ボード
    case duel = 3     // 最終決戦（めくり）
    case result = 4   // 優勝発表
    static func < (a: FinalsBeat, b: FinalsBeat) -> Bool { a.rawValue < b.rawValue }
    var next: FinalsBeat { FinalsBeat(rawValue: min(rawValue + 1, FinalsBeat.result.rawValue)) ?? .result }
}

struct FinalsPresentationView: View {
    let session: GameSession
    /// 観客モード（監査H-01）: 決勝に進めなかった年、第47週に今年の決勝を客席から観る。自組は出ない。
    var spectator: Bool = false
    /// 観客モードの終わり（優勝組名を渡して年末へ戻る）
    var onFinishSpectating: ((String) -> Void)? = nil

    @State private var beat: FinalsBeat = .lot
    @State private var revealedJudges = 0  // 見せ札を1人ずつ開示（M-1式・0..7）
    @State private var revealVotes = 0     // 最終決戦のめくり票数
    @State private var celebrate = false   // 優勝の紙吹雪・スタンプ
    @State private var slamFire = 0        // 開示のたびの衝撃（フラッシュ＋シェイク・Juice.swift）
    @State private var burstFire = 0       // 決着の紙吹雪バースト
    /// 開演の儀が終わったか（決勝の入りの儀式・L11）
    @State private var ceremonyDone = false
    /// 銀の紙吹雪（他組の優勝・自組の決勝敗退）
    @State private var silverFire = 0
    /// 7人目の前の間（全SE断＋BGMを絞る0.6s）。この間のタップは受けない
    @State private var holdingSeventh = false

    private var s: GameState { session.state }
    /// 見せ札の合成結果。描画のたびに作り直さず、最初に1回だけ作って保持する（X4-18）。
    @State private var dataCache: FinalsData?
    /// 優勝時は勝ち版、決勝で負けた時は負け版（監査E-08）、観客モードは自組抜きの3組
    private var d: FinalsData { dataCache ?? makeData() }
    private func makeData() -> FinalsData {
        // 決勝の点差（負けた夜は結果画面のデータ・優勝の夜は session が控えた値）。復元直後でも結果データから読める
        let margin = session.pendingResult?.results.last(where: { $0.name == "GP決勝" })?.margin ?? session.lastFinalMargin
        #if DEBUG
        // 目視用: MZ_FMARGIN=点差 で決勝の結果を差し替える（負＝敗退。-2 なら最終決戦で惜敗、-20 なら1本目で敗退）
        if let m = Double(ProcessInfo.processInfo.environment["MZ_FMARGIN"] ?? ""), !spectator {
            return FinalsData(state: s, champion: m > 0, margin: m, year: session.year)
        }
        #endif
        return FinalsData(state: s, champion: !spectator && session.winFinale, spectator: spectator,
                          margin: spectator ? nil : margin, year: session.year)
    }
    /// 1組の表示名（自組は付けたコンビ名）
    private func displayName(_ e: FinalsEntry) -> String { e.isSelf ? session.combiName : e.name }
    /// 最終決戦の3組名（1本目の順位順。自組が4位以下の年は他の3組）
    private var duelNames: [String] { d.duelEntries.map(displayName) }

    /// ビート→舞台の状態。籤＝開演前／採点〜最終決戦＝金屏風（客席から観る年は銀）／結果＝自組の優勝だけ最明部
    private var stageMode: StageFrame.Mode {
        switch beat {
        case .lot: return .preshow
        case .open, .board, .duel: return spectator ? .spectator : .judging
        case .result: return d.champion ? .winner : (spectator ? .spectator : .loser)
        }
    }
    /// 舞台に二人を立たせるビート（籤＝これから立つ舞台／優勝＝二人が画面にいる・A2 §1-9）
    private var stagePerformers: Bool { beat == .lot || (beat == .result && !spectator) }

    var body: some View {
        ZStack {
            // 暖色の客席に光る舞台（オーナー判断 Q1=A・visual_genre_overhaul_v1 §6 F1）。採点〜最終決戦は金屏風
            StageFrame(mode: stageMode, performers: stagePerformers,
                       floorTop: beat == .lot ? 0.60 : (beat == .result ? 0.62 : 0.56))
                .animation(.easeInOut(duration: 0.5), value: beat)
            if celebrate && d.champion {
                // 金の放射光と紙吹雪は自組の優勝の夜だけ（他組の優勝・決勝敗退には降らない・A2 §3-B2）
                RaysView().ignoresSafeArea().allowsHitTesting(false)
                ConfettiView().ignoresSafeArea().allowsHitTesting(false)
            }

            VStack(spacing: 18) {
                broadcastTitle

                Group {
                    switch beat {
                    case .lot: lotBeat
                    case .open: openBeat
                    case .board: boardBeat
                    case .duel: finalDuelBeat
                    case .result: resultBeat
                    }
                }
                .frame(maxWidth: .infinity)

                if beat < .result, !(beat == .duel && revealVotes < 7) {
                    // 送りの合図は▼1種（K4）。採点だけ「1人ずつ」と添える
                    VStack(spacing: 4) {
                        if beat == .open && revealedJudges < 7 {
                            Telop(text: "タップで1人ずつ発表", size: 13, color: Theme.houseLight)
                        }
                        AdvanceCue(color: Theme.gold)
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 44).padding(.bottom, 56)

            // 下部テロップ（番組の下三分帯・コンビ名）
            VStack { Spacer()
                lowerThird
            }.ignoresSafeArea(edges: .bottom).allowsHitTesting(false)
        }
        .overlay {
            ParticleBurst(trigger: burstFire, colors: [Theme.gold, Color(hex: 0xFFE07A), Theme.verm, .white],
                          style: .confetti, count: 60, origin: UnitPoint(x: 0.5, y: 0.42))
            // 他組の優勝・自組の決勝敗退＝銀の紙吹雪（負けの夜にも同じ物量・金は使わない・X2-06）
            ParticleBurst(trigger: silverFire, colors: [Theme.silver, .white, Color(hex: 0xAEB6C2)],
                          style: .confetti, count: 50, origin: UnitPoint(x: 0.5, y: 0.30))
        }
        .screenShake(trigger: slamFire, intensity: 8)
        .screenFlash(trigger: slamFire, color: Color(hex: 0xFFE9C4), strength: 0.30)
        .contentShape(Rectangle())
        .onTapGesture { if ceremonyDone { advance() } }
        // 長押し＝その場面の残りを一気にめくる早送り（ビートは飛ばさない＝決勝演出の規則・K6/R2-01）
        .onLongPressGesture(minimumDuration: 0.5) { if ceremonyDone { fastForwardBeat() } }
        .overlay {
            if !ceremonyDone {
                StageCeremony { ceremonyDone = true }
                    .transition(.opacity)
            }
        }
        .onAppear {
            if dataCache == nil { dataCache = makeData() }
            Sound.bgm(.finals)   // 番組のBGM（決勝の格）
            if spectator { beat = .board }   // 観客は籤と自組の採点を飛ばし、暫定ボードから観る
            #if DEBUG
            // 目視用: MZ_FIN=open/duel/win で各ビートへ直行（タップ注入できないCLI検証のため）
            switch ProcessInfo.processInfo.environment["MZ_FIN"] {
            case "open": beat = .open; revealedJudges = 5
            case "board": beat = .board
            case "duel": beat = .duel; revealVotes = 5
            case "win": beat = .result
            default: break
            }
            #endif
        }
    }

    /// 番組タイトル（黒×金の中継グラフィック）
    private var broadcastTitle: some View {
        VStack(spacing: 5) {
            Telop(text: "頂 グランプリ", size: 26, color: Color(hex: 0xFFE9A8))
            Text("決勝").font(.maru(.sub)).tracking(4).foregroundStyle(.white)
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
            Text(spectator ? "客席から" : session.combiName).font(.maru(.body)).foregroundStyle(.white)
            Spacer()
            Text(spectator ? session.combiName : "結成\(session.year)年").font(.maru(.sub)).foregroundStyle(Theme.gold)
        }
        .padding(.horizontal, 16).frame(height: 46)
        .background(Theme.lowerThird.opacity(0.96))
        .overlay(alignment: .top) { Rectangle().fill(Theme.gold.opacity(0.85)).frame(height: 1.5) }
        .padding(.bottom, 0)
    }

    private func advance() {
        guard !holdingSeventh else { return }
        switch beat {
        case .open where revealedJudges == 6:
            // 7人目（天堂寺がトリ）の前だけ、全SE断＋BGMを絞る0.6秒の間（伝説の間・finals_direction §2-2）
            holdingSeventh = true
            Sound.hushSE(true); Sound.duck(0.25, over: 0.2)
            Task {
                try? await Task.sleep(nanoseconds: 600_000_000)
                Sound.hushSE(false); Sound.duck(1, over: 0.4)
                holdingSeventh = false
                revealJudge()
            }
        case .open where revealedJudges < 7:
            revealJudge()
        case .duel where revealVotes < 7:
            withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) { revealVotes += 1 } // めくり1枚
            let winCount = d.voteOrder.prefix(revealVotes).filter { $0 == d.winnerIndex }.count
            if winCount == 4 {                                          // 過半数到達＝その瞬間に決着
                slamFire += 1                                           // 揺れ・閃光は決着の1回だけ（X2-26〜28）
                Haptics.rare(); burstFire += 1
                Sound.play(.taiko); Sound.play(.cheerBig)              // 決着＝太鼓＋大歓声
            } else {
                Haptics.confirm()
                Sound.play(.don)                                       // 札1枚＝ドン
            }
        default:
            if beat == .duel && d.champion && !celebrate {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { celebrate = true }
                Haptics.rare(); burstFire += 1
            }
            Sound.play(.transition)
            withAnimation(.easeInOut(duration: 0.4)) { beat = beat.next }
        }
    }

    /// 審査員を1人開く（M-1式＝1人ずつ・オーナー判断 Q2）。揺れ・閃光は付けない（決着と優勝だけ）
    private func revealJudge() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) { revealedJudges += 1 }
        Haptics.confirm()
        Sound.play(revealedJudges >= 7 ? .tada : .don)            // 1人ずつドン・全員出たらジャジャーン
        if revealedJudges >= 7 { Sound.play(.applauseHall) }
    }

    /// 長押しの早送り: 今の場面の残りの札を一度に開く（場面は飛ばさない・次へは通常のタップ）
    private func fastForwardBeat() {
        guard !holdingSeventh else { return }
        switch beat {
        case .open where revealedJudges < 7:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { revealedJudges = 7 }
            Haptics.confirm(); Sound.play(.tada); Sound.play(.applauseHall)
        case .duel where revealVotes < 7:
            let before = d.voteOrder.prefix(revealVotes).filter { $0 == d.winnerIndex }.count
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { revealVotes = 7 }
            if before < 4 {   // 早送りの中で決着が来た＝決着の一打だけは鳴らす
                slamFire += 1; Haptics.rare(); burstFire += 1
                Sound.play(.taiko); Sound.play(.cheerBig)
            }
        default:
            break
        }
    }

    // MARK: Beat 0 — 籤（出順）
    private var lotBeat: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 16)
            Telop(text: "出順発表", size: 17)
            // 金縁の出順プレート（テレビの札）
            VStack(spacing: 0) {
                Text("\(d.order)").font(.maru(74, weight: .black)).monospacedDigit()
                    .foregroundStyle(Theme.sumi)
                Text("番目 ／ 全10組").font(.maru(.sub)).foregroundStyle(Theme.goldDeep)
                    .padding(.bottom, 12)
            }
            .frame(width: 190)
            .background(Theme.mekuri, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(
                LinearGradient(colors: [Color(hex: 0xFFE9A8), Theme.gold, Color(hex: 0x8A6508)],
                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2.5))
            .shadow(color: Theme.gold.opacity(0.35), radius: 16, y: 6)
            Spacer(minLength: 16)
            NarrationCard(text: d.order == 1 ? "トップバッター。会場はまだ温まっていない。"
                          : d.order == 10 ? "大トリ。ここまでの空気を、全部ひっくり返す番だ。"
                          : "中盤。沸いた流れに、どう乗るか。")
                .padding(.bottom, 30)
        }
    }

    // MARK: Beat 1 — 7審査員 一斉オープン（見せ札）
    private var openBeat: some View {
        // M-1と同じく、7人全員の札が出るまで合計は出さない（途中の点数は伏せる・オーナー指摘 2026-10-10）
        let total = d.judges.reduce(0) { $0 + $1.score }
        let allShown = revealedJudges >= 7
        // 見せ札の型ラベル（v2 §4-3補2）: FinalsData（Σ=S補正・rng.int等）の計算には一切関与しない、
        // 既に確定済みの点数・出順の上に、選択中ネタの型を審査員の固定嗜好表で引いて添えるだけの純表示。
        let kata = session.selectedNeta?.kata
        return VStack(spacing: 14) {
            Telop(text: allShown ? "採点" : revealedJudges == 0 ? "採点発表" : "\(revealedJudges) / 7 人", size: 17)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 10) {
                ForEach(Array(d.judges.enumerated()), id: \.offset) { i, j in
                    judgeCard(j, shown: i < revealedJudges, kata: kata)
                }
            }
            VStack(spacing: 2) {
                Telop(text: allShown ? "\(total)" : "？？？", size: 64, color: allShown ? Color(hex: 0xFFE07A) : Theme.houseLight)
                    .monospacedDigit()
                    .punch(on: allShown, peak: 1.2)   // 7人目が開いた瞬間に初めて合計がドンと出る
                Telop(text: allShown ? "/ 700" : "……", size: 15, color: Theme.houseLight)
            }
            .padding(.top, 2)
            if let kata, allShown {
                NarrationCard(text: "\(NetaCatalog.displayName(kata))で挑んだ一本。")
            }
        }
    }

    private func judgeCard(_ j: JudgeScore, shown: Bool, kata: NetaKata?) -> some View {
        // M-1の採点開示＝審査員の「顔」の上に点数が出る（番組の画）。札は白紙＋墨、上の帯が重視軸の色。
        // 表と裏を別の面で描く＝回転の途中で面を切り替えるので鏡文字にならない（A2 §3-B1・L10 FlipCard）。
        let h: CGFloat = kata != nil ? 132 : 116
        return FlipCard(shown: shown) {
            judgeFace(j, kata: kata, height: h)
        } back: {
            judgeBack(j, height: h)
        }
        .scaleEffect(shown ? 1 : 0.96)
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: shown)
    }

    private func judgeFace(_ j: JudgeScore, kata: NetaKata?, height: CGFloat) -> some View {
        VStack(spacing: 4) {
            Text("\(j.score)").font(.maru(30, weight: .black)).monospacedDigit().foregroundStyle(Theme.sumi)
            CharacterFace(spec: FaceCatalog.judge(j.name), size: 40)
                .overlay(Circle().stroke(j.axisColor, lineWidth: 2))
            Text(j.name).font(.maru(.sub)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.6)
            if let kata {
                Text(NetaCatalog.affinity(kata, judge: j.name)).font(.maru(12, weight: .bold)).foregroundStyle(Theme.goldDeep)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .padding(.top, 9).padding(.horizontal, 4)
        .frame(maxWidth: .infinity).frame(height: height, alignment: .top)
        .background(Theme.mekuri, in: RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10).fill(j.axisColor).frame(height: 5)
        }
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.sumi.opacity(0.6), lineWidth: 1))
        .shadow(color: Theme.goldLeafLo.opacity(0.6), radius: 0, y: 4)
    }

    private func judgeBack(_ j: JudgeScore, height: CGFloat) -> some View {
        VStack(spacing: 4) {
            Text("？").font(.maru(30, weight: .black)).foregroundStyle(Theme.goldLeafMid)
            CharacterFace(spec: FaceCatalog.judge(j.name), size: 40)
                .saturation(0.35)
            Text(j.name).font(.maru(.sub)).foregroundStyle(Theme.inkSub).lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(.top, 9).padding(.horizontal, 4)
        .frame(maxWidth: .infinity).frame(height: height, alignment: .top)
        .background(Color(hex: 0xF3E6C6), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.goldLeafMid, lineWidth: 1.5))
        .shadow(color: Theme.goldLeafLo.opacity(0.6), radius: 0, y: 4)
    }

    // MARK: Beat 2 — 暫定ボード（全10組順位）
    private var boardBeat: some View {
        VStack(spacing: 5) {
            Telop(text: "暫定ボード", size: 17).padding(.bottom, 2)
            ForEach(Array(d.board.enumerated()), id: \.offset) { rank, row in
                HStack(spacing: 10) {
                    Text("\(rank + 1)").font(.maru(.body)).monospacedDigit()
                        .foregroundStyle(rank < 3 ? Theme.goldDeep : Theme.inkSub).frame(width: 24)
                    // 自組は付けたコンビ名で出す（「あなたたち」で名前が消えていた・A2 §1-7）
                    Text(row.isSelf ? session.combiName : row.name).font(.maru(row.isSelf ? .body : .bodyMedium))
                        .foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
                    Spacer()
                    Text("\(row.total)").font(.maru(.body)).monospacedDigit().foregroundStyle(Theme.sumi)
                }
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(row.isSelf ? Color(hex: 0xFFE9E2) : Theme.mekuri.opacity(0.94), in: RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .leading) {
                    if rank < 3 { Rectangle().fill(Theme.gold).frame(width: 4).clipShape(RoundedRectangle(cornerRadius: 2)) }
                }
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(row.isSelf ? Theme.verm : .clear, lineWidth: 2))
            }
            Telop(text: spectator ? "——今年の決勝。俺たちは、客席にいた。"
                  : d.champion || d.boardRank <= 3 ? "——上位3組。もう一本、最終決戦へ。" : "——決勝の舞台には立った。",
                  size: 15).padding(.top, 6)
        }
    }

    // MARK: Beat 3 — 最終決戦（M-1式＝3組・審査員7人が顔の上に組名札を掲げる）
    private var finalDuelBeat: some View {
        let names = duelNames
        let counts = (0..<3).map { k in d.voteOrder.prefix(revealVotes).filter { $0 == k }.count }
        return VStack(spacing: 14) {
            Telop(text: "最終決戦", size: 22, color: Color(hex: 0xFFE9A8))
            Telop(text: "勝ち残った3組。審査員は、面白かった方の名を書く。", size: 13)

            // 3組の得票カウンタ（番組のスコア表示・自組は金）
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { k in
                    trioCounter(name: names.count > k ? names[k] : "—", count: counts[k], mine: k == d.selfDuelIndex)
                }
            }

            // 審査員7人: 顔の上に票札（組名）が掲がる（M-1の票開示）
            HStack(spacing: 3) {
                ForEach(0..<7, id: \.self) { i in
                    let shown = i < revealVotes
                    let vote = d.voteOrder[i]
                    VStack(spacing: 3) {
                        votePlate(shown: shown, voteName: names.count > vote ? names[vote] : "—", forUs: vote == d.selfDuelIndex)
                        CharacterFace(spec: FaceCatalog.judge(d.judges[i].name), size: 40)
                            .overlay(Circle().stroke(shown ? (vote == d.selfDuelIndex ? Theme.gold : .white)
                                                           : .white.opacity(0.5), lineWidth: 2))
                        Text(String(d.judges[i].name.prefix(2)))
                            .font(.maru(12, weight: .bold)).foregroundStyle(Theme.sumi)
                            .padding(.horizontal, 4).background(Theme.mekuri.opacity(0.9), in: Capsule())
                    }
                }
            }
            VStack(spacing: 4) {
                Telop(text: revealVotes < 7 ? "タップで札をめくる（\(revealVotes)/7）" : "——開票、出揃った。",
                      size: 14, color: revealVotes < 7 ? Theme.houseLight : Color(hex: 0xFFE07A))
                if revealVotes < 7 { AdvanceCue(color: Theme.gold) }
            }
        }
    }

    private func trioCounter(name: String, count: Int, mine: Bool) -> some View {
        VStack(spacing: 1) {
            Text(name).font(.maru(.sub)).lineLimit(1).minimumScaleFactor(0.6)
                .foregroundStyle(Theme.ink)
            Text("\(count)")
                .font(.maru(34, weight: .black)).monospacedDigit()
                .foregroundStyle(mine ? Theme.vermD : Theme.sumi)
                .contentTransition(.numericText())
                .punch(on: count, peak: 1.3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Theme.mekuri, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(mine ? Theme.gold : Theme.paperEdge, lineWidth: mine ? 3 : 1))
        .shadow(color: Theme.goldLeafLo.opacity(0.6), radius: 0, y: 3)
    }

    /// 票札1枚: 組名が書かれた札が審査員の頭上に掲がる。自組＝朱地に金縁。表と裏を別の面で描く（鏡文字にならない）。
    private func votePlate(shown: Bool, voteName: String, forUs: Bool) -> some View {
        FlipCard(shown: shown) {
            Text(voteName)
                .font(.maru(12, weight: .black))
                .foregroundStyle(forUs ? Color(hex: 0xFFF3C8) : Theme.sumi)
                .lineLimit(2).minimumScaleFactor(0.5)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 2)
                .frame(width: 48, height: 46)
                .background(forUs ? AnyShapeStyle(LinearGradient(colors: [Theme.verm, Theme.vermD], startPoint: .top, endPoint: .bottom))
                                  : AnyShapeStyle(Theme.mekuri), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(forUs ? Theme.gold : Theme.paperEdge, lineWidth: forUs ? 2 : 1))
                .shadow(color: forUs ? Theme.verm.opacity(0.5) : .clear, radius: 6, y: 2)
        } back: {
            Text("？").font(.maru(17, weight: .black)).foregroundStyle(Theme.goldLeafMid)
                .frame(width: 48, height: 46)
                .background(Color(hex: 0xF3E6C6), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.goldLeafMid, lineWidth: 1.5))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: shown)
    }

    // MARK: Beat 4 — 優勝発表（3組から名前をコール）
    // 二人は舞台の上に立つ（StageFrame の performers）。名前はめくり札、判は金の丸判、耳打ちは谷口の吹き出し。
    private var resultBeat: some View {
        let names = duelNames
        let winnerName = names.count > d.winnerIndex ? names[d.winnerIndex] : session.combiName
        return VStack(spacing: 12) {
            Telop(text: "優勝は ——", size: 17)
            Text(winnerName)
                .font(.maru(30, weight: .black)).lineLimit(1).minimumScaleFactor(0.6)
                .foregroundStyle(Theme.sumi)
                .padding(.horizontal, 24).padding(.vertical, 10)
                .background(Theme.mekuri, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(d.champion ? Theme.gold : Theme.silver, lineWidth: 3))
                .shadow(color: (d.champion ? Theme.gold : Theme.silver).opacity(0.7), radius: 12)
                .scaleEffect(celebrate || !d.champion ? 1 : 1.6)
            if d.champion {
                Text("優勝").font(.maru(40, weight: .black)).foregroundStyle(Theme.onGold)
                    .frame(width: 128, height: 128)
                    .background(RadialGradient(colors: [Color(hex: 0xFFE07A), Theme.gold], center: .topLeading, startRadius: 5, endRadius: 140), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 4))
                    .rotationEffect(.degrees(-8)).shadow(color: Theme.gold.opacity(0.8), radius: 24, y: 8)
                    .scaleEffect(celebrate ? 1 : 2.0)
            } else if !spectator {
                Telop(text: "決勝", size: 30)
            }
            Spacer(minLength: 0)
            // 余韻（文言は既存のまま・地の文と台詞を分けただけ）
            if d.champion {
                VStack(spacing: 10) {
                    NarrationCard(text: "谷口が、そっと耳打ちした。")
                    TalkBubble(advice: Advice(name: "谷口", text: "……なあ、腹減ったな"))
                }
            } else if spectator {
                NarrationCard(text: "客席の照明が上がる前に、二人で席を立った。")
            } else {
                NarrationCard(text: "届かなかった。だが、この夜の舞台には立った。")
            }
            Button {
                if spectator { onFinishSpectating?(winnerName) }
                else if d.champion { session.acknowledgeWin() } else { session.acknowledgeResult() }
            } label: {
                Text(spectator ? "次の週へ ▶" : "結果を見る ▶").font(.maru(.body)).foregroundStyle(Theme.onGold)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Theme.gold, in: RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Theme.goldD, radius: 0, y: 3)
            }
            .buttonStyle(PressableStyle()).padding(.horizontal, 24).padding(.bottom, 28)
        }
        .frame(maxHeight: .infinity)
        .onAppear {
            if d.champion {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.55).delay(0.2)) { celebrate = true }
                Sound.play(.fanfare); Sound.play(.cheerBig)   // 優勝＝ファンファーレ＋大歓声
            } else {
                silverFire += 1                                // 他組の優勝・決勝敗退は銀の紙吹雪だけ
                Sound.play(.applauseHall)
            }
        }
    }
}

// MARK: - 見せ札の合成（単一結果→7審査員の点・順位・票。GameCore非消費・UI専用の決定的RNG）

struct JudgeScore { let name: String; let score: Int; let axisColor: Color }
struct BoardRow { let name: String; let total: Int; let isSelf: Bool }
/// 決勝の1組（出順つき）。自組は isSelf（名前は表示時に session.combiName に差し替える）
struct FinalsEntry { let name: String; let total: Int; let order: Int; let isSelf: Bool }

struct FinalsData {
    /// 自組の出順（1〜10・観客モードは 0）
    let order: Int
    /// 自組の合計（観客モードは 0）
    let total: Int
    let judges: [JudgeScore]
    /// 10組（出順つき）。M-1 と同じく、出順どおりに1組ずつ出てボードに載る
    let entries: [FinalsEntry]
    /// 1本目の最終順位（全組・合計の高い順）
    var board: [BoardRow]
    /// 自組の1本目の順位（観客モードは 0）
    var boardRank: Int
    let finalVotes: Int
    let champion: Bool
    /// 最終決戦の3組（1本目の順位順）。自組が4位以下の年は、自組を含まない3組
    var duelEntries: [FinalsEntry] = []
    /// 票札のめくり順（duelEntries の添字）。表示専用のシャッフル
    var voteOrder: [Int] = []
    /// 優勝コンビ（duelEntries の添字）
    var winnerIndex: Int = 0
    /// 自組が最終決戦に立つか
    var selfInDuel: Bool { duelEntries.contains { $0.isSelf } }
    /// 最終決戦での自組の添字（立たない年は nil）
    var selfDuelIndex: Int? { duelEntries.firstIndex { $0.isSelf } }

    /// - margin: GameCore の決勝のスコアと実効ラインの差（正＝優勝）。順位をこの差に沿わせる＝見せ札が内部の結果と矛盾しない
    /// - year: 年ごとに決勝の顔ぶれと出順を変える（毎年同じ10組にしない）
    init(state s: GameState, champion: Bool, spectator: Bool = false, margin: Double? = nil, year: Int = 1) {
        self.champion = champion
        // UI専用RNG（能力と年から決定的にseed＝再現可・GameCoreの乱数列に非干渉）
        var rng = SeededRng(seed: UInt64(bitPattern: Int64(
            Int(s.発想) &* 131 &+ Int(s.センス) &* 197 &+ Int(s.表現) &* 251 &+
            Int(s.華) &* 313 &+ Int(s.メンタル) &* 389 &+ Int(s.compat) &* 457 &+ year &* 7919 &+ 0x1F17)))

        // 今年の顔ぶれ（名簿から決定的に選ぶ。常連は毎年いるとは限らない）
        var pool = FinalsData.npcNames
        for i in stride(from: pool.count - 1, through: 1, by: -1) { pool.swapAt(i, rng.int(0...i)) }
        let npcCount = spectator ? 10 : 9
        let names = Array(pool.prefix(npcCount))

        // 自組の1本目の順位（内部の結果＝決勝の点差から）。優勝の年でも1本目1位とは限らない（R1 P7）
        let rank: Int
        if spectator {
            rank = 0
        } else if champion {
            let m = margin ?? 6
            rank = m >= 8 ? 1 : (m >= 3 ? rng.int(1...2) : rng.int(1...3))
        } else if let m = margin, m >= -4 {
            rank = rng.int(1...3)          // 惜敗＝最終決戦まで残って、そこで敗れる
        } else {
            let m = margin ?? -12          // 大きく届かない＝1本目で敗退（4〜10位）
            rank = min(10, max(4, 4 + Int((-m - 4) / 3) + rng.int(0...1)))
        }

        // 表示合計S（/700・帯写像＝内部式の逆算防止のため帯内ジッタ）【仮】
        let total: Int
        if spectator { total = 0 }
        else if champion { total = rng.int(632...668) }
        else if rank <= 3 { total = rng.int(618...645) }
        else { total = max(560, min(630, 628 - (rank - 4) * 7 + rng.int(-3...3))) }
        self.total = total
        let myOrder = spectator ? 0 : rng.int(1...10)
        self.order = myOrder
        self.boardRank = rank

        // 7審査員（自組の採点）: raw = S/7 + 人格bias + 重視軸tilt + ノイズ → Σ=S補正 → [50,99]クランプ
        let base = Double(max(total, 600)) / 7.0
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
        var ints = raw.map { Int($0.rounded()) }
        if !spectator {
            // Σ=S へ丸め補正
            var diff = total - ints.reduce(0, +)
            var idx = 0
            while diff != 0 && idx < 100 { let k = idx % 7; ints[k] += diff > 0 ? 1 : -1; diff += diff > 0 ? -1 : 1; idx += 1 }
        }
        ints = ints.map { max(50, min(99, $0)) }
        self.judges = zip(specs, ints).map { JudgeScore(name: $0.name, score: $1, axisColor: $0.color) }

        // 他組の合計: 自組より上に (rank−1) 組、残りは下（観客モードは10組を帯の中で）。同点は作らない
        var npcTotals: [Int] = []
        if spectator {
            for _ in 0..<npcCount { npcTotals.append(rng.int(565...662)) }
        } else {
            for i in 0..<npcCount {
                npcTotals.append(i < rank - 1 ? min(699, total + rng.int(1...22)) : max(520, total - rng.int(1...48)))
            }
        }
        var used: Set<Int> = spectator ? [] : [total]
        npcTotals = npcTotals.map { t in
            var v = t
            let above = !spectator && t > total
            while used.contains(v) { v += above ? 1 : -1 }
            used.insert(v)
            return v
        }

        // 出順: 自組は order、他組は残りの番号をシャッフル
        var orders = Array(1...10).filter { $0 != myOrder }
        for i in stride(from: orders.count - 1, through: 1, by: -1) { orders.swapAt(i, rng.int(0...i)) }
        var all = zip(names, npcTotals).enumerated().map { i, nt in
            FinalsEntry(name: nt.0, total: nt.1, order: orders[i], isSelf: false)
        }
        if !spectator { all.append(FinalsEntry(name: "あなたたち", total: total, order: myOrder, isSelf: true)) }
        self.entries = all.sorted { $0.order < $1.order }
        let ranked = all.sorted { $0.total > $1.total }
        self.board = ranked.map { BoardRow(name: $0.name, total: $0.total, isSelf: $0.isSelf) }

        // 最終決戦（M-1式＝1本目の上位3組・7票）
        let duel = Array(ranked.prefix(3))
        self.duelEntries = duel
        let selfIdx = duel.firstIndex { $0.isSelf }
        let winner: Int
        if champion, let si = selfIdx {
            winner = si
        } else {
            // 自組以外の誰か（1本目の順位が高いほど勝ちやすい・表示だけ）
            let cands = (0..<3).filter { $0 != selfIdx }
            let roll = rng.int(1...10)
            winner = roll <= 5 ? cands[0] : (roll <= 8 || cands.count < 3 ? cands[min(1, cands.count - 1)] : cands[2])
        }
        self.winnerIndex = winner
        let w = rng.int(4...7)                                   // 勝者は必ず過半数
        self.finalVotes = selfIdx == nil ? 0 : (selfIdx == winner ? w : 0)
        var counts = [0, 0, 0]
        counts[winner] = w
        let others = (0..<3).filter { $0 != winner }
        let a = rng.int(0...(7 - w))
        counts[others[0]] = a
        counts[others[1]] = 7 - w - a
        var vorder = counts.enumerated().flatMap { Array(repeating: $0.offset, count: $0.element) }
        for i in stride(from: 6, through: 1, by: -1) { vorder.swapAt(i, rng.int(0...i)) }
        self.voteOrder = vorder
    }

    /// NPCコンビ名（架空・プレースホルダ枠。本来は name_generator が毎周生成）。年ごとにこの中から9〜10組を選ぶ
    static let npcNames = ["紺屋", "夜明けの犬", "サーカス", "青写真", "十三", "静物画", "テレフォン", "北緯", "帰り道",
                           "灯台守", "三番線", "東口", "ペンギン座", "トランジスタ", "まどろみ", "夕凪", "赤鉛筆", "合鍵"]
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
