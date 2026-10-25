// 表示用の state と runner の正の状態が、どの入口を呼んだ後もずれないことを固定する（懸念の台帳 L55）
import XCTest
import GameCore
@testable import ManzaiGame

final class StateSyncTests: IsolatedStoreTestCase {
    private func bytes(_ s: GameState) -> Data {
        let e = JSONEncoder(); e.outputFormatting = .sortedKeys
        return try! e.encode(s)
    }
    private func assertInSync(_ s: GameSession, _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(bytes(s.state), bytes(s.debugRunnerState), "state と runner.state がずれた：\(label)", file: file, line: line)
    }

    /// 行動を順に回しながら2年通し、入口を1つ呼ぶごとに突き合わせる
    func testStateMirrorsRunnerThroughTwoYears() {
        let s = GameSession()
        let actions: [WeekAction] = [.train(.ネタ作り), .train(.ネタ合わせ), .job(.標準), .rest(.気分転換),
                                     .train(.ネタ見せ会), .job(.キツい), .rest(.相方と過ごす), .job(.楽)]
        var i = 0, steps = 0, years = 0
        assertInSync(s, "開始")
        while years < 2, steps < 1500 {
            steps += 1
            if s.watchingFinal { s.finishWatchingFinal(winner: "観戦の勝者"); assertInSync(s, "観戦"); continue }
            if s.pendingChoiceEvent != nil {
                if let c = s.availableEventChoices().first { s.applyEventChoice(c.id); assertInSync(s, "選択 週\(s.week)") }
                s.dismissChoiceEvent()   // 画面と同じ＝選んだ後の会話を閉じる
                assertInSync(s, "選択イベント 週\(s.week)"); continue
            }
            if s.pendingResult != nil { s.acknowledgeResult(); assertInSync(s, "結果 週\(s.week)"); continue }
            if s.winFinale { s.acknowledgeWin(); assertInSync(s, "勝ち版"); continue }
            if s.finished {
                years += 1
                if years < 2 { s.startNextYear(); assertInSync(s, "次の年") }
                continue
            }
            switch s.phase {
            case .tournamentDecision: s.decideTournament(.夜行バス)
            case .freeAction(let offer):
                if offer != nil, i % 3 == 0 { s.choose(.acceptOffer) } else { s.choose(actions[i % actions.count]) }
                i += 1
            case .gpRound, .gpRevival, .gpFinal: s.advanceAuto()
            default: XCTFail("想定外の段 \(s.phase)"); return
            }
            assertInSync(s, "週\(s.week) \(s.phase)")
        }
        XCTAssertEqual(years, 2, "2年通せなかった（steps=\(steps) 週\(s.week) \(s.phase) ev=\(String(describing: s.pendingChoiceEvent)) res=\(s.pendingResult != nil)）")
    }
}
