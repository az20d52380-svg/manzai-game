// GachaView.swift
// 衣装ガチャの画面（お店の入口から開く）。【仮デザイン】既存の札・判子・ボタン部品だけで組む。遊ぶ画面に％は出さない（提供割合は別ページ）。
// 回す前の確認に「提供割合を見る」を置く（Apple 審査 3.1.1）。有料は買ったらその場で回す（回数は貯めない）。
import SwiftUI
import StoreKit

struct GachaView: View {
    let onClose: () -> Void
    @StateObject private var gacha = GachaStore.shared
    @StateObject private var store = StoreManager.shared
    @State private var results: [PullResult] = []
    @State private var confirm: Plan?
    @State private var showRates = false
    @State private var busy = false
    @State private var wearing = StageOutfit.current
    @State private var exchangeTarget: StageOutfit?
    @State private var loginNote: String?

    private enum Plan: Identifiable {
        case paid1, paid10, free
        var id: Int { hashValue }
        var count: Int { self == .paid10 ? 10 : 1 }
    }

    private var s: GachaState { gacha.state }

    var body: some View {
        ZStack {
            YoseColor.kinari.ignoresSafeArea()
            VStack(spacing: 0) {
                YoseHeaderBar(title: "衣装ガチャ", closeAction: onClose)
                ScrollView {
                    VStack(spacing: 12) {
                        Text("衣装は見た目だけが変わります。強さや成績には関係しません。")
                            .font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        loginCard
                        pullCard
                        pityCard
                        closet
                        Button { showRates = true } label: {
                            Text("提供割合・ルール").frame(maxWidth: .infinity)
                        }.buttonStyle(YoseButtonStyle(.secondary))
                    }
                    .padding(.horizontal, YoseMetrics.screenMargin).padding(.top, 8).padding(.bottom, 28)
                }
            }
            if !results.isEmpty { resultOverlay }
        }
        .fullScreenCover(isPresented: $showRates) { GachaRatesView { showRates = false } }
        .confirmationDialog(confirmTitle, isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }), titleVisibility: .visible) {
            if let p = confirm {
                Button(p == .free ? "無料で回す" : "回す（\(price(p))）") { run(p) }
                Button("提供割合を見る") { showRates = true }
                Button("やめる", role: .cancel) {}
            }
        }
        .confirmationDialog(exchangeTarget.map { "「\($0.displayName)」と交換" } ?? "", isPresented: Binding(get: { exchangeTarget != nil }, set: { if !$0 { exchangeTarget = nil } }), titleVisibility: .visible) {
            if let o = exchangeTarget {
                if s.canExchangeShards(for: o), let r = o.rarity {
                    Button("かけら\(r.shardCost)個と交換") { _ = gacha.exchangeShards(for: o) }
                }
                if s.canExchangePity(for: o) {
                    Button("\(GachaCatalog.pityGoal)ポイントと交換") { _ = gacha.exchangePity(for: o) }
                }
                Button("やめる", role: .cancel) {}
            }
        }
        .task { store.clearMessage(); await store.refresh()}
    }

    // MARK: ログインボーナス
    private var loginCard: some View {
        let today = GachaState.dayKey()
        let can = s.canClaimLogin(today: today)
        return YoseKifudaCard(showNail: true) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("ログインボーナス").font(YoseFont.gothic(16, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                    Spacer()
                    YoseTag(text: "無料", style: .outlineShu)
                }
                HStack(spacing: 6) {
                    ForEach(0..<GachaCatalog.loginGoal, id: \.self) { i in
                        Circle().fill(i < s.loginStamps ? YoseColor.shu : YoseColor.ginNezu)
                            .frame(width: 22, height: 22)
                            .overlay(Circle().stroke(YoseColor.sumi, lineWidth: 1.5))
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("札 \(s.loginStamps)枚、\(GachaCatalog.loginGoal)枚で無料1回")
                Text("毎日1枚もらえます。\(GachaCatalog.loginGoal)枚で無料のガチャ1回。")
                    .font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
                Button {
                    let before = s.freeTickets
                    if gacha.claimLogin() { let note = gacha.state.freeTickets > before ? "無料の1回がたまりました" : "今日の札をもらいました"; loginNote = note; UIAccessibility.post(notification: .announcement, argument: note) }
                } label: {
                    Text(can ? "今日の札をもらう" : "今日の札はもらいました").frame(maxWidth: .infinity)
                }
                .buttonStyle(YoseButtonStyle(.primary)).disabled(!can)
                if let n = loginNote { Text(n).font(YoseFont.mincho(13)).foregroundStyle(YoseColor.sumi) }
            }
        }
    }

    // MARK: 回す
    private func price(_ p: Plan) -> String {
        switch p {
        case .paid1: return store.products[StoreIDs.ticket1]?.displayPrice ?? "\(GachaCatalog.price1)円"
        case .paid10: return store.products[StoreIDs.ticket10]?.displayPrice ?? "\(GachaCatalog.price10)円"
        case .free: return "無料"
        }
    }
    private var confirmTitle: String {
        guard let p = confirm else { return "" }
        return p == .free ? "無料券を1回分使って回します" : "\(p.count)回回します（\(price(p))）"
    }

    private var pullCard: some View {
        YoseKifudaCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("ガチャを回す").font(YoseFont.gothic(16, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                if s.paidPending > 0 {
                    Button { run(nil) } label: { Text("未開封の\(s.paidPending)回を回す").frame(maxWidth: .infinity) }
                        .buttonStyle(YoseButtonStyle(.primary, highlight: true))
                }
                HStack(spacing: 10) {
                    Button { confirm = .paid1 } label: { Text("1回 \(price(.paid1))").frame(maxWidth: .infinity) }
                        .buttonStyle(YoseButtonStyle(.primary))
                    Button { confirm = .paid10 } label: { Text("10回 \(price(.paid10))").frame(maxWidth: .infinity) }
                        .buttonStyle(YoseButtonStyle(.primary))
                }
                Button { confirm = .free } label: { Text("無料で回す（残り\(s.freeTickets)回）").frame(maxWidth: .infinity) }
                    .buttonStyle(YoseButtonStyle(.secondary)).disabled(s.freeTickets == 0)
                if let m = store.lastMessage { Text(m).font(YoseFont.mincho(13)).foregroundStyle(YoseColor.sumi) }
                Text("はじめての1回は、特別の衣装が必ず出ます【仮】。").font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
            }
        }
        .disabled(busy)
    }

    /// plan=nil は未開封の回数を回す
    private func run(_ plan: Plan?) {
        guard !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            switch plan {
            case .free:
                results = gacha.pull(count: 1)
            case .paid1, .paid10:
                let id = plan == .paid1 ? StoreIDs.ticket1 : StoreIDs.ticket10
                guard await store.purchase(id) else { return }
                results = gacha.pull(count: gacha.state.availableTickets > 0 ? plan!.count : 0)
            case nil:
                results = gacha.pull(count: gacha.state.paidPending)
            }
            if !results.isEmpty { Sound.play(.tap) }
        }
    }

    // MARK: 天井
    private var pityCard: some View {
        YoseKifudaCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("天井").font(YoseFont.gothic(16, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                    Spacer()
                    Text("\(min(s.pity, GachaCatalog.pityGoal)) / \(GachaCatalog.pityGoal)").font(YoseFont.number(16, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                        .accessibilityLabel("\(min(s.pity, GachaCatalog.pityGoal))ポイント、\(GachaCatalog.pityGoal)ポイントで交換")
                }
                YoseGauge(value: Double(s.pity), total: Double(GachaCatalog.pityGoal), fill: YoseColor.kin)
                Text(s.pity >= GachaCatalog.pityGoal ? "好きな衣装を1着えらべます。下の衣装一覧で、持っていない衣装を押してください。" : "回すたびに1ポイントたまります。\(GachaCatalog.pityGoal)ポイントで好きな衣装と交換できます。")
                    .font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
                Text("かけら \(s.shards) 個（同じ衣装が出ると増えます）").font(YoseFont.gothic(13, weight: .bold)).foregroundStyle(YoseColor.sumi)
            }
        }
    }

    // MARK: 衣装一覧（着替え・交換）
    private var closet: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("衣装").font(YoseFont.gothic(16, weight: .heavy)).foregroundStyle(YoseColor.sumi)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(StageOutfit.allCases, id: \.self) { o in outfitCell(o) }
            }
        }
    }

    private func outfitCell(_ o: StageOutfit) -> some View {
        let owned = gacha.owns(o)
        let canX = !owned && (s.canExchangeShards(for: o) || s.canExchangePity(for: o))
        return Button {
            if owned { StageOutfit.wear(o); wearing = o } else if canX { exchangeTarget = o }
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: -6) {
                    ManzaiFigure(height: 54, tilt: 0, breathe: 0, colors: o.ore(rival: false))
                    ManzaiFigure(height: 58, tilt: 0, breathe: 0, colors: o.taniguchi(rival: false))
                }
                .opacity(owned ? 1 : 0.22)
                .overlay { if !owned { Text("？").font(YoseFont.gothic(24, weight: .black)).foregroundStyle(YoseColor.haiSumi) } }
                Text(owned || o.rarity == nil ? o.displayName : (o.rarity?.label ?? "")).font(YoseFont.gothic(11, weight: .heavy))
                    .lineLimit(1).minimumScaleFactor(0.6).foregroundStyle(YoseColor.sumi)
                if wearing == o && owned { YoseTag(text: "着用中", style: .solidEnji) }
                else if canX { YoseTag(text: "交換できる", style: .outlineShu) }
                else if o == .kuromontsuki && !owned { YoseTag(text: "広告カット付き", style: .outlineHai) }
                else { Color.clear.frame(height: 20) }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 6)
            .yoseHarigami(isFeatured: wearing == o && owned)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(owned ? "\(o.displayName)\(wearing == o ? "、着用中" : "")"
                            : "未入手の衣装\(canX ? "、交換できる" : "")\(o == .kuromontsuki ? "、広告カット付き" : "")")
        .accessibilityAddTraits(wearing == o && owned ? .isSelected : [])
    }

    // MARK: 結果
    private var resultOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture { results = [] }
                .accessibilityHidden(true)   // とじるボタンがあるので読み上げ対象から外す
            VStack(spacing: 12) {
                Text("結果").font(YoseFont.gothic(18, weight: .heavy)).foregroundStyle(YoseColor.kinari)
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: results.count == 1 ? 1 : 2), spacing: 8) {
                        ForEach(Array(results.enumerated()), id: \.offset) { _, r in resultCell(r) }
                    }
                }
                .frame(maxHeight: 460)
                Button { results = [] } label: { Text("とじる").frame(maxWidth: .infinity) }
                    .buttonStyle(YoseButtonStyle(.primary))
            }
            .padding(YoseMetrics.padH + 4)
            .background(YoseColor.kinari)
            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
            .padding(.horizontal, 24)
            .accessibilityAddTraits(.isModal)   // 結果が出ている間は後ろの一覧を読まない
        }
    }

    private func resultCell(_ r: PullResult) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: -6) {
                ManzaiFigure(height: 70, tilt: 0, breathe: 0, colors: r.outfit.ore(rival: false))
                ManzaiFigure(height: 76, tilt: 0, breathe: 0, colors: r.outfit.taniguchi(rival: false))
            }
            Text(r.outfit.displayName).font(YoseFont.gothic(13, weight: .heavy)).foregroundStyle(YoseColor.sumi)
            HStack(spacing: 4) {
                YoseTag(text: r.outfit.rarity?.label ?? "", style: r.outfit.rarity == .tokubetsu ? .outlineKin : .outlineSumi)
                if r.isNew { YoseHankoStamp(text: "新") } else { YoseTag(text: "かけら+\(r.shardsGained)", style: .outlineHai) }
            }
        }
        .frame(maxWidth: .infinity).padding(8)
        .yoseHarigami(isFeatured: r.isNew)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(r.outfit.displayName)、\(r.outfit.rarity?.label ?? "")、\(r.isNew ? "新しく入手" : "かけら\(r.shardsGained)個")")
    }
}
