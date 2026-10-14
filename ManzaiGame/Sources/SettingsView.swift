// SettingsView.swift
// S1b 設定（正本: uiux_vision_reply_part2 §S1b・難度低）。rSheet(上辺角丸)の白面リスト。
// 音量(BGM/SE)・プライバシーポリシー・（進行中のみ）このキャリアをやめる。
// 動かない項目（購入を復元・通知・データ管理・利用規約）は監査G-02で撤去。課金/通知を実装する時に戻す。

import SwiftUI

struct SettingsView: View {
    var onClose: () -> Void
    /// 進行中に開いた時だけ渡す（「この年をやめてタイトルへ」・監査G-04）。タイトル画面からは nil。
    var onQuitRun: (() -> Void)? = nil
    @AppStorage("vol_bgm") private var bgm: Double = 0.7
    @AppStorage("vol_se") private var se: Double = 0.8
    /// 0=通常 1=確認1段目 2=確認2段目
    @State private var restartStep = 0

    var body: some View {
        ZStack {
            Color(hex: 0xFBF3E2).ignoresSafeArea()
            VStack(spacing: 0) {
                grabber
                header
                    .onAppear {
                        #if DEBUG
                        if let n = Int(ProcessInfo.processInfo.environment["MZ_STEP"] ?? "") { restartStep = n }
                        #endif
                    }
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
                            section("このキャリア") { restartBlock(onQuitRun) }
                        }
                        // 音楽クレジット（魔王魂の利用規約＝表記必須。削除しないこと・Resources/Audio/CREDITS.md 参照）
                        Text("音楽: 魔王魂 ／ 効果音: 効果音ラボ・On-Jin")
                            .font(.maru(10.5)).foregroundStyle(Theme.inkSub)
                            .padding(.top, Theme.Sp.s8)
                        Text("\(AppInfo.displayName) v\(AppInfo.version)").font(.maru(10.5)).foregroundStyle(Theme.inkFaint)
                    }
                    .padding(Theme.Sp.s16)
                }
            }
        }
    }

    private var grabber: some View { Color.clear.frame(height: 6) }

    /// 臙脂＋金の帯（週のメイン画面と同じ色）。寄席文字風の見出し。
    private var header: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Theme.goldLeafHi).frame(height: 1).frame(maxWidth: .infinity)
            Text("設定").font(.maru(22, weight: .black)).foregroundStyle(Theme.goldLeafHi)
                .shadow(color: .black.opacity(0.5), radius: 0, x: 1, y: 1)
            Rectangle().fill(Theme.goldLeafHi).frame(height: 1).frame(maxWidth: .infinity)
            Button(action: onClose) {
                Text("閉じる").font(.maru(12, weight: .black)).foregroundStyle(Theme.goldLeafHi)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .overlay(Rectangle().stroke(Theme.goldLeafHi, lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("閉じる")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(LinearGradient(colors: [Theme.curtainLit, Theme.curtain], startPoint: .top, endPoint: .bottom).ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.goldLeafMid).frame(height: 2) }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.maru(14, weight: .black)).foregroundStyle(Theme.sumi)
            VStack(spacing: 8) { content() }
                .padding(Theme.Sp.s16)
                .background(Color(hex: 0xFBF3E2))
                .overlay(alignment: .leading) { Rectangle().fill(Theme.verm).frame(width: 5) }
                .overlay(Rectangle().stroke(Theme.sumi, lineWidth: 1.5))
        }
    }

    /// 最初からやり直す（確認2段・セーブは onQuitRun＝GameSession.abandonRun が消してタイトルへ戻す）
    @ViewBuilder
    private func restartBlock(_ onQuitRun: @escaping () -> Void) -> some View {
        if restartStep == 0 {
            Button { restartStep = 1 } label: {
                HStack {
                    Text("最初からやり直す").font(.maru(16, weight: .black)).foregroundStyle(Theme.sumi)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(restartStep == 1 ? "最初からやり直しますか？\n今のコンビの記録は消えます。"
                                      : "本当に消しますか？\nもとには戻せません。")
                    .font(.maru(14, weight: .black)).foregroundStyle(restartStep == 1 ? Theme.sumi : Theme.vermD)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button { restartStep = 0 } label: {
                        Text("やめる").font(.maru(14, weight: .black)).foregroundStyle(Theme.sumi)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .overlay(Rectangle().stroke(Theme.sumi, lineWidth: 1.5))
                    }
                    Button { if restartStep == 1 { restartStep = 2 } else { onQuitRun() } } label: {
                        Text(restartStep == 1 ? "やり直す" : "消して最初から").font(.maru(14, weight: .black)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(restartStep == 1 ? Theme.verm : Theme.curtain)
                            .overlay(Rectangle().stroke(Theme.goldLeafMid, lineWidth: 1.5))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sliderRow(_ label: String, value: Binding<Double>) -> some View {
        HStack(spacing: 12) {
            Text(label).font(.maru(14, weight: .black)).foregroundStyle(Theme.sumi).frame(width: 44, alignment: .leading)
            Slider(value: value, in: 0...1).tint(Theme.verm)
            Text("\(Int(value.wrappedValue * 100))").font(.maru(12, weight: .black)).monospacedDigit().foregroundStyle(Theme.sumi).frame(width: 30, alignment: .trailing)
        }
    }

    private func linkRow(_ label: String) -> some View {
        HStack { Text(label).font(.maru(14, weight: .black)).foregroundStyle(Theme.sumi); Spacer()
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
