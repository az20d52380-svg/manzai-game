// YearResultView.swift
// S6 年次リザルト（正本: uiux_vision_reply_part2 §S6）。縦1カラムの紙面（年表の1ページ様式・e3）。
// 上から: 年目バッジ → 到達段階の判 → レーダー重ね(4月線+現在面) → 48週行動内訳色帯 → 出来事3行(大会結果のみ) → 賞金/知名度年計。
// トランジション: 紙面が下から0.4s・要素は上から0.15s間隔の時間差表示。判押印0.25s+hConfirm。レーダーモーフ0.8s・行動内訳帯左から0.6s。
// MVPは1年完結なので二択(勇退/続投=S6b/S9)は未実装＝「もう一度」で新周回。才能の灯りは【仮・TODO】。

import SwiftUI
import GameCore

struct YearResultView: View {
    let session: GameSession
    var onRestart: () -> Void

    private var s: GameState { session.state }
    private var o: YearOutcome? { session.outcome }

    @State private var appear = false
    @State private var stampIn = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Sp.s16) {
                yearBadge.stagger(0, appear)
                reachStamp.stagger(1, appear)
                radarBlock.stagger(2, appear)
                breakdownBlock.stagger(3, appear)
                eventsBlock.stagger(4, appear)
                totalsBlock.stagger(5, appear)
                unlockRow.stagger(6, appear)
                restartButton.stagger(7, appear)
            }
            .padding(.horizontal, Theme.Sp.s24).padding(.vertical, Theme.Sp.s32)
            .frame(maxWidth: .infinity)
        }
        .background(
            LinearGradient(colors: [Theme.bgTop, Theme.bg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        )
        .onAppear {
            withAnimation(.easeOut(duration: Theme.Motion.emph)) { appear = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { stampIn = true }
                Haptics.confirm()   // 年1回の重み
            }
        }
    }

    // MARK: 年目バッジ

    private var yearBadge: some View {
        VStack(spacing: 2) {
            Text(session.combiName).font(.maru(14)).foregroundStyle(Theme.ink)
            Text("\(session.year)年目 ・ 年次リザルト").font(.maru(11)).tracking(2).foregroundStyle(Theme.inkDim)
        }
    }

    // MARK: 到達段階の判

    private var reachStamp: some View {
        let (text, passed) = reach()
        let c = passed ? Theme.verm : Theme.ink
        return VStack(spacing: 6) {
            Text(text)
                .font(.maru(30)).foregroundStyle(.white)
                .padding(.horizontal, 22).padding(.vertical, 8)
                .background(c, in: RoundedRectangle(cornerRadius: Theme.Rad.stamp))
                .rotationEffect(.degrees(-4))
                .scaleEffect(stampIn ? 1 : 1.3)
                .opacity(stampIn ? 1 : 0)
            Text(reachSub()).font(.maru(11)).foregroundStyle(Theme.inkDim)
        }
    }

    // MARK: レーダー重ね

    private var radarBlock: some View {
        VStack(spacing: 4) {
            RadarChart(axes: RadarChart.abilityAxes(current: s, base: GameState(config: session.config), config: session.config))
                .frame(height: 210)
            HStack(spacing: 12) {
                legendDot(Theme.inkFaint, "4月", dashed: true)
                legendDot(Theme.verm, "現在", dashed: false)
            }
            .font(.maru(10)).foregroundStyle(Theme.inkDim)
        }
        .padding(Theme.Sp.s16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card))
        .e2()
    }

    // MARK: 48週 行動内訳色帯

    private var breakdownBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("この1年の使い方").font(.maru(11)).foregroundStyle(Theme.inkDim)
            ActionBreakdownBand(weeks: session.config.weeks, categoryByWeek: session.categoryLog)
            HStack(spacing: 10) {
                ForEach([BandCategory.keiko, .baito, .kaifuku, .taikai], id: \.label) { cat in
                    HStack(spacing: 4) {
                        Circle().fill(cat.color).frame(width: 7, height: 7)
                        Text(cat.label).font(.maru(9.5)).foregroundStyle(Theme.inkDim)
                    }
                }
            }
        }
        .padding(Theme.Sp.s16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card))
        .e2()
    }

    // MARK: 出来事3行（大会結果のみ）

    private var eventsBlock: some View {
        let lines = Array(session.log.suffix(3))
        return VStack(alignment: .leading, spacing: 5) {
            Text("出来事").font(.maru(11)).foregroundStyle(Theme.inkDim)
            if lines.isEmpty {
                Text("——大会は、来年こそ。").font(.system(size: 13, design: .serif)).foregroundStyle(Theme.inkDim)
            } else {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line).font(.system(size: 13, design: .serif)).foregroundStyle(Theme.ink)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Sp.s16)
        .background(Theme.card2, in: RoundedRectangle(cornerRadius: Theme.Rad.card))
        .e1()
    }

    // MARK: 賞金/知名度 年計

    private var totalsBlock: some View {
        HStack(spacing: 0) {
            total("賞金 年計", "¥\(session.totalPrize.formatted())")
            Divider().frame(height: 30)
            total("知名度", "\(Int(s.fame))")
            Divider().frame(height: 30)
            total("最終所持金", "¥\(s.money.formatted())")
        }
        .padding(.vertical, Theme.Sp.s12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card))
        .e1()
    }

    private func total(_ k: String, _ v: String) -> some View {
        VStack(spacing: 3) {
            Text(v).font(.maru(15)).monospacedDigit().foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
            Text(k).font(.maru(9.5)).foregroundStyle(Theme.inkDim)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 才能の灯り＋もう一度

    private var unlockRow: some View {
        HStack(spacing: 9) {
            Text("✦").foregroundStyle(Theme.goldD)
            Text("才能がひとつ灯った 〈来年の景色〉").font(.maru(12.5)).foregroundStyle(Theme.goldD)
        }
        .frame(maxWidth: .infinity).padding(Theme.Sp.s12)
        .background(LinearGradient(colors: [Theme.gold.opacity(0.22), Theme.gold.opacity(0.10)], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: Theme.Rad.board))
        .overlay(RoundedRectangle(cornerRadius: Theme.Rad.board).stroke(Theme.gold.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
    }

    private var restartButton: some View {
        Button(action: onRestart) {
            Text("もう一度").font(.maru(16)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, Theme.Sp.s12)
                .background(Theme.verm, in: RoundedRectangle(cornerRadius: Theme.Rad.btn))
        }
        .buttonStyle(PressableStyle()).padding(.horizontal, Theme.Sp.s24).padding(.top, Theme.Sp.s4)
    }

    private func legendDot(_ c: Color, _ label: String, dashed: Bool) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1).fill(c).frame(width: 12, height: 2)
            Text(label)
        }
    }

    // MARK: 導出

    /// 到達段階（判の文字, 通過系か）
    private func reach() -> (String, Bool) {
        guard let o else { return ("——", false) }
        if o.champion { return ("優勝", true) }
        if o.bankrupt { return ("夜逃げ", false) }
        if o.reachedFinal { return ("決勝", true) }
        let names = session.config.calendar.gpRoundNames
        switch o.roundsPassed {
        case 0: return ("予選敗退", false)
        case let n where n - 1 < names.count: return (names[n - 1].replacingOccurrences(of: "GP", with: ""), true)
        default: return ("\(o.roundsPassed)回戦", true)
        }
    }

    private func reachSub() -> String {
        guard let o else { return "" }
        if o.champion { return "頂グランプリ制覇" }
        if o.bankrupt { return "所持金が尽きてキャリア終了" }
        if o.reachedFinal { return "決勝の舞台に立った" }
        return "頂グランプリ 到達段階"
    }
}

// MARK: 時間差表示（上から 0.15s 間隔）

private extension View {
    func stagger(_ index: Int, _ appear: Bool) -> some View {
        self
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 10)
            .animation(.easeOut(duration: Theme.Motion.std).delay(0.1 + Double(index) * 0.15), value: appear)
    }
}
