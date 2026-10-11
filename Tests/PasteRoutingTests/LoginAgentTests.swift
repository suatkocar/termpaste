import XCTest
@testable import PasteRouting

final class LoginAgentTests: XCTestCase {
    func testAgentStartsTheInstalledHelperOnceAtLogin() throws {
        let executable = "/Users/someone/Applications/TermPaste.app/Contents/MacOS/TermPaste"
        let data = try LoginAgent.propertyList(executablePath: executable, bundleIdentifier: "com.suatkocar.termpaste")
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(plist["Label"] as? String, "com.suatkocar.termpaste")
        XCTAssertEqual(plist["ProgramArguments"] as? [String], [executable])
        XCTAssertEqual(plist["AssociatedBundleIdentifiers"] as? [String], ["com.suatkocar.termpaste"])
        XCTAssertEqual(plist["RunAtLoad"] as? Bool, true)
        XCTAssertNil(plist["KeepAlive"], "Quitting from the menu must not relaunch the helper")
        XCTAssertEqual(LoginAgent.url(home: URL(fileURLWithPath: "/Users/someone")).path,
                       "/Users/someone/Library/LaunchAgents/com.suatkocar.termpaste.plist")
    }

    func testOnlyInstalledCopiesRegisterThemselves() {
        let home = URL(fileURLWithPath: "/Users/someone")
        XCTAssertTrue(LoginAgent.isInstalledLocation("/Users/someone/Applications/TermPaste.app", home: home))
        XCTAssertTrue(LoginAgent.isInstalledLocation("/Applications/TermPaste.app", home: home))
        XCTAssertFalse(LoginAgent.isInstalledLocation("/Users/someone/repo/dist/TermPaste.app", home: home))
        XCTAssertFalse(LoginAgent.isInstalledLocation("/Users/someone/repo/.build/release/TermPaste", home: home))
        XCTAssertFalse(LoginAgent.isInstalledLocation("/Users/someone/ApplicationsOld/TermPaste.app", home: home))
    }
}
