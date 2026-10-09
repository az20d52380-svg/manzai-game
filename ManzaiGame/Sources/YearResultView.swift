// YearResultView.swift
// S6 年次リザルト（正本: uiux_vision_reply_part2 §S6）。縦1カラムの紙面（年表の1ページ様式・e3）。
// 上から: 年目バッジ → 到達段階の判 → レーダー重ね(4月線+現在面) → 48週行動内訳色帯 → 出来事3行(大会結果のみ) → 賞金/知名度年計。
// トランジション: 紙面が下から0.4s・要素は上から0.15s間隔の時間差表示。判押印0.25s+hConfirm。レーダーモーフ0.8s・行動内訳帯左から0.6s。
// 複数年キャリア（2026-10-10）: 区切りでない年末は「◯年目へ」で翌年へ。優勝年は勇退エンディングへ、
// 夜逃げ・結成10年目の年末は「もう一度」で新しいキャリアへ。締めは年次独白(voice_corpus yearEnd.*)。

import SwiftUI
import GameCore

struct YearResultView: View {
    let session: GameSession
    var onRestart: () -> Void
    var onEnding: (() -> Void)? = nil   // 優勝時のみ: 勇退エンディング(S6b)へ
    var onNextYear: (() -> Void)? = nil // キャリアが続く年末のみ: 翌年へ

    private var s: GameState { session.state }
    private var o: YearOutcome? { session.outcome }

    @State private var appear = false
    @State private var stampIn = false
    @State private var confettiFire = 0

    var body: some View {
        ScrollView {
            // 最初の1画面＝判＋等級の段（1年で何がどれだけ育ったか・G5）。レーダーや内訳は下へ
            VStack(spacing: Theme.Sp.s16) {
                yearBadge.stagger(0, appear)
                reachStamp.stagger(1, appear)
                gradeLadder.stagger(2, appear)
                historyBlock.stagger(2, appear)
                totalsBlock.stagger(3, appear)
                eventsBlock.stagger(4, appear)
                yearEndMonolog.stagger(5, appear)
                restartButton.stagger(6, appear)
                breakdownBlock.stagger(7, appear)
                radarBlock.stagger(8, appear)
            }
            .padding(.horizontal, Theme.Sp.s24).padding(.vertical, Theme.Sp.s32)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.bgGradient.ignoresSafeArea())
        .overlay {
            // 優勝の年だけ、判と同時に金の紙吹雪（年に1度の祝い）
            ParticleBurst(trigger: confettiFire, colors: [Theme.gold, Theme.verm, .white, Color(hex: 0xFFE07A)],
                          style: .confetti, count: 54, origin: UnitPoint(x: 0.5, y: 0.18))
        }
        .onAppear {
            withAnimation(.easeOut(duration: Theme.Motion.emph)) { appear = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { stampIn = true }
                Haptics.confirm()   // 年1回の重み
                if o?.champion == true { confettiFire += 1; Sound.play(.fanfare) }
            }
        }
    }

    // MARK: 等級の段（4月→いま・G5）

    /// 5能力の 4月の等級 → いまの等級 と、次の等級までの進み。上がった能力は金の縁と「↑」。等級は表示写像だけ（Theme.rank）
    private var gradeLadder: some View {
        let base = session.yearStartState
        let order: [Ability] = [.センス, .発想, .表現, .華, .メンタル]
        return VStack(alignment: .leading, spacing: 9) {
            Text("この1年で育ったもの").font(.maru(.sub)).foregroundStyle(Theme.inkSub)
            ForEach(order, id: \.self) { a in
                let from = Theme.rank(base[a]), to = Theme.rank(s[a])
                let up = from != to
                let cap = a == .メンタル ? session.config.mentalCap : session.config.abilityCap
                HStack(spacing: 10) {
                    AbilityBadge(ability: a, size: 22)
                    Text("\(a)").font(.maru(.sub)).foregroundStyle(Theme.ink).frame(width: 56, alignment: .leading)
                    gradeChip(from, dim: true)
                    Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.inkSub)
                    gradeChip(to, dim: false)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.abilityColor(a).opacity(0.14))
                            Capsule().fill(Theme.abilityColor(a))
                                .frame(width: geo.size.width * Theme.rankProgress(s[a], cap: cap))
                        }
                    }
                    .frame(height: 9)
                    Text(up ? "↑" : " ").font(.maru(.sub)).foregroundStyle(Theme.goldDeep).frame(width: 14)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(up ? Color(hex: 0xFFF6DD) : .clear, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(up ? Theme.gold : .clear, lineWidth: 2))
            }
        }
        .padding(Theme.Sp.s16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Rad.card).stroke(Theme.line, lineWidth: 2.5))
        .hardShadow()
    }

    private func gradeChip(_ g: String, dim: Bool) -> some View {
        Text(g).font(.maru(17, weight: .black)).foregroundStyle(.white)
            .frame(width: 30, height: 26)
            .background(Theme.gradeColor(g).opacity(dim ? 0.55 : 1), in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: これまで（1年＝1行・2年目以降だけ）

    /// 結成からの頂グランプリの到達を1年1行で並べる（何年もかけて登っていく手応え・表示専用）
    @ViewBuilder private var historyBlock: some View {
        if session.yearHistory.count >= 2 {
            VStack(alignment: .leading, spacing: 6) {
                Text("これまでの頂グランプリ").font(.maru(.sub)).foregroundStyle(Theme.inkSub)
                ForEach(session.yearHistory, id: \.year) { r in
                    let label = Self.reachLabel(r, names: session.config.calendar.gpRoundNames)
                    HStack(spacing: 10) {
                        Text("\(r.year)年目").font(.maru(.sub)).monospacedDigit().foregroundStyle(Theme.inkSub)
                            .frame(width: 52, alignment: .leading)
                        Text(label).font(.maru(.sub)).foregroundStyle(r.champion || r.reachedFinal ? Theme.goldDeep : Theme.ink)
                        Spacer()
                        if r.year == session.year {
                            Text("今年").font(.maru(.sub)).foregroundStyle(.white)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Theme.vermD, in: Capsule())
                        }
                    }
                }
            }
            .padding(Theme.Sp.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card))
            .overlay(RoundedRectangle(cornerRadius: Theme.Rad.card).stroke(Theme.line, lineWidth: 2.5))
            .hardShadow()
        }
    }

    /// 1年の到達の短い呼び名（年表・これまで共用）。敗れた回戦を言う（監査C-07 と同じ規則）
    static func reachLabel(_ r: GameSession.YearRecord, names: [String]) -> String {
        if r.champion { return "優勝" }
        if r.bankrupt { return "夜逃げ" }
        if r.reachedFinal { return "決勝" }
        if r.roundsPassed < names.count { return names[r.roundsPassed].replacingOccurrences(of: "GP", with: "") + "敗退" }
        return "準決勝敗退"
    }

    // MARK: 年目バッジ

    private var yearBadge: some View {
        VStack(spacing: 2) {
            Text(session.combiName).font(.maru(.title)).foregroundStyle(Theme.ink)
            Text("\(session.year)年目 ・ 年次リザルト").font(.maru(.sub)).foregroundStyle(Theme.inkSub)
        }
    }

    // MARK: 到達段階の判

    private var reachStamp: some View {
        let (text, passed) = reach()
        let c = passed ? Theme.verm : Theme.ink
        return VStack(spacing: 6) {
            Text(text)
                .font(.maru(.display)).foregroundStyle(.white)
                .padding(.horizontal, 24).padding(.vertical, 8)
                .background(c, in: RoundedRectangle(cornerRadius: Theme.Rad.stamp))
                .rotationEffect(.degrees(-4))
                .scaleEffect(stampIn ? 1 : 1.3)
                .opacity(stampIn ? 1 : 0)
            Text(reachSub()).font(.maru(.sub)).foregroundStyle(Theme.inkSub)
        }
    }

    // MARK: レーダー重ね

    private var radarBlock: some View {
        VStack(spacing: 4) {
            RadarChart(axes: RadarChart.abilityAxes(current: s, base: session.yearStartState, config: session.config))
                .frame(height: 210)
            HStack(spacing: 12) {
                legendDot(Theme.inkFaint, "4月", dashed: true)
                legendDot(Theme.verm, "現在", dashed: false)
            }
            .font(.maru(.sub)).foregroundStyle(Theme.inkSub)
        }
        .padding(Theme.Sp.s16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card))
        .e2()
    }

    // MARK: 48週 行動内訳色帯

    private var breakdownBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("この1年の使い方").font(.maru(.sub)).foregroundStyle(Theme.inkSub)
            ActionBreakdownBand(weeks: session.config.weeks, categoryByWeek: session.categoryLog)
            HStack(spacing: 10) {
                ForEach([BandCategory.keiko, .baito, .kaifuku, .taikai], id: \.label) { cat in
                    HStack(spacing: 4) {
                        Circle().fill(cat.color).frame(width: 7, height: 7)
                        Text(cat.label).font(.maru(.sub)).foregroundStyle(Theme.inkSub)
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
            Text("出来事").font(.maru(.sub)).foregroundStyle(Theme.inkSub)
            if lines.isEmpty {
                Text("——大会は、来年こそ。").font(.maru(.bodyMedium)).foregroundStyle(Theme.inkSub)
            } else {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line).font(.maru(.bodyMedium)).foregroundStyle(Theme.ink)
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
            total("賞金 年計", session.totalPrize, yen: true)
            Divider().frame(height: 30)
            total("知名度", Int(s.fame), yen: false)
            Divider().frame(height: 30)
            total("最終所持金", s.money, yen: true)
        }
        .padding(.vertical, Theme.Sp.s12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card))
        .e1()
    }

    private func total(_ k: String, _ v: Int, yen: Bool) -> some View {
        VStack(spacing: 3) {
            CountUpText(value: v, yen: yen)
                .font(.maru(.title)).foregroundStyle(v < 0 ? Theme.vermD : Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(k).font(.maru(.sub)).foregroundStyle(Theme.inkSub)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 年の締めの独白（voice_corpus yearEnd.* を復元）

    /// 全ランが負けで着地する1年版デモの「年の締め」。書き上げた独白を最後の画面に載せる。
    /// 旧「才能がひとつ灯った」は実体ゼロの常時表示だったため除去（監査 §1-4-①）。
    private var yearEndMonolog: some View {
        Group {
            if let line = yearEndLine() {
                NarrationCard(text: line)
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
        } else if session.careerOver && !o.champion && !o.reachedFinal && s.compat < 10 {
            // 解散年（相性が最後まで低い＝袂を分かつ・統合設計1-α・閾値【仮】）。終わり方の語彙なので、
            // キャリアの区切りの年末だけ（翌年へ続く年末に出すと「最後だった」と矛盾する）
            pool = Self.yeDissolution
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
        // 多年版のみ: "今年は、同じ準決勝の会場に三度立った。…"（準決勝が年1回の1年版では事実と矛盾＝監査D-06）
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
        Button(action: onNextYear ?? onEnding ?? onRestart) {
            Text(onNextYear != nil ? "\(session.year + 1)年目へ ▶" : onEnding != nil ? "勇退エンディングへ ▶" : "もう一度")
                .font(.maru(.body)).foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Theme.verm, in: RoundedRectangle(cornerRadius: Theme.Rad.btn))
                .shadow(color: Theme.vermD, radius: 0, y: 3)
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
        // 監査C-07: 「最後に通過した回戦」ではなく「敗れた回戦」を言う（3回戦で負けた人に「2回戦」と出さない）
        let names = session.config.calendar.gpRoundNames
        let n = o.roundsPassed
        if n < names.count { return (names[n].replacingOccurrences(of: "GP", with: "") + "敗退", n > 0) }
        return ("準決勝敗退", true)
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

// MARK: 数え上げの数字（年に1度の集計を「数える」で見せる・0.8秒・演出ひかえめでは即値）

struct CountUpText: View {
    let value: Int
    var yen: Bool = false
    @State private var shown = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(yen ? "¥\(shown.formatted())" : "\(shown)")
            .monospacedDigit()
            .contentTransition(.numericText())
            .task(id: value) {
                if reduceMotion { shown = value; return }
                try? await Task.sleep(nanoseconds: 500_000_000)   // 判の押印の後から数え始める
                let steps = 20
                for i in 1...steps {
                    try? await Task.sleep(nanoseconds: 40_000_000)
                    withAnimation(.linear(duration: 0.04)) { shown = Int(Double(value) * Double(i) / Double(steps)) }
                }
                shown = value
            }
    }
}
