public enum FocusPolicy {
    /// The focused control itself must be a text field or area carrying `label`, as Orca's xterm
    /// labels its input "Terminal input". Finding a terminal elsewhere in the window is not enough.
    public static func isTerminalInput(role: String?, labels: [String], label: String) -> Bool {
        (role == "AXTextField" || role == "AXTextArea") && labels.contains(label)
    }
}
