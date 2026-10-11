import ApplicationServices
import PasteRouting

enum TerminalFocus {
    /// Query the focused control's role and static labels only, never AXValue,
    /// selected text, terminal output, window titles, or the entire UI tree.
    static func isTerminalInput(processID: pid_t, label: String) -> Bool {
        let application = AXUIElementCreateApplication(processID)
        AXUIElementSetMessagingTimeout(application, 0.035)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return false }
        let focused = value as! AXUIElement
        AXUIElementSetMessagingTimeout(focused, 0.035)
        let attributes = [kAXRoleAttribute, kAXDescriptionAttribute, kAXTitleAttribute] as CFArray
        var result: CFArray?
        guard AXUIElementCopyMultipleAttributeValues(focused, attributes, [], &result) == .success,
              let values = result as? [Any], values.count == 3 else { return false }
        return FocusPolicy.isTerminalInput(role: values[0] as? String,
                                           labels: values.dropFirst().compactMap { $0 as? String }, label: label)
    }
}
