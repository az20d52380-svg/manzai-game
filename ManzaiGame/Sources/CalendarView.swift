// CalendarView.swift
// S4 年間カレンダー（正本: uiux_vision_reply_part2 §S4・難度低）。
// 紙のマス目 縦12行(月)×4列(週)=48セル。過去週=実行カテゴリ色の小ドット／現在週=verm縁＋照明の呼吸／
// 大会週=朱の丸印。上部に年サマリ1行。読み取り専用（タップで状態変更なし・RNG非消費・golden非対象）。
// 週履歴は GameSession.categoryLog（表示専用getter）を流用。

import SwiftUI
import GameCore

struct CalendarView: View {
    let session: GameSession
    var onClose: () -> Void

    @State private var breathe = false
    @State private var toast: String?

    private var cal: CalendarConfig { session.config.calendar }
    private var weeks: Int { session.config.weeks }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.paperTop, Theme.paperBottom], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 0) {
                header
                VStack(spacing: Theme.Sp.s12) {
                    summary
                    grid
                    legend   // 凡例は表のすぐ下
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Theme.Sp.s16).padding(.top, Theme.Sp.s12)
            }

            if let toast {
                Text(toast).font(.maru(12)).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Theme.pillDark, in: Capsule())
                    .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 40)
                    .transition(.opacity)
            }
        }
        .onAppear { breathe = true }
    }

    /// 劇場の香盤表の見出し＝臙脂の帯＋金の罫線（週のメイン画面と同じ色）。
    private var header: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Theme.goldLeafHi).frame(height: 1).frame(maxWidth: .infinity)
            Text("年間香盤").font(.maru(22, weight: .black)).tracking(4).foregroundStyle(Theme.goldLeafHi)
                .shadow(color: .black.opacity(0.5), radius: 0, x: 1, y: 1)
            Rectangle().fill(Theme.goldLeafHi).frame(height: 1).frame(maxWidth: .infinity)
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(Theme.goldLeafHi)
                    .frame(width: 34, height: 34)
                    .overlay(Rectangle().stroke(Theme.goldLeafMid, lineWidth: 1))
            }.buttonStyle(PressableStyle())
        }
        .padding(.horizontal, 14).padding(.top, 54).padding(.bottom, 8)
        .background(LinearGradient(colors: [Theme.curtainLit, Theme.curtain], startPoint: .top, endPoint: .bottom).ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.goldLeafMid).frame(height: 2) }
    }

    private var summary: some View {
        VStack(spacing: 4) {
            Text("\(session.combiName)").font(.maru(17, weight: .black)).foregroundStyle(Theme.sumi)
            Text("\(session.year)年目 ・ 第\(session.week)週 ・ 賞金 ¥\(session.totalPrize.formatted())")
                .font(.maru(11)).monospacedDigit().foregroundStyle(Theme.inkDim)
        }
    }

    // 12行(月)×4列(週)＝罫線だけの番付表
    private var grid: some View {
        VStack(spacing: 0) {
            ForEach(0..<12, id: \.self) { row in
                HStack(spacing: 0) {
                    Text(monthLabel(row)).font(.maru(14, weight: .black)).monospacedDigit()
                        .foregroundStyle(Theme.sumi).frame(width: 40)
                        .frame(maxHeight: .infinity)
                        .background(Color(hex: 0xEFE3C8))
                        .overlay(alignment: .trailing) { Rectangle().fill(Theme.sumi).frame(width: 1) }
                    ForEach(0..<4, id: \.self) { col in
                        cell(week: row * 4 + col + 1)
                            .overlay(alignment: .leading) { if col > 0 { Rectangle().fill(Theme.line).frame(width: 0.6) } }
                    }
                }
                .frame(height: 38)
                .overlay(alignment: .bottom) { if row < 11 { Rectangle().fill(Theme.line).frame(height: 0.6) } }
            }
        }
        .background(Color(hex: 0xFBF3E2))
        .overlay(Rectangle().stroke(Theme.sumi, lineWidth: 1.5))
        .overlay(Rectangle().stroke(Theme.goldLeafMid, lineWidth: 0.8).padding(3).allowsHitTesting(false))
    }

    @ViewBuilder private func cell(week w: Int) -> some View {
        let isCurrent = w == session.week
        let isPast = w < session.week
        let isTournament = isTournamentWeek(w)
        ZStack {
            if isTournament {
                Rectangle().fill(isPast ? Theme.vermD.opacity(0.55) : Theme.verm)   // 大会週＝朱の色面
                Text(tournamentLabel(w)).font(.maru(15, weight: .black)).tracking(1)
                    .foregroundStyle(.white)
                    .shadow(color: Theme.curtainShade.opacity(0.7), radius: 0, x: 1, y: 1)
            } else if isPast, let cat = session.categoryLog[w] {
                Text(cat.label.prefix(1)).font(.maru(13, weight: .black))   // 過去週＝やった事の頭文字（稽/バ/回）
                    .foregroundStyle(Theme.sumi.opacity(0.65))
            }
            if isCurrent {
                Rectangle().stroke(Theme.goldLeafHi, lineWidth: 3).padding(1)   // 現在週＝金の栞
                Rectangle().stroke(Theme.sumi, lineWidth: 1.5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.3) {
            if isPast { showToast("第\(w)週 \(session.categoryLog[w]?.label ?? "——")。") }
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            ForEach([BandCategory.keiko, .baito, .kaifuku], id: \.label) { cat in
                HStack(spacing: 4) {
                    Text(cat.label.prefix(1)).font(.maru(12, weight: .black)).foregroundStyle(Theme.sumi)
                        .frame(width: 20, height: 20).overlay(Rectangle().stroke(Theme.sumi, lineWidth: 1))
                    Text(cat.label)
                }
            }
            HStack(spacing: 4) { Rectangle().fill(Theme.verm).frame(width: 20, height: 20); Text("大会") }
            HStack(spacing: 4) { Rectangle().stroke(Theme.goldLeafHi, lineWidth: 3).frame(width: 20, height: 20); Text("今週") }
        }
        .font(.maru(11, weight: .bold)).foregroundStyle(Theme.sumi)
    }

    private func tournamentLabel(_ w: Int) -> String {
        if w == cal.gpFinalWeek { return "決勝" }
        if cal.gpRounds.contains(where: { $0.week == w }) { return "GP" }
        return "大会"
    }

    private func showToast(_ t: String) {
        withAnimation(.easeOut(duration: 0.2)) { toast = t }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation { toast = nil } }
    }

    private func isTournamentWeek(_ w: Int) -> Bool {
        if cal.tournament(inWeek: w) != nil { return true }
        if cal.gpRounds.contains(where: { $0.week == w }) { return true }
        return w == cal.gpFinalWeek
    }

    // 第1週=4月。4週で1ヶ月。
    private func monthLabel(_ row: Int) -> String {
        "\((3 + row) % 12 + 1)月"
    }
}
