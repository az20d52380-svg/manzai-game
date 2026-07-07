// SettingsView.swift
// S1b 設定（正本: uiux_vision_reply_part2 §S1b・難度低）。rSheet(上辺角丸)の白面リスト。
// 音量(BGM/SE)・通知ON/OFF・規約/プライバシー(外部リンク)・購入復元・データ管理の入口。
// MVPは音源/課金/セーブ未実装＝設定の「永続化のみ」実装（§実装ブリッジ）。閲覧＝無音・無振動、トグルのみSE極小。
// データ管理は GameState の Codable セーブ設計とのすり合わせが別途要る（START_HERE 残タスク5）＝準備中。

import SwiftUI

struct SettingsView: View {
    var onClose: () -> Void
    @AppStorage("vol_bgm") private var bgm: Double = 0.7
    @AppStorage("vol_se") private var se: Double = 0.8
    @AppStorage("notif_on") private var notif: Bool = false
    @State private var toast: String?

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.bgTop, Theme.bg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 0) {
                grabber
                header
                ScrollView {
                    VStack(spacing: Theme.Sp.s12) {
                        section("音量") {
                            sliderRow("BGM", value: $bgm)
                            Divider()
                            sliderRow("SE", value: $se)
                        }
                        section("通知") {
                            Toggle(isOn: $notif) { Text("開演前に知らせる").font(.maru(13)).foregroundStyle(Theme.ink) }
                                .tint(Theme.verm)
                        }
                        section("規約") {
                            linkRow("利用規約")
                            Divider()
                            linkRow("プライバシーポリシー")
                        }
                        section("その他") {
                            tapRow("購入を復元") { toastShow("購入情報を確認しました。") }
                            Divider()
                            tapRow("データ管理", trailing: "準備中") { }
                        }
                        Text("四分の夜【仮】 v0 ・ 数値/文言は全て仮").font(.maru(9.5)).foregroundStyle(Theme.inkFaint)
                            .padding(.top, Theme.Sp.s8)
                    }
                    .padding(Theme.Sp.s16)
                }
            }
            if let toast {
                Text(toast).font(.maru(12)).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8).background(Theme.pillDark, in: Capsule())
                    .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 40).transition(.opacity)
            }
        }
    }

    private var grabber: some View {
        Capsule().fill(Theme.inkFaint).frame(width: 40, height: 5).padding(.top, 10).padding(.bottom, 4)
    }

    private var header: some View {
        HStack {
            Text("設定").font(.maru(16)).foregroundStyle(Theme.ink)
            Spacer()
            Button(action: onClose) { Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundStyle(Theme.inkFaint) }
                .buttonStyle(PressableStyle())
        }.padding(.horizontal, Theme.Sp.s16).padding(.bottom, Theme.Sp.s8)
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.maru(11)).foregroundStyle(Theme.inkDim)
            VStack(spacing: 8) { content() }
                .padding(Theme.Sp.s16).background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card)).e1()
        }
    }

    private func sliderRow(_ label: String, value: Binding<Double>) -> some View {
        HStack(spacing: 12) {
            Text(label).font(.maru(13)).foregroundStyle(Theme.ink).frame(width: 44, alignment: .leading)
            Slider(value: value, in: 0...1).tint(Theme.verm)
            Text("\(Int(value.wrappedValue * 100))").font(.maru(11)).monospacedDigit().foregroundStyle(Theme.inkDim).frame(width: 30, alignment: .trailing)
        }
    }

    private func linkRow(_ label: String) -> some View {
        HStack { Text(label).font(.maru(13)).foregroundStyle(Theme.ink); Spacer()
            Image(systemName: "arrow.up.right.square").font(.system(size: 13)).foregroundStyle(Theme.inkFaint) }
    }

    private func tapRow(_ label: String, trailing: String? = nil, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack { Text(label).font(.maru(13)).foregroundStyle(Theme.ink); Spacer()
                Text(trailing ?? "").font(.maru(11)).foregroundStyle(Theme.inkFaint)
                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Theme.inkFaint) }
        }.buttonStyle(.plain)
    }

    private func toastShow(_ t: String) {
        withAnimation(.easeOut(duration: 0.2)) { toast = t }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation { toast = nil } }
    }
}
