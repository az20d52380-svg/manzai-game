// ChoiceEvent.swift
// 選択肢イベントの純データ（発火種別・選択肢の効果・選択可否ゲート）。正典: proposals/0024（実装ブリーフ）
// ＋ 0010/0017/0018/0019/0021（各イベントの本文・効果確定）。テキストはUI層（ManzaiGame/Sources）。
// 効果は EventEffect（ChoiceEventEffect.swift）のみ＝RandomSource を一切呼ばない＝golden不変。
// ★MVPスコープ（0024確定）: 確定発火＋確定効果のみ。抽選・効果内ロールは入れない（0010のA内部判定は本編送り）。

public enum ChoiceEventKind: String, CaseIterable {
    // --- 確定発火（既存フラグを見て点火・抽選しない） ---
    case justLostRehearsal   // 0017: 負けた日の稽古場（発火=justLost）
    case styleTalk           // 0019: 型を捨てる相談（発火=lossStreak>=3・一発化フラグで反復制御）
    case justPassedFork      // 0018: 通った日の分かれ道（発火=justPassedStage・weeksLeft>=3・低体力ガード）
    case preTournamentEve    // 0010: 前夜の一本（発火=weeksLeft==1・格の高い大会のみ）
    case tsuukaBreak         // 0021: 慣れの外し方（発火=相性が初めて15に到達した週・一発化）
    case earlyFormality      // 0020: まだ敬語の残る間（発火=結成初期(week<15)かつ他人行儀帯・一発化）
    case namelessReservationSlip  // 0028: 名前の無い予約票（確定発火=compat>=8・大会2-5週前・一発化。選択肢なしフレーバー）
    // --- 週次ランダム抽選プール（UI層RNGで発火＝golden非対象。効果は決定的delta＝golden不変） ---
    case brokeDrinkingInvite // 0011: 行けない飲み会（発火帯=所持金<5万・相性<上限）
    case senpaiMeishi        // 0013: 先輩の名刺（発火帯=所持金<20万・知名度<50）
    case peerFoldedChair     // 0015: 畳んだコンビの椅子（発火帯=week>=20）
    case lineupTop           // 0025: 香盤表の一番上（前座帯 知名度<20・選択肢なしフレーバー）
    case greenroomSilentTen  // 0027: 楽屋で無言の十分（噛み合い帯 相性8-14・選択肢なしフレーバー）
    case lastTrainReview     // 0014: 終電までの反省会（前座帯 知名度<20・選択肢あり）
    case luckyThirdLine      // 0029: 三行目を一度で（好調帯 体力80+・連敗なし・大会前・選択肢なしフレーバー）
    case regularEmployment   // 0023: 正社員の話（バイト多数×金欠<10万・選択肢あり・段階1のみ）
    case wroteOneTonight     // 0016: 書けた一本（持ちネタあり＝一本まとまった夜・選択肢あり・翌週バフはPhase2）

    /// 週次抽選プールに属するか（false=上の確定発火群）。GameSession の週次抽選が allCases から拾う。
    public var isWeeklyRandom: Bool {
        switch self {
        case .brokeDrinkingInvite, .senpaiMeishi, .peerFoldedChair, .lineupTop, .greenroomSilentTen,
             .lastTrainReview, .luckyThirdLine, .regularEmployment, .wroteOneTonight:
            return true
        default:
            return false
        }
    }
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
        case .tsuukaBreak:
            // 0021 慣れの外し方: A=センス+2/相性-1/体力-10（崩す）　B=表現+2/相性+1（固める・伸びしろ不動）
            return [
                ChoiceEventChoice(id: "A", effects: [
                    .ability(.センス, 2), .compat(-1), .stamina(-10),
                ]),
                ChoiceEventChoice(id: "B", effects: [
                    .ability(.表現, 2), .compat(1),
                ]),
            ]
        case .earlyFormality:
            // 0020 まだ敬語の残る間: A=相性+2/体力-15（踏み込む・実弾で買う）　B=体力+10/メンタル+1（間合いを保つ）
            return [
                ChoiceEventChoice(id: "A", effects: [
                    .compat(2), .stamina(-15),
                ]),
                ChoiceEventChoice(id: "B", effects: [
                    .stamina(10), .ability(.メンタル, 1),
                ]),
            ]
        case .brokeDrinkingInvite:
            // 0011 行けない飲み会: A=行く(所持金-4000/相性+1/メンタル+1)　B=残る(発想+1/メンタル-1)
            return [
                ChoiceEventChoice(id: "A", effects: [
                    .money(-4000), .compat(1), .ability(.メンタル, 1),
                ]),
                ChoiceEventChoice(id: "B", effects: [
                    .ability(.発想, 1), .ability(.メンタル, -1),
                ]),
            ]
        case .senpaiMeishi:
            // 0013 先輩の名刺: A=紹介を受ける(華+1/知名度+2/メンタル-1)　B=飯だけ(体力+15/メンタル+1/相性+1)
            return [
                ChoiceEventChoice(id: "A", effects: [
                    .ability(.華, 1), .fame(2), .ability(.メンタル, -1),
                ]),
                ChoiceEventChoice(id: "B", effects: [
                    .stamina(15), .ability(.メンタル, 1), .compat(1),
                ]),
            ]
        case .peerFoldedChair:
            // 0015 畳んだコンビの椅子: A=空き枠を引き継ぐ(知名度+2/体力-10/メンタル-1)　B=送り出しだけ(メンタル+1/相性+1)
            return [
                ChoiceEventChoice(id: "A", effects: [
                    .fame(2), .stamina(-10), .ability(.メンタル, -1),
                ]),
                ChoiceEventChoice(id: "B", effects: [
                    .ability(.メンタル, 1), .compat(1),
                ]),
            ]
        case .lastTrainReview:
            // 0014 終電までの反省会: A=その場で洗う(メンタル-2/体力-5/センス発想の低い方+2)　B=畳んで立て直す(体力+5/メンタル+1/相性+1/所持金-800)
            return [
                ChoiceEventChoice(id: "A", effects: [
                    .ability(.メンタル, -2), .stamina(-5), .weakerSenseIdeaPlus(2),
                ]),
                ChoiceEventChoice(id: "B", effects: [
                    .stamina(5), .ability(.メンタル, 1), .compat(1), .money(-800),
                ]),
            ]
        case .regularEmployment:
            // 0023 正社員の話（段階1のみ・段階2 growthBudget減算は規律Aで後日）: A=受ける(所持金+3万/体力-10/メンタル-1)　B=断る(メンタル+2/相性+1)
            return [
                ChoiceEventChoice(id: "A", effects: [
                    .money(30000), .stamina(-10), .ability(.メンタル, -1),
                ]),
                ChoiceEventChoice(id: "B", effects: [
                    .ability(.メンタル, 2), .compat(1),
                ]),
            ]
        case .wroteOneTonight:
            // 0016 書けた一本: A=今夜詰める(発想+2/表現+1/体力-15)　B=寝かせる(体力+5/メンタル+1)
            //   ※B の「翌週のネタ合わせ効果アップ」は翌週バフ機構が要る＝Phase2。MVPは即時回復のみ（0010/0018型トレード）
            return [
                ChoiceEventChoice(id: "A", effects: [
                    .ability(.発想, 2), .ability(.表現, 1), .stamina(-15),
                ]),
                ChoiceEventChoice(id: "B", effects: [
                    .stamina(5), .ability(.メンタル, 1),
                ]),
            ]
        case .namelessReservationSlip, .lineupTop, .greenroomSilentTen, .luckyThirdLine:
            return []   // 選択肢なしフレーバー（会話を送り切って閉じる・効果なし）
        }
    }

    /// 週次抽選イベントの発火ゲート（純関数・RNG非消費）。確定発火の kind は常に false（抽選プール外）。
    /// GameSession の週次抽選が「発火帯に入っている候補」だけを対象にする（proposals 各票の発火条件）。
    public static func weeklyFireable(_ kind: ChoiceEventKind, state: GameState, week: Int, config: GameConfig) -> Bool {
        switch kind {
        case .brokeDrinkingInvite:
            // 0011: 低所持金帯（<5万）＋相性が上限未満（上限だと A の相性+1 が死んで B 上位互換化＝proposal リスク節）
            return state.money < 50_000 && state.compat < config.compatCap
        case .senpaiMeishi:
            // 0013: 奢られる帯（所持金<20万）＋まだ繋がれる側（知名度<50）
            return state.money < 200_000 && state.fame < 50
        case .peerFoldedChair:
            // 0015: 芸歴が進んだ帯（week>=20）。同期の解散＝プレイの巧拙と無関係の"世界の彩り"
            return week >= 20
        case .lineupTop:
            // 0025: 前座が"一番上"になる皮肉が最も映える低知名度帯（<20）。フリーライブ直後は状態帯に緩めた
            return state.fame < 20
        case .greenroomSilentTen:
            // 0027: 噛み合い始めの帯（8-14）のみ。低評価判定は現状無いので compat 帯だけで絞る（proposal 安全側）
            return (8...14).contains(Int(state.compat))
        case .lastTrainReview:
            // 0014: 客の薄い帯（知名度<20）。フリーライブ直後は状態帯に緩めた
            return state.fame < 20
        case .luckyThirdLine:
            // 0029: 好調帯（体力80+）。連敗なし・大会2-4週前の追加ゲートは GameSession 側（lossStreak/weeksLeft を要する）
            return state.stamina >= 80
        case .regularEmployment:
            // 0023: 金欠帯（<10万）。バイトを重ねた条件は GameSession 側の jobCount ゲート（UI層カウンタ）
            return state.money < 100_000
        case .wroteOneTonight:
            // 0016: 持ちネタが1本でもある＝「一本まとまった夜」の文脈が立つ。ネタ作り直後は状態帯に緩めた
            return !state.netas.isEmpty
        default:
            return false
        }
    }
}
