// ShopView.swift
// 買い物（円で買うアイテム・GameCore/Item.swift）。入口は週画面の最下帯アイコン【仮：入手UIは item_design §5-1 未決＝メニュー直買いで仮置き】。
// 効果は向きだけ書く（数値・％は出さない）。乱数非消費・golden不変。
import SwiftUI
import GameCore

struct ShopView: View {
    let session: GameSession
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ShopItem.allCases, id: \.self) { item in
                        row(item)
                    }
                } header: {
                    Text("所持金 ¥\(session.state.money.formatted())").font(.maru(13)).monospacedDigit()
                } footer: {
                    Text("回数に限りがあるものは、年が明けると戻ります。").font(.maru(11))
                }
            }
            .navigationTitle("買い物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("閉じる", action: onClose) }
            }
        }
    }

    @ViewBuilder private func row(_ item: ShopItem) -> some View {
        let spec = session.config.items[item]
        let ok = GameEngine.canBuy(item, state: session.state, config: session.config)
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.rawValue).font(.maru(15))
                Text(spec?.summary ?? "").font(.maru(11)).foregroundStyle(.secondary)
                Text(limitText(item, spec)).font(.maru(10)).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                session.buyItem(item)
            } label: {
                Text("¥\((spec?.price ?? 0).formatted())").font(.maru(13)).monospacedDigit()
                    .padding(.horizontal, 10).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.verm)
            .disabled(!ok)
        }
        .opacity(ok ? 1 : 0.55)
    }

    private func limitText(_ item: ShopItem, _ spec: ItemSpec?) -> String {
        let s = session.state
        switch item {
        case .中古のICレコーダー: return s.hasRecorder == true ? "持っている" : "一度だけ"
        case .銭湯の回数券:
            if let t = s.sentoTickets, t > 0 { return "残り\(t)回" }
            return "4回ぶん"
        default:
            guard let lim = spec?.yearlyLimit else { return "" }
            let used = s.itemCounts?[item.rawValue] ?? 0
            return "今年あと\(max(0, lim - used))回"
        }
    }
}
