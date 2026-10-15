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
    case preceding = 0 // 自組より前の出順の組が1組ずつ出る（自動で送る・タップで次の組）
    case lot = 1       // 自組の籤（出順）
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
            if beat == .perform {   // ネタ中：舞台袖のめくり（コンビ名）
                VStack { Spacer(); HStack { Spacer(); StageMakuri(name: spectator ? "客席" : session.combiName).padding(.trailing, 20) }.padding(.bottom, 190) }
                    .allowsHitTesting(false)
            }
            if celebrate && d.champion {
                // 金の放射光と紙吹雪は自組の優勝の夜だけ（他組の優勝・決勝敗退には降らない・A2 §3-B2）
                RaysView().ignoresSafeArea().allowsHitTesting(false)
                ConfettiView().ignoresSafeArea().allowsHitTesting(false)
            }

            VStack(spacing: 10) {
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

                if beat < .result, !(beat == .duel && revealVotes < 7) {
                    // 送りの合図は▼1種（K4）。採点だけ「1人ずつ」と添える
                    VStack(spacing: 4) {
                        if beat == .open && revealedJudges < 7 {
                            YTelop(text: "タップで1人ずつ発表", size: 13)
                        }
                        if (beat == .preceding && shown < d.order - 1) || (beat == .board && shown < d.entries.count) {
                            YTelop(text: "タップで次の組へ", size: 13)
                        }
                        YoseAdvanceCue()
                    }
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
                StageCeremony { ceremonyDone = true }
                    .transition(.opacity)
            }
        }
        .onAppear {
            if dataCache == nil { dataCache = makeData() }
            Sound.bgm(.finals)   // 番組のBGM（決勝の格）
            if spectator {
                beat = .board; shown = 0; boardAuto = true   // 観客は10組を出順どおりに観てから最終決戦
            } else {
                beat = d.order == 1 ? .lot : .preceding        // トップバッターは先の組が無い
            }
            #if DEBUG
            // 目視用: MZ_FIN=pre/open/board/duel/win で各ビートへ直行（タップ注入できないCLI検証のため）
            switch ProcessInfo.processInfo.environment["MZ_FIN"] {
            case "lot": beat = .lot
            case "pre": beat = .preceding; shown = max(0, d.order - 1)
            case "open": beat = .open; revealedJudges = 5
            case "comments": beat = .comments; revealedJudges = 7
            case "board": beat = .board; shown = 10; boardAuto = true
            case "duel": beat = .duel; revealVotes = 5
            case "win": beat = .result
            default: break
            }
            #endif
        }
        // 先の組・後の組の自動送り（1.25秒ごとに1組）とネタの間（1.8秒で採点へ）。タップはいつでも次へ
        .task(id: autoKey) {
            guard ceremonyDone else { return }
            if beat == .perform {
                try? await Task.sleep(nanoseconds: 1_800_000_000)
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
        StageSign(title: "頂 グランプリ", subtitle: spectator ? "客席から観戦中" : nil, tag: "決勝", outlined: true)
            .padding(.horizontal, -4)
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
            goNext()
        }
    }

    /// 次のビートへ。ボードに入る瞬間は自組の行を載せ、暫定席に入れたかを音で返す
    private func goNext() {
        let nextBeat = beat.next
        Sound.play(.transition)
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
        Haptics.confirm()
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
                    Text("\(d.order)").font(YoseFont.number(48, weight: .black)).foregroundStyle(YoseColor.shu)
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
            Spacer(minLength: 130)
            // 全10組の出順番付（自組だけ朱枠の特別札）
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                ForEach(slots, id: \.order) { e in
                    VStack(spacing: 1) {
                        Text("\(e.order)").font(YoseFont.number(15, weight: .black))
                            .foregroundStyle(e.isSelf ? YoseColor.shu : YoseColor.enji)
                        Text(displayName(e)).font(YoseFont.mincho(11)).foregroundStyle(YoseColor.sumi)
                            .lineLimit(1).minimumScaleFactor(0.5)
                    }
                    .frame(maxWidth: .infinity).frame(height: 40)
                    .yoseHarigami(isFeatured: e.isSelf)
                }
            }
            mcBubble(FinalsMC.call(order: d.order, name: session.combiName))
                .padding(.top, 4)
        }
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
            YoseTag(text: "\(e.order)番目", style: .solidEnji)
            Text(displayName(e)).font(YoseFont.mincho(22)).foregroundStyle(YoseColor.sumi)
                .lineLimit(1).minimumScaleFactor(0.6)
            Spacer(minLength: 6)
            Text("\(e.total)").font(YoseFont.number(32, weight: .black)).foregroundStyle(YoseColor.sumi)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .yoseHarigami(isFeatured: e.isSelf)
        .id(e.order)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    /// その時点のボード。上位3組＝暫定席（朱枠の特別札）、4位以下＝敗退（薄く）。押し出された組は席を立つ（薄くなる）
    private func standingsList(n: Int, newest: FinalsEntry?) -> some View {
        let rows = standings(n)
        return VStack(spacing: 5) {
            // 見出し帯：上の「今出た組」札と同じ名前が並んでも、これは席の表だと分かる
            Text("暫定順位（上位3組が最終決戦へ）").font(YoseFont.captionBold).foregroundStyle(YoseColor.kin)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).frame(height: 26)
                .background(YoseColor.kuroUrushi)
                .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1))
            ForEach(Array(rows.enumerated()), id: \.element.order) { rank, e in
                let seated = rank < 3
                if rank == 3 {
                    Text("▲ ここまで最終決戦進出（上位3組） ▲").font(YoseFont.captionBold).foregroundStyle(YoseColor.kinari)
                        .frame(maxWidth: .infinity).frame(height: 20)
                        .background(YoseColor.shu)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                }
                HStack(spacing: 10) {
                    Text("\(rank + 1)").font(YoseFont.number(18, weight: .black))
                        .foregroundStyle(seated ? YoseColor.shu : YoseColor.haiSumi).lineLimit(1).minimumScaleFactor(0.7).frame(width: 28)
                    Text(displayName(e)).font(YoseFont.mincho(e.isSelf ? 17 : 15))
                        .foregroundStyle(YoseColor.sumi).lineLimit(1).minimumScaleFactor(0.7)
                    if e.isSelf { YoseTag(text: "あなた", style: .outlineShu) }
                    Spacer(minLength: 4)
                    if !seated { YoseTag(text: "敗退", style: .outlineSumi) }
                    Text("\(e.total)").font(YoseFont.number(17, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                }
                .padding(.horizontal, 12).padding(.vertical, 4)
                .yoseHarigami(isFeatured: seated)
                .overlay { if !seated && !e.isSelf { Rectangle().fill(YoseColor.ginNezu.opacity(0.6)).allowsHitTesting(false) } }
            }
            // まだ埋まっていない席は空の札で見せる（3つの椅子を争うと一目で分かる）
            ForEach(rows.count..<max(rows.count, 3), id: \.self) { rank in
                HStack(spacing: 10) {
                    Text("\(rank + 1)").font(YoseFont.number(18, weight: .black))
                        .foregroundStyle(YoseColor.haiSumi).frame(width: 28)
                    Text("ーーー").font(YoseFont.mincho(15)).foregroundStyle(YoseColor.haiSumi)
                    Spacer(minLength: 4)
                    Text("空席").font(YoseFont.captionBold).foregroundStyle(YoseColor.haiSumi)
                }
                .padding(.horizontal, 12).padding(.vertical, 4)
                .frame(height: 34)
                .background(YoseColor.ki)
                .overlay(Rectangle().stroke(YoseColor.haiSumi, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
            }
        }
        .padding(.bottom, 2)
    }

    // MARK: 司会の吹き出し（決勝の進行役）
    private func mcBubble(_ text: String) -> some View {
        YoseSpeechBox(speaker: family(FinalsMC.name), text: text, roleLabel: "司会")
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

    private func judgeBox(_ j: JudgeScore, text: String) -> some View {
        YoseSpeechBox(speaker: family(j.name), text: text, roleLabel: "審査員・\(j.score)点")
            .overlay(alignment: .topTrailing) { YoseHankoStamp(text: "\(j.score)", isSquare: true, angle: 6).scaleEffect(0.8).offset(x: 4, y: -22) }
            .padding(.top, 14)
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
                mcBubble(FinalsMC.askJudge(j.name, score: j.score, high: i == 0))
                judgeBox(j, text: text)
                    .id(j.name)
                    .transition(.opacity.combined(with: .offset(y: 8)))
                // 審査員のボケ行なら、司会が拾う1拍（r6 §5-4・P3）
                if let p = debugForcedComment.map({ FinalsMC.pickup(after: $0, scene: judgeScene, salt: salt) }) ?? c.pickup {
                    mcBubble(p.mc)
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
            let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(Array(d.judges.enumerated()), id: \.offset) { i, j in
                    judgeCard(j, shown: i < revealedJudges, kata: kata)
                }
            }
            // 合計の電光計器箱（黒漆＋二重金枠）。7人目が開くまで伏せる
            VStack(spacing: 0) {
                Text("合計").font(YoseFont.gothic(11, weight: .heavy)).foregroundStyle(YoseColor.kin)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(allShown ? "\(total)" : "？？？").font(YoseFont.number(40, weight: .black))
                        .foregroundStyle(allShown ? YoseColor.kinBright : YoseColor.haiSumi)
                        .contentTransition(.numericText())
                        .punch(on: allShown, peak: 1.2)   // 7人目が開いた瞬間に初めて合計がドンと出る
                    Text(allShown ? "/ 700" : "……").font(YoseFont.number(14, weight: .bold)).foregroundStyle(YoseColor.ginNezu)
                }
            }
            .frame(width: 240, height: 76)
            .background(YoseColor.kuroUrushi)
            .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 2))
            .overlay(Rectangle().stroke(YoseColor.kin.opacity(0.7), lineWidth: 0.8).padding(4))
            .background(Rectangle().fill(YoseColor.sumi).offset(y: 3))
            if revealedJudges == 0 {
                mcBubble(FinalsMC.startScoring)
            } else if let kata, allShown {
                YoseNarration(text: "\(NetaCatalog.displayName(kata))で挑んだ一本。")
            }
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
        .background(dim ? YoseColor.haiSumi : YoseColor.kuroUrushi)
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
    }

    private func judgeBack(_ j: JudgeScore, height: CGFloat) -> some View {
        VStack(spacing: 4) {
            Text("？").font(YoseFont.gothic(26, weight: .heavy)).foregroundStyle(YoseColor.haiSumi).frame(height: 34)
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

            // 3組の得票番付（自組・最多得票は朱枠の特別札・下に過半数4マス）
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { k in
                    trioCounter(rank: k + 1, name: names.count > k ? names[k] : "—", count: counts[k],
                                mine: k == d.selfDuelIndex, lead: counts[k] > 0 && counts[k] == counts.max())
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
                    .frame(width: 300)
            } else {
                YTelop(text: "——開票、出揃った。", size: 16, color: YoseColor.kinBright)
            }
        }
    }

    private func trioCounter(rank: Int, name: String, count: Int, mine: Bool, lead: Bool) -> some View {
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
            .frame(maxWidth: .infinity).frame(height: 116, alignment: .top)
            .background(forUs ? YoseColor.shu : YoseColor.washi)
        } back: {
            Text("？").font(YoseFont.gothic(20, weight: .heavy)).foregroundStyle(YoseColor.haiSumi)
                .frame(maxWidth: .infinity).frame(height: 116)
                .background(YoseColor.kiDark)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: shown)
    }

    // MARK: Beat 4 — 優勝発表（3組から名前をコール）
    // 二人は舞台の上に立つ（StageFrame の performers）。名前はめくり札、判は金の丸判、耳打ちは谷口の吹き出し。
    private var resultBeat: some View {
        let names = duelNames
        let winnerName = names.count > d.winnerIndex ? names[d.winnerIndex] : session.combiName
        return VStack(spacing: 12) {
            mcBubble(FinalsMC.announceWinner)
            // 優勝額縁（黒漆＋金＋朱の枠・左に特大の朱印）。他組の優勝は銀鼠の地
            HStack(spacing: 14) {
                YoseHankoStamp(text: "優勝", isSquare: true, angle: -4).scaleEffect(1.35)
                    .padding(.leading, 10).padding(.trailing, 6)
                VStack(alignment: .leading, spacing: 4) {
                    Text("頂グランプリ 今年の優勝").font(YoseFont.gothic(12, weight: .heavy))
                        .foregroundStyle(d.champion ? YoseColor.kin : YoseColor.sumi)
                    Text(winnerName).font(YoseFont.mincho(26))
                        .foregroundStyle(d.champion ? YoseColor.kinari : YoseColor.sumi)
                        .lineLimit(1).minimumScaleFactor(0.5)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 16).padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(d.champion ? YoseColor.kuroUrushi : YoseColor.ginNezu)
            .overlay(Rectangle().stroke(d.champion ? YoseColor.kin : YoseColor.sumi, lineWidth: 3))
            .overlay(Rectangle().stroke(d.champion ? YoseColor.shu : YoseColor.haiSumi, lineWidth: 1.5).padding(6))
            .background(alignment: .bottom) { Rectangle().fill(YoseColor.sumi).offset(y: 4) }
            .padding(.bottom, 4)
            .scaleEffect(celebrate || !d.champion ? 1 : 1.25)
            Spacer(minLength: 0)
            // 余韻（文言は既存のまま・地の文と台詞を分けただけ）
            if d.champion {
                VStack(spacing: 6) {
                    Text("谷口が、そっと耳打ちした。").font(YoseFont.mincho(13)).foregroundStyle(YoseColor.kinari)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(YoseColor.kuroUrushi)
                    YoseSpeechBox(speaker: "谷口", text: "……なあ、腹減ったな", roleLabel: "相方")
                }
            } else if spectator {
                YoseNarration(text: "客席の照明が上がる前に、二人で席を立った。")
            } else {
                YoseNarration(text: "届かなかった。だが、この夜の舞台には立った。")
            }
            Button {
                if spectator { onFinishSpectating?(winnerName) }
                else if d.champion { session.acknowledgeWin() } else { session.acknowledgeResult() }
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
                    ctx.fill(p, with: .color(YoseColor.kinBright.opacity(i.isMultiple(of: 2) ? 0.10 : 0.05)))
                }
            }
        }
    }
}

/// 決勝の紙吹雪（決定的な位置）
private struct ConfettiView: View {
    private let pieces = 30
    private let palette: [Color] = [YoseColor.kinBright, YoseColor.shu, YoseColor.washi]
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
