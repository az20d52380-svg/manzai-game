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
        #endif
        return .chikara
    }

    private var s: GameState { session.state }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.bgTop, Theme.bg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: Theme.Sp.s16) {
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
                    .padding(.horizontal, Theme.Sp.s16).padding(.bottom, Theme.Sp.s24)
                }
            }
            .padding(.top, Theme.Sp.s12)
        }
    }

    private var header: some View {
        HStack {
            Text("コンビの情報").font(.maru(20, weight: .heavy)).foregroundStyle(Theme.ink)
            Spacer()
            Text(session.combiName).font(.maru(12)).foregroundStyle(Theme.inkDim)
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundStyle(Theme.inkFaint)
            }.buttonStyle(PressableStyle())
        }
        .padding(.horizontal, Theme.Sp.s16)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton("能力", .chikara)
            tabButton("戦績", .kiroku)
            tabButton("持ちネタ", .neta)
        }
        .padding(4).background(Theme.card2, in: Capsule()).padding(.horizontal, Theme.Sp.s24)
    }

    private func tabButton(_ label: String, _ t: Tab) -> some View {
        Button { withAnimation(Theme.Motion.appearQuick) { tab = t } } label: {
            Text(label).font(.maru(13)).foregroundStyle(tab == t ? .white : Theme.inkDim)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(tab == t ? Theme.verm : .clear, in: Capsule())
        }.buttonStyle(.plain)
    }

    // MARK: 能力（パワプロの選手情報式・2026-10-12 オーナー「ちから/きろく/ネタも意味わからん」）
    // 1能力1行＝等級・値・次の等級までのバー。レーダーと「成長の器」の輪は外した（器は満ちた時だけ1行で言う）。

    private var chikaraPage: some View {
        let cfg = session.config
        let budget = s.growthBudget ?? 0
        let full = budget > 0 && s.growthUsed >= budget * 0.98
        let exp = AbilityUpView.points(s.expTotal)
        return VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("実力").font(.maru(14, weight: .bold)).foregroundStyle(Theme.inkSub)
                Text("\(Int(GameEngine.jitsuryoku(s, config: cfg).rounded()))").font(.maru(30, weight: .heavy))
                    .monospacedDigit().foregroundStyle(Theme.ink)
                Spacer()
                if exp > 0 && !cfg.autoPourAllocation {
                    Text("経験点 \(exp) 未使用").font(.maru(11.5, weight: .bold)).foregroundStyle(Theme.goldDeep)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card))

            VStack(spacing: 0) {
                ForEach(Array(Ability.allCases.enumerated()), id: \.element) { i, a in
                    if i > 0 { Divider().padding(.leading, 60) }
                    abilityRow(a, cap: a == .メンタル ? cfg.mentalCap : cfg.abilityCap)
                }
                Divider().padding(.leading, 60)
                compatRow
            }
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card))

            if full {
                Text("今年はもう、能力が伸びにくい（年が明けると戻る）。")
                    .font(.maru(12)).foregroundStyle(Theme.inkSub)
            }
        }
    }

    private func abilityRow(_ a: Ability, cap: Double) -> some View {
        let v = s[a]
        let g = Theme.rank(v)
        return HStack(spacing: 12) {
            Text(g).font(.maru(18, weight: .heavy)).foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Theme.gradeColor(g), in: RoundedRectangle(cornerRadius: 8))
            Text("\(a)").font(.maru(15, weight: .bold)).foregroundStyle(Theme.ink).frame(width: 74, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line)
                    Capsule().fill(Theme.abilityColor(a)).frame(width: geo.size.width * Theme.rankProgress(v, cap: cap))
                }
            }.frame(height: 8)
            Text("\(Int(v.rounded()))").font(.maru(17, weight: .heavy)).monospacedDigit().foregroundStyle(Theme.ink)
                .frame(width: 34, alignment: .trailing)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
    }

    private var compatRow: some View {
        let cap = session.config.compatCap
        return HStack(spacing: 12) {
            Image(systemName: "heart.fill").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Theme.cCompat, in: RoundedRectangle(cornerRadius: 8))
            Text("相性").font(.maru(15, weight: .bold)).foregroundStyle(Theme.ink).frame(width: 74, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line)
                    Capsule().fill(Theme.cCompat).frame(width: geo.size.width * CGFloat(min(1, s.compat / cap)))
                }
            }.frame(height: 8)
            Text("\(Int(s.compat))").font(.maru(17, weight: .heavy)).monospacedDigit().foregroundStyle(Theme.ink)
                .frame(width: 34, alignment: .trailing)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
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
                            Text("賞金 \(r.prize / 10000)万").font(.maru(11)).foregroundStyle(Theme.moneyDeep)
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
        .padding(Theme.Sp.s16).background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card)).e2()
    }

    // MARK: ネタ（持ちネタ帳・正典: docs/neta_system_redesign_v2.md §5-3。表示専用＋純適用のみ・golden非対象）

    private var netaPage: some View {
        VStack(alignment: .leading, spacing: Theme.Sp.s16) {
            activeNetaSection
            if !session.archivedNetas.isEmpty { archivedNetaSection }
        }
    }

    private var activeNetaSection: some View {
        VStack(alignment: .leading, spacing: Theme.Sp.s12) {
            HStack {
                Text("持ちネタ").font(.maru(12)).foregroundStyle(Theme.inkDim)
                Spacer()
                Text("\(session.activeNetas.count) / \(session.config.netaActiveSlots)")
                    .font(.maru(11)).monospacedDigit().foregroundStyle(Theme.inkFaint)
            }
            if session.activeNetas.isEmpty {
                Text("まだネタがない。「ネタを書く」から書こう。")
                    .font(.system(size: 13, design: .serif)).foregroundStyle(Theme.inkDim)
                    .padding(.vertical, Theme.Sp.s8)
            } else {
                ForEach(session.activeNetas) { neta in
                    netaCard(neta)
                }
            }
        }
        .padding(Theme.Sp.s16).background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card)).e2()
    }

    private var archivedNetaSection: some View {
        VStack(alignment: .leading, spacing: Theme.Sp.s12) {
            Text("しまったネタ").font(.maru(12)).foregroundStyle(Theme.inkDim)
            Text("いつでも出せる。前のネタが、また使えることもある。")
                .font(.system(size: 11.5, design: .serif)).foregroundStyle(Theme.inkFaint)
            ForEach(session.archivedNetas) { neta in
                archivedRow(neta)
            }
        }
        .padding(Theme.Sp.s16).background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card)).e1()
    }

    // MARK: アクティブなネタ1枚（型・名前・バッジ・完成度/手応え・尺・操作）

    private func netaCard(_ neta: Neta) -> some View {
        let isSelected = session.selectedNeta?.id == neta.id
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(Theme.kataColor(neta.kata)).frame(width: 8, height: 8)
                Text(NetaCatalog.displayName(neta.kata)).font(.maru(10.5)).foregroundStyle(Theme.inkDim)
                nameLabel(neta)
                Spacer(minLength: 4)
            }
            netaBar(label: "完成度", value: neta.polish, color: Theme.kataColor(neta.kata))
            netaBar(label: "客の反応", value: neta.buzz, color: Theme.gold)
            oroshiLine(neta)
            HStack(spacing: 8) {
                Text("舞台 \(neta.stageCount)回").font(.maru(10.5)).monospacedDigit().foregroundStyle(Theme.inkFaint)
                ForEach(neta.lengthFit, id: \.self) { l in
                    Text(NetaCatalog.displayName(l)).font(.maru(10.5)).foregroundStyle(Theme.inkDim)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.card2, in: Capsule())
                }
                Spacer()
                netaBadges(neta)   // 題名の行に置くと題名が切れた／札が2行に折れた→舞台の回数の行へ
            }
            if kataPickerFor == neta.id { kataPicker(neta) }
            HStack(spacing: 8) {
                // 選択中は「✓ 勝負ネタ中」（「勝負ネタ」だけだと押せない灰色に見えた）
                actionChip(isSelected ? "✓ 勝負ネタ中" : "勝負ネタにする", active: !isSelected) {
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
        .padding(Theme.Sp.s12)
        .background(Theme.card2, in: RoundedRectangle(cornerRadius: Theme.Rad.btn))
        .overlay(RoundedRectangle(cornerRadius: Theme.Rad.btn)
            .stroke(isSelected ? Theme.verm.opacity(0.55) : .clear, lineWidth: 1.5))
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
                    .font(.maru(13)).foregroundStyle(Theme.ink)
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
                    Text(neta.name).font(.maru(13)).foregroundStyle(Theme.ink).lineLimit(1)
                    Image(systemName: "pencil").font(.system(size: 9)).foregroundStyle(Theme.inkFaint)
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
                Text("まだ人前でやっていない").font(.maru(10.5)).foregroundStyle(Theme.inkFaint)
                    .lineLimit(1).fixedSize()   // 2行に折れて窮屈だった
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .overlay(Capsule().stroke(Theme.inkFaint, style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
            }
            if neta.isTeppan(config: session.config) {
                Text("自信作").font(.maru(10.5, weight: .bold)).foregroundStyle(Theme.goldD)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Theme.gold.opacity(0.18), in: Capsule())
            }
        }
    }

    /// 完成度/手応えバー（0..100・数値併記）
    private func netaBar(label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.maru(10.5)).foregroundStyle(Theme.inkDim).frame(width: 48, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.card)
                    Capsule().fill(color).frame(width: geo.size.width * CGFloat(min(1, max(0, value / 100))))
                }
            }.frame(height: 6)
            Text("\(Int(value.rounded()))").font(.maru(10)).monospacedDigit().foregroundStyle(Theme.inkFaint)
                .frame(minWidth: 20, alignment: .trailing).fixedSize()
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
            Text(label).font(.maru(10.5)).foregroundStyle(active ? Theme.verm : Theme.inkFaint)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Theme.card, in: Capsule())
                .overlay(Capsule().stroke(active ? Theme.verm.opacity(0.4) : Theme.line, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
        .disabled(!active)
    }

    // MARK: 保管庫の1行（呼び戻すだけの軽量表示）

    @ViewBuilder private func archivedRow(_ neta: Neta) -> some View {
        let revival = neta.isRevival(currentYear: session.year, config: session.config)
        let slotsFull = session.activeNetas.count >= session.config.netaActiveSlots
        HStack(spacing: 8) {
            Circle().fill(Theme.kataColor(neta.kata)).frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(neta.name).font(.maru(12)).foregroundStyle(Theme.ink)
                HStack(spacing: 6) {
                    Text(NetaCatalog.displayName(neta.kata)).font(.maru(10.5)).foregroundStyle(Theme.inkDim)
                    if revival {
                        Text("もう一度").font(.maru(10.5, weight: .bold)).foregroundStyle(Theme.cCompat)
                    }
                }
            }
            Spacer()
            actionChip("出す", active: !slotsFull) {
                withAnimation(Theme.Motion.appear) { session.recallNeta(neta.id) }
            }
        }
        .padding(.vertical, 6)
        Divider()
    }
}
