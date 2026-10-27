// IntroFlow.swift
// S1 タイトル／コンビ結成（正本: uiux_vision_reply_part2 §S1）。新規開始の初回フロー:
// KVタイトル →「はじめる」→ コンビの形 → コンビ名入力見開き（出会い方も選ぶ）→ 回想3カット(紙芝居・選んだ型) →（onComplete）→ 育成メイン。
// 中断セーブがある時は RootView がこのフローを飛ばして続きから再開する。
// セーブ/つづきから・顔合わせ・名鑑・排出・壁写真は永続レイヤ未実装のため本編送り（§0）。
// ReminiscencePlayer は §依頼6 の共用部品①（S6b年表・優勝エピローグでも使う）。KV/立ち絵は【仮】プレースホルダ。

import SwiftUI
import UserNotifications

// MARK: 回想紙芝居プレイヤー（共用部品・夕景の3段階＋紙の地の文＋吹き出し・クロスフェード0.18s）
// 見た目の作り直し v1 §6 I2：暗い紫と半透明の灰色の形をやめ、明るい夕景（昼→放課後→宵）と色付きの二人で描く。

/// 回想の時刻（背景の色）。黒にしない。
enum DuskMood { case noon, after, eve, night }

struct ReminiscenceCard: Identifiable {
    let id = UUID()
    let caption: String
    var tint: Color = Theme.ink   // 旧切り絵シルエットの色（互換のため残す・未使用）
    var mood: DuskMood = .eve
    /// 台詞（あれば話者の吹き出しで出す。caption は地の文の紙）
    var speaker: String? = nil
    var line: String? = nil
    /// 短い会話（1〜2往復）。あれば line より優先して吹き出しを順に並べる（v3 ①：会話で場面が分かる）
    var talk: [Advice] = []
    /// 二人の立ち位置（true＝並ぶ／false＝離れている）
    var together: Bool = true
    /// 場面のト書きの場所・時間帯（あればイベント用の背景を使う。nil は従来の共通の室内絵）
    var backdrop: EventBackdrop? = nil
}

struct ReminiscencePlayer: View {
    let cards: [ReminiscenceCard]
    var title: String = "はじまりの話"
    var onComplete: () -> Void
    var onSkip: (() -> Void)? = nil   // 指定時だけヘッダー右に「とばす ▶」を出す（導入の2周目以降）
    @State private var index = ReminiscencePlayer.debugStart
    #if DEBUG
    static var debugStart: Int { Int(ProcessInfo.processInfo.environment["MZ_CARD"] ?? "") ?? Int(ProcessInfo.processInfo.environment["MZ_ENDSTEP"] ?? "") ?? 0 }   // 目視用: MZ_CARD=<0始まり>で途中の場面から
    #else
    static var debugStart: Int { 0 }
    #endif

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let card = cards[safe: index] ?? cards[0]
        let lines: [Advice] = !card.talk.isEmpty ? card.talk
            : (card.line.map { [Advice(name: card.speaker, text: $0)] } ?? [])
        VStack(spacing: 0) {
            YoseHeaderBar(title: title, subtitle: "\(index + 1) / \(cards.count)",
                          closeTitle: "とばす ▶", closeAction: onSkip.map { skip in { Sound.play(.cursor); skip() } })
            ZStack(alignment: .topLeading) {
                RecallPicture(mood: card.mood, together: card.together, backdrop: card.backdrop)
                    .padding(.horizontal, YoseMetrics.screenMargin).padding(.top, 14)
                    .id("scene\(index)")
                HStack(alignment: .top) {
                    RecallPlaceTag(text: card.caption)
                    Spacer(minLength: 8)
                    RecallPageMark(index: index, count: cards.count)
                }
                .padding(.horizontal, YoseMetrics.screenMargin + 8).padding(.top, 22)
            }
            .frame(maxHeight: .infinity)
            // 台詞＝過去の行は薄い台本行・今の行はめくり名札＋貼り紙の吹き出し
            VStack(alignment: .leading, spacing: 8) {
                // 大きい文字（アクセシビリティ）では過去の行を直前の1行だけに（台詞ボックスが下端に押し出されないように・表示だけ）
                ForEach(Array(lines.indices.dropLast().suffix(dynamicTypeSize.isAccessibilitySize ? 1 : lines.count)), id: \.self) { i in
                    RecallScriptRow(advice: lines[i])
                }
                if let last = lines.last {
                    YoseSpeechBox(speaker: Names.show(last.name ?? "俺"), text: Names.show(last.text))
                }
            }
            .frame(minHeight: 112, alignment: .bottom)
            .padding(.horizontal, YoseMetrics.screenMargin).padding(.top, 10).padding(.bottom, 26)
            .id("cap\(index)")
            .transition(.opacity)
        }
        .background(YoseColor.kinari.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture { nextCard() }
        .accessibilityAction { nextCard() }   // 読み上げ中の二度押しでも同じく進む（a11y_check_1026_voiceover_v0 #1・FinalsBroadcastIntro:596 と同形）
    }

    private func nextCard() {
        Sound.play(.cursor)
        if index + 1 < cards.count {
            withAnimation(Theme.Motion.r(.easeInOut(duration: 0.18))) { index += 1 }
        } else {
            onComplete()
        }
    }
}

/// 場所・時間の札（直角・臙脂地・左に金の縦帯・墨枠・下影）
private struct RecallPlaceTag: View {
    let text: String
    var body: some View {
        Text(text).font(YoseFont.gothic(14, weight: .heavy)).foregroundStyle(YoseColor.kinari)
            .padding(.horizontal, 12).padding(.vertical, 6).padding(.leading, 4)
            .background(YoseColor.enji)
            .overlay(alignment: .leading) { Rectangle().fill(YoseColor.kin).frame(width: 4) }
            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
            .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))
    }
}

/// 何枚目か（直角の印）
private struct RecallPageMark: View {
    let index: Int
    let count: Int
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                Rectangle().fill(i == index ? YoseColor.shu : YoseColor.ginNezu)
                    .frame(width: 10, height: 10)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
            }
        }
        .padding(.top, 8)
        .accessibilityHidden(true)
    }
}

/// 過去の台詞（台本行・薄く）
private struct RecallScriptRow: View {
    let advice: Advice
    var body: some View {
        let name = advice.name ?? "俺"
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(verbatim: "\(Names.show(name))「\(Names.show(advice.text))」").font(YoseFont.mincho(14)).foregroundStyle(YoseColor.sumi.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12).padding(.vertical, 4)
                .background(YoseColor.ki.opacity(0.35))
                .overlay(alignment: .leading) { Rectangle().fill(YoseColor.shu).frame(width: 3) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Names.show(name))、\(Names.show(advice.text))")
    }
}

/// 回想の挿絵額縁（二重墨枠・夕景の面＋格子窓＋床＋二人の名札）。人の絵は描かず、めくり名札で二人を表す。
private struct RecallPicture: View {
    let mood: DuskMood
    let together: Bool
    var backdrop: EventBackdrop? = nil

    private var sky: [Color] {
        switch mood {
        case .noon: return [YoseColor.washiFeatured, YoseColor.ki]
        case .after: return [YoseColor.ki, YoseColor.kin.opacity(0.65)]
        case .eve: return [YoseColor.kiDark, YoseColor.shu.opacity(0.55)]
        case .night: return [Color(hex: 0x1F2440), Color(hex: 0x3A3350)]   // 深夜：藍の闇
        }
    }
    private var floorColor: Color {
        switch mood {
        case .noon: return YoseColor.kiDark
        case .after: return YoseColor.kiDark.opacity(0.9)
        case .eve: return YoseColor.haiSumi
        case .night: return Color(hex: 0x1A1626)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let floorH = h * 0.30
            ZStack(alignment: .bottom) {
                if let backdrop {
                    EventStageBackdropView(backdrop: backdrop).frame(width: w, height: h)
                } else {
                LinearGradient(colors: sky, startPoint: .top, endPoint: .bottom)
                // 格子窓
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { _ in
                        ZStack {
                            LinearGradient(colors: mood == .night ? [Color(hex: 0x0F1430), Color(hex: 0x2B3560)]
                                           : mood == .eve ? [YoseColor.kinBright.opacity(0.8), YoseColor.shu.opacity(0.35)]
                                           : [Color(hex: 0xE8C590).opacity(0.85), YoseColor.washiFeatured],
                                           startPoint: .top, endPoint: .bottom)
                            Rectangle().fill(.white.opacity(0.45)).frame(width: 10).rotationEffect(.degrees(28)).offset(x: -8)
                            Rectangle().fill(YoseColor.sumi).frame(width: 2)
                            Rectangle().fill(YoseColor.sumi).frame(height: 2)
                        }
                        .clipped()
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2.5))
                    }
                }
                .frame(width: w * 0.78, height: h * 0.21)
                .frame(maxHeight: .infinity, alignment: .top).padding(.top, h * 0.17)
                // 床
                Rectangle().fill(floorColor).frame(height: floorH)
                    .overlay(alignment: .top) { Rectangle().fill(YoseColor.sumi).frame(height: 2.5) }
                // 二人の名札
                HStack(alignment: .bottom, spacing: together ? 18 : w * 0.34) {
                    RecallNameBoard(name: "俺", band: YoseColor.kuroUrushi, height: min(150, h * 0.46))
                    RecallNameBoard(name: "谷口", band: YoseColor.shu, height: min(176, h * 0.52))
                }
                .padding(.bottom, floorH * 0.28)
                // 手前の机2つ（天板＋ネタ帳）
                HStack(spacing: together ? 24 : w * 0.18) {
                    RecallDesk(); RecallDesk()
                }
                .padding(.bottom, floorH * 0.04)
                }
                if backdrop != nil {
                    // 二人の名札（背景の手前）
                    HStack(alignment: .bottom, spacing: together ? 18 : w * 0.34) {
                        RecallNameBoard(name: "俺", band: YoseColor.kuroUrushi, height: min(150, h * 0.46))
                        RecallNameBoard(name: "谷口", band: YoseColor.shu, height: min(176, h * 0.52))
                    }
                    .padding(.bottom, h * 0.06)
                }
            }
            .clipped()
        }
        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2.5))
        .padding(4)
        .background(YoseColor.washi)
        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
        .background(Rectangle().fill(YoseColor.sumi).offset(y: 3))
        .padding(.bottom, 3)
    }
}

/// 教室の机（台形の天板＋脚・白いネタ帳）
private struct RecallDesk: View {
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Rectangle().fill(YoseColor.kiDark)
                Rectangle().fill(YoseColor.washi).frame(width: 22, height: 10).rotationEffect(.degrees(-6)).offset(x: -14)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1).frame(width: 22, height: 10).rotationEffect(.degrees(-6)).offset(x: -14))
            }
            .frame(width: 92, height: 14)
            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
            HStack { Rectangle().fill(YoseColor.sumi).frame(width: 4, height: 18); Spacer(); Rectangle().fill(YoseColor.sumi).frame(width: 4, height: 18) }
                .frame(width: 76)
        }
    }
}

/// 寄席のめくり風の縦名札
private struct RecallNameBoard: View {
    let name: String
    let band: Color
    let height: CGFloat
    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(band).frame(height: 14)
                .overlay(Rectangle().fill(YoseColor.kin).frame(width: 14, height: 2))
            VStack(spacing: 2) {
                ForEach(Array(Names.show(name).enumerated()), id: \.offset) { _, ch in
                    Text(String(ch)).font(YoseFont.mincho(26)).foregroundStyle(YoseColor.sumi)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: 56, height: height)
        .background(YoseColor.washi)
        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
        .background(Rectangle().fill(YoseColor.sumi).offset(y: 3))
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
        case .night: return [Color(hex: 0x1F2440), Color(hex: 0x2E2F55), Color(hex: 0x4A3E63)]   // 深夜（暗転ではなく藍・窓だけ灯る）
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
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(colors: windowColors, startPoint: .top, endPoint: .bottom))
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.sumi.opacity(0.55), lineWidth: 3))
                    }
                }
                .frame(width: w * 0.80, height: h * 0.36)
                .position(x: w / 2, y: h * 0.32)
                // 床
                LinearGradient(colors: floorColors, startPoint: .top, endPoint: .bottom)
                    .frame(height: h - floorTop)
                    .position(x: w / 2, y: floorTop + (h - floorTop) / 2)
                // 二人
                ManzaiFigure(height: figH * 0.9, tilt: together ? 2.2 : 0, breathe: 3.1, colors: StageOutfit.standard.ore(rival: false))
                    .position(x: together ? w * 0.34 : w * 0.24, y: h * 0.95 - figH * 0.45)
                ManzaiFigure(height: figH, tilt: together ? -2.6 : 0, breathe: 2.4, colors: StageOutfit.standard.taniguchi(rival: false))
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
        case .night: return [Color(hex: 0x141A33), Color(hex: 0x232B4F)]
        }
    }
    private var floorColors: [Color] {
        switch mood {
        case .noon: return [Color(hex: 0xEED2A4), Color(hex: 0xD9B07A)]
        case .after: return [Color(hex: 0xE2A47A), Color(hex: 0xC98462)]
        case .eve: return [Color(hex: 0xB07E86), Color(hex: 0x8C6A82)]
        case .night: return [Color(hex: 0x3A3350), Color(hex: 0x2A2540)]
        }
    }
}

// MARK: S1 タイトル（KV＋ロゴ＋はじめる）

struct S1TitleView: View {
    var onStart: () -> Void
    @State private var lit = false
    @State private var showSettings = false
    @State private var showBook = false

    private static let crowd: [(CGFloat, CGFloat)] = [   // (幅, 高さ)＝ばらつかせた観客席の影
        (34, 40), (22, 52), (40, 36), (28, 56), (36, 44), (24, 38), (42, 54), (30, 42), (26, 50), (38, 36), (32, 48), (24, 56)
    ]

    var body: some View {
        ZStack {
            // 定式幕（黒・柿・萌葱の縦縞）
            HStack(spacing: 0) {
                ForEach(0..<9, id: \.self) { i in
                    [YoseColor.kuroUrushi, YoseColor.shu, YoseColor.tokiwa][i % 3]
                }
            }
            .ignoresSafeArea()
            .overlay(Rectangle().fill(YoseColor.kuroUrushi.opacity(0.25)).ignoresSafeArea())
            VStack(spacing: 0) {
                Spacer().frame(height: 118)
                signboard
                Spacer(minLength: 12)
                stageTableau
                Spacer(minLength: 12)
                Button(action: onStart) {
                    YoseOutlinedText(text: "はじめる", font: YoseFont.gothic(22, weight: .black),
                                     fill: YoseColor.kinari, outlineColor: YoseColor.sumi, outlineWidth: 1.5, dropShadowY: 1.5)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1).padding(3))
                }
                .buttonStyle(YoseButtonStyle(.primary))
                .padding(.horizontal, YoseMetrics.screenMargin)
                .padding(.bottom, 20)
                crowdBand
            }
            .opacity(lit ? 1 : 0).animation(Theme.Motion.r(.easeOut(duration: 0.5)), value: lit)
        }
        .overlay(alignment: .topTrailing) {
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill").font(.system(size: Font.mzScaled(18), weight: .bold)).foregroundStyle(YoseColor.sumi)
                    .frame(width: 40, height: 40)
                    .background(YoseColor.ki)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))
            }
            .padding(.top, 64).padding(.trailing, 14)
            .accessibilityLabel("設定")
        }
        .overlay(alignment: .topLeading) {
            Button { showBook = true } label: {
                Text("エンディング図鑑").font(YoseFont.gothic(13, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                    .frame(minWidth: 52, minHeight: 40).padding(.horizontal, 6)
                    .background(YoseColor.ki)
                    .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                    .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))
            }
            .padding(.top, 64).padding(.leading, 14)
            .accessibilityLabel("エンディング図鑑")
        }
        .fullScreenCover(isPresented: $showBook) { EndingGalleryView { showBook = false } }
        .sheet(isPresented: $showSettings) { SettingsView { showSettings = false } }
        .onAppear { lit = true }
    }

    /// 寄席大看板（黒漆＋金枠＋朱の内枠）
    private var signboard: some View {
        VStack(spacing: 8) {
            YoseOutlinedText(text: AppInfo.displayName, font: YoseFont.gothic(48, weight: .black),
                             fill: YoseColor.kinari, outlineColor: YoseColor.sumi, outlineWidth: 2.5, dropShadowY: 3)
            Text("――漫才師、育成。").font(YoseFont.mincho(17)).foregroundStyle(YoseColor.kinBright)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 22)
        .background(YoseColor.kuroUrushi)
        .overlay(Rectangle().stroke(YoseColor.shu, lineWidth: 1.5).padding(6))
        .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 3))
        .background(Rectangle().fill(YoseColor.sumi).offset(y: 4))
        .padding(.horizontal, YoseMetrics.screenMargin)
    }

    /// 上手・下手のめくり台＋中央のサンパチマイク
    private var stageTableau: some View {
        HStack(alignment: .bottom, spacing: 26) {
            mekuri(YoseColor.shu, "漫才")
            VStack(spacing: 0) {
                // マイクヘッド（金枠・横スリット3本・中央の金帯）
                VStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { _ in Rectangle().fill(YoseColor.kin.opacity(0.5)).frame(height: 1) }
                }
                .padding(.horizontal, 3).padding(.vertical, 5)
                .frame(width: 24, height: 40)
                .background(YoseColor.kuroUrushi)
                .overlay(Rectangle().fill(YoseColor.kin).frame(height: 4))
                .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1.5))
                Rectangle().fill(YoseColor.kuroUrushi).frame(width: 6, height: 90)
                // 二段の重りベース
                Rectangle().fill(YoseColor.kuroUrushi).frame(width: 32, height: 4)
                Rectangle().fill(YoseColor.kuroUrushi).frame(width: 48, height: 6)
                    .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1))
            }
            mekuri(YoseColor.kin, "四分")
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 14)
        // 高座の床板（めくり台とマイクの脚を接地させる）
        .background(alignment: .bottom) {
            Rectangle().fill(YoseColor.kiDark).frame(height: 22).frame(maxWidth: .infinity)
                .overlay(alignment: .top) { Rectangle().fill(YoseColor.sumi).frame(height: 2.5) }
                .overlay {
                    VStack(spacing: 5) {
                        Rectangle().fill(YoseColor.sumi.opacity(0.28)).frame(height: 1)
                        Rectangle().fill(YoseColor.sumi.opacity(0.28)).frame(height: 1)
                    }.padding(.top, 5)
                }
                .padding(.horizontal, -40)
        }
    }

    private func mekuri(_ band: Color, _ label: String) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(band).frame(height: 14)
            VStack(spacing: 4) {
                ForEach(Array(label), id: \.self) { Text(String($0)).font(YoseFont.mincho(30)).foregroundStyle(YoseColor.sumi) }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: 68, height: 150)
        .background(YoseColor.washi)
        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
        .background(Rectangle().fill(YoseColor.sumi).offset(y: 3))
    }

    /// 観客席（#181210 単色・高さ幅をばらす・金枠なし）
    private var crowdBand: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Self.crowd.indices, id: \.self) { i in
                VStack(spacing: -2) {   // 頭＋肩（客のシルエット）
                    Circle().fill(Color(hex: 0x181210)).frame(width: Self.crowd[i].0 * 0.52, height: Self.crowd[i].0 * 0.52)
                    UnevenRoundedRectangle(topLeadingRadius: Self.crowd[i].0 * 0.45, topTrailingRadius: Self.crowd[i].0 * 0.45)
                        .fill(Color(hex: 0x181210)).frame(width: Self.crowd[i].0, height: Self.crowd[i].1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .bottom).frame(height: 78, alignment: .bottom)
        .clipped()
        .background(alignment: .bottom) {   // 客席の影の下は画面の下端まで黒漆で塗る（定式幕を貫通させない）
            Color(hex: 0x181210).frame(height: 14).background(Color(hex: 0x181210).ignoresSafeArea(edges: .bottom))
        }
        .ignoresSafeArea(edges: .bottom)
    }
}


// MARK: コンビ名入力（ネタ帳見開き）

struct NameEntryView: View {
    var comboKind: ComboKind = .maleMale   // 結成届の薄い文字（俺／私）を形に合わせる
    var onDecide: (String, String?, String?, MeetingKind) -> Void   // コンビ名・自分の名前・相方の名前（空欄＝nil）・出会い方
    @State private var name = ""
    @State private var meeting: MeetingKind = .highSchool   // 出会い方（既定＝①高校の同級生・表示専用）
    @State private var myName = ""
    @State private var partnerName = ""
    @State private var inkWet = false
    @State private var decided = false   // 「結成する！」の二度押しで onDecide が2回走らない（code_review_2026-10-19e §2）
    private var nameBlank: Bool { name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }   // 空白だけは未入力と同じ扱い（§1）
    @FocusState private var focused: Bool

    private static let candidates = ["なんば亭", "ぽんぽこ座", "ドラ焼き兄弟", "三時のおやつ", "ひだまり劇場",
                                     "すっぽん横丁", "ハチミツ堂", "夜更かしバンビ", "ちゃぶ台ガレージ", "しゃべり場"]

    var body: some View {
        VStack(spacing: 0) {
            YoseHeaderBar(title: "コンビ結成")
            VStack(spacing: 14) {
                Text("コンビ名を、決めよう。").font(YoseFont.sectionTitle).foregroundStyle(YoseColor.sumi)
                    .padding(.top, 22)

                // めくり札（横額縁・金の内枠・上に太鼓鋲）に名前を書く
                VStack(spacing: 8) {
                    TextField("", text: $name, prompt: Text("例：なんば亭").foregroundColor(YoseColor.haiSumi.opacity(0.55)))
                        .onChange(of: name) { _, v in if v.count > 12 { name = String(v.prefix(12)) } }
                        .font(YoseFont.mincho(28)).foregroundStyle(YoseColor.sumi)
                        .multilineTextAlignment(.center)
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .focused($focused)
                        .tint(YoseColor.shu)   // 青いカーソルを朱に
                        .submitLabel(.done)
                        .onSubmit(decide)
                    Text("※最大12文字").font(YoseFont.captionBold).foregroundStyle(YoseColor.haiSumi)
                }
                .padding(.vertical, 22).padding(.horizontal, 18)
                .frame(maxWidth: .infinity)
                .yoseHarigami()
                .overlay(RoundedRectangle(cornerRadius: 1).stroke(YoseColor.kin, lineWidth: 1.5).padding(5))   // 四方均等の金の内枠（左帯なし）
                .overlay(alignment: .top) {
                    HStack { rivet; Spacer(); rivet }.padding(.horizontal, 12).padding(.top, 10)
                }
                .overlay(alignment: .bottom) {
                    HStack { rivet; Spacer(); rivet }.padding(.horizontal, 12).padding(.bottom, 10)
                }
                .scaleEffect(inkWet ? 1.03 : 1)
                .padding(.horizontal, YoseMetrics.screenMargin)

                Button {
                    var pick = Self.candidates.randomElement() ?? "なんば亭"
                    if pick == name { pick = Self.candidates.randomElement() ?? pick }
                    withAnimation(Theme.Motion.r(.easeOut(duration: 0.15))) { name = pick }
                    Haptics.confirm()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "dice.fill").font(.system(size: Font.mzScaled(13), weight: .black)).foregroundStyle(YoseColor.kinari).accessibilityHidden(true)   // 飾りの記号＝読み上げは横の文字だけ（a11y_check_1026_voiceover_v0 #6）
                            .frame(width: 24, height: 24).background(YoseColor.enji)
                            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                        Text("おまかせで考える").font(YoseFont.gothic(15, weight: .heavy))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(YoseButtonStyle(.secondary))
                .padding(.horizontal, YoseMetrics.screenMargin)

                // コンビ結成届（書いた名前がそのまま写る）
                VStack(spacing: 8) {
                    Text("コンビ結成届").font(YoseFont.gothic(13, weight: .heavy)).foregroundStyle(YoseColor.kinari)
                        .frame(maxWidth: .infinity).padding(.vertical, 5).background(YoseColor.enji)
                    HStack { Text("コンビ名").font(YoseFont.bodyBold).foregroundStyle(YoseColor.haiSumi)
                        Spacer()
                        Text(name.isEmpty ? "＿＿＿＿＿＿" : name).font(YoseFont.mincho(24)).foregroundStyle(YoseColor.sumi).lineLimit(1).minimumScaleFactor(0.6)
                    }.padding(.horizontal, 14)
                    Rectangle().fill(YoseColor.sumi.opacity(0.4)).frame(height: 1).padding(.horizontal, 14)
                    HStack { Text("自　分").font(YoseFont.bodyBold).foregroundStyle(YoseColor.haiSumi)
                        Spacer()
                        nameField($myName, prompt: comboKind.meFirstPerson)
                    }.padding(.horizontal, 14)
                    Rectangle().fill(YoseColor.sumi.opacity(0.4)).frame(height: 1).padding(.horizontal, 14)
                    HStack { Text("相　方").font(YoseFont.bodyBold).foregroundStyle(YoseColor.haiSumi)
                        Spacer()
                        nameField($partnerName, prompt: "谷口")
                    }.padding(.horizontal, 14)
                    Rectangle().fill(YoseColor.sumi.opacity(0.4)).frame(height: 1).padding(.horizontal, 14)
                    HStack { Text("出会い").font(YoseFont.bodyBold).foregroundStyle(YoseColor.haiSumi)
                        Spacer()
                        meetingMenu
                    }.padding(.horizontal, 14)
                    Rectangle().fill(YoseColor.sumi.opacity(0.4)).frame(height: 1).padding(.horizontal, 14)
                    HStack { Text("結成日").font(YoseFont.bodyBold).foregroundStyle(YoseColor.haiSumi)
                        Spacer()
                        Text("1年目　第1週").font(YoseFont.mincho(18)).foregroundStyle(YoseColor.sumi)
                    }.padding(.horizontal, 14)
                    Rectangle().fill(YoseColor.sumi.opacity(0.4)).frame(height: 1).padding(.horizontal, 14)
                    HStack { Text("目　標").font(YoseFont.bodyBold).foregroundStyle(YoseColor.haiSumi)
                        Spacer()
                        Text("頂グランプリ 優勝").font(YoseFont.mincho(18)).foregroundStyle(YoseColor.sumi)
                    }.padding(.horizontal, 14)
                    // 判子欄：名前を書くと朱印『結成』が押される（空の間は点線の枠だけ）
                    HStack {
                        Spacer()
                        ZStack {
                            Rectangle().stroke(YoseColor.kiDark, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                            if nameBlank {
                                Text("結成印").font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.haiSumi.opacity(0.6))
                            } else {
                                YoseHankoStamp(text: "結成", isSquare: true, angle: -7)
                                    .transition(.scale(scale: 1.6).combined(with: .opacity))
                            }
                        }
                        .frame(width: 72, height: 72)
                        .animation(Theme.Motion.appearQuick, value: nameBlank)
                    }
                    .padding(.horizontal, 14).padding(.top, 6).padding(.bottom, 14)
                }
                .frame(maxWidth: .infinity)
                .yoseHarigami()
                .padding(.horizontal, YoseMetrics.screenMargin)
                .padding(.top, 8)
                Spacer(minLength: 0)
                // 書類（結成届）に名前を書いたら、いちばん下の主ボタンで出す＝視線が上から下へ流れる
                if nameBlank {
                    Text("名前を書くと「結成する！」が押せます").font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.shu)
                }
                Button(action: decide) {
                    Text("結成する！").font(YoseFont.gothic(18, weight: .heavy))
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(YoseButtonStyle(.primary))
                .disabled(nameBlank)
                .padding(.horizontal, YoseMetrics.screenMargin)
                .padding(.bottom, 16)
            }
        }
        .background(YoseColor.kinari.ignoresSafeArea())
        .onAppear { focused = true }
    }

    /// 結成届の名前欄（全角6字まで・空欄＝既定の名前のまま）
    private func nameField(_ text: Binding<String>, prompt: String) -> some View {
        HStack(spacing: 6) {
            TextField("", text: text, prompt: Text(verbatim: prompt).foregroundColor(YoseColor.haiSumi.opacity(0.55)))
                .onChange(of: text.wrappedValue) { _, v in if v.count > Names.maxLength { text.wrappedValue = String(v.prefix(Names.maxLength)) } }
                .font(YoseFont.mincho(20)).foregroundStyle(YoseColor.sumi)
                .multilineTextAlignment(.trailing).lineLimit(1).minimumScaleFactor(0.6)
                .submitLabel(.done).tint(YoseColor.shu)
                .overlay(alignment: .bottom) { Rectangle().fill(YoseColor.haiSumi.opacity(0.6)).frame(height: 1).offset(y: 2) }   // 書ける欄だと分かる下線（コンビ名の行と同じ・firstlook_check_1027c #9）
            Text("（6字まで）").font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
        }
        .frame(maxWidth: 190)
    }

    /// 出会い方の選択（結成届の1行・押すと4つから選べる。決めた後の回想がこの型で流れる）
    private var meetingMenu: some View {
        Menu {
            Picker("出会い方", selection: $meeting) {
                ForEach(MeetingKind.allCases, id: \.self) { m in Text(m.label).tag(m) }
            }
        } label: {
            HStack(spacing: 6) {
                Text(meeting.label).font(YoseFont.mincho(18)).foregroundStyle(YoseColor.sumi)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: Font.mzScaled(11), weight: .bold))
                    .foregroundStyle(YoseColor.haiSumi)
            }
        }
        .accessibilityLabel("出会い方、\(meeting.label)")
        .accessibilityHint("押すと出会い方を選べる")   // a11y_check_1026 低5
    }

    private var rivet: some View {
        Circle().fill(YoseColor.kuroUrushi).frame(width: 8, height: 8)
            .overlay(Circle().stroke(YoseColor.kin, lineWidth: 1))
    }

    private func decide() {
        guard !decided else { return }
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        decided = true
        withAnimation(Theme.Motion.r(.easeOut(duration: 0.4))) { inkWet = true }   // 札が一瞬ふくらむ（書いた名前が決まる手応え）
        Haptics.confirm()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { onDecide(name, Names.clean(myName).isEmpty ? nil : Names.clean(myName), Names.clean(partnerName).isEmpty ? nil : Names.clean(partnerName), meeting) }
    }
}


// MARK: フロー統合（title → comboKind → nameEntry（名前＋出会い方）→ reminiscence → onComplete）

// MARK: S1c 通知許諾プリプロンプト（白面カード・イラスト無し・「消えます」/残り時間は出さない）

struct NotificationPromptView: View {
    var onDecide: () -> Void
    @AppStorage("notif_asked") private var asked = false
    @AppStorage("notif_snooze_until") private var snoozeUntil: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            // 臙脂の帯＋寄席文字風の見出し（週メイン・設定と同じ）
            Text("お知らせ").font(.maru(24, weight: .black)).foregroundStyle(Theme.kinari)
                .frame(maxWidth: .infinity).padding(.top, 64).padding(.bottom, 16)
                .background(LinearGradient(colors: [Theme.curtainLit, Theme.curtain], startPoint: .top, endPoint: .bottom).ignoresSafeArea(edges: .top))
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.gold).frame(height: 2) }
            Spacer()
            // 読み物の欄（押せない物はカードにしない＝墨の罫と朱の左帯だけ）
            VStack(alignment: .leading, spacing: Theme.Sp.s12) {
                Text("大会の開演前に、\nお知らせします。")
                    .font(.maru(22, weight: .heavy)).lineSpacing(6).foregroundStyle(Theme.sumi)
                Text("また続きをやりに来られるように。")
                    .font(.maru(.body)).foregroundStyle(Theme.inkSub)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 20).padding(.trailing, 16).padding(.vertical, Theme.Sp.s16)
            .background(Theme.kinariPanel)
            .overlay(alignment: .leading) { Rectangle().fill(Theme.verm).frame(width: 5) }
            .overlay(alignment: .top) { Rectangle().fill(Theme.sumi).frame(height: 1.5) }
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.sumi).frame(height: 1.5) }
            .padding(.horizontal, Theme.Sp.s24)
            Spacer()
            VStack(spacing: Theme.Sp.s16) {
                Button(action: allow) {
                    Text("知らせてもらう").font(.maru(.title)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Theme.verm, in: RoundedRectangle(cornerRadius: Theme.Rad.btn))
                        .shadow(color: Theme.vermD, radius: 0, y: 3)
                }.buttonStyle(PressableStyle())
                Button(action: later) {
                    Text("あとで").font(.maru(.body)).foregroundStyle(Theme.inkSub)
                        .underline().frame(minHeight: 44)
                }.buttonStyle(PressableStyle())
            }
            .padding(.horizontal, Theme.Sp.s32).padding(.bottom, Theme.Sp.s32)
        }
        .background(Theme.kinari.ignoresSafeArea())
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
    var onComplete: (String, String?, String?, ComboKind, MeetingKind) -> Void
    @State private var stage: Stage = IntroFlowView.initialStage
    @State private var name = "あなたのコンビ"
    @State private var myName: String? = nil
    @State private var partnerName: String? = nil
    @State private var kind: ComboKind = IntroFlowView.initialKind
    @State private var meeting: MeetingKind = IntroFlowView.initialMeeting
    private enum Stage { case title, comboKind, nameEntry, reminiscence, notif }

    private func finish() { onComplete(name, myName, partnerName, kind, meeting) }

    private static var initialMeeting: MeetingKind {
        #if DEBUG
        if let m = MeetingKind.debugForced { return m }
        #endif
        return .highSchool
    }

    /// 導入（回想3場面）を最後まで見た記録。周回をまたぐ（GameSession.store＝UserDefaults）。2周目以降だけ「とばす ▶」を出す。
    static let seenKey = "manzai.introSeen.v1"
    static var hasSeenIntro: Bool { GameSession.store.bool(forKey: seenKey) }
    static func markIntroSeen() { GameSession.store.set(true, forKey: seenKey) }

    /// 目視用: MZ_UI=intro_name で名前決めへ直行する時、MZ_KIND の形で結成届を出す（本編は形を選ぶ画面で必ず上書き）
    private static var initialKind: ComboKind {
        #if DEBUG
        if let k = ProcessInfo.processInfo.environment["MZ_KIND"].flatMap({ ComboKind(rawValue: $0) }) { return k }
        #endif
        return .maleMale
    }

    private static var initialStage: Stage {
        #if DEBUG
        if ProcessInfo.processInfo.environment["MZ_UI"] == "intro_name" {   // 目視用: 名前決めへ直行（MZ_KIND があれば結成届の「俺／私」もその形で）
            if let k = ProcessInfo.processInfo.environment["MZ_KIND"].flatMap({ ComboKind(rawValue: $0) }) { Names.setKind(k) }
            return .nameEntry
        }
        if ProcessInfo.processInfo.environment["MZ_UI"] == "combokind" { return .comboKind }   // 目視用: コンビの形を選ぶ画面へ直行
        if MeetingKind.debugForced != nil { return .reminiscence }   // 目視用: MZ_MEET=1〜4 で回想をその型で直接流す
        #endif
        return .title
    }

    /// ①高校の同級生の回想（RootView の MZ_UI=intro 目視・旧呼び出し用）。型ごとの文は MeetingKind.cards
    static var cards: [ReminiscenceCard] { MeetingKind.highSchool.cards }

    var body: some View {
        ZStack {
            switch stage {
            case .title:
                S1TitleView { withAnimation(Theme.Motion.r(.easeInOut(duration: 0.4))) { stage = .comboKind } }
                    .transition(.opacity)
            case .comboKind:
                ComboKindPickerView { k in
                    kind = k
                    Names.setKind(k)   // 結成届・回想の「俺／私」・顔・衣装が選んだ形で出る
                    withAnimation(Theme.Motion.r(.easeInOut(duration: 0.4))) { stage = .nameEntry }
                }
                .transition(.opacity)
            case .nameEntry:
                // 名前と出会い方を決めてから回想（キュー63・オーナー決定 10/20）。回想は入れた名前・選んだ型で流す
                NameEntryView(comboKind: kind) { n, me, partner, m in
                    name = n.isEmpty ? "あなたのコンビ" : n
                    myName = me; partnerName = partner; meeting = m
                    Names.set(me: me, partner: partner)
                    withAnimation(Theme.Motion.r(.easeInOut(duration: 0.4))) { stage = .reminiscence }
                }
                .transition(.opacity)
            case .reminiscence:
                ReminiscencePlayer(
                    cards: meeting.cards,
                    onComplete: { Self.markIntroSeen(); finish() },
                    onSkip: Self.hasSeenIntro ? { finish() } : nil)
                    .transition(.opacity)
            case .notif:
                // 通知機能が1本も実装されていない間は許諾を求めない（初週前の摩擦だけが残るため導線から外す）。
                // NotificationPromptView 本体と MZ_UI=notif は通知実装時に復帰させる（休眠温存）。
                NotificationPromptView { finish() }
                    .transition(.opacity)
            }
        }
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
