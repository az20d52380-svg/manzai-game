// FirstPersonLiteralTests.swift
// 女性の形（10/25〜）：主人公・相方の一人称は {me}/{partner1} で書き、Names.show が形に合わせて「俺／私」にする。
// 台詞の本文に「俺」を直書きすると女性の形でもそのまま出る（female_voice_check_1027_v0）。
// アプリ側の文字列はここから直接読めないため、ManzaiGame/Sources の文字列リテラルを文字で読んで検査する。

import XCTest

final class FirstPersonLiteralTests: XCTestCase {

    /// 「俺」を直書きしてよい文字列（主人公・相方ではない人物の台詞と、形を説明する文）。足す時は誰が言うかを添える。
    private static let allowed: Set<String> = [
        "俺",   // 自分の話者の札（Names.show が完全一致で形ごとの一人称に変える）
        "選んだ形で、台詞の「俺」「私」と見た目が変わる。\\nこのコンビでいるあいだは変えられない。",   // 形の選択画面の説明
        "よし。じゃあ、俺が一年目の頃の話からな",       // 堀口（先輩）
        "よし。社長には、俺から二人の名前を伝えておく",   // 野々村（事務所）
    ]

    func testNoHardcodedOreInAppStrings() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let dir = root.appendingPathComponent("ManzaiGame/Sources")
        let files = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
        XCTAssertGreaterThan(files.count, 20, "ManzaiGame/Sources が読めていない")
        let literal = try NSRegularExpression(pattern: #""((?:[^"\\]|\\.)*)""#)
        var bad: [String] = []
        for f in files {
            let src = try String(contentsOf: f, encoding: .utf8)
            for (i, line) in src.components(separatedBy: "\n").enumerated() {
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.hasPrefix("//") || !line.contains("俺") { continue }
                let ns = line as NSString
                for m in literal.matches(in: line, range: NSRange(location: 0, length: ns.length)) {
                    let s = ns.substring(with: m.range(at: 1))
                    if s.contains("俺"), !Self.allowed.contains(s) {
                        bad.append("\(f.lastPathComponent):\(i + 1) \(s)")
                    }
                }
            }
        }
        XCTAssertTrue(bad.isEmpty, "主人公・相方の台詞は {me}/{partner1} で書く（女性の形で「俺」のまま出る）：\n" + bad.joined(separator: "\n"))
    }
}
