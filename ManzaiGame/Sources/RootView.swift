// RootView.swift
// 画面ルーティング（Phase駆動）。育成メイン(S1)⇄大会入口/本番⇄結果(S2/S3)⇄年末(S4)。

import SwiftUI
import GameCore

struct RootView: View {
    @State private var session = GameSession()

    var body: some View {
        Group {
            if session.finished {
                YearResultView(session: session) {
                    session = GameSession(seed: UInt64.random(in: .min ... .max))
                }
            } else if let result = session.pendingResult {
                TournamentResultView(session: session, summary: result)   // S2波形→S3講評
            } else {
                switch session.phase {
                case .freeAction(let offer):
                    WeekMainView(session: session, offer: offer)          // S1 育成メイン
                case .tournamentDecision(let spec):
                    TournamentEntryView(session: session, spec: spec)     // 大会入口（遠征選択）
                case .gpRound(_, let name):
                    StagePreludeView(session: session, title: name)       // GP本番前
                case .gpRevival:
                    StagePreludeView(session: session, title: "敗者復活")
                case .gpFinal:
                    StagePreludeView(session: session, title: "頂GP 決勝")
                default:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.bgGradient.ignoresSafeArea())
                }
            }
        }
        .task {
            #if DEBUG
            let smoke = ProcessInfo.processInfo.environment["MZ_SMOKE"]
            if session.week <= 1 {
                if smoke == "1" { session.debugAdvanceToFirstResult() }
                else if smoke == "2" { session.debugAdvanceToFirstResult(stopAtEntry: true) }
                else if smoke == "3" { session.debugPlayToEnd() }
            }
            #endif
        }
    }
}
