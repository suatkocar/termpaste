import CoreGraphics

public enum EventMapping {
    public static let marker: Int64 = 0x54495041535445
    public static func modifiers(_ event: CGEvent) -> KeyModifiers {
        var result: KeyModifiers = []
        if event.flags.contains(.maskCommand) { result.insert(.command) }
        if event.flags.contains(.maskControl) { result.insert(.control) }
        if event.flags.contains(.maskAlternate) { result.insert(.option) }
        if event.flags.contains(.maskShift) { result.insert(.shift) }
        if event.flags.contains(.maskSecondaryFn) { result.insert(.function) }
        return result
    }
    public static func controlV(_ event: CGEvent) {
        event.flags.remove(.maskCommand)
        event.flags.insert(.maskControl)
        event.setIntegerValueField(.eventSourceUserData, value: marker)
    }
}
