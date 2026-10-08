// IntroFlow.swift
// S1 タイトル／コンビ結成（正本: uiux_vision_reply_part2 §S1）。新規開始の初回フロー:
// KVタイトル →「はじめる」→ 回想3カット(紙芝居) → コンビ名入力見開き →（onComplete）→ 育成メイン。
// 中断セーブがある時は RootView がこのフローを飛ばして続きから再開する。
// セーブ/つづきから・顔合わせ・名鑑・排出・壁写真は永続レイヤ未実装のため本編送り（§0）。
// ReminiscencePlayer は §依頼6 の共用部品①（S6b年表・優勝エピローグでも使う）。KV/立ち絵は【仮】プレースホルダ。

import SwiftUI
import UserNotifications

// MARK: 回想紙芝居プレイヤー（共用部品・夕景の3段階＋紙の地の文＋吹き出し・クロスフェード0.18s）
// 見た目の作り直し v1 §6 I2：暗い紫と半透明の灰色の形をやめ、明るい夕景（昼→放課後→宵）と色付きの二人で描く。

/// 回想の時刻（背景の色）。黒にしない。
enum DuskMood { case noon, after, eve }

struct ReminiscenceCard: Identifiable {
    let id = UUID()
    let caption: String
    var tint: Color = Theme.ink   // 旧切り絵シルエットの色（互換のため残す・未使用）
    var mood: DuskMood = .eve
    /// 台詞（あれば話者の吹き出しで出す。caption は地の文の紙）
    var speaker: String? = nil
    var line: String? = nil
    /// 二人の立ち位置（true＝並ぶ／false＝離れている）
    var together: Bool = true
}

struct ReminiscencePlayer: View {
    let cards: [ReminiscenceCard]
    var onComplete: () -> Void
    @State private var index = 0

    var body: some View {
        let card = cards[safe: index] ?? cards[0]
        VStack(spacing: 0) {
            ReminiscenceScene(mood: card.mood, together: card.together)
                .frame(maxHeight: .infinity)
                .id("scene\(index)")
                .transition(.opacity)
            VStack(spacing: 14) {
                if let line = card.line {
                    TalkBubble(advice: Advice(name: card.speaker, text: line), large: true)   // 回想の台詞は1枚に1つ＝決め台詞として大きく
                }
                NarrationCard(text: card.caption, showCue: true)
            }
            .id("cap\(index)")
            .transition(.opacity)
            .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 30)
        }
        .background(LinearGradient(colors: ReminiscenceScene.colors(card.mood), startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture {
            Sound.play(.cursor)
            if index + 1 < cards.count {
                withAnimation(.easeInOut(duration: 0.18)) { index += 1 }   // 紙めくりクロスフェード
            } else {
                onComplete()
            }
        }
    }
}

/// 回想の場面: 夕景の色＋窓の光＋床＋色付きの二人（俺＝青・谷口＝朱）。
struct ReminiscenceScene: View {
    let mood: DuskMood
    let together: Bool

    static func colors(_ m: DuskMood) -> [Color] {
        switch m {
        case .noon: return Theme.duskNoon
        case .after: return Theme.duskAfter
        case .eve: return Theme.duskEve
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let floorTop = h * 0.70
            let figH = min(230, h * 0.50)
            ZStack {
                LinearGradient(colors: Self.colors(mood), startPoint: .top, endPoint: .bottom)
                // 窓（教室・廊下の窓／宵は灯りのついた窓）
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(colors: windowColors, startPoint: .top, endPoint: .bottom))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.45), lineWidth: 5))
                    }
                }
                .frame(width: w * 0.80, height: h * 0.36)
                .position(x: w / 2, y: h * 0.32)
                // 床と、窓から床へ落ちる光
                LinearGradient(colors: floorColors, startPoint: .top, endPoint: .bottom)
                    .frame(height: h - floorTop)
                    .position(x: w / 2, y: floorTop + (h - floorTop) / 2)
                Rectangle()
                    .fill(LinearGradient(colors: [Color.white.opacity(mood == .eve ? 0.10 : 0.28), .clear],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.5, height: h - floorTop)
                    .rotationEffect(.degrees(-18))
                    .position(x: w * 0.42, y: floorTop + (h - floorTop) * 0.5)
                    .blur(radius: 6)
                // 二人
                ManzaiFigure(height: figH * 0.9, tilt: together ? 2.2 : 0, accent: Color(hex: 0x2E55B0), breathe: 3.1,
                             bodyColors: [Color(hex: 0x4A7BE8), Color(hex: 0x2E55B0)],
                             headColor: Color(hex: 0xFFDFC2), hairColor: Color(hex: 0x40394F))
                    .position(x: together ? w * 0.34 : w * 0.24, y: h * 0.95 - figH * 0.45)
                ManzaiFigure(height: figH, tilt: together ? -2.6 : 0, accent: Color(hex: 0xB02318), breathe: 2.4,
                             bodyColors: [Color(hex: 0xF0533E), Color(hex: 0xC22E1D)],
                             headColor: Color(hex: 0xFFDFC2), hairColor: Color(hex: 0x2E2838))
                    .position(x: together ? w * 0.67 : w * 0.72, y: h * 0.95 - figH * 0.50)
            }
            .clipped()
        }
        .ignoresSafeArea(edges: .top)
    }

    private var windowColors: [Color] {
        switch mood {
        case .noon: return [Color(hex: 0xFFFFFF), Color(hex: 0xFFF3D6)]
        case .after: return [Color(hex: 0xFFF1D6), Color(hex: 0xFFC98E)]
        case .eve: return [Color(hex: 0xFFE3A0), Color(hex: 0xF6B37A)]
        }
    }
    private var floorColors: [Color] {
        switch mood {
        case .noon: return [Color(hex: 0xEED2A4), Color(hex: 0xD9B07A)]
        case .after: return [Color(hex: 0xE2A47A), Color(hex: 0xC98462)]
        case .eve: return [Color(hex: 0xB07E86), Color(hex: 0x8C6A82)]
        }
    }
}

// MARK: S1 タイトル（KV＋ロゴ＋はじめる）

struct S1TitleView: View {
    var onStart: () -> Void
    @State private var lit = false     // 照明輪→ロゴの順で灯る
    @State private var showSettings = false

    var body: some View {
        ZStack {
            // 開演前の舞台＝いつか立つ舞台の光の中に二人（見た目の作り直し v1 §6 I1・暗い紫と隠れた二人をやめる）
            StageFrame(mode: .preshow, performers: true, floorTop: 0.60)
            VStack(spacing: Theme.Sp.s16) {
                Spacer().frame(height: 128)
                // ロゴ（仮）
                VStack(spacing: 6) {
                    Telop(text: AppInfo.displayName, size: 46, color: Color(hex: 0xFFF3D6))
                        .shadow(color: Theme.gold.opacity(lit ? 0.6 : 0), radius: 18)
                    Telop(text: "――漫才師、育成。", size: 15, color: Theme.houseLight)
                }
                .opacity(lit ? 1 : 0)
                .animation(.easeInOut(duration: 0.8).delay(0.4), value: lit)

                Spacer()

                Button(action: onStart) {
                    Text("はじめる").font(.maru(.title)).foregroundStyle(Theme.onGold)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Theme.gold, in: RoundedRectangle(cornerRadius: Theme.Rad.btn))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Rad.btn).stroke(.white.opacity(0.8), lineWidth: 2))
                        .shadow(color: Theme.goldD, radius: 0, y: 4)
                }
                .buttonStyle(PressableStyle())
                .padding(.horizontal, Theme.Sp.s32)
                .padding(.bottom, 92)   // 客席の頭の列より上＝二人を隠さない
                .opacity(lit ? 1 : 0).animation(.easeOut(duration: 0.5).delay(0.9), value: lit)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { showSettings = true } label: {   // Quietの歯車 → S1b設定
                Image(systemName: "gearshape.fill").font(.system(size: 18)).foregroundStyle(.white.opacity(0.85))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(PressableStyle()).padding(.top, 44).padding(.trailing, 28)
            .accessibilityLabel("設定")
        }
        .sheet(isPresented: $showSettings) { SettingsView { showSettings = false } }
        .onAppear { lit = true }
    }
}

// MARK: コンビ名入力（ネタ帳見開き）

struct NameEntryView: View {
    var onDecide: (String) -> Void
    @State private var name = ""
    @State private var inkWet = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Theme.bgGradient.ignoresSafeArea()
            VStack(spacing: Theme.Sp.s16) {
                // 二人（色付き）＋センターマイク＝これから名前を付けるコンビ（見た目の作り直し v1 §6 I3）
                ZStack(alignment: .bottom) {
                    Ellipse().fill(Theme.ink.opacity(0.10)).frame(width: 220, height: 18).blur(radius: 3)
                    HStack(alignment: .bottom, spacing: 18) {
                        ManzaiFigure(height: 120, tilt: 2.2, accent: Color(hex: 0x2E55B0), breathe: 3.1,
                                     bodyColors: [Color(hex: 0x4A7BE8), Color(hex: 0x2E55B0)],
                                     headColor: Color(hex: 0xFFDFC2), hairColor: Color(hex: 0x40394F))
                        CenterMic(height: 96)
                        ManzaiFigure(height: 132, tilt: -2.6, accent: Color(hex: 0xB02318), breathe: 2.4,
                                     bodyColors: [Color(hex: 0xF0533E), Color(hex: 0xC22E1D)],
                                     headColor: Color(hex: 0xFFDFC2), hairColor: Color(hex: 0x2E2838))
                    }
                }
                .padding(.top, 40)

                Text("コンビ名を、決めよう。").font(.maru(.title)).foregroundStyle(Theme.ink)

                // めくり札（白紙に墨・上に紐の輪2つ）に名前を書く
                TextField("コンビ名", text: $name)
                    .onChange(of: name) { _, v in if v.count > 12 { name = String(v.prefix(12)) } }   // 監査G-09: 長い名前で画面が崩れる
                    .font(.maru(30, weight: .black)).foregroundStyle(Theme.sumi)
                    .multilineTextAlignment(.center)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(decide)
                    .padding(.vertical, 26).padding(.horizontal, 18)
                    .frame(maxWidth: .infinity)
                    .background(Theme.mekuri, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.paperEdge, lineWidth: 1.5))
                    .overlay(alignment: .top) {
                        HStack(spacing: 120) { ring; ring }.offset(y: -7)   // 紐の輪（めくり札の印）
                    }
                    .scaleEffect(inkWet ? 1.03 : 1)
                    .shadow(color: Theme.ink.opacity(0.14), radius: 10, y: 4)
                    .padding(.horizontal, Theme.Sp.s32)

                Button(action: decide) {
                    Text("これでいく").font(.maru(.body)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(name.isEmpty ? Theme.inkFaint : Theme.verm, in: RoundedRectangle(cornerRadius: Theme.Rad.btn))
                        .shadow(color: name.isEmpty ? .clear : Theme.vermD, radius: 0, y: 3)
                }
                .buttonStyle(PressableStyle(enabled: !name.isEmpty))
                .disabled(name.isEmpty)
                .padding(.horizontal, Theme.Sp.s32)
                Spacer()
            }
        }
        .onAppear { focused = true }
    }

    private var ring: some View {
        Circle().stroke(Color(hex: 0x8A7A60), lineWidth: 2).frame(width: 12, height: 12)
            .background(Circle().fill(Theme.mekuri))
    }

    private func decide() {
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        withAnimation(.easeOut(duration: 0.4)) { inkWet = true }   // 札が一瞬ふくらむ（書いた名前が決まる手応え）
        Haptics.confirm()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { onDecide(name) }
    }
}

// MARK: フロー統合（title → reminiscence → nameEntry → onComplete(name)）

// MARK: S1c 通知許諾プリプロンプト（白面カード・イラスト無し・「消えます」/残り時間は出さない）

struct NotificationPromptView: View {
    var onDecide: () -> Void
    @AppStorage("notif_asked") private var asked = false
    @AppStorage("notif_snooze_until") private var snoozeUntil: Double = 0

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.bgTop, Theme.bg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: Theme.Sp.s24) {
                Spacer()
                VStack(spacing: Theme.Sp.s16) {
                    Text("大会の開演前に、\nお知らせします。")
                        .font(.maru(17)).lineSpacing(6).multilineTextAlignment(.center).foregroundStyle(Theme.ink)
                    Text("また続きをやりに来られるように。")
                        .font(.system(size: 12, design: .serif)).foregroundStyle(Theme.inkDim)
                }
                .padding(Theme.Sp.s24).frame(maxWidth: .infinity)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card)).e2()
                .padding(.horizontal, Theme.Sp.s24)

                VStack(spacing: Theme.Sp.s12) {
                    Button(action: allow) {
                        Text("知らせてもらう").font(.maru(16)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, Theme.Sp.s16)
                            .background(Theme.verm, in: RoundedRectangle(cornerRadius: Theme.Rad.btn))
                    }.buttonStyle(PressableStyle())
                    Button(action: later) {
                        Text("あとで").font(.maru(14)).foregroundStyle(Theme.inkDim)
                    }.buttonStyle(PressableStyle())
                }
                .padding(.horizontal, Theme.Sp.s32)
                Spacer()
            }
        }
    }

    /// 再表示すべきか（未回答 かつ スヌーズ期限切れ）。IntroFlow から使う。
    static func shouldShow() -> Bool {
        let d = UserDefaults.standard
        if d.bool(forKey: "notif_asked") { return false }
        let until = d.double(forKey: "notif_snooze_until")
        return until == 0 || Date().timeIntervalSince1970 >= until
    }

    private func allow() {
        asked = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        onDecide()
    }
    private func later() {
        snoozeUntil = Date().timeIntervalSince1970 + 7 * 24 * 3600   // 7日後に1回だけ再表示（裁定②）
        onDecide()
    }
}

struct IntroFlowView: View {
    var onComplete: (String) -> Void
    @State private var stage: Stage = .title
    @State private var name = "あなたのコンビ"
    private enum Stage { case title, reminiscence, nameEntry, notif }

    private let cards = [
        // 文言は既存のまま（2枚目の台詞だけ谷口の吹き出しへ分けた・語は1字も変えない）
        ReminiscenceCard(caption: "高校の教室。窓際で、谷口が一人で喋っていた。\n誰も聞いていなかった。俺だけが、笑った。",
                         mood: .noon, together: false),
        ReminiscenceCard(caption: "谷口はそう言った。放課後の、誰もいない廊下で。",
                         mood: .after, speaker: "谷口", line: "コンビ、組まへんか"),
        ReminiscenceCard(caption: "それから、何年。\n売れない日々の、まだ入口だった。", mood: .eve),
    ]

    var body: some View {
        ZStack {
            switch stage {
            case .title:
                S1TitleView { withAnimation(.easeInOut(duration: 0.4)) { stage = .reminiscence } }
                    .transition(.opacity)
            case .reminiscence:
                ReminiscencePlayer(cards: cards) { withAnimation(.easeInOut(duration: 0.4)) { stage = .nameEntry } }
                    .transition(.opacity)
            case .nameEntry:
                NameEntryView { n in
                    name = n.isEmpty ? "あなたのコンビ" : n
                    onComplete(name)
                }
                .transition(.opacity)
            case .notif:
                // 通知機能が1本も実装されていない間は許諾を求めない（初週前の摩擦だけが残るため導線から外す）。
                // NotificationPromptView 本体と MZ_UI=notif は通知実装時に復帰させる（休眠温存）。
                NotificationPromptView { onComplete(name) }
                    .transition(.opacity)
            }
        }
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
