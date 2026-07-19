// ChoiceEvent.swift
// 選択肢イベントの純データ（発火種別・選択肢の効果・選択可否ゲート）。正典: proposals/0024（実装ブリーフ）
// ＋ 0010/0017/0018/0019（各イベントの本文・効果確定）。テキスト（地の文・会話）はUI層（ManzaiGame/Sources）。
// 効果は EventEffect（ChoiceEventEffect.swift）のみ＝RandomSource を一切呼ばない＝golden不変。
// ★MVPスコープ（0024確定）: 確定発火＋確定効果のみ。抽選・効果内ロールは入れない（0010のA内部判定は本編送り）。

public enum ChoiceEventKind: String, CaseIterable {
    case justLostRehearsal   // 0017: 負けた日の稽古場（発火=justLost）
    case styleTalk           // 0019: 型を捨てる相談（発火=lossStreak>=3・一発化フラグで反復制御）
    case justPassedFork      // 0018: 通った日の分かれ道（発火=justPassedStage・weeksLeft>=3・低体力ガード）
    case preTournamentEve    // 0010: 前夜の一本（発火=weeksLeft==1・格の高い大会のみ）
}

/// 選択肢1件（純データ）。gate は選択可否（0017C の所持金ゲート等）。デフォルトは常に選択可。
public struct ChoiceEventChoice {
    public let id: String                        // "A" / "B" / "C"
    public let effects: [EventEffect]
    public let gate: (GameState) -> Bool
    public init(id: String, effects: [EventEffect], gate: @escaping (GameState) -> Bool = { _ in true }) {
        self.id = id; self.effects = effects; self.gate = gate
    }
}

/// 各イベントの選択肢定義（数値は全て【仮】・水準確定はMac側sim較正）。
public enum ChoiceEventTable {

    /// 0017 負けた日の稽古場: A=最弱4技能(メンタル除外)+2/メンタル-2/体力-10
    ///                     B=体力+15/メンタル+2
    ///                     C=相性+2/メンタル+1/体力+5/所持金-1500（所持金<1500で非活性）
    public static func choices(for kind: ChoiceEventKind, config: GameConfig) -> [ChoiceEventChoice] {
        switch kind {
        case .justLostRehearsal:
            return [
                ChoiceEventChoice(id: "A", effects: [
                    .weakestSkillPlus(2), .ability(.メンタル, -2), .stamina(-10),
                ]),
                ChoiceEventChoice(id: "B", effects: [
                    .stamina(15), .ability(.メンタル, 2),
                ]),
                ChoiceEventChoice(id: "C", effects: [
                    .compat(2), .ability(.メンタル, 1), .stamina(5), .money(-1500),
                ], gate: { $0.money >= 1500 }),
            ]
        case .styleTalk:
            // 0019 型を捨てる相談: A=発想+2/表現-1/相性-2　B=表現+2/相性+1/メンタル-1
            return [
                ChoiceEventChoice(id: "A", effects: [
                    .ability(.発想, 2), .ability(.表現, -1), .compat(-2),
                ]),
                ChoiceEventChoice(id: "B", effects: [
                    .ability(.表現, 2), .compat(1), .ability(.メンタル, -1),
                ]),
            ]
        case .justPassedFork:
            // 0018 通った日の分かれ道: A=知名度+3/体力-15/メンタル-1　B=センス発想低い方+1/相性+1
            return [
                ChoiceEventChoice(id: "A", effects: [
                    .fame(3), .stamina(-15), .ability(.メンタル, -1),
                ]),
                ChoiceEventChoice(id: "B", effects: [
                    .weakerSenseIdeaPlus(1), .compat(1),
                ]),
            ]
        case .preTournamentEve:
            // 0010 前夜の一本: A=表現+1（確定効果のみ・内部ロールは本編送り＝0024確定）　B=体力+10/メンタル+1
            return [
                ChoiceEventChoice(id: "A", effects: [
                    .ability(.表現, 1),
                ]),
                ChoiceEventChoice(id: "B", effects: [
                    .stamina(10), .ability(.メンタル, 1),
                ]),
            ]
        }
    }
}
