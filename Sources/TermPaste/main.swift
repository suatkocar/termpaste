import AppKit
import PasteRouting

if CommandLine.arguments.contains("--status") {
    if let data = try? Data(contentsOf: EventRouter.statusURL), let status = String(data: data, encoding: .utf8) { print(status) }
    else { print("{\"running\":false,\"status\":\"not started\"}") }
} else if CommandLine.arguments.contains("--clipboard-types") {
    let board = NSPasteboard.general
    let value: [String: Any] = ["changeCount": board.changeCount,
        "types": (board.pasteboardItems ?? []).map { $0.types.map(\.rawValue) },
        "hasImage": ClipboardProbe.kind(board) == .nativeImage]
    if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .prettyPrinted]) {
        print(String(data: data, encoding: .utf8)!)
    }
} else {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    // `kill` and launchd stop the helper with SIGTERM; quit normally so the taps close and status.json says so.
    signal(SIGTERM, SIG_IGN)
    let termination = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    termination.setEventHandler { NSApp.terminate(nil) }
    termination.resume()
    app.run()
}
