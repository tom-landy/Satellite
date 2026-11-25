import SafariServices
import SwiftUI

extension Date {
    /// "Today, 09:41", "Yesterday, 18:00", "Monday", "3 Nov".
    var articleDate: String {
        let time = formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(self) { return "Today, \(time)" }
        if Calendar.current.isDateInYesterday(self) { return "Yesterday, \(time)" }
        if self > .now.addingTimeInterval(-6 * 86400) { return formatted(.dateTime.weekday(.wide)) }
        if Calendar.current.isDate(self, equalTo: .now, toGranularity: .year) {
            return formatted(.dateTime.day().month(.abbreviated))
        }
        return formatted(.dateTime.day().month(.abbreviated).year())
    }
}

/// A source's feed icon, or its initial on a colour that's stable per source.
struct SourceIcon: View {
    let source: Source?
    var size: CGFloat = 28

    private var seed: String { source?.host ?? "" }

    private var hue: Double {
        Double(seed.unicodeScalars.reduce(UInt32(7)) { $0 &* 31 &+ $1.value } % 360) / 360
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
        ZStack {
            LinearGradient(colors: [Color(hue: hue, saturation: 0.45, brightness: 0.55),
                                    Color(hue: hue, saturation: 0.6, brightness: 0.3)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(String((source?.title ?? "?").prefix(1)).uppercased())
                .font(.system(size: size * 0.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            if let url = source?.iconURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay { shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5) }
        .accessibilityHidden(true)
    }
}

/// Safari inside the app, for opening an article's web page.
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    @Environment(\.theme) private var theme

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(theme.color)
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

struct IdentifiedURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
