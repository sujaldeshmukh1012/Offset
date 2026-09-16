import Foundation

@MainActor
final class AppState: ObservableObject {
    enum RootRoute: Equatable {
        case onboarding
        case main
    }

    enum Tab: Hashable {
        case projects
        case checklist
        case settings
    }

    @Published private(set) var profile: UserProfile?
    @Published private(set) var savedProjects: [SavedProject]
    @Published private(set) var completedClaimSteps: Set<ClaimStepID>
    @Published private(set) var notificationPreferences: NotificationPreferences
    @Published private(set) var latestPricerDraft: PricerDraft?
    @Published private(set) var hasCompletedOnboarding: Bool
    @Published private(set) var rootRoute: RootRoute
    @Published var selectedTab: Tab = .projects
    @Published var notificationRoute: NotificationRoute?
    @Published private(set) var notificationSyncRevision = 0
    @Published private(set) var persistenceErrorMessage: String?

    private let store: any AppStateStoring

    init(store: any AppStateStoring = UserDefaultsAppStateStore()) {
        self.store = store

        do {
            let snapshot = try store.load() ?? AppStateSnapshot()
            profile = snapshot.profile
            savedProjects = snapshot.savedProjects
            completedClaimSteps = snapshot.completedClaimSteps
            notificationPreferences = snapshot.notificationPreferences
            latestPricerDraft = nil
            let completedOnboarding = snapshot.hasCompletedOnboarding && snapshot.profile != nil
            hasCompletedOnboarding = completedOnboarding
            rootRoute = completedOnboarding ? .main : .onboarding
            persistenceErrorMessage = nil
        } catch {
            profile = nil
            savedProjects = []
            completedClaimSteps = []
            notificationPreferences = NotificationPreferences()
            latestPricerDraft = nil
            hasCompletedOnboarding = false
            rootRoute = .onboarding
            persistenceErrorMessage = "Your saved data could not be loaded. You can continue with a fresh setup."
        }
    }

    func completeOnboarding(with profile: UserProfile) {
        self.profile = normalized(profile)
        latestPricerDraft = nil
        hasCompletedOnboarding = true
        rootRoute = .main
        persist()
    }

    func updateProfile(_ profile: UserProfile) {
        self.profile = normalized(profile)
        latestPricerDraft = nil
        persist()
    }

    func setEligibilityAnswer(_ answer: EligibilityAnswer?, for field: String) {
        guard var profile else { return }
        if field == "vehicle_condition" {
            if case .text(let value) = answer {
                profile.vehicleCondition = VehicleCondition(rawValue: value)
            } else {
                profile.vehicleCondition = nil
            }
        } else if field == "vehicle_category" {
            if case .text(let value) = answer {
                profile.vehicleCategory = VehicleCategory(rawValue: value)
            } else {
                profile.vehicleCategory = nil
            }
        } else if let answer {
            profile.eligibilityAnswers[field] = answer
        } else {
            profile.eligibilityAnswers.removeValue(forKey: field)
        }
        self.profile = normalized(profile)
        latestPricerDraft = nil
        persist()
    }

    func restartOnboarding() {
        hasCompletedOnboarding = false
        latestPricerDraft = nil
        rootRoute = .onboarding
        persist()
    }

    func finishEditingProfile() {
        guard profile != nil else { return }
        hasCompletedOnboarding = true
        rootRoute = .main
        persist()
    }

    func saveProject(_ project: SavedProject) {
        guard project.stickerPriceUSD >= 0 else { return }

        if let index = savedProjects.firstIndex(where: { $0.id == project.id }) {
            savedProjects[index] = project
        } else {
            savedProjects.append(project)
        }
        savedProjects.sort { $0.updatedAt > $1.updatedAt }
        latestPricerDraft = nil
        persist()
    }

    func recordPricerDraft(projectType: ProjectType, stickerPriceUSD: Double) {
        guard stickerPriceUSD > 0 else { return }
        latestPricerDraft = PricerDraft(projectType: projectType, stickerPriceUSD: stickerPriceUSD)
        notificationSyncRevision += 1
    }

    func canCreateProject(hasPremiumAccess: Bool) -> Bool {
        hasPremiumAccess || savedProjects.isEmpty
    }

    @discardableResult
    func createProject(_ project: SavedProject, hasPremiumAccess: Bool) -> Bool {
        guard !savedProjects.contains(where: { $0.id == project.id }),
              canCreateProject(hasPremiumAccess: hasPremiumAccess) else { return false }
        saveProject(project)
        return true
    }

    func deleteProject(id: SavedProject.ID) {
        savedProjects.removeAll { $0.id == id }
        completedClaimSteps = completedClaimSteps.filter { $0.projectID != id }
        persist()
    }

    func setClaimStep(_ id: ClaimStepID, isComplete: Bool) {
        if isComplete {
            completedClaimSteps.insert(id)
        } else {
            completedClaimSteps.remove(id)
        }
        persist()
    }

    func isClaimStepComplete(_ id: ClaimStepID) -> Bool {
        completedClaimSteps.contains(id)
    }

    func setDeadlineRemindersEnabled(_ isEnabled: Bool) {
        notificationPreferences.deadlineRemindersEnabled = isEnabled
        persist()
    }

    func markNotificationValuePrimerPresented() {
        guard !notificationPreferences.hasPresentedValuePrimer else { return }
        notificationPreferences.hasPresentedValuePrimer = true
        persist()
    }

    func clearPersistenceError() {
        persistenceErrorMessage = nil
    }

    func openNotificationRoute(_ route: NotificationRoute) {
        guard hasCompletedOnboarding else { return }
        selectedTab = route.isChecklistDestination ? .checklist : .projects
        notificationRoute = route
    }

    func clearNotificationRoute() {
        notificationRoute = nil
    }

    private func normalized(_ profile: UserProfile) -> UserProfile {
        var profile = profile
        profile.zipCode = profile.zipCode.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.state = profile.state.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        profile.utilityProvider = profile.utilityProvider?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        return profile
    }

    private func persist() {
        notificationSyncRevision += 1
        let snapshot = AppStateSnapshot(
            profile: profile,
            savedProjects: savedProjects,
            completedClaimSteps: completedClaimSteps,
            notificationPreferences: notificationPreferences,
            hasCompletedOnboarding: hasCompletedOnboarding
        )

        do {
            try store.save(snapshot)
            persistenceErrorMessage = nil
        } catch {
            persistenceErrorMessage = "Your latest changes could not be saved. Please try again."
        }
    }
}

private extension NotificationRoute {
    var isChecklistDestination: Bool {
        if case .project = self { return true }
        return false
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
