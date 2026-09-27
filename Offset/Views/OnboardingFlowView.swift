import SwiftUI

struct OnboardingFlowView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var model: OnboardingViewModel
    @FocusState private var isZIPFieldFocused: Bool

    init(profile: UserProfile?) {
        let locations = (try? LocationService.current()) ?? .empty
        _model = StateObject(wrappedValue: OnboardingViewModel(profile: profile, locations: locations))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if model.step != .welcome {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Profile setup")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(OffsetTheme.navy)
                            Spacer()
                            Text("\(model.step.rawValue + 1) / \(OnboardingViewModel.Step.allCases.count)")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(OffsetTheme.secondaryText)
                        }
                        GeometryReader { proxy in
                            let availableWidth = proxy.size.width.isFinite ? max(0, proxy.size.width) : 0
                            ZStack(alignment: .leading) {
                                Capsule().fill(OffsetTheme.surfaceHigh)
                                Capsule().fill(OffsetTheme.emerald)
                                    .frame(width: availableWidth * max(0, min(1, CGFloat(model.progress))))
                            }
                        }
                        .frame(height: 5)
                    }
                        .accessibilityLabel("Onboarding progress")
                        .accessibilityValue("Step \(model.step.rawValue + 1) of \(OnboardingViewModel.Step.allCases.count)")
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                }

                ScrollView {
                    stepContent
                        .frame(maxWidth: 620, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 28)
                        .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)

                footer
            }
            .offsetScreen()
            .navigationTitle(model.isEditing ? "Edit profile" : "Set up Offset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if model.isEditing && model.step == .homeStatus {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            appState.finishEditingProfile()
                        }
                    }
                } else if model.step != .welcome {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            move { model.goBack() }
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isZIPFieldFocused = false
                    }
                    .accessibilityIdentifier("onboarding.keyboard-done")
                }
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch model.step {
        case .welcome:
            welcomeStep
        case .homeStatus:
            homeStatusStep
        case .zipCode:
            zipCodeStep
        case .utility:
            utilityStep
        case .projects:
            projectsStep
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            OffsetBrandHeader(badgeText: "Verified sources")

            VStack(alignment: .leading, spacing: 12) {
                Text("Find savings for your next upgrade")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(OffsetTheme.text)
                Text("Tell us where you live and what you’re planning. Offset checks the programs currently available in its verified catalog.")
                    .font(.body)
                    .foregroundStyle(OffsetTheme.secondaryText)
            }

            VStack(alignment: .leading, spacing: 16) {
                BenefitRow(icon: "mappin.and.ellipse", text: "Matches based on your ZIP and utility")
                BenefitRow(icon: "list.number", text: "Clear savings and application steps")
                BenefitRow(icon: "lock.shield", text: "No account—your profile stays on this iPhone")
            }
            .offsetCard()

            Label {
                Text("Coverage is expanding. If a local program has not been added yet, we’ll say so clearly instead of showing a made-up estimate.")
            } icon: {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(OffsetTheme.navy)
            }
            .font(.footnote)
            .foregroundStyle(OffsetTheme.navy)
            .padding(14)
            .background(OffsetTheme.savingsTint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var homeStatusStep: some View {
        OnboardingStepLayout(
            eyebrow: "YOUR HOME",
            title: "Do you own or rent?",
            detail: "Some incentives depend on whether you own the property where the upgrade will be installed."
        ) {
            VStack(spacing: 12) {
                SelectionCard(
                    icon: "house",
                    title: "I own my home",
                    subtitle: "Includes a primary or second home",
                    isSelected: model.homeStatus == .homeowner
                ) {
                    model.homeStatus = .homeowner
                }
                .accessibilityIdentifier("onboarding.home.homeowner")
                SelectionCard(
                    icon: "key",
                    title: "I rent my home",
                    subtitle: "We’ll show renter-eligible programs",
                    isSelected: model.homeStatus == .renter
                ) {
                    model.homeStatus = .renter
                }
                .accessibilityIdentifier("onboarding.home.renter")
            }
        }
    }

    private var zipCodeStep: some View {
        OnboardingStepLayout(
            eyebrow: "LOCATION",
            title: "Where is the project?",
            detail: "Your ZIP code identifies the state and helps narrow down nearby utility programs."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                TextField("ZIP code", text: Binding(
                    get: { model.zipCode },
                    set: { model.updateZIPCode($0) }
                ))
                .font(.title2.monospacedDigit())
                .keyboardType(.numberPad)
                .textContentType(.postalCode)
                .focused($isZIPFieldFocused)
                .padding(16)
                .background(OffsetTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(model.zipValidationMessage == nil ? OffsetTheme.outline : OffsetTheme.error, lineWidth: 1)
                }
                .accessibilityHint("Enter the five digit ZIP code for the project location")

                if let state = model.derivedState {
                    Label("State found: \(state)", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(OffsetTheme.emerald)
                } else if let message = model.zipValidationMessage {
                    Label(message, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(OffsetTheme.error)
                }
            }
        }
        .onAppear { isZIPFieldFocused = model.zipCode.isEmpty }
    }

    private var utilityStep: some View {
        OnboardingStepLayout(
            eyebrow: "UTILITY",
            title: "Who provides your energy?",
            detail: utilityDetail
        ) {
            VStack(spacing: 10) {
                ForEach(model.availableUtilities) { utility in
                    CompactSelectionRow(
                        title: utility.name,
                        isSelected: model.hasChosenUtility && model.selectedUtilityID == utility.id,
                        accessibilityIdentifier: "onboarding.utility.\(utility.id)"
                    ) {
                        model.chooseUtility(utility.id)
                    }
                }

                CompactSelectionRow(
                    title: model.availableUtilities.isEmpty ? "Continue without a utility" : "My utility isn’t listed",
                    isSelected: model.hasChosenUtility && model.selectedUtilityID == nil,
                    accessibilityIdentifier: "onboarding.utility.not-listed"
                ) {
                    model.chooseUtility(nil)
                }
            }
        }
    }

    private var utilityDetail: String {
        if model.availableUtilities.isEmpty {
            return "Utility matching is not available for \(model.derivedState ?? "this state") yet. Federal and state programs can still be matched."
        }
        return "Choose from common providers in \(model.derivedState ?? "your state"). Utility territories can overlap, so use the name on your bill."
    }

    private var projectsStep: some View {
        OnboardingStepLayout(
            eyebrow: "YOUR PLANS",
            title: "What are you considering?",
            detail: "Select everything that might be on your list. You can change this later."
        ) {
            LazyVGrid(columns: onboardingProjectColumns, spacing: 12) {
                ForEach(ProjectType.allCases) { project in
                    ProjectSelectionCard(
                        project: project,
                        isSelected: model.selectedProjects.contains(project)
                    ) {
                        model.toggleProject(project)
                    }
                }
            }
        }
    }

    private var onboardingProjectColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 150), spacing: 12)]
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button(action: continueTapped) {
                HStack(spacing: 8) {
                    Text(continueTitle)
                    Image(systemName: model.step == .projects ? "sparkles" : "arrow.right")
                }
            }
            .buttonStyle(OffsetPrimaryButtonStyle())
            .disabled(!model.canContinue)
            .accessibilityIdentifier("onboarding.continue")

            if model.step == .welcome {
                Text("Takes about one minute")
                    .font(.caption)
                    .foregroundStyle(OffsetTheme.secondaryText)
            }
        }
        .frame(maxWidth: 620)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(OffsetTheme.surface)
        .overlay(alignment: .top) { Divider().opacity(0.35) }
    }

    private var continueTitle: String {
        switch model.step {
        case .welcome: "Get started"
        case .projects: model.isEditing ? "Save changes" : "See my matches"
        default: "Continue"
        }
    }

    private func continueTapped() {
        isZIPFieldFocused = false
        if model.step == .projects {
            guard let profile = model.makeProfile() else { return }
            if model.isEditing {
                appState.updateProfile(profile)
                appState.finishEditingProfile()
            } else {
                appState.completeOnboarding(with: profile)
            }
        } else {
            move { model.advance() }
        }
    }

    private func move(_ update: () -> Void) {
        if reduceMotion {
            update()
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { update() }
        }
    }
}

private struct OnboardingStepLayout<Content: View>: View {
    let eyebrow: String
    let title: String
    let detail: String
    @ViewBuilder let content: Content

    init(eyebrow: String, title: String, detail: String, @ViewBuilder content: () -> Content) {
        self.eyebrow = eyebrow
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text(eyebrow.lowercased().capitalized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OffsetTheme.emerald)
                Text(title)
                    .font(.title.weight(.bold))
                    .foregroundStyle(OffsetTheme.text)
                Text(detail)
                    .font(.body)
                    .foregroundStyle(OffsetTheme.secondaryText)
            }
            content
        }
    }
}

private struct BenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        Label {
            Text(text)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(OffsetTheme.emerald)
        }
        .font(.body.weight(.medium))
    }
}

private struct WelcomeLedgerPreview: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 7) {
                    Circle()
                        .fill(OffsetTheme.emeraldBright)
                        .frame(width: 7, height: 7)
                    OffsetEyebrow(text: "INCENTIVE LEDGER")
                }
                Spacer()
                Text("VERIFIED")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.7)
                    .foregroundStyle(OffsetTheme.emerald)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(OffsetTheme.surfaceHigh, in: Capsule())
            }

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 12) {
                        projectIdentity
                        Text("$12,000")
                            .font(.headline.monospacedDigit())
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                } else {
                    HStack(spacing: 12) {
                        projectIdentity
                        Spacer()
                        Text("$12,000")
                            .font(.headline.monospacedDigit())
                    }
                }
            }
            .padding(12)
            .background(OffsetTheme.surfaceLow, in: RoundedRectangle(cornerRadius: 12))

            VStack(spacing: 8) {
                previewRow("Federal credit", value: "−$2,000")
                previewRow("State program", value: "−$3,000")
                previewRow("Utility rebate", value: "−$1,500")
            }

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 10) {
                        netPriceLabel
                        Text("$5,500")
                            .font(.system(size: 25, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(OffsetTheme.emeraldBright)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                } else {
                    HStack {
                        netPriceLabel
                        Spacer()
                        Text("$5,500")
                            .font(.system(size: 25, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(OffsetTheme.emeraldBright)
                    }
                }
            }
            .padding(15)
            .background(Color(hex: 0x0D2137), in: RoundedRectangle(cornerRadius: 13))
        }
        .offsetCard(padding: 14, elevated: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Example incentive ledger. A twelve thousand dollar heat pump with six thousand five hundred dollars in illustrative incentives has an estimated net price of five thousand five hundred dollars.")
    }

    private var projectIdentity: some View {
        HStack(spacing: 12) {
            Image(systemName: "thermometer.medium")
                .font(.title3)
                .foregroundStyle(OffsetTheme.navy)
                .frame(width: 38, height: 38)
                .background(OffsetTheme.surfaceHigh, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text("Heat pump project")
                    .font(.subheadline.weight(.semibold))
                Text("Illustrative sticker price")
                    .font(.caption)
                    .foregroundStyle(OffsetTheme.secondaryText)
            }
        }
    }

    private var netPriceLabel: some View {
        VStack(alignment: .leading, spacing: 2) {
            OffsetEyebrow(text: "ESTIMATED NET PRICE")
            Text("Applied in program order")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.68))
        }
    }

    private func previewRow(_ title: String, value: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(OffsetTheme.emerald)
            Text(title)
                .font(.subheadline.weight(.medium))
            Spacer()
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(OffsetTheme.emerald)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(OffsetTheme.surfaceLow, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct SelectionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 36, height: 36)
                    .foregroundStyle(isSelected ? Color.white : OffsetTheme.emerald)
                    .background(isSelected ? OffsetTheme.emerald : OffsetTheme.surfaceHigh, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(OffsetTheme.secondaryText)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? OffsetTheme.emerald : OffsetTheme.outline)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(OffsetTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? OffsetTheme.emerald : OffsetTheme.outline, lineWidth: isSelected ? 2 : 1)
        }
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

private struct CompactSelectionRow: View {
    let title: String
    let isSelected: Bool
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? OffsetTheme.emerald : OffsetTheme.outline)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .background(OffsetTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? OffsetTheme.emerald : OffsetTheme.outline.opacity(0.25), lineWidth: isSelected ? 2 : 1)
        }
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

private struct ProjectSelectionCard: View {
    let project: ProjectType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: project.icon)
                        .font(.title2)
                        .foregroundStyle(OffsetTheme.emerald)
                        .accessibilityHidden(true)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? OffsetTheme.emerald : OffsetTheme.outline)
                        .accessibilityHidden(true)
                }
                Text(project.displayName)
                    .font(.headline)
                    .foregroundStyle(OffsetTheme.text)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(OffsetTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? OffsetTheme.emerald : OffsetTheme.outline, lineWidth: isSelected ? 2 : 1)
        }
        .accessibilityLabel(project.displayName)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Double tap to \(isSelected ? "remove" : "select")")
    }
}

extension ProjectType {
    var displayName: String {
        switch self {
        case .heatPump: "Heat pump"
        case .evPurchase: "Electric vehicle"
        case .evCharger: "EV charger"
        case .insulation: "Insulation"
        case .solar: "Solar panels"
        case .waterHeater: "Heat pump water heater"
        case .batteryStorage: "Battery storage"
        case .windows: "Efficient windows"
        case .ductwork: "Duct sealing"
        case .weatherization: "Weatherization"
        }
    }

    var icon: String {
        switch self {
        case .heatPump: "thermometer.medium"
        case .evPurchase: "car.side"
        case .evCharger: "bolt.car"
        case .insulation: "square.3.layers.3d"
        case .solar: "sun.max"
        case .waterHeater: "drop"
        case .batteryStorage: "battery.100percent"
        case .windows: "window.vertical.closed"
        case .ductwork: "wind"
        case .weatherization: "house.and.flag"
        }
    }
}
