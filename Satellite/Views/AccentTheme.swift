import SwiftUI
import UIKit

/// App colour themes. Keep in sync with design/themes.json, which renders the matching icons.
enum AccentTheme: String, CaseIterable, Identifiable {
    case orange, ember, gold, lime, mint, teal, blue, violet, pink, silver

    static let storageKey = "accentTheme"
    static let matchIconKey = "matchAppIcon"

    var id: String { rawValue }

    var name: String { rawValue.capitalized }

    /// The accent, adjusted per appearance: the bright shade on dark backgrounds,
    /// a darker shade on light ones (4.6:1 contrast on white or better).
    var color: Color {
        let dark = hex.base, light = lightHex
        return Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }

    /// Text and icons placed on the accent: black on the bright shade, white on the darker one.
    static var onColor: Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? .black : .white })
    }

    var lightHex: UInt32 {
        switch self {
        case .orange: 0xCD4800
        case .ember: 0xDA372C
        case .gold: 0xA26800
        case .lime: 0x468300
        case .mint: 0x008653
        case .teal: 0x008091
        case .blue: 0x3270E0
        case .violet: 0x845AD9
        case .pink: 0xCD3B7B
        case .silver: 0x71747A
        }
    }
    var top: Color { Color(hex: hex.top) }
    var bottom: Color { Color(hex: hex.bottom) }
    var gradient: LinearGradient {
        LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    /// Satellite's own colour, so it's told apart from Orbit (orange) on the Home Screen.
    static let standard: AccentTheme = .blue

    /// nil means the primary icon (blue).
    var iconName: String? { self == .standard ? nil : "AppIcon-\(rawValue)" }

    var hexValues: (base: UInt32, top: UInt32, bottom: UInt32) { hex }

    private var hex: (base: UInt32, top: UInt32, bottom: UInt32) {
        switch self {
        case .orange: (0xF26A2A, 0xFFB25C, 0xF2551D)
        case .ember: (0xEC4A3C, 0xFF8A6B, 0xD92D2D)
        case .gold: (0xF5B83D, 0xFFE08A, 0xEE9F1A)
        case .lime: (0x8FD14F, 0xD4F27A, 0x5DB82E)
        case .mint: (0x3DD39A, 0x8FF5C8, 0x1FAF7A)
        case .teal: (0x2CC2D4, 0x86ECF0, 0x1497B0)
        case .blue: (0x4D8DFF, 0x9CCBFF, 0x2F6BF0)
        case .violet: (0xA57DFF, 0xD3B5FF, 0x7A4AF0)
        case .pink: (0xFF6AA5, 0xFFA8CB, 0xEE3D82)
        case .silver: (0xD4D7DE, 0xFFFFFF, 0x9EA2AD)
        }
    }

    @MainActor
    func applyIcon(_ match: Bool) {
        let wanted = match ? iconName : nil
        guard UIApplication.shared.supportsAlternateIcons,
              UIApplication.shared.alternateIconName != wanted else { return }
        UIApplication.shared.setAlternateIconName(wanted)
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// System, Light or Dark. Chosen at first launch and in Settings.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "appearance"
    static let chosenKey = "appearanceChosen"

    var id: String { rawValue }
    var name: String { rawValue.capitalized }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: AccentTheme = .standard
}

extension EnvironmentValues {
    var theme: AccentTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

/// The Satellite mark drawn natively, so it takes the current theme colour.
/// Geometry matches design/logo-template.svg on a 1024 grid: Orbit's satellite, sending.
/// The dot and two arcs are the feed symbol, drawn with Orbit's stroke weight and round caps.
struct LogoView: View {
    var theme: AccentTheme
    var showsBackground = true

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / 1024
            ZStack {
                if showsBackground {
                    LinearGradient(colors: [Color(hex: 0x23262D), Color(hex: 0x0C0D10)], startPoint: .top, endPoint: .bottom)
                    RadialGradient(colors: [theme.bottom.opacity(0.22), .clear], center: .center,
                                   startRadius: 0, endRadius: 512 * s)
                }
                Self.mark(scale: s).fill(theme.gradient)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    /// Satellite at (296, 728); arcs of radius 250 and 466 sweep from straight up to straight right.
    static func mark(scale s: CGFloat) -> Path {
        let cx = 296.0, cy = 728.0
        func arc(_ r: Double) -> Path {
            var path = Path()
            let steps = 60
            for i in 0...steps {
                let a = (-90 + 90 * Double(i) / Double(steps)) * .pi / 180
                let point = CGPoint(x: (cx + r * cos(a)) * s, y: (cy + r * sin(a)) * s)
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            return path
        }
        let style = StrokeStyle(lineWidth: 92 * s, lineCap: .round, lineJoin: .round)
        var shape = arc(250).strokedPath(style)
        shape.addPath(arc(466).strokedPath(style))
        shape.addEllipse(in: CGRect(x: (cx - 80) * s, y: (cy - 80) * s, width: 160 * s, height: 160 * s))
        return shape
    }
}
