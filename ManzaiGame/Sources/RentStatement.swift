// RentStatement.swift  月末の支払い（生活費の引き落としの演出）。表示専用：式・乱数・golden には触れない。
// 金額は GameConfig.livingCost から（内訳は 6:4:2:2 の比で、合計が必ず livingCost に一致する）。

import SwiftUI
import UIKit

struct RentStatement: Equatable {
    struct Line: Equatable { let label: String; let amount: Int }
    let lines: [Line]
    let total: Int
    let moneyBefore: Int
    let moneyAfter: Int
    /// 足りなかった額（所持金が負なら全額が借金へ回る）。払えたら 0。
    var shortfall: Int { max(0, total - max(0, moneyBefore)) }
    var paid: Bool { shortfall == 0 }

    static let ratio: [(String, Int)] = [("家賃", 6), ("食費", 4), ("光熱費・携帯", 2), ("交通費", 2)]

    /// 内訳（合計 = total。端数は最後の行で吸収）。
    static func breakdown(total: Int) -> [Line] {
        let sum = ratio.reduce(0) { $0 + $1.1 }
        var rest = total
        var out: [Line] = []
        for (i, r) in ratio.enumerated() {
            let a = i == ratio.count - 1 ? rest : total * r.1 / sum
            out.append(Line(label: r.0, amount: a)); rest -= a
        }
        return out
    }

    /// moneyAfter は支払い後の所持金（週末処理済みの state.money）。
    /// roomExtra は部屋の上乗せ（livingCost は上乗せ込みの合計）。「家賃」の行にだけ乗る。
    static func make(livingCost: Int, moneyAfter: Int, roomExtra: Int = 0, roomName: String? = nil) -> RentStatement {
        var lines = breakdown(total: livingCost - roomExtra)
        if let n = roomName, !lines.isEmpty { lines[0] = Line(label: "家賃（\(n)）", amount: lines[0].amount) }
        if roomExtra > 0, !lines.isEmpty { lines[0] = Line(label: lines[0].label, amount: lines[0].amount + roomExtra) }
        return RentStatement(lines: lines, total: livingCost,
                      moneyBefore: moneyAfter + livingCost, moneyAfter: moneyAfter)
    }

    static func yen(_ n: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        return f.string(from: NSNumber(value: abs(n))) ?? "\(abs(n))"
    }
}

/// 支払い画面。約2秒で自動で閉じる。タップで即閉じ（早送り）。
struct RentStatementView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    let statement: RentStatement
    let onDone: () -> Void

    @State private var shownRows = 0
    @State private var showTotal = false
    @State private var money: Double = 0
    @State private var settled = false

    private var shortfallMode: Bool { !statement.paid }

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
                .contentShape(Rectangle()).onTapGesture { onDone() }
            VStack(spacing: 0) {
                Text("月末の支払い").font(YoseFont.gothic(17, weight: .heavy)).foregroundStyle(YoseColor.kin)
                    .frame(maxWidth: .infinity).frame(height: 40).background(YoseColor.enji)
                    .overlay(alignment: .bottom) { Rectangle().fill(YoseColor.kin).frame(height: 1.5) }
                VStack(spacing: 10) {
                    ForEach(Array(statement.lines.enumerated()), id: \.offset) { i, l in
                        HStack {
                            Text(l.label).font(YoseFont.gothic(15, weight: .bold)).foregroundStyle(YoseColor.sumi)
                            Spacer()
                            Text(RentStatement.yen(l.amount)).font(YoseFont.number(17, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                        }
                        .opacity(i < shownRows ? 1 : 0).offset(y: i < shownRows ? 0 : 6)
                    }
                    Rectangle().fill(YoseColor.sumi).frame(height: 2).opacity(showTotal ? 1 : 0)
                    HStack {
                        Text("合計").font(YoseFont.gothic(16, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                        Spacer()
                        Text(RentStatement.yen(statement.total)).font(YoseFont.numLarge).foregroundStyle(YoseColor.sumi)
                    }.opacity(showTotal ? 1 : 0)
                    HStack {
                        Text("所持金").font(YoseFont.gothic(13, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
                        Spacer()
                        Text((money < 0 ? "−" : "") + RentStatement.yen(Int(money)))
                            .font(YoseFont.numLarge)
                            .foregroundStyle(money < 0 ? YoseColor.shu : YoseColor.kinText)
                            .contentTransition(.numericText(value: money))
                    }
                    .padding(.vertical, 6).padding(.horizontal, 8)
                    .background(YoseColor.ki.opacity(0.45))
                    .opacity(showTotal ? 1 : 0)

                    ZStack {
                        if shortfallMode {
                            VStack(spacing: 4) {
                                Text("足りない ▲\(RentStatement.yen(statement.shortfall))")
                                    .font(YoseFont.number(20, weight: .black)).foregroundStyle(YoseColor.shu)
                                Text("次の支払いまでにバイトを。")
                                    .font(YoseFont.gothic(13, weight: .bold)).foregroundStyle(YoseColor.sumi)
                            }
                            .opacity(settled ? 1 : 0)
                        } else {
                            YoseHankoStamp(text: "今月も払えた", isSquare: true, angle: -6)
                                .modifier(YoseStampImpactModifier(isStamped: settled))
                        }
                    }
                    .frame(minHeight: 56).padding(.top, 4)
                }
                .padding(16).background(YoseColor.washi)
            }
            .clipShape(RoundedRectangle(cornerRadius: YoseMetrics.radius))
            .overlay(RoundedRectangle(cornerRadius: YoseMetrics.radius).stroke(YoseColor.sumi, lineWidth: 2.5))
            .background(RoundedRectangle(cornerRadius: YoseMetrics.radius).fill(YoseColor.sumi).offset(y: 4))
            .padding(.horizontal, 24)
            .onTapGesture { onDone() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction { onDone() }   // ダブルタップで閉じる
        .accessibilityLabel(statement.paid ? "月末の支払い。合計\(statement.total)円。今月も払えた。"
                            : "月末の支払い。合計\(statement.total)円。\(statement.shortfall)円足りない。")
        .task {
            money = Double(statement.moneyBefore)
            let step: UInt64 = reduceMotion ? 0 : 90_000_000
            for _ in statement.lines {
                withAnimation(.easeOut(duration: 0.15)) { shownRows += 1 }
                try? await Task.sleep(nanoseconds: step)
                if Task.isCancelled { return }   // タップで閉じた後に音・振動・onDone が後から走らない（code_review_2026-10-19b §1-1）
            }
            withAnimation(.easeOut(duration: 0.15)) { showTotal = true }
            try? await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { return }
            Sound.play(.money)
            withAnimation(.easeOut(duration: 0.45)) { money = Double(statement.moneyAfter) }
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            withAnimation { settled = true }
            if shortfallMode { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled || voiceOver { return }   // VoiceOver 中は自動で閉じない＝読み終えてから閉じる（a11y_check_1019）
            onDone()
        }
    }
}
