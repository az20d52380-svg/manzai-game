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
            case "allocate": AllocationView(session: session, onClose: {}) // 割り振り目視（.taskで粒を積む）
            case "neta": NotebookView(session: session, onClose: {})       // ネタ帳タブ目視（.taskで持ちネタを積む）
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
            if ui == "allocate", session.week <= 1 {
                // 割り振り目視: 経験点残高を積んだ開始状態（数値は全て【仮】・発行側の会計移設が入るまでの目視専用）
                session = GameSession(startState: GameSession.debugAllocationState())
            }
            if ui == "neta", session.week <= 1 {
                // ネタ帳目視: 持ちネタ（鉄板/おろし前/擦り切れ/保管庫）を積んだ開始状態（数値は全て【仮】）
                session = GameSession(startState: GameSession.debugNetaState())
            }
            if ui == "event", session.week <= 1 {
                // 選択肢イベント目視: 金欠帯の開始状態で選択肢イベントを強制発火（MZ_EV で kind 選択・既定=0011）
                var s = GameState(config: GameConfig()); s.money = 3000
                session = GameSession(startState: s)
                let kind: ChoiceEventKind
                switch ProcessInfo.processInfo.environment["MZ_EV"] {
                case "0013": kind = .senpaiMeishi
                case "0015": kind = .peerFoldedChair
                case "0028": kind = .namelessReservationSlip
                case "0025": kind = .lineupTop
                case "0027": kind = .greenroomSilentTen
                case "0014": kind = .lastTrainReview
                case "0029": kind = .luckyThirdLine
                case "0023": kind = .regularEmployment
                case "0016": kind = .wroteOneTonight
                case "0012": kind = .taniguchiShortJob
                default:     kind = .brokeDrinkingInvite
                }
                session.debugForceEvent(kind)
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
            FinalsPresentationView(session: session)                 // M-1本家型 決勝演出（籤→7審査員→ボード→めくり→優勝）
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
            case .gpRound(let index, let name):
                StagePreludeView(session: session, title: name,
                                  requiredLength: NetaCatalog.lengthForGPRound(index: index))   // GP本番前
            case .gpRevival:
                StagePreludeView(session: session, title: "敗者復活",
                                  requiredLength: NetaCatalog.lengthForGPRevival)
            case .gpFinal:
                StagePreludeView(session: session, title: "頂GP 決勝",
                                  isFinal: true, requiredLength: NetaCatalog.lengthForGPFinal)
            default:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.bgGradient.ignoresSafeArea())
            }
        }
    }

    #if DEBUG
    /// DEBUG限定の導線（本番導線は不変）。🏆=優勝まで自動／💪=能力マックスで第1週から手動プレイ（無双体験の実験用）。
    private var debugButton: some View {
        VStack(spacing: 6) {
            Button { forceChampion() } label: { debugChip("🏆優勝") }
            Button { forceMaxedPlay() } label: { debugChip("💪無双") }
        }
        .padding(.top, 120).padding(.trailing, 10)
    }

    private func debugChip(_ label: String) -> some View {
        Text(label).font(.system(size: 11, weight: .heavy))
            .foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 5)
            .background(.black.opacity(0.45), in: Capsule())
    }

    private func forceChampion() {
        session = GameSession(startState: GameSession.debugMaxedState())
        session.debugAdvanceToChampionFinale()
    }

    /// 能力マックスの新規ゲームを第1週から始める（自動プレイしない＝手で無双して遊ぶ）。
    private func forceMaxedPlay() {
        session = GameSession(startState: GameSession.debugMaxedState())
        started = true
    }
    #endif
}
