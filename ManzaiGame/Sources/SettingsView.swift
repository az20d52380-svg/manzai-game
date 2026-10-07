// SettingsView.swift
// S1b 設定（正本: uiux_vision_reply_part2 §S1b・難度低）。rSheet(上辺角丸)の白面リスト。
// 音量(BGM/SE)・プライバシーポリシー・（進行中のみ）この年をやめる。
// 動かない項目（購入を復元・通知・データ管理・利用規約）は監査G-02で撤去。課金/通知を実装する時に戻す。

import SwiftUI

struct SettingsView: View {
    var onClose: () -> Void
    /// 進行中に開いた時だけ渡す（「この年をやめてタイトルへ」・監査G-04）。タイトル画面からは nil。
    var onQuitRun: (() -> Void)? = nil
    @AppStorage("vol_bgm") private var bgm: Double = 0.7
    @AppStorage("vol_se") private var se: Double = 0.8
    @State private var quitArmed = false

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
                                .onChange(of: bgm) { _, _ in Sound.shared.refreshBGMVolume() }   // 即時反映
                            Divider()
                            sliderRow("SE", value: $se)
                                .onChange(of: se) { _, _ in Sound.play(.tap) }                   // 試し鳴らし
                        }
                        // 監査G-02: 押しても何も起きない項目（購入を復元・通知・データ管理・利用規約）は撤去。
                        // プライバシーポリシーは審査5.1.1でアプリ内リンクが必須＝URLが決まり次第 AppInfo に入れる。
                        if let url = AppInfo.privacyPolicyURL {
                            section("規約") {
                                Link(destination: url) { linkRow("プライバシーポリシー") }
                            }
                        }
                        if let onQuitRun {
                            section("この年") {
                                Button {
                                    if quitArmed { onQuitRun() } else { quitArmed = true }
                                } label: {
                                    HStack {
                                        Text(quitArmed ? "もう一度押すと、この年の記録を消してタイトルへ戻る"
                                                       : "この年をやめてタイトルへ")
                                            .font(.maru(13)).foregroundStyle(quitArmed ? Theme.verm : Theme.ink)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        // 音楽クレジット（魔王魂の利用規約＝表記必須。削除しないこと・Resources/Audio/CREDITS.md 参照）
                        Text("音楽: 魔王魂 ／ 効果音: 効果音ラボ・On-Jin")
                            .font(.maru(9.5)).foregroundStyle(Theme.inkDim)
                            .padding(.top, Theme.Sp.s8)
                        Text("\(AppInfo.displayName) v\(AppInfo.version)").font(.maru(9.5)).foregroundStyle(Theme.inkFaint)
                    }
                    .padding(Theme.Sp.s16)
                }
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
                .accessibilityLabel("閉じる")
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
}

/// 出荷情報の置き場（監査G-02/G-11/H-06）。名前とURLはオーナー確定待ち＝ここだけ書き換える。
enum AppInfo {
    /// アプリ名（ストア名・ホーム画面名と揃える）。確定前は作業名。
    static let displayName = "四分の夜"
    /// プライバシーポリシーのURL（審査5.1.1で必須）。nil の間は設定画面に行を出さない＝申請前に必ず埋める。
    static let privacyPolicyURL: URL? = nil
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }
}
