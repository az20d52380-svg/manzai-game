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
            noren
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(session.config.shopLineup, id: \.self) { row($0); shelfBoard }   // 能力に効く品は売らない（原則 2026-10-12）
                    Text("お店をとじるまでは「戻す」で取り消せます。\n回数に限りがあるものは、年が明けると戻ります。")
                        .multilineTextAlignment(.center)
                        .font(.maru(12, weight: .bold)).foregroundStyle(Theme.inkSub).padding(.top, 14)
                }
                .padding(.horizontal, 16).padding(.bottom, 20)
            }
        }
        .background(Color(hex: 0xF3E6C8).ignoresSafeArea())   // 試作q70: 商店街の店先（生成りの壁）
        .onAppear { if visitStart == nil { visitStart = session.state } }
    }

    /// 試作q70: 臙脂の帯（店の看板）。決勝の幕・週画面の帯と同じ臙脂＋金。
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("お店").font(.maru(28, weight: .black)).foregroundStyle(Theme.goldLeafHi)
                .shadow(color: .black.opacity(0.5), radius: 0, x: 1, y: 1)
            Text("所持金 \(Yen.text(session.state.money))").font(.maru(14, weight: .black))
                .monospacedDigit().foregroundStyle(Theme.goldLeafHi.opacity(0.9))
            Spacer()
            Button(action: onClose) {
                Text("とじる").font(.maru(13, weight: .black)).foregroundStyle(Theme.goldLeafHi)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .overlay(Rectangle().stroke(Theme.goldLeafHi, lineWidth: 1.2))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 10)
        .background(LinearGradient(colors: [Theme.curtainLit, Theme.curtain], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.goldLeafMid).frame(height: 2) }
    }

    /// のれん: 看板の下に垂れる布（切れ込み入り）
    private var noren: some View {
        HStack(spacing: 3) {
            ForEach(0..<6, id: \.self) { i in
                Rectangle()
                    .fill(LinearGradient(colors: [Theme.curtain, Theme.curtainShade], startPoint: .top, endPoint: .bottom))
                    .frame(height: 26)
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.goldLeafMid).frame(height: 2) }
            }
        }
        .padding(.horizontal, 10)
    }

    /// 棚板（品と品のあいだ）
    private var shelfBoard: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.boardsLit).frame(height: 5)
            Rectangle().fill(Theme.boardsDark).frame(height: 3)
        }
        .padding(.horizontal, -16)
        .padding(.bottom, 4)
    }

    private func price(_ item: ShopItem) -> Int { session.config.items[item]?.price ?? 0 }

    private func row(_ item: ShopItem) -> some View {
        let spec = session.config.items[item]
        let ok = GameEngine.canBuy(item, state: session.state, config: session.config)
        let limit = limitText(item, spec)
        let big = price(item) >= 100_000   // 高い品は名前も値札も大きく（安い品との重みの差）
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.rawValue).font(.maru(big ? 24 : 19, weight: .black))
                    .foregroundStyle(ok ? Theme.sumi : Theme.inkSub)
                    .shadow(color: ok ? Theme.goldLeafHi.opacity(0.8) : .clear, radius: 0, x: 1, y: 1)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text(spec?.summary ?? "").font(.maru(12, weight: .bold)).foregroundStyle(Theme.inkSub)
                    .fixedSize(horizontal: false, vertical: true)
                if !limit.isEmpty {
                    Text(limit).font(.maru(11.5, weight: .black)).foregroundStyle(Theme.verm)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .overlay(Rectangle().stroke(Theme.verm, lineWidth: 1.5))
                        .rotationEffect(.degrees(-3))
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 8) {
                Button { buy(item) } label: { priceTag(item, ok: ok, big: big) }
                    .buttonStyle(PressableStyle(enabled: ok)).disabled(!ok)
                let n = purchases.filter { $0 == item }.count
                if n > 0 {
                    Button { undo(item) } label: {
                        Text(n > 1 ? "戻す（\(n)個）" : "戻す").font(.maru(12, weight: .black))
                            .foregroundStyle(Theme.sumi)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .overlay(Rectangle().stroke(Theme.sumi, lineWidth: 1.2))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
        .padding(.vertical, big ? 20 : 14)
    }

    /// 値札: 紙の短冊（左上を斜めに落とし、ひもの穴）。押せる品は朱の縁、高い品は金の二重縁。
    private func priceTag(_ item: ShopItem, ok: Bool, big: Bool) -> some View {
        let ink = ok ? Theme.curtain : Theme.inkSub
        return Text("¥\(price(item).formatted())").font(.maru(big ? 22 : 17, weight: .black)).monospacedDigit()
            .foregroundStyle(ink)
            .padding(.leading, 22).padding(.trailing, 12).padding(.vertical, big ? 12 : 9)
            .background(TagShape().fill(ok ? Color(hex: 0xFFF8E6) : Color(hex: 0xE6DEC9)))
            .overlay(TagShape().stroke(ok ? Theme.verm : Theme.line, lineWidth: 2))
            .overlay {
                if big && ok { TagShape().stroke(Theme.goldLeafMid, lineWidth: 1).padding(3) }
            }
            .overlay(alignment: .leading) {
                Circle().stroke(ink.opacity(0.7), lineWidth: 1.5).frame(width: 7, height: 7).padding(.leading, 9)
            }
    }

    private struct TagShape: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            let c: CGFloat = 12
            p.move(to: CGPoint(x: r.minX + c, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX + c, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.midY))
            p.closeSubpath()
            return p
        }
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
