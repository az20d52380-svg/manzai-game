// NotebookView.swift
// S5 ネタ帳（正本: uiux_vision_reply_part2 §S5）。見開きメタファ（縦持ちはタブで代替）。
// 能力（旧ちから）=1能力1行（等級・値・バー）＋相性（2026-10-12 パワプロ式に作り直し・旧レーダー/器の輪は git 履歴）。
// きろく=大会履歴(判ミニチュア+回戦名)・称号。効果量の事前表示はしない既定を維持（ここは「育ったか」を見る場所）。
// 表示専用（RNG非消費・golden非対象）。育成メインの「データ」から開く。

import SwiftUI
import GameCore

struct NotebookView: View {
    let session: GameSession
    var onClose: () -> Void
    @State private var tab: Tab = NotebookView.initialTab
    /// 型変更ピッカーを開いているネタID（1つだけ開く・トグル）
    @State private var kataPickerFor: Int?
    /// 改名フィールドを開いているネタID
    @State private var renamingID: Int?
    @State private var renameDraft: String = ""
    private enum Tab { case chikara, kiroku, neta }

    private static var initialTab: Tab {
        #if DEBUG
        if ProcessInfo.processInfo.environment["MZ_TAB"] == "kiroku" { return .kiroku }   // 大会の記録の目視（MZ_UI=notebook と併用）
        if ProcessInfo.processInfo.environment["MZ_TAB"] == "neta" || ProcessInfo.processInfo.environment["MZ_UI"] == "neta_list" { return .neta }   // 持ちネタ帳の目視
        #endif
        return .chikara
    }

    private var s: GameState { session.state }

    private static let rule = Color(hex: 0xBFAE8A)
    private var hairline: some View { Rectangle().fill(Theme.sumi.opacity(0.35)).frame(height: 1) }

    private var tabIndex: Binding<Int> {
        Binding(get: { tab == .chikara ? 0 : (tab == .kiroku ? 1 : 2) },
                set: { tab = [Tab.chikara, .kiroku, .neta][$0] })
    }

    var body: some View {
        VStack(spacing: 0) {
            YoseHeaderBar(title: "ネタ帳", subtitle: session.combiName, closeAction: onClose)
            YoseTopTabBar(tabs: ["能力", "戦績", "持ちネタ"], selectedIndex: tabIndex)
                .overlay(alignment: .bottom) { Rectangle().fill(YoseColor.sumi).frame(height: 2) }
            ScrollView {
                Group {
                    switch tab {
                    case .chikara: AnyView(chikaraPage)
                    case .kiroku: AnyView(kirokuPage)
                    case .neta: AnyView(netaPage)
                    }
                }
                .padding(.horizontal, YoseMetrics.screenMargin).padding(.top, 14).padding(.bottom, 24)
            }
        }
        .background(YoseColor.kinari.ignoresSafeArea())
    }

    // MARK: 能力（パワプロの選手情報式・2026-10-12 オーナー「ちから/きろく/ネタも意味わからん」）
    // 1能力1行＝等級・値・次の等級までのバー。レーダーと「成長の器」の輪は外した（器は満ちた時だけ1行で言う）。

    private var chikaraPage: some View {
        let cfg = session.config
        let budget = s.growthBudget ?? 0
        let full = budget > 0 && s.growthUsed >= budget * 0.98
        let exp = AbilityUpView.points(s.expTotal)
        return VStack(spacing: 8) {
            HStack(spacing: 10) {
                YosePowerBadge(power: Int(GameEngine.jitsuryoku(s, config: cfg).rounded()))
                compatBadge
                Spacer(minLength: 0)
            }
            .padding(.bottom, 4)
            if exp > 0 && !cfg.autoPourAllocation {
                HStack {
                    YoseTag(text: "経験点 \(exp) 未使用", style: .outlineShu)
                    Spacer()
                }
            }
            ForEach(Array(Ability.allCases.enumerated()), id: \.element) { _, a in
                abilityRow(a, cap: a == .メンタル ? cfg.mentalCap : cfg.abilityCap)
            }
            if full {
                Text("今年はもう、能力が伸びにくい（年が明けると戻る）。")
                    .font(YoseFont.mincho(13)).foregroundStyle(YoseColor.haiSumi).padding(.top, 6)
            }
        }
    }

    private func abilityRow(_ a: Ability, cap: Double) -> some View {
        let v = s[a]
        let g = Theme.rank(v)
        return HStack(spacing: 10) {
            Text(g).font(YoseFont.gothic(18, weight: .black)).foregroundStyle(YoseColor.kinBright)
                .frame(width: 34, height: 34)
                .background(YoseColor.enji)
                .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 2))
                .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1).padding(-1))
            Text("\(a)").font(YoseFont.gothic(15, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                .frame(width: 64, alignment: .leading).lineLimit(1).minimumScaleFactor(0.8)
            YoseGauge(value: Theme.rankProgress(v, cap: cap), total: 1, fill: YoseColor.shu, height: 12)
            Text("\(Int(v.rounded()))").font(YoseFont.number(20, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                .lineLimit(1).minimumScaleFactor(0.8).fixedSize()
                .frame(width: 48, alignment: .trailing)
        }
        .padding(.horizontal, 10).frame(height: 58)
        .yoseHarigami()
    }

    private var compatBadge: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("相性").font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1))
            Text("\(Int(s.compat.rounded()))").font(YoseFont.number(24, weight: .black)).foregroundStyle(YoseColor.shu)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .yoseKifuda()
    }

    /// 墨の細い帯（角丸なし・1色）
    private func inkBar(_ frac: Double, color: Color, height: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Self.rule.opacity(0.5))
                Rectangle().fill(color).frame(width: geo.size.width * CGFloat(min(1, max(0, frac))))
            }
        }
        .frame(height: height)
        .overlay(Rectangle().stroke(Theme.sumi.opacity(0.5), lineWidth: 0.8))
    }

    // MARK: きろく（大会履歴＋称号）

    private struct LogEntry: Hashable { let week: String; let title: String; let mark: String; let prize: Int }

    private var logEntries: [LogEntry] {
        var out: [LogEntry] = []
        var prev = ""
        for line in session.log where line != prev {
            prev = line
            let mark = (line.contains("優勝") && !line.contains("客席")) ? "優勝"
                : (line.contains("客席") ? "観戦"
                    : (line.contains("通過") ? "通過" : (line.contains("敗退") ? "敗退" : "休")))
            var week = "", body = line
            if let r = line.range(of: ": ") { week = String(line[..<r.lowerBound]); body = String(line[r.upperBound...]) }
            var prize = 0
            var rest = body
            if let re = try? NSRegularExpression(pattern: "\\+(\\d+)万") {
                for m in re.matches(in: body, range: NSRange(body.startIndex..., in: body)) {
                    if let r = Range(m.range(at: 1), in: body) { prize += Int(body[r]) ?? 0 }
                }
                rest = re.stringByReplacingMatches(in: body, range: NSRange(body.startIndex..., in: body), withTemplate: "")
                    .trimmingCharacters(in: .whitespaces)
            }
            out.append(LogEntry(week: week, title: rest, mark: mark, prize: prize))
        }
        return out
    }

    private var kirokuPage: some View {
        let entries = logEntries
        let played = entries.filter { ["通過", "敗退", "優勝"].contains($0.mark) }.count
        let wins = entries.filter { $0.mark == "優勝" }.count + session.yearHistory.filter { $0.champion }.count
        let total = entries.reduce(0) { $0 + $1.prize } + session.yearHistory.reduce(0) { $0 + $1.prize / 10000 }
        return VStack(alignment: .leading, spacing: 10) {
            // 通算戦績（3カラム木札）
            HStack(spacing: 0) {
                kirokuStat("大会出場", "\(played)", "回")
                Rectangle().fill(YoseColor.kiDark).frame(width: 1).padding(.vertical, 8)
                kirokuStat("優勝", "\(wins)", "回")
                Rectangle().fill(YoseColor.kiDark).frame(width: 1).padding(.vertical, 8)
                kirokuStat("獲得賞金", "\(total)", "万")
            }
            .frame(height: 64).frame(maxWidth: .infinity).yoseKifuda()
            .padding(.bottom, 2)
            // これまでの年（出来事ログは年ごとに消えるので、2年目以降は前の年が見えなかった）。年の記録＝yearHistory
            if !session.yearHistory.isEmpty {
                Text("これまでの頂グランプリ").font(YoseFont.sectionTitle).foregroundStyle(YoseColor.sumi)
                ForEach(session.yearHistory, id: \.year) { r in
                    let win = r.champion
                    HStack(spacing: 10) {
                        Text("\(r.year)年目").font(YoseFont.number(13)).foregroundStyle(YoseColor.haiSumi)
                            .frame(width: 52, alignment: .leading)
                        Text(YearResultView.reachLabel(r, names: session.config.calendar.gpRoundNames))
                            .font(YoseFont.gothic(15, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if r.prize > 0 {
                            Text("+\(Yen.man(r.prize))").font(YoseFont.number(15)).foregroundStyle(YoseColor.shu)
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .yoseHarigami(isFeatured: win || r.reachedFinal)
                }
            }
            Text(session.yearHistory.isEmpty ? "大会の記録" : "今年の大会")
                .font(YoseFont.sectionTitle).foregroundStyle(YoseColor.sumi)
            if entries.isEmpty {
                Text("――まだ、舞台の記録はない。").font(YoseFont.mincho(14)).foregroundStyle(YoseColor.haiSumi)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(entries.enumerated()), id: \.offset) { _, e in
                    HStack(spacing: 10) {
                        Text(e.week.replacingOccurrences(of: "第", with: "").replacingOccurrences(of: "週", with: "週"))
                            .font(YoseFont.number(13)).foregroundStyle(YoseColor.haiSumi)
                            .frame(width: 44, alignment: .leading)
                        Rectangle().fill(YoseColor.kiDark).frame(width: 1.5, height: 24)
                        Text(e.title).font(YoseFont.gothic(14, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if e.prize > 0 {
                            Text("+¥\(e.prize)万").font(YoseFont.number(13)).foregroundStyle(YoseColor.shu)
                        }
                        kirokuMark(e.mark).frame(minWidth: 46)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .yoseHarigami(isFeatured: e.mark == "優勝")
                }
            }
            // 称号は周回メタ（未実装）の器＝実体が入るまで出さない（監査G-02: 【仮】の空欄を出荷画面に残さない）
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func kirokuStat(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(YoseFont.captionBold).foregroundStyle(YoseColor.haiSumi)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(YoseFont.numLarge).foregroundStyle(YoseColor.sumi)
                Text(unit).font(YoseFont.captionBold).foregroundStyle(YoseColor.haiSumi)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private func kirokuMark(_ mark: String) -> some View {
        switch mark {
        case "優勝": YoseHankoStamp(text: "優勝", angle: -4)
        case "通過": YoseTag(text: "通過", style: .solidEnji)
        case "敗退": YoseTag(text: "敗退", style: .outlineSumi)
        default: YoseTag(text: mark, style: .outlineSumi)
        }
    }

    // MARK: ネタ（持ちネタ帳・正典: docs/neta_system_redesign_v2.md §5-3。表示専用＋純適用のみ・golden非対象）

    private var netaPage: some View {
        VStack(alignment: .leading, spacing: Theme.Sp.s16) {
            activeNetaSection
            if !session.archivedNetas.isEmpty { archivedNetaSection }
        }
    }

    private func sectionTitle(_ s: String, trailing: String? = nil) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(s).font(.maru(20, weight: .black)).foregroundStyle(Theme.sumi)
                    .shadow(color: Theme.gold.opacity(0.8), radius: 0, x: 1, y: 1)
                Spacer()
                if let trailing { Text(trailing).font(.maru(13, weight: .bold)).monospacedDigit().foregroundStyle(Theme.curtain) }
            }
            Rectangle().fill(Theme.sumi).frame(height: 2)
            Rectangle().fill(Theme.sumi.opacity(0.5)).frame(height: 0.8)
        }
    }

    private var activeNetaSection: some View {
        VStack(alignment: .leading, spacing: Theme.Sp.s12) {
            sectionTitle("持ちネタ", trailing: "\(session.activeNetas.count) / \(session.config.netaActiveSlots)")
            if session.activeNetas.isEmpty {
                Text("まだネタがない。「ネタを書く」から書こう。")
                    .font(.system(size: 13, design: .serif)).foregroundStyle(Theme.inkDim)
                    .padding(.vertical, Theme.Sp.s8)
            } else {
                ForEach(session.activeNetas) { neta in
                    netaCard(neta).padding(.bottom, 4)
                }
            }
        }
    }

    private var archivedNetaSection: some View {
        VStack(alignment: .leading, spacing: Theme.Sp.s12) {
            sectionTitle("しまったネタ")
            Text("いつでも出せる。前のネタが、また使えることもある。")
                .font(.system(size: 12, design: .serif)).foregroundStyle(Theme.inkSub)
            ForEach(session.archivedNetas) { neta in
                archivedRow(neta)
            }
        }
    }

    // MARK: アクティブなネタ1枚（型・名前・バッジ・完成度/手応え・尺・操作）

    private func netaCard(_ neta: Neta) -> some View {
        let isSelected = session.selectedNeta?.id == neta.id
        return VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center, spacing: 8) {
                nameLabel(neta)
                Spacer(minLength: 4)
                if isSelected {
                    YoseHankoStamp(text: "真剣勝負")
                        .modifier(StampShake())
                }
                if renamingID != neta.id {
                    YoseTag(text: "改名", style: .outlineSumi)   // 名前タップと同じ＝題名を直す入口を札で示す
                        .onTapGesture { renameDraft = neta.name; renamingID = neta.id }
                }
            }
            YoseTag(text: NetaCatalog.displayName(neta.kata), style: .solidEnji)
            netaBar(label: "完成度", value: neta.polish, color: YoseColor.shu)
            netaBar(label: "客の反応", value: neta.buzz, color: YoseColor.kinBright)
            oroshiLine(neta)
            HStack(spacing: 8) {
                Text("舞台 \(neta.stageCount)回").font(YoseFont.gothic(11, weight: .bold)).monospacedDigit().foregroundStyle(YoseColor.haiSumi)
                if !neta.lengthFit.isEmpty {
                    YoseTag(text: neta.lengthFit.map { NetaCatalog.displayName($0) }.joined(separator: " / "), style: .outlineSumi)   // 尺タグは1つの角札に統合
                        .lineLimit(1)
                }
                Spacer()
                netaBadges(neta)
            }
            if kataPickerFor == neta.id { kataPicker(neta) }
            HStack(spacing: 8) {
                if isSelected {
                    EmptyView()   // 勝負ネタ状態は右上の「真剣勝負」印だけで伝える
                } else {
                    actionChip("勝負ネタにする", active: true, primary: true) {
                        session.selectNeta(neta.id)
                    }
                }
                actionChip("型を変える", active: true) {
                    withAnimation(Theme.Motion.appearQuick) {
                        kataPickerFor = kataPickerFor == neta.id ? nil : neta.id
                    }
                }
                actionChip("しまう", active: true) {
                    withAnimation(Theme.Motion.exit) { session.retireNeta(neta.id) }
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .yoseHarigami(isFeatured: isSelected)
    }

    /// ネタおろし（初披露）直後だけの一言（v2 §3-2補2・行動すると失効＝justPassedと同型）
    @ViewBuilder private func oroshiLine(_ neta: Neta) -> some View {
        if session.justOroshiNeta?.id == neta.id, let text = session.justOroshiNeta?.text {
            Text(text).font(.system(size: 11.5, design: .serif)).foregroundStyle(Theme.inkDim)
                .transition(.opacity)
        }
    }

    /// 名前（タップで改名フィールドへ）
    @ViewBuilder private func nameLabel(_ neta: Neta) -> some View {
        if renamingID == neta.id {
            HStack(spacing: 6) {
                TextField("題材名", text: $renameDraft)
                    .onChange(of: renameDraft) { _, v in if v.count > 16 { renameDraft = String(v.prefix(16)) } }   // 新しく書く時の題名と同じ上限（長い名前で題名の行が崩れる）
                    .font(YoseFont.mincho(18)).foregroundStyle(YoseColor.sumi)
                    .textFieldStyle(.plain)
                    .onSubmit { commitRename(neta.id) }
                Button { commitRename(neta.id) } label: {
                    Image(systemName: "checkmark.square.fill").foregroundStyle(YoseColor.shu)
                }.buttonStyle(PressableStyle())
            }
        } else {
            Button {
                renameDraft = neta.name
                renamingID = neta.id
            } label: {
                HStack(spacing: 4) {
                    Text(neta.name).font(YoseFont.netaTitle).foregroundStyle(YoseColor.sumi).lineLimit(1)
                }
            }.buttonStyle(.plain)
        }
    }

    private func commitRename(_ id: Int) {
        session.renameNeta(id, to: renameDraft)
        renamingID = nil
    }

    /// バッジ: おろし前（点線）／鉄板（金）
    @ViewBuilder private func netaBadges(_ neta: Neta) -> some View {
        HStack(spacing: 4) {
            NetaTiredBadge(neta: neta)
            if !neta.isDown {
                YoseTag(text: "まだ人前でやっていない", style: .outlineSumi)
                    .lineLimit(1).fixedSize()   // 2行に折れて窮屈だった
            }
            if neta.isTeppan(config: session.config) {
                YoseTag(text: "自信作", style: .outlineKin)
            }
        }
    }

    /// 完成度/手応えバー（0..100・数値併記）
    private func netaBar(label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label).font(YoseFont.captionBold).foregroundStyle(YoseColor.haiSumi).frame(width: 60, alignment: .leading)
            YoseGauge(value: value, total: 100, fill: color, height: 14)
            Text("\(Int(value.rounded()))").font(YoseFont.numLarge)
                .foregroundStyle(YoseColor.sumi)
                .frame(width: 40, alignment: .trailing)
        }
    }

    /// 型ピッカー（7型の色ドット・現在の型は金フチ）
    private func kataPicker(_ neta: Neta) -> some View {
        HStack(spacing: 8) {
            ForEach(NetaKata.allCases, id: \.self) { k in
                Button {
                    session.changeNetaKata(neta.id, to: k)
                    withAnimation(Theme.Motion.appearQuick) { kataPickerFor = nil }
                } label: {
                    Rectangle().fill(Theme.kataColor(k)).frame(width: 22, height: 22)
                        .overlay(Rectangle().stroke(k == neta.kata ? YoseColor.kinBright : YoseColor.sumi, lineWidth: k == neta.kata ? 3 : 1.5))
                }.buttonStyle(PressableStyle())
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .transition(.opacity)
    }

    private func actionChip(_ label: String, active: Bool, primary: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Text(label).font(YoseFont.gothic(primary ? 15 : 13, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.85)
        }
        .buttonStyle(YoseButtonStyle(primary ? .primary : .secondary))
        .frame(width: primary ? 132 : 92)
        .disabled(!active)
    }

    // MARK: 保管庫の1行（呼び戻すだけの軽量表示）

    @ViewBuilder private func archivedRow(_ neta: Neta) -> some View {
        let revival = neta.isRevival(currentYear: session.year, config: session.config)
        let slotsFull = session.activeNetas.count >= session.config.netaActiveSlots
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(neta.name).font(.maru(15, weight: .black)).foregroundStyle(Theme.sumi)
                HStack(spacing: 6) {
                    Text(NetaCatalog.displayName(neta.kata)).font(.maru(11)).foregroundStyle(Theme.inkSub)
                    if revival {
                        Text("もう一度").font(.maru(11, weight: .black)).foregroundStyle(Theme.verm)
                    }
                }
            }
            Spacer()
            actionChip("出す", active: !slotsFull) {
                withAnimation(Theme.Motion.appear) { session.recallNeta(neta.id) }
            }
        }
        .padding(.vertical, 6)
        hairline
    }
}


/// 判子の押印：表示時に「ドンッ」と一度だけ震える（Haptics 連動は呼び出し元の操作側）。
struct StampShake: ViewModifier {
    @State private var t: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .modifier(ShakeEffect(travel: 3, animatableData: t))
            .onAppear { withAnimation(.linear(duration: 0.3)) { t = 1 } }
    }
}
