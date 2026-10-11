import AppKit
import XCTest
@testable import PasteRouting

final class ClipboardProbeTests: XCTestCase {
    private var board: NSPasteboard!
    override func setUp() { board = NSPasteboard(name: .init("termpaste-test-\(UUID().uuidString)")) }
    override func tearDown() { board.releaseGlobally() }

    func testPasteImageWithFileURLIsAnImageAndNothingIsChanged() {
        let item = NSPasteboardItem()
        let data = Data([137, 80, 78, 71])
        item.setData(data, forType: .png)
        item.setString("file:///tmp/test.png", forType: .fileURL)
        item.setData(Data(), forType: .init("com.wiheads.paste"))
        board.writeObjects([item])
        let count = board.changeCount
        XCTAssertEqual(ClipboardProbe.kind(board), .nativeImage)
        XCTAssertEqual(board.changeCount, count)
        XCTAssertEqual(board.data(forType: .png), data)
        XCTAssertEqual(board.string(forType: .fileURL), "file:///tmp/test.png")
    }

    func testTIFFAndJPEGImageRepresentationsAreRecognized() {
        for type in [NSPasteboard.PasteboardType.tiff, .init("public.jpeg"), .init("public.heic")] {
            board.clearContents()
            board.setData(Data([1, 2, 3]), forType: type)
            XCTAssertEqual(ClipboardProbe.kind(board), .nativeImage)
        }
    }

    func testTextAndFileURLAloneAreNotTreatedAsImageData() {
        board.setString("/tmp/test.png", forType: .string)
        XCTAssertEqual(ClipboardProbe.kind(board), .none)
        board.clearContents()
        board.setString("file:///tmp/test.png", forType: .fileURL)
        XCTAssertEqual(ClipboardProbe.kind(board), .none)
    }

    func testMultipleItemsAreNotCollapsedIntoASingleImagePaste() {
        let image = NSPasteboardItem()
        image.setData(Data([1]), forType: .png)
        let text = NSPasteboardItem()
        text.setString("another item", forType: .string)
        board.writeObjects([image, text])
        XCTAssertEqual(ClipboardProbe.kind(board), .none)
    }
}
