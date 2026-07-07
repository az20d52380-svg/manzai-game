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
            LinearGradient(colors: [Theme.bgTop, Theme.bg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: Theme.Sp.s12) {
                header
                summary
                grid
                Spacer(minLength: 0)
                legend
            }
            .padding(Theme.Sp.s16)

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

    private var header: some View {
        HStack {
            Text("年間カレンダー").font(.maru(16)).foregroundStyle(Theme.ink)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundStyle(Theme.inkFaint)
            }.buttonStyle(PressableStyle())
        }
    }

    private var summary: some View {
        Text("\(session.combiName) ・ \(session.year)年目 ・ 第\(session.week)週 ・ 賞金 ¥\(session.totalPrize.formatted())")
            .font(.maru(11)).monospacedDigit().foregroundStyle(Theme.inkDim)
    }

    // 12行(月)×4列(週)
    private var grid: some View {
        VStack(spacing: 6) {
            ForEach(0..<12, id: \.self) { row in
                HStack(spacing: 8) {
                    Text(monthLabel(row)).font(.maru(10)).monospacedDigit()
                        .foregroundStyle(Theme.inkDim).frame(width: 34, alignment: .leading)
                    ForEach(0..<4, id: \.self) { col in
                        cell(week: row * 4 + col + 1)
                    }
                }
            }
        }
        .padding(Theme.Sp.s16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.card)).e2()
    }

    @ViewBuilder private func cell(week w: Int) -> some View {
        let isCurrent = w == session.week
        let isPast = w < session.week
        let isTournament = isTournamentWeek(w)
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(isPast ? Theme.card2 : Color.white.opacity(0.4))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(isCurrent ? Theme.verm : Theme.line, lineWidth: isCurrent ? 1.5 : 1))
            if isTournament {
                Circle().stroke(Theme.verm, lineWidth: 2).frame(width: 16, height: 16)   // 大会週=朱の丸印
            } else if isPast, let cat = session.categoryLog[w] {
                Circle().fill(cat.color).frame(width: 8, height: 8)                        // 過去週=カテゴリ色ドット
            }
        }
        .frame(maxWidth: .infinity).frame(height: 30)
        .scaleEffect(isCurrent && breathe ? 1.02 : 1)
        .animation(isCurrent ? .easeInOut(duration: 2).repeatForever(autoreverses: true) : .default, value: breathe)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.3) {
            if isPast { showToast("第\(w)週 \(session.categoryLog[w]?.label ?? "——")。") }
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach([BandCategory.keiko, .baito, .kaifuku], id: \.label) { cat in
                HStack(spacing: 4) { Circle().fill(cat.color).frame(width: 7, height: 7); Text(cat.label) }
            }
            HStack(spacing: 4) { Circle().stroke(Theme.verm, lineWidth: 2).frame(width: 10, height: 10); Text("大会") }
        }
        .font(.maru(9.5)).foregroundStyle(Theme.inkDim)
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
