import XCTest
@testable import PasteRouting

final class AppListFileTests: XCTestCase {
    private var directory: URL!
    private var url: URL { directory.appendingPathComponent("apps.json") }

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("tip-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testMissingFileIsWrittenWithTheDefaults() throws {
        let file = AppListFile(url: url) { AppList.defaults(superEngineeringEnabled: false) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        file.refresh()
        XCTAssertNil(file.problem)
        XCTAssertEqual(file.list, AppList.defaults(superEngineeringEnabled: false))
        XCTAssertEqual(try AppList.decode(Data(contentsOf: url)), AppList.defaults(superEngineeringEnabled: false))
        XCTAssertFalse(file.refresh(), "An unchanged file is not read again")
    }

    func testHandEditsAreReadWhenTheFileChanges() throws {
        let file = AppListFile(url: url) { AppList.defaults() }
        file.refresh()
        try Data(#"{"version":1,"apps":[{"bundleID":"dev.zed.Zed","name":"Zed"}]}"#.utf8).write(to: url)
        XCTAssertTrue(file.refresh())
        XCTAssertEqual(file.list.apps.map(\.name), ["Zed"])
    }

    func testUnreadableFileKeepsTheLastListAndIsCopiedBeforeASave() throws {
        let file = AppListFile(url: url) { AppList.defaults() }
        file.refresh()
        let broken = Data(#"{"apps":[{"bundleID":"dev.zed.Zed","scope":"window"}]}"#.utf8)
        try broken.write(to: url)
        XCTAssertTrue(file.refresh())
        XCTAssertEqual(file.list, AppList.defaults(), "The last list that could be read stays in use")
        XCTAssertEqual(file.problem, "apps.json can’t be read: “scope” has an unknown value")
        XCTAssertEqual(try Data(contentsOf: url), broken, "Reading never rewrites the file")

        var edited = file.list
        edited.remove("com.apple.Terminal")
        try file.save(edited)
        XCTAssertNil(file.problem)
        XCTAssertEqual(try Data(contentsOf: file.unreadableCopyURL), broken)
        XCTAssertEqual(try AppList.decode(Data(contentsOf: url)), edited)
    }

    func testReasonsNameTheProblem() {
        func reason(_ json: String) -> String {
            do { _ = try AppList.decode(Data(json.utf8)); return "read" } catch { return AppListFile.reason(error) }
        }
        XCTAssertEqual(reason(#"{"apps":"#), "it isn’t valid JSON")
        XCTAssertEqual(reason(#"{"apps":[{"name":"No ID"}]}"#), "“bundleID” is missing")
        XCTAssertEqual(reason(#"{"apps":[{"bundleID":"a.b","enabled":"yes"}]}"#), "“enabled” has the wrong type")
        XCTAssertEqual(reason(#"{"apps":[{"bundleID":"a.b"},{"bundleID":"a.b"}]}"#), "it lists a.b twice")
    }
}
