// RootView.swift
// 画面ルーティング（Phase駆動）。育成メイン(S1)⇄大会入口/本番⇄結果(S2/S3)⇄勝ち版決勝⇄年末(S4)。

import SwiftUI
import GameCore

struct RootView: View {
    @State private var session = GameSession()
    @State private var started = false   // S1初回フロー完了で true（本編開始）
    @State private var showEnding = false // 優勝→S6b勇退エンディング

    var body: some View {
        Group {
            #if DEBUG
            switch ProcessInfo.processInfo.environment["MZ_UI"] {
            case "notebook": NotebookView(session: session, onClose: {})   // S5目視（能力は.taskでgrown）
            case "calendar": CalendarView(session: session, onClose: {})   // S4目視（.taskで数週プレイ）
            case "settings": SettingsView(onClose: {})                     // S1b目視
            case "notif": NotificationPromptView(onDecide: {})             // S1c目視
            case "ending": S6bView(session: session, onFinish: {})         // S6b目視（.taskで優勝させる）
            default: mainFlow
            }
            #else
            mainFlow
            #endif
        }
        .task {
            #if DEBUG
            let smoke = ProcessInfo.processInfo.environment["MZ_SMOKE"]
            let ui = ProcessInfo.processInfo.environment["MZ_UI"]
            if smoke != nil || ui != nil { started = true }   // スモーク/UI確認時はS1を飛ばす
            if session.week <= 1 {
                if smoke == "1" { session.debugAdvanceToFirstResult() }
                else if smoke == "2" { session.debugAdvanceToFirstResult(stopAtEntry: true) }
                else if smoke == "3" { session.debugPlayToEnd() }
                else if smoke == "4" { forceChampion() }
                else if smoke == "5" { forceChampion(); session.acknowledgeWin() }   // S4優勝ボード確認用
            }
            // UIスモーク: MZ_UI=grown/notebook で能力マックス状態（充填ピル/gold縁/レーダー満ちの目視用）
            if (ui == "grown" || ui == "notebook"), session.week <= 1 {
                session = GameSession(startState: GameSession.debugMaxedState())
            }
            if ui == "calendar", session.week <= 1 {
                session.debugAdvanceToFirstResult()   // 数週バイトで進める（過去週の色ドット＋大会週の目視）
            }
            if ui == "ending", session.week <= 1 {
                forceChampion()   // S6b目視: 優勝データ（outcome.champion＋高残金）を用意
            }
            #endif
        }
    }

    @ViewBuilder private var mainFlow: some View {
        if started {
            content
                .overlay(alignment: .topTrailing) {
                    #if DEBUG
                    debugButton
                    #endif
                }
        } else {
            IntroFlowView { name in                       // S1: KV→回想→名入力
                session = GameSession(combiName: name)
                withAnimation(.easeInOut(duration: 0.4)) { started = true }
            }
        }
    }

    @ViewBuilder private var content: some View {
        if session.winFinale {
            WinFinaleView(session: session)                          // 勝ち版 決勝演出
        } else if session.finished {
            if showEnding {
                S6bView(session: session) {                                    // S6b 勇退エンディング→顔合わせ(=新周回)
                    session = GameSession(seed: UInt64.random(in: .min ... .max)); showEnding = false
                }
            } else {
                YearResultView(session: session,
                               onRestart: { session = GameSession(seed: UInt64.random(in: .min ... .max)) },
                               onEnding: session.outcome?.champion == true ? { showEnding = true } : nil)
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

    #if DEBUG
    /// DEBUG限定の導線: 能力マックスで開始し、決勝優勝まで自動で飛ぶ（優勝演出の確認用・本番導線は不変）
    private var debugButton: some View {
        Button {
            forceChampion()
        } label: {
            Text("🏆DEBUG").font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 5)
                .background(.black.opacity(0.45), in: Capsule())
        }
        .padding(.top, 120).padding(.trailing, 10)
    }

    private func forceChampion() {
        session = GameSession(startState: GameSession.debugMaxedState())
        session.debugAdvanceToChampionFinale()
    }
    #endif
}
