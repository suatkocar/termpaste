import XCTest
@testable import PasteRouting

final class FocusPolicyTests: XCTestCase {
    private let orca = AppRule.defaultInputLabel

    func testOnlyTheFocusedTerminalInputIsEligible() {
        XCTAssertTrue(FocusPolicy.isTerminalInput(role: "AXTextField", labels: ["Terminal input"], label: orca))
        XCTAssertTrue(FocusPolicy.isTerminalInput(role: "AXTextArea", labels: ["", "Terminal input"], label: orca))
    }

    func testOtherControlsAndMissingAccessibilityDoNotMatch() {
        XCTAssertFalse(FocusPolicy.isTerminalInput(role: "AXTextField", labels: ["Search"], label: orca))
        XCTAssertFalse(FocusPolicy.isTerminalInput(role: "AXTextField", labels: ["Message"], label: orca))
        XCTAssertFalse(FocusPolicy.isTerminalInput(role: "AXTextField", labels: ["Terminal input settings"], label: orca))
        XCTAssertFalse(FocusPolicy.isTerminalInput(role: "AXWindow", labels: ["Terminal input"], label: orca))
        XCTAssertFalse(FocusPolicy.isTerminalInput(role: nil, labels: [], label: orca))
    }

    func testAnAppCanNameItsOwnTerminalField() {
        XCTAssertTrue(FocusPolicy.isTerminalInput(role: "AXTextArea", labels: ["Shell"], label: "Shell"))
        XCTAssertFalse(FocusPolicy.isTerminalInput(role: "AXTextArea", labels: ["Terminal input"], label: "Shell"))
    }
}
