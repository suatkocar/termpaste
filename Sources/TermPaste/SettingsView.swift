import AppKit
import PasteRouting
import SwiftUI

struct SettingsView: View {
    let state: AppState
    let navigation: SettingsNavigation

    var body: some View {
        // A switch rather than a TabView, so SwiftUI draws no tab bar of its own under the toolbar.
        Group {
            switch navigation.tab {
            case .general: GeneralPane(state: state)
            case .apps: AppsPane(state: state)
            case .diagnostics: DiagnosticsPane(state: state)
            }
        }
        .frame(width: 660, height: 440)
    }
}

private struct GeneralPane: View {
    let state: AppState

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: { !state.paused }, set: { state.setPaused(!$0) })) {
                    Text("Image paste")
                    Text("Turn ⌘V into Ctrl+V in the apps on the Apps tab while the clipboard holds an image.")
                }
                Toggle(isOn: Binding(get: { state.launchAtLogin }, set: { state.setLaunchAtLogin($0) })) {
                    Text("Launch at login")
                    Text("Starts TermPaste when you log in.")
                }
            }
            Section {
                LabeledContent("Apps list") {
                    Button("Show apps.json in Finder", action: state.revealAppsFile)
                }
                LabeledContent("Version", value: AppIdentity.version)
            }
        }
        .formStyle(.grouped)
    }
}

private struct AppsPane: View {
    let state: AppState
    @State private var confirmRestore = false
    @State private var addError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("⌘V becomes Ctrl+V in these apps while the clipboard holds an image. Changes apply at once.")
                .foregroundStyle(.secondary)
            if let problem = state.fileProblem {
                Label("\(problem). The last list that could be read stays in use.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            Table(state.apps) {
                TableColumn("On") { rule in
                    Toggle("\(rule.name) enabled", isOn: Binding(get: { rule.enabled }, set: { state.setEnabled(rule.bundleID, $0) }))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                }
                .width(28)
                TableColumn("App") { rule in AppCell(rule: rule) }
                TableColumn("Where") { rule in
                    Picker("Where \(rule.name) routes", selection: Binding(get: { rule.scope }, set: { state.setScope(rule.bundleID, $0) })) {
                        Text("Whole app").tag(AppRule.Scope.app)
                        Text("Terminal input only").tag(AppRule.Scope.terminalInput)
                    }
                    .labelsHidden()
                    .help("Terminal input only works where the focused field is named “\(rule.requiredLabel)”, as in Orca.")
                }
                .width(158)
                TableColumn("Status") { rule in StatusPill(status: state.status(for: rule)) }
                    .width(96)
                TableColumn("") { rule in
                    Button {
                        state.remove(rule.bundleID)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove \(rule.name)")
                    .accessibilityLabel("Remove \(rule.name)")
                }
                .width(22)
            }
            .overlay {
                if state.apps.isEmpty {
                    Text("No apps. Add one, or restore the defaults.").foregroundStyle(.secondary)
                }
            }
            HStack {
                Button("Add App…", action: chooseApp)
                if let candidate = state.quickAddCandidate {
                    Button("Add “\(candidate.name)”", action: state.addPrevious)
                        .help("The app you used last before this one.")
                }
                Spacer()
                Button("Restore Defaults…") { confirmRestore = true }
            }
            HStack(spacing: 4) {
                Text("Saved in \(state.appsFileURL.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))")
                    .textSelection(.enabled)
                Button("Show in Finder", action: state.revealAppsFile)
                    .buttonStyle(.link)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .alert("Restore the default apps?", isPresented: $confirmRestore) {
            Button("Restore Defaults", role: .destructive, action: state.restoreDefaults)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The list goes back to Ghostty, Orca, super.engineering, iTerm, Warp and Terminal. Apps you added are removed.")
        }
        .alert("Not added", isPresented: Binding(get: { addError != nil }, set: { if !$0 { addError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(addError ?? "")
        }
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "Choose an app. While the clipboard holds an image, ⌘V becomes Ctrl+V in it."
        panel.prompt = "Add"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        addError = state.addApp(at: url)
    }
}

private struct AppCell: View {
    let rule: AppRule

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: AppIdentity.icon(for: rule.bundleID, size: 22))
            VStack(alignment: .leading, spacing: 1) {
                Text(rule.name)
                Text(rule.bundleID)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct StatusPill: View {
    let status: AppStatus

    var body: some View {
        Text(status.text)
            .font(.caption)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(0.14), in: .capsule)
    }

    private var color: Color {
        switch status {
        case .connected: .green
        case .cannotAttach, .filePathUnavailable: .orange
        case .off, .notRunning, .waiting: .secondary
        }
    }
}

private struct DiagnosticsPane: View {
    let state: AppState
    @State private var copied = false

    var body: some View {
        Form {
            Section {
                ForEach(rows, id: \.0) { row in
                    LabeledContent(row.0) { Text(row.1).textSelection(.enabled).multilineTextAlignment(.trailing) }
                }
            }
            Section {
                HStack {
                    Button("Open Accessibility Settings…", action: state.openAccessibilitySettings)
                    Button("Show status.json in Finder", action: state.revealStatusFile)
                    Spacer()
                    Button(copied ? "Copied" : "Copy Diagnostics", action: copy)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var rows: [(String, String)] {
        [
            ("Accessibility", state.trusted ? "Allowed" : "Not allowed"),
            ("Secure Input", state.secureInput ? "On. " + state.secureInputLines.joined(separator: " ") : "Off"),
            ("Image paste", state.paused ? "Paused" : "On"),
            ("Connected", state.connectedNames.isEmpty ? "None" : state.connectedNames.joined(separator: ", ")),
            ("Last ⌘V", state.lastDecision ?? "None since launch"),
            ("Pastes", state.pasteSummary()),
            ("apps.json", state.fileProblem ?? "Read"),
            ("Signature", AppIdentity.signature),
            ("Version", AppIdentity.version),
        ]
    }

    /// Names states and apps only: no clipboard contents, typed text or file paths.
    private func copy() {
        let text = (["TermPaste diagnostics"] + rows.map { "\($0.0): \($0.1)" }).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copied = true
    }
}
