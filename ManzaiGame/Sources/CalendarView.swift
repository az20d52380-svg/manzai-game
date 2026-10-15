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
            YoseColor.kinari.ignoresSafeArea()
            VStack(spacing: 0) {
                YoseHeaderBar(title: "年間香盤", closeAction: onClose)
                VStack(spacing: 10) {
                    summary
                    grid
                    legend   // 凡例は表のすぐ下
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, YoseMetrics.screenMargin).padding(.top, 12)
            }

            if let toast {
                YoseToast(message: toast)
                    .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 40)
                    .transition(.opacity)
            }
        }
        .onAppear { breathe = true }
    }

    private var summary: some View {
        VStack(spacing: 3) {
            Text("\(session.combiName)").font(YoseFont.gothic(17, weight: .heavy)).foregroundStyle(YoseColor.kinari)
            Text("\(session.year)年目 ・ 第\(session.week)週 ・ 賞金 ¥\(session.totalPrize.formatted())")
                .font(YoseFont.number(12, weight: .bold)).foregroundStyle(YoseColor.kinBright)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 7)
        .background(YoseColor.kuroUrushi)   // 番付の見出し帯（黒漆＋金線）
        .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 1.5))
        .background(Rectangle().fill(YoseColor.sumi).offset(y: 2))
    }

    // 12行(月)×4列(週)＝罫線だけの番付表
    private var grid: some View {
        VStack(spacing: 0) {
            ForEach(0..<12, id: \.self) { row in
                HStack(spacing: 0) {
                    Text(monthLabel(row)).font(YoseFont.number(14, weight: .black))
                        .foregroundStyle(YoseColor.sumi).frame(width: 42)
                        .frame(maxHeight: .infinity)
                        .background(YoseColor.ki)
                        .overlay(alignment: .trailing) { Rectangle().fill(YoseColor.sumi).frame(width: 2) }
                    ForEach(0..<4, id: \.self) { col in
                        cell(week: row * 4 + col + 1)
                            .overlay(alignment: .leading) { if col > 0 { Rectangle().fill(YoseColor.kiDark).frame(width: 1) } }
                    }
                }
                .frame(height: 40)
                .overlay(alignment: .bottom) { if row < 11 { Rectangle().fill(YoseColor.kiDark).frame(height: row % 3 == 2 ? 1.5 : 1) } }
            }
        }
        .background(YoseColor.washi)
        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2.5))
        .background(Rectangle().fill(YoseColor.sumi).offset(y: 3))
        .padding(.bottom, 3)
    }

    @ViewBuilder private func cell(week w: Int) -> some View {
        let isCurrent = w == session.week
        let isPast = w < session.week
        let isTournament = isTournamentWeek(w)
        ZStack {
            if isTournament {
                Rectangle().fill(isPast ? YoseColor.shu.opacity(0.55) : YoseColor.shu)   // 大会週＝朱の色面
                VStack(spacing: 0) {
                    Text(tournamentName(w)).font(YoseFont.gothic(10, weight: .bold)).foregroundStyle(YoseColor.kinBright)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(tournamentLabel(w)).font(YoseFont.gothic(13, weight: .heavy)).foregroundStyle(YoseColor.kinari)
                        .lineLimit(1)
                }
                .padding(.horizontal, 2)
            } else if isPast, let cat = session.categoryLog[w] {
                Text(cat.label.prefix(1)).font(YoseFont.gothic(13, weight: .heavy))   // 過去週＝やった事の頭文字（稽/バ/回）
                    .foregroundStyle(YoseColor.sumi.opacity(0.75))
                    .frame(width: 24, height: 24)
                    .background(catTint(cat).opacity(0.28))   // 小判子（種別で薄く色分け）
                    .overlay(Rectangle().stroke(catTint(cat).opacity(0.7), lineWidth: 1))
            }
            if isCurrent {
                Rectangle().stroke(YoseColor.kinBright, lineWidth: 3).padding(1)   // 現在週＝金の栞
                Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topLeading) {
            if isCurrent {
                Text("今週").font(YoseFont.gothic(9, weight: .heavy)).foregroundStyle(YoseColor.kinBright)
                    .padding(.horizontal, 3).background(YoseColor.kuroUrushi)
            }
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.3) {
            if isPast { showToast("第\(w)週 \(session.categoryLog[w]?.label ?? "——")。") }
        }
    }

    private func catTint(_ cat: BandCategory) -> Color {
        switch cat {
        case .keiko: return YoseColor.expTan
        case .baito: return YoseColor.tokiwa
        default: return YoseColor.kin
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach([BandCategory.keiko, .baito, .kaifuku], id: \.label) { cat in
                HStack(spacing: 4) {
                    Text(cat.label.prefix(1)).font(YoseFont.gothic(12, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                        .frame(width: 20, height: 20).overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
                    Text(cat.label)
                }
            }
            HStack(spacing: 4) { Rectangle().fill(YoseColor.shu).frame(width: 20, height: 20).overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5)); Text("大会") }
            HStack(spacing: 4) { Rectangle().stroke(YoseColor.kinBright, lineWidth: 3).frame(width: 20, height: 20).overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5)).overlay(alignment: .topLeading) { Text("今").font(YoseFont.gothic(8, weight: .heavy)).foregroundStyle(YoseColor.kinBright).padding(.horizontal, 2).background(YoseColor.kuroUrushi).offset(x: -1, y: -1) }; Text("今週") }
        }
        .font(YoseFont.gothic(11, weight: .bold)).foregroundStyle(YoseColor.sumi)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .yoseKifuda()
    }

    private func tournamentLabel(_ w: Int) -> String {
        if w == cal.gpFinalWeek { return "決勝" }
        if cal.gpRounds.contains(where: { $0.week == w }) { return "GP" }
        return "大会"
    }

    /// 上段に出す大会の略称（どの大会か）。春新人賞A→春新人A／大阪戎コンクール→大阪戎 など
    private func tournamentName(_ w: Int) -> String {
        if w == cal.gpFinalWeek { return "頂GP" }
        if let i = cal.gpRounds.firstIndex(where: { $0.week == w }), i < cal.gpRoundNames.count { return cal.gpRoundNames[i] }
        guard let n = cal.tournament(inWeek: w)?.name else { return "" }
        return n.replacingOccurrences(of: "コンクール", with: "").replacingOccurrences(of: "賞", with: "").replacingOccurrences(of: "制", with: "")
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
