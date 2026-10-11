import XCTest
@testable import PasteRouting

final class KeyRoutingTests: XCTestCase {
    func testNativeImageConvertsCommandVAndItsKeyUp() {
        let router = KeyRouter()
        XCTAssertEqual(router.handle(phase: .down, keyCode: 9, modifiers: .command, eligible: true, clipboard: .nativeImage), .controlV)
        XCTAssertEqual(router.handle(phase: .up, keyCode: 9, modifiers: [], eligible: true, clipboard: .none), .controlV)
        XCTAssertEqual(router.handle(phase: .up, keyCode: 9, modifiers: .command, eligible: true, clipboard: .nativeImage), .forward)
    }

    func testTextAndOtherApplicationsKeepTheirNormalPaste() {
        let router = KeyRouter()
        XCTAssertEqual(router.handle(phase: .down, keyCode: 9, modifiers: .command, eligible: true, clipboard: .none), .forward)
        XCTAssertEqual(router.handle(phase: .down, keyCode: 9, modifiers: .command, eligible: false, clipboard: .nativeImage), .forward)
    }

    func testControlVAndModifiedPasteCommandsAreNotIntercepted() {
        let router = KeyRouter()
        for modifiers: KeyModifiers in [.control, [.command, .shift], [.command, .option], [.command, .control], []] {
            XCTAssertEqual(router.handle(phase: .down, keyCode: 9, modifiers: modifiers, eligible: true, clipboard: .nativeImage), .forward)
        }
        XCTAssertEqual(router.handle(phase: .down, keyCode: 8, modifiers: .command, eligible: true, clipboard: .nativeImage), .forward)
    }

    func testOurSyntheticEventsNeverTriggerAnotherPaste() {
        let router = KeyRouter()
        XCTAssertEqual(router.handle(phase: .down, keyCode: 9, modifiers: .command, ownEvent: true, eligible: true, clipboard: .nativeImage), .forward)
    }

    func testNativeRepeatStillRequiresCurrentEligibilityAndImage() {
        let router = KeyRouter()
        XCTAssertEqual(router.handle(phase: .down, keyCode: 9, modifiers: .command, eligible: true, clipboard: .nativeImage), .controlV)
        XCTAssertEqual(router.handle(phase: .down, keyCode: 9, modifiers: .command, isRepeat: true, eligible: true, clipboard: .nativeImage), .controlV)
        XCTAssertEqual(router.handle(phase: .down, keyCode: 9, modifiers: .command, isRepeat: true, eligible: false, clipboard: .nativeImage), .consume)
    }

}
