// AppSaveFixtureTests.swift
// アプリの中断セーブ（GameSession.SaveData）の固定 JSON を今のコードで復号する（code_review_2026-10-25e §3-1・§3-4）。
// 保存に載る enum（ChoiceEventKind／BandCategory など）の case を消す・名前を変える、非 Optional のキーを足すと、
// 旧セーブ全体が読めずに新規へ戻る（loadedOrNew）。それを赤で止める。GameCore 側は SaveFixtureTests。
// 固定 JSON の作り直しは `TEST_RUNNER_MZ_WRITE_FIXTURE=1 xcodebuild test … -only-testing:ManzaiGameTests/AppSaveFixtureTests` だけ。

import XCTest
@testable import ManzaiGame
import GameCore

final class AppSaveFixtureTests: XCTestCase {

    private var fixtureURL: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("TestFixtures/save_1025.json")
    }

    func testFixtureSaveStillDecodes() throws {
        if ProcessInfo.processInfo.environment["MZ_WRITE_FIXTURE"] != nil {
            let s = GameSession(seed: 1)
            s.saveNow()
            let d = try XCTUnwrap(GameSession.store.data(forKey: "manzai.save.v1"))
            var save = try JSONDecoder().decode(GameSession.SaveData.self, from: d)
            save.firedWeeklyEvents = Set(ChoiceEventKind.allCases)
            save.pendingChoiceEvent = ChoiceEventKind.allCases.first
            save.categoryLog = [1: .keiko, 2: .baito, 3: .kaifuku, 4: .offer, 5: .taikai]
            save.comboKind = "femaleMale"
            let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys, .prettyPrinted]
            try FileManager.default.createDirectory(at: fixtureURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try enc.encode(save).write(to: fixtureURL)
            throw XCTSkip("固定 JSON を書き出した: \(fixtureURL.path)")
        }
        let save = try JSONDecoder().decode(GameSession.SaveData.self, from: Data(contentsOf: fixtureURL))
        XCTAssertFalse(save.firedWeeklyEvents.isEmpty, "選択イベントの case が復号できた")
        XCTAssertEqual(save.categoryLog.count, 5, "日程の印の全 case が復号できた")
        // 寛容な復号でも case を消したら赤にする（固定 JSON の文字列の数と、読めた数が一致すること）
        let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: fixtureURL)) as? [String: Any]
        let rawFired = try XCTUnwrap(raw?["firedWeeklyEvents"] as? [String])
        XCTAssertEqual(save.firedWeeklyEvents.count, rawFired.count, "固定 JSON の選択イベントの種別が全部今も在る")
        let restored = GameSession(restoring: save)
        XCTAssertEqual(restored.comboKind, .femaleMale)
    }

    /// 知らない種別（消した case）が混じった旧セーブでも、セーブ全体は読める＝その要素だけ捨てる（save_compat_audit_1108_v0）。
    func testUnknownChoiceEventKindIsDroppedNotFatal() throws {
        var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: fixtureURL)) as? [String: Any])
        let fired = try XCTUnwrap(obj["firedWeeklyEvents"] as? [String])
        obj["firedWeeklyEvents"] = fired + ["removedKindForTest"]
        obj["pendingChoiceEvent"] = "removedKindForTest"
        let save = try JSONDecoder().decode(GameSession.SaveData.self, from: JSONSerialization.data(withJSONObject: obj))
        XCTAssertEqual(save.firedWeeklyEvents.count, Set(fired).count, "知らない値だけ捨てる")
        XCTAssertNil(save.pendingChoiceEvent, "知らない保留イベントは無し扱い")
    }
}
