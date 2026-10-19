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
            YoseHeaderBar(title: "お店", closeAction: onClose)
            YoseVitalMoneyBar(stamina: Int(session.state.stamina.rounded()), maxStamina: 100, money: session.state.money)
            noren
            ScrollView {
                VStack(spacing: 10) {
                    roomSection
                    ForEach(session.config.shopLineup, id: \.self) { row($0) }   // 能力に効く品は売らない（原則 2026-10-12）
                    Text("お店をとじるまでは「戻す」で取り消せます。\n回数に限りがあるものは、年が明けると戻ります。")
                        .multilineTextAlignment(.leading)
                        .font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.sumi)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, YoseMetrics.padH).padding(.vertical, 12)
                        .yoseKifuda(showNail: true)
                        .padding(.top, 8)
                }
                .padding(.horizontal, YoseMetrics.screenMargin).padding(.top, 6).padding(.bottom, 24)
            }
        }
        .background(YoseColor.kinari.ignoresSafeArea())
        .onAppear { if visitStart == nil { visitStart = session.state } }
    }

    /// 品書き見出し（左に見出し・右に操作の説明・下に墨線）
    private var noren: some View {
        HStack(alignment: .lastTextBaseline) {
            Text("品書き").font(YoseFont.gothic(17, weight: .heavy)).foregroundStyle(YoseColor.sumi)
            Spacer()
            Text("値札を押すと買えます").font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
        }
        .padding(.horizontal, YoseMetrics.screenMargin).padding(.top, 10).padding(.bottom, 6)
        .overlay(alignment: .bottom) { Rectangle().fill(YoseColor.sumi).frame(height: 2).padding(.horizontal, YoseMetrics.screenMargin) }
    }

    // MARK: 部屋を選ぶ（キュー90・§90）
    static let roomNames = ["ボロアパート", "マンション", "タワーマンション"]

    /// 家賃の行（金額は墨・太字で目立たせる）
    private func roomRentText(_ i: Int) -> String {
        let rent = session.config.roomRents[i]
        return rent == 0 ? "家賃はいまのまま" : "家賃 +¥\(rent.formatted())（4週ごとの支払い）"
    }

    /// その部屋に住んだ時の4週ごとの支払いの合計（生活費・やりくり上手込み）
    private func totalDue(room i: Int) -> Int {
        var t = session.state
        t.room = i == 0 ? nil : i
        return GameEngine.livingCostDue(t, config: session.config)
    }

    /// 暮らしの効果の行
    private func roomHealText(_ i: Int) -> String? {
        i == 0 ? nil : (i == 2 ? "家で休むと体力がとてもよく回復する" : "家で休むと体力がよく回復する")
    }

    private var roomSection: some View {
        let cur = session.state.room ?? 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline) {
                Text("部屋を選ぶ").font(YoseFont.gothic(17, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                Spacer()
                Text("いつでも選び直せます").font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
            }
            ForEach(0..<Self.roomNames.count, id: \.self) { i in
                let ok = GameEngine.canMoveRoom(to: i, state: session.state, config: session.config)
                let here = i == cur
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(Self.roomNames[i]).font(YoseFont.gothic(17, weight: .heavy))
                                .foregroundStyle(ok || here ? YoseColor.sumi : YoseColor.disabledText)
                            if here { YoseTag(text: "いま住んでいる", style: .outlineShu) }
                        }
                        Text(roomRentText(i)).font(YoseFont.gothic(13, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                            .fixedSize(horizontal: false, vertical: true)
                        if i > 0 {   // 生活費と合わせた支払いの合計（引っ越した後の苦しさが見えるように・code_review_2026-10-19 §3-3）
                            Text("生活費と合わせると 4週で ¥\(totalDue(room: i).formatted())")
                                .font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let h = roomHealText(i) {
                            Text(h).font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !ok, !here {   // 引っ越せない理由（あといくら）
                            Text("あと ¥\((session.config.roomRents[i] - session.state.money).formatted()) あれば引っ越せる")
                                .font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.shu)
                        }
                    }
                    Spacer(minLength: 0)
                    if !here {
                        Button { if session.moveRoom(to: i) { visitStart?.room = session.state.room; Haptics.tick() } } label: {   // 引っ越しは「戻す」の対象外＝起点の部屋も今の部屋に（code_review_2026-10-19 §1-1）
                            Text(i < cur ? "戻る" : "引っ越す").font(YoseFont.gothic(14, weight: .heavy)).padding(.vertical, 6)
                        }
                        .buttonStyle(YoseButtonStyle(.kifuda)).frame(width: 96).disabled(!ok)
                    }
                }
                .padding(.horizontal, YoseMetrics.padH).padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .yoseHarigami()
            }
            Text("上の部屋へは、増える家賃の1回ぶんを持っている時だけ引っ越せます。下の部屋へはお金がなくても戻れます。新しい家賃は次の支払い（4週ごと）からです。")
                .font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 6)
    }

    private func price(_ item: ShopItem) -> Int { session.config.items[item]?.price ?? 0 }

    private func row(_ item: ShopItem) -> some View {
        let spec = session.config.items[item]
        let ok = GameEngine.canBuy(item, state: session.state, config: session.config)
        let limit = limitText(item, spec)
        let big = price(item) >= 100_000   // 高い品は名前も値札も大きく（安い品との重みの差）
        let n = purchases.filter { $0 == item }.count
        return HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.rawValue).font(YoseFont.gothic(big ? 20 : 17, weight: .heavy))
                    .foregroundStyle(ok ? YoseColor.sumi : YoseColor.disabledText)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text(spec?.summary ?? "").font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
                    .fixedSize(horizontal: false, vertical: true)
                if !limit.isEmpty { YoseTag(text: limit, style: .outlineShu) }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 6) {
                Button { buy(item) } label: {
                    VStack(spacing: 0) {
                        // 値札の上辺に朱の小帯（白抜きの「購入」）＋下段に値段＝押すと買える札だと一目で分かる
                        Text("購入").font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(ok ? YoseColor.kinari : YoseColor.kinari.opacity(0.8))
                            .frame(maxWidth: .infinity).frame(height: 16)
                            .background(ok ? YoseColor.shu : YoseColor.disabledText)
                        Text("¥\(price(item).formatted())").font(YoseFont.number(big ? 20 : 18, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.7)
                            .padding(.vertical, 4)
                    }
                }
                .buttonStyle(YoseButtonStyle(.kifuda))   // 値札は全商品同じ木札（高額だけ朱にしない）
                .frame(width: 118)
                .disabled(!ok)
                if n > 0 {
                    Button { undo(item) } label: {
                        Text(n > 1 ? "戻す（\(n)個）" : "戻す").font(YoseFont.gothic(13, weight: .heavy))
                    }
                    .buttonStyle(YoseButtonStyle(.secondary))
                    .frame(width: 118)
                }
            }
        }
        .padding(.horizontal, YoseMetrics.padH).padding(.vertical, big ? 18 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .yoseHarigami()
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
            return "\(session.config.itemSentoTickets)回ぶん"
        default:
            guard let lim = spec?.yearlyLimit else { return "" }
            let used = s.itemCounts?[item.rawValue] ?? 0
            return "今年あと\(max(0, lim - used))回"
        }
    }
}
