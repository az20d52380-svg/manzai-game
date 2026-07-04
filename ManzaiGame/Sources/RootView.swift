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
            } else {
                WeekMainView(session: session)
            }
        }
        .animation(.default, value: session.finished)
    }
}

#Preview {
    RootView()
}
