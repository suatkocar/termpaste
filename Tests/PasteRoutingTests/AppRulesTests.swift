import XCTest
@testable import PasteRouting

final class AppRulesTests: XCTestCase {
    func testDefaultsAreTheListEarlierBuildsCompiledIn() {
        let list = AppList.defaults()
        XCTAssertEqual(list.apps.map(\.bundleID), ["com.mitchellh.ghostty", "com.stablyai.orca", "engineering.super.app",
                                                   "com.googlecode.iterm2", "dev.warp.Warp-Stable", "com.apple.Terminal"])
        XCTAssertTrue(list.apps.allSatisfy { $0.enabled && $0.paste == .image })
        XCTAssertEqual(list.rule(for: "com.stablyai.orca")?.scope, .terminalInput)
        XCTAssertEqual(list.rule(for: "com.stablyai.orca")?.requiredLabel, "Terminal input")
        XCTAssertEqual(list.apps.filter { $0.scope == .terminalInput }.count, 1)
        XCTAssertEqual(AppList.defaults(superEngineeringEnabled: false).rule(for: "engineering.super.app")?.enabled, false)
    }

    func testHandWrittenEntriesNeedOnlyABundleID() throws {
        let list = try AppList.decode(Data(#"{"apps":[{"bundleID":" dev.zed.Zed "}]}"#.utf8))
        XCTAssertEqual(list.version, 1)
        XCTAssertEqual(list.apps, [AppRule(bundleID: "dev.zed.Zed", name: "dev.zed.Zed")])
    }

    func testEncodedListReadsBackUnchanged() throws {
        var list = AppList.defaults()
        list.add(AppRule(bundleID: "dev.zed.Zed", name: "Zed", enabled: false, paste: .path))
        let text = try XCTUnwrap(String(data: list.encoded(), encoding: .utf8))
        XCTAssertTrue(text.hasSuffix("\n"))
        XCTAssertFalse(text.contains("\\/"))
        XCTAssertEqual(try AppList.decode(list.encoded()), list)
    }

    func testFilesThatCannotBeTrustedAreRejected() {
        let cases: [(String, AppList.Problem?)] = [
            (#"{"version":2,"apps":[]}"#, .newerVersion(2)),
            (#"{"apps":[{"bundleID":""}]}"#, .emptyBundleID),
            (#"{"apps":[{"bundleID":"a.b"},{"bundleID":"a.b","name":"Again"}]}"#, .duplicate("a.b")),
            (#"{"apps":[{"bundleID":"a.b","scope":"window"}]}"#, nil),
            (#"{"apps":[{"name":"No ID"}]}"#, nil),
            (#"{"apps":"#, nil),
        ]
        for (json, expected) in cases {
            XCTAssertThrowsError(try AppList.decode(Data(json.utf8)), json) { error in
                if let expected { XCTAssertEqual(error as? AppList.Problem, expected, json) }
            }
        }
    }

    func testAddingRemovingAndChangingRules() {
        var list = AppList(apps: [])
        XCTAssertTrue(list.add(AppRule(bundleID: "dev.zed.Zed", name: "Zed")))
        XCTAssertFalse(list.add(AppRule(bundleID: "dev.zed.Zed", name: "Zed again")), "A bundle ID is listed once")
        XCTAssertFalse(list.add(AppRule(bundleID: "", name: "Nothing")))
        list.update("dev.zed.Zed") { $0.scope = .terminalInput }
        XCTAssertEqual(list.rule(for: "dev.zed.Zed")?.inputLabel, "Terminal input", "A new terminal-input rule gets the default label")
        list.update("dev.zed.Zed") { $0.enabled = false }
        XCTAssertFalse(list.rule(for: "dev.zed.Zed")?.routes ?? true)
        list.remove("dev.zed.Zed")
        XCTAssertTrue(list.apps.isEmpty)
    }

    func testStatusNamesWhyAnAppIsOrIsNotConnected() {
        let rule = AppRule(bundleID: "a.b", name: "A")
        XCTAssertEqual(AppStatus.of(rule, running: true, attached: true, failed: false), .connected)
        XCTAssertEqual(AppStatus.of(rule, running: false, attached: false, failed: false), .notRunning)
        XCTAssertEqual(AppStatus.of(rule, running: true, attached: false, failed: true), .cannotAttach)
        XCTAssertEqual(AppStatus.of(rule, running: true, attached: false, failed: false), .waiting)
        var off = rule
        off.enabled = false
        XCTAssertEqual(AppStatus.of(off, running: true, attached: false, failed: false), .off)
        var path = rule
        path.paste = .path
        XCTAssertEqual(AppStatus.of(path, running: true, attached: false, failed: false), .filePathUnavailable)
        XCTAssertFalse(path.routes, "File path mode is reserved, not routed")
    }
}
