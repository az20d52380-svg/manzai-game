import XCTest
import GameCore
@testable import ManzaiGame

/// 【候補 C-24 案②】受けると体力0になるオファーの札にだけ「体力0になる」を出す（offer_low_stamina_measure_1108_v0）
final class OfferStaminaNote1109Tests: XCTestCase {
    private let roke = GameConfig().offersNamed.first { $0.name == "ロケ" }!   // 体力 −25

    func testDrainsWhenStaminaNotEnough() {
        XCTAssertTrue(WeekMainView.offerDrainsStamina(stamina: 20, offer: roke))
        XCTAssertTrue(WeekMainView.offerDrainsStamina(stamina: 25, offer: roke))   // ちょうど0
        XCTAssertFalse(WeekMainView.offerDrainsStamina(stamina: 26, offer: roke))
    }

    func testAllOffersAtFullStaminaShowNothing() {
        for o in GameConfig().offersNamed { XCTAssertFalse(WeekMainView.offerDrainsStamina(stamina: 100, offer: o), o.name) }
    }
}
