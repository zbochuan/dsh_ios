import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum DSHTheme {
    // Blue identifies an available action; reading surfaces stay neutral.
    static let blue = adaptive(light: 0x4176E6, dark: 0x5686FE)
    static let action = adaptive(light: 0x2E60CF, dark: 0x9AB8FF)
    static let background = adaptive(light: 0xFFFFFF, dark: 0x151517)
    static let surface = adaptive(light: 0xF6F6F7, dark: 0x202022)
    static let bubble = adaptive(light: 0xF0F1F3, dark: 0x2B2C2F)
    static let separator = adaptive(light: 0xE1E2E5, dark: 0x3C3D40)
    static let ink = adaptive(light: 0x202124, dark: 0xF4F4F5)
    static let secondary = adaptive(light: 0x696B72, dark: 0xA9ABB2)
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
