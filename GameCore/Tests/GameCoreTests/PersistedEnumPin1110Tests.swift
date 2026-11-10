// PersistedEnumPin1110Tests.swift
// セーブに載る enum の rawValue を 2026-11-10 時点の一覧で固定する（save_compat_audit_1108_v0 §足すべきテストの案 6）。
//  - case を消す・名前を変える → 旧セーブのその値が読めなくなる（または黙って捨てられる）ので赤
//  - case を足すのは許可（一覧に無い新しい値は見ない）
// 改名が必要な時は、読み込み側で旧名を新名に読み替える口を先に作ってから、この一覧を直す。

import XCTest
@testable import GameCore

final class PersistedEnumPin1110Tests: XCTestCase {

    private func pin<E: RawRepresentable>(_ t: E.Type, _ name: String, _ raws: [String],
                                          file: StaticString = #filePath, line: UInt = #line) where E.RawValue == String {
        for r in raws {
            XCTAssertNotNil(E(rawValue: r), "\(name) の保存値「\(r)」が読めなくなった（旧セーブが壊れる）", file: file, line: line)
        }
    }

    func testPersistedRawValuesStillDecode() {
        pin(ChoiceEventKind.self, "ChoiceEventKind", ["justLostRehearsal", "styleTalk", "justPassedFork", "preTournamentEve", "tsuukaBreak", "earlyFormality", "namelessReservationSlip", "taniguchiShortJob", "riftWarning", "weekendInvite", "brokeDrinkingInvite", "senpaiMeishi", "peerFoldedChair", "lineupTop", "greenroomSilentTen", "lastTrainReview", "luckyThirdLine", "regularEmployment", "wroteOneTonight", "photoShootOffer", "kouhaiInvite", "senpaiAllNight", "stageCrewChairs", "writerPostcards", "doukiJointLive", "baitoInventory", "homecomingCall", "regularFanOranges", "officeTicketQuota", "summerFestivalGig", "doukiOnTV", "theaterRenovation", "classmateInAudience", "partnerFever", "lostNotebook", "yearEndLive"])
        pin(Skill.self, "Skill", ["体が資本", "愛され芸人", "やりくり上手", "相方思い"])
        pin(NetaKata.self, "NetaKata", ["王道しゃべくり", "関係性", "伏線回収", "リターン", "非定型", "瞬発", "華先行"])
        pin(NetaLength.self, "NetaLength", ["短尺", "中尺", "長尺"])
        pin(ShopItem.self, "ShopItem", ["栄養ドリンク", "回復ドリンク大", "喉のケア用品", "銭湯の回数券", "中古のICレコーダー", "新幹線回数券", "ネタ作家の勉強会", "ボイトレ短期集中", "稽古場の年契約"])
    }
}
