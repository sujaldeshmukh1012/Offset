import Foundation
import Testing
@testable import Offset

@MainActor
struct AppStateTests {
    @Test func persistsAndRestoresTheCompleteLocalState() throws {
        let store = MemoryAppStateStore()
        let state = AppState(store: store)
        let profile = UserProfile(
            zipCode: " 02108 ",
            state: "ma",
            utilityProvider: " evergreen-electric ",
            isHomeowner: true,
            selectedProjects: [.heatPump]
        )
        let project = SavedProject(
            id: UUID(),
            name: "Heat pump",
            projectType: .heatPump,
            stickerPriceUSD: 12_000,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let claimStep = ClaimStepID(projectID: project.id, programID: "federal-25c", stepIndex: 1)

        state.completeOnboarding(with: profile)
        state.saveProject(project)
        state.setClaimStep(claimStep, isComplete: true)
        state.setDeadlineRemindersEnabled(true)
        state.markNotificationValuePrimerPresented()

        let restored = AppState(store: store)
        #expect(restored.hasCompletedOnboarding)
        #expect(restored.rootRoute == .main)
        #expect(restored.profile?.zipCode == "02108")
        #expect(restored.profile?.state == "MA")
        #expect(restored.profile?.utilityProvider == "evergreen-electric")
        #expect(restored.savedProjects == [project])
        #expect(restored.isClaimStepComplete(claimStep))
        #expect(restored.notificationPreferences.deadlineRemindersEnabled)
        #expect(restored.notificationPreferences.hasPresentedValuePrimer)
    }

    @Test func deletingAProjectAlsoDeletesItsChecklistProgress() {
        let store = MemoryAppStateStore()
        let state = AppState(store: store)
        let deletedProject = SavedProject(name: "Solar", projectType: .solar, stickerPriceUSD: 20_000)
        let retainedProject = SavedProject(name: "Insulation", projectType: .insulation, stickerPriceUSD: 4_000)
        let deletedStep = ClaimStepID(projectID: deletedProject.id, programID: "solar-credit", stepIndex: 0)
        let retainedStep = ClaimStepID(projectID: retainedProject.id, programID: "25c", stepIndex: 0)

        state.saveProject(deletedProject)
        state.saveProject(retainedProject)
        state.setClaimStep(deletedStep, isComplete: true)
        state.setClaimStep(retainedStep, isComplete: true)
        state.deleteProject(id: deletedProject.id)

        #expect(!state.savedProjects.contains { $0.id == deletedProject.id })
        #expect(!state.isClaimStepComplete(deletedStep))
        #expect(state.isClaimStepComplete(retainedStep))
    }

    @Test func restartOnboardingKeepsTheExistingProfileForEditing() throws {
        let store = MemoryAppStateStore()
        let state = AppState(store: store)
        let profile = UserProfile(
            zipCode: "10001",
            state: "NY",
            isHomeowner: false,
            selectedProjects: [.evPurchase]
        )

        state.completeOnboarding(with: profile)
        state.restartOnboarding()

        #expect(!state.hasCompletedOnboarding)
        #expect(state.rootRoute == .onboarding)
        #expect(state.profile == profile)
        #expect(try store.load()?.profile == profile)

        state.finishEditingProfile()
        #expect(state.hasCompletedOnboarding)
        #expect(state.rootRoute == .main)
    }

    @Test func loadFailureFallsBackToSafeEmptyState() {
        let state = AppState(store: FailingAppStateStore())

        #expect(!state.hasCompletedOnboarding)
        #expect(state.profile == nil)
        #expect(state.savedProjects.isEmpty)
        #expect(state.persistenceErrorMessage != nil)
    }

    @Test func savingProjectsRequiresPremium() {
        let state = AppState(store: MemoryAppStateStore())
        let first = SavedProject(name: "Heat pump", projectType: .heatPump, stickerPriceUSD: 10_000)
        let second = SavedProject(name: "Solar", projectType: .solar, stickerPriceUSD: 20_000)

        #expect(!state.canCreateProject(hasPremiumAccess: false))
        #expect(!state.createProject(first, hasPremiumAccess: false))
        #expect(!state.createProject(second, hasPremiumAccess: false))
        #expect(state.savedProjects.isEmpty)
        #expect(state.canCreateProject(hasPremiumAccess: true))
        #expect(state.createProject(first, hasPremiumAccess: true))
        #expect(state.createProject(second, hasPremiumAccess: true))
        #expect(state.savedProjects.count == 2)
    }

    @Test func decodesLegacySnapshotAndNotificationPreferencesWithSafeDefaults() throws {
        let legacySnapshot = Data(#"{"profile":null,"savedProjects":[],"completedClaimSteps":[],"hasCompletedOnboarding":false}"#.utf8)
        let snapshot = try JSONDecoder().decode(AppStateSnapshot.self, from: legacySnapshot)
        #expect(snapshot.schemaVersion == 1)
        #expect(snapshot.notificationPreferences == NotificationPreferences())

        let legacyPreferences = Data(#"{"deadlineRemindersEnabled":true}"#.utf8)
        let preferences = try JSONDecoder().decode(NotificationPreferences.self, from: legacyPreferences)
        #expect(preferences.deadlineRemindersEnabled)
        #expect(!preferences.hasPresentedValuePrimer)
    }

    @Test func persistedSnapshotDoesNotContainCalculatedPremiumAmountsOrProgramNames() throws {
        let snapshot = AppStateSnapshot(
            profile: UserProfile(zipCode: "02108", state: "MA", isHomeowner: true, selectedProjects: [.solar]),
            savedProjects: [SavedProject(name: "Roof project", projectType: .solar, stickerPriceUSD: 12_000)],
            hasCompletedOnboarding: true
        )
        let data = try JSONEncoder().encode(snapshot)
        let text = try #require(String(data: data, encoding: .utf8))

        #expect(!text.contains("estimatedSavings"))
        #expect(!text.contains("netPrice"))
        #expect(!text.contains("Massachusetts Residential Renewable Energy Credit"))
    }
}

private final class MemoryAppStateStore: AppStateStoring {
    private var snapshot: AppStateSnapshot?

    func load() throws -> AppStateSnapshot? {
        snapshot
    }

    func save(_ snapshot: AppStateSnapshot) throws {
        self.snapshot = snapshot
    }
}

private struct FailingAppStateStore: AppStateStoring {
    struct LoadError: Error {}

    func load() throws -> AppStateSnapshot? {
        throw LoadError()
    }

    func save(_ snapshot: AppStateSnapshot) throws {}
}
