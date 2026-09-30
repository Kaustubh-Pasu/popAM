import SwiftUI

/// Shared look of the terminal-on-glass popover: monospaced ink on the popover material.
enum Term {
    static let ink = Color.primary
    static let dim = Color.primary.opacity(0.5)
    static let faint = Color.primary.opacity(0.18)

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

let dash = "—"

/// Full-width 1 pt divider between sections.
struct Hairline: View {
    var body: some View {
        Rectangle().fill(Term.faint).frame(height: 1).padding(.vertical, 2)
    }
}

/// Dim key on the left, value on the right.
struct TermLine: View {
    let key: String
    let value: String

    init(_ key: String, _ value: String) {
        self.key = key
        self.value = value
    }

    var body: some View {
        HStack {
            Text(key).foregroundStyle(Term.dim)
            Spacer()
            Text(value).foregroundStyle(Term.ink.opacity(0.85))
        }
        .font(Term.mono(10.5))
    }
}

/// Section title, a text block bar, and the headline value.
struct GaugeRow: View {
    let label: String
    /// 0...1, or nil for an empty bar.
    let fraction: Double?
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label).font(Term.mono(12, .bold))
            BlockBar(fraction: fraction ?? 0)
            Spacer()
            Text(value).font(Term.mono(12, .semibold))
        }
        .foregroundStyle(Term.ink)
    }
}
