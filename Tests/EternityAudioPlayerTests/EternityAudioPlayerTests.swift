import XCTest
@testable import EternityAudioPlayer

final class EternityAudioPlayerTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(AudioPlayer().mode, PlayerMode.sectionBased)
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
