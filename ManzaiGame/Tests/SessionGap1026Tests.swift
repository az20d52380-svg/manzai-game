// アプリ側の穴埋めテスト 10/26（カバー率で未通過だった本番の経路・現在の挙動を固定）
// ①優勝の演出中に閉じたセーブの復元＝演出から出し直す（A-3）②おすすめ注ぎの延長（監査F-02）③予定表の敗者復活の行
import XCTest
import GameCore
@testable import ManzaiGame

final class SessionGap1026Tests: IsolatedStoreTestCase {
    private func drive(_ s: GameSession, maxSteps: Int = 600, until stop: (GameSession) -> Bool) {
        var steps = 0
        while !stop(s), !s.finished, steps < maxSteps {
            steps += 1
            if s.watchingFinal { return }
            if s.pendingChoiceEvent != nil { s.dismissChoiceEvent(); continue }
            if s.pendingResult != nil { s.acknowledgeResult(); continue }
            switch s.phase {
            case .tournamentDecision: s.decideTournament(.夜行バス)
            case .freeAction:         s.choose(.job(.標準))
            case .gpRound, .gpRevival, .gpFinal: s.advanceAuto()
            default: return
            }
        }
    }

    // MARK: ① 優勝の演出中に閉じた

    func testRestoreDuringWinFinaleReplaysFinale() throws {
        var cfg = GameConfig()
        cfg.calendar.gpRounds = cfg.calendar.gpRounds.map { ($0.week, 0) }; cfg.calendar.gpFinalLine = 0
        let s = GameSession(config: cfg, startState: GameSession.debugMaxedState(config: cfg))
        drive(s) { $0.winFinale }
        XCTAssertTrue(s.winFinale)
        let data = try XCTUnwrap(GameSession.store.data(forKey: "manzai.save.v1"), "演出中も保存されている")
        let save = try JSONDecoder().decode(GameSession.SaveData.self, from: data)
        guard case .yearDone(let o) = save.phase else { return XCTFail("保存された段は年の終わり") }
        XCTAssertTrue(o.champion)
        let r = GameSession(restoring: save, config: cfg)
        XCTAssertTrue(r.winFinale, "演出から出し直す")
        XCTAssertFalse(r.finished, "年末の画面へは飛ばさない（「次へ」で S4）")
        XCTAssertEqual(r.outcome?.champion, true)
    }

    // MARK: ② おすすめ注ぎの延長

    func testRecommendedAllocationExtendsPastCanonPlanAndExhausts() {
        // 成長予算が尽きて一番低い能力は伸びないが、予算の外のメンタルにはまだ注げる＝正典の台本は止まる（F-02 の形）
        var st = GameState(config: GameConfig())
        st.exp閃き = 50; st.exp語彙 = 50; st.exp間合い = 50; st.exp存在感 = 50; st.exp胆力 = 150
        st.growthBudget = 0
        st[.メンタル] = Ability.allCases.filter { $0 != .メンタル }.map { st[$0] }.max()! + 10
        let s = GameSession(startState: st)
        let canon = GameEngine.recommendedPlan(state: s.state, config: s.config)
        let plan = s.recommendedAllocation()
        XCTAssertGreaterThan(plan.count, canon.count, "台本の続きを UI 側で拾う")
        XCTAssertEqual(Array(plan.prefix(canon.count)), canon, "先頭は正典の台本のまま")
        var probe = s.state
        for a in plan { GameEngine.pourStep(a, to: &probe, config: s.config) }
        for a in Ability.allCases {
            var p = probe
            XCTAssertEqual(GameEngine.pourStep(a, to: &p, config: s.config), 0, accuracy: 1e-9, "\(a) にもう注げない＝使い切り")
        }
        XCTAssertEqual(s.previewAllocation([]).exp胆力, st.exp胆力, "見積もりは状態を変えない")
    }

    // MARK: ③ 予定表の敗者復活

    func testUpcomingStagesShowsRevivalWhenOnlyRevivalLeft() throws {
        var cfg = GameConfig()
        cfg.calendar.gpRounds = cfg.calendar.gpRounds.enumerated().map { ($1.week, $0 == 4 ? 9999 : 0) }
        cfg.calendar.gpRevivalLine = 9999
        let s = GameSession(config: cfg, startState: GameSession.debugMaxedState(config: cfg))
        drive(s) { $0.upcomingStages().contains { $0.name == "敗者復活" } }
        guard !s.finished else { throw XCTSkip("敗者復活の権利が立たなかった") }
        let gp = s.upcomingStages().filter(\.isGP)
        XCTAssertEqual(gp.map(\.name), ["敗者復活"], "回戦・決勝は消え、敗者復活の行だけ")
        XCTAssertEqual(gp.first?.week, cfg.calendar.gpFinalWeek)
        XCTAssertEqual(gp.first?.length, NetaCatalog.lengthForGPRevival)
        XCTAssertEqual(gp.first?.highStakes, true)
    }
}
