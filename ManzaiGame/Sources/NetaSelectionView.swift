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
                Text(title).font(.maru(11)).foregroundStyle(Theme.inkDim)
                Spacer()
                if let requiredLength {
                    Text("この舞台は\(NetaCatalog.displayName(requiredLength))")
                        .font(.maru(9.5)).foregroundStyle(Theme.inkFaint)
                }
            }
            Button {
                withAnimation(Theme.Motion.appearQuick) { expanded.toggle() }
            } label: {
                currentSummary
            }.buttonStyle(.plain)

            if expanded {
                VStack(spacing: 6) {
                    if session.activeNetas.isEmpty {
                        Text("——まだ、ネタは無い。").font(.system(size: 12, design: .serif)).foregroundStyle(Theme.inkFaint)
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
        .padding(Theme.Sp.s12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Rad.btn))
        .overlay(RoundedRectangle(cornerRadius: Theme.Rad.btn).stroke(Theme.line, lineWidth: 1.5))
    }

    @ViewBuilder private var currentSummary: some View {
        if let neta = selected {
            HStack(spacing: 8) {
                Circle().fill(Theme.kataColor(neta.kata)).frame(width: 9, height: 9)
                Text(neta.name).font(.maru(13)).foregroundStyle(Theme.ink)
                Text(NetaCatalog.displayName(neta.kata)).font(.maru(10)).foregroundStyle(Theme.inkDim)
                if let requiredLength, !neta.fits(requiredLength) {
                    Text("尺が合わない").font(.maru(9.5)).foregroundStyle(Theme.verm)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.verm.opacity(0.1), in: Capsule())
                }
                Spacer()
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11)).foregroundStyle(Theme.inkFaint)
            }
        } else {
            HStack {
                Text("選んでいない").font(.maru(13)).foregroundStyle(Theme.inkFaint)
                Spacer()
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11)).foregroundStyle(Theme.inkFaint)
            }
        }
    }

    private func candidateRow(_ neta: Neta) -> some View {
        let isThis = neta.id == selected?.id
        let fits = requiredLength.map(neta.fits) ?? true
        return Button {
            onSelect(neta.id)
            withAnimation(Theme.Motion.appearQuick) { expanded = false }
        } label: {
            HStack(spacing: 8) {
                Circle().fill(Theme.kataColor(neta.kata)).frame(width: 7, height: 7)
                Text(neta.name).font(.maru(12)).foregroundStyle(Theme.ink)
                Text(NetaCatalog.displayName(neta.kata)).font(.maru(9.5)).foregroundStyle(Theme.inkDim)
                if !fits {
                    Text("尺△").font(.maru(9)).foregroundStyle(Theme.inkFaint)
                }
                Spacer()
                if isThis {
                    Image(systemName: "checkmark").font(.system(size: 11)).foregroundStyle(Theme.verm)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(isThis ? Theme.card2 : .clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PressableStyle())
    }
}
