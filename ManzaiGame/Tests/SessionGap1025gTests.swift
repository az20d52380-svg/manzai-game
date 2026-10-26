// アプリ側の未カバー（Names.clean/set・RentStatement・ComboKind/MeetingKind・StoreIDs・WeekHint 優先順・StageOutfit 髪型）
import XCTest
import GameCore
@testable import ManzaiGame

final class NamesCleanTests: XCTestCase {
    override func tearDown() { Names.set(me: nil, partner: nil); Names.setKind(.maleMale); super.tearDown() }

    func testCleanTrimsAndLimitsLength() {
        XCTAssertEqual(Names.clean(nil), "")
        XCTAssertEqual(Names.clean("  \n "), "")
        XCTAssertEqual(Names.clean("  ミナト \n"), "ミナト")
        XCTAssertEqual(Names.clean("あいうえおかきくけこ"), "あいうえおか")   // 6文字まで
        XCTAssertEqual(Names.clean("  あいうえおかき  ").count, Names.maxLength)
    }

    func testSetFallsBackToDefaultPartnerAndKeepsMeEmpty() {
        Names.set(me: "  ", partner: "   ")
        XCTAssertEqual(Names.me, "")
        XCTAssertEqual(Names.partner, Names.defaultPartner)
        Names.set(me: " ミナト ", partner: " ケンジ ")
        XCTAssertEqual(Names.me, "ミナト")
        XCTAssertEqual(Names.partner, "ケンジ")
    }
}

final class RentStatementGapTests: XCTestCase {
    func testBreakdownSumsToTotalForAwkwardAmounts() {
        for total in [0, 1, 7, 99_999, 140_000, 150_001, 1_234_567] {
            let lines = RentStatement.breakdown(total: total)
            XCTAssertEqual(lines.map(\.amount).reduce(0, +), total, "total=\(total)")
            XCTAssertEqual(lines.map(\.label), ["家賃", "食費", "光熱費・携帯", "交通費"])
        }
        XCTAssertEqual(RentStatement.breakdown(total: 140_000).map(\.amount), [60_000, 40_000, 20_000, 20_000])
    }

    func testMakeAddsRoomExtraToRentLineOnly() {
        let s = RentStatement.make(livingCost: 160_000, moneyAfter: 30_000, roomExtra: 20_000, roomName: "六畳")
        XCTAssertEqual(s.lines[0].label, "家賃（六畳）")
        XCTAssertEqual(s.lines[0].amount, 60_000 + 20_000)
        XCTAssertEqual(s.lines.map(\.amount).reduce(0, +), 160_000)
        XCTAssertEqual(s.total, 160_000)
        XCTAssertEqual(s.moneyBefore, 190_000)
        XCTAssertTrue(s.paid)
    }

    func testShortfallAndPaidFlag() {
        let ok = RentStatement.make(livingCost: 140_000, moneyAfter: 0)   // ちょうど払えた
        XCTAssertEqual(ok.shortfall, 0); XCTAssertTrue(ok.paid)
        let short = RentStatement.make(livingCost: 140_000, moneyAfter: -50_000)   // 前の所持金 90,000
        XCTAssertEqual(short.shortfall, 50_000); XCTAssertFalse(short.paid)
        let debt = RentStatement.make(livingCost: 140_000, moneyAfter: -200_000)   // 前の所持金が負＝全額が借金
        XCTAssertEqual(debt.shortfall, 140_000)
    }

    func testYenGroupsDigitsAndDropsSign() {
        XCTAssertEqual(RentStatement.yen(1_234_567), "1,234,567")
        XCTAssertEqual(RentStatement.yen(-50_000), "50,000")
        XCTAssertEqual(RentStatement.yen(0), "0")
    }
}

final class ComboMeetingKindTests: XCTestCase {
    func testComboKindFromAndFirstPersons() {
        XCTAssertEqual(ComboKind.from(nil), .maleMale)
        XCTAssertEqual(ComboKind.from("xxx"), .maleMale)
        XCTAssertEqual(ComboKind.from("femaleMale"), .femaleMale)
        let expect: [(ComboKind, String, String)] = [(.maleMale, "俺", "俺"), (.femaleFemale, "私", "私"),
                                                     (.maleFemale, "俺", "私"), (.femaleMale, "私", "俺")]
        for (k, me, pa) in expect {
            XCTAssertEqual(k.meFirstPerson, me, "\(k)"); XCTAssertEqual(k.partnerFirstPerson, pa, "\(k)")
        }
        XCTAssertEqual(ComboKind.maleFemale.cardTitle, ComboKind.femaleMale.cardTitle)
        XCTAssertNotEqual(ComboKind.maleFemale.cardSub, ComboKind.femaleMale.cardSub)
    }

    func testMeetingKindFromFallbackAndLabelsUnique() {
        XCTAssertEqual(MeetingKind.from(nil), .highSchool)
        XCTAssertEqual(MeetingKind.from("unknown"), .highSchool)
        XCTAssertEqual(MeetingKind.from("partTime"), .partTime)
        XCTAssertEqual(Set(MeetingKind.allCases.map(\.label)).count, MeetingKind.allCases.count)
        for m in MeetingKind.allCases {   // Codable は rawValue のまま往復する
            let d = try? JSONEncoder().encode(m)
            XCTAssertEqual(d.flatMap { try? JSONDecoder().decode(MeetingKind.self, from: $0) }, m)
        }
    }
}

final class StoreIDsTests: XCTestCase {
    func testAllIDsUniquePrefixedAndCostumesMatchOutfits() {
        XCTAssertEqual(Set(StoreIDs.all).count, StoreIDs.all.count)
        XCTAssertTrue(StoreIDs.all.allSatisfy { $0.hasPrefix(StoreIDs.prefix + ".") })
        XCTAssertEqual(StoreIDs.costume("hakama"), "\(StoreIDs.prefix).costume.hakama")
        // 商品になる衣装名は StageOutfit の rawValue と一致し、standard（無料）は商品にしない
        for n in StoreIDs.costumeNames { XCTAssertNotNil(StageOutfit(rawValue: n), n) }
        XCTAssertFalse(StoreIDs.costumeNames.contains(StageOutfit.standard.rawValue))
        XCTAssertEqual(StoreIDs.all.count, 2 + StoreIDs.costumeNames.count)
    }
}

final class WeekHintPriorityTests: XCTestCase {
    private func base() -> WeekHint.Input {
        .init(netaCount: 2, stamina: 80, livingThisWeek: false, money: 500_000, livingCost: 140_000,
              weeksWithoutPartner: 0, plusAvailable: false, expBannerShown: false)
    }

    func testQuietWeekHasNoHint() { XCTAssertNil(WeekHint.line(base())) }

    func testNegativeMoneyBeatsEverything() {
        var i = base(); i.money = -1; i.netaCount = 0; i.preoccupied = true; i.stamina = 5
        XCTAssertEqual(WeekHint.line(i), "所持金はマイナス。今月の家賃のめどが立っていない。")
    }

    func testStaminaTiers() {
        var i = base(); i.stamina = WeekHint.staminaLow
        XCTAssertEqual(WeekHint.line(i), "体力が少ない。今週は休むのも手だ。")
        i.stamina = WeekHint.staminaLow + 0.5   // 30超〜体調ダウン線未満は谷口の一言
        XCTAssertEqual(WeekHint.line(i), "谷口：無理すると倒れるよ。")
        i.stamina = WeekHint.injuryWarn
        XCTAssertNil(WeekHint.line(i))
    }

    func testLaterHintsOrderAndExpBannerSuppressesPlus() {
        var i = base(); i.livingInTwoWeeks = true; i.weeksWithoutPartner = 9; i.plusAvailable = true; i.money = 200_000
        XCTAssertEqual(WeekHint.line(i), "再来週は月末の支払い（家賃など）14万円。")
        i.livingInTwoWeeks = false
        XCTAssertEqual(WeekHint.line(i), "最近、相方とゆっくり話していない。")
        i.weeksWithoutPartner = WeekHint.partnerGapWeeks - 1
        XCTAssertEqual(WeekHint.line(i), "経験点で上げられる能力がある。")
        i.expBannerShown = true
        XCTAssertNil(WeekHint.line(i))
    }
}

final class StageOutfitHairTests: XCTestCase {
    func testFemaleKindsChangeHairAndStandardColorsOnlyForPlayers() {
        XCTAssertEqual(StageOutfit.standard.ore(rival: false, kind: .maleMale).hairStyle, .short)
        XCTAssertEqual(StageOutfit.standard.ore(rival: false, kind: .femaleMale).hairStyle, .long)
        XCTAssertEqual(StageOutfit.standard.ore(rival: true, kind: .femaleMale).hairStyle, .short)   // ライバルは変えない
        XCTAssertEqual(StageOutfit.standard.taniguchi(rival: false, kind: .maleFemale).hairStyle, .bun)
        XCTAssertEqual(StageOutfit.standard.taniguchi(rival: false, kind: .femaleMale).hairStyle, .short)
        XCTAssertEqual(StageOutfit.hakama.taniguchi(rival: false, kind: .maleFemale).hairStyle, .bun)
        for o in StageOutfit.allCases { XCTAssertEqual(o.ore(rival: false, kind: .maleMale).body.count, 2) }
    }
}
