import SwiftUI

struct CardHeader: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
            Text(value).font(.subheadline.monospacedDigit())
        }
    }
}

/// Secondary detail line under a card header.
struct DetailText: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
    }
}

let dash = "—"
