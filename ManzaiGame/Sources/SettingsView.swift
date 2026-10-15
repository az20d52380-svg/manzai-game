// SettingsView.swift
// S1b 設定（正本: uiux_vision_reply_part2 §S1b・難度低）。rSheet(上辺角丸)の白面リスト。
// 音量(BGM/SE)・プライバシーポリシー・（進行中のみ）このキャリアをやめる。
// 動かない項目（購入を復元・通知・データ管理・利用規約）は監査G-02で撤去。課金/通知を実装する時に戻す。

import SwiftUI
import GameCore

struct SettingsView: View {
    var onClose: () -> Void
    /// 進行中に開いた時だけ渡す（「この年をやめてタイトルへ」・監査G-04）。タイトル画面からは nil。
    var onQuitRun: (() -> Void)? = nil
    @AppStorage("vol_bgm") private var bgm: Double = 0.7
    @AppStorage("vol_se") private var se: Double = 0.8
    /// 0=通常 1=確認1段目 2=確認2段目
    @State private var restartStep = 0
    @State private var showEndingBook = false
    @State private var showGlossary = false

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
                        section("遊び方") {
                            Button { showGlossary = true } label: { linkRow("用語集") }
                                .buttonStyle(.plain)
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
        // 全画面の開き先は1つにまとめる（同じ View に fullScreenCover を2つ並べると片方が開かないことがある）
        .fullScreenCover(isPresented: Binding(get: { showEndingBook || showGlossary },
                                              set: { if !$0 { showEndingBook = false; showGlossary = false } })) {
            if showGlossary { GlossaryView { showGlossary = false } }
            else { EndingGalleryView { showEndingBook = false } }
        }
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


/// 用語集（設定内）。事実だけを1語1〜2行。数値は GameConfig の既定値に合わせて書く（変えたらここも直す）。
struct GlossaryView: View {
    var onClose: () -> Void

    private struct Group: Identifiable { let title: String; let rows: [(String, String)]; var id: String { title } }
    private static let groups: [Group] = [
        Group(title: "強さ", rows: [
            ("実力", "コンビの強さ。センス・発想・表現・華の4つから決まる。大会の通過ラインと比べられる。"),
            ("相性", "二人の息の合い方。実力に足されて数えられる。"),
            ("体力", "行動すると減り、休むと戻る。低いと稽古ができず、体調を崩して休むことがある。"),
            ("経験点", "練習やネタ書きでたまる5種の粒。閃き・語彙・間合い・存在感・胆力。能力アップで使う。"),
            ("能力", "センス・発想・表現・華・メンタル。経験点で上がる。メンタルは、本番の出来のばらつきを小さくする。"),
        ]),
        Group(title: "ネタ", rows: [
            ("完成度", "ネタの仕上がり（0〜100）。ネタ書きで上がる。低いネタは本番の点が下がる。"),
            ("飽き", "同じネタを大会で使い続けると、客に見飽きられて本番の点が下がる。新しいネタを書くと元どおり。"),
        ]),
        Group(title: "暮らし", rows: [
            ("知名度", "どれだけ知られているか（0〜100）。舞台に立つと上がる。決勝では高いほど通過ラインが少し下がる。"),
            ("所持金と生活費", "バイトや賞金で増える。\(GameConfig().livingInterval)週に1度、週の終わりに\(GameConfig().livingCost / 10_000)万円の生活費が引かれる。"),
            ("借金と夜逃げ", "お金が足りないと借金になる。借金が\(-GameConfig().bankruptLine / 10_000)万円を超えると夜逃げになり、芸人は続けられない。"),
        ]),
        Group(title: "コンビ", rows: [
            ("すれ違い", "相性が上がらない週が続くとたまる。途中で予告が出る。たまりきるとコンビは解散する。"),
        ]),
        Group(title: "大会", rows: [
            ("通過ライン", "大会ごとの数字。実力（相性をふくむ）がこれを超えるほど通過しやすい。"),
            ("決勝", "頂グランプリの最後の舞台（第\(GameConfig().calendar.gpFinalWeek)週）。ネタは1本目と2本目を選べる。"),
            ("エンディング図鑑", "キャリアの終わり方の記録。見た結末が並び、あとから読み返せる。"),
        ]),
    ]

    var body: some View {
        ZStack {
            YoseColor.kinari.ignoresSafeArea()
            VStack(spacing: 0) {
                YoseHeaderBar(title: "用語集", closeAction: onClose)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(Self.groups) { g in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Rectangle().fill(YoseColor.enji).frame(width: 5, height: 18)
                                    Text(g.title).font(YoseFont.sectionTitle).foregroundStyle(YoseColor.sumi)
                                }
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(g.rows, id: \.0) { r in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(r.0).font(YoseFont.gothic(14, weight: .heavy)).foregroundStyle(YoseColor.enji)
                                            Text(r.1).font(YoseFont.gothic(13, weight: .bold)).foregroundStyle(YoseColor.sumi)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                                .padding(YoseMetrics.padH + 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .yoseHarigami()
                            }
                        }
                    }
                    .padding(.horizontal, YoseMetrics.screenMargin).padding(.vertical, 16)
                }
            }
        }
    }
}
