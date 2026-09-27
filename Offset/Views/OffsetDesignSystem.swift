import SwiftUI

enum OffsetTheme {
    static let navy = Color(hex: 0x12345B)
    static let navyDeep = Color(hex: 0x092342)
    static let inverseSurface = Color(hex: 0x092342)
    static let emerald = Color(hex: 0x155EEF)
    static let emeraldBright = Color(hex: 0xFFC83D)
    static let gold = Color(hex: 0xB8860B)
    static let text = Color(hex: 0x172B3A)
    static let secondaryText = Color(hex: 0x536474)
    static let mutedText = Color(hex: 0x758391)
    static let canvas = Color(hex: 0xF7F5F0)
    static let surfaceLow = Color(hex: 0xFAFAF8)
    static let surface = Color(hex: 0xFFFFFF)
    static let surfaceHigh = Color(hex: 0xEDF3FF)
    static let outline = Color(hex: 0xDDE2E7)
    static let divider = Color(hex: 0xE8EBEE)
    static let success = Color(hex: 0x157347)
    static let warning = Color(hex: 0x9A6700)
    static let error = Color(hex: 0xB42318)
    static let savingsTint = Color(hex: 0xFFF3C4)

    static let cardRadius: CGFloat = 18
    static let imageRadius: CGFloat = 15
    static let cardPadding: CGFloat = 18
    static let screenMargin: CGFloat = 20
    static let sectionSpacing: CGFloat = 28
}

struct OffsetLogoMark: View {
    var size: CGFloat = 36

    var body: some View {
        Image("OffsetLogo")
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
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
            .background(OffsetTheme.surface, in: RoundedRectangle(cornerRadius: OffsetTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OffsetTheme.cardRadius, style: .continuous)
                    .stroke(OffsetTheme.outline.opacity(elevated ? 0.72 : 0.5), lineWidth: 1)
            }
            .shadow(color: OffsetTheme.navyDeep.opacity(elevated ? 0.09 : 0.035), radius: elevated ? 18 : 8, y: elevated ? 8 : 3)
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

struct OffsetCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content.offsetCard(padding: OffsetTheme.cardPadding)
    }
}

struct OffsetSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(OffsetTheme.text)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(OffsetTheme.secondaryText)
                }
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
            }
        }
    }
}

struct ProgramSourceBadge: View {
    let level: ProgramLevel

    var body: some View {
        Text(level.shortDisplayName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(OffsetTheme.navy)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(OffsetTheme.surfaceHigh, in: Capsule())
    }
}

struct CoverageBadge: View {
    let assessment: CoverageAssessment

    var body: some View {
        Label(assessment.title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(color.opacity(0.1), in: Capsule())
            .accessibilityLabel("Coverage: \(assessment.title)")
    }

    private var icon: String {
        switch assessment.confidence {
        case .verified: "checkmark.shield.fill"
        case .verifiedDynamic: "clock.badge.checkmark"
        case .partial: "circle.lefthalf.filled"
        case .discovery: "magnifyingglass"
        case .unsupported: "questionmark.circle"
        }
    }

    private var color: Color {
        switch assessment.confidence {
        case .verified: OffsetTheme.success
        case .verifiedDynamic, .partial: OffsetTheme.warning
        case .discovery, .unsupported: OffsetTheme.secondaryText
        }
    }
}

extension ProgramLevel {
    var shortDisplayName: String {
        switch self {
        case .federal: "Federal"
        case .state: "State"
        case .utility: "Utility"
        case .regional: "Regional"
        case .local: "Local"
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
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
