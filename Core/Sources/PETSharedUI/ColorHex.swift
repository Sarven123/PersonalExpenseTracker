import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public extension Color {
    init(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized.removeAll { $0 == "#" }
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)
        let red: Double
        let green: Double
        let blue: Double
        if sanitized.count == 6 {
            red = Double((value & 0xFF0000) >> 16) / 255
            green = Double((value & 0x00FF00) >> 8) / 255
            blue = Double(value & 0x0000FF) / 255
        } else {
            red = 0.6
            green = 0.6
            blue = 0.6
        }
        self.init(red: red, green: green, blue: blue)
    }

    func toHex() -> String {
        #if canImport(AppKit)
        let native = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor(self)
        let red = Int((native.redComponent * 255).rounded())
        let green = Int((native.greenComponent * 255).rounded())
        let blue = Int((native.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
        #elseif canImport(UIKit)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
        #else
        return "#9CA3AF"
        #endif
    }
}
