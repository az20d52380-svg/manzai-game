// TournamentResultView.swift
// SCREEN 02→03: 笑い波形メーター → 通過/敗退スタンプ → 半紙の紙講評（審査員1行＋星）。
// finals_direction の順序（波形→通過/敗退→講評）。判定は GameCore のまま・ここは表示のみ。

import SwiftUI
import GameCore

struct TournamentResultView: View {
    let session: GameSession
    let summary: WeekSummary

    @State private var revealedWave = false    // 波形（開示の最初＝判より先に笑いの形を見せる）
    @State private var countProgress: Double = 0   // 得たものの数字カウントアップ 0→1
    @State private var revealed = false        // 判（押印）
    @State private var revealedReview = false  // 講評（判の0.4s後）
    @State private var revealedRest = false    // 星・賞金・次へ（さらに0.6s後）＝段階的な情報開示（§2-3）
    @State private var climaxIndex: Int? = nil // ⑪ 山場（敗者復活で散る）のタップ送りページ。nil=通常
    @State private var ctaPulse = false
    @State private var showPass = false        // 回戦突破の祝い（次へ 押下で1度だけ・GPの通過のみ）
    @State private var showBurstCutIn = false  // ハマった夜の斜めカットイン（判の叩きつけと同時に1度だけ）
    @State private var signIn = false          // 番組アイキャッチ：大会看板がドンと打ち出される
    @State private var slamFire = 0            // 判の叩きつけ（screenShake+screenFlash・Juice.swift）
    @State private var confettiFire = 0        // 通過のみ: 紙吹雪（敗退は無音の重さ＝紙吹雪なし）
    /// 開示列のタスク（保持して画面を離れたら取り消す＝投げっぱなしにしない・X4-08）
    @State private var revealTask: Task<Void, Never>?
    /// 判の前の溜めをタップで畳む要求（規格K6）。判の叩きつけ以降は畳まない（解放は必ず見せる）
    @State private var skipRequested = false
    /// 開演の儀が終わったか（儀式の相 → 開示列の順・X4-11：覆いの下で開示が先に終わらない）
    @State private var ceremonyDone = false
    /// 頂GP 準決勝の後の決勝進出者の発表（M-1 方式）。済むまで判の演出を始めない。準決勝以外は最初から済み
    @State private var announceDone = false
    /// 頂GP 予選（1回戦〜準々決勝）の知らせ方（通知→通過者一覧／相方のメッセージ）。済むまで判の演出を始めない
    @State private var qualDone = false
    private var needsQual: Bool { QualifierNoticeView.applies(result.name) }
    /// 判の前に流す観客の声（fan_report_design §1）。shown=いま見えている枚数／tap=タップで送った回数／active=声の相か
    @State private var fanShown = 0
    @State private var fanTap = 0
    @State private var fanActive = false
    /// 画面の段（儀式が終わった・判が出た）が切り替わった時刻。直後 0.4 秒のタップは誤タップとして無視する（結果板・講評を飛ばさない）。
    @State private var stageChangedAt = Date.distantPast
    private func tapAccepted() -> Bool { Date().timeIntervalSince(stageChangedAt) >= 0.4 }

    /// この週の代表結果（複数戦なら最後＝最新）。非空はGameSession.pump()の`!big.isEmpty`ガードで
    /// pendingResult生成時に保証済み（WeekSummary.resultsは型としては0件も許すが、この経路では届かない）。
    private var result: StageResult { summary.results.last! }
    private var needsAnnounce: Bool { result.name == "GP準決勝" }
    /// 判の前に流す観客の声（2〜4枚）。点数は出さない・乱数非消費（salt の剰余）
    private var fanVoices: [String] {
        let r = result
        let salt = summary.year * 131 + summary.week
        // このキャリアで出していない声を先に（同じ結果の間は同じ並び＝再描画で動かない）
        return session.fanVoices(key: salt) { used in
            FanReportData.voices(name: session.combiName, passed: r.passed, margin: r.margin,
                                 burst: r.burst == true || debugForceFanReport,
                                 salt: salt,
                                 known: FanReportData.isKnown(year: summary.year, fame: session.state.fame), used: used)
        }
    }
    /// 発火した山場ページ（準決敗退/敗者復活敗退のみ非空。Fable doc02・golden非干渉）
    private var climaxPages: [ClimaxPage] { ClimaxData.pages(for: result) }
    /// この本番が道中大会（単発6種）か。道中週とGP週は重ならないので週で判別（名前ヒューリスティックを避ける）。
    private var isMidTournament: Bool { session.config.calendar.tournament(inWeek: summary.week) != nil }
    /// 負けの距離 0..1（監査E-03）。margin（スコア−実効ライン）を3段に丸めて波形に渡す。数字は出さない。【仮】
    private func nearMiss(_ r: StageResult) -> Double {
        guard !r.passed, let m = r.margin else { return 0 }
        if m >= -3 { return 1 }
        if m >= -10 { return 0.45 }
        return 0
    }

    /// 敗退の一言（距離3段）。margin が無い旧データは従来の一言
    private func missLine(_ r: StageResult) -> String {
        guard let m = r.margin else { return "——固い空気…" }
        if m >= -3 { return "——あと一歩。" }
        if m >= -10 { return "——届かず。" }
        return "——遠い。"
    }

    /// 結果スタンプの語。道中は単発コンテスト（入賞/敗退）、GPは回戦（通過/敗退）。判定は不変・語だけの演出的合成（⑬）。
    private func stampLabel(passed: Bool) -> String {
        // 道中の単発大会（春新人賞など）は通過ライン超え＝その賞を取る（賞金・知名度＝TournamentSpec の「優勝時」）＝「優勝」。GP回戦は「通過」
        if isMidTournament { return passed ? "優勝" : "敗退" }
        return passed ? "通過" : "敗退"
    }

    /// 大会の格の金属色（道中＝銅／GP＝銀。金は決勝の夜だけ・§4-1）
    private var metal: Color { isMidTournament ? Theme.bronze : Theme.silver }

    var body: some View {
        let r = result
        let review = JudgeData.review(passed: r.passed, state: summary.state, salt: summary.year * 131 + summary.week,
                                       config: session.config, year: summary.year, margin: r.margin, burst: r.burst == true)   // 年も混ぜる＝回戦の週は固定なので週だけだと毎年同じ1行になる

        GeometryReader { geo in
            ZStack {
                // 舞台（判の前は明転・敗退はスポットを絞って色温度を下げる＝暗くはしない）
                StageFrame(mode: revealed && !r.passed ? .loser : .lit, floorTop: 0.52)
                    .animation(.easeInOut(duration: 0.4), value: revealed)

                // 下端の座布団（観客の頭の上に載る文字・ボタンの地を黒漆で沈める）
                VStack(spacing: 0) {
                    Spacer()
                    LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: YoseColor.kuroUrushi.opacity(0.92), location: 0.3), .init(color: YoseColor.kuroUrushi, location: 0.55)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 190)
                }
                .ignoresSafeArea().allowsHitTesting(false)

                // 判の前：客席のウケの波形（床に置く木札。勝敗は出さない・波の形だけ）
                if !revealed {
                    waveBoard(passed: r.passed, nearMiss: nearMiss(r), burst: r.burst == true)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.645)
                        .opacity(revealedWave && !(fanActive && fanShown > 1) ? 1 : 0)   // 声の札が2枚以上並ぶ間は波形を譲る（札の下に透けて重なる崩れを避ける・順番は不変）
                        .animation(.easeOut(duration: 0.25), value: fanShown)
                        .transition(.opacity)
                }

                VStack(spacing: 0) {
                    // 一文字幕の上に大会名（黒漆＋消金の二重枠の看板。GP系は頂グランプリの札）
                    StageSign(title: GPName.display(r.name), subtitle: "第\(summary.week)週 ・ 本番", tag: isMidTournament ? nil : "頂グランプリ")
                        .padding(.top, 8)
                        .scaleEffect(signIn ? 1 : 1.15)          // アイキャッチ：1.15→1.0 で打ち出す（se_shaku_wooden_clap）
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: signIn)
                    // 番組の下三分（小型）：LIVE札＋コンビ名＋結成年・週。点数は出さない
                    HStack(spacing: 8) {
                        Text("LIVE 生放送").font(YoseFont.gothic(10, weight: .black)).foregroundStyle(YoseColor.kinari)
                            .padding(.horizontal, 6).frame(height: 20).background(YoseColor.shu)
                            .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1.2))
                        Text(session.combiName).font(YoseFont.mincho(14)).foregroundStyle(YoseColor.kinari).lineLimit(1).minimumScaleFactor(0.6)
                        Spacer(minLength: 4)
                        Text("結成\(summary.year)年目　第\(summary.week)週").font(YoseFont.gothic(11, weight: .heavy)).foregroundStyle(YoseColor.kin).lineLimit(1)
                    }
                    .padding(.horizontal, 10).frame(height: 28)
                    .background(YoseColor.kuroUrushi.opacity(0.9))
                    .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1))
                    .padding(.horizontal, YoseMetrics.screenMargin).padding(.top, 6)
                    stepDots.padding(.top, 6)

                    // 結果額縁（大会名のすぐ下・二人の頭の上）＋一言の墨帯
                    VStack(spacing: 10) {
                        if !needsQual { verdictPlate(passed: r.passed) }   // 予選は通知で結果を先に知っている＝判の文字は出さない（客席の反応と講評だけ）
                        if revealed {
                            StageTelopBelt(text: r.passed ? "——どっと沸いた！" : missLine(r))
                                .transition(.opacity)
                        }
                    }
                    .padding(.top, 14)

                    Spacer(minLength: 0)

                    // 舞台板の上＝読み物と出口（判の後に段階で出す）
                    VStack(spacing: 10) {
                        if revealedReview {
                            washi(text: review.text, judge: review.judge, passed: r.passed)
                                .transition(.opacity.combined(with: .offset(y: 10)))
                            if !r.passed && Self.gpQualifierNames.contains(r.name) {   // §94 予選で落ちると相性が下がる（数字は出さない・ボケない）
                                taniguchiLossLine
                                    .transition(.opacity)
                            }
                        }
                        if revealedRest {
                            settlementCard(r)
                                .transition(.opacity)
                            Button {
                                if r.passed && !isMidTournament && climaxPages.isEmpty { withAnimation(.easeIn(duration: 0.2)) { showPass = true } }
                                else if climaxPages.isEmpty { session.acknowledgeResult() }
                                else { withAnimation(.easeInOut(duration: 0.5)) { climaxIndex = 0 } }   // ⑪ 山場へ
                            } label: {
                                Text("次へ 進む ▶")
                            }
                            .buttonStyle(YoseButtonStyle(.primary))
                            .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, YoseMetrics.screenMargin).padding(.bottom, 18)
                }
            }
        }
        .overlay {
            if r.passed && revealed { RisingGlow().allowsHitTesting(false).transition(.opacity) }
        }
        .overlay {
            // 通過の紙吹雪（判と同時に舞う・敗退は降らない＝静けさが重さ）。色は大会の格（銅/銀）
            ParticleBurst(trigger: confettiFire,
                          colors: [YoseColor.kinBright, YoseColor.kin, YoseColor.washi, YoseColor.shu],
                          style: .confetti, count: 44,
                          origin: UnitPoint(x: 0.5, y: 0.40))
        }
        .screenShake(trigger: slamFire, intensity: r.passed ? 10 : 7)     // 判の衝撃（勝敗とも）
        .screenFlash(trigger: r.passed ? slamFire : 0,                    // 白むのは通過だけ
                     color: Color(hex: 0xFFEDCB), strength: 0.4)
        .overlay {
            // 判が出るまでは画面のどこを叩いても溜めを畳んで判へ飛ぶ（K6・初回から）
            if !revealed {
                Color.clear.contentShape(Rectangle())
                    .onTapGesture { guard tapAccepted() else { return }; if fanActive { fanTap += 1 } else { skipRequested = true } }   // 声の相は1枚ずつ送る
            }
        }
        .overlay(alignment: .bottom) {
            // 判の前の観客の声（タップで次の1枚／「飛ばす」で判へ）。判が出たら消える
            if fanActive && !revealed {
                VStack(spacing: 6) {
                    ForEach(Array(fanVoices.prefix(fanShown).enumerated()), id: \.offset) { i, t in
                        fanReportCard(t, showTag: i == 0).transition(.opacity.combined(with: .offset(y: 10)))   // 見出し札は1枚目だけ（3連呼を避ける）
                    }
                    HStack(spacing: 10) {   // 進む（画面タップと同じ）が主・飛ばすは副。幅は決める
                        Button("次の声へ ▶") { fanTap += 1 }
                            .buttonStyle(YoseButtonStyle(.primary))
                        Button("スキップ") { skipRequested = true }
                            .buttonStyle(YoseButtonStyle(.secondary))
                            .frame(width: 104)
                    }
                    .padding(.top, 10)
                    .background(alignment: .bottom) {   // ボタンの座布団（客席の頭と重ならない黒漆の帯）
                        YoseColor.kuroUrushi.opacity(0.88)
                            .padding(.horizontal, -YoseMetrics.screenMargin)
                            .padding(.bottom, -18)
                            .overlay(alignment: .top) { Rectangle().fill(YoseColor.kin).frame(height: 1.5).padding(.horizontal, -YoseMetrics.screenMargin) }
                            .ignoresSafeArea(edges: .bottom)
                    }
                }
                .padding(.horizontal, YoseMetrics.screenMargin).padding(.bottom, 18)
                .transition(.opacity)
            }
        }
        .overlay {
            // 判のあとも、タップで残りの段階（講評・得たもの）を一気に出せる。次へのボタンは出し切ってから
            if revealed && !revealedRest && ceremonyDone {
                Color.clear.contentShape(Rectangle())
                    .onTapGesture { guard tapAccepted() else { return }; finishReveal() }
            }
        }
        .onChange(of: ceremonyDone) { _, _ in stageChangedAt = Date() }
        .onChange(of: revealed) { _, _ in stageChangedAt = Date() }
        .onChange(of: revealedReview) { _, _ in stageChangedAt = Date() }
        .overlay {
            if !ceremonyDone && (announceDone || !needsAnnounce) && (qualDone || !needsQual) {
                StageCeremony { ceremonyDone = true; beginReveal() }
                    .transition(.opacity)
            }
        }
        .onAppear { signIn = true }
        .onDisappear { revealTask?.cancel() }
        #if DEBUG
        .onAppear {   // 目視用：MZ_UI=result_done で演出を最後まで進めた状態で開く
            if ProcessInfo.processInfo.environment["MZ_UI"] == "result_done" { ceremonyDone = true; finishReveal(); if ProcessInfo.processInfo.environment["MZ_PASSFX"] != nil { showPass = true } }   // MZ_PASSFX=1 で回戦突破の祝いを直接開く
        }
        #endif
        .overlay {
            if needsQual && !qualDone {   // 判の前に、予選の結果の知らせ（通知→一覧／相方のメッセージ）
                QualifierNoticeView(combiName: session.combiName, partnerName: Names.partner, year: summary.year, roundName: result.name, passed: result.passed) {
                    withAnimation(.easeOut(duration: 0.3)) { qualDone = true }
                }
                .transition(.opacity)
            }
        }
        .overlay {
            if needsAnnounce && !announceDone {   // 判の前に、決勝進出者の発表（五十音順の読み上げ）
                FinalistAnnounceView(combiName: session.combiName, year: summary.year, passed: result.passed) {
                    withAnimation(.easeOut(duration: 0.3)) { announceDone = true }
                }
                .transition(.opacity)
            }
        }
        .overlay {
            if showBurstCutIn { YoseBigSuccessCutIn(title: "ハマった夜！", showGains: false) { showBurstCutIn = false }.allowsHitTesting(false) }
        }
        .overlay {
            if showPass {   // 回戦突破の祝い（通過の判の後・次へ の代わりに1度だけ）。タップで閉じて先へ
                YosePassCelebrationView(duoName: session.combiName, roundName: GPName.display(r.name), judgeName: review.judge,
                                        nextStep: "次戦へ", fameGain: 0,   // 講評・知名度は判の画面で出し済み＝重複させない
                                        threshold: 0, power: Int(Ability.allCases.reduce(0.0) { $0 + summary.state[$1] }.rounded()),
                                        judgeComment: "") { showPass = false; session.acknowledgeResult() }
                    .transition(.opacity)
            }
        }
        .overlay {
            if let i = climaxIndex { climaxOverlay(i) }   // ⑪ 山場のタップ送り
        }
    }

    /// 開示列を始める（1回だけ）。開演の儀（visual_genre_overhaul_v1 §6 L11）を挟む時はその相の後にここを呼ぶ。
    private func beginReveal() {
        guard revealTask == nil else { return }
        Sound.bgm(.tension)                                              // 本番の緊張（日常BGMからクロスフェード）
        revealTask = Task { await runReveal() }
    }

    /// 波形の余韻＋開示前の静止（溜め→開示の最小単位・§4-2a）→判→講評→残り。溜めは skipRequested で畳める。
    private func runReveal() async {
        let r = result
        withAnimation(.easeOut(duration: 0.35)) { revealedWave = true }  // ①波形が先
        if r.passed { Sound.play(.cheerMid) }                            // 客席の「どっ」（波形と同時）
        await pause(0.9)
        if Task.isCancelled { return }
        await runFanVoices()                                             // 判の前：観客の声を2〜4枚（タップ送り・飛ばせる）
        if Task.isCancelled { return }
        if !skipRequested { Sound.play(.drumroll) }                      // 開示前のタメ（畳んだ時は鳴らさない）
        await pause(0.7)
        if Task.isCancelled { return }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.62)) { revealed = true }   // 判の叩きつけ
        slamFire += 1                                                    // シェイク＋（通過なら）フラッシュ
        if r.burst == true && !skipRequested { showBurstCutIn = true }   // ハマった夜＝斜めカットイン（約1秒で自動退場）
        if r.passed {
            if needsQual { Sound.play(.applauseHall) }                   // 予選＝拍手と歓声だけ（判の文字・紙吹雪・太鼓なし）
            else { confettiFire += 1; Haptics.rare(); Sound.play(.taiko); Sound.play(.applauseHall) }   // 通過＝太鼓ドン＋会場拍手
        } else {
            if !needsQual { Haptics.confirm(); Sound.play(.taiko2) }     // 予選の敗退は静かな客席だけ
            // 敗退＝重いドドン（拍手なし＝静けさ）
        }
        try? await Task.sleep(nanoseconds: 400_000_000)                  // 判の解放は畳まない（0.4s は必ず見せる）
        if Task.isCancelled { return }
        #if DEBUG
        if ProcessInfo.processInfo.environment["MZ_HOLD"] != nil { return }   // 目視用：判の直後で止める（段階の途中を撮る）
        #endif
        withAnimation(.easeOut(duration: 0.25)) { revealedReview = true }
        try? await Task.sleep(nanoseconds: 600_000_000)
        if Task.isCancelled { return }
        withAnimation(.easeOut(duration: 0.25)) { revealedRest = true }
        withAnimation(.easeOut(duration: r.passed ? 1.1 : 0.8)) { countProgress = 1 }   // ④数字がカウントアップ
    }

    /// タップで残りを一気に出す（数字は出し切った値で止める）
    private func finishReveal() {
        revealTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            revealedWave = true; revealed = true; revealedReview = true; revealedRest = true; countProgress = 1
        }
    }

    /// 観客の声を1枚ずつ出す。各枚は約2.4秒で自動送り、タップで即次へ、「飛ばす」で判へ。最後の1枚の後も同じ間を置く。
    private func runFanVoices() async {
        let n = fanVoices.count
        guard n > 0, !skipRequested else { return }
        withAnimation(.easeOut(duration: 0.2)) { fanActive = true }
        for i in 1...n {
            withAnimation(.easeOut(duration: 0.3)) { fanShown = i }
            Sound.play(.cursor)
            let t0 = fanTap
            for _ in 0..<48 {   // 2.4秒
                if skipRequested || Task.isCancelled || fanTap != t0 { break }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            if skipRequested || Task.isCancelled { break }
        }
        withAnimation(.easeOut(duration: 0.2)) { fanActive = false }
    }

    /// 指定秒だけ待つ。畳む要求か取り消しで即戻る。
    private func pause(_ seconds: Double) async {
        for _ in 0..<Int(seconds / 0.05) {
            if skipRequested || Task.isCancelled { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    /// 今どの段かを示す3つの角札（客席の反応 ▶ 結果発表 ▶ 講評と精算）。順序・時間は変えない表示だけ
    private var stepDots: some View {
        let cur = !revealed ? 0 : (revealedReview ? 2 : 1)
        let names = ["① 客席の反応", "② 結果発表", "③ 講評・精算"]
        return HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Text(names[i]).font(YoseFont.gothic(11, weight: .heavy))
                    .foregroundStyle(i == cur ? YoseColor.kinari : YoseColor.sumi.opacity(0.75))
                    .frame(maxWidth: .infinity).frame(height: 22)
                    .background(i == cur ? YoseColor.shu : YoseColor.ki)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: i == cur ? 1.5 : 1))
                if i < 2 { Image(systemName: "arrowtriangle.right.fill").font(.system(size: Font.mzScaled(8))).foregroundStyle(YoseColor.kin).accessibilityHidden(true) }
            }
        }
        .padding(.horizontal, YoseMetrics.screenMargin)
    }

    /// 結果額縁（押印の演出）。通過/優勝＝黒漆＋金＋朱／敗退＝銀鼠＋墨の重い枠。語は stampLabel（判定は不変）。
    /// 通過は高くから叩きつける／敗退は低く静かに沈む（slamFire のシェイクと同時に着地）。
    private func verdictPlate(passed: Bool) -> some View {
        StageVerdictPlate(text: stampLabel(passed: passed), lost: !passed)
            .scaleEffect(1.15)
            .padding(.vertical, 6)
            .scaleEffect(revealed ? 1 : (passed ? 2.6 : 1.5))
            .opacity(revealed ? 1 : 0)
    }

    /// 客席のウケの波形（24本の縦スリット。通過＝後半へ育ってオチで跳ねる／敗退＝低く疎ら・惜しいほど後半が立つ）
    private func waveBoard(passed: Bool, nearMiss: Double, burst: Bool) -> some View {
        let n = 24
        func level(_ k: Int) -> Double {
            let x = Double(k) / Double(n - 1)
            let jitter = 0.5 + 0.5 * abs(sin(Double(k) * 2.3 + 1.1))
            let surge = burst ? exp(-pow((x - 0.45) / 0.10, 2)) * 0.7 : 0
            let a: Double
            if passed { a = 0.16 + 0.5 * x + exp(-pow((x - 0.83) / 0.08, 2)) * 0.95 + surge }
            else { a = 0.10 + 0.30 * nearMiss * x + 0.06 * sin(x * 8) + surge }
            return min(1, a) * (0.55 + 0.45 * jitter)
        }
        return VStack(spacing: 6) {
            Text("客席のウケ").font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.enji)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 0) {   // ツカミ／中盤／オチの3等分の見出し
                ForEach(["ツカミ", "中盤", "オチ"], id: \.self) { t in
                    Text(t).font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                        .frame(maxWidth: .infinity)
                }
            }
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<n, id: \.self) { k in
                    let v = level(k)
                    Rectangle().fill(v > 0.85 ? YoseColor.kinBright : (passed ? YoseColor.shu : YoseColor.haiSumi))
                        .frame(height: max(4, 54 * v))
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 56, alignment: .bottom)
            .background {   // 計器の目盛り（25/50/75%の薄い横破線）。低ウケでも上が空白に見えない
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        Spacer(minLength: 0)
                        Rectangle().stroke(YoseColor.kiDark.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3])).frame(height: 1)
                    }
                    Spacer(minLength: 0)
                }
            }
            .overlay {   // 3等分の縦仕切り（細い破線）
                HStack(spacing: 0) {
                    Color.clear.frame(maxWidth: .infinity)
                    Rectangle().stroke(YoseColor.kiDark, style: StrokeStyle(lineWidth: 1, dash: [3, 3])).frame(width: 1)
                    Color.clear.frame(maxWidth: .infinity)
                    Rectangle().stroke(YoseColor.kiDark, style: StrokeStyle(lineWidth: 1, dash: [3, 3])).frame(width: 1)
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .yoseKifuda()
        .padding(.horizontal, YoseMetrics.screenMargin + 6)
    }

    /// §94 予選（1回戦〜準決勝）。敗者復活・決勝の負けでは相性は下がらない
    private static let gpQualifierNames: Set<String> = ["GP1回戦", "GP2回戦", "GP3回戦", "GP準々決勝", "GP準決勝"]
    private var taniguchiLossLine: some View {
        HStack(spacing: 8) {
            Text("谷口").font(YoseFont.captionBold).foregroundStyle(YoseColor.kin)
                .padding(.horizontal, 8).frame(height: 22).background(YoseColor.kuroUrushi)
            Text("……次や、次").font(YoseFont.dialogueBody).foregroundStyle(YoseColor.sumi)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .yoseHarigami()
        .padding(.bottom, 2)
    }

    /// 結果・精算の2段貼り紙（上段：突破判子／下段：賞金・知名度）。数字と基準は出さない
    private func settlementCard(_ r: StageResult) -> some View {
        let hasPrize = r.prize > 0
        let hasFame = session.lastResultFameDelta >= 0.5
        return VStack(spacing: 0) {
            if r.passed {
                YoseHankoStamp(text: "突破", angle: -8)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
            }
            if hasPrize || hasFame {
                Rectangle().fill(YoseColor.kiDark).frame(height: 1)
                HStack(spacing: 10) {
                    if hasPrize {
                        RollingNumberText(value: Double(r.prize / 10000) * countProgress, prefix: "賞金 +", suffix: "万")
                            .font(YoseFont.numMedium).foregroundStyle(YoseColor.sumi)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(YoseColor.kin.opacity(0.2))
                            .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1.5))
                    }
                    if hasFame {
                        Text("知名度 \(Int(summary.state.fame.rounded()))").font(YoseFont.numMedium).foregroundStyle(YoseColor.sumi)
                        YoseTag(text: "↑ +\(Int(session.lastResultFameDelta.rounded()))", style: .outlineShu)
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(YoseColor.ki.opacity(0.35))
            }
        }
        .yoseHarigami(isFeatured: r.passed)   // 突破・賞金の下段を主役に（講評の貼り紙は普通の枠）
        .overlay { if r.passed { Rectangle().stroke(YoseColor.kinBright, lineWidth: 2.5).allowsHitTesting(false) } }   // 通過したら枠が金に光る
        .shadow(color: r.passed ? YoseColor.kinBright.opacity(0.7) : .clear, radius: 9)
        .padding(.bottom, 2)
    }

    /// DEBUG限定の目視フック：MZ_FANREPORT=1 でハマった夜でなくてもカードを出す（表示だけ・判定不変）
    private var debugForceFanReport: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["MZ_FANREPORT"] != nil
        #else
        return false
        #endif
    }

    /// 観客の一言（架空SNS）。審査員の講評と見分けがつくよう、貼り紙＋SNS名の角札で出す
    private func fanReportCard(_ text: String, showTag: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if showTag { YoseTag(text: "客席アンケート ・ \(FanReportData.sns)", style: .outlineSumi) }
            Text(text).font(YoseFont.mincho(14)).lineSpacing(4).foregroundStyle(YoseColor.sumi)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .yoseHarigami()
        .padding(.bottom, 2)
    }

    /// 審査講評の貼り紙（審査員1人・点数は出さない）。左上に黒漆の名札、右に講評印
    private func washi(text: String, judge: String, passed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text("審査講評").font(YoseFont.captionBold).foregroundStyle(YoseColor.kin)
                    Text(judge).font(YoseFont.mincho(15)).foregroundStyle(YoseColor.kinari)
                }
                .padding(.horizontal, 10).frame(height: 26)
                .background(YoseColor.kuroUrushi)
                Spacer(minLength: 8)
                YoseHankoStamp(text: passed ? "秀" : "惜", isSquare: true, angle: -6).scaleEffect(0.85)
            }
            Text(text)
                .font(YoseFont.dialogueBody).lineSpacing(6)
                .foregroundStyle(YoseColor.sumi)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)   // 講評は最後まで出す（切らない）
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .yoseHarigami()
        .padding(.bottom, 2)
    }

    // MARK: ⑪ 山場（敗者復活で散る）のタップ送りオーバーレイ（Fable doc02）
    private func climaxOverlay(_ i: Int) -> some View {
        let page = climaxPages[min(i, climaxPages.count - 1)]
        let isLast = i >= climaxPages.count - 1
        return VStack(spacing: 0) {
            ReminiscenceScene(mood: .eve, together: true)   // 会場の外の宵（暗転ではなく夕景・§4-1）
                .frame(maxHeight: .infinity)
            Group {
                if let sp = page.speaker {
                    YoseSpeechBox(speaker: sp, text: page.text, roleLabel: sp == "谷口" ? "相方" : nil)
                } else {
                    YoseNarration(text: page.text)
                }
            }
            .id(i)
            .transition(.opacity)
            .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 34)
        }
        .background(LinearGradient(colors: Theme.duskEve, startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture {
            Sound.play(.cursor)
            if isLast { session.acknowledgeResult() }
            else { withAnimation(.easeInOut(duration: 0.45)) { climaxIndex = i + 1 } }
        }
        .transition(.opacity)
    }
}

// MARK: ⑪ 実質最終戦の語り（Fable doc02・敗者復活で散る＝その年の終幕・静的タップ送り・golden非干渉）

struct ClimaxPage {
    let speaker: String?   // nil=地の文/独白（俺のPOV）・非nil=会話の話者（谷口/俺/相方）
    let text: String
}

enum ClimaxData {
    /// 準決敗退（週45）の前段。敗者復活の枠が残る＝ここでは泣かせず軽く受ける。
    static let semifinalLoss: [ClimaxPage] = [
        ClimaxPage(speaker: nil, text: "準決勝で落ちた。でも、敗者復活に回れる。\n決勝の日の昼が勝負だ。今夜のうちに稽古を組み直そう。"),
    ]
    /// 敗者復活の敗北（週47・決勝と同日の昼）＝1年版デモの実質最終戦。話者ごと1ページ（本文はFable doc02・Skill採点済）。
    static let revivalLoss: [ClimaxPage] = [
        ClimaxPage(speaker: nil, text: "敗者復活で負けた。今年は、ここまでだ。"),
        ClimaxPage(speaker: "谷口", text: "……決勝、見ていくか？"),
        ClimaxPage(speaker: "俺", text: "見よう。来年、あそこに立つために。"),
        ClimaxPage(speaker: nil, text: "決勝会場。立ち見の列の後ろ。"),
        ClimaxPage(speaker: "谷口", text: "優勝したとこ、ほんまにすごかったな"),
        ClimaxPage(speaker: "俺", text: "ああ。今の俺たちとは、まだ差がある"),
        ClimaxPage(speaker: nil, text: "帰り道。駅の手前。"),
        ClimaxPage(speaker: "谷口", text: "悔しいな。来年は、絶対あっち側に立とな"),
        ClimaxPage(speaker: "俺", text: "ああ。次の合わせ、いつにする"),
    ]
    /// 本番結果から山場ページを選ぶ（発火A=準決敗退／発火B=敗者復活敗退）。該当なし=空＝通常の「次へ」。
    static func pages(for r: StageResult) -> [ClimaxPage] {
        guard !r.passed else { return [] }
        switch r.name {
        case "GP準決勝": return semifinalLoss
        case "敗者復活": return revivalLoss
        default: return []
        }
    }
}

/// 数字のカウントアップ用（value が 0→目標へ動く間、整数で刻む）。表示だけ。
struct RollingNumberText: View, Animatable {
    var value: Double
    let prefix: String
    let suffix: String
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }
    var body: some View {
        Text("\(prefix)\(Int(value.rounded()))\(suffix)").monospacedDigit()
    }
}


/// 歓声の熱気＝金と白の光粒が下からふわっと立ち上る（床の折れ線の代わり）
private struct RisingGlow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View { decorativeBody.accessibilityHidden(true) }   // 飾り（読み上げ対象外）
    @ViewBuilder private var decorativeBody: some View {
        TimelineView(.animation(minimumInterval: nil, paused: reduceMotion)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                for i in 0..<26 {
                    let seed = Double(i) * 12.9898
                    let x = (sin(seed) * 0.5 + 0.5) * size.width
                    let speed = 0.06 + (cos(seed * 1.7) * 0.5 + 0.5) * 0.08
                    let ph = (t * speed + Double(i) * 0.137).truncatingRemainder(dividingBy: 1)
                    let y = size.height * (1.02 - ph)
                    let r = 1.5 + (sin(seed * 3.1) * 0.5 + 0.5) * 2.5
                    let a = sin(ph * .pi) * 0.7
                    let c = i % 3 == 0 ? Color.white : Color(hex: 0xFFE07A)
                    ctx.fill(Path(ellipseIn: CGRect(x: x + sin(t + seed) * 8, y: y, width: r * 2, height: r * 2)), with: .color(c.opacity(a)))
                }
            }
        }
        .ignoresSafeArea()
    }
}
