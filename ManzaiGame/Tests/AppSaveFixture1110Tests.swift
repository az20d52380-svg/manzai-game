// AppSaveFixture1110Tests.swift
// 中断セーブの固定 JSON の2世代目（2026-11-10 時点・save_compat_audit_1108 §足すべきテストの案3）。
// 10/25 版（AppSaveFixtureTests）より後に足した Optional の項目（名前・形・出会い・予告・使った文・道中大会の数など）を
// すべて値ありで固定し、今のコードで復号→復元して値が戻ることを見る。項目の改名・型の変更・case の削除で赤。
// 固定 JSON の作り直しは `TEST_RUNNER_MZ_WRITE_FIXTURE_1110=1 xcodebuild test … -only-testing:ManzaiGameTests/AppSaveFixture1110Tests` だけ（作り直さないのが原則）。

import XCTest
@testable import ManzaiGame
import GameCore

final class AppSaveFixture1110Tests: XCTestCase {

    private var fixtureURL: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("TestFixtures/save_1110.json")
    }

    func testFixture1110StillDecodesWithAllOptionalFields() throws {
        if ProcessInfo.processInfo.environment["MZ_WRITE_FIXTURE_1110"] != nil {
            let saved = GameSession.store
            GameSession.store = UserDefaults(suiteName: "fx1110-\(UUID().uuidString)")!
            defer { GameSession.store = saved }
            let s = GameSession(seed: 7)
            s.saveNow()
            let d = try XCTUnwrap(GameSession.store.data(forKey: "manzai.save.v1"))
            var save = try JSONDecoder().decode(GameSession.SaveData.self, from: d)
            save.firedWeeklyEvents = Set(ChoiceEventKind.allCases)
            save.categoryLog = [1: .keiko, 2: .baito, 3: .kaifuku, 4: .offer, 5: .taikai]
            save.version = GameSession.saveVersion
            save.didFireLostRehearsal = true; save.didFirePassFork = true; save.didFireEve = true; save.didWatchFinal = true
            save.yearHistory = [GameSession.YearRecord(year: 1, roundsPassed: 2, reachedFinal: false, champion: false, bankrupt: false, prize: 0,
                                                       enteredGP: true, dissolved: false, watchedFinal: true)]
            save.debtWarnTier = 1
            save.myName = "佐藤"; save.partnerName = "鈴木"; save.comboKind = "femaleFemale"; save.meetingKind = "partTime"
            save.winAcknowledged = false; save.didFireRiftWarn = true; save.riftWarnChoice = "B"; save.didShowRiftHint = false
            save.usedPicks = ["fx": [0, 2]]; save.usedFanLines = ["fx"]; save.shownOnce = ["fx"]
            save.weeksWithoutPartner = 2; save.injuryNoticeWeeks = 1; save.smallEntered = 3; save.smallWon = 1; save.writeNetaID = 0
            let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys, .prettyPrinted]
            try enc.encode(save).write(to: fixtureURL)
            throw XCTSkip("固定 JSON を書き出した: \(fixtureURL.path)")
        }
        let data = try Data(contentsOf: fixtureURL)
        let save = try JSONDecoder().decode(GameSession.SaveData.self, from: data)
        // 固定 JSON の鍵がひとつも読み落とされていない（Optional の改名は黙って nil になるので鍵で見る）
        let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let back = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(save)) as? [String: Any])
        XCTAssertEqual(Set(raw.keys).subtracting(back.keys), [], "固定 JSON の項目が今の SaveData で読めなくなった")
        XCTAssertEqual(save.firedWeeklyEvents.count, (raw["firedWeeklyEvents"] as? [String])?.count)
        XCTAssertEqual(save.categoryLog.count, 5)
        let r = GameSession(restoring: save)
        XCTAssertEqual(r.comboKind, .femaleFemale)
        XCTAssertEqual(r.meetingKind, .partTime)
    }
}
