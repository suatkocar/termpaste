import Foundation

public struct KeyModifiers: OptionSet, Equatable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let command = Self(rawValue: 1)
    public static let control = Self(rawValue: 2)
    public static let option = Self(rawValue: 4)
    public static let shift = Self(rawValue: 8)
    public static let function = Self(rawValue: 16)
}

public enum ClipboardKind { case none, nativeImage }
public enum KeyPhase { case down, up }
public enum KeyAction: Equatable { case forward, controlV, consume }

public final class KeyRouter {
    private var remappedKey: UInt16?
    public init() {}
    public func handle(phase: KeyPhase, keyCode: UInt16, modifiers: KeyModifiers,
                       isRepeat: Bool = false, ownEvent: Bool = false,
                       eligible: Bool, clipboard: ClipboardKind) -> KeyAction {
        guard !ownEvent else { return .forward }
        if phase == .up {
            guard remappedKey == keyCode else { return .forward }
            remappedKey = nil
            return .controlV
        }
        if isRepeat && remappedKey == keyCode && (!eligible || clipboard != .nativeImage) {
            return .consume
        }
        guard keyCode == 9, modifiers == .command, eligible, clipboard == .nativeImage else {
            if !isRepeat && remappedKey == keyCode { remappedKey = nil }
            return .forward
        }
        remappedKey = keyCode
        return .controlV
    }
}
