// PersistedEnumPin1110AppTests.swift
// アプリ側でセーブ・周回メタに載る enum の rawValue を 2026-11-10 時点の一覧で固定する（save_compat_audit_1108_v0 §足すべきテストの案 6）。
//  - EndingID・TrophyID：周回メタ（エンディング記録・図鑑）の辞書のキー。消す・改名で記録が消える
//  - ComboKind・MeetingKind：SaveData に文字列で保存（未知は既定値に寄せる＝改名すると黙って形が変わる）
//  - BandCategory：categoryLog（未知は捨てる＝改名すると行動内訳の帯が欠ける）
// case を足すのは許可。改名する時は読み込み側の読み替えを先に作ってから一覧を直す。

import XCTest
@testable import ManzaiGame

final class PersistedEnumPin1110AppTests: XCTestCase {

    private func pin<E: RawRepresentable>(_ t: E.Type, _ name: String, _ raws: [String],
                                          file: StaticString = #filePath, line: UInt = #line) where E.RawValue == String {
        for r in raws {
            XCTAssertNotNil(E(rawValue: r), "\(name) の保存値「\(r)」が読めなくなった（旧セーブ・周回の記録が壊れる）", file: file, line: line)
        }
    }

    func testPersistedRawValuesStillDecode() {
        pin(EndingID.self, "EndingID", ["nightEscape", "breakup", "gaveUp", "keptGoing", "tenYearsClose", "tenYearsTrue", "championRetire", "championPair"])
        pin(TrophyID.self, "TrophyID", (1...22).map { String(format: "t%02d", $0) })
        pin(ComboKind.self, "ComboKind", ["maleMale", "femaleFemale", "maleFemale", "femaleMale"])
        pin(MeetingKind.self, "MeetingKind", ["highSchool", "school", "partTime", "afterBreakup"])
        pin(BandCategory.self, "BandCategory", ["keiko", "baito", "kaifuku", "offer", "taikai"])
    }

    /// ComboKind.from／MeetingKind.from は旧セーブ（nil）と未知の値を既定値に寄せる。固定した値はそのまま戻る。
    func testFromKeepsPinnedValues() {
        for k in ComboKind.allCases { XCTAssertEqual(ComboKind.from(k.rawValue), k) }
        for k in MeetingKind.allCases { XCTAssertEqual(MeetingKind.from(k.rawValue), k) }
        XCTAssertEqual(ComboKind.from(nil), .maleMale)
        XCTAssertEqual(MeetingKind.from(nil), .highSchool)
    }
}
