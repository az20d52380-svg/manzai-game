// FinalsPresentationView.swift
// M-1本家型 決勝演出（uiux_vision_reply_part1 §4-2b/c/d ＋ Fable doc03 の7審査員）。
// M-1と同じ進行（comedy_research_v2/r1 §2・§7 P2/P3・2026-10-10）: 先に出る組が出順どおり1組ずつ出てボードに載る →
// 自組の籤 → ネタ → 7審査員を1人ずつ開く(合計は全員の後) → 暫定席に入るか敗退か → 後の組が1組ずつ出て暫定席が入れ替わる
// → 上位3組の最終決戦めくり(票) → 優勝。観客モードは10組を順に観てから最終決戦。
// ★絶対制約: 全て「単一の内部結果(outcome)」からの演出的合成。GameCoreの判定・乱数列には一切触れない＝golden不変。
// 数値は全て【仮・実機目視で調整】。表示用RNGは state から決定的に seed（再現可・GameCore非消費）。

import SwiftUI
import GameCore

/// 決勝のビート（順に進む・飛ばさない）。中身の無いビート（出順1番の「先の組」）だけは入らない。
enum FinalsBeat: Int, Comparable {
    case lot = 0       // 自組の籤（出順）＝番組の最初（導入→くじ→1組目…）
    case preceding = 1 // 自組より前の出順の組が1組ずつ出る（自動で送る・タップで次の組）
    case perform = 2   // ネタ（舞台の二人・歓声。自動で採点へ）
    case open = 3      // 7審査員の採点（1人ずつ開く＝オーナー判断 2026-10-09）
    case comments = 4  // 司会が審査員2人（最高点・最低点）に講評を振る（r1 §3・P4）
    case board = 5     // 自組がボードに入る → 後の組が1組ずつ出て暫定席が入れ替わる → 1本目の確定
    case duel = 6      // 最終決戦（めくり）
    case result = 7    // 優勝発表
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
    /// ボードに載った組の数（出順の先頭から）。先の組→自組→後の組の順に増える
    @State private var shown = 0
    /// 自組がボードに入った後、後の組を自動で流し始めたか（自組の入りの瞬間はタップを待つ）
    @State private var boardAuto = false
    /// 講評の何人目か（0=最高点の審査員・1=最低点の審査員）
    @State private var commentStep = 0
    @State private var revealedJudges = 0  // 見せ札を1人ずつ開示（M-1式・0..7）
    @State private var revealVotes = 0     // 最終決戦のめくり票数
    @State private var celebrate = false   // 優勝の紙吹雪・スタンプ
    @State private var slamFire = 0        // 開示のたびの衝撃（フラッシュ＋シェイク・Juice.swift）
    @State private var burstFire = 0       // 決着の紙吹雪バースト
    /// 開演の儀が終わったか（決勝の入りの儀式・L11）
    @State private var ceremonyDone = false
    /// 番組導入（煽りV→タイトル→審査員席→進出組）が終わったか。終わると開演の儀へ
    @State private var introDone = false
    #if DEBUG
    // 目視用: 子の onAppear が親より先に走るため、MZ_FIN の導入場面は初期値で渡す
    @State private var introStart: FinalsIntroStage = FinalsIntroStage.debug(ProcessInfo.processInfo.environment["MZ_FIN"] ?? "") ?? .vtr
    #else
    @State private var introStart: FinalsIntroStage = .vtr
    #endif
    /// 銀の紙吹雪（他組の優勝・自組の決勝敗退）
    @State private var silverFire = 0
    /// 7人目の前の間（全SE断＋BGMを絞る0.6s）。この間のタップは受けない
    @State private var holdingSeventh = false
    // 番組の演出（見せ方だけ・結果は FinalsData のまま）
    @State private var lotRevealed = false     // 出番くじ: 心拍のあと出順が出る
    @State private var lotPulse = false
    @State private var doorsOpen = false       // 登場の扉
    @State private var entranceFull = false    // 登場の扉の初回フル
    @State private var duelFull = false        // 王手の溜めの初回フル
    @State private var totalCount: Double = 0  // 合計点のカウントアップ
    @State private var showChamp = false       // 優勝の瞬間（YoseChampionCelebrationView）
    @State private var showEnding = false      // 番組のエンディング
    @State private var endingFull = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            return FinalsData(state: s, champion: m > 0, margin: m, year: session.year, selfName: session.combiName)
        }
        #endif
        return FinalsData(state: s, champion: !spectator && session.winFinale, spectator: spectator,
                          margin: spectator ? nil : margin, year: session.year, selfName: session.combiName)
    }
    /// 1組の表示名（自組は付けたコンビ名）
    private func displayName(_ e: FinalsEntry) -> String { e.isSelf ? session.combiName : e.name }
    /// 最終決戦の3組名（1本目の順位順。自組が4位以下の年は他の3組）
    private var duelNames: [String] { d.duelEntries.map(displayName) }

    /// ビート→舞台の状態。籤＝開演前／採点〜最終決戦＝金屏風（客席から観る年は銀）／結果＝自組の優勝だけ最明部
    private var stageMode: StageFrame.Mode {
        switch beat {
        case .lot: return .preshow
        case .perform: return .lit
        case .preceding, .open, .comments, .board, .duel: return spectator ? .spectator : .judging
        case .result: return d.champion ? .winner : (spectator ? .spectator : .loser)
        }
    }
    /// 舞台に二人を立たせるビート（籤＝これから立つ舞台／ネタ中／優勝＝二人が画面にいる・A2 §1-9）
    private var stagePerformers: Bool { beat == .lot || beat == .perform || (beat == .result && !spectator) }
    /// ボードの n 組時点の順位（合計の高い順）
    private func standings(_ n: Int) -> [FinalsEntry] {
        Array(d.entries.prefix(n)).sorted { $0.total > $1.total }
    }
    /// 自動送りの鍵（ビート・自動開始・開演の儀の終わりが変わるたびに張り直す）
    private var autoKey: String { "\(beat.rawValue)-\(boardAuto)-\(ceremonyDone)" }

    var body: some View {
        ZStack {
            // 暖色の客席に光る舞台（オーナー判断 Q1=A・visual_genre_overhaul_v1 §6 F1）。採点〜最終決戦は金屏風
            StageFrame(mode: stageMode, performers: stagePerformers,
                       floorTop: beat == .lot ? 0.60 : (beat == .result ? 0.62 : (beat == .perform ? 0.58 : 0.56)))
                .animation(.easeInOut(duration: 0.5), value: beat)
            FinalsStudioLights(duel: beat == .duel)   // スタジオ照明（最終決戦だけ真紅×群青）
            if beat == .perform {   // ネタ中：舞台袖のめくり（コンビ名）
                VStack { Spacer(); HStack { Spacer(); StageMakuri(name: spectator ? "客席" : session.combiName).padding(.trailing, 20) }.padding(.bottom, 190) }
                    .allowsHitTesting(false)
            }
            if celebrate && d.champion {
                // 金の放射光と紙吹雪は自組の優勝の夜だけ（他組の優勝・決勝敗退には降らない・A2 §3-B2）
                RaysView().ignoresSafeArea().allowsHitTesting(false)
                ConfettiView().ignoresSafeArea().allowsHitTesting(false)
            }

            // 下半分の座布団（観客の頭・床の茶色を黒漆で沈め、ボタンの土台にする）
            VStack(spacing: 0) {
                Spacer()
                LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: YoseColor.kuroUrushi.opacity(0.92), location: 0.16),
                                       .init(color: YoseColor.kuroUrushi, location: 0.36)], startPoint: .top, endPoint: .bottom)   // ボタンと黒帯の間に客の頭を挟まない
                    .frame(height: 170)
            }
            .ignoresSafeArea().allowsHitTesting(false)
            if spectator {   // 観戦の年は舞台を少し暗めに（自分は立てなかった夜）
                Rectangle().fill(Color.black.opacity(0.22)).ignoresSafeArea().allowsHitTesting(false)
            }
            if let n = centerMakuriName {   // 出番の組のめくり札（無人の舞台に立てる・人形は増やさない）
                GeometryReader { geo in
                    StageMakuri(name: n, big: true).id(n)
                        .scaleEffect(beat == .open && n.count > 4 ? 0.82 : 1)   // 開票中は合計箱の下に収める
                        .position(x: geo.size.width / 2, y: geo.size.height * (beat == .comments ? 0.45 : (beat == .open ? 0.70 : 0.665)))
                        .transition(.opacity)
                }
                .allowsHitTesting(false)
            }

            if beat == .perform {   // 登場の扉（割れて逆光＋紹介テロップ）
                FinalsEntranceDoors(open: doorsOpen, order: d.order, name: spectator ? "客席" : session.combiName, year: session.year)
            }
            VStack(spacing: 10) {
                FinalsLiveBar(scene: liveSceneName, trailing: spectator ? "客席から観戦" : (d.order > 0 ? "第\(d.order)番手" : nil))
                broadcastTitle

                Group {
                    switch beat {
                    case .preceding: precedingBeat
                    case .lot: lotBeat
                    case .perform: performBeat
                    case .open: openBeat
                    case .comments: commentsBeat
                    case .board: boardBeat
                    case .duel: finalDuelBeat
                    case .result: resultBeat
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if beat < .result, beat != .perform, !(beat == .duel && revealVotes < 7) {
                    // 送りは下部固定の朱の主ボタン1つ（画面のどこをタップしても進む仕様は不変・押し場所を見せるだけ）
                    Button { if ceremonyDone { advance() } } label: { Text(advanceLabel) }
                        .buttonStyle(YoseButtonStyle(.primary))
                        .padding(.bottom, 6)
                }
            }
            .padding(.horizontal, YoseMetrics.screenMargin).padding(.top, 8).padding(.bottom, 62)

            // 下部テロップ（番組の下三分帯・コンビ名）
            VStack { Spacer()
                lowerThird
            }.ignoresSafeArea(edges: .bottom).allowsHitTesting(false)
        }
        .overlay {
            ParticleBurst(trigger: burstFire, colors: [YoseColor.kinBright, YoseColor.kin, YoseColor.shu, YoseColor.washi],
                          style: .confetti, count: 60, origin: UnitPoint(x: 0.5, y: 0.42))
            // 他組の優勝・自組の決勝敗退＝銀の紙吹雪（負けの夜にも同じ物量・金は使わない・X2-06）
            ParticleBurst(trigger: silverFire, colors: [YoseColor.ginNezu, YoseColor.washi, YoseColor.haiSumi],
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
                if !introDone {
                    FinalsBroadcastIntro(combiName: session.combiName, year: session.year, spectator: spectator,
                                         finalists: d.entries.map { (name: displayName($0), isSelf: $0.isSelf) },
                                         startStage: introStart) {
                        withAnimation(.easeOut(duration: 0.3)) { introDone = true }
                    }
                    .transition(.opacity)
                } else {
                    StageCeremony { ceremonyDone = true }
                        .transition(.opacity)
                }
            }
        }
        .overlay {
            if showChamp {   // 優勝の瞬間（金テープ・大判優勝めくり・賞金ボード・相方の言葉）。タップで即完成→もう一度タップで先へ
                YoseChampionCelebrationView(tournamentName: "頂グランプリ 決勝戦", generationText: "結成\(session.year)年目",
                                            duoName: session.combiName, prizeAmountYen: session.config.calendar.gpPrize,
                                            partnerName: Names.partner, partnerLine: "「……ほんまに、勝ったんやな」") {
                    withAnimation(.easeOut(duration: 0.3)) { showChamp = false }
                    // 優勝年は全画面の後に「優勝は……！」の結果発表を重ねない（結果が2度伝わるため）＝そのまま番組エンディングへ
                    endingFull = FinalsSeen.first("ending") && !reduceMotion
                    showEnding = true
                }
                .transition(.opacity)
            }
        }
        .overlay {
            if showEnding {   // 番組のエンディング（優勝組・最終決戦の3組・出場組→放送はここまで）
                FinalsBroadcastEnding(winnerName: resultWinnerName, champion: d.champion, spectator: spectator,
                                      duelNames: duelNames, allNames: d.entries.map(displayName),
                                      short: !endingFull) {
                    showEnding = false
                    finishResult()
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            if dataCache == nil { dataCache = makeData() }
            Sound.bgm(.finals)   // 番組のBGM（決勝の格）
            if spectator {
                beat = .board; shown = 0; boardAuto = true   // 観客は10組を出順どおりに観てから最終決戦
            } else {
                beat = .lot                                    // くじが最初（先の組はそのあと・トップバッターは先の組が無い）
            }
            #if DEBUG
            // 目視用: MZ_FIN=pre/open/board/duel/win で各ビートへ直行（タップ注入できないCLI検証のため）
            let fin = ProcessInfo.processInfo.environment["MZ_FIN"] ?? ""
            if let st = FinalsIntroStage.debug(fin) { introStart = st }   // MZ_FIN=vtr/title/judges/finalists で番組導入の各場面へ
            else if !fin.isEmpty { introDone = true }                     // 他の MZ_FIN は導入を飛ばして直行
            switch fin {
            case "lot": beat = .lot
            case "pre": beat = .preceding; shown = max(0, d.order - 1)
            case "open": beat = .open; revealedJudges = 5
            case "comments": beat = .comments; revealedJudges = 7
            case "board": beat = .board; shown = 10; boardAuto = true
            case "duel": beat = .duel; revealVotes = 5; duelFull = true
            case "win": beat = .result
            case "door": beat = .perform; entranceFull = true
            case "total": beat = .open; revealedJudges = 7; totalCount = Double(d.total)
            case "seats": beat = .board; shown = min(d.entries.count, 6); boardAuto = true
            case "oute":   // 王手（3票）の瞬間
                beat = .duel; duelFull = true
                for k in 0...7 where (0..<3).map({ j in d.voteOrder.prefix(k).filter { $0 == j }.count }).max() == 3 { revealVotes = k; break }
            case "champ": beat = .result; if d.champion && !spectator { showChamp = true }
            case "ending": beat = .result; endingFull = true; showEnding = true
            default: break
            }
            #endif
        }
        // 先の組・後の組の自動送り（1.25秒ごとに1組）とネタの間（1.8秒で採点へ）。タップはいつでも次へ
        .task(id: autoKey) {
            guard ceremonyDone else { return }
            if beat == .perform {
                if entranceFull && !reduceMotion {   // 扉が割れる→紹介テロップ→ネタ（初回は長め）
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    withAnimation { doorsOpen = true }
                    Haptics.confirm()          // se_door_open_heavy（大扉が割れる）
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                } else {
                    doorsOpen = true
                    try? await Task.sleep(nanoseconds: 1_800_000_000)
                }
                if !Task.isCancelled, beat == .perform { goNext() }
                return
            }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_250_000_000)
                if Task.isCancelled { return }
                if beat == .preceding, shown < d.order - 1 { stepBoard() }
                else if beat == .board, boardAuto, shown < d.entries.count { stepBoard() }
                else { return }
            }
        }
    }

    /// 番組タイトル（黒×金の中継グラフィック）
    private var broadcastTitle: some View {
        VStack(spacing: 6) {
            StageSign(title: "頂 グランプリ", subtitle: spectator ? "客席から観戦中" : nil, tag: "決勝", outlined: true)
                .padding(.horizontal, -4)
            if spectator {
                Text("※ 予選敗退のため、客席から決勝を観戦しています")
                    .font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.kinari)
                    .frame(maxWidth: .infinity).frame(height: 26).background(YoseColor.enji)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
            }
        }
    }

    /// 下部の主ボタンの文言（押すと画面タップと同じ advance）
    private var advanceLabel: String {
        switch beat {
        case .preceding: return shown < d.order - 1 ? "次の組を見る ▶" : "舞台へ ▶"
        case .lot: return lotRevealed ? (d.order > 1 ? "先の組を見る ▶" : "舞台へ ▶") : "くじの結果を見る ▶"
        case .perform: return ""
        case .open: return revealedJudges < 7 ? "審査員の得点をめくる（\(min(7, revealedJudges + 1))/7）▶" : "講評へ ▶"
        case .comments: return commentStep < commentPicks.count - 1 ? "次の講評へ ▶" : "順位ボードへ ▶"
        case .board: return !boardAuto ? "後の組を見る ▶" : (shown < d.entries.count ? "次の組を見る ▶" : "最終決戦へ 進む ▶")
        case .duel: return "優勝発表へ ▶"
        case .result: return ""
        }
    }
    /// 舞台中央に立てる出番の組のめくり札（先の組・ボード進行中・講評中の自組）。無ければ nil
    private var centerMakuriName: String? {
        switch beat {
        case .preceding where shown >= 1 && shown <= 5: return displayName(d.entries[shown - 1])
        case .board where boardAuto && shown >= 1 && shown <= 5 && shown < d.entries.count: return displayName(d.entries[shown - 1])
        case .comments: return session.combiName
        case .open: return session.combiName   // 開票中も舞台に自組のめくり札（無人の床を見せない）
        default: return nil
        }
    }

    /// 下部テロップ帯（コンビ名・M-1の下三分）。今が何番手かを常に出す
    private var lowerThird: some View {
        StageLowerBand(name: spectator ? session.combiName : session.combiName,
                       left: spectator ? "客席から" : nil,
                       tag: spectator ? "結成\(session.year)年目・観戦" : (d.order > 0 ? "結成\(session.year)年目・第\(d.order)番" : "結成\(session.year)年目"))
    }

    private func advance() {
        guard !holdingSeventh else { return }
        switch beat {
        case .preceding where shown < d.order - 1:
            stepBoard()
        case .comments where commentStep < commentPicks.count - 1:
            withAnimation(.easeOut(duration: 0.25)) { commentStep += 1 }
            Sound.play(.cursor); Haptics.tick()
        case .board where !boardAuto:
            boardAuto = true      // 自組の入りを見せた後のタップ＝後の組を流し始める（最初の1組はすぐ出す・大トリなら確定へ）
            if shown < d.entries.count { stepBoard() }
        case .board where shown < d.entries.count:
            stepBoard()
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
        case .lot where !lotRevealed:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { lotRevealed = true }   // くじの溜めを畳む
            Haptics.rare()
        case .duel where revealVotes < 7:
            // 王手（勝者の3票）の次が決着の札なら、めくる前に溜める（全SE断＋BGMを絞る・初回0.9秒／以降0.35秒）
            let before = d.voteOrder.prefix(revealVotes).filter { $0 == d.winnerIndex }.count
            if before == 3 && d.voteOrder[revealVotes] == d.winnerIndex {
                holdingSeventh = true
                Sound.hushSE(true); Sound.duck(0.25, over: 0.2)       // se_silence_tension（決定票の前の無音）
                Haptics.tick()
                let hold: UInt64 = duelFull && !reduceMotion ? 900_000_000 : 350_000_000
                Task {
                    try? await Task.sleep(nanoseconds: hold)
                    Sound.hushSE(false); Sound.duck(1, over: 0.4)
                    holdingSeventh = false
                    revealVote()
                }
            } else {
                revealVote()
            }
        default:
            if beat == .duel && d.champion && !celebrate {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { celebrate = true }
                Haptics.rare(); burstFire += 1
            }
            goNext()
        }
    }

    /// 最終決戦の票札を1枚めくる
    private func revealVote() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) { revealVotes += 1 } // めくり1枚
        let winCount = d.voteOrder.prefix(revealVotes).filter { $0 == d.winnerIndex }.count
        if winCount == 4 {                                          // 過半数到達＝その瞬間に決着
            slamFire += 1                                           // 揺れ・閃光は決着の1回だけ（X2-26〜28）
            Haptics.rare(); burstFire += 1
            Sound.play(.taiko); Sound.play(.cheerBig)              // 決着＝太鼓＋大歓声
            if revealVotes < 7 {                                    // 4票で決まったあとの残りの札：1拍おいて、早めに1枚ずつ開く（連打の手間を省く）
                holdingSeventh = true
                Task {
                    try? await Task.sleep(nanoseconds: 1_100_000_000)
                    while revealVotes < 7 {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { revealVotes += 1 }
                        Haptics.confirm(); Sound.play(.don)
                        try? await Task.sleep(nanoseconds: 380_000_000)
                    }
                    holdingSeventh = false
                }
            }
        } else {
            Haptics.confirm()
            Sound.play(.don)                                       // 札1枚＝ドン
        }
    }

    /// 結果画面の出口（番組エンディングのあとに呼ぶ）
    private func finishResult() {
        if spectator { onFinishSpectating?(resultWinnerName) }
        else if d.champion { session.acknowledgeWin() } else { session.acknowledgeResult() }
    }
    private var resultWinnerName: String {
        let names = duelNames
        return names.count > d.winnerIndex ? names[d.winnerIndex] : session.combiName
    }
    /// LIVE ヘッダーの場面名
    private var liveSceneName: String {
        switch beat {
        case .lot: return "出番くじ"
        case .preceding: return "ファーストラウンド"
        case .perform: return "登場・ネタ披露"
        case .open: return "採点発表"
        case .comments: return "審査員講評"
        case .board: return "暫定ボード"
        case .duel: return "最終決戦"
        case .result: return "結果発表"
        }
    }

    /// 次のビートへ。ボードに入る瞬間は自組の行を載せ、暫定席に入れたかを音で返す
    private func goNext() {
        let nextBeat = (beat == .lot && d.order <= 1) ? FinalsBeat.perform : beat.next   // トップバッターは先の組を飛ばす
        Sound.play(.transition)
        if nextBeat == .perform { doorsOpen = false; entranceFull = FinalsSeen.first("door") }
        if nextBeat == .duel { duelFull = FinalsSeen.first("duel") }
        if nextBeat == .result && d.champion && !spectator {   // 優勝の瞬間へ接続（結果発表の画面は挟まない＝閉じたら番組エンディング）
            showChamp = true
            return
        }
        if nextBeat == .board && !spectator {
            shown = d.order
            boardAuto = false
            let rank = (standings(shown).firstIndex { $0.isSelf } ?? 0) + 1
            if rank <= 3 { Sound.play(.cheerMid); Haptics.confirm() } else { Sound.play(.taiko2); Haptics.rare() }
        }
        withAnimation(.easeInOut(duration: 0.4)) { beat = nextBeat }
    }

    /// ボードに次の組を1組載せる。暫定席（上位3）に入れば「ドン」、自組が押し出されたら重い太鼓
    private func stepBoard() {
        guard shown < d.entries.count else { return }
        let wasSelfSeated = standings(shown).prefix(3).contains { $0.isSelf }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { shown += 1 }
        let entry = d.entries[shown - 1]
        let top = standings(shown).prefix(3)
        let seated = top.contains { $0.order == entry.order }
        if wasSelfSeated && !top.contains(where: { $0.isSelf }) {
            Sound.play(.taiko2); Haptics.rare()            // 自組が席を立つ
        } else if seated {
            Sound.play(.don); Haptics.confirm()            // 暫定席に入った
        } else {
            Sound.play(.applauseSmall); Haptics.tick()
        }
    }

    /// 審査員を1人開く（M-1式＝1人ずつ・オーナー判断 Q2）。揺れ・閃光は付けない（決着と優勝だけ）
    private func revealJudge() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) { revealedJudges += 1 }
        // se_score_flip_electronic_wood ×7／95点以上は se_crowd_gasp_high（どよめき）と強い振動
        if d.judges.indices.contains(revealedJudges - 1), d.judges[revealedJudges - 1].score >= 95 { Haptics.rare() } else { Haptics.confirm() }
        Sound.play(revealedJudges >= 7 ? .tada : .don)            // 1人ずつドン・全員出たらジャジャーン
        if revealedJudges >= 7 { Sound.play(.applauseHall) }
    }

    /// 長押しの早送り: 今の場面の残りの札を一度に開く（場面は飛ばさない・次へは通常のタップ）
    private func fastForwardBeat() {
        guard !holdingSeventh else { return }
        switch beat {
        case .preceding where shown < d.order - 1:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { shown = d.order - 1 }
            Haptics.confirm()
        case .board where shown < d.entries.count:
            boardAuto = true
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { shown = d.entries.count }
            Haptics.confirm()
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
        // 札は上に小さく置き、舞台の二人（StageFrame の performers）を隠さない
        let slots = d.entries.sorted { $0.order < $1.order }
        return VStack(spacing: 8) {
            // 中央メイン札（出順抽選）
            VStack(spacing: 2) {
                Text("出順抽選").font(YoseFont.captionBold).tracking(3).foregroundStyle(YoseColor.enji)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("第").font(YoseFont.mincho(20)).foregroundStyle(YoseColor.sumi)
                    Text(lotRevealed ? "\(d.order)" : "？").font(YoseFont.number(48, weight: .black)).foregroundStyle(YoseColor.shu)
                        .scaleEffect(lotRevealed ? 1 : (lotPulse ? 1.25 : 0.95))
                        .punch(on: lotRevealed, peak: 1.4)
                    Text("番").font(YoseFont.mincho(20)).foregroundStyle(YoseColor.sumi)
                    Text("／ 全10組").font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.haiSumi)
                }
                Text(session.combiName).font(YoseFont.mincho(22)).foregroundStyle(YoseColor.sumi)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 28).padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .yoseKifuda(showNail: true)
            .overlay(RoundedRectangle(cornerRadius: YoseMetrics.radius).stroke(YoseColor.kin, lineWidth: 1.5).padding(6))
            .padding(.horizontal, 20)
            Spacer(minLength: 96)
            // 全10組の出順番付（縦長の木札・2段×5列。自組だけ朱枠＋「あなた」の朱判）
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 5), spacing: 8) {
                ForEach(slots, id: \.order) { e in
                    VStack(spacing: 2) {
                        Text("\(e.order)").font(YoseFont.number(17, weight: .black))
                            .foregroundStyle(e.isSelf ? YoseColor.shu : YoseColor.enji)
                        let chars = Array(displayName(e)).map(String.init)
                        let half = (chars.count + 1) / 2
                        let cols: [[String]] = chars.count > 5 ? [Array(chars.prefix(half)), Array(chars.dropFirst(half))] : [chars]
                        HStack(alignment: .top, spacing: 1) {   // 長い名は2列（右の列から読む縦書き）
                            ForEach(Array(cols.enumerated()), id: \.offset) { _, col in
                                VStack(spacing: 0) {
                                    ForEach(Array(col.enumerated()), id: \.offset) { _, c in
                                        Text(c).font(YoseFont.mincho(12)).foregroundStyle(YoseColor.sumi)
                                    }
                                }
                            }
                        }
                        .environment(\.layoutDirection, .rightToLeft)
                        Spacer(minLength: 0)
                        if e.isSelf { Text("あなた").font(YoseFont.gothic(9, weight: .heavy)).foregroundStyle(YoseColor.kinari)
                            .frame(maxWidth: .infinity).padding(.vertical, 2).background(YoseColor.shu) }
                    }
                    .padding(.top, 9).padding(.horizontal, 2)
                    .frame(maxWidth: .infinity).frame(height: 98)
                    .yoseKifuda(showNail: true)
                    .overlay { if e.isSelf && lotRevealed { Rectangle().stroke(YoseColor.shu, lineWidth: 2.5) } }
                    // 待機組の震え（くじの最中だけ）
                    .rotationEffect(.degrees(lotRevealed ? 0 : (lotPulse ? 1.6 : -1.6)))
                }
            }
            mcBubble(FinalsMC.call(order: d.order, name: session.combiName))
                .padding(.top, 4).opacity(lotRevealed ? 1 : 0)
        }
        .task { await runLot() }
    }

    /// 出番くじ（§4-8）。心拍の振動（ドクン…ドクン）→出順が出る。初回は4拍・2回目以降は1拍。タップで畳める。
    private func runLot() async {
        guard !lotRevealed else { return }
        let full = FinalsSeen.first("lot") && !reduceMotion
        for _ in 0..<(full ? 4 : 1) {
            guard !Task.isCancelled, !lotRevealed else { return }
            withAnimation(.easeOut(duration: 0.12)) { lotPulse = true }
            Haptics.confirm()                         // se_heartbeat_low（ドクン）
            try? await Task.sleep(nanoseconds: 170_000_000)
            withAnimation(.easeIn(duration: 0.12)) { lotPulse = false }
            Haptics.tick()                            // （ドクッ）
            try? await Task.sleep(nanoseconds: full ? 520_000_000 : 260_000_000)
        }
        guard !Task.isCancelled, !lotRevealed else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { lotRevealed = true }
        Haptics.rare()                                // se_taiko_grand_hit（出順確定）
    }

    // MARK: 先の組（出順が自組より前）— 1組ずつ出てボードに載る
    private var precedingBeat: some View {
        VStack(spacing: 10) {
            if shown == 0 {
                YTelop(text: "ファーストラウンド", size: 17)
            } else {
                nowCard(d.entries[shown - 1])
            }
            standingsList(n: shown, newest: shown > 0 ? d.entries[shown - 1] : nil)
        }
    }

    // MARK: ネタ（舞台の二人・歓声。1.8秒で採点へ）
    private var performBeat: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 20)
            if let neta = session.selectedNeta {
                YTelop(text: "「\(neta.name)」", size: 22)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            Spacer(minLength: 200)
        }
        .onAppear {
            Sound.play(.cheerMid)
            Task {
                try? await Task.sleep(nanoseconds: 800_000_000)
                Sound.play(.cheerBig)
            }
        }
    }

    /// 今出た1組の札（出順・名前・合計）。自組は朱枠の特別札
    private func nowCard(_ e: FinalsEntry) -> some View {
        HStack(spacing: 10) {
            VStack(spacing: 3) {
                YoseTag(text: "\(e.order)番目", style: .solidEnji)
                if let r = (standings(shown).firstIndex { $0.order == e.order }).map({ $0 + 1 }), r <= 3 {
                    YoseTag(text: "暫定\(r)位", style: .outlineShu)
                }
            }
            Text(displayName(e)).font(YoseFont.mincho(22)).foregroundStyle(YoseColor.sumi)
                .lineLimit(1).minimumScaleFactor(0.6)
            Spacer(minLength: 6)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(e.total)").font(YoseFont.number(36, weight: .black)).foregroundStyle(YoseColor.sumi)
                    .contentTransition(.numericText())
                Text("点").font(YoseFont.gothic(16, weight: .heavy)).foregroundStyle(YoseColor.sumi)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)

        .yoseHarigami(isFeatured: e.isSelf)
        .overlay(alignment: .leading) { Rectangle().fill(YoseColor.enji).frame(width: 6) }   // 「いま出た組」の左帯
        .id(e.order)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    /// その時点のボード（§4-5 暫定3席）。上段＝暫定席3つ（椅子取り・新しく座った組は金に光る）、
    /// 席を押し出された組は「席を離れる」帯で退場、下段＝4位以下（敗退・薄く）。順位・合計は standings(n) のまま。
    private func standingsList(n: Int, newest: FinalsEntry?) -> some View {
        let rows = standings(n)
        let seats = Array(rows.prefix(3))
        let rest = Array(rows.dropFirst(3))
        let prevTop = Set(standings(max(0, n - 1)).prefix(3).map(\.order))
        let nowTop = Set(seats.map(\.order))
        // 今の1組で席から押し出された組（席が埋まる前の n<=3 では無し）
        let ousted: FinalsEntry? = n >= 4 ? d.entries.prefix(n).first { prevTop.contains($0.order) && !nowTop.contains($0.order) } : nil
        return VStack(spacing: 5) {
            // 見出し帯：上の「今出た組」札と同じ名前が並んでも、これは席の表だと分かる
            Text("暫定順位（上位3組が最終決戦へ）").font(YoseFont.captionBold).foregroundStyle(YoseColor.kin)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).frame(height: 26)
                .background(YoseColor.kuroUrushi)
                .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1))
            // 暫定席3つ（空席は札のまま・座ると金枠が光る）
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { rank in
                    if rank < seats.count {
                        seatCard(rank: rank, e: seats[rank], fresh: newest?.order == seats[rank].order)
                            .id(seats[rank].order)
                            .transition(.scale(scale: 0.85).combined(with: .opacity))
                    } else {
                        VStack(spacing: 3) {
                            Text("暫定\(rank + 1)位").font(YoseFont.captionBold).foregroundStyle(YoseColor.haiSumi)
                            Text("空席").font(YoseFont.mincho(14)).foregroundStyle(YoseColor.haiSumi)
                        }
                        .frame(maxWidth: .infinity).frame(height: 84)
                        .background(ZStack { YoseColor.ki; YoseColor.kiDark.opacity(0.55) })
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("暫定\(rank + 1)位、空席")
                    }
                }
            }
            // 席を押し出された組（照明が消えて下段へ）。se_spotlight_shutoff（バチン）
            if let o = ousted {
                HStack(spacing: 8) {
                    Text("▼").font(YoseFont.gothic(12, weight: .black)).foregroundStyle(YoseColor.enji)
                    Text("\(displayName(o))").font(YoseFont.mincho(15)).foregroundStyle(YoseColor.sumi).lineLimit(1).minimumScaleFactor(0.6)
                    Text("暫定席を離れる").font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                    Spacer(minLength: 4)
                    YoseTag(text: "敗退", style: .outlineSumi)
                }
                .padding(.horizontal, 12).frame(height: 30)
                .background(YoseColor.ginNezu)
                .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                .id("ousted-\(o.order)-\(n)")
                .transition(.opacity.combined(with: .offset(y: -6)))
            }
            // 4位以下（敗退）
            ForEach(Array(rest.enumerated()), id: \.element.order) { i, e in
                HStack(spacing: 10) {
                    Text("\(i + 4)").font(YoseFont.number(15, weight: .black)).foregroundStyle(YoseColor.haiSumi)
                        .lineLimit(1).minimumScaleFactor(0.7).frame(width: 26)
                    Text(displayName(e)).font(YoseFont.mincho(e.isSelf ? 15 : 13))
                        .foregroundStyle(YoseColor.sumi).lineLimit(1).minimumScaleFactor(0.7)
                    if e.isSelf { YoseTag(text: "あなた", style: .outlineShu) }
                    Spacer(minLength: 4)
                    YoseTag(text: "敗退", style: .outlineSumi)
                    Text("\(e.total)").font(YoseFont.number(15, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                }
                .padding(.horizontal, 12).frame(height: 28)
                .background(YoseColor.ginNezu.opacity(0.75))
                .overlay(Rectangle().stroke(e.isSelf ? YoseColor.shu : YoseColor.haiSumi, lineWidth: e.isSelf ? 2 : 1))
            }
        }
        .padding(.bottom, 2)
    }

    /// 暫定席1つ（縦長の札・順位／名前／合計）。自組は朱枠・いま座った組は金の発光
    private func seatCard(rank: Int, e: FinalsEntry, fresh: Bool) -> some View {
        VStack(spacing: 3) {
            YoseTag(text: "暫定\(rank + 1)位", style: rank == 0 ? .solidEnji : .outlineShu)
            Text(displayName(e)).font(YoseFont.mincho(e.isSelf ? 15 : 14)).foregroundStyle(YoseColor.sumi)
                .lineLimit(2).minimumScaleFactor(0.55).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity).frame(minHeight: 34)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(e.total)").font(YoseFont.number(22, weight: .black)).foregroundStyle(e.isSelf ? YoseColor.shu : YoseColor.sumi)
                Text("点").font(YoseFont.gothic(10, weight: .heavy)).foregroundStyle(YoseColor.sumi)
            }
            if e.isSelf { Text("あなた").font(YoseFont.gothic(9, weight: .black)).foregroundStyle(YoseColor.kinari)
                .frame(maxWidth: .infinity).background(YoseColor.shu) }
        }
        .padding(.vertical, 5).padding(.horizontal, 3)
        .frame(maxWidth: .infinity).frame(height: 98, alignment: .top)   // 名前2行＋「あなた」帯でも合計が切れない
        .yoseHarigami(isFeatured: true)
        .overlay { if e.isSelf { Rectangle().stroke(YoseColor.shu, lineWidth: 2.5) } }
        .overlay { if fresh { Rectangle().stroke(YoseColor.kinBright, lineWidth: 2.5) } }
        .shadow(color: fresh ? YoseColor.kinBright.opacity(0.9) : .clear, radius: 10)   // se_rank_slide_heavy（席が入れ替わる）
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("暫定\(rank + 1)位、\(displayName(e))、\(e.total)点" + (e.isSelf ? "、あなたたち" : "") + (fresh ? "、いま席に入った" : ""))
    }

    // MARK: 司会の吹き出し（決勝の進行役）
    private func mcBubble(_ text: String, cue: Bool = true) -> some View {
        YoseSpeechBox(speaker: family(FinalsMC.name), text: text, roleLabel: "司会", showCue: cue)
            .transition(.opacity)
    }
    /// 名前札には姓だけ（「鳴海 ジョー」→「鳴海」）
    private func family(_ full: String) -> String { String(full.split(separator: " ").first ?? Substring(full)) }

    // MARK: 講評（採点の直後・司会が最高点と最低点の審査員に振る）
    /// 講評する審査員（最高点の人→最低点の人。同点は席順の早い方）
    private var commentPicks: [JudgeScore] {
        let ordered = d.judges.enumerated().sorted {
            $0.element.score != $1.element.score ? $0.element.score > $1.element.score : $0.offset < $1.offset
        }.map(\.element)
        guard let hi = ordered.first, let lo = ordered.last else { return [] }
        return hi.name == lo.name ? [hi] : [hi, lo]
    }

    private var debugForcedComment: String? {
        #if DEBUG
        return ProcessInfo.processInfo.environment["MZ_PICKUP"]
        #else
        return nil
        #endif
    }

    /// 講評に差し込む本番の材料（1本目のネタ・出順・ハマった夜・敗者復活経由・コンビの状態）。表示専用。
    private var judgeScene: JudgeTalk.Scene {
        let burst = session.pendingResult?.results.last(where: { $0.name == "GP決勝" })?.burst ?? false
        return JudgeTalk.Scene.from(state: s, neta: session.selectedNeta, config: session.config, year: session.year,
                                    burst: burst, order: d.order, viaRevival: session.reachedFinalViaRevival)
    }

    private func judgeBox(_ j: JudgeScore, text: String, cue: Bool = true) -> some View {
        YoseSpeechBox(speaker: family(j.name), text: text, roleLabel: "審査員", showCue: cue)
            .overlay(alignment: .topTrailing) { YoseHankoStamp(text: "\(j.score)", isSquare: true, angle: 6).scaleEffect(0.72).offset(x: 6, y: -34) }   // 点数札は吹き出しの上へ出す（本文の右上に被らない）
            .padding(.top, 24)
    }

    private var commentsBeat: some View {
        let picks = commentPicks
        let i = min(commentStep, max(0, picks.count - 1))
        let selfRank = (standings(d.order).firstIndex { $0.isSelf } ?? 0) + 1
        return VStack(spacing: 12) {
            // 合計の木札ボード（コンビ名＋暫定順位＋合計）
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.combiName).font(YoseFont.mincho(20)).foregroundStyle(YoseColor.sumi)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    YoseTag(text: "暫定\(selfRank)位", style: .solidEnji)
                }
                Spacer(minLength: 6)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(d.total)").font(YoseFont.number(38, weight: .black)).foregroundStyle(YoseColor.shu)
                    Text("点").font(YoseFont.gothic(16, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .yoseHarigami(isFeatured: true)
            .padding(.bottom, 2)
            if picks.indices.contains(i) {
                let j = picks[i]
                // 目視用（DEBUG）: MZ_PICKUP=ボケ行 で講評を差し替え、司会の拾いの1拍を必ず出す
                let salt = j.score &+ session.year &* 7 &+ d.order &+ i
                let c = FinalsJudgeTalk.comment(judge: j.name, score: j.score, high: i == 0, scene: judgeScene, salt: salt)
                let text = debugForcedComment ?? c.text
                Spacer(minLength: 0)
                mcBubble(FinalsMC.askJudge(j.name, score: j.score, high: i == 0), cue: false)
                judgeBox(j, text: text)
                    .id(j.name)
                    .transition(.opacity.combined(with: .offset(y: 8)))
                // 審査員のボケ行なら、司会が拾う1拍（r6 §5-4・P3）
                if let p = debugForcedComment.map({ FinalsMC.pickup(after: $0, scene: judgeScene, salt: salt) }) ?? c.pickup {
                    mcBubble(p.mc, cue: false)
                    if let reply = p.reply {
                        judgeBox(j, text: reply)
                    }
                }
            }
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
        return VStack(spacing: 12) {
            // 誰の採点かを明示する黒漆バー
            HStack(spacing: 8) {
                Text("\(d.order)番手").font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.kin)
                Text(session.combiName).font(YoseFont.mincho(17)).foregroundStyle(YoseColor.kinari)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Spacer(minLength: 4)
                Text(allShown ? "開票 完了" : "\(revealedJudges) / 7 人 開票")
                    .font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.kinBright)
            }
            .padding(.horizontal, 14).frame(height: 38)
            .background(YoseColor.kuroUrushi)
            .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1.5))
            .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))
            let cw = (UIScreen.main.bounds.width - YoseMetrics.screenMargin * 2 - 24) / 4
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { i in
                        judgeCard(d.judges[i], shown: i < revealedJudges, kata: kata).frame(width: cw)
                    }
                }
                HStack(spacing: 8) {   // 2段目の3枚は中央に（下の合計箱と軸を揃える）
                    ForEach(4..<min(7, d.judges.count), id: \.self) { i in
                        judgeCard(d.judges[i], shown: i < revealedJudges, kata: kata).frame(width: cw)
                    }
                }
            }
            // 合計の電光計器箱（黒漆＋二重金枠）。7人目が開くまで伏せる
            VStack(spacing: 0) {
                Text("合計").font(YoseFont.gothic(11, weight: .heavy)).foregroundStyle(YoseColor.kin)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Group {
                        if allShown { RollingNumberText(value: totalCount, prefix: "", suffix: "") }   // 0→合計へ電光カウントアップ
                        else { Text("？？？") }
                    }
                    .font(YoseFont.number(40, weight: .black))
                    .foregroundStyle(allShown ? YoseColor.kinBright : YoseColor.haiSumi)
                    .punch(on: allShown, peak: 1.2)   // 7人目が開いた瞬間に初めて合計がドンと出る
                    Text(allShown ? "/ 700" : "点").font(allShown ? YoseFont.number(14, weight: .bold) : YoseFont.gothic(16, weight: .heavy)).foregroundStyle(YoseColor.ginNezu)
                }
            }
            .frame(width: 240, height: 76)
            .background(YoseColor.kuroUrushi)
            .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 2))
            .overlay(Rectangle().stroke(YoseColor.kin.opacity(0.7), lineWidth: 0.8).padding(4))
            .background(Rectangle().fill(YoseColor.sumi).offset(y: 3))
            .overlay(alignment: .topTrailing) {
                if allShown && !spectator {   // 合計の右上に暫定順位の朱印が叩きつけられる（se_total_score_explosion）
                    let r = (standings(d.order).firstIndex { $0.isSelf } ?? 0) + 1
                    YoseHankoStamp(text: "暫定\(r)位", isSquare: true, angle: -6).scaleEffect(0.62)
                        .offset(x: 30, y: -30)
                        .transition(.scale(scale: 2.0).combined(with: .opacity))
                }
            }
            if revealedJudges == 0 {
                mcBubble(FinalsMC.startScoring)
            } else if let kata, allShown {
                YoseNarration(text: "\(NetaCatalog.displayName(kata))で挑んだ一本。")
            }
        }
        .onChange(of: allShown) { _, now in
            guard now else { return }
            totalCount = 0
            withAnimation(.easeOut(duration: reduceMotion ? 0.2 : 1.1)) { totalCount = Double(total) }
        }
    }

    private func judgeCard(_ j: JudgeScore, shown: Bool, kata: NetaKata?) -> some View {
        // 木札の表と裏を別の面で描く＝回転の途中で面を切り替えるので鏡文字にならない（A2 §3-B1・L10 FlipCard）。
        let h: CGFloat = kata != nil ? 112 : 96
        return FlipCard(shown: shown) {
            judgeFace(j, kata: kata, height: h)
        } back: {
            judgeBack(j, height: h)
        }
        .scaleEffect(shown ? 1 : 0.96)
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: shown)
    }

    /// 審査員の名札（姓＋名の2行）
    private func judgeNamePlate(_ name: String, dim: Bool = false) -> some View {
        let parts = name.split(separator: " ").map(String.init)
        return VStack(spacing: 0) {
            Text(parts.first ?? name).font(YoseFont.mincho(14)).lineLimit(1).minimumScaleFactor(0.6)
            Text(parts.count > 1 ? parts[1] : " ").font(YoseFont.mincho(10)).lineLimit(1).minimumScaleFactor(0.6)
        }
        .foregroundStyle(dim ? YoseColor.ginNezu : YoseColor.kinari)
        .frame(maxWidth: .infinity).frame(height: 34)
        .background(dim ? YoseColor.kuroUrushi.opacity(0.85) : YoseColor.kuroUrushi)
    }

    private func judgeFace(_ j: JudgeScore, kata: NetaKata?, height: CGFloat) -> some View {
        VStack(spacing: 4) {
            Text("\(j.score)").font(YoseFont.number(30, weight: .black))
                .foregroundStyle(j.score >= 95 ? YoseColor.shu : YoseColor.sumi)
                .frame(height: 34)
            judgeNamePlate(j.name)
            if let kata {
                Text(NetaCatalog.affinity(kata, judge: j.name)).font(YoseFont.gothic(11, weight: .heavy)).foregroundStyle(YoseColor.kinText)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
        }
        .padding(.top, 6).padding(.bottom, 6).padding(.horizontal, 3)
        .frame(maxWidth: .infinity).frame(height: height, alignment: .top)
        .yoseHarigami(isFeatured: j.score >= 95)
        .overlay { if j.score >= 95 { Rectangle().fill(YoseColor.kin.opacity(0.16)).allowsHitTesting(false) } }   // 高得点札は金地
        .overlay { if j.score >= 95 { Rectangle().stroke(YoseColor.kinBright, lineWidth: 2.5).allowsHitTesting(false) } }   // 95点以上＝金枠発光
        .shadow(color: j.score >= 95 ? YoseColor.kinBright.opacity(0.85) : .clear, radius: 9)
    }

    private func judgeBack(_ j: JudgeScore, height: CGFloat) -> some View {
        VStack(spacing: 4) {
            Text("？").font(YoseFont.gothic(28, weight: .black)).foregroundStyle(YoseColor.haiSumi).frame(height: 34)
            judgeNamePlate(j.name, dim: true)
        }
        .padding(.top, 6).padding(.horizontal, 3)
        .frame(maxWidth: .infinity).frame(height: height, alignment: .top)
        .yoseKifuda()
    }

    // MARK: ボード — 自組が入る → 後の組が1組ずつ出て暫定席が入れ替わる → 1本目の確定
    private var boardBeat: some View {
        let selfRank = (standings(shown).firstIndex { $0.isSelf } ?? 0) + 1
        let done = shown >= d.entries.count
        return VStack(spacing: 10) {
            if !spectator && !boardAuto {
                // 自組がボードに入った瞬間（タップを待つ）
                YoseHankoStamp(text: "暫定\(selfRank)位", isSquare: true, angle: -5)
                    .scaleEffect(1.5).padding(.vertical, 10)
                mcBubble(selfRank <= 3 ? FinalsMC.seated(name: session.combiName, rank: selfRank)
                                       : FinalsMC.eliminated(name: session.combiName, rank: selfRank))
            } else if done {
                mcBubble(FinalsMC.firstRoundEnd)
            } else if shown == 0 {
                YTelop(text: "ファーストラウンド", size: 17)
            } else {
                nowCard(d.entries[shown - 1])
            }
            standingsList(n: shown, newest: shown > 0 && !done ? d.entries[shown - 1] : nil)
        }
    }

    // MARK: Beat 3 — 最終決戦（M-1式＝3組・審査員7人が縦長の票札で組名を掲げる）
    private var finalDuelBeat: some View {
        let names = duelNames
        let counts = (0..<3).map { k in d.voteOrder.prefix(revealVotes).filter { $0 == k }.count }
        return VStack(spacing: 14) {
            if revealVotes == 0 { mcBubble(FinalsMC.startVoting) }

            Text("最終決戦  ——  4票先取で優勝").font(YoseFont.gothic(13, weight: .black)).tracking(1).foregroundStyle(YoseColor.kinari)
                .frame(maxWidth: .infinity).frame(height: 28)
                .background(YoseColor.enji)
                .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1.5))
            // 3組の得票番付（自組・最多得票は朱枠の特別札・下に過半数4マス）
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { k in
                    trioCounter(rank: k + 1, name: names.count > k ? names[k] : "—", count: counts[k],
                                mine: k == d.selfDuelIndex, lead: counts[k] > 0 && counts[k] == counts.max(),
                                check: counts[k] == 3 && revealVotes < 7)
                }
            }

            // 審査員7人: 縦長の木札。上が投票先（縦書き）・下が審査員の姓
            HStack(spacing: 5) {
                ForEach(0..<7, id: \.self) { i in
                    let shown = i < revealVotes
                    let vote = d.voteOrder[i]
                    VStack(spacing: 0) {
                        votePlate(shown: shown, voteName: names.count > vote ? names[vote] : "—", forUs: vote == d.selfDuelIndex)
                        // 姓をそのまま出す（2文字で切ると天堂寺→「天堂」・神楽坂→「神楽」と別の語に読めた）
                        Text(String(d.judges[i].name.split(separator: " ").first ?? Substring(d.judges[i].name)))
                            .font(YoseFont.gothic(11, weight: .heavy)).foregroundStyle(YoseColor.kin)
                            .lineLimit(1).minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity).frame(height: 26)
                            .background(YoseColor.kuroUrushi)
                            .overlay(alignment: .top) { Rectangle().fill(YoseColor.kin).frame(height: 1.5) }
                    }
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))
                }
            }
            if revealVotes < 7 {
                Button { advance() } label: { Text("次の審査員札をめくる（\(revealVotes)/7）▶") }
                    .buttonStyle(YoseButtonStyle(.primary))
            } else {
                YTelop(text: "——開票、出揃った。", size: 16, color: YoseColor.kinBright)
            }
        }
    }

    private func trioCounter(rank: Int, name: String, count: Int, mine: Bool, lead: Bool, check: Bool = false) -> some View {
        VStack(spacing: 4) {
            YoseTag(text: "1本目\(rank)位", style: mine ? .solidEnji : .outlineSumi)
            Text(name).font(YoseFont.mincho(15)).foregroundStyle(YoseColor.sumi)
                .lineLimit(2).minimumScaleFactor(0.6).multilineTextAlignment(.center)
                .frame(height: 38)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(count)").font(YoseFont.number(40, weight: .black))
                    .foregroundStyle(count > 0 ? YoseColor.shu : YoseColor.haiSumi)
                    .contentTransition(.numericText())
                    .punch(on: count, peak: 1.3)
                Text("票").font(YoseFont.gothic(13, weight: .heavy)).foregroundStyle(YoseColor.sumi)
            }
            HStack(spacing: 3) {   // 過半数（7人中4票）までの4マス
                ForEach(0..<4, id: \.self) { n in
                    Rectangle().fill(n < count ? YoseColor.shu : YoseColor.ginNezu).frame(height: 6)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1))
                }
            }
            .padding(.horizontal, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .yoseHarigami(isFeatured: mine || lead)
        .overlay(alignment: .top) {   // 王手（あと1票で4票）
            if check {
                Text("王手").font(YoseFont.gothic(12, weight: .black)).foregroundStyle(YoseColor.kinari)
                    .padding(.horizontal, 10).frame(height: 20).background(YoseColor.shu)
                    .overlay(Rectangle().stroke(YoseColor.kinBright, lineWidth: 1.5))
                    .offset(y: -11).transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: check)
        .padding(.bottom, 2)
    }

    /// 票札1枚: 投票先の組名を縦書きで掲げる。自組＝朱地。表と裏を別の面で描く（鏡文字にならない）。
    private func votePlate(shown: Bool, voteName: String, forUs: Bool) -> some View {
        FlipCard(shown: shown) {
            VStack(spacing: 0) {
                ForEach(Array(voteName.enumerated()), id: \.offset) { _, c in
                    Text(String(c)).font(YoseFont.mincho(13)).lineLimit(1)
                }
            }
            .minimumScaleFactor(0.5)
            .foregroundStyle(forUs ? YoseColor.kinari : YoseColor.sumi)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity).frame(height: 150, alignment: .top)
            .background(forUs ? YoseColor.shu : YoseColor.washi)
        } back: {
            YoseHankoStamp(text: "封", isSquare: true, angle: 0).scaleEffect(0.8)
                .frame(maxWidth: .infinity).frame(height: 150)
                .background(YoseColor.ki)
                .overlay(Rectangle().stroke(YoseColor.kiDark, lineWidth: 1.5).padding(3))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: shown)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(shown ? "票札、\(voteName)に一票" + (forUs ? "（あなたたち）" : "") : "封をした票札、まだ開いていない")
    }

    // MARK: Beat 4 — 優勝発表（3組から名前をコール）
    // 二人は舞台の上に立つ（StageFrame の performers）。名前はめくり札、判は金の丸判、耳打ちは谷口の吹き出し。
    private var resultBeat: some View {
        let names = duelNames
        let winnerName = names.count > d.winnerIndex ? names[d.winnerIndex] : session.combiName
        return VStack(spacing: 12) {
            mcBubble(FinalsMC.announceWinner, cue: !d.champion)
            // 優勝額縁（黒漆＋金＋朱の枠・左に特大の朱印）。他組の優勝は銀鼠の地
            HStack(spacing: 14) {
                YoseHankoStamp(text: "優勝", isSquare: true, angle: -4).scaleEffect(1.35)
                    .padding(.leading, 10).padding(.trailing, 6)
                VStack(alignment: .leading, spacing: 4) {
                    Text("頂グランプリ 今年の優勝").font(YoseFont.gothic(12, weight: .heavy))
                        .foregroundStyle(d.champion ? YoseColor.kin : YoseColor.sumi)
                    if d.champion {
                        YoseOutlinedText(text: winnerName, font: YoseFont.mincho(28), fill: YoseColor.kinBright,
                                         outlineColor: YoseColor.kuroUrushi, outlineWidth: 2, dropShadowY: 2)
                            .lineLimit(1).minimumScaleFactor(0.5)
                    } else {
                        Text(winnerName).font(YoseFont.mincho(26)).foregroundStyle(YoseColor.sumi)
                            .lineLimit(1).minimumScaleFactor(0.5)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 16).padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(d.champion ? YoseColor.kuroUrushi : YoseColor.ginNezu)
            .overlay(Rectangle().stroke(d.champion ? YoseColor.kin : YoseColor.sumi, lineWidth: 3))
            .overlay(Rectangle().stroke(d.champion ? YoseColor.kin : YoseColor.haiSumi, lineWidth: 1).padding(6))
            .overlay(Rectangle().stroke(d.champion ? YoseColor.shu : YoseColor.haiSumi, lineWidth: 1.5).padding(10))
            .background(alignment: .bottom) { Rectangle().fill(YoseColor.sumi).offset(y: 4) }
            .padding(.bottom, 4)
            .scaleEffect(celebrate || !d.champion ? 1 : 1.25)
            Spacer(minLength: 0)
            // 余韻（文言は既存のまま・地の文と台詞を分けただけ）
            if d.champion {
                VStack(alignment: .leading, spacing: 0) {   // ト書きは吹き出しの上辺に結合して1つの塊に
                    Text(Names.show("谷口が、そっと耳打ちした。")).font(YoseFont.mincho(13)).foregroundStyle(YoseColor.kinari)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(YoseColor.kuroUrushi)
                        .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1))
                    YoseSpeechBox(speaker: "谷口", text: "……ほんまに、勝ったんやな", roleLabel: "相方")
                }
            } else if spectator {
                // 固定の一文：このキャリアで二度目以降は出さない（毎年同じ最後の一行にならない）
                if session.firstShow("final.spectatorLast", key: session.year) { YoseNarration(text: "客席の照明が上がる前に、二人で席を立った。") }
            } else {
                if session.firstShow("final.lostLast", key: session.year) { YoseNarration(text: "届かなかった。だが、この夜の舞台には立った。") }
            }
            Button {
                endingFull = FinalsSeen.first("ending") && !reduceMotion   // 番組のエンディング→出口
                showEnding = true
            } label: {
                Text(spectator ? "次の週へ ▶" : "結果を見る ▶")
            }
            .buttonStyle(YoseButtonStyle(.primary))
            .padding(.bottom, 14)
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
    init(state s: GameState, champion: Bool, spectator: Bool = false, margin: Double? = nil, year: Int = 1, selfName: String = "") {
        self.champion = champion
        // UI専用RNG（能力と年から決定的にseed＝再現可・GameCoreの乱数列に非干渉）
        var rng = SeededRng(seed: UInt64(bitPattern: Int64(
            Int(s.発想) &* 131 &+ Int(s.センス) &* 197 &+ Int(s.表現) &* 251 &+
            Int(s.華) &* 313 &+ Int(s.メンタル) &* 389 &+ Int(s.compat) &* 457 &+ year &* 7919 &+ 0x1F17)))

        // 今年の顔ぶれ（名簿から決定的に選ぶ。常連は毎年いるとは限らない）
        var pool = FinalsData.npcNames.filter { $0 != selfName }   // 自組と同じ名前のモブを並べない（プレイヤーが同名を付けた時）
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
        // 勝者は必ず過半数。全員一致（7票）は現実にほぼ無い（オーナー指摘 2026-10-10）＝決勝で圧倒した時だけ
        let m = margin ?? 0
        let w: Int
        if champion, selfIdx == winner {
            w = m >= 20 ? rng.int(6...7) : (m >= 10 ? rng.int(5...6) : rng.int(4...5))
        } else {
            w = rng.int(4...6)
        }
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
    /// 設計上の固有名（ライバル役の「静物画」「夜行列車」・後輩NPCの「雨宿り」）とは重ねない（2026-10-14 差し替え）
    static let npcNames = ["紺屋", "夜明けの犬", "サーカス", "青写真", "十三", "深夜のグラタン", "テレフォン", "北緯", "帰り道",
                           "灯台守", "三番線", "東口", "ペンギン座", "トランジスタ", "まどろみ", "夕凪", "赤鉛筆", "合鍵",
                           "日めくり", "回送電車", "白湯", "角部屋", "手旗信号", "満月書店", "栞", "小春日和", "遠回り", "置き手紙",
                           "二重丸", "冬支度", "屋上庭園", "古時計", "紙飛行機", "宵の口", "渡り廊下", "給水塔", "綿雲", "画鋲",
                           "天気雨", "終着駅", "星見台", "曇天予報", "迷い猫", "番台", "薄荷", "定食屋", "乾電池", "空き瓶",
                           "通り雨", "裏木戸"]
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
    @State private var startDate = Date()
    @State private var frozen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        // 余韻（6.5秒）の後は回転を止めて最後の絵のまま静止（CPU 節約）
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: frozen || reduceMotion)) { tl in
            let t = reduceMotion ? 0 : min(tl.date.timeIntervalSince(startDate), 6.5)
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
                    ctx.fill(p, with: .color(YoseColor.kinBright.opacity(i.isMultiple(of: 2) ? 0.10 : 0.05)))
                }
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 6_600_000_000)
            frozen = true
        }
    }
}

/// 決勝の紙吹雪（決定的な位置）
private struct ConfettiView: View {
    private let pieces = 30
    private let palette: [Color] = [YoseColor.kinBright, YoseColor.shu, YoseColor.washi]
    @State private var startDate = Date()
    @State private var frozen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        // 余韻（6.5秒）の後は新しい粒を出さず、落ちきったら描画を止める（CPU 節約）
        TimelineView(.animation(paused: frozen || reduceMotion)) { timeline in
            let t = min(timeline.date.timeIntervalSince(startDate), 6.5 + 10)
            Canvas { ctx, size in
                guard !reduceMotion else { return }
                for i in 0..<pieces {
                    let seed = Double(i)
                    let x = (sin(seed * 12.9898) * 0.5 + 0.5) * size.width
                    let speed = 42 + (i % 5) * 14
                    let totalH = Double(size.height + 40)
                    if floor((Double(speed) * t + seed * 47) / totalH) > floor((Double(speed) * 6.5 + seed * 47) / totalH) { continue }
                    let y = (Double(speed) * t + seed * 47).truncatingRemainder(dividingBy: totalH) - 20
                    let rot = t * 2 + seed
                    let c = palette[i % palette.count]
                    var rect = Path(CGRect(x: -4, y: -6, width: 8, height: 12))
                    rect = rect.applying(CGAffineTransform(rotationAngle: rot)).applying(CGAffineTransform(translationX: x, y: y))
                    ctx.fill(rect, with: .color(c.opacity(0.9)))
                }
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 16_600_000_000)
            frozen = true
        }
    }
}
