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
        VStack(spacing: 0) {
            YoseHeaderBar(title: "\(session.year)年目 年末総決算", subtitle: session.combiName)
            ScrollView {
                // 最初の1画面＝判＋等級の段（1年で何がどれだけ育ったか・G5）。レーダーや内訳は下へ
                VStack(spacing: 12) {
                    reachStamp.stagger(1, appear)
                    gradeLadder.stagger(2, appear)
                    totalsBlock.stagger(3, appear)
                    historyBlock.stagger(3, appear)
                    eventsBlock.stagger(4, appear)
                    yearEndMonolog.stagger(5, appear)
                    breakdownBlock.stagger(7, appear)
                    radarBlock.stagger(8, appear)
                }
                .padding(.horizontal, YoseMetrics.screenMargin).padding(.vertical, 14)
                .frame(maxWidth: .infinity)
            }
            // 押せるボタンは画面下に固定（スクロールの末尾に埋もれさせない）
            restartButton.stagger(6, appear)
                .padding(.horizontal, YoseMetrics.screenMargin).padding(.top, 8).padding(.bottom, 6)
                .background(YoseColor.kinari)
                .overlay(alignment: .top) { Rectangle().fill(YoseColor.sumi).frame(height: 2) }
        }
        .background(YoseColor.kinari.ignoresSafeArea())
        .overlay {
            // 優勝の年だけ、判と同時に金の紙吹雪（年に1度の祝い）
            ParticleBurst(trigger: confettiFire, colors: [YoseColor.kinBright, YoseColor.shu, YoseColor.washi, YoseColor.kin],
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

    private func abilityColor(_ a: Ability) -> Color {
        switch a {
        case .センス: return YoseColor.expGo
        case .発想: return YoseColor.expSen
        case .表現: return YoseColor.expMa
        case .華: return YoseColor.expSon
        case .メンタル: return YoseColor.expTan
        }
    }

    /// 木札の見出し（黒漆に消金）
    private func sectionLabel(_ t: String) -> some View {
        Text(t).font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.kin)
            .padding(.horizontal, 10).frame(height: 24)
            .background(YoseColor.kuroUrushi)
    }

    // MARK: 等級の段（4月→いま・G5）

    /// 5能力の 4月の等級 → いまの等級 と、次の等級までの進み。上がった能力は金の縁と「↑」。等級は表示写像だけ（Theme.rank）
    private var gradeLadder: some View {
        let base = session.yearStartState
        let order: [Ability] = [.センス, .発想, .表現, .華, .メンタル]
        return VStack(alignment: .leading, spacing: 8) {
            sectionLabel("この1年で育ったもの")
            ForEach(order, id: \.self) { a in
                let from = Theme.rank(base[a]), to = Theme.rank(s[a])
                let up = from != to
                let cap = a == .メンタル ? session.config.mentalCap : session.config.abilityCap
                HStack(spacing: 8) {
                    Text(String("\(a)".prefix(1))).font(YoseFont.gothic(11, weight: .heavy)).foregroundStyle(.white)
                        .frame(width: 18, height: 18).background(abilityColor(a))
                    Text("\(a)").font(YoseFont.gothic(13, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                        .frame(width: 54, alignment: .leading).lineLimit(1).minimumScaleFactor(0.7)
                    gradeChip(from, dim: true)
                    Image(systemName: "arrowtriangle.right.fill").font(.system(size: 9)).foregroundStyle(YoseColor.shu)
                    gradeChip(to, dim: false)
                    YoseGauge(value: Theme.rankProgress(s[a], cap: cap), total: 1, fill: abilityColor(a), height: 12)
                    Text(up ? "↑" : " ").font(YoseFont.gothic(14, weight: .black)).foregroundStyle(YoseColor.shu).frame(width: 14)
                }
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(up ? YoseColor.kinBright.opacity(0.16) : Color.clear)
                .overlay(Rectangle().stroke(up ? YoseColor.kin : Color.clear, lineWidth: 1.5))
            }
        }
        .padding(.horizontal, YoseMetrics.padH).padding(.vertical, YoseMetrics.padV)
        .frame(maxWidth: .infinity, alignment: .leading)
        .yoseHarigami()
        .padding(.bottom, 2)
    }

    /// 等級の角章（開始時は薄く・いまは濃く。Sだけ消金の地）
    private func gradeChip(_ g: String, dim: Bool) -> some View {
        Text(g).font(YoseFont.gothic(15, weight: .black))
            .foregroundStyle(g == "S" ? YoseColor.sumi : (dim ? YoseColor.haiSumi : YoseColor.kinari))
            .frame(width: 28, height: 24)
            .background(g == "S" ? YoseColor.kin : (dim ? YoseColor.ginNezu : YoseColor.enji))
            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
    }

    // MARK: これまで（1年＝1行・2年目以降だけ）

    /// 結成からの頂グランプリの到達を1年1行で並べる（何年もかけて登っていく手応え・表示専用）
    @ViewBuilder private var historyBlock: some View {
        if session.yearHistory.count >= 2 {
            VStack(alignment: .leading, spacing: 6) {
                sectionLabel("これまでの頂グランプリ")
                ForEach(session.yearHistory, id: \.year) { r in
                    let label = Self.reachLabel(r, names: session.config.calendar.gpRoundNames)
                    HStack(spacing: 10) {
                        Text("\(r.year)年目").font(YoseFont.number(13, weight: .heavy)).foregroundStyle(YoseColor.haiSumi)
                            .frame(width: 52, alignment: .leading)
                        Text(label).font(YoseFont.mincho(15)).foregroundStyle(r.champion || r.reachedFinal ? YoseColor.shu : YoseColor.sumi)
                        Spacer()
                        if r.year == session.year { YoseTag(text: "今年", style: .solidEnji) }
                    }
                }
            }
            .padding(.horizontal, YoseMetrics.padH).padding(.vertical, YoseMetrics.padV)
            .frame(maxWidth: .infinity, alignment: .leading)
            .yoseHarigami()
            .padding(.bottom, 2)
        }
    }

    /// 1年の到達の短い呼び名（年表・これまで共用）。敗れた回戦を言う（監査C-07 と同じ規則）
    static func reachLabel(_ r: GameSession.YearRecord, names: [String]) -> String {
        if r.champion { return "優勝" }
        if r.bankrupt { return "夜逃げ" }
        if r.reachedFinal { return "決勝" }
        if r.enteredGP == false { return "不出場" }
        if r.roundsPassed < names.count { return names[r.roundsPassed].replacingOccurrences(of: "GP", with: "") + "敗退" }
        return "準決勝敗退"
    }

    // MARK: 到達段階の額縁（左に朱印・右に到達の説明）

    private var reachStamp: some View {
        let (text, passed) = reach()
        return HStack(spacing: 14) {
            YoseHankoStamp(text: text, isSquare: true, angle: -4).scaleEffect(1.25)
                .padding(.leading, 14).padding(.trailing, 4)
                .scaleEffect(stampIn ? 1 : 1.6).opacity(stampIn ? 1 : 0)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(session.year)年目 ・ 年次リザルト").font(YoseFont.gothic(11, weight: .heavy))
                    .foregroundStyle(passed ? YoseColor.kin : YoseColor.ginNezu)
                Text(reachSub()).font(YoseFont.mincho(17)).foregroundStyle(YoseColor.kinari)
                    .lineLimit(2).minimumScaleFactor(0.7).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 18).padding(.trailing, 12)
        .frame(maxWidth: .infinity)
        .background(YoseColor.kuroUrushi)
        .overlay(Rectangle().stroke(passed ? YoseColor.kin : YoseColor.haiSumi, lineWidth: 3))
        .overlay(Rectangle().stroke(passed ? YoseColor.shu : YoseColor.sumi, lineWidth: 1.5).padding(6))
        .background(alignment: .bottom) { Rectangle().fill(YoseColor.sumi).offset(y: 4) }
        .padding(.bottom, 4)
    }

    // MARK: レーダー重ね

    private var radarBlock: some View {
        VStack(spacing: 4) {
            sectionLabel("年初と現在").frame(maxWidth: .infinity, alignment: .leading)
            RadarChart(axes: RadarChart.abilityAxes(current: s, base: session.yearStartState, config: session.config))
                .frame(height: 210)
            HStack(spacing: 12) {
                legendDot(YoseColor.haiSumi, "年初", dashed: true)
                legendDot(YoseColor.shu, "現在", dashed: false)
            }
            .font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
        }
        .padding(.horizontal, YoseMetrics.padH).padding(.vertical, YoseMetrics.padV)
        .yoseHarigami()
        .padding(.bottom, 2)
    }

    // MARK: 48週 行動内訳色帯

    private var breakdownBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("この1年の使い方")
            ActionBreakdownBand(weeks: session.config.weeks, categoryByWeek: session.categoryLog)
            HStack(spacing: 10) {
                ForEach([BandCategory.keiko, .baito, .kaifuku, .taikai], id: \.label) { cat in
                    HStack(spacing: 4) {
                        Rectangle().fill(cat.color).frame(width: 8, height: 8)
                        Text(cat.label).font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
                    }
                }
            }
        }
        .padding(.horizontal, YoseMetrics.padH).padding(.vertical, YoseMetrics.padV)
        .frame(maxWidth: .infinity, alignment: .leading)
        .yoseHarigami()
        .padding(.bottom, 2)
    }

    // MARK: 出来事3行（大会結果のみ）

    private var eventsBlock: some View {
        let lines = Array(session.log.suffix(3))
        return VStack(alignment: .leading, spacing: 6) {
            sectionLabel("出来事")
            if lines.isEmpty {
                Text("今年は、大会に出なかった。").font(YoseFont.mincho(14)).foregroundStyle(YoseColor.haiSumi)
            } else {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    // 「第43週: GP準々決勝 通過」→ 左に黒漆の週札・右に本文（文言は変えない）
                    if let r = line.range(of: ": ") ?? line.range(of: "：", options: []), line.hasPrefix("第"), line[..<r.lowerBound].hasSuffix("週") {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(String(line[..<r.lowerBound])).font(YoseFont.gothic(11, weight: .heavy)).foregroundStyle(YoseColor.kin)
                                .padding(.horizontal, 6).padding(.vertical, 2).frame(minWidth: 48)
                                .background(YoseColor.kuroUrushi)
                            Text(String(line[r.upperBound...])).font(YoseFont.mincho(14)).lineSpacing(3).foregroundStyle(YoseColor.sumi)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                    } else {
                        Text(line).font(YoseFont.mincho(14)).lineSpacing(3).foregroundStyle(YoseColor.sumi)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, YoseMetrics.padH).padding(.vertical, YoseMetrics.padV)
        .yoseHarigami()
        .padding(.bottom, 2)
    }

    // MARK: 賞金/知名度 年計

    private var totalsBlock: some View {
        HStack(spacing: 8) {
            total("今年の賞金", session.totalPrize, yen: true)
            total("知名度", Int(s.fame.rounded()), yen: false, delta: Int(s.fame.rounded()) - Int(session.yearStartState.fame.rounded()))
            total("最終所持金", s.money, yen: true)
        }
        .padding(.bottom, 2)
    }

    private func total(_ k: String, _ v: Int, yen: Bool, delta: Int? = nil) -> some View {
        VStack(spacing: 3) {
            Text(k).font(YoseFont.gothic(11, weight: .heavy)).foregroundStyle(YoseColor.enji)
            CountUpText(value: v, yen: yen)
                .font(YoseFont.numMedium).foregroundStyle(v < 0 ? YoseColor.shu : YoseColor.sumi)
                .lineLimit(1).minimumScaleFactor(0.6)
            if let delta, delta > 0 {
                Text("↑+\(delta)").font(YoseFont.number(12, weight: .heavy)).foregroundStyle(YoseColor.shu)
            } else {
                Text(" ").font(YoseFont.number(12, weight: .heavy))
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .yoseKifuda()
    }

    // MARK: 年の締めの独白（voice_corpus yearEnd.* を復元）

    /// 全ランが負けで着地する1年版デモの「年の締め」。書き上げた独白を最後の画面に載せる。
    /// 旧「才能がひとつ灯った」は実体ゼロの常時表示だったため除去（監査 §1-4-①）。
    private var yearEndMonolog: some View {
        Group {
            if let line = yearEndLine() {
                YoseNarration(text: line)
            }
        }
    }

    /// 年の締めの独白を1行返す。到達結果で 躍進/停滞/貧乏 に決定的分岐（RNG非消費＝golden不変）。
    /// オーナー決定 2026-07-06：else（決勝未到達・非破産）を fame/roundsPassed で二分。閾値は【仮】——sim到達分布で後日確定。
    private func yearEndLine() -> String? {
        guard let o else { return nil }
        var pool: [String]
        var scene = "yearEnd"
        if o.bankrupt {
            scene += ".bankrupt"; pool = Self.yeBankrupt                                               // 貧乏年
        } else if session.careerOver && !o.champion && !o.reachedFinal && s.compat < 10 {
            // 解散年（相性が最後まで低い＝袂を分かつ・統合設計1-α・閾値【仮】）。終わり方の語彙なので、
            // キャリアの区切りの年末だけ（翌年へ続く年末に出すと「最後だった」と矛盾する）
            scene += ".dissolution"; pool = Self.yeDissolution
        } else if o.champion || o.reachedFinal || o.roundsPassed >= 3 || Int(s.fame) >= 30 {
            scene += ".leap"; pool = Self.yeLeap                                                    // 躍進年
        } else {
            scene += ".stall"; pool = Self.yeStall                                                  // 停滞年
        }
        // 1年目には「去年」「今年も」が無い（不具合 2026-10-12）。前年を前提にする行を外し、1年目用の行を足す。
        if session.year <= 1 {
            if pool == Self.yeStall { pool = Self.yeFirstStall; scene += ".first" }
            else if pool == Self.yeLeap { pool = pool.filter { !$0.contains("去年") } + Self.yeFirstLeap; scene += ".first" }
        }
        let salt = Int(s.fame) &+ o.roundsPassed &+ session.year                 // 状態から決定的（乱数非消費）
        // 直近の年に出した行は避ける（同じ年の再描画は同じ行＝key=年）
        return DialogueData.choose(pool, salt: salt, scene: scene, picker: session.picker(key: session.year))
    }

    // yearEnd.* 逐語（voice_corpus_v0 §4-3＋§8・calibration 0be8a11）。独白(俺)・標準語。相方固有名を含む行は除外。
    private static let yeLeap = [   // 躍進年
        "去年より、ずっと忙しい一年だった。たまには実家に顔を出そう。",
        "電車で、知らない人に声をかけられた。少し、身なりに気をつけよう。",
        "後輩に挨拶されることが増えた。今度、飯でもおごってやろう。",
        "今年は、移動の多い一年だった。靴を新しくしよう。",
        "今年は、大会で顔見知りが増えた。会ったら、こちらから挨拶しよう。",
        "バイト先の人たちが、大会を気にかけてくれた。年明けに、何か持っていこう。",
        "手帳が、予定で埋まった一年だった。新しい手帳を買いに行こう。",
    ]
    private static let yeStall = [  // 停滞年
        "今年は、思ったほど勝ち進めなかった。谷口が落ち込んでないか心配だ。",
        // 多年版のみ: "今年は、同じ準決勝の会場に三度立った。…"（準決勝が年1回の1年版では事実と矛盾＝監査D-06）
        "バイトと稽古だけで、一年が終わった。明日は一日、何もしないで休もう。",
        "今年は、予選で落ちる日が多かった。落ちた大会の名前を、手帳に書き出しておこう。",
        "一年、財布の中身ばかり数えていた。年が明けたら、家計簿をつけよう。",
        "谷口と、ちゃんと話す時間が少なかった。年が明けたら、飯に誘おう。",
        "大会の帰りの電車に、何度も乗った一年だった。今夜は早く寝よう。",
    ]
    private static let yeFirstLeap = [   // 躍進年（1年目）
        "一年目で、ここまで来るとは思わなかった。谷口に、ちゃんと礼を言おう。",
    ]
    private static let yeFirstStall = [  // 停滞年（1年目）
        "最初の一年が終わった。春からのことを、谷口と相談しよう。",
        "一年目は悔しい。来年は稽古を増やそう。",
    ]
    private static let yeBankrupt = [  // 貧乏年
        "家賃が、もう払えない。今夜のうちに荷物をまとめよう。",
        "バイトを増やしても、生活費が足りなかった。谷口には、自分の口で話そう。",
        "大会の参加費も、もう出せない。親に電話して、実家に帰ろう。",
    ]
    private static let yeDissolution = [  // 解散年（相性が最後まで低い＝袂を分かつ）＝終わり方の語彙（統合設計§1-2・drama-voice採点済A○/B3○）
        "谷口とのコンビは、解散することにした。\n明日、二人で事務所に話しに行く。",
    ]

    private var restartButton: some View {
        Button(action: onNextYear ?? onEnding ?? onRestart) {
            Text(onNextYear != nil ? "\(session.year + 1)年目へ ▶" : onEnding != nil ? "勇退エンディングへ ▶" : "もう一度")
        }
        .buttonStyle(YoseButtonStyle(.primary))
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
        if notEnteredGP { return ("不出場", false) }
        if n < names.count { return (names[n].replacingOccurrences(of: "GP", with: "") + "敗退", n > 0) }
        return ("準決勝敗退", true)
    }

    private func reachSub() -> String {
        guard let o else { return "" }
        if o.champion { return "頂グランプリ制覇" }
        if o.bankrupt { return "所持金が尽きてキャリア終了" }
        if o.reachedFinal { return "決勝の舞台に立った" }
        if notEnteredGP { return "エントリー費が払えず、頂グランプリに出られなかった" }
        return "頂グランプリ 到達段階"
    }

    /// GPに一度も出ていない年か（エントリー費が払えない＝WeekRunner の gpAlive=false）。出ていないのに「1回戦敗退」と出ていた。
    /// その年の出来事ログ（年ごとにリセット）に1回戦の行が無く、1回戦も通っていない時だけ true。表示専用
    private var notEnteredGP: Bool {
        guard let o, o.roundsPassed == 0, let first = session.config.calendar.gpRoundNames.first else { return false }
        return !session.log.contains { $0.contains(first) }
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
        Text(yen ? Yen.text(shown) : "\(shown)")
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
