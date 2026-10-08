// TournamentResultView.swift
// SCREEN 02→03: 笑い波形メーター → 通過/敗退スタンプ → 半紙の紙講評（審査員1行＋星）。
// finals_direction の順序（波形→通過/敗退→講評）。判定は GameCore のまま・ここは表示のみ。

import SwiftUI
import GameCore

struct TournamentResultView: View {
    let session: GameSession
    let summary: WeekSummary

    @State private var revealed = false        // 判（押印）
    @State private var revealedReview = false  // 講評（判の0.4s後）
    @State private var revealedRest = false    // 星・賞金・次へ（さらに0.6s後）＝段階的な情報開示（§2-3）
    @State private var climaxIndex: Int? = nil // ⑪ 山場（敗者復活で散る）のタップ送りページ。nil=通常
    @State private var slamFire = 0            // 判の叩きつけ（screenShake+screenFlash・Juice.swift）
    @State private var confettiFire = 0        // 通過のみ: 紙吹雪（敗退は無音の重さ＝紙吹雪なし）
    /// 開示列のタスク（保持して画面を離れたら取り消す＝投げっぱなしにしない・X4-08）
    @State private var revealTask: Task<Void, Never>?
    /// 判の前の溜めをタップで畳む要求（規格K6）。判の叩きつけ以降は畳まない（解放は必ず見せる）
    @State private var skipRequested = false
    /// 開演の儀が終わったか（儀式の相 → 開示列の順・X4-11：覆いの下で開示が先に終わらない）
    @State private var ceremonyDone = false

    /// この週の代表結果（複数戦なら最後＝最新）。非空はGameSession.pump()の`!big.isEmpty`ガードで
    /// pendingResult生成時に保証済み（WeekSummary.resultsは型としては0件も許すが、この経路では届かない）。
    private var result: StageResult { summary.results.last! }
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
        if isMidTournament { return passed ? "優勝" : "敗退" }   // 道中の単発大会を勝ち抜く＝その大会で優勝（入賞とは意味が違う）
        return passed ? "通過" : "敗退"
    }

    /// 大会の格の金属色（道中＝銅／GP＝銀。金は決勝の夜だけ・§4-1）
    private var metal: Color { isMidTournament ? Theme.bronze : Theme.silver }

    /// 入口と同じ単位の「通過ライン」（名目値。道中＝大会の値／GP回戦＝その週の値／敗者復活）。無ければ出さない
    private var displayLine: Double? {
        let cal = session.config.calendar
        if let t = cal.tournament(inWeek: summary.week) { return t.line }
        if result.name == "敗者復活" { return cal.gpRevivalLine }
        return cal.gpRounds.first { $0.week == summary.week }?.line
    }
    /// 入口と同じ「いまの実力」（実力値＋相性）
    private var currentPower: Int {
        Int((GameEngine.jitsuryoku(summary.state, config: session.config) + summary.state.compat).rounded())
    }

    var body: some View {
        let r = result
        let review = JudgeData.review(passed: r.passed, state: summary.state, salt: summary.week)

        GeometryReader { geo in
            ZStack {
                // 舞台（判の前は明転・敗退はスポットを絞って色温度を下げる＝暗くはしない）
                StageFrame(mode: revealed && !r.passed ? .loser : .lit, floorTop: 0.52)
                    .animation(.easeInOut(duration: 0.4), value: revealed)

                VStack(spacing: 0) {
                    // 一文字幕の上に大会名（GP系は頂グランプリの札）
                    VStack(spacing: 4) {
                        if !isMidTournament {
                            Text("頂 グランプリ").font(.maru(.sub)).foregroundStyle(.white)
                                .padding(.horizontal, 14).padding(.vertical, 2)
                                .background(Theme.vermD, in: Capsule())
                                .overlay(Capsule().stroke(Theme.gold, lineWidth: 1))
                        }
                        Telop(text: r.name, size: 24)
                        Text("第\(summary.week)週 ・ 本番").font(.maru(.sub)).foregroundStyle(Theme.houseLight)
                    }
                    .padding(.top, 50)

                    // 判（大会名のすぐ下・二人の頭の上）＋一言のテロップ
                    VStack(spacing: 10) {
                        stamp(passed: r.passed)
                        if revealed {
                            Telop(text: r.passed ? "——どっと沸いた！" : missLine(r), size: 20,
                                  color: r.passed ? Color(hex: 0xFFE07A) : .white)
                                .transition(.opacity)
                        }
                    }
                    .padding(.top, 10)

                    Spacer(minLength: 0)

                    // 舞台板の上＝読み物と出口（判の後に段階で出す）
                    VStack(spacing: 10) {
                        if revealedReview {
                            WaveformView(passed: r.passed, nearMiss: nearMiss(r), compact: true)
                                .transition(.opacity)
                            washi(text: review.text, judge: review.judge, passed: r.passed)
                                .transition(.opacity.combined(with: .offset(y: 10)))
                        }
                        if revealedRest {
                            HStack(spacing: 8) {
                                if let line = displayLine {
                                    // G4: 入口と同じ2つを同じ大きさで再掲（大きくしない＝見込みに寄せない）
                                    Text("通過ライン \(Int(line)) ／ いまの実力 \(currentPower)")
                                        .font(.maru(.sub)).foregroundStyle(Theme.ink)
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(.white.opacity(0.92), in: Capsule())
                                }
                                if r.prize > 0 {
                                    GainChip(text: "賞金 +\(r.prize / 10000)万", kind: .gain(Theme.moneyDeep))
                                }
                            }
                            .transition(.opacity)
                            Button {
                                if climaxPages.isEmpty { session.acknowledgeResult() }
                                else { withAnimation(.easeInOut(duration: 0.5)) { climaxIndex = 0 } }   // ⑪ 山場へ
                            } label: {
                                Text("次へ ▶").font(.maru(.body)).foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, minHeight: 52)
                                    .background(Theme.verm, in: RoundedRectangle(cornerRadius: Theme.Rad.btn))
                                    .shadow(color: Theme.vermD, radius: 0, y: 3)
                            }
                            .buttonStyle(PressableStyle())
                            .padding(.horizontal, 24)
                            .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 18).padding(.bottom, 22)
                }
            }
        }
        .overlay {
            // 通過の紙吹雪（判と同時に舞う・敗退は降らない＝静けさが重さ）。色は大会の格（銅/銀）
            ParticleBurst(trigger: confettiFire,
                          colors: [metal, Theme.gold, .white, Theme.verm],
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
                    .onTapGesture { skipRequested = true }
            }
        }
        .overlay {
            if !ceremonyDone {
                StageCeremony { ceremonyDone = true; beginReveal() }
                    .transition(.opacity)
            }
        }
        .onDisappear { revealTask?.cancel() }
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
        if r.passed { Sound.play(.cheerMid) }                            // 客席の「どっ」（波形と同時）
        await pause(0.9)
        if Task.isCancelled { return }
        if !skipRequested { Sound.play(.drumroll) }                      // 開示前のタメ（畳んだ時は鳴らさない）
        await pause(0.7)
        if Task.isCancelled { return }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.62)) { revealed = true }   // 判の叩きつけ
        slamFire += 1                                                    // シェイク＋（通過なら）フラッシュ
        if r.passed {
            confettiFire += 1; Haptics.rare()
            Sound.play(.taiko); Sound.play(.applauseHall)                // 通過＝太鼓ドン＋会場拍手
        } else {
            Haptics.confirm()
            Sound.play(.taiko2)                                          // 敗退＝重いドドン（拍手なし＝静けさ）
        }
        try? await Task.sleep(nanoseconds: 400_000_000)                  // 判の解放は畳まない（0.4s は必ず見せる）
        if Task.isCancelled { return }
        withAnimation(.easeOut(duration: 0.25)) { revealedReview = true }
        try? await Task.sleep(nanoseconds: 600_000_000)
        if Task.isCancelled { return }
        withAnimation(.easeOut(duration: 0.25)) { revealedRest = true }
    }

    /// 指定秒だけ待つ。畳む要求か取り消しで即戻る。
    private func pause(_ seconds: Double) async {
        for _ in 0..<Int(seconds / 0.05) {
            if skipRequested || Task.isCancelled { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    /// 判（§3-5）: 角判rStamp・縁2pt。通過=verm／敗退=鈍色——色でなく重さの差（負けにも勝ちと同じ物量）。
    /// 敗退の地は暗転背景に溶けない鈍色（inkは闇と同化するため明度だけ上げる）。
    private func stamp(passed: Bool) -> some View {
        let c = passed ? Theme.verm : Color(hex: 0x4E423C)   // 敗退は暖色の炭（舞台の光の中で沈まない・紫は使わない）
        return Text(stampLabel(passed: passed))
            .font(.maru(.display)).foregroundStyle(.white)
            .frame(width: 124, height: 124)
            .background(RadialGradient(colors: [c.opacity(0.88), c], center: .topLeading, startRadius: 5, endRadius: 130),
                       in: RoundedRectangle(cornerRadius: Theme.Rad.stamp))
            .overlay(RoundedRectangle(cornerRadius: Theme.Rad.stamp).stroke(metal, lineWidth: 3).padding(5))   // 縁＝大会の格の金属色
            .rotationEffect(.degrees(-4))
            .shadow(color: c.opacity(0.55), radius: 16, y: 8)
            .scaleEffect(revealed ? 1 : 2.3)      // 高くから叩きつける（slamFire のシェイクと同時に着地）
            .opacity(revealed ? 1 : 0)
    }

    private func washi(text: String, judge: String, passed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                CharacterFace(spec: FaceCatalog.judge(judge), size: 40)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                VStack(alignment: .leading, spacing: 0) {
                    Text("審査講評").font(.maru(.sub)).foregroundStyle(Theme.sealName)
                    Text("審査員　\(judge)").font(.maru(.sub)).foregroundStyle(Theme.sealName)
                }
                Spacer(minLength: 8)
                Text(stampLabel(passed: passed)).font(.maru(.sub)).foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(passed ? Theme.verm : Color(hex: 0x4E423C), in: RoundedRectangle(cornerRadius: Theme.Rad.stamp))
                    .rotationEffect(.degrees(-4))
            }
            Text(text)
                .font(.maru(.bodyMedium)).lineSpacing(TypeStep.bodyMedium.lineSpacing)
                .foregroundStyle(Theme.paperInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)   // 講評は最後まで出す（切らない）
        }
        .padding(18)
        .background(LinearGradient(colors: [Theme.paperTop, Theme.paperBottom], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.paperEdge, lineWidth: 1))
        .shadow(color: Color(hex: 0x785014, alpha: 0.3), radius: 14, y: 8)
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
                    TalkBubble(advice: Advice(name: sp, text: page.text), showCue: !isLast)
                } else {
                    NarrationCard(text: page.text, showCue: !isLast)
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
        ClimaxPage(speaker: nil, text: "準決勝で落ちた。敗者復活の枠には、残った。\n次の舞台は、決勝の日の昼にある。稽古の組み直しは、その夜のうちに決めた。"),
    ]
    /// 敗者復活の敗北（週47・決勝と同日の昼）＝1年版デモの実質最終戦。話者ごと1ページ（本文はFable doc02・Skill採点済）。
    static let revivalLoss: [ClimaxPage] = [
        ClimaxPage(speaker: nil, text: "敗者復活で、終わった。\n会場を出ると、外はまだ明るかった。"),
        ClimaxPage(speaker: "谷口", text: "……なあ。夜まで、おるか。"),
        ClimaxPage(speaker: "俺", text: "見て帰る。立ち見なら、まだ入れる。"),
        ClimaxPage(speaker: nil, text: "決勝は、立ち見の柵の前で見た。\n優勝が決まった瞬間、立ち見の列はひとつ前へ詰めて、俺たちはそのままでいた。"),
        ClimaxPage(speaker: nil, text: "会場を出るとき、裏口へ、優勝したコンビ宛の花が運び込まれていくのが見えた。\n\n谷口とは、駅の手前で別れた。決めたのは、次の合わせの時間だけだった。"),
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
