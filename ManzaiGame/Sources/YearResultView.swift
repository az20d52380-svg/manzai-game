// YearResultView.swift
// S6 年次リザルト（正本: uiux_vision_reply_part2 §S6）。縦1カラムの紙面（年表の1ページ様式・e3）。
// 上から: 年目バッジ → 到達段階の判 → レーダー重ね(4月線+現在面) → 48週行動内訳色帯 → 出来事3行(大会結果のみ) → 賞金/知名度年計。
// トランジション: 紙面が下から0.4s・要素は上から0.15s間隔の時間差表示。判押印0.25s+hConfirm。レーダーモーフ0.8s・行動内訳帯左から0.6s。
// MVPは1年完結なので二択(勇退/続投=S6b/S9)は未実装＝「もう一度」で新周回。締めは年次独白(voice_corpus yearEnd.*)。

import SwiftUI
import GameCore

struct YearResultView: View {
    let session: GameSession
    var onRestart: () -> Void
    var onEnding: (() -> Void)? = nil   // 優勝時のみ: 勇退エンディング(S6b)へ

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
                yearEndMonolog.stagger(6, appear)
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

    // MARK: 年の締めの独白（voice_corpus yearEnd.* を復元）

    /// 全ランが負けで着地する1年版デモの「年の締め」。書き上げた独白を最後の画面に載せる。
    /// 旧「才能がひとつ灯った」は実体ゼロの常時表示だったため除去（監査 §1-4-①）。
    private var yearEndMonolog: some View {
        Group {
            if let line = yearEndLine() {
                VStack(alignment: .leading, spacing: Theme.Sp.s12) {
                    Rectangle().fill(Theme.inkFaint.opacity(0.5)).frame(width: 40, height: 1)
                    Text(line)
                        .font(.system(size: 14.5, design: .serif))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, Theme.Sp.s16)
                .padding(.top, Theme.Sp.s4)
            }
        }
    }

    /// 年の締めの独白を1行返す。到達結果で 躍進/停滞/貧乏 に決定的分岐（RNG非消費＝golden不変）。
    /// オーナー決定 2026-07-06：else（決勝未到達・非破産）を fame/roundsPassed で二分。閾値は【仮】——sim到達分布で後日確定。
    private func yearEndLine() -> String? {
        guard let o else { return nil }
        let pool: [String]
        if o.bankrupt {
            pool = Self.yeBankrupt                                               // 貧乏年
        } else if !o.champion && !o.reachedFinal && s.compat < 10 {
            pool = Self.yeDissolution                                            // 解散年（相性が最後まで低い＝袂を分かつ・統合設計1-α・閾値【仮】）
        } else if o.champion || o.reachedFinal || o.roundsPassed >= 3 || Int(s.fame) >= 30 {
            pool = Self.yeLeap                                                    // 躍進年
        } else {
            pool = Self.yeStall                                                  // 停滞年
        }
        guard !pool.isEmpty else { return nil }
        let salt = Int(s.fame) &+ o.roundsPassed &+ session.year                 // 状態から決定的（乱数非消費）
        return pool[((salt % pool.count) + pool.count) % pool.count]
    }

    // yearEnd.* 逐語（voice_corpus_v0 §4-3＋§8・calibration 0be8a11）。独白(俺)・標準語。相方固有名を含む行は除外。
    private static let yeLeap = [   // 躍進年
        "今年の手帳は、十二月まで字がある。去年までは、夏から白かった。",
        "来年の予定は、もう春まで埋まっている。空けておく週を、こっちから頼んで作ってもらった。",
        "今年から、楽屋で若手が道を空けてくれる。ぶつかりそうになって、こっちが先に謝った回もある。",
    ]
    private static let yeStall = [  // 停滞年
        "合わせの録音で、電話の容量が今年も一杯になった。順位は、去年のままだ。",
        "今年は、同じ準決勝の会場に三度立った。三度とも、決勝の会場を見ずに帰った。",
        "順位が貼り出される紙の、俺たちの名前の上と下は、今年も同じ二組だった。",
    ]
    private static let yeBankrupt = [  // 貧乏年
        "十二月の最後の週まで、二人とも、稽古場代の缶には入れ続けた。",
        "宣材写真を、今年、撮り直した。金は、バイトを一週分足して作った。",
        "エントリー用紙は、今年も一枚も出し惜しまなかった。振り込んだ参加費のうち、半分は捨てた金になった。",
    ]
    private static let yeDissolution = [  // 解散年（相性が最後まで低い＝袂を分かつ）＝終わり方の語彙（統合設計§1-2・drama-voice採点済A○/B3○）
        "その月のライブの香盤表に、二人の名前が並んでいた。並ぶのは、それが最後だった。\n次の月の分には、下の方に、俺の名だけがあった。",
    ]

    private var restartButton: some View {
        Button(action: onEnding ?? onRestart) {
            Text(onEnding != nil ? "勇退エンディングへ ▶" : "もう一度").font(.maru(16)).foregroundStyle(.white)
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
