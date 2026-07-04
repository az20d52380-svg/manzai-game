// RootView.swift
// MVPの画面切替。週メイン（S2）⇄ 年次リザルト（S6）だけの最小構成（ui_design §1）。

import SwiftUI

struct RootView: View {
    @State private var session = GameSession()

    var body: some View {
        Group {
            if session.finished {
                YearResultView(session: session) {
                    // もう一度（別シードで新しいコンビ）
                    session = GameSession(seed: UInt64.random(in: .min ... .max))
                }
            } else if let result = session.pendingResult {
                TournamentResultView(session: session, summary: result)   // S3 大会結果
            } else {
                WeekMainView(session: session)
            }
        }
        .animation(.default, value: session.finished)
        .animation(.default, value: session.pendingResult?.week)
        .task {
            #if DEBUG
            // QA早送り（MZ_SMOKE=1 のときだけ・最初の大会結果まで自動プレイ）
            if ProcessInfo.processInfo.environment["MZ_SMOKE"] == "1", session.week <= 1 {
                session.debugAdvanceToFirstResult()
            }
            #endif
        }
    }
}

#Preview {
    RootView()
}
