// NetaSelectionView.swift
// 「今かけるネタ」選択カード。正典: docs/neta_system_redesign_v2.md §4-3（大会/GP入口に隣接させる・
// 尺マッチのラベル表示・golden非干渉＝state を読んで session.selectNeta/2 を呼ぶだけ）。
// アクティブ枠のみ選べる（保管庫の呼び戻しはネタ帳で行う・§4-1 3秒動線の簡略化）。

import SwiftUI
import GameCore

struct NetaPickRow: View {
    let session: GameSession
    let title: String                  // "今夜かけるネタ" / "決勝・1本目" 等
    let requiredLength: NetaLength?     // nil = 尺の言及なし
    let selected: Neta?
    let onSelect: (Int) -> Void

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(YoseFont.captionBold).foregroundStyle(YoseColor.haiSumi)
                // 尺の条件は見出しの隣に小さく（右の「変更」ボタンと並べて同じ箱に見せない）
                if let requiredLength {
                    YoseTag(text: "舞台尺：\(NetaCatalog.displayName(requiredLength))", style: .outlineSumi)
                }
                Spacer()
            }
            Button {
                withAnimation(Theme.Motion.appearQuick) { expanded.toggle() }
            } label: {
                currentSummary
            }.buttonStyle(PressableStyle())

            if expanded {
                VStack(spacing: 6) {
                    if session.activeNetas.isEmpty {
                        Text("——まだ、ネタは無い。").font(YoseFont.dialogueBody).foregroundStyle(YoseColor.haiSumi)
                    } else {
                        ForEach(session.activeNetas) { neta in
                            candidateRow(neta)
                        }
                    }
                }
                .padding(.top, 2)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, YoseMetrics.padH).padding(.vertical, YoseMetrics.padV)
        .frame(maxWidth: .infinity, alignment: .leading)
        .yoseHarigami(isFeatured: selected != nil)   // 未選択は朱の特別枠にしない（選んだ札と見分ける）
    }

    private var changeLabel: some View {
        let unset = selected == nil && !session.activeNetas.isEmpty
        return Text(expanded ? "とじる ▲" : (unset ? "ネタを選ぶ ▼" : "変更 ▼")).font(YoseFont.gothic(unset && !expanded ? 14 : 12, weight: .heavy))
            .foregroundStyle(unset && !expanded ? YoseColor.kinari : YoseColor.sumi)
            .padding(.horizontal, unset && !expanded ? 12 : 8).padding(.vertical, unset && !expanded ? 8 : 5)
            .background(unset && !expanded ? YoseColor.shu : YoseColor.ki)
            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 1.5))
            .background(alignment: .bottom) { Rectangle().fill(YoseColor.sumi).offset(y: 2) }   // 押せる物理ボタンのハードシャドウ
    }

    private func tags(_ neta: Neta) -> some View {
        HStack(spacing: 6) {
            YoseTag(text: NetaCatalog.displayName(neta.kata), style: .solidEnji)
            NetaTiredBadge(neta: neta)
            if let requiredLength, !neta.fits(requiredLength) {
                YoseTag(text: "尺が合わない", style: .outlineShu)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private var currentSummary: some View {
        if let neta = selected {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text(neta.name).font(YoseFont.netaTitle).foregroundStyle(YoseColor.sumi)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text("完成度 \(Int(neta.polish.rounded()))").font(YoseFont.numMedium).foregroundStyle(YoseColor.shu)
                        .lineLimit(1).fixedSize()
                    Spacer(minLength: 0)
                    changeLabel
                }
                tags(neta)
            }
        } else {
            HStack {
                // 持ちネタが無い時は「選んでいない」でなく、無いと言う（選べる物があるように見えた）。
                // ※「選ぶと有利」とは言わない：完成度・客の反応が50未満のネタは本番の点がマイナス（netaScoreBonus）
                Text(session.activeNetas.isEmpty ? "持ちネタがない" : "選んでいない")
                    .font(YoseFont.netaTitle).foregroundStyle(YoseColor.haiSumi)
                Spacer()
                changeLabel
            }
        }
    }

    private func candidateRow(_ neta: Neta) -> some View {
        let isThis = neta.id == selected?.id
        return Button {
            onSelect(neta.id)
            withAnimation(Theme.Motion.appearQuick) { expanded = false }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 10) {
                    Text(neta.name).font(YoseFont.mincho(17)).foregroundStyle(YoseColor.sumi)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text("完成度 \(Int(neta.polish.rounded()))").font(YoseFont.numMedium).foregroundStyle(YoseColor.shu)
                        .lineLimit(1).fixedSize()
                    Spacer(minLength: 0)
                    if isThis { YoseTag(text: "選択中", style: .outlineShu) }
                }
                tags(neta)
            }
            .padding(.horizontal, 8).padding(.vertical, 8).frame(minHeight: 44)
            .background(isThis ? YoseColor.ki.opacity(0.55) : YoseColor.ki.opacity(0.18))
            .overlay(Rectangle().stroke(YoseColor.kiDark, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}

/// 「飽きられてきた」札（表示専用）。tiredYears 1＝少し見飽きられた（墨）／2以上＝見飽きられた（朱）。nil/0 は何も出さない。
struct NetaTiredBadge: View {
    let neta: Neta
    var body: some View {
        let y = neta.tiredYears ?? 0
        if y >= 1 {
            YoseTag(text: y >= 2 ? "見飽きられた" : "少し見飽きられた", style: y >= 2 ? .outlineShu : .outlineSumi)
                .lineLimit(1).fixedSize()
        }
    }
}
