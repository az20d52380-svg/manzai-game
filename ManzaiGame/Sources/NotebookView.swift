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
        if ProcessInfo.processInfo.environment["MZ_TAB"] == "neta" { return .neta }   // 持ちネタ帳の目視
        #endif
        return .chikara
    }

    private var s: GameState { session.state }

    // 試作q70: 帳面の紙（生成り＋罫線＋左の赤い余白線）。色は週画面試作と同じ 墨・生成り・朱＋臙脂/金。
    private static let paper = Theme.kinari
    private static let rule = Color(hex: 0xBFAE8A)

    private var paperBackground: some View {
        Canvas { ctx, size in
            var y: CGFloat = 8
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(Self.rule.opacity(0.55)))
                y += 30
            }
            ctx.fill(Path(CGRect(x: 30, y: 0, width: 1.5, height: size.height)), with: .color(Theme.verm.opacity(0.45)))
            ctx.fill(Path(CGRect(x: 34, y: 0, width: 0.8, height: size.height)), with: .color(Theme.verm.opacity(0.3)))
        }
        .background(Self.paper)
        .ignoresSafeArea()
    }

    private var hairline: some View { Rectangle().fill(Theme.sumi.opacity(0.35)).frame(height: 1) }

    var body: some View {
        ZStack {
            paperBackground
            VStack(spacing: 0) {
                header
                tabBar
                ScrollView {
                    Group {
                        switch tab {
                        case .chikara: AnyView(chikaraPage)
                        case .kiroku: AnyView(kirokuPage)
                        case .neta: AnyView(netaPage)
                        }
                    }
                    .padding(.leading, 44).padding(.trailing, Theme.Sp.s16).padding(.top, 14).padding(.bottom, Theme.Sp.s24)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("ネタ帳").font(.maru(24, weight: .black)).foregroundStyle(Theme.gold)
                .shadow(color: .black.opacity(0.5), radius: 0, x: 1, y: 1)
            Text(session.combiName).font(.maru(12, weight: .bold)).foregroundStyle(Theme.gold.opacity(0.8))
            Spacer()
            Button(action: onClose) {
                Text("とじる").font(.maru(13, weight: .black)).foregroundStyle(Theme.gold)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .overlay(Rectangle().stroke(Theme.gold, lineWidth: 1.2))
            }.buttonStyle(PressableStyle())
        }
        .padding(.horizontal, Theme.Sp.s16).padding(.vertical, 10)
        .background(Theme.curtain.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.gold).frame(height: 2) }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton("能力", .chikara)
            tabButton("戦績", .kiroku)
            tabButton("持ちネタ", .neta)
        }
        .padding(.leading, 34).padding(.trailing, Theme.Sp.s16).padding(.top, 8)
        .overlay(alignment: .bottom) { hairline }
    }

    private func tabButton(_ label: String, _ t: Tab) -> some View {
        Button { withAnimation(Theme.Motion.appearQuick) { tab = t } } label: {
            Text(label).font(.maru(16, weight: .black)).foregroundStyle(tab == t ? Theme.sumi : Theme.inkSub)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(tab == t ? Theme.verm : .clear).frame(height: 4)
                }
        }.buttonStyle(.plain)
    }

    // MARK: 能力（パワプロの選手情報式・2026-10-12 オーナー「ちから/きろく/ネタも意味わからん」）
    // 1能力1行＝等級・値・次の等級までのバー。レーダーと「成長の器」の輪は外した（器は満ちた時だけ1行で言う）。

    private var chikaraPage: some View {
        let cfg = session.config
        let budget = s.growthBudget ?? 0
        let full = budget > 0 && s.growthUsed >= budget * 0.98
        let exp = AbilityUpView.points(s.expTotal)
        return VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("実力").font(.maru(16, weight: .black)).foregroundStyle(Theme.sumi)
                Text("\(Int(GameEngine.jitsuryoku(s, config: cfg).rounded()))").font(.maru(34, weight: .black))
                    .monospacedDigit().foregroundStyle(Theme.curtain)
                    .shadow(color: Theme.gold, radius: 0, x: 1, y: 1)
                Spacer()
                if exp > 0 && !cfg.autoPourAllocation {
                    Text("経験点 \(exp) 未使用").font(.maru(12, weight: .bold)).foregroundStyle(Theme.vermD)
                }
            }
            .padding(.vertical, 8)
            hairline
            ForEach(Array(Ability.allCases.enumerated()), id: \.element) { i, a in
                abilityRow(a, cap: a == .メンタル ? cfg.mentalCap : cfg.abilityCap)
                hairline.opacity(0.5)
            }
            compatRow
            hairline
            if full {
                Text("今年はもう、能力が伸びにくい（年が明けると戻る）。")
                    .font(.maru(12)).foregroundStyle(Theme.inkSub).padding(.top, 10)
            }
        }
    }

    private func abilityRow(_ a: Ability, cap: Double) -> some View {
        let v = s[a]
        let g = Theme.rank(v)
        return HStack(spacing: 10) {
            Text(g).font(.maru(20, weight: .black)).foregroundStyle(Theme.curtain)
                .frame(width: 34, height: 34)
                .overlay(Rectangle().stroke(Theme.curtain, lineWidth: 1.5))
            Text("\(a)").font(.maru(16, weight: .black)).foregroundStyle(Theme.sumi).frame(width: 74, alignment: .leading)
            inkBar(Theme.rankProgress(v, cap: cap), color: Theme.curtainLit, height: 7)
            Text("\(Int(v.rounded()))").font(.maru(20, weight: .black)).monospacedDigit().foregroundStyle(Theme.sumi)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.vertical, 9)
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

    private var compatRow: some View {
        let cap = session.config.compatCap
        return HStack(spacing: 10) {
            Text("相").font(.maru(20, weight: .black)).foregroundStyle(Theme.verm)
                .frame(width: 34, height: 34)
                .overlay(Rectangle().stroke(Theme.verm, lineWidth: 1.5))
            Text("相性").font(.maru(16, weight: .black)).foregroundStyle(Theme.sumi).frame(width: 74, alignment: .leading)
            inkBar(s.compat / cap, color: Theme.verm, height: 7)
            Text("\(Int(s.compat.rounded()))").font(.maru(20, weight: .black)).monospacedDigit().foregroundStyle(Theme.sumi)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.vertical, 9)
    }

    // MARK: きろく（大会履歴＋称号）

    private var kirokuPage: some View {
        VStack(alignment: .leading, spacing: Theme.Sp.s12) {
            // これまでの年（出来事ログは年ごとに消えるので、2年目以降は前の年が見えなかった）。年の記録＝yearHistory
            if !session.yearHistory.isEmpty {
                Text("これまでの頂グランプリ").font(.maru(12)).foregroundStyle(Theme.inkDim)
                ForEach(session.yearHistory, id: \.year) { r in
                    HStack(spacing: 10) {
                        Text("\(r.year)年目").font(.maru(12)).monospacedDigit().foregroundStyle(Theme.inkSub)
                            .frame(width: 44, alignment: .leading)
                        Text(YearResultView.reachLabel(r, names: session.config.calendar.gpRoundNames))
                            .font(.maru(13, weight: .bold))
                            .foregroundStyle(r.champion || r.reachedFinal ? Theme.goldDeep : Theme.ink)
                        Spacer()
                        if r.prize > 0 {
                            Text("賞金 \(Yen.man(r.prize))").font(.maru(11)).foregroundStyle(Theme.moneyDeep)
                        }
                    }
                    .padding(.vertical, 2)
                }
                Divider().padding(.vertical, 4)
            }
            Text(session.yearHistory.isEmpty ? "大会の記録" : "今年の大会").font(.maru(12)).foregroundStyle(Theme.inkDim)
            if session.log.isEmpty {
                Text("——まだ、舞台の記録はない。").font(.system(size: 13, design: .serif)).foregroundStyle(Theme.inkDim)
                    .padding(.vertical, Theme.Sp.s8)
            } else {
                ForEach(Array(session.log.enumerated()), id: \.offset) { _, line in
                    // 判ミニチュア（通過=verm/敗退=ink/休=inkDim）。療養週（summarize の mark="休"）は
                    // 合否ではないので「敗退」に混ぜない（監査§1-4-5・summarize と同じ三値）。
                    // GP決勝の優勝行（"頂GP決勝 優勝 +…万"）は通過/敗退の語を含まない＝「休」に落ちていたので先に拾う。
                    // 客席から観た決勝（"優勝「組名」（客席から）"）は自分の優勝ではないので従来どおり。
                    let mark = (line.contains("優勝") && !line.contains("客席")) ? "優勝"
                        : (line.contains("通過") ? "通過" : (line.contains("敗退") ? "敗退" : "休"))
                    HStack(spacing: 10) {
                        Text(mark)
                            .font(.maru(10)).foregroundStyle(.white)
                            .frame(width: 40, height: 24)
                            .background(mark == "通過" || mark == "優勝" ? Theme.verm : (mark == "敗退" ? Theme.ink : Theme.inkDim),
                                        in: RoundedRectangle(cornerRadius: Theme.Rad.stamp))
                        Text(line).font(.system(size: 12.5, design: .serif)).foregroundStyle(Theme.ink)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
            // 称号は周回メタ（未実装）の器＝実体が入るまで出さない（監査G-02: 【仮】の空欄を出荷画面に残さない）
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    Text("真剣勝負").font(.maru(14, weight: .black)).foregroundStyle(Theme.verm)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .overlay(Rectangle().stroke(Theme.verm, lineWidth: 2.2))
                        .overlay(Rectangle().stroke(Theme.verm.opacity(0.5), lineWidth: 0.8).padding(3))
                        .rotationEffect(.degrees(-6))
                        .modifier(StampShake())
                }
            }
            Text(NetaCatalog.displayName(neta.kata)).font(.maru(11.5, weight: .bold)).foregroundStyle(Theme.curtain)
            netaBar(label: "完成度", value: neta.polish, color: Theme.curtainLit)
            netaBar(label: "客の反応", value: neta.buzz, color: Theme.gold)
            oroshiLine(neta)
            HStack(spacing: 8) {
                Text("舞台 \(neta.stageCount)回").font(.maru(11)).monospacedDigit().foregroundStyle(Theme.inkSub)
                ForEach(neta.lengthFit, id: \.self) { l in
                    Text(NetaCatalog.displayName(l)).font(.maru(11)).foregroundStyle(Theme.inkSub)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .overlay(Rectangle().stroke(Theme.inkFaint, lineWidth: 0.8))
                }
                Spacer()
                netaBadges(neta)
            }
            if kataPickerFor == neta.id { kataPicker(neta) }
            HStack(spacing: 8) {
                actionChip(isSelected ? "勝負ネタ中" : "勝負ネタにする", active: !isSelected) {
                    session.selectNeta(neta.id)
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
        .background(Theme.kinariPanel)
        .overlay(alignment: .leading) { Rectangle().fill(isSelected ? Theme.verm : Theme.sumi).frame(width: 5) }
        .overlay(Rectangle().stroke(Theme.sumi, lineWidth: 1.8))
        .shadow(color: .black.opacity(0.40), radius: 0, y: 3)
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
                    .font(.maru(17, weight: .black)).foregroundStyle(Theme.sumi)
                    .textFieldStyle(.plain)
                    .onSubmit { commitRename(neta.id) }
                Button { commitRename(neta.id) } label: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.verm)
                }.buttonStyle(PressableStyle())
            }
        } else {
            Button {
                renameDraft = neta.name
                renamingID = neta.id
            } label: {
                HStack(spacing: 4) {
                    Text(neta.name).font(.maru(18, weight: .black)).foregroundStyle(Theme.sumi).lineLimit(1)
                    Image(systemName: "pencil").font(.system(size: 11)).foregroundStyle(Theme.inkSub)
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
                Text("まだ人前でやっていない").font(.maru(11)).foregroundStyle(Theme.inkSub)
                    .lineLimit(1).fixedSize()   // 2行に折れて窮屈だった
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .overlay(Rectangle().stroke(Theme.inkSub, style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
            }
            if neta.isTeppan(config: session.config) {
                Text("自信作").font(.maru(11.5, weight: .black)).foregroundStyle(Theme.goldD)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .overlay(Rectangle().stroke(Theme.gold, lineWidth: 1.4))
            }
        }
    }

    /// 完成度/手応えバー（0..100・数値併記）
    private func netaBar(label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.maru(11.5, weight: .bold)).foregroundStyle(Theme.inkSub).frame(width: 60, alignment: .leading)
            inkBar(value / 100, color: color, height: 10)
            Text("\(Int(value.rounded()))").font(.maru(13, weight: .black)).monospacedDigit().foregroundStyle(Theme.sumi)
                .frame(minWidth: 24, alignment: .trailing).fixedSize()
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
                    Circle().fill(Theme.kataColor(k)).frame(width: 20, height: 20)
                        .overlay(Circle().stroke(Theme.gold, lineWidth: k == neta.kata ? 2.5 : 0))
                }.buttonStyle(PressableStyle())
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .transition(.opacity)
    }

    private func actionChip(_ label: String, active: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.maru(12, weight: .black)).foregroundStyle(active ? Theme.sumi : Theme.inkFaint)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .overlay(Rectangle().stroke(active ? Theme.sumi : Theme.line, lineWidth: 1.2))
                .overlay(alignment: .leading) { Rectangle().fill(active ? Theme.verm : Theme.line).frame(width: 3) }
        }
        .buttonStyle(PressableStyle())
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
