// ShopView.swift
// お店（円で買うアイテム・GameCore/Item.swift）。入口は週画面の最下帯の袋アイコン。
// 2026-10-12 作り直し（オーナー「アイテムのとこのUIUX悪すぎる」）：素のiOS一覧→アプリの札の見た目・アイコン・
// 買う前に確認・残り回数の札。効果は向きだけ書く（％は出さない）。乱数非消費・golden不変。
import SwiftUI
import GameCore

struct ShopView: View {
    let session: GameSession
    let onClose: () -> Void
    @State private var confirming: ShopItem?
    @State private var bought: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(ShopItem.allCases, id: \.self) { row($0) }
                    Text("回数に限りがあるものは、年が明けると戻ります。")
                        .font(.maru(11)).foregroundStyle(Theme.inkSub).padding(.top, 4)
                }
                .padding(.horizontal, 16).padding(.bottom, 20)
            }
        }
        .background(LinearGradient(colors: [Theme.bgTop, Theme.bg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if let b = bought {
                Text(b).font(.maru(14, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(Theme.ink.opacity(0.9), in: Capsule())
                    .padding(.bottom, 30)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .confirmationDialog(confirming.map { "\($0.rawValue)を買う？" } ?? "",
                            isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
                            titleVisibility: .visible) {
            if let item = confirming {
                Button("¥\(price(item).formatted()) で買う") { buy(item) }
                Button("やめる", role: .cancel) { confirming = nil }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("お店").font(.maru(22, weight: .heavy)).foregroundStyle(Theme.ink)
                Text("所持金 ¥\(session.state.money.formatted())").font(.maru(13, weight: .bold))
                    .monospacedDigit().foregroundStyle(Theme.moneyDeep)
            }
            Spacer()
            Button(action: onClose) {
                Text("とじる").font(.maru(14, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Theme.verm, in: Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)
    }

    private func price(_ item: ShopItem) -> Int { session.config.items[item]?.price ?? 0 }

    private func row(_ item: ShopItem) -> some View {
        let spec = session.config.items[item]
        let ok = GameEngine.canBuy(item, state: session.state, config: session.config)
        let (glyph, tint) = look(item)
        let limit = limitText(item, spec)
        return HStack(spacing: 12) {
            Image(systemName: glyph).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(ok ? tint : Theme.inkFaint, in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.rawValue).font(.maru(15, weight: .bold)).foregroundStyle(ok ? Theme.ink : Theme.inkSub)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text(spec?.summary ?? "").font(.maru(11.5)).foregroundStyle(Theme.inkSub)
                    .fixedSize(horizontal: false, vertical: true)
                if !limit.isEmpty {
                    Text(limit).font(.maru(10.5, weight: .bold)).foregroundStyle(tint)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .overlay(Capsule().stroke(tint.opacity(0.7), lineWidth: 1.2))
                }
            }
            Spacer(minLength: 0)
            Button { confirming = item } label: {
                Text("¥\(price(item).formatted())").font(.maru(13, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(ok ? .white : Theme.inkSub)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(ok ? Theme.verm : Theme.line, in: Capsule())
            }
            .buttonStyle(PressableStyle(enabled: ok)).disabled(!ok)
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card))
        .shadow(color: Theme.cmdShadow, radius: 0, y: 3)
    }

    private func look(_ item: ShopItem) -> (String, Color) {
        switch item {
        case .栄養ドリンク: return ("bolt.fill", Theme.cMental)
        case .銭湯の回数券: return ("drop.fill", Theme.night)
        case .中古のICレコーダー: return ("recordingtape", Theme.cIdea)
        case .新幹線回数券: return ("tram.fill", Theme.cSense)
        case .ネタ作家の勉強会: return ("book.fill", Theme.cIdea)
        case .ボイトレ短期集中: return ("waveform", Theme.cExpr)
        case .稽古場の年契約: return ("building.2.fill", Theme.gold)
        }
    }

    private func buy(_ item: ShopItem) {
        confirming = nil
        session.buyItem(item)
        Haptics.tick()
        withAnimation(Theme.Motion.appearQuick) { bought = "\(item.rawValue)を買った" }
        Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(Theme.Motion.appearQuick) { bought = nil }
        }
    }

    private func limitText(_ item: ShopItem, _ spec: ItemSpec?) -> String {
        let s = session.state
        switch item {
        case .中古のICレコーダー: return s.hasRecorder == true ? "持っている" : "一度だけ"
        case .銭湯の回数券:
            if let t = s.sentoTickets, t > 0 { return "のこり\(t)回" }
            return "4回ぶん"
        default:
            guard let lim = spec?.yearlyLimit else { return "" }
            let used = s.itemCounts?[item.rawValue] ?? 0
            return "今年あと\(max(0, lim - used))回"
        }
    }
}
