import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case welcome
        case homeStatus
        case zipCode
        case utility
        case projects
    }

    enum HomeStatus: String, CaseIterable, Identifiable {
        case homeowner
        case renter

        var id: Self { self }
    }

    @Published private(set) var step: Step
    @Published var homeStatus: HomeStatus?
    @Published private(set) var zipCode: String
    @Published private(set) var derivedState: String?
    @Published var selectedUtilityID: String?
    @Published private(set) var hasChosenUtility: Bool
    @Published var selectedProjects: Set<ProjectType>
    @Published private(set) var zipValidationMessage: String?

    let isEditing: Bool
    private let locations: LocationService
    private let existingProfile: UserProfile?

    init(profile: UserProfile?, locations: LocationService) {
        isEditing = profile != nil
        self.locations = locations
        existingProfile = profile
        step = profile == nil ? .welcome : .homeStatus
        homeStatus = profile.map { $0.isHomeowner ? .homeowner : .renter }
        zipCode = profile?.zipCode ?? ""
        derivedState = profile.flatMap { locations.state(forZIPCode: $0.zipCode) } ?? profile?.state
        selectedUtilityID = profile?.utilityProvider
        hasChosenUtility = profile != nil
        selectedProjects = Set(profile?.selectedProjects ?? [])
    }

    var progress: Double {
        Double(step.rawValue + 1) / Double(Step.allCases.count)
    }

    var availableUtilities: [UtilityProvider] {
        guard let derivedState else { return [] }
        return locations.utilities(in: derivedState)
    }

    var canContinue: Bool {
        switch step {
        case .welcome:
            true
        case .homeStatus:
            homeStatus != nil
        case .zipCode:
            derivedState != nil && zipCode.count == 5
        case .utility:
            hasChosenUtility
        case .projects:
            !selectedProjects.isEmpty
        }
    }

    func updateZIPCode(_ value: String) {
        let cleaned = String(value.filter(\.isNumber).prefix(5))
        guard cleaned != zipCode else { return }

        zipCode = cleaned
        derivedState = locations.state(forZIPCode: cleaned)
        zipValidationMessage = cleaned.count == 5 && derivedState == nil
            ? "That ZIP code is not in the bundled U.S. ZIP catalog."
            : nil
        selectedUtilityID = nil
        hasChosenUtility = false
    }

    func chooseUtility(_ identifier: String?) {
        selectedUtilityID = identifier
        hasChosenUtility = true
    }

    func toggleProject(_ project: ProjectType) {
        if selectedProjects.contains(project) {
            selectedProjects.remove(project)
        } else {
            selectedProjects.insert(project)
        }
    }

    func advance() {
        if step == .zipCode && derivedState == nil {
            zipValidationMessage = zipCode.count == 5
                ? "That ZIP code is not in the bundled U.S. ZIP catalog."
                : "Enter a five-digit ZIP code."
            return
        }

        guard canContinue,
              let next = Step(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    func goBack() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    func makeProfile() -> UserProfile? {
        guard let homeStatus, let derivedState, !selectedProjects.isEmpty else { return nil }
        return UserProfile(
            zipCode: zipCode,
            state: derivedState,
            utilityProvider: selectedUtilityID,
            isHomeowner: homeStatus == .homeowner,
            selectedProjects: ProjectType.allCases.filter(selectedProjects.contains),
            annualIncomeUSD: existingProfile?.annualIncomeUSD,
            filingStatus: existingProfile?.filingStatus,
            vehicleCondition: existingProfile?.vehicleCondition,
            vehicleCategory: existingProfile?.vehicleCategory,
            eligibilityAnswers: existingProfile?.eligibilityAnswers ?? [:]
        )
    }
}
