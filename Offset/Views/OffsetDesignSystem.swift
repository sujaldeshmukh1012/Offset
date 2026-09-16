import SwiftUI

enum OffsetTheme {
    static let navy = Color(light: 0x12345B, dark: 0xB8D4FF)
    static let navyDeep = Color(light: 0x092342, dark: 0xE6EEFF)
    static let emerald = Color(light: 0x155EEF, dark: 0x7CABFF)
    static let emeraldBright = Color(light: 0xFFC83D, dark: 0xFFD66B)
    static let text = Color(light: 0x172B3A, dark: 0xF1F5F9)
    static let secondaryText = Color(light: 0x536474, dark: 0xB7C4D1)
    static let canvas = Color(light: 0xF5F7FA, dark: 0x0B1320)
    static let surfaceLow = Color(light: 0xF8FAFC, dark: 0x101B2B)
    static let surface = Color(light: 0xFFFFFF, dark: 0x162235)
    static let surfaceHigh = Color(light: 0xEAF1FF, dark: 0x223654)
    static let outline = Color(light: 0xD5DDE7, dark: 0x41516A)
    static let error = Color(light: 0xB42318, dark: 0xFF8A80)
    static let savingsTint = Color(light: 0xFFF4C2, dark: 0x493B13)
}

struct OffsetLogoMark: View {
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(OffsetTheme.emerald)
            Capsule()
                .fill(Color.white.opacity(0.28))
                .frame(width: size * 0.56, height: size * 0.14)
                .offset(y: -size * 0.16)
            Image(systemName: "arrow.down")
                .font(.system(size: size * 0.25, weight: .bold))
                .foregroundStyle(Color.white)
                .offset(y: size * 0.02)
            Capsule()
                .fill(OffsetTheme.emeraldBright)
                .frame(width: size * 0.44, height: size * 0.14)
                .offset(y: size * 0.27)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct OffsetBrandHeader: View {
    var badgeText: String? = "VERIFIED PROGRAM DATA"

    var body: some View {
        HStack(spacing: 10) {
            OffsetLogoMark(size: 34)
            Text("Offset")
                .font(.headline.weight(.bold))
                .foregroundStyle(OffsetTheme.text)
            Spacer()
            if let badgeText {
                Label(badgeText, systemImage: "checkmark.shield.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(OffsetTheme.navy)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(OffsetTheme.savingsTint, in: Capsule())
                    .lineLimit(1)
            }
        }
    }
}

struct OffsetEyebrow: View {
    let text: String

    var body: some View {
        Text(displayText)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(OffsetTheme.emerald)
    }

    private var displayText: String {
        guard text == text.uppercased() else { return text }
        let lowercase = text.lowercased()
        let sentence = lowercase.prefix(1).uppercased() + lowercase.dropFirst()
        return sentence
            .replacingOccurrences(of: "zip", with: "ZIP")
            .replacingOccurrences(of: "ev", with: "EV")
            .replacingOccurrences(of: "irs", with: "IRS")
    }
}

struct OffsetCardModifier: ViewModifier {
    var padding: CGFloat = 16
    var elevated = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(OffsetTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(OffsetTheme.outline.opacity(elevated ? 1 : 0.72), lineWidth: 1)
            }
    }
}

struct OffsetPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.white.opacity(isEnabled ? 1 : 0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                OffsetTheme.emerald.opacity(isEnabled ? 1 : 0.42),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct OffsetSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(OffsetTheme.navy)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(OffsetTheme.surfaceHigh, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(OffsetTheme.outline, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

extension View {
    func offsetCard(padding: CGFloat = 16, elevated: Bool = false) -> some View {
        modifier(OffsetCardModifier(padding: padding, elevated: elevated))
    }

    func offsetScreen() -> some View {
        foregroundStyle(OffsetTheme.text)
            .background(OffsetTheme.canvas.ignoresSafeArea())
            .tint(OffsetTheme.emerald)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
