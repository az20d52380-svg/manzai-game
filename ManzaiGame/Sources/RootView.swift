// RootView.swift
// 画面ルーティング（Phase駆動）。育成メイン(S1)⇄大会入口/本番⇄結果(S2/S3)⇄勝ち版決勝⇄年末(S4)。

import SwiftUI
import GameCore

struct RootView: View {
    @State private var session: GameSession
    @State private var started: Bool     // S1初回フロー完了で true（本編開始）
    @State private var showEnding = false // キャリアの区切り→エンディング（8種・endings_spec）
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        // QAスモーク（MZ_SMOKE/MZ_UI）はセーブを読まず従来どおり固定シードの新規から＝決定的なまま。
        // saveNow 側も同条件でガード済み＝QA走行が実プレイのセーブを潰さない。
        let env = ProcessInfo.processInfo.environment
        if env["MZ_SMOKE"] != nil || env["MZ_UI"] != nil || env["MZ_ENDING"] != nil {
            _session = State(initialValue: GameSession())
            _started = State(initialValue: false)   // .task が true にする
            return
        }
        #endif
        // 中断セーブがあればその週から再開（IntroFlow はスキップ）。無ければ従来どおり S1 から。
        let loaded = GameSession.loadedOrNew()
        _session = State(initialValue: loaded)
        _started = State(initialValue: loaded.isRestored)
    }

    var body: some View {
        Group {
            #if DEBUG
            if let bg = ProcessInfo.processInfo.environment["MZ_BG"], let place = EventPlace(rawValue: bg) {
                // 背景の目視: MZ_BG=<keikoba|station|apartment|gakuya|train|park|famires|sento|theater|kissaten|office>&MZ_BGTIME=<morning|day|evening|night>
                // （env は & 区切りでなく別々に渡す）。背景だけを全画面（高さ220の舞台を縦に並べず中央に1枚）
                let time = EventTimeOfDay(rawValue: ProcessInfo.processInfo.environment["MZ_BGTIME"] ?? "day") ?? .day
                ZStack {
                    YoseColor.kinari.ignoresSafeArea()
                    EventStageBackdropView(backdrop: EventBackdrop(place, time)).frame(height: 220)
                        .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2))
                }
            } else {
            if let n = Int(ProcessInfo.processInfo.environment["MZ_ENDING"] ?? ""), let id = EndingID.from(number: n) {
                // エンディング直接再生: MZ_ENDING=1..8（記録しない）。#5/#7/#8 の S6b 用に .task が優勝データを用意する
                EndingFlowView(session: session, ending: id, record: false, onFinish: {})
            } else if let fx = ProcessInfo.processInfo.environment["MZ_FX"] { YoseFXPreview(kind: fx) }   // 演出の単独再生（MZ_FX=rankup/yearturn/burst/pass/champion/cutin/streak）
            else {
            switch ProcessInfo.processInfo.environment["MZ_UI"] {
            case "notebook": NotebookView(session: session, onClose: {})   // S5目視（能力は.taskでgrown）
                .onAppear { if ProcessInfo.processInfo.environment["MZ_TAB"] == "kiroku" { session.debugSeedKirokuLog() } }
            case "calendar": CalendarView(session: session, onClose: {})   // S4目視（.taskで数週プレイ）
            case "settings": SettingsView(onClose: {}, onQuitRun: {})   // S1b目視（MZ_STEP=0/1/2 で確認の段へ）
            case "glossary": GlossaryView(onClose: {})                      // 用語集の目視
            case "shop": ShopView(session: session, onClose: {})            // 買い物目視
            case "notif": NotificationPromptView(onDecide: {})             // S1c目視
            case "intro": ReminiscencePlayer(cards: IntroFlowView.cards, onComplete: {}) // 導入の回想カード目視
            case "ending": S6bView(session: session, onFinish: {})         // S6b目視（.taskで優勝させる）
            case "allocate": AbilityUpView(session: session, onClose: {}) // 割り振り目視（.taskで粒を積む）
            case "neta", "neta_list": NotebookView(session: session, onClose: {})       // ネタ帳タブ目視（.taskで持ちネタを積む）
            case "intro_title", "intro_name": IntroFlowView { _, _, _ in }          // タイトル／名前決めの目視
            case "endingbook": EndingGalleryView(onClose: {})               // エンディング図鑑の目視（MZ_BOOKSEEN=1,3,7 で見た扱いの見本）
            case "catalog": YoseCatalogView()                               // デザイン部品見本
            case "frame": StageFramePreview(mode: debugFrameMode)                  // 本番の舞台の部品目視（MZ_MODE で状態）
            default: mainFlow
            }
            }
            }
            #else
            mainFlow
            #endif
        }
        .task {
            #if DEBUG
            let smoke = ProcessInfo.processInfo.environment["MZ_SMOKE"]
            let ui = ProcessInfo.processInfo.environment["MZ_UI"]
            let endingHook = ProcessInfo.processInfo.environment["MZ_ENDING"] != nil
            if smoke != nil || ui != nil || endingHook { started = true }
            if smoke == "selftest" { GameSession.debugSelfTest(); return }
            if smoke == "actiontrace" { GameSession.debugActionTrace(); return }
            if smoke == "soak" { await soakLoop(); return }   // 漏れ点検: 実UIを通して年を回し続ける（MZ_SOAK_MS=1手の待ち）
            if endingHook, session.week <= 1 { forceChampion() }   // S6b（#5/#7/#8）用の優勝データ。1〜4・6 の場面は session 不要   // スモーク/UI確認時はS1を飛ばす
            // 複数年の目視: MZ_YEARS=n で n 年ぶん自動で年末→翌年へ進めてから、他のフックを掛ける
            if let n = Int(ProcessInfo.processInfo.environment["MZ_YEARS"] ?? ""), n > 0, session.year == 1 {
                session.debugAdvanceYears(n)
            }
            // 監査直しの目視用: MZ_SAVEMAKE=champ|yearend|yearend_old で中断セーブを作る（MZ_ALLOWSAVE=1 と併用）
            if let mk = ProcessInfo.processInfo.environment["MZ_SAVEMAKE"] {
                var st = mk == "champ" ? GameSession.debugMaxedState() : GameState(config: GameConfig()); st.compat = 10; st.money = 500_000
                session = GameSession(startState: st)
                if mk == "champ" { session.debugAdvanceToChampionFinale() }
                else { session.debugAdvanceYears(1); session.debugAdvanceToYearEnd() }
                session.saveNow()
                if mk == "yearend_old",
                   let d = UserDefaults.standard.data(forKey: "manzai.save.v1"),
                   var o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                    o.removeValue(forKey: "yearStartState")
                    if let nd = try? JSONSerialization.data(withJSONObject: o) { UserDefaults.standard.set(nd, forKey: "manzai.save.v1") }
                }
                print("[savemake] \(mk) year=\(session.year) win=\(session.winFinale) fin=\(session.finished)")
                return
            }
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
            if ui == "yearend", session.week <= 1 {
                // 年末リザルト本体の目視: 通常は最後まで自動で進め、客席観戦の決勝を観終えた扱いにして年末総決算へ。MZ_MODE=champion は優勝版
                if ProcessInfo.processInfo.environment["MZ_MODE"] == "champion" { forceChampion(); session.acknowledgeWin() }
                else {
                    session.debugPlayToEnd()
                    if session.watchingFinal { session.finishWatchingFinal(winner: "（見本）"); session.debugPlayToEnd() }
                }
            }
            if ui == "prestage", session.week <= 1 {
                // 大会前の振り忘れの知らせの目視：最初の大会（春新人賞A）の1週前まで練習で進める
                if let w = session.nextStage?.week {
                    session.debugAdvanceUntilStage(weeksBefore: 1, stageWeek: w)
                }
            }
            if ui == "calendar", session.week <= 1 {
                session.debugAdvanceToFirstResult()   // 数週バイトで進める（過去週の色ドット＋大会週の目視）
            }
            if ui == "ending", session.week <= 1 {
                forceChampion()   // S6b目視: 優勝データ（outcome.champion＋高残金）を用意
            }
            if ui == "allocate", session.week <= 1 {
                // 割り振り目視: 経験点残高を積んだ開始状態（数値は全て【仮】・発行側の会計移設が入るまでの目視専用）
                var st = GameSession.debugAllocationState()
                if ProcessInfo.processInfo.environment["MZ_MODE"] == "short" { st.exp閃き = 2; st.exp語彙 = 3; st.exp間合い = 0.5; st.exp存在感 = 1; st.exp胆力 = 0 }   // 足りない行の目視
                session = GameSession(startState: st)
            }
            if ui == "stage" || ui == "juice", session.week <= 1, session.year == 1 {   // MZ_YEARS 後（2年目）は素の状態へ作り直さない
                // 舞台シーン目視: 週頭イベント帯（0020[compat0-7]/0021[>=15]/0012[金欠]）を全て外した素の育成メイン
                var st = GameState(config: session.config); st.compat = 10; st.money = 500_000
                session = GameSession(startState: st)
            }
            if ui == "debt", session.week <= 1, session.year == 1 {
                // 借金の知らせ・朱の表示の目視: MZ_MONEY=<円> で所持金を指定して週メインを開く（例 -100000 / -600000 / -900000）
                var st = GameState(config: session.config); st.compat = 10
                st.money = Int(ProcessInfo.processInfo.environment["MZ_MONEY"] ?? "") ?? -100_000
                session = GameSession(startState: st)
            }
            if ui == "juice" {
                // ジュース目視: 2秒後にネタ作りを自動実行＝Beat2バースト＋パーティクル＋ピル跳ねをスクショで拾う
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                session.choose(.train(.ネタ作り))
            }
            if ui == "pass" || ui == "result_done", session.week <= 1 {
                // 合否演出（通過側）目視: 能力マックスで初回大会へ＝「通過」判＋紙吹雪＋フラッシュを拾う
                session = GameSession(startState: GameSession.debugMaxedState())
                session.debugAdvanceToFirstResult()
            }
            if ui == "cards", session.week <= 1 {
                // 0022 稽古ロック目視: preoccupiedWeeks>0 の開始状態＝WeekMainView(MZ_UI=cards)で稽古がグレー＋「今週は撮影」。
                // compat 10（8-14帯＝0020[0-7]/0021[>=15]の確定発火を回避）＋高所持金（0012回避）で稽古グリッドが被らず見える。
                var st = GameSession.debugMaxedState(); st.compat = 10; st.money = 500_000; st.preoccupiedWeeks = ProcessInfo.processInfo.environment["MZ_FREE"] != nil ? 0 : 1
                session = GameSession(startState: st)
            }
            if ui == "neta" || ui == "neta_list" || ui == "netaentry" || ui == "weeknetas", session.week <= 1 {
                // ネタ帳目視: 持ちネタ（鉄板/おろし前/擦り切れ/保管庫）を積んだ開始状態（数値は全て【仮】）
                session = GameSession(startState: GameSession.debugNetaState())
                // netaentry＝その持ちネタのまま最初の大会の入口で止める（入口のネタ選びの目視・2026-10-14）
                if ui == "netaentry" { session.debugAdvanceToFirstResult(stopAtEntry: true) }
            }
            if ui == "prelude" || ui == "prelude_final", session.week <= 1 {
                // 本番前カード（ネタ選び）の目視: 能力マックスで GP の本番前（prelude_final＝決勝）まで進める
                var st = GameSession.debugMaxedState(); let ns = GameSession.debugNetaState()
                st.netas = ns.netas; st.nextNetaID = ns.nextNetaID; st.selectedNetaID = ns.selectedNetaID; st.archivedNetas = ns.archivedNetas
                session = GameSession(startState: st)
                session.debugAdvanceToPrelude(final: ui == "prelude_final")
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
                case "0016": kind = .wroteOneTonight
                case "0012": kind = .taniguchiShortJob
                case "0022": kind = .photoShootOffer
                case "0041": kind = .kouhaiInvite
                case "0042": kind = .senpaiAllNight
                case "0043": kind = .stageCrewChairs
                case "0044": kind = .writerPostcards
                case "0045": kind = .doukiJointLive
                case "0046": kind = .baitoInventory
                case "0047": kind = .homecomingCall
                case "0048": kind = .regularFanOranges
                case "0049": kind = .officeTicketQuota
                case "0050": kind = .riftWarning
                default:     kind = .brokeDrinkingInvite
                }
                session.debugForceEvent(kind)
            }
            #endif
        }
        .onChange(of: session.abandoned) { _, quit in
            // 「この年をやめてタイトルへ」（監査G-04）: セーブは GameSession 側で削除済み
            if quit {
                session = GameSession()
                withAnimation(.easeInOut(duration: 0.3)) { started = false }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // バックグラウンド移行時の保険保存（通常の保存は GameSession の各入力確定点で走る）
            if phase == .background, started { session.saveNow() }
        }
    }

    @ViewBuilder private var mainFlow: some View {
        if started {
            content
                .overlay(alignment: .topTrailing) {
                    #if DEBUG
                    if ProcessInfo.processInfo.environment["MZ_NOCHIP"] == nil, !(session.finished && showEnding) { debugButton }   // 目視用: MZ_NOCHIP=1 で DEBUG チップを隠す
                    #endif
                }
        } else {
            IntroFlowView { name, me, partner in          // S1: KV→回想→名入力（コンビ名・自分の名前・相方の名前）
                // 初回もランダムシード（「もう一度」と同じ）。固定424242だと全プレイヤーの初年が同一乱数になる。
                // DEBUGの MZ_SMOKE/MZ_UI 経路は上の .task が固定シードの session をそのまま使う＝決定的なまま。
                session = GameSession(seed: UInt64.random(in: .min ... .max), combiName: name, myName: me, partnerName: partner)
                withAnimation(.easeInOut(duration: 0.4)) { started = true }
            }
        }
    }

    @ViewBuilder private var content: some View {
        if session.winFinale {
            FinalsPresentationView(session: session)                 // M-1本家型 決勝演出（籤→7審査員→ボード→めくり→優勝）
        } else if session.watchingFinal {
            // 決勝に進めなかった年の第47週＝今年の決勝を客席から観る（監査H-01）
            FinalsPresentationView(session: session, spectator: true,
                                   onFinishSpectating: { session.finishWatchingFinal(winner: $0) })
        } else if session.finished {
            if showEnding {
                if let ending = session.endingID {
                    EndingFlowView(session: session, ending: ending) {                 // 場面→一枚絵→図鑑に記録→もう一度(=新周回)
                        session = GameSession(seed: UInt64.random(in: .min ... .max), combiName: session.combiName, myName: session.myName, partnerName: session.partnerName)
                        showEnding = false
                    }
                }
            } else {
                YearResultView(session: session,
                               onRestart: { session = GameSession(seed: UInt64.random(in: .min ... .max),
                                                                  combiName: session.combiName, myName: session.myName, partnerName: session.partnerName) },
                               onEnding: session.endingID != nil ? { showEnding = true } : nil,
                               onNextYear: session.careerOver ? nil : { session.startNextYear() })
            }
        } else if let result = session.pendingResult {
            if let r = result.results.last, r.name == "GP決勝", !r.passed {
                FinalsPresentationView(session: session)              // 決勝で負けた夜も決勝演出で見せる（負け版・監査E-08）
            } else {
                TournamentResultView(session: session, summary: result)   // S2波形→S3講評
            }
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
        Text(label).font(.system(size: Font.mzScaled(11), weight: .heavy))
            .foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 5)
            .background(.black.opacity(0.45), in: Capsule())
    }

    /// 長時間の画面往復（メモリの漏れ点検）：1手ずつ待ちを置いて本物の画面を通し、年末・決勝・エンディングも通る。
    private func soakLoop() async {
        let ms = UInt64(ProcessInfo.processInfo.environment["MZ_SOAK_MS"] ?? "") ?? 120
        var rounds = 0
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: ms * 1_000_000)
            let s = session
            if s.winFinale { try? await Task.sleep(nanoseconds: 1_500_000_000); s.acknowledgeWin(); continue }
            if s.watchingFinal { s.finishWatchingFinal(winner: "—"); continue }
            if s.pendingChoiceEvent != nil { s.dismissChoiceEvent(); continue }
            if s.pendingResult != nil { s.acknowledgeResult(); continue }
            if s.finished {
                try? await Task.sleep(nanoseconds: 800_000_000)
                if s.careerOver {
                    if s.endingID != nil { showEnding = true; try? await Task.sleep(nanoseconds: 3_000_000_000) }
                    showEnding = false
                    rounds += 1
                    if rounds % 2 == 0 { forceChampion() }
                    else { session = GameSession(seed: UInt64.random(in: .min ... .max), combiName: s.combiName, myName: s.myName, partnerName: s.partnerName) }
                } else { s.startNextYear() }
                continue
            }
            switch s.phase {
            case .tournamentDecision: s.decideTournament(.新幹線)
            case .freeAction:
                if s.state.money < 250_000 { s.choose(.job(.標準)) }
                else if s.state.stamina >= 45 { s.choose(.train(.ネタ作り)) }
                else { s.choose(.rest(.完全休養)) }
            case .gpRound, .gpRevival, .gpFinal: s.advanceAuto()
            default: break
            }
        }
    }

    private func forceChampion() {
        session = GameSession(startState: GameSession.debugMaxedState())
        session.debugAdvanceToChampionFinale()
    }

    /// MZ_UI=frame の舞台の状態（MZ_MODE=preshow/lit/judging/winner/loser/spectator・既定 lit）
    private var debugFrameMode: StageFrame.Mode {
        switch ProcessInfo.processInfo.environment["MZ_MODE"] {
        case "preshow": return .preshow
        case "judging": return .judging
        case "winner": return .winner
        case "loser": return .loser
        case "spectator": return .spectator
        default: return .lit
        }
    }

    /// 能力マックスの新規ゲームを第1週から始める（自動プレイしない＝手で無双して遊ぶ）。
    private func forceMaxedPlay() {
        session = GameSession(startState: GameSession.debugMaxedState())
        started = true
    }
    #endif
}
