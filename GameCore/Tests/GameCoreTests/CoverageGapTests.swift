// CoverageGapTests.swift
// 未カバーだった所を「今の振る舞いのまま」固定するテスト（式・乱数・golden・ソースは不変）。
// イベント効果の残り / アイテム購入の境目 / オファーの受け方 / 生活苦と夜逃げの境目 / 旧セーブ読み込み / JudgeTalk の区分け。

import XCTest
@testable import GameCore

final class CoverageGapTests: XCTestCase {
    private let cfg = GameConfig()

    // MARK: 選択イベントの効果

    /// 体力・知名度は 0..100 に収まる
    func testStaminaAndFameClamp() {
        var s = GameState(config: cfg)
        s.stamina = 95; s.fame = 2
        s.applyEventEffect(.stamina(30), config: cfg)
        s.applyEventEffect(.fame(-10), config: cfg)
        XCTAssertEqual(s.stamina, 100, accuracy: 1e-9)
        XCTAssertEqual(s.fame, 0, accuracy: 1e-9)
        s.applyEventEffect(.stamina(-500), config: cfg)
        s.applyEventEffect(.fame(500), config: cfg)
        XCTAssertEqual(s.stamina, 0, accuracy: 1e-9)
        XCTAssertEqual(s.fame, 100, accuracy: 1e-9)
    }

    /// メンタルだけ mentalCap、他の能力は abilityCap で止まる
    func testAbilityCapsDifferForMental() {
        var s = GameState(config: cfg)
        s.メンタル = cfg.mentalCap - 1; s.センス = cfg.abilityCap - 1
        s.applyEventEffect(.ability(.メンタル, 100), config: cfg)
        s.applyEventEffect(.ability(.センス, 100), config: cfg)
        XCTAssertEqual(s.メンタル, cfg.mentalCap, accuracy: 1e-9)
        XCTAssertEqual(s.センス, cfg.abilityCap, accuracy: 1e-9)
    }

    /// 凍結・ブースト・拘束の週数は「長い方を残す」（短い付与で縮めない）
    func testDurationEffectsKeepLongerWeeks() {
        var s = GameState(config: cfg)
        s.applyEventEffect(.compatFreeze(3), config: cfg)
        s.applyEventEffect(.compatFreeze(1), config: cfg)
        s.applyEventEffect(.netaBoostNextWeek(2), config: cfg)
        s.applyEventEffect(.netaBoostNextWeek(4), config: cfg)
        s.applyEventEffect(.preoccupyNextWeek(5), config: cfg)
        s.applyEventEffect(.preoccupyNextWeek(2), config: cfg)
        XCTAssertEqual(s.compatFreezeWeeks, 3)
        XCTAssertEqual(s.netaBoostWeeks, 4)
        XCTAssertEqual(s.preoccupiedWeeks, 5)
    }

    /// 成長天井: nil(無制限)は no-op／数値は増減／下限0／使用済み量は動かない
    func testGrowthCeilingEffect() {
        var s = GameState(config: cfg)
        s.applyEventEffect(.growthCeiling(-3), config: cfg)
        XCTAssertNil(s.growthBudget)
        s.growthBudget = 5; s.growthUsed = 2
        s.applyEventEffect(.growthCeiling(1.5), config: cfg)
        XCTAssertEqual(s.growthBudget!, 6.5, accuracy: 1e-9)
        s.applyEventEffect(.growthCeiling(-100), config: cfg)
        XCTAssertEqual(s.growthBudget!, 0, accuracy: 1e-9)
        XCTAssertEqual(s.growthUsed, 2, accuracy: 1e-9)
    }

    /// 発想とセンスが同値ならセンスに乗る（<=）／最弱技能が同値なら先頭側（センス）に乗る
    func testTieBreaksInWeakerSelection() {
        var s = GameState(config: cfg)
        s.センス = 20; s.発想 = 20
        s.applyEventEffect(.weakerSenseIdeaPlus(1), config: cfg)
        XCTAssertEqual(s.センス, 21, accuracy: 1e-9)
        XCTAssertEqual(s.発想, 20, accuracy: 1e-9)
        s.センス = 10; s.発想 = 10; s.表現 = 10; s.華 = 10
        s.applyEventEffect(.weakestSkillPlus(2), config: cfg)
        XCTAssertEqual(s.センス, 12, accuracy: 1e-9)
        XCTAssertEqual(s.発想, 10, accuracy: 1e-9)
    }

    // MARK: アイテムの購入

    /// 所持金が価格ちょうどなら買え、1円足りなければ買えず状態も不変
    func testBuyMoneyBoundary() {
        let price = cfg.items[.栄養ドリンク]!.price
        var s = GameState(config: cfg)
        s.money = price - 1
        let before = s
        XCTAssertFalse(GameEngine.buy(.栄養ドリンク, to: &s, config: cfg))
        XCTAssertEqual(s.money, before.money)
        XCTAssertNil(s.itemCounts)
        s.money = price
        XCTAssertTrue(GameEngine.buy(.栄養ドリンク, to: &s, config: cfg))
        XCTAssertEqual(s.money, 0)
        XCTAssertEqual(s.itemCounts?[ShopItem.栄養ドリンク.rawValue], 1)
    }

    /// 新幹線回数券: 買うとその年は再購入不可・年初リセットで再び買える・銭湯の枚数は年を越えて残る
    func testShinkansenBlockAndYearlyResetKeepsSento() {
        var s = GameState(config: cfg)
        s.money = 3_000_000
        XCTAssertTrue(GameEngine.buy(.新幹線回数券, to: &s, config: cfg))
        XCTAssertEqual(s.shinkansenActive, true)
        XCTAssertFalse(GameEngine.canBuy(.新幹線回数券, state: s, config: cfg))
        XCTAssertTrue(GameEngine.buy(.銭湯の回数券, to: &s, config: cfg))
        GameEngine.resetYearlyItems(&s)
        XCTAssertNil(s.shinkansenActive)
        XCTAssertEqual(s.sentoTickets, cfg.itemSentoTickets)   // 持ち越し（年初に消えない）
        XCTAssertTrue(GameEngine.canBuy(.新幹線回数券, state: s, config: cfg))
    }

    /// 品揃えに無い品は所持金が十分でも買えない
    func testNotInLineupCannotBuy() {
        var c = cfg
        c.shopLineup = [.栄養ドリンク]
        var s = GameState(config: c)
        s.money = 10_000_000
        XCTAssertFalse(GameEngine.canBuy(.新幹線回数券, state: s, config: c))
        XCTAssertTrue(GameEngine.canBuy(.栄養ドリンク, state: s, config: c))
    }

    // MARK: オファー

    /// オファーを受けると収入・知名度・体力が反映され、能力付きなら能力も上がる（金だけの方は能力不変）
    func testApplyOfferEffects() {
        var s = GameState(config: cfg)
        s.stamina = 80
        let m0 = s.money, f0 = s.fame, e0 = s.表現
        GameEngine.applyOffer(cfg.offerMoney, to: &s, config: cfg)
        XCTAssertEqual(s.money, m0 + cfg.offerMoney.income)
        // 知名度の伸びは「その他の伸び」＝×fameOtherMult×(1−知名度/fameOtherCap)²（キュー62 案G・GameEngine.add）
        let d = max(0.0, 1 - f0 / cfg.fameOtherCap)
        XCTAssertEqual(s.fame, f0 + cfg.offerMoney.fame * cfg.fameOtherMult * (d * d), accuracy: 1e-9)
        XCTAssertEqual(s.stamina, 80 + cfg.offerMoney.stamina, accuracy: 1e-9)
        XCTAssertEqual(s.表現, e0, accuracy: 1e-12)
        GameEngine.applyOffer(cfg.offerExp, to: &s, config: cfg)
        XCTAssertGreaterThan(s.表現, e0)
    }

    /// 発生率の帯の境目（知名度20ちょうどは次の帯）と、乱数ちょうど=率は外れ
    func testRollOfferFameBandBoundary() {
        var s = GameState(config: cfg)
        s.fame = 20
        var hit = SeqRandom(values: [0.149, 0.0])
        XCTAssertNotNil(GameEngine.rollOffer(state: s, config: cfg, rng: &hit))
        var edge = SeqRandom(values: [0.15])
        XCTAssertNil(GameEngine.rollOffer(state: s, config: cfg, rng: &edge))
        XCTAssertEqual(edge.index, 1)   // 外れは1drawで終わる
        var split = SeqRandom(values: [0.0, 0.5])
        XCTAssertEqual(GameEngine.rollOffer(state: s, config: cfg, rng: &split)?.name, cfg.offerExp.name)   // 0.5 は経験重視側
    }

    // MARK: 生活苦と夜逃げ

    /// 所持金が生活費後に0以上なら生活苦なし／マイナスなら体力とメンタルが減る
    func testDebtLifeBoundary() {
        var ok = GameState(config: cfg)
        ok.money = cfg.livingCost; ok.stamina = 80; ok.メンタル = 50
        XCTAssertFalse(GameEngine.applyWeekEnd(week: cfg.livingInterval, to: &ok, config: cfg))
        XCTAssertEqual(ok.money, 0)
        XCTAssertEqual(ok.stamina, 80, accuracy: 1e-9)
        XCTAssertEqual(ok.メンタル, 50, accuracy: 1e-9)

        var debt = GameState(config: cfg)
        debt.money = cfg.livingCost - 1; debt.stamina = 80; debt.メンタル = 50
        XCTAssertFalse(GameEngine.applyWeekEnd(week: cfg.livingInterval, to: &debt, config: cfg))
        XCTAssertEqual(debt.money, -1)
        XCTAssertLessThan(debt.stamina, 80)
        XCTAssertLessThan(debt.メンタル, 50)
        XCTAssertFalse(debt.bankrupt)
    }

    /// 夜逃げは「夜逃げライン未満」から。ちょうどラインなら生き残る
    func testBankruptBoundary() {
        var edge = GameState(config: cfg)
        edge.money = cfg.bankruptLine + cfg.livingCost
        XCTAssertFalse(GameEngine.applyWeekEnd(week: cfg.livingInterval, to: &edge, config: cfg))
        XCTAssertFalse(edge.bankrupt)
        var over = GameState(config: cfg)
        over.money = cfg.bankruptLine + cfg.livingCost - 1
        XCTAssertTrue(GameEngine.applyWeekEnd(week: cfg.livingInterval, to: &over, config: cfg))
        XCTAssertTrue(over.bankrupt)
    }

    /// 生活費の週でなければ、借金中でも何も起きない
    func testNoDebtEffectOffInterval() {
        var s = GameState(config: cfg)
        s.money = -500_000; s.stamina = 80
        XCTAssertFalse(GameEngine.applyWeekEnd(week: 1, to: &s, config: cfg))
        XCTAssertEqual(s.money, -500_000)
        XCTAssertEqual(s.stamina, 80, accuracy: 1e-9)
    }

    // MARK: セーブ（Codable）

    /// アイテム・各種フラグを持つ状態が往復で保たれる
    func testItemAndFlagFieldsRoundTrip() throws {
        var s = GameState(config: cfg)
        s.itemCounts = ["栄養ドリンク": 2]; s.sentoTickets = 3; s.hasRecorder = true
        s.shinkansenActive = true; s.studioActive = true
        s.compatFreezeWeeks = 2; s.netaBoostWeeks = 1; s.preoccupiedWeeks = 4
        s.selectedNetaID = 7; s.selectedNetaID2 = 8
        let back = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back.itemCounts, ["栄養ドリンク": 2])
        XCTAssertEqual(back.sentoTickets, 3)
        XCTAssertEqual(back.hasRecorder, true)
        XCTAssertEqual(back.shinkansenActive, true)
        XCTAssertEqual(back.studioActive, true)
        XCTAssertEqual([back.compatFreezeWeeks, back.netaBoostWeeks, back.preoccupiedWeeks], [2, 1, 4])
        XCTAssertEqual([back.selectedNetaID, back.selectedNetaID2], [7, 8])
    }

    /// アイテム系 Optional が無い旧セーブ（キー欠落）も読め、全て nil（効果なし）になる
    func testDecodeOldSaveWithoutItemKeys() throws {
        let enc = try JSONEncoder().encode(GameState(config: cfg))
        var obj = try JSONSerialization.jsonObject(with: enc) as! [String: Any]
        for k in ["itemCounts", "sentoTickets", "hasRecorder", "shinkansenActive", "studioActive", "growthBudget"] {
            obj.removeValue(forKey: k)
        }
        let old = try JSONSerialization.data(withJSONObject: obj)
        let s = try JSONDecoder().decode(GameState.self, from: old)
        XCTAssertNil(s.itemCounts); XCTAssertNil(s.sentoTickets); XCTAssertNil(s.hasRecorder)
        XCTAssertNil(s.shinkansenActive); XCTAssertNil(s.studioActive); XCTAssertNil(s.growthBudget)
        XCTAssertEqual(s.money, cfg.initMoney)
    }

    // MARK: JudgeTalk

    /// 決勝の帯の境目
    func testBandBoundaries() {
        XCTAssertEqual(JudgeTalk.band(95), "A"); XCTAssertEqual(JudgeTalk.band(94), "B")
        XCTAssertEqual(JudgeTalk.band(91), "B"); XCTAssertEqual(JudgeTalk.band(90), "C")
        XCTAssertEqual(JudgeTalk.band(87), "C"); XCTAssertEqual(JudgeTalk.band(86), "D")
        XCTAssertEqual(JudgeTalk.band(0), "D")
    }

    /// 司会の拾い: 該当しない文は nil／花園の割れは reply なし／自虐の脱線は reply が差し込み済み
    func testPickupMatching() {
        XCTAssertNil(JudgeTalk.pickup(after: "とても良かったです。"))
        let split = JudgeTalk.pickup(after: "点は辛うつけたけど、好きは好きやねん。続き")
        XCTAssertNotNil(split)
        XCTAssertNil(split?.reply)
        let scene = JudgeTalk.Scene(netaName: "満員電車", kata: .王道しゃべくり)
        let p = JudgeTalk.pickup(after: "粗を探す気で座った。粗がなかった。", scene: scene, salt: 3)
        XCTAssertEqual(p?.mc, "粗がなかった、と。")
        XCTAssertFalse(p?.reply?.contains("{") ?? true)
    }

    /// 最高点側の講評には「辛うつけたけど」系の最低点専用行が出ない（全審査員・全帯）
    func testHighCommentNeverLowOnly() {
        let scene = JudgeTalk.Scene(netaName: "満員電車", kata: .関係性)
        for j in JudgeTalk.judgeNames {
            for sc in [84, 88, 92, 97] {
                for salt in 0..<8 {
                    let c = JudgeTalk.finalComment(judge: j, score: sc, high: true, scene: scene, salt: salt)
                    XCTAssertFalse(JudgeTalk.isLowOnly(c.text), "\(j) \(sc) \(salt)")
                }
            }
        }
    }
}
