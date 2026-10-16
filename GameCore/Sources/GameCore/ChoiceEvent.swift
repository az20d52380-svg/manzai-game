// ChoiceEvent.swift
// 選択肢イベントの純データ（発火種別・選択肢の効果・選択可否ゲート）。正典: proposals/0024（実装ブリーフ）
// ＋ 0010/0017/0018/0019/0021（各イベントの本文・効果確定）。テキストはUI層（ManzaiGame/Sources）。
// 効果は EventEffect（ChoiceEventEffect.swift）のみ＝RandomSource を一切呼ばない＝golden不変。
// ★MVPスコープ（0024確定）: 確定発火＋確定効果のみ。抽選・効果内ロールは入れない（0010のA内部判定は本編送り）。

public enum ChoiceEventKind: String, CaseIterable, Codable {   // Codable=中断セーブ用（発火済み集合の永続化）
    // --- 確定発火（既存フラグを見て点火・抽選しない） ---
    case justLostRehearsal   // 0017: 負けた日の稽古場（発火=justLost）
    case styleTalk           // 0019: 型を捨てる相談（発火=lossStreak>=3・一発化フラグで反復制御）
    case justPassedFork      // 0018: 通った日の分かれ道（発火=justPassedStage・weeksLeft>=3・低体力ガード）
    case preTournamentEve    // 0010: 前夜の一本（発火=weeksLeft==1・格の高い大会のみ）
    case tsuukaBreak         // 0021: 慣れの外し方（発火=相性が初めて15に到達した週・一発化）
    case earlyFormality      // 0020: まだ敬語の残る間（発火=結成初期(week<15)かつ他人行儀帯・一発化）
    case namelessReservationSlip  // 0028: 名前の無い予約票（確定発火=compat>=8・大会2-5週前・一発化。選択肢なしフレーバー）
    case taniguchiShortJob        // 0012: 谷口の耳寄りな話（確定発火=金欠<10万・相性8+・大会3週以内なし・選択肢あり）
    case riftWarning              // 0050: 会わない週が続いた（確定発火=riftWarned が初めて true になった週の次の週頭・キャリア1回・docs/endings_spec_v1 §4）
    // --- 週次ランダム抽選プール（UI層RNGで発火＝golden非対象。効果は決定的delta＝golden不変） ---
    case brokeDrinkingInvite // 0011: 行けない飲み会（発火帯=所持金<5万・相性<上限）
    case senpaiMeishi        // 0013: 先輩の名刺（発火帯=所持金<20万・知名度<50）
    case peerFoldedChair     // 0015: 畳んだコンビの椅子（発火帯=week>=20）
    case lineupTop           // 0025: 香盤表の一番上（前座帯 知名度<20・選択肢なしフレーバー）
    case greenroomSilentTen  // 0027: 楽屋で無言の十分（噛み合い帯 相性8-14・選択肢なしフレーバー）
    case lastTrainReview     // 0014: 終電までの反省会（前座帯 知名度<20・選択肢あり）
    case luckyThirdLine      // 0029: 三行目を一度で（好調帯 体力80+・連敗なし・大会前・選択肢なしフレーバー）
    // 0023: 正社員の話。オーナー決定(2026-10-15)で廃止＝抽選から外した（isWeeklyRandom=false）。
    // ただし ChoiceEventKind は Codable で中断セーブ(firedWeeklyEvents/pendingChoiceEvent)に載るため、ケースを消すと古いセーブが読めない＝ケースと本文は互換のため残す。
    case regularEmployment
    case wroteOneTonight     // 0016: 書けた一本（持ちネタあり＝一本まとまった夜・選択肢あり・翌週バフはPhase2）
    case photoShootOffer     // 0022: 撮られる仕事（知名度20-50・選択肢あり。popup2択化で rollOffer 非依存＝golden不変）
    // --- 相方以外の人とのイベント（docs/choice_events_others_v1.md・2026-10-15 オーナー指示。週次抽選プール・各1回制） ---
    case kouhaiInvite        // 0041: 後輩の誘い（所持金2万+・2年目か週24以降）
    case senpaiAllNight      // 0042: 先輩の朝まで（体力40+・本番の前週でない）
    case stageCrewChairs     // 0043: 片付けの手伝い（週8以降）
    case writerPostcards     // 0044: ハガキの仕分け（知名度10+・所持金<20万）
    case doukiJointLive      // 0045: 同期からの誘い（週16以降・知名度<40・所持金2万+）
    case baitoInventory      // 0046: 棚卸しの夜（所持金<15万・バイト3回以上）
    case homecomingCall      // 0047: 母からの電話（週38以降・3週以内に本番なし）
    case regularFanOranges   // 0048: いつものお客さん（知名度15+）
    case officeTicketQuota   // 0049: ライブのチケット（知名度<30）
    // --- 芸人の暮らしのイベント 第2束（docs/choice_events_more_v1.md・2026-10-16。週次抽選プール・各1回制） ---
    case summerFestivalGig   // 0051: 夏祭りの営業（7〜8月=週14-20・体力40+・本番の前週でない）
    case doukiOnTV           // 0052: 同期がテレビに出た夜（週20以降・知名度<30）
    case theaterRenovation   // 0053: いつもの劇場の改装（週12以降・知名度<40）
    case classmateInAudience // 0054: 同級生が客席に（週10以降・知名度5+）
    case partnerFever        // 0055: 相方の熱（週6以降・体力<50）
    case lostNotebook        // 0056: なくしたノート（週10以降・持ちネタあり）
    case yearEndLive         // 0057: 年末のライブ（12月=週33-36）

    /// 週次抽選プールに属するか（false=上の確定発火群）。GameSession の週次抽選が allCases から拾う。
    public var isWeeklyRandom: Bool {
        switch self {
        case .brokeDrinkingInvite, .senpaiMeishi, .peerFoldedChair, .lineupTop, .greenroomSilentTen,
             .lastTrainReview, .luckyThirdLine, .wroteOneTonight, .photoShootOffer,
             .kouhaiInvite, .senpaiAllNight, .stageCrewChairs, .writerPostcards, .doukiJointLive,
             .baitoInventory, .homecomingCall, .regularFanOranges, .officeTicketQuota,
             .summerFestivalGig, .doukiOnTV, .theaterRenovation, .classmateInAudience, .partnerFever,
             .lostNotebook, .yearEndLive:
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
            // 0023 正社員の話: A=受ける(所持金+3万/体力-10/メンタル-1＋その年の成長天井が縮む＝芸に注げる時間の機会費用)
            //                B=断る(メンタル+2/相性+1)
            //   段階2＝growthBudget減算（.growthCeiling）を実装。golden-inert（applyEventEffect は gen_golden 非経路）。
            return [
                ChoiceEventChoice(id: "A", effects: [
                    .money(30000), .stamina(-10), .ability(.メンタル, -1),
                    .growthCeiling(-config.regularJobCeilingCost),
                ]),
                ChoiceEventChoice(id: "B", effects: [
                    .ability(.メンタル, 2), .compat(1),
                ]),
            ]
        case .taniguchiShortJob:
            // 0012 谷口の耳寄りな話: A=二人で受ける(所持金+15万/体力-15【仮】。夜勤で体力は削れるが相方とは会える＝相性は動かさない)　B=断る(メンタル-1/相性+1)
            return [
                ChoiceEventChoice(id: "A", effects: [
                    .money(150_000), .stamina(-15),   // 【仮】compatFreeze は使わない（古いセーブ互換のため機構は残置）
                ]),
                ChoiceEventChoice(id: "B", effects: [
                    .ability(.メンタル, -1), .compat(1),
                ]),
            ]
        case .wroteOneTonight:
            // 0016 書けた一本: A=今夜詰める(発想+2/表現+1/体力-15)　B=寝かせる(体力+5/メンタル+1＋向こう数週ネタ合わせ効果UP)
            //   ※B の「翌週のネタ合わせ効果アップ」＝翌週バフ機構（.netaBoostNextWeek）で実装（golden-inert）。
            //     netaBoostWeeks を config.netaBoostWeeks 週分点火＝以後 applyNetaRevise が netaBoostMult 倍で乗る。
            return [
                ChoiceEventChoice(id: "A", effects: [
                    .ability(.発想, 2), .ability(.表現, 1), .stamina(-15),
                ]),
                ChoiceEventChoice(id: "B", effects: [
                    .stamina(5), .ability(.メンタル, 1), .netaBoostNextWeek(config.netaBoostWeeks),
                ]),
            ]
        case .photoShootOffer:
            // 0022 撮られる仕事: A=受ける(華+2/知名度+1/所持金+1万/体力-5＋その週の稽古を撮影に奪われる)　B=断って稽古(センス発想の低い方+1)
            //   ※proposal の「その週稽古打てない」機会費用＝週奪い機構（乙・.preoccupyNextWeek）で実装＝その週は稽古不可（UI層で自動休養化）。
            //     体力-15 の近似は撤去し撮影疲れの -5 に。全て確定加算＋UI層ロック＝rollOffer 非依存＝golden不変（規律C-8 オーナー確定=乙）。
            return [
                ChoiceEventChoice(id: "A", effects: [
                    .ability(.華, 2), .fame(1), .money(10_000), .stamina(-5),
                    .preoccupyNextWeek(config.photoShootPreoccupyWeeks),
                ]),
                ChoiceEventChoice(id: "B", effects: [
                    .weakerSenseIdeaPlus(1),
                ]),
            ]
        // --- 相方以外の人とのイベント（docs/choice_events_others_v1.md §2。数値は既存の週次イベントと同じ幅に揃えた【仮】） ---
        case .kouhaiInvite:
            // 0041 後輩の誘い: A=おごる(所持金-8000/華+1/メンタル+1・所持金<8000で非活性)　B=断る(華-1/メンタル-1/体力+5・オーナー「華とかメンタルが若干下がる」)
            return [
                ChoiceEventChoice(id: "A", effects: [
                    .money(-8000), .ability(.華, 1), .ability(.メンタル, 1),
                ], gate: { $0.money >= 8000 }),
                ChoiceEventChoice(id: "B", effects: [
                    .ability(.華, -1), .ability(.メンタル, -1), .stamina(5),
                ]),
            ]
        case .senpaiAllNight:
            // 0042 先輩の朝まで: A=ついて行く(センス+1/メンタル+1/体力-15)　B=遠慮する(何もなし＝オーナー指示)
            return [
                ChoiceEventChoice(id: "A", effects: [
                    .ability(.センス, 1), .ability(.メンタル, 1), .stamina(-15),
                ]),
                ChoiceEventChoice(id: "B", effects: []),
            ]
        case .stageCrewChairs:
            // 0043 片付けの手伝い: A=手伝う(知名度+1/体力-10)　B=先に帰る(体力+5)
            return [
                ChoiceEventChoice(id: "A", effects: [.fame(1), .stamina(-10)]),
                ChoiceEventChoice(id: "B", effects: [.stamina(5)]),
            ]
        case .writerPostcards:
            // 0044 ハガキの仕分け: A=引き受ける(所持金+15000/発想+1/体力-10)　B=断る(相性+1)
            return [
                ChoiceEventChoice(id: "A", effects: [.money(15_000), .ability(.発想, 1), .stamina(-10)]),
                ChoiceEventChoice(id: "B", effects: [.compat(1)]),
            ]
        case .doukiJointLive:
            // 0045 同期からの誘い: A=二組でやる(知名度+2/所持金-10000/体力-10・所持金<10000で非活性)　B=断る(相性+1)
            return [
                ChoiceEventChoice(id: "A", effects: [
                    .fame(2), .money(-10_000), .stamina(-10),
                ], gate: { $0.money >= 10_000 }),
                ChoiceEventChoice(id: "B", effects: [.compat(1)]),
            ]
        case .baitoInventory:
            // 0046 棚卸しの夜: A=入る(所持金+20000/体力-15)　B=断る(表現+1)
            return [
                ChoiceEventChoice(id: "A", effects: [.money(20_000), .stamina(-15)]),
                ChoiceEventChoice(id: "B", effects: [.ability(.表現, 1)]),
            ]
        case .homecomingCall:
            // 0047 母からの電話: A=帰省する(体力+15/メンタル+1/所持金-12000・所持金<12000で非活性)　B=残って稽古(表現+1/メンタル-1)
            return [
                ChoiceEventChoice(id: "A", effects: [
                    .stamina(15), .ability(.メンタル, 1), .money(-12_000),
                ], gate: { $0.money >= 12_000 }),
                ChoiceEventChoice(id: "B", effects: [.ability(.表現, 1), .ability(.メンタル, -1)]),
            ]
        case .regularFanOranges:
            // 0048 いつものお客さん: A=残って挨拶(華+1/知名度+1/所持金-5000＝バイトに遅れた分)　B=急いで出る(何もなし)
            return [
                ChoiceEventChoice(id: "A", effects: [.ability(.華, 1), .fame(1), .money(-5000)]),
                ChoiceEventChoice(id: "B", effects: []),
            ]
        case .officeTicketQuota:
            // 0049 ライブのチケット: A=手売り(知名度+1/体力-10)　B=買い取る(所持金-6000/表現+1・所持金<6000で非活性)
            return [
                ChoiceEventChoice(id: "A", effects: [.fame(1), .stamina(-10)]),
                ChoiceEventChoice(id: "B", effects: [
                    .money(-6000), .ability(.表現, 1),
                ], gate: { $0.money >= 6000 }),
            ]
        // --- 芸人の暮らしのイベント 第2束（docs/choice_events_more_v1.md §2。幅は 0041〜0049 と同じ【仮】） ---
        case .summerFestivalGig:
            // 0051 夏祭りの営業: A=受ける(所持金+12000/知名度+1/体力-15)　B=断って休む(体力+10/メンタル+1)
            return [
                ChoiceEventChoice(id: "A", effects: [.money(12_000), .fame(1), .stamina(-15)]),
                ChoiceEventChoice(id: "B", effects: [.stamina(10), .ability(.メンタル, 1)]),
            ]
        case .doukiOnTV:
            // 0052 同期がテレビに出た夜: A=最後まで見る(センス+1/メンタル-1)　B=消して銭湯へ(体力+10/メンタル+1/所持金-1000・所持金<1000で非活性)
            return [
                ChoiceEventChoice(id: "A", effects: [.ability(.センス, 1), .ability(.メンタル, -1)]),
                ChoiceEventChoice(id: "B", effects: [
                    .stamina(10), .ability(.メンタル, 1), .money(-1000),
                ], gate: { $0.money >= 1000 }),
            ]
        case .theaterRenovation:
            // 0053 いつもの劇場の改装: A=隣町の劇場に通う(知名度+2/所持金-8000/体力-10・所持金<8000で非活性)　B=公園で二人で練習(表現+1/体力-5)
            return [
                ChoiceEventChoice(id: "A", effects: [
                    .fame(2), .money(-8000), .stamina(-10),
                ], gate: { $0.money >= 8000 }),
                ChoiceEventChoice(id: "B", effects: [.ability(.表現, 1), .stamina(-5)]),
            ]
        case .classmateInAudience:
            // 0054 同級生が客席に: A=同級生たちの飲み会に行く(知名度+1/メンタル+1/体力-10)　B=相方と帰る(相性+1/体力+5)
            return [
                ChoiceEventChoice(id: "A", effects: [.fame(1), .ability(.メンタル, 1), .stamina(-10)]),
                ChoiceEventChoice(id: "B", effects: [.compat(1), .stamina(5)]),
            ]
        case .partnerFever:
            // 0055 相方の熱: A=看病に行く(相性+2/所持金-2000/体力-5・所持金<2000で非活性)　B=一人で稽古場に残る(表現+1)
            return [
                ChoiceEventChoice(id: "A", effects: [
                    .compat(2), .money(-2000), .stamina(-5),
                ], gate: { $0.money >= 2000 }),
                ChoiceEventChoice(id: "B", effects: [.ability(.表現, 1)]),
            ]
        case .lostNotebook:
            // 0056 なくしたノート: A=終点の駅まで取りに行く(メンタル+1/体力-10/所持金-1500・所持金<1500で非活性)　B=新しいノートを買う(発想+1/メンタル-1)
            return [
                ChoiceEventChoice(id: "A", effects: [
                    .ability(.メンタル, 1), .stamina(-10), .money(-1500),
                ], gate: { $0.money >= 1500 }),
                ChoiceEventChoice(id: "B", effects: [.ability(.発想, 1), .ability(.メンタル, -1)]),
            ]
        case .yearEndLive:
            // 0057 年末のライブ: A=打ち上げに最後まで残る(センス+1/知名度+1/所持金-5000/体力-10・所持金<5000で非活性)
            //                    B=二人でそばを食べて帰る(相性+1/メンタル+1/所持金-1500・所持金<1500で非活性)
            return [
                ChoiceEventChoice(id: "A", effects: [
                    .ability(.センス, 1), .fame(1), .money(-5000), .stamina(-10),
                ], gate: { $0.money >= 5000 }),
                ChoiceEventChoice(id: "B", effects: [
                    .compat(1), .ability(.メンタル, 1), .money(-1500),
                ], gate: { $0.money >= 1500 }),
            ]
        case .riftWarning:
            // 0050 会わない週が続いた: A=向き合う(rift-30/体力-10)　B=流す(何もなし＝仲はそのまま)。乱数なし
            return [
                ChoiceEventChoice(id: "A", effects: [.rift(-30), .stamina(-10)]),
                ChoiceEventChoice(id: "B", effects: []),
            ]
        case .namelessReservationSlip, .lineupTop, .greenroomSilentTen, .luckyThirdLine:
            return []   // 選択肢なしフレーバー（会話を送り切って閉じる・効果なし）
        }
    }

    /// 週次抽選イベントの発火ゲート（純関数・RNG非消費）。確定発火の kind は常に false（抽選プール外）。
    /// GameSession の週次抽選が「発火帯に入っている候補」だけを対象にする（proposals 各票の発火条件）。
    public static func weeklyFireable(_ kind: ChoiceEventKind, state: GameState, week: Int, config: GameConfig) -> Bool {
        guard weeklyBandFireable(kind, state: state, week: week, config: config) else { return false }
        // 全イベント共通: 選択肢があるのに今の状態で1つも選べないイベントは出さない（発火も上限消費もしない）。
        // 選択肢なしのフレーバーは対象外。RNG非消費・候補の絞り込みのみ。
        let cs = choices(for: kind, config: config)
        return cs.isEmpty || cs.contains { $0.gate(state) }
    }

    private static func weeklyBandFireable(_ kind: ChoiceEventKind, state: GameState, week: Int, config: GameConfig) -> Bool {
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
        case .photoShootOffer:
            // 0022: 顔で呼ばれ始める帯（知名度20-50）。下限は新人賞通過等で1年内到達しうる／上限は主に2年目以降
            return state.fame >= 20 && state.fame <= 50
        // 相方以外の人とのイベント（docs/choice_events_others_v1.md §2）。年・バイト回数・本番までの週は GameSession の追加ゲート
        case .kouhaiInvite:      return state.money >= 20_000          // おごれる余地がある時だけ（A が灰色だらけにならない）
        case .senpaiAllNight:    return state.stamina >= 40            // 朝まで付き合っても倒れない帯
        case .stageCrewChairs:   return week >= 8                      // 劇場に出入りし始めた後
        case .writerPostcards:   return state.fame >= 10 && state.money < 200_000
        case .doukiJointLive:    return week >= 16 && state.fame < 40 && state.money >= 20_000
        case .baitoInventory:    return state.money < 150_000
        case .homecomingCall:    return week >= 38                     // 年末（正月の帰省の話）
        case .regularFanOranges: return state.fame >= 15               // 常連がつき始めた帯
        case .officeTicketQuota: return state.fame < 30                // 手売りが要る帯
        // 芸人の暮らしのイベント 第2束（docs/choice_events_more_v1.md §2）。第1週=4月・4週で1か月
        case .summerFestivalGig:   return (14...20).contains(week) && state.stamina >= 40   // 7〜8月・炎天下に立てる体力
        case .doukiOnTV:           return week >= 20 && state.fame < 30   // まだテレビに縁がない帯
        case .theaterRenovation:   return week >= 12 && state.fame < 40   // いつもの劇場に出ている帯
        case .classmateInAudience: return week >= 10 && state.fame >= 5   // 噂が地元に届き始めた頃
        case .partnerFever:        return week >= 6 && state.stamina < 50 // 疲れがたまった頃
        case .lostNotebook:        return week >= 10 && !state.netas.isEmpty
        case .yearEndLive:         return (33...36).contains(week)        // 12月
        default:
            return false
        }
    }
}
