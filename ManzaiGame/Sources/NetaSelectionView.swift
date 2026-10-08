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
                Text(title).font(.maru(.sub)).foregroundStyle(Theme.inkSub)
                Spacer()
                if let requiredLength {
                    Text("この舞台は\(NetaCatalog.displayName(requiredLength))")
                        .font(.maru(.sub)).foregroundStyle(Theme.inkSub)
                }
            }
            Button {
                withAnimation(Theme.Motion.appearQuick) { expanded.toggle() }
            } label: {
                currentSummary
            }.buttonStyle(PressableStyle())

            if expanded {
                VStack(spacing: 6) {
                    if session.activeNetas.isEmpty {
                        Text("——まだ、ネタは無い。").font(.maru(.bodyMedium)).foregroundStyle(Theme.inkSub)
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
        .overlay(RoundedRectangle(cornerRadius: Theme.Rad.btn).stroke(Theme.lineStrong, lineWidth: 2))
        .hardShadow()
    }

    @ViewBuilder private var currentSummary: some View {
        if let neta = selected {
            HStack(spacing: 8) {
                Circle().fill(Theme.kataColor(neta.kata)).frame(width: 10, height: 10)
                Text(neta.name).font(.maru(.body)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
                Text(NetaCatalog.displayName(neta.kata)).font(.maru(.sub)).foregroundStyle(Theme.inkSub)
                if let requiredLength, !neta.fits(requiredLength) {
                    Text("尺が合わない").font(.maru(.sub)).foregroundStyle(Theme.vermD)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.verm.opacity(0.1), in: Capsule())
                }
                Spacer()
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.inkSub)
            }
            .frame(minHeight: 32)
        } else {
            HStack {
                Text("選んでいない").font(.maru(.body)).foregroundStyle(Theme.inkSub)
                Spacer()
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.inkSub)
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
                Circle().fill(Theme.kataColor(neta.kata)).frame(width: 9, height: 9)
                Text(neta.name).font(.maru(.body)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
                Text(NetaCatalog.displayName(neta.kata)).font(.maru(.sub)).foregroundStyle(Theme.inkSub)
                if !fits {
                    Text("尺△").font(.maru(.sub)).foregroundStyle(Theme.inkSub)
                }
                Spacer()
                if isThis {
                    Image(systemName: "checkmark").font(.system(size: 11)).foregroundStyle(Theme.verm)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 8).frame(minHeight: 44)
            .background(isThis ? Theme.card2 : .clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PressableStyle())
    }
}
