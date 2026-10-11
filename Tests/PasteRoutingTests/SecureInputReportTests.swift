import XCTest
@testable import PasteRouting

final class SecureInputReportTests: XCTestCase {
    func testOwnerPIDComesFromTheConsoleSession() {
        XCTAssertNil(SecureInputReport.ownerPID(in: []))
        XCTAssertNil(SecureInputReport.ownerPID(in: [["kCGSSessionUserIDKey": 501]]), "The key is absent while Secure Input is off")
        XCTAssertNil(SecureInputReport.ownerPID(in: [["kCGSSessionSecureInputPID": 0]]))
        XCTAssertEqual(SecureInputReport.ownerPID(in: [["kCGSSessionUserIDKey": 501],
                                                       ["kCGSSessionSecureInputPID": NSNumber(value: 812)]]), 812)
    }

    func testLinesSayWhichAppMacOSNamesAndWhatUsuallyEndsIt() {
        let listed: Set = ["com.mitchellh.ghostty"]
        let ghostty = SecureInputOwner(pid: 10, name: "Ghostty", bundleID: "com.mitchellh.ghostty", isRunning: true)
        XCTAssertEqual(SecureInputReport.lines(owner: ghostty, frontmostPID: 10, listedBundleIDs: listed),
                       ["macOS names Ghostty, the app in front.",
                        "If it lasts, turn off Secure Keyboard Entry in Ghostty, or quit password apps."])

        let browser = SecureInputOwner(pid: 20, name: "Safari", bundleID: "com.apple.Safari", isRunning: true)
        XCTAssertEqual(SecureInputReport.lines(owner: browser, frontmostPID: 20, listedBundleIDs: listed)[1],
                       "Usually a focused password field; if it lasts, quit password apps.")
        XCTAssertEqual(SecureInputReport.lines(owner: browser, frontmostPID: 10, listedBundleIDs: listed)[1],
                       "Finish its password prompt or quit it; if it lasts, lock and unlock your Mac.")

        let login = SecureInputOwner(pid: 30, name: "loginwindow", bundleID: "com.apple.loginwindow", isRunning: true)
        XCTAssertEqual(SecureInputReport.lines(owner: login, frontmostPID: 10, listedBundleIDs: listed)[0], "macOS names loginwindow.")

        let gone = SecureInputOwner(pid: 40, name: nil, bundleID: nil, isRunning: false)
        XCTAssertEqual(SecureInputReport.lines(owner: gone, frontmostPID: 10, listedBundleIDs: listed)[0],
                       "The process macOS names (pid 40) has quit.")
        XCTAssertEqual(SecureInputReport.lines(owner: nil, frontmostPID: 10, listedBundleIDs: listed)[0],
                       "macOS doesn’t name the app that turned it on.")
    }
}
