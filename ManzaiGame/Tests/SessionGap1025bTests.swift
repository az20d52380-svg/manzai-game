// アプリ側の穴埋めテスト その2（カバレッジ0の純ロジック：終わりの判定・終わりの図鑑・ネタ段・コンビ形・司会台詞・星・尺・嗜好・現在の挙動を固定）
import XCTest
import GameCore
@testable import ManzaiGame

final class EndingJudgeGapTests: XCTestCase {
    private func rec(_ y: Int, final f: Bool) -> GameSession.YearRecord {
        GameSession.YearRecord(year: y, roundsPassed: 1, reachedFinal: f, champion: false, bankrupt: false, prize: 0)
    }
    private func out(champ: Bool = false, final f: Bool = false, bank: Bool = false, diss: Bool = false) -> YearOutcome {
        YearOutcome(champion: champ, roundsPassed: 0, reachedFinal: f, bankrupt: bank, dissolved: diss)
    }

    func testBankruptBeatsEverything() {
        let o = out(champ: true, bank: true, diss: true)
        XCTAssertEqual(EndingID.judge(outcome: o, compat: 50, history: [], year: 1, careerYears: 10), .nightEscape)
    }
    func testDissolvedBeatsChampion() {
        let o = out(champ: true, diss: true)
        XCTAssertEqual(EndingID.judge(outcome: o, compat: 50, history: [], year: 1, careerYears: 10), .breakup)
    }
    func testChampionSplitsOnCompatThreshold15() {
        let o = out(champ: true, final: true)
        XCTAssertEqual(EndingID.judge(outcome: o, compat: 15, history: [], year: 2, careerYears: 10), .championPair)
        XCTAssertEqual(EndingID.judge(outcome: o, compat: 14.9, history: [], year: 2, careerYears: 10), .championRetire)
    }
    func testNotYetEndsReturnsNilBeforeCareerYears() {
        XCTAssertNil(EndingID.judge(outcome: out(), compat: 99, history: [rec(1, final: true)], year: 9, careerYears: 10))
    }
    func testCareerEndFourWays() {
        let withFinal = [rec(1, final: false), rec(2, final: true)]
        let noFinal = [rec(1, final: false)]
        func j(_ h: [GameSession.YearRecord], _ c: Double) -> EndingID? {
            EndingID.judge(outcome: out(), compat: c, history: h, year: 10, careerYears: 10)
        }
        XCTAssertEqual(j(withFinal, 15), .tenYearsTrue)
        XCTAssertEqual(j(withFinal, 0), .tenYearsClose)
        XCTAssertEqual(j(noFinal, 20), .keptGoing)
        XCTAssertEqual(j(noFinal, 14), .gaveUp)
    }
    func testNumbersRoundTripAndKinds() {
        XCTAssertEqual(EndingID.allCases.map { $0.number }, [1, 2, 3, 4, 5, 6, 7, 8])
        for id in EndingID.allCases { XCTAssertEqual(EndingID.from(number: id.number), id) }
        XCTAssertNil(EndingID.from(number: 0)); XCTAssertNil(EndingID.from(number: 9))
        XCTAssertEqual(EndingID.nightEscape.kind.label, "バッド")
        XCTAssertEqual(EndingID.keptGoing.kind.label, "ビター")
        XCTAssertEqual(EndingID.tenYearsClose.kind.label, "ノーマル")
        XCTAssertEqual(EndingID.championRetire.kind.label, "グッド")
        XCTAssertEqual(EndingID.championPair.kind.label, "トゥルー")
        XCTAssertEqual(EndingID.championPair.title, "間の席")
        XCTAssertEqual(EndingID.nightEscape.caption, "始発は五時十二分に出た。")
    }
}

final class EndingBookGapTests: IsolatedStoreTestCase {
    func testEmptyThenRecordThenCountUp() {
        XCTAssertTrue(EndingBook.load().isEmpty)
        EndingBook.record(.breakup, partner: "A")
        var all = EndingBook.load()
        XCTAssertEqual(all[.breakup]?.count, 1)
        XCTAssertEqual(all[.breakup]?.lastPartnerName, "A")
        let first = all[.breakup]?.firstSeenAt
        EndingBook.record(.breakup, partner: "B")
        EndingBook.record(.gaveUp, partner: "C")
        all = EndingBook.load()
        XCTAssertEqual(all[.breakup]?.count, 2)
        XCTAssertEqual(all[.breakup]?.lastPartnerName, "B")
        XCTAssertEqual(all[.breakup]?.firstSeenAt, first)
        XCTAssertEqual(all[.gaveUp]?.count, 1)
        XCTAssertEqual(all.count, 2)
    }
}

final class NetaStageGapTests: XCTestCase {
    func testStageBoundaries() {
        XCTAssertEqual(NetaStage.index(0), 0)
        XCTAssertEqual(NetaStage.index(34.9), 0)
        XCTAssertEqual(NetaStage.index(35), 1)
        XCTAssertEqual(NetaStage.index(59.9), 1)
        XCTAssertEqual(NetaStage.index(60), 2)
        XCTAssertEqual(NetaStage.index(84.9), 2)
        XCTAssertEqual(NetaStage.index(85), 3)
        XCTAssertEqual(NetaStage.index(500), 3)
        XCTAssertEqual(NetaStage.name(10), "書きかけ")
        XCTAssertEqual(NetaStage.name(90), "仕上がった")
    }
}

final class ComboKindGapTests: XCTestCase {
    func testFromRawFallsBackToMaleMale() {
        XCTAssertEqual(ComboKind.from(nil), .maleMale)
        XCTAssertEqual(ComboKind.from("bogus"), .maleMale)
        XCTAssertEqual(ComboKind.from("femaleMale"), .femaleMale)
    }
    func testGenderFlagsAndFirstPersons() {
        let t: [(ComboKind, Bool, Bool, String, String)] = [
            (.maleMale, false, false, "俺", "俺"),
            (.femaleFemale, true, true, "私", "私"),
            (.maleFemale, false, true, "俺", "私"),
            (.femaleMale, true, false, "私", "俺"),
        ]
        for (k, me, pa, mf, pf) in t {
            XCTAssertEqual(k.meIsFemale, me); XCTAssertEqual(k.partnerIsFemale, pa)
            XCTAssertEqual(k.meFirstPerson, mf); XCTAssertEqual(k.partnerFirstPerson, pf)
        }
    }
    func testCardTexts() {
        XCTAssertEqual(ComboKind.maleFemale.cardTitle, "男女コンビ")
        XCTAssertEqual(ComboKind.femaleMale.cardTitle, "男女コンビ")
        XCTAssertEqual(ComboKind.maleFemale.cardSub, "自分が男・相方が女")
        XCTAssertEqual(ComboKind.femaleMale.cardSub, "自分が女・相方が男")
        XCTAssertEqual(ComboKind.femaleFemale.cardTitle, "女コンビ")
    }
}

final class FinalsTalkGapTests: XCTestCase {
    func testMCCallAndSeats() {
        XCTAssertEqual(FinalsMC.call(order: 1, name: "X"), "トップバッターは、X！")
        XCTAssertEqual(FinalsMC.call(order: 10, name: "X"), "いよいよ大トリです。X！")
        XCTAssertEqual(FinalsMC.call(order: 4, name: "X"), "4番目は……X！")
        XCTAssertEqual(FinalsMC.seated(name: "X", rank: 2), "X、暫定2位！ 暫定席へどうぞ！")
        XCTAssertEqual(FinalsMC.eliminated(name: "X", rank: 5), "X、暫定5位。ここで敗退です。ありがとうございました！")
    }
    func testAskJudgeUsesFamilyNameAndHighLow() {
        XCTAssertEqual(FinalsMC.askJudge("音羽 ルリ", score: 95, high: true), "音羽さん、95点。いかがでしたか？")
        XCTAssertEqual(FinalsMC.askJudge("音羽 ルリ", score: 80, high: false), "音羽さんは80点と、少し辛めでした。いかがでしたか？")
        XCTAssertEqual(FinalsMC.askJudge("単名", score: 80, high: true), "単名さん、80点。いかがでしたか？")
    }
    func testBandThresholds() {
        XCTAssertEqual(FinalsJudgeTalk.band(95), "A"); XCTAssertEqual(FinalsJudgeTalk.band(94), "B")
        XCTAssertEqual(FinalsJudgeTalk.band(91), "B"); XCTAssertEqual(FinalsJudgeTalk.band(90), "C")
        XCTAssertEqual(FinalsJudgeTalk.band(87), "C"); XCTAssertEqual(FinalsJudgeTalk.band(86), "D")
    }
}

final class JudgeStarsAndCatalogGapTests: XCTestCase {
    func testStarsClampAndDerivation() {
        var s = GameState(config: GameConfig())
        s.発想 = 0; s.センス = 120; s.表現 = 200; s.華 = 200
        let st = JudgeData.stars(s)
        XCTAssertEqual(st.map { $0.0 }, ["構成", "間", "熱量"])
        XCTAssertEqual(st.map { $0.1 }, [1, 5, 5])
        s.発想 = 24; s.センス = 60; s.表現 = 0; s.華 = 48   // 24→2 / 60(2.5→3)→4 / 平均24→2
        XCTAssertEqual(JudgeData.stars(s).map { $0.1 }, [2, 4, 2])
    }
    func testGPRoundLengthsAndTournamentLengths() {
        XCTAssertEqual(NetaCatalog.lengthForGPRound(index: 0), .短尺)
        XCTAssertEqual(NetaCatalog.lengthForGPRound(index: 1), .短尺)
        XCTAssertEqual(NetaCatalog.lengthForGPRound(index: 2), .中尺)
        XCTAssertEqual(NetaCatalog.lengthForGPRound(index: 3), .中尺)
        XCTAssertEqual(NetaCatalog.lengthForGPRound(index: 4), .長尺)
        XCTAssertEqual(NetaCatalog.lengthForTournament, .中尺)
        XCTAssertEqual(NetaCatalog.lengthForGPRevival, .長尺)
        XCTAssertEqual(NetaCatalog.lengthForGPFinal, .長尺)
    }
    func testAutoKataCyclesAndNamesWrap() {
        let all = NetaKata.allCases
        XCTAssertEqual(NetaCatalog.autoKata(forID: 0), all[0])
        XCTAssertEqual(NetaCatalog.autoKata(forID: all.count), all[0])
        XCTAssertEqual(NetaCatalog.autoKata(forID: -1), all[all.count - 1])
        XCTAssertEqual(NetaCatalog.autoName(forID: 3), NetaCatalog.autoName(forID: 3 + 10_000 * 0))
        XCTAssertFalse(NetaCatalog.autoName(forID: -7).isEmpty)
    }
    func testDisplayNamesAndDefaultFit() {
        XCTAssertEqual(NetaCatalog.displayName(.短尺), "短め")
        XCTAssertEqual(NetaCatalog.displayName(.中尺), "ふつう")
        XCTAssertEqual(NetaCatalog.displayName(.長尺), "長め")
        XCTAssertEqual(NetaCatalog.displayName(NetaKata.非定型), "飛び道具")
        XCTAssertEqual(NetaCatalog.displayName(NetaKata.瞬発), "畳みかけ")
        XCTAssertEqual(NetaCatalog.defaultLengthFit(for: .伏線回収), [.長尺])
        XCTAssertEqual(NetaCatalog.defaultLengthFit(for: .華先行), [.短尺])
        XCTAssertEqual(NetaCatalog.affinity(.王道しゃべくり, judge: "存在しない審査員"), "○")
    }
}
