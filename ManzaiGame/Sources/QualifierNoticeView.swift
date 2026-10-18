// QualifierNoticeView.swift
// 頂GP 予選（1回戦〜準々決勝）の結果の知らせ方（docs/result_reveal_m1_research_v0.md §2・案B→案C の段階づけ）。
// 1〜3回戦＝スマホのロック画面に通知→タップで開く→通過者一覧（自組の名前を目で探す）。
// 準々決勝＝相方からのメッセージ（トーク風）。表示だけ：判定・乱数・golden には触れない。
// 数字・順位・点・通過ライン・通過組数は出さない（一覧の長さは通過/落選で同じ）。実在サービス名・ロゴは使わない。【仮デザイン】

import SwiftUI

struct QualifierNoticeView: View {
    let combiName: String
    let partnerName: String
    let year: Int
    let roundName: String      // "GP1回戦" 等
    let passed: Bool
    let onFinish: () -> Void

    static func applies(_ name: String) -> Bool { ["GP1回戦", "GP2回戦", "GP3回戦", "GP準々決勝"].contains(name) }
    private var isChat: Bool { roundName == "GP準々決勝" }
    private var roundLabel: String { roundName.replacingOccurrences(of: "GP", with: "") }

    private enum Stage { case lock, list, chat }
    @State private var stage: Stage = .lock
    @State private var noticeIn = false
    @State private var scanned = false          // 一覧を最後まで見終えた（自組が光る）
    @State private var msgs = 0                 // トークの表示済み件数
    @State private var chosen = false           // 「開く」を選んだ
    @State private var chosenText = "開く"       // 吹き出しに出す自分の返事
    @State private var task: Task<Void, Never>?

    private var rowNames: [String] {
        let mobs = FinalsData.yearRoster(year: year &+ roundName.count &* 31, selfName: combiName, count: passed ? 8 : 9)
        var arr = mobs
        if passed { arr.append(combiName) }
        let selfY = combiName.applyingTransform(.hiraganaToKatakana, reverse: true) ?? combiName
        return arr.sorted { (FinalistAnnounceView.yomi[$0] ?? selfY) < (FinalistAnnounceView.yomi[$1] ?? selfY) }
    }

    private var resultLines: [String] { passed ? ["あった！", "名前、あった！！", "やった……"] : ["…………", "次いこ"] }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1B2230), Color(hex: 0x0B0E14)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            switch stage {
            case .lock: lockScreen.transition(.opacity)
            case .list: listScreen.transition(.opacity)
            case .chat: chatScreen.transition(.opacity)
            }
            VStack { HStack { Spacer()
                Button { finish() } label: {
                    Text("飛ばす").font(YoseFont.gothic(13)).foregroundStyle(YoseColor.ginNezu).padding(.horizontal, 12).padding(.vertical, 6)
                        .overlay(Capsule().stroke(YoseColor.ginNezu.opacity(0.5)))
                }
            }.padding(.top, 54).padding(.trailing, 16); Spacer() }
        }
        .onAppear { start() }
        .onDisappear { task?.cancel() }
    }

    // MARK: ロック画面＋通知
    private var lockScreen: some View {
        VStack(spacing: 6) {
            Spacer().frame(height: 110)
            Text("21:04").font(.system(size: 72, weight: .thin)).foregroundStyle(.white.opacity(0.9))
            Spacer()
            if noticeIn {
                Button { open() } label: {
                    HStack(alignment: .top, spacing: 10) {
                        RoundedRectangle(cornerRadius: 9).fill(YoseColor.kin).frame(width: 38, height: 38)
                            .overlay(Image(systemName: isChat ? "bubble.left.fill" : "megaphone.fill").foregroundStyle(YoseColor.kuroUrushi))
                        VStack(alignment: .leading, spacing: 3) {
                            HStack { Text(isChat ? partnerName : "頂GP公式").font(YoseFont.gothic(13, weight: .bold)); Spacer(); Text("いま").font(YoseFont.gothic(11)).foregroundStyle(.white.opacity(0.5)) }
                            Text(isChat ? "見た？" : "【結果発表】\(roundLabel)の通過者を掲載しました").font(YoseFont.gothic(13)).multilineTextAlignment(.leading)
                        }.foregroundStyle(.white)
                    }
                    .padding(12).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 14)
                }
                .buttonStyle(.plain).transition(.move(edge: .top).combined(with: .opacity))
                Text("通知をタップ").font(YoseFont.gothic(12)).foregroundStyle(.white.opacity(0.45)).padding(.top, 8)
            }
            Spacer().frame(height: 90)
        }
    }

    // MARK: 通過者一覧
    private var listScreen: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("頂GP公式").font(YoseFont.gothic(14, weight: .bold)).foregroundStyle(YoseColor.kin)
                Text("\(roundLabel) 通過者").font(YoseFont.mincho(22)).foregroundStyle(.white)
            }.padding(.top, 96).padding(.bottom, 14)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(rowNames, id: \.self) { n in
                        let me = n == combiName
                        HStack {
                            Text(n).font(YoseFont.mincho(18)).foregroundStyle(me && scanned ? YoseColor.kinBright : .white.opacity(0.88))
                            Spacer()
                        }
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .background(me && scanned ? YoseColor.kin.opacity(0.22) : .clear)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(YoseColor.kinBright.opacity(me && scanned ? 0.9 : 0), lineWidth: 1.5))
                        .shadow(color: YoseColor.kinBright.opacity(me && scanned ? 0.7 : 0), radius: 10)
                        Divider().background(.white.opacity(0.12))
                    }
                }
            }
            .padding(.horizontal, 14)
            if !scanned {
                Text("タップで次へ").font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(.white.opacity(0.55))
                    .padding(.vertical, 22).transition(.opacity)
            }
            if scanned {
                Button { finish() } label: {
                    Text(passed ? "つづける" : "閉じる").font(YoseFont.gothic(16, weight: .heavy)).foregroundStyle(passed ? YoseColor.kuroUrushi : YoseColor.washi)
                        .padding(.horizontal, 44).padding(.vertical, 11)
                        .background(passed ? YoseColor.kinBright : .clear, in: Capsule())
                        .overlay(Capsule().stroke(YoseColor.ginNezu.opacity(passed ? 0 : 0.6)))
                }.padding(.vertical, 18).transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if !scanned { withAnimation { scanned = true } } }
    }

    // MARK: 相方とのトーク
    private var chatScreen: some View {
        VStack(spacing: 0) {
            Text(partnerName).font(YoseFont.gothic(16, weight: .bold)).foregroundStyle(.white).padding(.top, 96).padding(.bottom, 12)
            ScrollView {
                VStack(spacing: 10) {
                    bubble(false, "見た？")
                    if msgs >= 1 { bubble(false, "まだ開いてへん。こわいわ") }
                    if chosen { bubble(true, chosenText) }
                    if chosen && msgs >= 3 { Text("既読").font(YoseFont.gothic(10)).foregroundStyle(.white.opacity(0.4)).frame(maxWidth: .infinity, alignment: .trailing) }
                    ForEach(0..<max(0, msgs - 2), id: \.self) { i in
                        if i < resultLines.count { bubble(false, resultLines[i]) }
                    }
                }.padding(.horizontal, 16)
            }
            if !chosen && msgs >= 1 {
                HStack(spacing: 12) {
                    choice("開く") { pickOpen("開く") }
                    choice("あとで") { pickOpen("……いま開く") }
                }.padding(.vertical, 18).transition(.opacity)
            } else if msgs >= 2 + resultLines.count {
                Button { finish() } label: {
                    Text("つづける").font(YoseFont.gothic(16, weight: .heavy)).foregroundStyle(passed ? YoseColor.kuroUrushi : YoseColor.washi)
                        .padding(.horizontal, 44).padding(.vertical, 11).background(passed ? YoseColor.kinBright : .clear, in: Capsule())
                        .overlay(Capsule().stroke(YoseColor.ginNezu.opacity(passed ? 0 : 0.6)))
                }.padding(.vertical, 18).transition(.opacity)
            } else { Spacer().frame(height: 70) }
        }
    }

    private func bubble(_ mine: Bool, _ t: String) -> some View {
        HStack {
            if mine { Spacer() }
            Text(t).font(YoseFont.gothic(15)).foregroundStyle(mine ? YoseColor.kuroUrushi : .white)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(mine ? YoseColor.kinBright : Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))
            if !mine { Spacer() }
        }.transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func choice(_ t: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(t).font(YoseFont.gothic(15, weight: .bold)).foregroundStyle(.white)
                .padding(.horizontal, 30).padding(.vertical, 10).overlay(Capsule().stroke(.white.opacity(0.5)))
        }
    }

    // MARK: 進行
    private func start() {
        guard task == nil else { return }
        #if DEBUG
        if let o = ProcessInfo.processInfo.environment["MZ_OPEN"] {   // 目視用：1=通知を開いた後から／2=さらに「開く」を選んだ後から
            open()
            if o == "2" { Task { try? await Task.sleep(nanoseconds: 1_500_000_000); pickOpen() } }
            return
        }
        #endif
        task = Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if Task.isCancelled { return }
            withAnimation(.spring(duration: 0.5)) { noticeIn = true }
            Sound.play(.cursor); Haptics.rare()
        }
    }

    private func open() {
        guard stage == .lock else { return }
        task?.cancel()
        Sound.play(.tap)
        withAnimation(.easeInOut(duration: 0.35)) { stage = isChat ? .chat : .list }
        task = Task {
            if isChat {
                try? await Task.sleep(nanoseconds: 900_000_000)
                withAnimation { msgs = 1 }
            } else {
                try? await Task.sleep(nanoseconds: 3_200_000_000)   // 目で探す間
                if Task.isCancelled { return }
                withAnimation(.easeOut(duration: 0.4)) { scanned = true }
                if passed { Sound.play(.success); Haptics.rare() }
            }
        }
    }

    private func pickOpen(_ text: String = "開く") {
        guard !chosen else { return }
        chosenText = text
        Sound.play(.tap)
        withAnimation { chosen = true; msgs = 2 }
        task?.cancel()
        task = Task {
            try? await Task.sleep(nanoseconds: passed ? 1_100_000_000 : 2_600_000_000)   // 落選は既読のまま無音の間
            for i in 0..<resultLines.count {
                if Task.isCancelled { return }
                withAnimation { msgs = 3 + i }
                if passed { Sound.play(.tap) }
                try? await Task.sleep(nanoseconds: passed ? 800_000_000 : 1_400_000_000)
            }
            if passed { Sound.play(.success) }
        }
    }

    private func finish() { task?.cancel(); onFinish() }
}
