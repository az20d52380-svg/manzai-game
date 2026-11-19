// SwallowedModifierTests.swift
// 行末コメントの後ろに書いた SwiftUI の修飾子は、コメントに飲まれて効かない（コンパイルは通る）。
// 11/16：大会の記録と年末の出来事の行で `// …折る.foregroundStyle(sumi)` となり、文字色と行間が消えていた（code_review_1116_wrap §2-1）。
// アプリ側は直接テストできないため、ManzaiGame/Sources の行末コメントを文字で読んで検査する。

import XCTest

final class SwallowedModifierTests: XCTestCase {

    func testNoModifierAfterTrailingComment() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let dir = root.appendingPathComponent("ManzaiGame/Sources")
        let files = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
        XCTAssertGreaterThan(files.count, 20, "ManzaiGame/Sources が読めていない")
        let literal = try NSRegularExpression(pattern: #""(?:[^"\\]|\\.)*""#)
        // コメントの中で、語の直後に「.修飾子(」が続く形（「コメント文.foregroundStyle(」）
        let swallowed = try NSRegularExpression(pattern:
            #"[^\s(（.`\\]\.(foregroundStyle|foregroundColor|font|lineSpacing|padding|frame|opacity|lineLimit|fixedSize|minimumScaleFactor|multilineTextAlignment|background|overlay|accessibility[A-Za-z]*)\("#)
        var bad: [String] = []
        for f in files {
            let src = try String(contentsOf: f, encoding: .utf8)
            for (i, raw) in src.components(separatedBy: "\n").enumerated() {
                let ns = raw as NSString
                let line = literal.stringByReplacingMatches(in: raw, range: NSRange(location: 0, length: ns.length), withTemplate: "\"\"")
                guard let r = line.range(of: "//") else { continue }
                let code = line[..<r.lowerBound].trimmingCharacters(in: .whitespaces)
                if code.isEmpty { continue }   // 行頭のコメント（説明文）は対象外＝行末コメントだけ
                let comment = String(line[r.upperBound...])
                let cn = comment as NSString
                if swallowed.firstMatch(in: comment, range: NSRange(location: 0, length: cn.length)) != nil {
                    bad.append("\(f.lastPathComponent):\(i + 1)")
                }
            }
        }
        XCTAssertEqual(bad, [], "行末コメントに修飾子が飲まれている（コメントを行の最後へ）: \(bad)")
    }
}
