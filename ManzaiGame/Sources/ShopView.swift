// ShopView.swift
// お店（円で買うアイテム・GameCore/Item.swift）。入口は週画面の最下帯の袋アイコン。
// 2026-10-12 作り直し（オーナー「アイテムのとこのUIUX悪すぎる」）：素のiOS一覧→アプリの札の見た目・アイコン・残り回数の札。
// 買い方（オーナー 2026-10-12「押したら買えて、キャンセルだけ」「常時で」）：値段を押す＝すぐ買う。店を開いている間は
// 買った行にずっと「戻す」が出る（店に入った時の状態から残りを買い直す＝ずれない）。とじると確定。乱数非消費・golden不変。
import SwiftUI
import GameCore

struct ShopView: View {
    let session: GameSession
    let onClose: () -> Void
    /// 店に入った時の状態（「戻す」の起点）と、この来店で買った順
    @State private var visitStart: GameState?
    @State private var purchases: [ShopItem] = []

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(ShopItem.allCases, id: \.self) { row($0) }
                    Text("お店をとじるまでは「戻す」で取り消せます。\n回数に限りがあるものは、年が明けると戻ります。")
                        .multilineTextAlignment(.center)
                        .font(.maru(11)).foregroundStyle(Theme.inkSub).padding(.top, 4)
                }
                .padding(.horizontal, 16).padding(.bottom, 20)
            }
        }
        .background(LinearGradient(colors: [Theme.bgTop, Theme.bg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .onAppear { if visitStart == nil { visitStart = session.state } }
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
            VStack(alignment: .trailing, spacing: 6) {
                Button { buy(item) } label: {
                    Text("¥\(price(item).formatted())").font(.maru(13, weight: .heavy)).monospacedDigit()
                        .foregroundStyle(ok ? .white : Theme.inkSub)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(ok ? Theme.verm : Theme.line, in: Capsule())
                }
                .buttonStyle(PressableStyle(enabled: ok)).disabled(!ok)
                let n = purchases.filter { $0 == item }.count
                if n > 0 {
                    Button { undo(item) } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward").font(.system(size: 10, weight: .bold))
                            Text(n > 1 ? "戻す（\(n)個）" : "戻す").font(.maru(11.5, weight: .bold))
                        }
                        .foregroundStyle(Theme.inkSub)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .overlay(Capsule().stroke(Theme.inkFaint, lineWidth: 1.2))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
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
        if visitStart == nil { visitStart = session.state }
        guard session.buyItem(item) else { return }
        purchases.append(item)
        Haptics.tick()
    }

    /// この来店で買った item を1つ返す＝店に入った時の状態から、残りの買い物だけ順に買い直す
    private func undo(_ item: ShopItem) {
        guard let start = visitStart, let i = purchases.lastIndex(of: item) else { return }
        purchases.remove(at: i)
        session.replayShopVisit(from: start, purchases)
        Haptics.tick()
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
