// SaveDataConventionTests.swift
// 監査 A-6: ManzaiGame/Sources/GameSession.swift の SaveData に「非Optional」を足すと旧セーブが全部復号失敗→
// 退避して新規＝プレイヤーの進行が消える。規約（後から足す物は Optional）を人頼みにせず、ソースを読んで検査する。
// SaveData はアプリ側の型でここからは直接復号できないため、宣言を文字で読む（#filePath から repo 根を辿る）。

import XCTest

final class SaveDataConventionTests: XCTestCase {

    /// 初版から非Optionalで存在する項目（凍結）。ここに足す＝旧セーブ破壊。足したくなったら Optional にすること。
    private static let frozenNonOptional: Set<String> = [
        "runner", "phase", "log", "lossStreak", "justPassedStage", "justLostStage", "styleTalkDone",
        "didFireTsuukaChoice", "didFireEarlyFormality", "didFireNamelessSlip", "didFireTaniguchiJob",
        "uiEventRng", "firedWeeklyEvents", "weeklyEventFiredCount", "lastEventRollWeek", "jobCount",
        "lastBanterRollWeek", "categoryLog", "totalPrize", "combiName",
    ]

    private func saveDataFields() throws -> [(name: String, type: String)] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let src = try String(contentsOf: root.appendingPathComponent("ManzaiGame/Sources/GameSession.swift"), encoding: .utf8)
        let lines = src.components(separatedBy: "\n")
        guard let start = lines.firstIndex(where: { $0.contains("struct SaveData: Codable") }) else {
            XCTFail("SaveData の宣言が見つからない"); return []
        }
        var out: [(String, String)] = []
        for line in lines[(start + 1)...] {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t == "}" { break }
            guard t.hasPrefix("var ") else { continue }
            let body = t.dropFirst(4).components(separatedBy: "//")[0]
            let parts = body.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            out.append((parts[0], parts[1]))
        }
        return out
    }

    func testSaveDataNonOptionalFieldsAreFrozen() throws {
        let fields = try saveDataFields()
        XCTAssertGreaterThan(fields.count, 20, "SaveData の項目が読めていない")
        let nonOptional = Set(fields.filter { !$0.type.hasSuffix("?") }.map { $0.name })
        XCTAssertEqual(nonOptional, Self.frozenNonOptional,
                       "SaveData に非Optionalの項目を足した/消した。旧セーブが復号できなくなる＝足す項目は必ず Optional に（監査A-6）")
    }
}
