import AppKit
import XCTest
@testable import PasteRouting

final class EventMappingTests: XCTestCase {
    func testNativeEventBecomesActualControlVWithoutPostingAnything() {
        let event = CGEvent(keyboardEventSource: CGEventSource(stateID: .privateState), virtualKey: 9, keyDown: true)!
        event.flags = [.maskCommand, .maskAlphaShift]
        XCTAssertEqual(EventMapping.modifiers(event), .command)
        EventMapping.controlV(event)
        XCTAssertEqual(EventMapping.modifiers(event), .control)
        XCTAssertTrue(event.flags.contains(.maskAlphaShift))
        XCTAssertEqual(NSEvent(cgEvent: event)?.characters, "\u{16}")
        XCTAssertEqual(event.getIntegerValueField(.keyboardEventKeycode), 9)
    }

    func testFunctionModifiedPasteIsNotPlainCommandV() {
        let event = CGEvent(keyboardEventSource: CGEventSource(stateID: .privateState), virtualKey: 9, keyDown: true)!
        event.flags = [.maskCommand, .maskSecondaryFn]
        XCTAssertNotEqual(EventMapping.modifiers(event), .command)
    }
}
