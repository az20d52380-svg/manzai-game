// BurstChipView.swift
// 獲得チップの共有部品（週メインの Beat2 バースト／大会結果の報酬列／選択肢イベントの効果ポップ）。
// dot!=nil は「貯まる粒」（塗りドット）、nil は即効の効果ピル（色地・白字）。outline は称号の金縁用（白縁を上書き）。
// style: .slam=パワプロの「＋経験点ドン」（でかく・白縁・ハード影＝見た目基盤②の文法）／.compact=文中の小さめ表示。
// 表示専用・golden非対象。元は WeekMainView 私有（第1弾 Beat2→見た目基盤②で強化）＝共有化のみで挙動不変。

import SwiftUI

struct BurstChip: Identifiable {
    let id: Int
    var dot: Color? = nil
    let text: String
    let fg: Color
    let bg: Color
    var outline: Color? = nil
}

struct BurstChipView: View {
    enum Style { case slam, compact }

    let chip: BurstChip
    var style: Style = .slam

    var body: some View {
        HStack(spacing: style == .slam ? 5 : 4) {
            if let dot = chip.dot {
                Circle().fill(dot).frame(width: style == .slam ? 9 : 7, height: style == .slam ? 9 : 7)
            }
            Text(chip.text)
                .font(.system(size: style == .slam ? 16 : 12.5, weight: .black))
                .foregroundStyle(chip.fg)
        }
        .padding(.horizontal, style == .slam ? 12 : 9)
        .padding(.vertical, style == .slam ? 6 : 4)
        .background(chip.bg, in: Capsule())
        .overlay(Capsule().stroke(chip.outline ?? .white, lineWidth: style == .slam ? 2 : 1.5))
        .shadow(color: Theme.ink.opacity(0.25), radius: 0, y: style == .slam ? 3 : 2)
    }
}
