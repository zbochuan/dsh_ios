import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum DSHTheme {
    // Neutral canvas. Blue marks running work and tappable text only; amber means "needs you".
    static let background = adaptive(light: 0xFFFFFF, dark: 0x151517)
    static let surface = adaptive(light: 0xF4F5F7, dark: 0x202022)
    static let bubble = adaptive(light: 0xF1F2F4, dark: 0x2B2C2F)
    static let separator = adaptive(light: 0xE3E4E8, dark: 0x3C3D40)
    static let ink = adaptive(light: 0x1B1C1F, dark: 0xF4F4F5)
    static let secondary = adaptive(light: 0x6B6E76, dark: 0xA9ABB2)
    static let blue = adaptive(light: 0x2F5FD0, dark: 0x8FB0FF)
    static let blueTint = adaptive(light: 0xEAF0FD, dark: 0x1E2A45)
    static let action = blue
    static let amber = adaptive(light: 0xD97706, dark: 0xF5A524)
    static let amberText = adaptive(light: 0x9A4A06, dark: 0xF5B860)
    static let amberCard = adaptive(light: 0xFFF7EC, dark: 0x2E2213)
    static let amberBorder = adaptive(light: 0xF3D9B5, dark: 0x5C4220)
    static let green = adaptive(light: 0x1F9D55, dark: 0x4CC27E)
    static let greenText = adaptive(light: 0x1F7A45, dark: 0x6FD39A)
    static let red = adaptive(light: 0xB42318, dark: 0xFF8A80)
    static let redTint = adaptive(light: 0xFDECEC, dark: 0x3A1715)
    static let neutralTint = adaptive(light: 0xF1F2F4, dark: 0x2B2C2F)
    static let diffAdded = adaptive(light: 0xE8F5EC, dark: 0x16301F)
    static let diffAddedText = adaptive(light: 0x145A32, dark: 0x8FE0AE)
    static let diffRemoved = adaptive(light: 0xFDECEC, dark: 0x3A1715)
    static let diffRemovedText = adaptive(light: 0x8A1C12, dark: 0xFFB4AB)
    static let diffHeader = adaptive(light: 0xF7F8F9, dark: 0x1C1C1F)
    // The terminal stays dark in both modes.
    static let terminal = adaptive(light: 0x16171A, dark: 0x0E0F11)
    static let terminalText = adaptive(light: 0xD7D9DE, dark: 0xD7D9DE)
    static let terminalMuted = adaptive(light: 0x9A9DA5, dark: 0x9A9DA5)
    static let readingWidth: CGFloat = 680

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        func components(_ value: UInt32) -> (Double, Double, Double) {
            (Double((value >> 16) & 255) / 255, Double((value >> 8) & 255) / 255, Double(value & 255) / 255)
        }
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            let (r, g, b) = components(traits.userInterfaceStyle == .dark ? dark : light)
            return UIColor(red: r, green: g, blue: b, alpha: 1)
        })
        #else
        return Color(nsColor: NSColor(name: nil) { appearance in
            let (r, g, b) = components(appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light)
            return NSColor(red: r, green: g, blue: b, alpha: 1)
        })
        #endif
    }
}

struct PressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var scalesOnPress = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed && scalesOnPress && !reduceMotion ? 0.97 : 1)
            // Press immediately; only the release settles, without overshoot.
            .animation(configuration.isPressed || reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 1), value: configuration.isPressed)
            // Keep the target outside the visual transform, including small icons.
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }
}

func copyText(_ text: String) {
    #if canImport(UIKit)
    UIPasteboard.general.string = text
    #elseif canImport(AppKit)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    #endif
}
