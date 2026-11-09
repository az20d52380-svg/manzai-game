import XCTest
@testable import ManzaiGame

final class FirstPassShare1108Tests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let name = "FirstPassShare1108.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    func testOffersOnlyOnce() {
        let d = freshDefaults()
        XCTAssertTrue(FirstPassShare.shouldOffer(d))
        FirstPassShare.markOffered(d)
        XCTAssertFalse(FirstPassShare.shouldOffer(d))
    }

    func testCardTextHasNoPercentAndNoJoke() {
        let all = FirstPassShare.headline + FirstPassShare.detail(roundName: "GP1回戦", year: 1)
        XCTAssertFalse(all.contains("%"))
        XCTAssertFalse(all.contains("％"))
        XCTAssertEqual(FirstPassShare.detail(roundName: "GP1回戦", year: 2), "GP1回戦　結成2年目")
    }
}
