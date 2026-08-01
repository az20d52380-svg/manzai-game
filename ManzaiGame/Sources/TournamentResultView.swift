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

    /// この週の代表結果（複数戦なら最後＝最新）。非空はGameSession.pump()の`!big.isEmpty`ガードで
    /// pendingResult生成時に保証済み（WeekSummary.resultsは型としては0件も許すが、この経路では届かない）。
    private var result: StageResult { summary.results.last! }
    /// 発火した山場ページ（準決敗退/敗者復活敗退のみ非空。Fable doc02・golden非干渉）
    private var climaxPages: [ClimaxPage] { ClimaxData.pages(for: result) }
    /// この本番が道中大会（単発6種）か。道中週とGP週は重ならないので週で判別（名前ヒューリスティックを避ける）。
    private var isMidTournament: Bool { session.config.calendar.tournament(inWeek: summary.week) != nil }
    /// 結果スタンプの語。道中は単発コンテスト（入賞/敗退）、GPは回戦（通過/敗退）。判定は不変・語だけの演出的合成（⑬）。
    private func stampLabel(passed: Bool) -> String {
        if isMidTournament { return passed ? "優勝" : "敗退" }   // 道中の単発大会を勝ち抜く＝その大会で優勝（入賞とは意味が違う）
        return passed ? "通過" : "敗退"
    }

    var body: some View {
        let r = result
        let review = JudgeData.review(passed: r.passed, state: summary.state, salt: summary.week)
        let stars = JudgeData.stars(summary.state)

        ScrollView {
            VStack(spacing: 14) {
                // ヘッダ（道中大会は「頂グランプリ」帯を出さない＝大会名 r.name が主題。GP系のみ帯を出す＝⑫）
                if !isMidTournament {
                    Text("頂 グランプリ").font(.maru(12)).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 3)
                        .background(Theme.verm, in: Capsule())
                }
                Text(r.name).font(.maru(22)).foregroundStyle(.white)
                Text("第\(summary.week)週 ・ 本番").font(.maru(12, weight: .bold)).foregroundStyle(.white.opacity(0.55))

                // 笑い波形（結果連動）
                WaveformView(passed: r.passed)

                Text(r.passed ? "——どっと沸いた！" : "——固い空気…")
                    .font(.maru(15)).foregroundStyle(r.passed ? Theme.gold : .white.opacity(0.45))
                    .frame(minHeight: 20)

                if revealed {
                    stamp(passed: r.passed)
                }
                if revealedReview {
                    washi(text: review.text, judge: review.judge, passed: r.passed)
                        .transition(.opacity)
                }
                if revealedRest {
                    starsRow(stars).transition(.opacity)
                    rewardBlock(r).transition(.opacity)   // 実入りの後味: 賞金/知名度/称号のチップ（通過時のみ）
                    Button {
                        if climaxPages.isEmpty { session.acknowledgeResult() }
                        else { withAnimation(.easeInOut(duration: 0.5)) { climaxIndex = 0 } }   // ⑪ 山場へ
                    } label: {
                        Text("次へ ▶").font(.maru(15)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Theme.verm, in: RoundedRectangle(cornerRadius: Theme.Rad.btn))
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.horizontal, 40).padding(.top, 4)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 暗転した客席＝結果は舞台の闇の中で言い渡される（紙の講評が闇に浮かぶ）
        .background {
            ZStack {
                LinearGradient(colors: [Color(hex: 0x120D22), Color(hex: 0x241633), Color(hex: 0x1A1128)],
                               startPoint: .top, endPoint: .bottom)
                // 判の席に落ちるスポットライト
                RadialGradient(colors: [Color(hex: 0xFFE9C4).opacity(0.14), .clear],
                               center: UnitPoint(x: 0.5, y: 0.30), startRadius: 20, endRadius: 320)
            }
            .ignoresSafeArea()
        }
        .overlay {
            // 通過の紙吹雪（判と同時に舞う・敗退は降らない＝静けさが重さ）
            ParticleBurst(trigger: confettiFire,
                          colors: [Theme.gold, Theme.verm, .white, Theme.cExpr],
                          style: .confetti, count: 44,
                          origin: UnitPoint(x: 0.5, y: 0.30))
        }
        .screenShake(trigger: slamFire, intensity: r.passed ? 10 : 7)     // 判の衝撃（勝敗とも）
        .screenFlash(trigger: r.passed ? slamFire : 0,                    // 白むのは通過だけ
                     color: Color(hex: 0xFFEDCB), strength: 0.4)
        .onAppear {
            Task {
                // 波形の余韻＋開示前の静止0.3s（溜め→開示の最小単位・§4-2a）を含む1.6s
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                withAnimation(.spring(response: 0.22, dampingFraction: 0.62)) { revealed = true }   // 判の叩きつけ
                slamFire += 1                                                // シェイク＋（通過なら）フラッシュ
                if r.passed { confettiFire += 1; Haptics.rare() }            // 紙吹雪は勝ちの専有
                else { Haptics.confirm() }
                try? await Task.sleep(nanoseconds: 400_000_000)
                withAnimation(.easeOut(duration: 0.25)) { revealedReview = true }
                try? await Task.sleep(nanoseconds: 600_000_000)
                withAnimation(.easeOut(duration: 0.25)) { revealedRest = true }
                if !titleChips.isEmpty { Haptics.confirm() }   // 称号獲得の一拍（通過演出の hRare とは別の軽い一発）
            }
        }
        .overlay {
            if let i = climaxIndex { climaxOverlay(i) }   // ⑪ 山場のタップ送り
        }
    }

    /// 判（§3-5）: 角判rStamp・縁2pt。通過=verm／敗退=鈍色——色でなく重さの差（負けにも勝ちと同じ物量）。
    /// 敗退の地は暗転背景に溶けない鈍色（inkは闇と同化するため明度だけ上げる）。
    private func stamp(passed: Bool) -> some View {
        let c = passed ? Theme.verm : Color(hex: 0x5A5470)
        return Text(stampLabel(passed: passed))
            .font(.maru(30)).foregroundStyle(.white)
            .frame(width: 108, height: 108)
            .background(RadialGradient(colors: [c.opacity(0.88), c], center: .topLeading, startRadius: 5, endRadius: 120),
                       in: RoundedRectangle(cornerRadius: Theme.Rad.stamp))
            .overlay(RoundedRectangle(cornerRadius: Theme.Rad.stamp).stroke(.white.opacity(0.55), lineWidth: 2).padding(5))
            .rotationEffect(.degrees(-4))
            .shadow(color: c.opacity(0.55), radius: 16, y: 8)
            .scaleEffect(revealed ? 1 : 2.3)      // 高くから叩きつける（slamFire のシェイクと同時に着地）
            .opacity(revealed ? 1 : 0)
    }

    private func washi(text: String, judge: String, passed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("審 査 講 評").font(.maru(11)).tracking(6).foregroundStyle(Color(hex: 0xA98B52))
                .frame(maxWidth: .infinity).padding(.bottom, 12)
            Text(text)
                .font(.system(size: 15, design: .serif))
                .lineSpacing(7).foregroundStyle(Color(hex: 0x33301F))
                .frame(maxWidth: .infinity, alignment: .leading)
            // 講評フッタ: 審査員名は左・スタンプは右で被らせない（mvp §8）
            HStack(alignment: .bottom) {
                Text("審査員　\(judge)").font(.maru(12.5, weight: .bold)).foregroundStyle(Color(hex: 0xA98B52))
                Spacer(minLength: 8)
                Text(stampLabel(passed: passed)).font(.maru(12)).foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(passed ? Theme.verm : Theme.ink, in: RoundedRectangle(cornerRadius: Theme.Rad.stamp))
                    .rotationEffect(.degrees(-4))
            }
            .padding(.top, 16)
        }
        .padding(22)
        .background(LinearGradient(colors: [Color(hex: 0xFDFBF4), Color(hex: 0xF6EEDC)],
                                   startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0xE6D9BE), lineWidth: 1))
        .shadow(color: Color(hex: 0x785014, alpha: 0.3), radius: 14, y: 8)
    }

    // MARK: 実入りの後味（賞金/知名度/称号のチップ・通過時のみ。敗退週に金を立てない）

    @ViewBuilder private func rewardBlock(_ r: StageResult) -> some View {
        let money = moneyFameChips(r)
        let titles = titleChips
        if r.passed, !money.isEmpty || !titles.isEmpty {
            VStack(spacing: 6) {
                if !money.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(money) { BurstChipView(chip: $0, style: .slam) }
                    }
                }
                // 称号は1行1枚（金縁・その週の獲得分のみ。傷跡系 tone=.ink は出さず、きろくに静かに刻むだけ）
                ForEach(titles) { BurstChipView(chip: $0, style: .slam) }
            }
            .padding(.top, 2)
        }
    }

    private func moneyFameChips(_ r: StageResult) -> [BurstChip] {
        guard r.passed else { return [] }
        var chips: [BurstChip] = []
        if r.prize > 0 {
            chips.append(BurstChip(id: 0, text: "賞金 +\(r.prize / 10000)万", fg: .white, bg: Theme.cMoney))
        }
        let f = Int(session.lastStageFameGain.rounded())
        if f > 0 {
            chips.append(BurstChip(id: 1, text: "知名度 +\(f)", fg: .white, bg: Theme.cChara))
        }
        return chips
    }

    /// この週に獲得した称号のチップ（金縁＝fullStamp の文法）。旧セーブ復帰などで空なら出さない。
    private var titleChips: [BurstChip] {
        var chips: [BurstChip] = []
        for (i, t) in session.earnedTitles.enumerated() where t.week == summary.week {
            let spec = TitleData.spec(t.id)
            guard spec.tone != .ink else { continue }
            chips.append(BurstChip(id: 100 + i, text: "称号「\(spec.name)」",
                                   fg: Theme.goldD, bg: Color(hex: 0xFFF3D6), outline: Theme.gold))
        }
        return chips
    }

    private func starsRow(_ stars: [(String, Int)]) -> some View {
        HStack(spacing: 6) {
            ForEach(stars, id: \.0) { s in
                HStack(spacing: 3) {
                    Text(s.0).font(.maru(11)).foregroundStyle(Theme.inkDim)
                    Text(starString(s.1)).font(.system(size: 11)).foregroundStyle(Theme.goldD)
                }
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.line, lineWidth: 1.5))
            }
        }
    }

    private func starString(_ n: Int) -> String {
        String(repeating: "★", count: n) + String(repeating: "☆", count: max(0, 5 - n))
    }

    // MARK: ⑪ 山場（敗者復活で散る）のタップ送りオーバーレイ（Fable doc02）
    private func climaxOverlay(_ i: Int) -> some View {
        let page = climaxPages[min(i, climaxPages.count - 1)]
        let isLast = i >= climaxPages.count - 1
        return ZStack {
            Color(hex: 0x14121C).opacity(0.98).ignoresSafeArea()   // 暖色の結果画面から静かな夜へ転調
            VStack(alignment: .leading, spacing: 16) {
                if let sp = page.speaker {
                    Text(sp).font(.maru(12)).tracking(2).foregroundStyle(Theme.gold.opacity(0.85))
                }
                Text(page.text)
                    .font(.system(size: 17, design: .serif)).lineSpacing(10)
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.opacity)
                Text(isLast ? "タップして終える" : "タップ")
                    .font(.maru(10)).foregroundStyle(.white.opacity(0.38))
                    .frame(maxWidth: .infinity, alignment: .trailing).padding(.top, 6)
            }
            .padding(.horizontal, 34).frame(maxWidth: 430)
        }
        .contentShape(Rectangle())
        .onTapGesture {
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
