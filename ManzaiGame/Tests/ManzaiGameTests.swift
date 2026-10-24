// アプリ側の判定ロジック（Endings / Names / 借金の段 / 客席の声 / 予告0050）の単体テスト。UI は対象外。
import XCTest
import GameCore
@testable import ManzaiGame

final class EndingJudgeTests: IsolatedStoreTestCase {
    private func rec(_ y: Int, final f: Bool) -> GameSession.YearRecord {
        GameSession.YearRecord(year: y, roundsPassed: 1, reachedFinal: f, champion: false, bankrupt: false, prize: 0)
    }
    private func out(champ: Bool = false, bank: Bool = false, diss: Bool = false) -> YearOutcome {
        YearOutcome(champion: champ, roundsPassed: 2, reachedFinal: false, bankrupt: bank, dissolved: diss)
    }
    private func judge(_ o: YearOutcome, compat: Double, hist: [GameSession.YearRecord] = [], year: Int = 3) -> EndingID? {
        EndingID.judge(outcome: o, compat: compat, history: hist, year: year, careerYears: 10)
    }

    func testBankruptAndDissolve() {
        XCTAssertEqual(judge(out(bank: true), compat: 20), .nightEscape)
        XCTAssertEqual(judge(out(diss: true), compat: 20), .breakup)
        XCTAssertEqual(judge(out(bank: true, diss: true), compat: 0), .nightEscape)   // 夜逃げが先
    }
    func testChampionByCompatBoundary() {
        XCTAssertEqual(judge(out(champ: true), compat: 15), .championPair)
        XCTAssertEqual(judge(out(champ: true), compat: 14.99), .championRetire)
        XCTAssertEqual(judge(out(champ: true), compat: 0), .championRetire)
    }
    func testDissolveBeatsChampionSameYear() {
        XCTAssertEqual(judge(out(champ: true, diss: true), compat: 20), .breakup)
        XCTAssertEqual(judge(out(champ: true, bank: true), compat: 20), .nightEscape)
    }
    func testNotYetEnded() {
        XCTAssertNil(judge(out(), compat: 20, year: 9))
    }
    func testTenYearsFourWay() {
        let none = (1...10).map { rec($0, final: false) }
        var once = none; once[4] = rec(5, final: true)
        let many = (1...10).map { rec($0, final: true) }
        XCTAssertEqual(judge(out(), compat: 14.99, hist: none, year: 10), .gaveUp)
        XCTAssertEqual(judge(out(), compat: 15, hist: none, year: 10), .keptGoing)
        XCTAssertEqual(judge(out(), compat: 14.99, hist: once, year: 10), .tenYearsClose)   // 決勝1回
        XCTAssertEqual(judge(out(), compat: 15, hist: once, year: 10), .tenYearsTrue)
        XCTAssertEqual(judge(out(), compat: 15, hist: many, year: 10), .tenYearsTrue)
        XCTAssertEqual(judge(out(), compat: 0, hist: [], year: 10), .gaveUp)   // 履歴空＝決勝0回
    }
    func testNumbersUniqueAndRoundTrip() {
        XCTAssertEqual(Set(EndingID.allCases.map { $0.number }).count, EndingID.allCases.count)
        for id in EndingID.allCases { XCTAssertEqual(EndingID.from(number: id.number), id) }
    }
}

final class NamesTests: IsolatedStoreTestCase {
    override func tearDown() { Names.set(me: nil, partner: nil); Names.setKind(.maleMale); super.tearDown() }

    func testFirstPersonTokensByComboKind() {
        Names.set(me: nil, partner: nil)
        let line = "{me}が出す。{partner1}たちで行こう。{partner1}らもな"
        Names.setKind(.maleMale);   XCTAssertEqual(Names.show(line), "俺が出す。俺たちで行こう。俺らもな")
        Names.setKind(.femaleFemale); XCTAssertEqual(Names.show(line), "私が出す。私たちで行こう。私たちもな")
        Names.setKind(.maleFemale); XCTAssertEqual(Names.show("{me}／{partner1}"), "俺／私")   // 自分が男・相方が女
        Names.setKind(.femaleMale); XCTAssertEqual(Names.show("{me}／{partner1}"), "私／俺")   // 自分が女・相方が男
        Names.setKind(.femaleMale); XCTAssertEqual(Names.show("俺"), "私")   // 話者の札
        Names.set(me: "ミナト", partner: nil); XCTAssertEqual(Names.show("俺"), "ミナト")
    }
    func testOldSaveIsMaleMaleAndKindRoundTrips() throws {
        let s = GameSession(comboKind: .femaleMale)
        XCTAssertEqual(Names.show("{me}"), "私")
        s.saveNow()
        let d = try XCTUnwrap(GameSession.store.data(forKey: "manzai.save.v1"))
        var o = try XCTUnwrap(JSONSerialization.jsonObject(with: d) as? [String: Any])
        XCTAssertEqual(o["comboKind"] as? String, "femaleMale")
        XCTAssertEqual(GameSession(restoring: try JSONDecoder().decode(GameSession.SaveData.self, from: d)).comboKind, .femaleMale)
        o.removeValue(forKey: "comboKind")
        let old = try JSONDecoder().decode(GameSession.SaveData.self, from: JSONSerialization.data(withJSONObject: o))
        XCTAssertNil(old.comboKind)
        XCTAssertEqual(GameSession(restoring: old).comboKind, .maleMale)
        XCTAssertEqual(Names.show("{me}"), "俺")
    }

    func testDefaultsUnchanged() {
        Names.set(me: nil, partner: nil)
        XCTAssertEqual(Names.show("谷口さんが来た"), "谷口さんが来た")
        XCTAssertEqual(Names.show("俺"), "俺")
    }
    func testPartnerReplacedInsideSentence() {
        Names.set(me: nil, partner: "ケンジ")
        XCTAssertEqual(Names.show("谷口の言う通りだ。谷口さん、行こう"), "ケンジの言う通りだ。ケンジさん、行こう")
    }
    func testMeOnlyWhenExactLabel() {
        Names.set(me: "ミナト", partner: nil)
        XCTAssertEqual(Names.show("俺"), "ミナト")
        XCTAssertEqual(Names.show("俺は行く"), "俺は行く")   // 地の文・心の声の「俺」は触らない
    }
    func testBlankFallsBack() {
        Names.set(me: "  ", partner: "")
        XCTAssertEqual(Names.show("俺"), "俺")
        XCTAssertEqual(Names.show("谷口"), "谷口")
        Names.set(me: nil, partner: " \n")
        XCTAssertEqual(Names.partner, "谷口")
    }
    func testSixAndSevenChars() {
        Names.set(me: nil, partner: "ABCDEF")
        XCTAssertEqual(Names.show("谷口"), "ABCDEF")
        Names.set(me: nil, partner: "ABCDEFG")   // 7字目は切る
        XCTAssertEqual(Names.partner, "ABCDEF")
    }
}

/// アプリ本体(テストホスト)と UserDefaults.standard を取り合わないよう、テスト中は専用 suite に保存先を差し替える
class IsolatedStoreTestCase: XCTestCase {
    private var savedStore: UserDefaults!
    private var suiteName = ""
    override func setUp() {
        super.setUp()
        savedStore = GameSession.store
        suiteName = "mz.test.\(UUID().uuidString)"
        GameSession.store = UserDefaults(suiteName: suiteName)!
    }
    override func tearDown() {
        GameSession.store.removePersistentDomain(forName: suiteName)
        GameSession.store = savedStore
        super.tearDown()
    }
}

final class IntroSkipTests: IsolatedStoreTestCase {
    func testSkipOnlyAfterIntroSeen() {
        XCTAssertFalse(IntroFlowView.hasSeenIntro)   // 1周目：出さない
        IntroFlowView.markIntroSeen()
        XCTAssertTrue(IntroFlowView.hasSeenIntro)    // 最後まで見た記録のあと：出す
    }
}

final class DebtWarnTests: IsolatedStoreTestCase {

    func testTierBoundaries() {
        XCTAssertEqual(GameSession.debtTier(money: 0), 0)
        XCTAssertEqual(GameSession.debtTier(money: -1), 1)
        XCTAssertEqual(GameSession.debtTier(money: -500_000), 1)
        XCTAssertEqual(GameSession.debtTier(money: -500_001), 2)
        XCTAssertEqual(GameSession.debtTier(money: -800_000), 2)
        XCTAssertEqual(GameSession.debtTier(money: -800_001), 3)
    }
    func testEachTierShownOnce() {
        let s = GameSession()
        XCTAssertNil(s.debtNoticeTierToShow(money: 10_000))
        var shown: [Int] = []
        for money in [-10_000, -10_000, -600_000, -600_000, -400_000, -900_000, -900_000, -600_000] {
            if let t = s.debtNoticeTierToShow(money: money) { shown.append(t); s.markDebtWarned(t) }
        }
        XCTAssertEqual(shown, [1, 2, 3])   // 回復して再び落ちても同じ段は出ない
    }
    func testSkippingTiersJumpsDirectly() {
        let s = GameSession()
        XCTAssertEqual(s.debtNoticeTierToShow(money: -900_000), 3)
        s.markDebtWarned(3)
        XCTAssertNil(s.debtNoticeTierToShow(money: -100_000))
    }
    func testOldSaveWithoutDebtTier() throws {
        let s = GameSession()
        s.markDebtWarned(2)   // saveNow される
        s.saveNow()
        let d = try XCTUnwrap(GameSession.store.data(forKey: "manzai.save.v1"))
        var o = try XCTUnwrap(JSONSerialization.jsonObject(with: d) as? [String: Any])
        XCTAssertNotNil(o["debtWarnTier"])
        o.removeValue(forKey: "debtWarnTier")
        let old = try JSONDecoder().decode(GameSession.SaveData.self, from: JSONSerialization.data(withJSONObject: o))
        XCTAssertNil(old.debtWarnTier)
        let r = GameSession(restoring: old)
        XCTAssertEqual(r.debtWarnTier, 0)
        XCTAssertEqual(r.debtNoticeTierToShow(money: -10_000), 1)
    }
}

final class FanReportTests: IsolatedStoreTestCase {
    func testIsKnownBoundaries() {
        XCTAssertFalse(FanReportData.isKnown(year: 1, fame: 99))
        XCTAssertFalse(FanReportData.isKnown(year: 2, fame: 14.99))
        XCTAssertTrue(FanReportData.isKnown(year: 2, fame: 15))
        XCTAssertTrue(FanReportData.isKnown(year: 10, fame: 40))
    }
    private let knownMarks = ["いつも", "去年", "安定", "期待が違った", "切れが増して"]
    func testUnknownNeverGetsKnownOnlyLines() {
        for salt in -40...200 {
            let b = FanReportData.burst(name: "X", salt: salt, known: false)
            XCTAssertFalse(knownMarks.contains { b.contains($0) }, b)
            for passed in [true, false] { for m in [20.0, 5.0, -2.0, -8.0, -30.0, nil] as [Double?] {
                for burst in [true, false] {
                    for v in FanReportData.voices(name: "X", passed: passed, margin: m, burst: burst, salt: salt, known: false) {
                        XCTAssertFalse(knownMarks.contains { v.contains($0) }, v)
                    }
                }
            } }
        }
    }
    /// 客席アンケートの声は、同じ帯のプールが尽きる前に同じ文を繰り返さない（隣の帯で補い、それも尽きたら最古から）
    func testFanVoicesAvoidRepeatsAcrossCareer() {
        let session = GameSession()
        var seen: [String] = []
        var repeatsBeforeExhaust = 0
        for visit in 0..<3 {
            let salt = 131 * 4 + 20 + visit * 4
            let lines = session.fanVoices(key: salt) { used in
                FanReportData.voices(name: "X", passed: true, margin: 20, burst: false, salt: salt, known: false, used: used)
            }
            XCTAssertFalse(lines.isEmpty)
            XCTAssertEqual(Set(lines).count, lines.count, "同じ回の中で重複")
            for l in lines { if seen.contains(l) { repeatsBeforeExhaust += 1 } }
            seen += lines
        }
        XCTAssertEqual(repeatsBeforeExhaust, 0, "A帯8＋B帯4＝12文のうちは再登場しない：\(seen)")
    }
    func testKnownCanGetKnownOnlyLines() {
        var hit = false
        for salt in 0..<300 {
            if FanReportData.burst(name: "X", salt: salt, known: true).contains("去年") { hit = true }
            for v in FanReportData.voices(name: "X", passed: true, margin: 20, burst: true, salt: salt, known: true) where knownMarks.contains(where: { v.contains($0) }) { hit = true }
        }
        XCTAssertTrue(hit)
    }
}

final class RiftWarnEventTests: IsolatedStoreTestCase {

    /// 予告0050：riftWarned が初めて true になった週の次の週頭に1回だけ出る（1キャリア1回）
    func testRiftWarningFiresOnceAfterFlagSet() {
        var st = GameState(config: GameConfig()); st.compat = 3; st.money = 500_000; st.rift = 49
        let s = GameSession(startState: st)
        var fired = 0, steps = 0
        var warnedBeforeFire: Bool?
        var warnedBeforeEver = false
        while steps < 4000, !s.finished { steps += 1
            if s.pendingChoiceEvent == .riftWarning {
                fired += 1
                if fired == 1 { warnedBeforeFire = (s.state.riftWarned == true); warnedBeforeEver = (s.didFireRiftWarn) }
                s.dismissChoiceEvent(); continue
            }
            if s.state.riftWarned != true { XCTAssertEqual(fired, 0, "フラグ前に出た") }
            if s.pendingChoiceEvent != nil { s.dismissChoiceEvent(); continue }
            if s.pendingResult != nil { s.acknowledgeResult(); continue }
            switch s.phase {
            case .tournamentDecision: s.decideTournament(.新幹線)
            case .freeAction: s.choose(.rest(.完全休養))
            case .gpRound, .gpRevival, .gpFinal: s.advanceAuto()
            default: steps = 4000
            }
        }
        XCTAssertEqual(fired, 1)
        XCTAssertEqual(warnedBeforeFire, true)
        XCTAssertTrue(warnedBeforeEver)
    }
    /// 予告の後の「すれ違いが減る」知らせは、選んだ後に一度だけ出る（選ぶ前は出ない・記録後は出ない）
    func testRiftHintShowsOnlyOnceAfterWarning() {
        var st = GameState(config: GameConfig()); st.compat = 12; st.money = 5_000_000; st.rift = 10; st.riftWarned = true
        let s = GameSession(startState: st)
        XCTAssertEqual(s.pendingChoiceEvent, .riftWarning)
        XCTAssertFalse(s.riftHintToShow, "選ぶ前に出た")
        s.applyEventChoice(s.availableEventChoices()[0].id)
        s.dismissChoiceEvent()
        XCTAssertTrue(s.riftHintToShow)
        s.markRiftHintShown()
        XCTAssertFalse(s.riftHintToShow, "2回目が出た")
    }
    /// 予告が出た週に「年末へ」を押しても、予告は消えず次の年の第1週頭に出る（1キャリア1回は保つ）
    func testRiftWarningSurvivesFastForwardToYearEnd() {
        var st = GameState(config: GameConfig()); st.compat = 12; st.money = 5_000_000; st.rift = 10; st.riftWarned = true
        let s = GameSession(startState: st)
        XCTAssertEqual(s.pendingChoiceEvent, .riftWarning)
        s.fastForwardToYearEnd()
        if s.watchingFinal { s.finishWatchingFinal(winner: "x"); s.fastForwardToYearEnd() }   // 決勝の夜は観せて止まる
        XCTAssertTrue(s.finished && !s.careerOver, "年末まで進む前提 finished=\(s.finished) over=\(s.careerOver) rift=\(s.state.rift ?? -1)")
        guard s.finished, !s.careerOver else { return }
        XCTAssertFalse(s.didFireRiftWarn)
        s.startNextYear()
        XCTAssertEqual(s.pendingChoiceEvent, .riftWarning)
        XCTAssertEqual(s.week, 1)
        XCTAssertTrue(s.didFireRiftWarn)
        s.dismissChoiceEvent()
        s.fastForwardToYearEnd()
        XCTAssertTrue(s.didFireRiftWarn)
    }
    func testNoRiftWarnWhenFlagNeverSet() {
        var st = GameState(config: GameConfig()); st.rift = 0
        let s = GameSession(startState: st)
        XCTAssertNotEqual(s.pendingChoiceEvent, .riftWarning)
        XCTAssertFalse(s.didFireRiftWarn)
    }
}

final class PlaytestFixTests: IsolatedStoreTestCase {
    func testShortagesWhenOnlyMaGrains() {
        let cfg = GameConfig()
        var st = GameState(config: cfg)
        for c in ExpCurrency.allCases { st[currency: c] = 0 }
        st[currency: .間合い] = 80          // 間だけ貯まっている
        // 華（存在感70%・閃き30%）は存在感も閃きも足りない
        let sh = AbilityUpView.shortages(.華, state: st, config: cfg)
        XCTAssertTrue(sh.contains { $0.currency == .存在感 && $0.short > 0 })
        XCTAssertTrue(sh.contains { $0.currency == .閃き && $0.short > 0 })
        XCTAssertFalse(sh.contains { $0.currency == .間合い })
    }
    func testNoShortageWhenRich() {
        let cfg = GameConfig()
        var st = GameState(config: cfg)
        for c in ExpCurrency.allCases { st[currency: c] = 500 }
        for a in Ability.allCases { XCTAssertTrue(AbilityUpView.shortages(a, state: st, config: cfg).isEmpty) }
    }
    func testPracticesMapToTrainingSpec() {
        let cfg = GameConfig()
        XCTAssertEqual(AbilityUpView.practices(for: .存在感, config: cfg).first, "舞台に立つ")
        XCTAssertTrue(AbilityUpView.practices(for: .存在感, config: cfg).contains("カラオケボックスで声出し"))
        XCTAssertEqual(AbilityUpView.practices(for: .閃き, config: cfg).first, "ネタを書く")
        XCTAssertFalse(AbilityUpView.practices(for: .語彙, config: cfg).isEmpty)   // 語彙は副効果から引く
    }
}


/// 実プレイ点検 v2 の直し：年末の独白の条件（その年の戦績）・使った文を避ける選び方・観客の声。
final class PlaytestFixV2Tests: IsolatedStoreTestCase {
    func testStageRecordCountsWinsAndLosses() {
        let log = ["第10週: 春新人賞A 通過", "第15週: 春新人賞B 敗退 / 夏の賞 優勝 +25万", "第20週: 体調 休", "第46週: 頂GP 決勝 優勝「夕凪」（客席から）"]
        let r = YearResultView.stageRecord(log: log)
        XCTAssertEqual(r.wins, 2)
        XCTAssertEqual(r.losses, 1)
    }
    func testWinningYearDropsLosingMonologue() {
        let pool = ["今年は、予選で落ちる日が多かった。落ちた大会の名前を、手帳に書き出しておこう。",
                    "バイトと稽古だけで、一年が終わった。明日は一日、何もしないで休もう。"]
        // 5勝2敗：負けを語る行は出ない
        XCTAssertEqual(YearResultView.filterByRecord(pool, wins: 5, losses: 2), [pool[1]])
        // 負け越し・同数・記録なし：そのまま
        XCTAssertEqual(YearResultView.filterByRecord(pool, wins: 2, losses: 5), pool)
        XCTAssertEqual(YearResultView.filterByRecord(pool, wins: 2, losses: 2), pool)
        XCTAssertEqual(YearResultView.filterByRecord(pool, wins: 0, losses: 0), pool)
        // 外すと空になる時は元のまま
        XCTAssertEqual(YearResultView.filterByRecord([pool[0]], wins: 5, losses: 2), [pool[0]])
    }
    func testIndexAvoidingUsedPrefersFreshThenOldest() {
        XCTAssertEqual(DialogueData.indexAvoidingUsed(count: 4, salt: 1, used: []), 1)
        XCTAssertEqual(DialogueData.indexAvoidingUsed(count: 4, salt: 1, used: [1, 2]), 3)
        // 尽きたら最も古い物（先頭）から
        XCTAssertEqual(DialogueData.indexAvoidingUsed(count: 3, salt: 0, used: [2, 0, 1]), 2)
    }
    func testSessionPickRotatesThroughPoolBeforeRepeating() {
        let s = GameSession()
        var seen: [Int] = []
        for i in 0..<5 { seen.append(s.pickIndex(scene: "t", count: 5, salt: i * 3)) }
        XCTAssertEqual(Set(seen).count, 5)           // 5回で全部違う
        XCTAssertEqual(s.pickIndex(scene: "t", count: 5, salt: 0), seen[0])   // 尽きたら最も古い物から
    }
    func testFanVoicesAvoidUsedLines() {
        let first = FanReportData.voices(name: "A", passed: true, margin: 12, burst: false, salt: 3)
        let second = FanReportData.voices(name: "A", passed: true, margin: 12, burst: false, salt: 3, used: first)
        XCTAssertTrue(Set(first).isDisjoint(with: Set(second)))
        XCTAssertEqual(first, FanReportData.voices(name: "A", passed: true, margin: 12, burst: false, salt: 3, used: []))
    }
}

final class WeekHintTests: IsolatedStoreTestCase {
    private func base() -> WeekHint.Input {
        .init(netaCount: 2, stageWeeksLeft: 10, stageLength: .中尺, netaFitsStage: true, stamina: 80,
              livingThisWeek: false, money: 500_000, livingCost: 140_000, weeksWithoutPartner: 0,
              plusAvailable: false, expBannerShown: false)
    }
    func testNone() { XCTAssertNil(WeekHint.line(base())) }
    func testDebtWeekIsNarration() {
        var i = base(); i.money = -1; i.stamina = 40
        XCTAssertEqual(WeekHint.line(i), "所持金はマイナス。今月の家賃のめどが立っていない。")
    }
    func testInjuryWarn() {
        var i = base(); i.stamina = 45
        XCTAssertEqual(WeekHint.line(i), "谷口：無理すると倒れるぞ。")
    }
    func testNoNeta() {
        var i = base(); i.netaCount = 0
        XCTAssertEqual(WeekHint.line(i), "まだネタが無い。まずはネタを書こう。")
    }
    func testStamina() {
        var i = base(); i.stamina = 30
        XCTAssertEqual(WeekHint.line(i), "体力が少ない。今週は休むのも手だ。")
        i.stamina = 31; XCTAssertEqual(WeekHint.line(i), "谷口：無理すると倒れるぞ。")   // 体調ダウンの注意（体力50未満・§97）
        i.stamina = 50; XCTAssertNil(WeekHint.line(i))
    }
    func testLiving() {
        var i = base(); i.livingThisWeek = true; i.money = 139_999
        XCTAssertEqual(WeekHint.line(i), "今週末に生活費。所持金が足りない。")
        i.money = 140_000; XCTAssertNil(WeekHint.line(i))
        i.livingThisWeek = false; i.money = 0; XCTAssertNil(WeekHint.line(i))
    }
    func testLivingForecast() {
        var i = base(); i.livingInTwoWeeks = true
        XCTAssertEqual(WeekHint.line(i), "再来週は月末の支払い（家賃など）14万円。")
    }
    func testPartner() {
        var i = base(); i.weeksWithoutPartner = 6
        XCTAssertEqual(WeekHint.line(i), "最近、相方とゆっくり話していない。")
        i.weeksWithoutPartner = 5; XCTAssertNil(WeekHint.line(i))
    }
    func testPlusAndBannerMerge() {
        var i = base(); i.plusAvailable = true
        XCTAssertEqual(WeekHint.line(i), "経験点で上げられる能力がある。")
        i.expBannerShown = true; XCTAssertNil(WeekHint.line(i))   // 朱の帯と重ねない
    }
    func testPriorityOrder() {
        var i = base()
        i.netaCount = 0; i.stageWeeksLeft = 2; i.netaFitsStage = false; i.stamina = 10
        i.livingThisWeek = true; i.money = 0; i.weeksWithoutPartner = 9; i.plusAvailable = true
        XCTAssertEqual(WeekHint.line(i), "まだネタが無い。まずはネタを書こう。")
        i.netaCount = 1; XCTAssertEqual(WeekHint.line(i), "今週末に生活費。所持金が足りない。")
        i.money = 999_999; XCTAssertEqual(WeekHint.line(i), "体力が少ない。今週は休むのも手だ。")
        i.stamina = 80; XCTAssertEqual(WeekHint.line(i), "最近、相方とゆっくり話していない。")
        i.weeksWithoutPartner = 0; XCTAssertEqual(WeekHint.line(i), "経験点で上げられる能力がある。")
    }
}

/// 週次の選択肢イベントは1キャリア1回（年をまたいでも同じイベントが再発火しない・playtest_v4 ②）
final class WeeklyEventOnceTests: IsolatedStoreTestCase {
    func testNoRepeatAcrossYears() {
        for seed in [424242, 1, 7, 99, 2024] as [UInt64] {
            let s = GameSession(seed: seed)
            var kinds: [String: Int] = [:]
            _ = GameSession.debugSelfPlay(s, kinds: &kinds)
            let weekly = Set(ChoiceEventKind.allCases.filter { $0.isWeeklyRandom }.map { "\($0)" })
            for (k, n) in kinds where weekly.contains(k) {
                XCTAssertLessThanOrEqual(n, 1, "seed \(seed): \(k) が \(n) 回発火")
            }
        }
    }
}

/// playtest_v4 ③④：本番前の既定ネタ・年末の出来事の優勝
final class PlaytestV4FixTests: IsolatedStoreTestCase {
    func testStageNetaDefaultIsBestPolished() {
        var st = GameState(config: GameConfig())
        var best = Neta(id: 0, name: "商店街の福引", kata: .伏線回収, lengthFit: [.長尺], bornYear: 1); best.polish = 100; best.stageCount = 3
        var fresh = Neta(id: 1, name: "終電の二人", kata: .瞬発, lengthFit: [.短尺], bornYear: 1); fresh.polish = 30
        st.netas = [best, fresh]; st.selectedNetaID = 1   // 新しく書いた直後に自動で選ばれた低い2本目
        let s = GameSession(startState: st)
        s.ensureStageNetaDefault()
        XCTAssertEqual(s.selectedNeta?.id, 0)
        s.selectNeta(nil); s.ensureStageNetaDefault()
        XCTAssertEqual(s.selectedNeta?.id, 0)   // 選び忘れも一番高い物へ
        var played = fresh; played.stageCount = 2; played.polish = 40
        var st2 = st; st2.netas = [best, played]; st2.selectedNetaID = 1
        let t = GameSession(startState: st2)
        t.ensureStageNetaDefault()
        XCTAssertEqual(t.selectedNeta?.id, 1)   // 手で選んだ舞台経験ありのネタは保つ
    }
    func testEventLinesKeepChampionships() {
        let log = ["第12週: 春新人賞A 優勝 +50万", "第15週: 春新人賞B 優勝 +25万", "第27週: 夏中堅賞 敗退",
                   "第41週: GP3回戦 通過", "第43週: GP準々決勝 通過", "第46週: GP準決勝 敗退"]
        let l = YearResultView.eventLines(log)
        XCTAssertEqual(l.count, 3)
        XCTAssertTrue(l.contains(log[0]) && l.contains(log[1]))
        XCTAssertEqual(l.last, log[5])
        XCTAssertEqual(YearResultView.eventLines(["a", "b"]), ["a", "b"])
    }
    func testEventLinesKeepFinalsLoss() {
        let log = ["第27週: 夏中堅賞 優勝 +500万", "第29週: 秋賞 優勝 +25万", "第35週: 冬賞 優勝 +10万",
                   "第43週: GP準々決勝 通過", "第46週: GP準決勝 通過", "第47週: GP決勝 敗退"]
        let l = YearResultView.eventLines(log)
        XCTAssertEqual(l.count, 3)
        XCTAssertTrue(l.contains(log[5]))
    }
    func testFinalsYearHasNoMonolog() {
        XCTAssertTrue(YearResultView.silentFinalsYear(bankrupt: false, dissolved: false, champion: false, reachedFinal: true))
        XCTAssertTrue(YearResultView.silentFinalsYear(bankrupt: false, dissolved: false, champion: true, reachedFinal: true))
        XCTAssertFalse(YearResultView.silentFinalsYear(bankrupt: false, dissolved: false, champion: false, reachedFinal: false))
        XCTAssertFalse(YearResultView.silentFinalsYear(bankrupt: true, dissolved: false, champion: false, reachedFinal: true))
        XCTAssertFalse(YearResultView.silentFinalsYear(bankrupt: false, dissolved: true, champion: false, reachedFinal: true))
    }
}

/// 月末の支払い（生活費の演出）：内訳の合計と足りない額
final class RentStatementTests: IsolatedStoreTestCase {
    func testBreakdownSumsToLivingCost() {
        for total in [140_000, 100_000, 123_457, 1, 0] {
            XCTAssertEqual(RentStatement.breakdown(total: total).reduce(0) { $0 + $1.amount }, total)
        }
        let d = RentStatement.breakdown(total: GameConfig().livingCost).map(\.amount)
        XCTAssertEqual(d, [60_000, 40_000, 20_000, 20_000])
    }
    func testShortfall() {
        var r = RentStatement.make(livingCost: 140_000, moneyAfter: 60_000)
        XCTAssertEqual(r.moneyBefore, 200_000); XCTAssertEqual(r.shortfall, 0); XCTAssertTrue(r.paid)
        r = RentStatement.make(livingCost: 140_000, moneyAfter: 0)
        XCTAssertEqual(r.shortfall, 0)
        r = RentStatement.make(livingCost: 140_000, moneyAfter: -30_000)
        XCTAssertEqual(r.shortfall, 30_000); XCTAssertFalse(r.paid)
        r = RentStatement.make(livingCost: 140_000, moneyAfter: -240_000)
        XCTAssertEqual(r.moneyBefore, -100_000); XCTAssertEqual(r.shortfall, 140_000)
    }
}


final class ExpDisplayTests: XCTestCase {
    func testValueFloorsAfterScaling() {
        XCTAssertEqual(ExpDisplay.value(1.44), 14)
        XCTAssertEqual(ExpDisplay.value(2.88), 28)
        XCTAssertEqual(ExpDisplay.value(0.0), 0)
        XCTAssertEqual(ExpDisplay.value(1.0), 10)   // 浮動小数の誤差で9にならない
    }
    func testCostRoundsUpButNeverExceedsAffordableHave() {
        XCTAssertEqual(ExpDisplay.cost(1.42, have: 5.0), 15)   // 余裕あり＝切り上げ
        XCTAssertEqual(ExpDisplay.cost(1.42, have: 1.44), 14)  // 足りるのに15と出さない
        XCTAssertEqual(ExpDisplay.cost(1.5, have: 1.44), 15)   // 足りない＝持ち分14 < 必要15
    }
    func testNoAffordableMismatch() {
        for h in stride(from: 0.05, through: 6.0, by: 0.01) {
            for a in stride(from: 0.05, through: 6.0, by: 0.07) where a <= h {
                XCTAssertLessThanOrEqual(ExpDisplay.cost(a, have: h), max(1, ExpDisplay.value(h)))
            }
        }
    }
}

final class NetaStageTests: XCTestCase {
    func testStageBoundaries() {
        XCTAssertEqual(NetaStage.index(0), 0)
        XCTAssertEqual(NetaStage.index(34.99), 0)
        XCTAssertEqual(NetaStage.index(35), 1)
        XCTAssertEqual(NetaStage.index(59.99), 1)
        XCTAssertEqual(NetaStage.index(60), 2)
        XCTAssertEqual(NetaStage.index(84.99), 2)
        XCTAssertEqual(NetaStage.index(85), 3)
        XCTAssertEqual(NetaStage.name(100), "仕上がった")
    }
}

/// 2026-10-19 に直した GameSession の動き（二度押し・ネタ選択の重複・休みへの差し替え）を守る
final class SessionGuardTests20261019: IsolatedStoreTestCase {
    private func neta(_ id: Int, polish: Double = 50) -> Neta {
        var n = Neta(id: id, name: "ネタ\(id)", kata: .瞬発, lengthFit: [.短尺], bornYear: 1)
        n.polish = polish
        return n
    }
    private func threeNetaSession() -> GameSession {
        var st = GameState(config: GameConfig())
        st.netas = [neta(0), neta(1), neta(2)]
        st.nextNetaID = 3
        st.selectedNetaID = 0
        return GameSession(startState: st)
    }

    func testAcknowledgeResultTwiceAdvancesOnce() {
        let s = GameSession(startState: GameSession.debugMaxedState())
        s.debugAdvanceToFirstResult()
        XCTAssertNotNil(s.pendingResult)
        s.acknowledgeResult()
        let w = s.week
        s.acknowledgeResult()
        XCTAssertEqual(s.week, w)
        XCTAssertNil(s.pendingResult)
    }

    func testSelectNeta2RejectsSameAsFirst() {
        let s = threeNetaSession()
        s.selectNeta2(0)
        XCTAssertNil(s.state.selectedNetaID2)
        s.selectNeta2(1)
        XCTAssertEqual(s.state.selectedNetaID2, 1)
    }

    func testSelectNetaDropsSecondWhenSame() {
        let s = threeNetaSession()
        s.selectNeta2(1)
        s.selectNeta(1)
        XCTAssertEqual(s.state.selectedNetaID, 1)
        XCTAssertNil(s.state.selectedNetaID2)
    }

    func testRetireSecondNetaClearsSecond() {
        let s = threeNetaSession()
        s.selectNeta2(1)
        s.retireNeta(1)
        XCTAssertNil(s.state.selectedNetaID2)
        XCTAssertFalse(s.state.netas.contains { $0.id == 1 })
    }

    func testEnsureStageNetaDefaultFixesSameFirstAndSecond() {
        var st = GameState(config: GameConfig())
        st.netas = [neta(0), neta(1)]
        st.selectedNetaID = 0
        st.selectedNetaID2 = 0   // 旧セーブの1本目＝2本目
        let s = GameSession(startState: st)
        s.ensureStageNetaDefault()
        XCTAssertNil(s.state.selectedNetaID2)
    }

    func testApplyEventChoiceTwiceAppliesOnce() throws {
        let s = GameSession(startState: GameSession.debugMaxedState())
        var found = false
        let enc = JSONEncoder()
        enc.outputFormatting = .sortedKeys   // itemCounts（辞書）の並びが呼ぶたびに変わり、同じ中身でも別バイトになる
        for kind in ChoiceEventKind.allCases {
            s.debugForceEvent(kind)
            guard let c = s.availableEventChoices().first else { continue }
            let before = try enc.encode(s.state)
            s.applyEventChoice(c.id)
            let once = try enc.encode(s.state)
            s.applyEventChoice(c.id)
            let twice = try enc.encode(s.state)
            XCTAssertEqual(once, twice, "\(kind) の二度呼びで効果が二重にかかった")
            if once != before { found = true; break }   // 状態が動く選択肢で一度確かめれば足りる
        }
        XCTAssertTrue(found)
    }

    func testBuyItemSuccessSpendsMoney() throws {
        var st = GameState(config: GameConfig())
        st.money = 1_000_000
        let s = GameSession(startState: st)
        let item = try XCTUnwrap(s.config.shopLineup.first { GameEngine.canBuy($0, state: s.state, config: s.config) })
        let price = try XCTUnwrap(s.config.items[item]).price
        XCTAssertTrue(s.buyItem(item))
        XCTAssertEqual(s.state.money, 1_000_000 - price)
    }

    func testRehearsalReplacedByRestCountsAsWeekWithoutPartner() {
        // 体力ゲート（体力 < staminaGate）で稽古が休みに差し替わる。キツいバイトで体力を削ってから、ネタ合わせを選ぶ
        let s = GameSession(startState: GameState(config: GameConfig()))
        var guardSteps = 0
        while s.state.stamina >= s.config.staminaGate, !s.finished, guardSteps < 30 {
            guardSteps += 1
            s.debugFreeWeeks(1, .job(.キツい))
        }
        guard case .freeAction = s.phase, s.state.stamina < s.config.staminaGate, s.pendingChoiceEvent == nil, s.pendingResult == nil else {
            return XCTFail("体力を削れなかった/自由週ではない: \(s.phase) \(s.state.stamina)")
        }
        let before = s.state.stamina
        let prev = s.weeksWithoutPartner
        s.choose(.train(.ネタ合わせ))
        XCTAssertGreaterThan(s.state.stamina, before)   // ネタ合わせは体力-20＝増えた＝休みに差し替わった
        XCTAssertEqual(s.weeksWithoutPartner, prev + 1)
    }

    // キュー116: 決勝の審査員の点と7票（表示のみ・勝敗は GameCore の champion/margin のまま）
    func testFinalsJudgeVotesAbilityBased() {
        var weak = GameState(config: GameConfig())
        weak.センス = 60; weak.発想 = 60; weak.表現 = 60; weak.華 = 50; weak.メンタル = 50; weak.compat = 8
        for y in 1...40 {
            // MAX・優勝・大差 → 補正なしで7-0
            let mx = FinalsData(state: GameSession.debugMaxedState(), champion: true, margin: 30, year: y, selfName: "あなたのコンビ", polish: 100)
            XCTAssertEqual(mx.finalVotes, 7, "year \(y)")
            XCTAssertEqual(mx.judges.reduce(0) { $0 + $1.score }, mx.total)
            for st in [GameSession.debugMaxedState(), weak] {
                for (champ, m) in [(true, 2.0), (true, 12.0), (false, -2.0), (false, -12.0)] {
                    let d = FinalsData(state: st, champion: champ, margin: m, year: y, selfName: "あなたのコンビ", polish: 55)
                    XCTAssertEqual(d.judges.reduce(0) { $0 + $1.score }, d.total)
                    XCTAssertEqual(d.judgeVotes.count, 7)
                    if let si = d.selfDuelIndex {
                        let own = d.judgeVotes.filter { $0 == si }.count
                        if champ { XCTAssertGreaterThanOrEqual(own, 4); XCTAssertEqual(d.winnerIndex, si) }
                        else { XCTAssertLessThanOrEqual(own, 3); XCTAssertNotEqual(d.winnerIndex, si) }
                    } else { XCTAssertFalse(champ) }
                }
            }
        }
        // 重み表は行合計1
        for w in FinalsData.judgeWeights { XCTAssertEqual(w.reduce(0, +), 1.0, accuracy: 1e-9) }
    }
}
