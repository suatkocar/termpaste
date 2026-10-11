import AppKit

/// The menu's first row: a coloured dot with the state, then what it means.
final class StatusHeaderView: NSView {
    enum Tone { case on, paused, warning, failure }

    static let minimumWidth: CGFloat = 320
    private let inset: CGFloat = 14
    private let dot = NSView()
    private let title = NSTextField(labelWithString: "")
    private var lines: [NSTextField] = []

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Self.minimumWidth, height: 60))
        autoresizingMask = [.width]
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 4
        title.font = .boldSystemFont(ofSize: 13)
        title.lineBreakMode = .byTruncatingTail
        addSubview(dot)
        addSubview(title)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isFlipped: Bool { true }

    /// `warning` lines are drawn in orange after the others.
    func update(tone: Tone, title text: String, lines texts: [String], warnings: [String] = []) {
        title.stringValue = text
        setAccessibilityLabel(([text] + texts + warnings).joined(separator: ". "))
        for line in lines { line.removeFromSuperview() }
        lines = (texts.map { ($0, false) } + warnings.map { ($0, true) }).map { text, warning in
            let line = NSTextField(wrappingLabelWithString: text)
            line.font = .systemFont(ofSize: 11.5)
            line.textColor = warning ? .systemOrange : .secondaryLabelColor
            addSubview(line)
            return line
        }
        let color: NSColor = switch tone {
        case .on: .systemGreen
        case .paused: .tertiaryLabelColor
        case .warning: .systemOrange
        case .failure: .systemRed
        }
        effectiveAppearance.performAsCurrentDrawingAppearance {
            dot.layer?.backgroundColor = color.cgColor
        }
        let width = max(frame.width, Self.minimumWidth)
        setFrameSize(NSSize(width: width, height: height(forWidth: width)))
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let inner = bounds.width - inset * 2
        var y: CGFloat = 5
        let titleHeight = title.intrinsicContentSize.height
        dot.frame = NSRect(x: inset, y: y + (titleHeight - 8) / 2, width: 8, height: 8)
        title.frame = NSRect(x: inset + 14, y: y, width: inner - 14, height: titleHeight)
        y += titleHeight + 2
        for line in lines {
            let lineHeight = height(of: line, width: inner)
            line.frame = NSRect(x: inset, y: y, width: inner, height: lineHeight)
            y += lineHeight + 1
        }
    }

    private func height(forWidth width: CGFloat) -> CGFloat {
        let inner = width - inset * 2
        return 5 + title.intrinsicContentSize.height + 2 + lines.reduce(0) { $0 + height(of: $1, width: inner) + 1 } + 6
    }

    private func height(of line: NSTextField, width: CGFloat) -> CGFloat {
        line.preferredMaxLayoutWidth = width
        return ceil(line.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: width, height: 1000)).height ?? 15)
    }
}
