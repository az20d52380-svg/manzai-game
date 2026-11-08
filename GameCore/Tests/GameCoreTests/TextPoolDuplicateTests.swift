import XCTest
import Foundation

/// 文の在庫（週頭の声・ファンレポ・講評）に同じ文が二重に入っていないか（懸念の台帳 L40 の増補が続くため・11/09 定期）。
/// アプリのソースを読む（FirstPersonLiteralTests と同じ方式）。`static let 名前 = [ … ]` の塊ごとに、12字以上の日本語の文の重複を数える。
/// knownOnly（ファンレポの「顔を知られてから」用の部分集合）は他の塊の写しなので対象外。塊をまたぐ重複は意図した物があるので見ない。
final class TextPoolDuplicateTests: XCTestCase {
    private static let files = ["DialogueData.swift", "FanReportData.swift", "JudgeData.swift"]
    private static let skip: Set<String> = ["knownOnly"]

    private func sourcesDir() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ManzaiGame/Sources")
    }

    /// 1行の中の文字列リテラル（エスケープを考慮）と、文字列の外の [ ] の増減
    private func scan(_ line: String) -> (literals: [String], depth: Int) {
        var lits: [String] = [], cur = "", inStr = false, esc = false, depth = 0
        for ch in line {
            if inStr {
                if esc { esc = false; cur.append(ch); continue }
                if ch == "\\" { esc = true; continue }
                if ch == "\"" { inStr = false; lits.append(cur); cur = "" } else { cur.append(ch) }
            } else {
                if ch == "\"" { inStr = true }
                else if ch == "[" { depth += 1 }
                else if ch == "]" { depth -= 1 }
            }
        }
        return (lits, depth)
    }

    private func stripComment(_ line: String) -> String {
        // 文字列の外の // 以降を落とす
        var inStr = false, esc = false, prev: Character = " "
        for i in line.indices {
            let ch = line[i]
            if inStr { if esc { esc = false } else if ch == "\\" { esc = true } else if ch == "\"" { inStr = false } }
            else if ch == "\"" { inStr = true }
            else if ch == "/" && prev == "/" { return String(line[..<line.index(before: i)]) }
            prev = ch
        }
        return line
    }

    private func isJapaneseSentence(_ s: String) -> Bool {
        s.count >= 12 && s.unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) || (0x4E00...0x9FFF).contains($0.value) }
    }

    func testNoDuplicateLinesWithinAPool() throws {
        let header = try NSRegularExpression(pattern: #"static (?:let|var) (\w+)[^=]*=\s*\["#)
        var checkedPools = 0, checkedLines = 0
        var bad: [String] = []
        for name in Self.files {
            let src = try String(contentsOf: sourcesDir().appendingPathComponent(name), encoding: .utf8)
            var pool: String? = nil, depth = 0, seen: [String: Int] = [:]
            for (i, raw) in src.components(separatedBy: "\n").enumerated() {
                let line = stripComment(raw)
                if pool == nil {
                    let ns = line as NSString
                    guard let m = header.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { continue }
                    pool = ns.substring(with: m.range(at: 1)); depth = 0; seen = [:]
                }
                let (lits, d) = scan(line)
                depth += d
                if let p = pool, !Self.skip.contains(p) {
                    for s in lits where isJapaneseSentence(s) {
                        checkedLines += 1
                        if let first = seen[s] { bad.append("\(name) \(p) \(first + 1)行と\(i + 1)行: \(s)") } else { seen[s] = i }
                    }
                }
                if depth <= 0 {
                    if let p = pool, !Self.skip.contains(p) { checkedPools += 1 }
                    pool = nil
                }
            }
        }
        XCTAssertGreaterThan(checkedPools, 20, "塊が読めていない")
        XCTAssertGreaterThan(checkedLines, 800, "文が読めていない")
        XCTAssertTrue(bad.isEmpty, "同じ塊に同じ文が二重:\n" + bad.joined(separator: "\n"))
    }
}
