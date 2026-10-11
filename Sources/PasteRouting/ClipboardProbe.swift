import AppKit
import UniformTypeIdentifiers

public enum ClipboardProbe {
    /// Inspect advertised types only. Never read or rewrite the user's image bytes.
    public static func kind(_ pasteboard: NSPasteboard) -> ClipboardKind {
        guard let items = pasteboard.pasteboardItems, items.count == 1 else { return .none }
        return items[0].types.contains {
            UTType($0.rawValue)?.conforms(to: .image) == true
        } ? .nativeImage : .none
    }
}
