// FinalistAnnounceView.swift
// 頂GP 準決勝の後の「決勝進出者の発表」（docs/result_reveal_m1_research_v0.md §3）。4画面・約40秒。
// 表示だけ：判定・乱数・golden には触れない。読み上げは五十音順＝成績の手がかりにしない。
// 数字・順位・点・通過ライン・決勝の枠数は出さない。敗者復活の案内は、呼ばれなかった時だけ司会が最後に一言（Q14）。

import SwiftUI

struct FinalistAnnounceView: View {
    let combiName: String
    let year: Int
    let passed: Bool
    let onFinish: () -> Void

    private enum Stage { case wait, line, read, after }
    @State private var stage: Stage = .wait
    @State private var called = 0            // 読み上げ済みの組数
    @State private var lastCallFlash = false
    @State private var dim = false           // 最後の2組の溜め
    @State private var task: Task<Void, Never>?
    @State private var skipStep = false

    /// 読み上げの1組（五十音順）。自組も同じ並びに入る
    private struct Slot: Identifiable { let id: Int; let name: String; let yomi: String; let isSelf: Bool; let finalist: Bool }

    static let yomi: [String: String] = [
        "紺屋": "こうや", "夜明けの犬": "よあけのいぬ", "サーカス": "さあかす", "青写真": "あおじゃしん", "十三": "じゅうそう",
        "深夜のグラタン": "しんやのぐらたん", "テレフォン": "てれふぉん", "北緯": "ほくい", "帰り道": "かえりみち",
        "灯台守": "とうだいもり", "三番線": "さんばんせん", "東口": "ひがしぐち", "ペンギン座": "ぺんぎんざ", "トランジスタ": "とらんじすた",
        "まどろみ": "まどろみ", "夕凪": "ゆうなぎ", "赤鉛筆": "あかえんぴつ", "合鍵": "あいかぎ", "日めくり": "ひめくり",
        "回送電車": "かいそうでんしゃ", "白湯": "さゆ", "角部屋": "かどべや", "手旗信号": "てばたしんごう", "満月書店": "まんげつしょてん",
        "栞": "しおり", "小春日和": "こはるびより", "遠回り": "とおまわり", "置き手紙": "おきてがみ", "二重丸": "にじゅうまる",
        "冬支度": "ふゆじたく", "屋上庭園": "おくじょうていえん", "古時計": "ふるどけい", "紙飛行機": "かみひこうき", "宵の口": "よいのくち",
        "渡り廊下": "わたりろうか", "給水塔": "きゅうすいとう", "綿雲": "わたぐも", "画鋲": "がびょう", "天気雨": "てんきあめ",
        "終着駅": "しゅうちゃくえき", "星見台": "ほしみだい", "曇天予報": "どんてんよほう", "迷い猫": "まよいねこ", "番台": "ばんだい",
        "薄荷": "はっか", "定食屋": "ていしょくや", "乾電池": "かんでんち", "空き瓶": "あきびん", "通り雨": "とおりあめ", "裏木戸": "うらきど",
    ]

    /// 決勝の他組（決勝の画面と同じ名簿：年だけで決まる）。落選の年は10組すべて他組（観客版の決勝と同じ）
    private var finalistNames: [String] { FinalsData.yearRoster(year: year, selfName: combiName, count: passed ? 9 : 10) }
    /// 会場に並ぶ全員（決勝に進む組＋進めなかった組の影）。進めなかった組は名前を持たない（読まれない）
    private var slots: [Slot] {
        var arr: [Slot] = finalistNames.enumerated().map { Slot(id: $0.offset, name: $0.element, yomi: Self.yomi[$0.element] ?? $0.element, isSelf: false, finalist: true) }
        arr.append(Slot(id: 100, name: combiName, yomi: "", isSelf: true, finalist: passed))
        for i in 0..<5 { arr.append(Slot(id: 200 + i, name: "", yomi: "", isSelf: false, finalist: false)) }
        // 並びは年で決まる決定論シャッフル（自組は列の真ん中寄りに置く）
        var seed = UInt64(bitPattern: Int64(year &* 2654435761 &+ 17))
        func nx() -> Int { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Int((seed >> 33) % 1000) }
        for i in stride(from: arr.count - 1, through: 1, by: -1) { arr.swapAt(i, nx() % (i + 1)) }
        if let si = arr.firstIndex(where: { $0.isSelf }) { arr.swapAt(si, arr.count / 2 + arr.count / 4) }   // 前列の真ん中寄り（列の端だと名札が画面からはみ出す）
        return arr
    }
    /// 読み上げ順（五十音順）。自組は名前を読みに直せない＝先頭の仮名で置く（読みは名前そのものに近い仮名と見なす）
    private var readOrder: [Slot] {
        let selfYomi = combiName.applyingTransform(.hiraganaToKatakana, reverse: true) ?? combiName
        return slots.filter { $0.finalist }
            .map { $0.isSelf ? Slot(id: $0.id, name: $0.name, yomi: selfYomi, isSelf: true, finalist: true) : $0 }
            .sorted { $0.yomi < $1.yomi }
    }
    private func isCalled(_ s: Slot) -> Bool { readOrder.prefix(called).contains { $0.id == s.id } }
    private var selfCalled: Bool { passed && readOrder.prefix(called).contains { $0.isSelf } }
    private var caption: String {
        switch stage {
        case .wait: return "準決勝の終演から、しばらく。"
        case .line: return "舞台に、準決勝を終えた組が並ぶ。"
        case .read:
            if called == 0 { return "決勝に進む組が、読み上げられる。" }
            if let cur = readOrder.prefix(called).last { return cur.isSelf ? "——\(cur.name)。" : cur.name }
            return ""
        case .after: return passed ? "以上の組が、決勝に進む。" : "以上の組が、決勝に進む。\n呼ばれなかった皆さん、\n敗者復活戦は決勝当日です。"
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [YoseColor.kuroUrushi, Color(hex: 0x2A211C)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer(minLength: 90)
                if stage == .wait {
                    Image(systemName: "building.columns").font(.system(size: 54)).foregroundStyle(YoseColor.kin.opacity(0.6))
                        .transition(.opacity)
                    Text(caption).font(YoseFont.mincho(17)).foregroundStyle(YoseColor.washi)
                        .multilineTextAlignment(.center).frame(minHeight: 44).id(caption).transition(.opacity)
                } else {
                    mcBlock.transition(.opacity)
                    lineUp.transition(.opacity)
                }
                Spacer()
                if stage == .after {
                    Button { if passed { Sound.play(.success) }; onFinish() } label: {
                        Text("つづける").font(YoseFont.gothic(16)).foregroundStyle(YoseColor.washi)
                            .padding(.horizontal, 40).padding(.vertical, 11).overlay(Capsule().stroke(YoseColor.ginNezu.opacity(0.6)))
                    }.transition(.opacity)
                }
                Color.clear.frame(height: 30)   // 固定：上下の余白を上と真ん中の Spacer で等分＝並びが画面の中ほどに来る
            }
            .padding(.horizontal, 16)
            Color.black.opacity(dim ? 0.45 : 0).ignoresSafeArea().allowsHitTesting(false)   // 最後の2組の溜め
            if stage != .after { VStack { HStack { Spacer()   // 終わりの画面では消す（「つづける」と並んで迷う・playtest_v12 §2-1）
                Button { skipAll() } label: {
                    Text("飛ばす").font(YoseFont.gothic(13)).foregroundStyle(YoseColor.ginNezu).padding(.horizontal, 12).padding(.vertical, 6)
                        .overlay(Capsule().stroke(YoseColor.ginNezu.opacity(0.5)))
                }
            }.padding(.top, 54).padding(.trailing, 16); Spacer() }.transition(.opacity) }
        }
        .contentShape(Rectangle())
        .onTapGesture { tapAdvance() }
        .onAppear { start() }
        .onDisappear { task?.cancel() }
        #if DEBUG
        .onAppear {   // 目視用：MZ_HOLD_AT=読み上げ済み組数 で読み上げをその位置で止める
            if let n = Int(ProcessInfo.processInfo.environment["MZ_HOLD_AT"] ?? "") { task?.cancel(); stage = .read; called = n }
        }
        #endif
    }

    /// 司会（MC）：マイクを持つ人物と、読み上げの吹き出し（名前は1組ずつ）
    private var mcBlock: some View {
        let big = stage == .read && called > 0
        let hot = selfCalled && stage == .read && readOrder.prefix(called).last?.isSelf == true
        return VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 16) {
                VStack(spacing: 2) {
                    ZStack(alignment: .top) {
                        Capsule().fill(YoseColor.kin.opacity(0.9)).frame(width: 40, height: 66)
                        Circle().fill(YoseColor.kinBright).frame(width: 24, height: 24).offset(y: -13)
                        Image(systemName: "mic.fill").font(.system(size: 16)).foregroundStyle(YoseColor.kuroUrushi).offset(x: 18, y: 30)
                    }.frame(height: 76)
                    Text("司会").font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.kin)
                }
                .frame(width: 56)
                Text(caption)
                    .font(YoseFont.mincho(big ? 26 : 16))
                    .foregroundStyle(hot ? YoseColor.kinBright : YoseColor.kuroUrushi)
                    .multilineTextAlignment(.center).minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(hot ? Color.black.opacity(0.85) : YoseColor.washi.opacity(0.95), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(YoseColor.kin, lineWidth: hot ? 2 : 1))
                    .id(caption).transition(.opacity)
            }
        }
        .padding(.bottom, 20)
    }

    /// 並び：2段のシルエット。呼ばれた組は半歩前へ出て光る（名前は小さく添える）
    private var lineUp: some View {
        let all = slots
        let rows = [Array(all.prefix(all.count / 2)), Array(all.suffix(all.count - all.count / 2))]
        return VStack(spacing: 26) {
            ForEach(0..<2, id: \.self) { r in
                HStack(spacing: 8) {
                    ForEach(rows[r]) { s in silhouette(s) }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// 自分たちの印＝コンビ名（長ければ7文字で省略・初期名「あなたのコンビ」は切らない）
    private var selfLabel: String { combiName.count > 7 ? String(combiName.prefix(7)) + "…" : combiName }

    private func silhouette(_ s: Slot) -> some View {
        let on = stage == .read && isCalled(s)
        let done = stage == .after || (stage == .read && !dim && false)
        let lost = stage == .after && !s.finalist
        return VStack(spacing: 3) {
            ZStack(alignment: .top) {
                Capsule().fill(on || (stage == .after && s.finalist) ? YoseColor.kin.opacity(0.9) : YoseColor.ginNezu.opacity(0.42))
                    .frame(width: 30, height: 50)
                Circle().fill(on || (stage == .after && s.finalist) ? YoseColor.kinBright : YoseColor.ginNezu.opacity(0.6)).frame(width: 17, height: 17).offset(y: -10)
            }
            .frame(height: 60)
            .overlay(alignment: .bottom) {
                if s.isSelf { Capsule().stroke(YoseColor.kinBright, lineWidth: 1.5).frame(width: 38, height: 68).offset(y: 4) }
            }
            .offset(y: on || (stage == .after && s.finalist) ? (s.isSelf && on ? -14 : -8) : 0)
            .shadow(color: s.isSelf && on ? YoseColor.kinBright.opacity(0.9) : .clear, radius: 10)
            .opacity(lost ? 0.35 : 1)
            Text(" ").font(YoseFont.gothic(13))   // 名札の高さ確保（名札本体は overlay＝横にはみ出しても隣を押さない）
                .overlay(alignment: .top) {
                    if s.isSelf {
                        Text(selfLabel).font(YoseFont.gothic(13).weight(.bold)).foregroundStyle(YoseColor.kinBright)
                            .lineLimit(1).fixedSize()
                            .shadow(color: YoseColor.kin.opacity(on ? 0.9 : 0.4), radius: on ? 6 : 2)
                            .scaleEffect(on ? 1.18 : 1)
                    }
                }
        }
        .animation(s.isSelf ? .spring(response: 0.35, dampingFraction: 0.45) : .easeOut(duration: 0.35), value: on)
        .frame(width: 38)
        .accessibilityHidden(done)
    }

    // MARK: 進行
    private func start() {
        guard task == nil else { return }
        task = Task { await run() }
    }

    private func pause(_ sec: Double) async {
        let steps = Int(sec * 20)
        for _ in 0..<max(1, steps) {
            if Task.isCancelled || skipStep { break }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        skipStep = false
    }

    private func run() async {
        Sound.bgm(.tension)
        await pause(4)                                                      // ① 待ちの1枚
        if Task.isCancelled { return }
        withAnimation(.easeInOut(duration: 0.5)) { stage = .line }
        Sound.play(.cursor)
        await pause(5)                                                      // ② 並ぶ
        if Task.isCancelled { return }
        withAnimation(.easeInOut(duration: 0.4)) { stage = .read }
        await pause(2.5)
        let order = readOrder
        for i in 0..<order.count {                                          // ③ 読み上げ（最後の2組に溜め）
            if Task.isCancelled { return }
            let last2 = i >= order.count - 2
            if last2 { withAnimation(.easeInOut(duration: 0.6)) { dim = true }; Sound.play(.drumroll); await pause(1.6) }
            if Task.isCancelled { return }
            withAnimation(.easeOut(duration: 0.3)) { called = i + 1 }
            if order[i].isSelf { Sound.play(.success); Haptics.rare() } else { Sound.play(.tap) }
            await pause(last2 ? 2.4 : 1.7)
        }
        if Task.isCancelled { return }
        withAnimation(.easeInOut(duration: 0.8)) { dim = false; stage = .after }   // ④
        if passed { Sound.play(.applauseSmall) }
    }

    private func tapAdvance() { if stage != .after { skipStep = true } }

    private func skipAll() {
        task?.cancel()
        withAnimation(.easeInOut(duration: 0.3)) { dim = false; called = readOrder.count; stage = .after }
    }
}
