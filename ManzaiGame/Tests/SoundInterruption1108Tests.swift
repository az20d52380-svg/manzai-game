import XCTest
import AVFoundation
@testable import ManzaiGame

/// 割り込みの後に BGM を戻すかどうかの判定（code_review_1108b #1）。実際の鳴り方は実機でしか確かめられない。
final class SoundInterruption1108Tests: XCTestCase {
    private func info(_ type: AVAudioSession.InterruptionType, options: AVAudioSession.InterruptionOptions?) -> [AnyHashable: Any] {
        var d: [AnyHashable: Any] = [AVAudioSessionInterruptionTypeKey: type.rawValue]
        if let options { d[AVAudioSessionInterruptionOptionKey] = options.rawValue }
        return d
    }

    func testResumesOnlyWhenEndedWithShouldResume() {
        XCTAssertTrue(SoundEngine.shouldResumeAfterInterruption(info(.ended, options: .shouldResume)))
        XCTAssertFalse(SoundEngine.shouldResumeAfterInterruption(info(.ended, options: [])))
        XCTAssertFalse(SoundEngine.shouldResumeAfterInterruption(info(.ended, options: nil)))
        XCTAssertFalse(SoundEngine.shouldResumeAfterInterruption(info(.began, options: nil)))
        XCTAssertFalse(SoundEngine.shouldResumeAfterInterruption(nil))
    }
}
