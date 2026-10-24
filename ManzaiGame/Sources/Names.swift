// Names.swift
// 自分の名前・相方の名前（表示専用・golden非対象）。
// データ（GameCore / DialogueData / ChoiceEventData など）には「谷口」「俺」を直書きのまま残し、
// 画面に出す瞬間（Text(String)）に差し替える。話者判定（顔・色・役札）は元の名前のまま行う。
//   ・文の中の「谷口」        → 相方の名前（「谷口さん」「谷口の」など助詞・敬称はそのまま付く）
//   ・{me}／{partner1}       → 自分／相方の一人称（男＝俺・女＝私）
//   ・文字列がちょうど「俺」  → 自分の名前（話し手の札だけ。心の声・地の文の「俺」は触らない）
// 空欄＝従来どおり（俺／谷口）。

import SwiftUI

enum Names {
    static let maxLength = 6
    static let defaultPartner = "谷口"
    static let defaultMe = "俺"
    /// 空＝既定（俺）
    static var me = ""
    /// 既定＝谷口
    static var partner = defaultPartner

    /// コンビの形（既定＝男コンビ）。{me}{partner1} の一人称と、名前が空の時の自分の札（俺／私）を決める
    static var kind: ComboKind = .maleMale
    static func setKind(_ k: ComboKind) { kind = k }

    static func set(me: String?, partner: String?) {
        self.me = clean(me)
        let p = clean(partner)
        self.partner = p.isEmpty ? defaultPartner : p
    }

    static func clean(_ s: String?) -> String {
        String((s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxLength))
    }

    /// 画面に出す文字列へ。差し替えが無ければそのまま返す
    static func show(_ s: String) -> String {
        if s == defaultMe { return me.isEmpty ? kind.meFirstPerson : me }
        var t = s
        if t.contains("{") {   // 一人称の差し込み記号（{me}＝自分・{partner1}＝相方）
            t = t.replacingOccurrences(of: "{me}", with: kind.meFirstPerson)
                .replacingOccurrences(of: "{partner1}", with: kind.partnerFirstPerson)
            t = t.replacingOccurrences(of: "私ら", with: "私たち")
        }
        guard partner != defaultPartner, t.contains(defaultPartner) else { return t }
        return t.replacingOccurrences(of: defaultPartner, with: partner)
    }
}

extension Text {
    /// アプリ内の Text(String) はすべてここを通る（SwiftUI 標準の String/LocalizedStringKey 版より優先される）
    init(_ s: String) { self.init(verbatim: Names.show(s)) }
}
