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
        let restored = GameSession(restoring: save)
        XCTAssertEqual(restored.comboKind, .femaleMale)
    }
}
