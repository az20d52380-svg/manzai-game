// YoseCatalog.swift  DEBUG専用「部品見本」（MZ_UI=catalog）。全部品を1画面に並べる。

#if DEBUG
import SwiftUI

struct YoseCatalogView: View {
    @State private var tab = 0
    @State private var stamped = false
    @State private var power = 120
    @State private var toast: String? = nil
    @State private var showModal = ProcessInfo.processInfo.environment["MZ_CATALOG_MODAL"] != nil
    /// 目視用：MZ_CATALOG_PAGE=1..3 で見本を分けて表示（未指定は全部）
    private let page: Int? = ProcessInfo.processInfo.environment["MZ_CATALOG_PAGE"].flatMap { Int($0) }
    private func pg(_ n: Int) -> Bool { page == nil || page == n }

    private func section(_ t: String) -> some View {
        Text(t).font(YoseFont.sectionTitle).foregroundStyle(YoseColor.sumi)
            .padding(.leading, 8).overlay(alignment: .leading) { Rectangle().fill(YoseColor.shu).frame(width: 4) }
            .padding(.top, 6)
    }

    var body: some View {
        ZStack {
            YoseColor.kinari.ignoresSafeArea()
            VStack(spacing: 0) {
                YoseHeaderBar(title: "部品見本", subtitle: "寄席と計器", closeAction: {})
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if pg(1) {
                        section("文字")
                        YoseOutlinedText(text: "大看板・番付")
                        Text("商店街の福引").font(YoseFont.netaTitle)
                        Text("どっと沸いた！！相方の肉声はこの明朝。").font(YoseFont.dialogueBody)
                        Text("1,234").font(YoseFont.numHero)

                        section("ボタン（主・副・押せない・コマンド）")
                        HStack(spacing: YoseMetrics.gridGap) {
                            Button("勝負ネタにする") { }.buttonStyle(YoseButtonStyle(.primary)).frame(maxWidth: .infinity, minHeight: 44)
                            Button("型を変える") { }.buttonStyle(YoseButtonStyle(.secondary)).frame(maxWidth: .infinity, minHeight: 44)
                        }
                        HStack(spacing: YoseMetrics.gridGap) {
                            Button("押せない") { }.buttonStyle(YoseButtonStyle(.secondary)).disabled(true).frame(maxWidth: .infinity, minHeight: 44)
                            Button("稽古") { }.buttonStyle(YoseButtonStyle(.command, badgeText: "出張中")).frame(maxWidth: .infinity, minHeight: 68)
                        }

                        }

                        if pg(2) {
                        section("木札・貼り紙")
                        YoseKifudaCard(showNail: true) { Text("ステータス木札").font(YoseFont.bodyBold) }
                        YoseHarigamiCard { Text("貼り紙カード").font(YoseFont.bodyBold) }
                        YoseHarigamiCard(isFeatured: true) {
                            HStack { Text("勝負ネタ").font(YoseFont.netaTitle); Spacer(); YoseHankoStamp(text: "真剣勝負") }
                        }

                        section("タグ・判子")
                        HStack(spacing: 6) {
                            YoseTag(text: "伏線回収", style: .solidEnji)
                            YoseTag(text: "見飽きられた", style: .outlineShu)
                            YoseTag(text: "自信作", style: .outlineKin)
                            YoseTag(text: "未披露")
                        }
                        HStack(spacing: 16) {
                            YoseHankoStamp(text: "秀", isSquare: true)
                            YoseHankoStamp(text: "突破")
                            YoseHankoStamp(text: "印", isSquare: true).yoseStampImpact(stamped)
                            Button("叩く") { stamped.toggle() }.buttonStyle(YoseButtonStyle(.secondary)).frame(width: 80, height: 36)
                        }

                        section("数値表示")
                        HStack {
                            YosePowerBadge(power: power, delta: 12)
                            Button("＋") { power += 7 }.buttonStyle(YoseButtonStyle(.primary)).frame(width: 48, height: 36)
                        }
                        YoseVitalMoneyBar(stamina: 70, maxStamina: 100, money: 123456, fame: 42, fameDelta: 6)

                        }

                        if pg(3) {
                        section("ゲージ")
                        YoseGauge(value: 60, total: 100)
                        YoseGauge(value: 25, total: 100, fill: YoseColor.tokiwa, height: 16)
                        HStack(spacing: 6) {
                            ForEach([YoseColor.expSen, YoseColor.expGo, YoseColor.expMa, YoseColor.expSon, YoseColor.expTan], id: \.self) {
                                Rectangle().fill($0).frame(height: 18).overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                            }
                        }

                        section("吹き出し")
                        YoseSpeechBox(speaker: "谷口", text: "次の大会までに、もう一本ネタを仕上げとこか。", roleLabel: "相方")

                        section("上部タブ")
                        YoseTopTabBar(tabs: ["能力", "戦績", "持ちネタ"], selectedIndex: $tab)
                            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))

                        section("トースト・モーダル")
                        HStack(spacing: YoseMetrics.gridGap) {
                            Button("トースト") { toast = "勝負ネタを『商店街の福引』に変更！" }
                                .buttonStyle(YoseButtonStyle(.secondary)).frame(maxWidth: .infinity, minHeight: 44)
                            Button("モーダル") { showModal = true }
                                .buttonStyle(YoseButtonStyle(.secondary)).frame(maxWidth: .infinity, minHeight: 44)
                        }
                        YoseToast(message: "静的表示のトースト")
                        }
                    }
                    .padding(.horizontal, YoseMetrics.screenMargin).padding(.vertical, 12)
                }
                YoseFooterTabBar(items: [
                    YoseFooterItem(title: "日程", symbol: "calendar", action: {}),
                    YoseFooterItem(title: "コンビ", symbol: "person.2.fill", action: {}),
                    YoseFooterItem(title: "設定", symbol: "gearshape.fill", action: {}),
                ])
            }
            if showModal {
                YoseModal(title: "確認", primaryTitle: "決める", primaryAction: { showModal = false },
                          cancelAction: { showModal = false }) {
                    Text("この勝負ネタで本番に出ますか？").font(YoseFont.dialogueBody)
                }
            }
        }
        .yoseToast($toast)
        .preferredColorScheme(.light)
    }
}
#endif
