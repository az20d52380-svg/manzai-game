import XCTest
import GameCore
@testable import ManzaiGame

/// GameSession の「DEBUG 以外で未通過だった」処理の穴埋め（11/09 網羅測定より）
final class SessionCoverage1109Tests: IsolatedStoreTestCase {
    // StageInfo.length の既定値
    func testStageInfoDefaultLengthIsMiddle() {
        let info = GameSession.StageInfo(week: 10, name: "新人賞", line: 5, highStakes: false, isGP: false)
        XCTAssertEqual(info.length, .中尺)
    }

    // 旧版セーブ互換：予告を出した扱いだが、選んでおらず保留にも無い＝未発火に戻して復元する
    func testRestoreResetsRiftWarnWhenFiredButNeverSeen() throws {
        var st = GameState(config: GameConfig()); st.compat = 12; st.money = 5_000_000; st.rift = 10; st.riftWarned = true
        let s = GameSession(startState: st)
        XCTAssertEqual(s.pendingChoiceEvent, .riftWarning)
        XCTAssertTrue(s.didFireRiftWarn)
        s.dismissChoiceEvent()   // 選ばず閉じる＝riftWarnChoice nil・保留なし・発火済み
        XCTAssertNil(s.riftWarnChoice)
        let restored = GameSession.loadedOrNew()
        XCTAssertFalse(restored.didFireRiftWarn, "見ないまま消えた予告は未発火に戻る")
    }

    // 予告を選んだ後なら、復元しても発火済みのまま
    func testRestoreKeepsRiftWarnWhenChoiceMade() {
        var st = GameState(config: GameConfig()); st.compat = 12; st.money = 5_000_000; st.rift = 10; st.riftWarned = true
        let s = GameSession(startState: st)
        s.applyEventChoice(s.availableEventChoices()[0].id)
        s.dismissChoiceEvent()
        XCTAssertNotNil(s.riftWarnChoice)
        let restored = GameSession.loadedOrNew()
        XCTAssertTrue(restored.didFireRiftWarn)
        XCTAssertEqual(restored.riftWarnChoice, s.riftWarnChoice)
    }

    // 戦績の行：賞金の桁が Int を超える時は 0 扱い（クラッシュしない）
    func testParseLogLineHugePrizeFallsBackToZero() {
        let parts = GameSession.parseLogLine("第3週: 新人賞 優勝 +99999999999999999999万")
        XCTAssertEqual(parts.count, 1)
        XCTAssertEqual(parts[0].prize, 0)
        XCTAssertEqual(parts[0].mark, "優勝")
    }

    // 戦績の行：賞金だけで題が空になっても落ちず、札は「休」
    func testParseLogLineOnlyPrizeGivesEmptyTitleAndRestMark() {
        let parts = GameSession.parseLogLine("第4週: +5万")
        XCTAssertEqual(parts.count, 1)
        XCTAssertEqual(parts[0].title, "")
        XCTAssertEqual(parts[0].mark, "休")
        XCTAssertEqual(parts[0].prize, 5)
    }

    // 戦績の行：週の区切りが無く本文が空でも1件返る
    func testParseLogLineEmptyLine() {
        let parts = GameSession.parseLogLine("")
        XCTAssertEqual(parts.count, 1)
        XCTAssertEqual(parts[0].week, "")
        XCTAssertEqual(parts[0].mark, "休")
        XCTAssertEqual(parts[0].prize, 0)
    }

    // GP1回戦の名前が設定に無い（空）時は既定名で記録を探す
    func testLoggedGPEntryFallsBackWhenRoundNamesEmpty() {
        var cfg = GameConfig()
        cfg.calendar.gpRoundNames = []
        XCTAssertTrue(GameSession.loggedGPEntry(in: ["第20週: 頂GP 1回戦 通過"], config: cfg))
        XCTAssertFalse(GameSession.loggedGPEntry(in: ["第3週: 新人賞 敗退"], config: cfg))
    }

    // 記録が空なら GP 出場なし
    func testLoggedGPEntryFalseForEmptyLog() {
        XCTAssertFalse(GameSession.loggedGPEntry(in: [], config: GameConfig()))
    }
}
