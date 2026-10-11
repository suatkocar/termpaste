import AppKit

/// The menu bar picture: a terminal window holding a picture, the same drawing as the app icon.
/// Paused dims it; a dot marks a state that stops image paste (red: no Accessibility, orange: Secure Input).
/// Drawn with the button's appearance so it reads on light and dark menu bars.
enum StatusGlyph {
    enum Tone: Equatable { case on, paused, needsAccessibility, secureInput }

    static func image(_ tone: Tone, appearance: NSAppearance) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            appearance.performAsCurrentDrawingAppearance {
                let ink = tone == .paused ? NSColor.labelColor.withAlphaComponent(0.45) : NSColor.labelColor
                ink.setStroke()
                let frame = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 3, width: 15, height: 12), xRadius: 2.6, yRadius: 2.6)
                frame.lineWidth = 1.4
                frame.stroke()
                let prompt = NSBezierPath()
                prompt.move(to: NSPoint(x: 4.4, y: 7))
                prompt.line(to: NSPoint(x: 6.5, y: 8.7))
                prompt.line(to: NSPoint(x: 4.4, y: 10.4))
                prompt.lineWidth = 1.35
                prompt.lineCapStyle = .round
                prompt.lineJoinStyle = .round
                prompt.stroke()
                let picture = NSBezierPath()
                picture.move(to: NSPoint(x: 8.8, y: 13.2))
                picture.line(to: NSPoint(x: 11.1, y: 10.5))
                picture.line(to: NSPoint(x: 12.6, y: 12))
                picture.line(to: NSPoint(x: 13.7, y: 11))
                picture.line(to: NSPoint(x: 15.3, y: 13.2))
                picture.lineWidth = 1.2
                picture.lineCapStyle = .round
                picture.lineJoinStyle = .round
                picture.stroke()

                let dotColor: NSColor? = switch tone {
                case .needsAccessibility: .systemRed
                case .secureInput: .systemOrange
                case .on, .paused: nil
                }
                if let dotColor {
                    let center = NSPoint(x: 15, y: 14.2)
                    NSGraphicsContext.current?.compositingOperation = .clear
                    NSBezierPath(ovalIn: NSRect(x: center.x - 4.3, y: center.y - 4.3, width: 8.6, height: 8.6)).fill()
                    NSGraphicsContext.current?.compositingOperation = .sourceOver
                    dotColor.setFill()
                    NSBezierPath(ovalIn: NSRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)).fill()
                }
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}
