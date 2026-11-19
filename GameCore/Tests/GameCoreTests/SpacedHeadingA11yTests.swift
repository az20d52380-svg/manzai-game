// SpacedHeadingA11yTests.swift
// 字の間に空白を入れた見出し（「番 付 昇 格」）は、VoiceOver が1文字ずつ読む。読み上げ用の名前（accessibilityLabel）を同じ行に付ける（AUTOPILOT 601）。
// アプリ側は直接テストできないため、ManzaiGame/Sources の文字列を文字で読んで検査する。

import XCTest

final class SpacedHeadingA11yTests: XCTestCase {
    /// 親ごと読み上げ対象外（accessibilityHidden）になっている所。足す時は理由を添える。
    private static let allowed: Set<String> = [
        "漫 才 の 頂 、 こ こ に 決 ま る",   // 優勝演出の看板の帯（親の HStack が accessibilityHidden）
    ]

    func testSpacedHeadingsHaveLabel() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let dir = root.appendingPathComponent("ManzaiGame/Sources")
        let files = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
        XCTAssertGreaterThan(files.count, 20, "ManzaiGame/Sources が読めていない")
        // Text("一 字 ず つ") ＝1文字と空白が4回以上続く文字列
        let spaced = try NSRegularExpression(pattern: #"Text\("((?:[^ "\\] ){3,}[^ "\\][^"]*)"\)"#)
        var bad: [String] = []
        for f in files {
            let src = try String(contentsOf: f, encoding: .utf8)
            for (i, line) in src.components(separatedBy: "\n").enumerated() {
                let ns = line as NSString
                for m in spaced.matches(in: line, range: NSRange(location: 0, length: ns.length)) {
                    let t = ns.substring(with: m.range(at: 1))
                    if Self.allowed.contains(t) || line.contains("accessibilityLabel") || line.contains("accessibilityHidden") { continue }
                    bad.append("\(f.lastPathComponent):\(i + 1) \(t)")
                }
            }
        }
        XCTAssertEqual(bad, [], "字間に空白のある見出しに読み上げ用の名前が無い: \(bad)")
    }
}
