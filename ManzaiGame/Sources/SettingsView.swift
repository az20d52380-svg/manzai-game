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
    @State private var showEndingBook = false

    var body: some View {
        ZStack {
            YoseColor.kinari.ignoresSafeArea()
            VStack(spacing: 0) {
                YoseHeaderBar(title: "設定", closeAction: onClose)
                    .onAppear {
                        #if DEBUG
                        if let n = Int(ProcessInfo.processInfo.environment["MZ_STEP"] ?? "") { restartStep = n }
                        #endif
                    }
                GeometryReader { geo in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        section("音量") {
                            volumeRow("BGM", value: $bgm)
                                .onChange(of: bgm) { _, _ in Sound.shared.refreshBGMVolume() }   // 即時反映
                            Rectangle().fill(YoseColor.kiDark).frame(height: 1)
                            volumeRow("SE", value: $se)
                                .onChange(of: se) { _, _ in Sound.play(.tap) }                   // 試し鳴らし
                        }
                        section("記録") {
                            Button { showEndingBook = true } label: { linkRow("エンディング図鑑") }
                                .buttonStyle(.plain)
                        }
                        // 監査G-02: 押しても何も起きない項目（購入を復元・通知・データ管理・利用規約）は撤去。
                        // プライバシーポリシーは審査5.1.1でアプリ内リンクが必須＝URLが決まり次第 AppInfo に入れる。
                        if let url = AppInfo.privacyPolicyURL {
                            section("規約") {
                                Link(destination: url) { linkRow("プライバシーポリシー") }
                            }
                        }
                        if let onQuitRun {
                            careerSection(onQuitRun)
                        }
            // 音楽クレジット（魔王魂の利用規約＝表記必須。削除しないこと・Resources/Audio/CREDITS.md 参照）
            Spacer(minLength: 16)   // 権利表記は画面の下端に据える（下半分の空白を作らない）
            VStack(spacing: 4) {
                Text("権利表記・バージョン").font(YoseFont.gothic(11, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                Rectangle().fill(YoseColor.kiDark).frame(height: 1).padding(.horizontal, 28)
                Text("音楽: 魔王魂 ／ 効果音: 効果音ラボ・On-Jin")
                    .font(YoseFont.gothic(11, weight: .bold)).foregroundStyle(YoseColor.sumi)
                Text("\(AppInfo.displayName) v\(AppInfo.version)")
                    .font(YoseFont.gothic(11, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity).padding(12).frame(minHeight: 64)
            .yoseKifuda(showNail: true)
            .padding(.top, 14)
                    }
                    .padding(.horizontal, YoseMetrics.screenMargin).padding(.vertical, 16)
                    .frame(minHeight: geo.size.height)
                }
                }
            }
            if restartStep > 0, onQuitRun != nil { restartModal }
        }
        .fullScreenCover(isPresented: $showEndingBook) { EndingGalleryView { showEndingBook = false } }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Rectangle().fill(YoseColor.enji).frame(width: 5, height: 18)   // 見出しの左朱帯
                Text(title).font(YoseFont.sectionTitle).foregroundStyle(YoseColor.sumi)
            }
            VStack(spacing: 12) { content() }
                .padding(YoseMetrics.padH + 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .yoseHarigami()
        }
    }

    /// 最初からやり直す（確認2段・セーブは onQuitRun＝GameSession.abandonRun が消してタイトルへ戻す）
    @ViewBuilder
    private func restartBlock(_ onQuitRun: @escaping () -> Void) -> some View {
        Button { restartStep = 1 } label: {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: Font.mzScaled(14), weight: .black)).accessibilityHidden(true)
                Text("最初からやり直す")
            }
            .foregroundStyle(YoseColor.shu)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(YoseButtonStyle(.secondary))
        .overlay(Rectangle().stroke(YoseColor.shu, lineWidth: 2).padding(3).allowsHitTesting(false))   // 壊す操作の重み
    }

    /// 「このキャリア」：外の貼り紙枠は付けず、注意書きとボタンだけを直に置く（二重枠をやめる）
    private func careerSection(_ onQuitRun: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Rectangle().fill(YoseColor.enji).frame(width: 5, height: 18)
                Text("このキャリア").font(YoseFont.sectionTitle).foregroundStyle(YoseColor.sumi)
            }
            Text("※いまのコンビの進行データが初期化されます").font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
            restartBlock(onQuitRun)
        }
    }

    /// 確認は画面を暗くして中央のモーダルに（「やめる」は二重の意味になるので取りやめは「もどる」）
    @ViewBuilder
    private var restartModal: some View {
        if let onQuitRun {
            YoseModal(title: "キャリアのやり直し",
                      primaryTitle: restartStep == 1 ? "やり直す" : "記録を消してやり直す",
                      primaryAction: { if restartStep == 1 { restartStep = 2 } else { onQuitRun() } },
                      cancelTitle: "もどる", cancelAction: { restartStep = 0 }) {
                Text(restartStep == 1 ? "最初からやり直しますか？\n今のコンビの記録は消えます。"
                                      : "本当に消しますか？\nもとには戻せません。")
                    .font(YoseFont.bodyBold).foregroundStyle(restartStep == 1 ? YoseColor.sumi : YoseColor.shu)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
            .transition(.opacity)
        }
    }

    /// 音量: [−] 目盛りゲージ [＋] 数字（1段＝10。ゲージ直接ドラッグでも動く）
    private func volumeRow(_ label: String, value: Binding<Double>) -> some View {
        HStack(spacing: 8) {
            Text(label).font(YoseFont.bodyBold).foregroundStyle(YoseColor.sumi).lineLimit(1).minimumScaleFactor(0.5).frame(width: 36, alignment: .leading)
            Button { step(value, -0.1) } label: { Text("−").font(YoseFont.gothic(18, weight: .black)) }
                .accessibilityLabel("\(label)を下げる")
                .buttonStyle(YoseButtonStyle(.secondary)).frame(width: 40).disabled(value.wrappedValue <= 0.001)
            YoseGauge(value: value.wrappedValue, total: 1, fill: YoseColor.shu, height: 18, showTicks: false)
                .overlay { GeometryReader { geo in
                    HStack(spacing: 0) { ForEach(1..<10, id: \.self) { _ in Spacer(); Rectangle().fill(YoseColor.sumi.opacity(0.3)).frame(width: 1) }; Spacer() }
                        .allowsHitTesting(false)
                    Color.clear.contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                            let r: Double = Double(g.location.x / geo.size.width)
                            value.wrappedValue = (min(max(r, 0.0), 1.0) * 10.0).rounded() / 10.0
                        })
                } }
            Button { step(value, 0.1) } label: { Text("＋").font(YoseFont.gothic(18, weight: .black)) }
                .accessibilityLabel("\(label)を上げる")
                .buttonStyle(YoseButtonStyle(.secondary)).frame(width: 40).disabled(value.wrappedValue >= 0.999)
            Text("\(Int((value.wrappedValue * 100).rounded()))").font(YoseFont.number(20, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                .lineLimit(1).minimumScaleFactor(0.5).frame(width: 36, alignment: .trailing)
        }
    }

    private func step(_ v: Binding<Double>, _ d: Double) {
        v.wrappedValue = min(max(((v.wrappedValue + d) * 10).rounded() / 10, 0), 1)
    }

    private func linkRow(_ label: String) -> some View {
        HStack { Text(label).font(YoseFont.bodyBold).foregroundStyle(YoseColor.sumi); Spacer()
            Image(systemName: "arrow.up.right.square").font(.system(size: Font.mzScaled(13))).foregroundStyle(YoseColor.haiSumi).accessibilityHidden(true) }
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
