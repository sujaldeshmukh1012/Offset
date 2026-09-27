import Foundation
import Testing
@testable import Offset

struct NotificationRetentionTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let projectID = UUID(uuid: (0x11, 0x11, 0x11, 0x11, 0x22, 0x22, 0x33, 0x33, 0x44, 0x44, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55))

    @Test func freePlanNeverTagsLockedProgramData() {
        let plan = makePlan(hasPremiumAccess: false)

        #expect(plan.tags["matched_program_ids"] == "federal-program")
        #expect(plan.tags["matched_program_names"] == "Federal credit")
        #expect(plan.tags["matched_savings_usd"] == "1000")
        #expect(!(plan.tags["matched_program_ids"]?.contains("state-program") ?? true))
    }

    @Test func premiumPlanTagsAllVisibleMatchFields() {
        let plan = makePlan(hasPremiumAccess: true)

        #expect(plan.tags["matched_program_ids"]?.contains("federal-program") == true)
        #expect(plan.tags["matched_program_ids"]?.contains("state-program") == true)
        #expect(plan.tags["matched_program_names"]?.contains("State rebate") == true)
        #expect(plan.tags["matched_savings_usd"]?.contains("500") == true)
        #expect(plan.tags["matched_deadlines"]?.contains("none") == false)
    }

    @Test func unsavedPricerResultStillProducesTagsAndProgramRoutes() {
        let plan = NotificationRetentionPlan.make(
            context: NotificationSyncContext(
                profile: profile,
                savedProjects: [],
                latestPricerDraft: PricerDraft(projectType: .heatPump, stickerPriceUSD: 10_000),
                completedClaimSteps: [],
                preferences: NotificationPreferences(deadlineRemindersEnabled: true),
                hasCompletedOnboarding: true,
                hasPremiumAccess: false
            ),
            programs: programs,
            now: now,
            calendar: Calendar(identifier: .gregorian)
        )

        #expect(plan.tags["matched_program_ids"] == "federal-program")
        #expect(!plan.reminders.contains { $0.identifier == "offset.nudge.no-saved-project" })
        #expect(plan.reminders.contains { $0.route == .program(id: "federal-program", projectID: nil) })
    }

    @Test func schedulesThirtyFourteenAndSevenDayDeadlineCopyAndRoutes() {
        let plan = makePlan(hasPremiumAccess: true)
        let deadlineReminders = plan.reminders.filter { $0.identifier.hasPrefix("offset.deadline.") }

        #expect(deadlineReminders.count == 6)
        #expect(deadlineReminders.contains { $0.title.hasPrefix("30 days left:") })
        #expect(deadlineReminders.contains { $0.title.hasPrefix("14 days left:") })
        #expect(deadlineReminders.contains { $0.title.hasPrefix("7 days left:") })
        #expect(deadlineReminders.allSatisfy { $0.body.contains("review the claim checklist") })
        #expect(deadlineReminders.allSatisfy { $0.route != nil })
    }

    @Test func completingAProgramsStepsRemovesItsDeadlineReminders() {
        let completed = Set([
            ClaimStepID(projectID: projectID, programID: "federal-program", stepIndex: 0)
        ])
        let plan = makePlan(hasPremiumAccess: true, completedClaimSteps: completed)

        #expect(!plan.reminders.contains { $0.identifier.contains("federal-program") })
        #expect(plan.reminders.contains { $0.identifier.contains("state-program") })
        #expect(plan.tags["claim_steps_complete"] == "1")
    }

    @Test func configuresIncompleteWelcomeAndNoProjectNudges() {
        let incomplete = NotificationRetentionPlan.make(
            context: context(profile: nil, projects: [], onboardingComplete: false),
            programs: programs,
            now: now
        )
        let ready = NotificationRetentionPlan.make(
            context: context(profile: profile, projects: [], onboardingComplete: true),
            programs: programs,
            now: now
        )

        #expect(incomplete.reminders.map(\.identifier) == ["offset.nudge.incomplete-onboarding"])
        #expect(Set(ready.reminders.map(\.identifier)) == [
            "offset.nudge.welcome", "offset.nudge.no-saved-project"
        ])
    }

    @Test func identifiesOnlyManagedStaleTagsForRemoval() async {
        let stale = await NotificationService.managedStaleTagKeys(
            existing: ["matched_program_names": "Old", "unrelated_dashboard_tag": "keep"],
            desired: ["match_count": "0"]
        )

        #expect(stale == ["matched_program_names"])
    }

    @Test func freeOneSignalPlanUsesOnlyEssentialRemoteTags() {
        let plan = makePlan(hasPremiumAccess: false)
        let remoteTags = plan.tags.filter { NotificationRetentionPlan.remoteTagKeys.contains($0.key) }

        #expect(remoteTags == [
            "journey_stage": "saved_project",
            "premium_access": "free"
        ])
    }

    private func makePlan(
        hasPremiumAccess: Bool,
        completedClaimSteps: Set<ClaimStepID> = []
    ) -> NotificationRetentionPlan {
        NotificationRetentionPlan.make(
            context: NotificationSyncContext(
                profile: profile,
                savedProjects: [project],
                latestPricerDraft: nil,
                completedClaimSteps: completedClaimSteps,
                preferences: NotificationPreferences(deadlineRemindersEnabled: true),
                hasCompletedOnboarding: true,
                hasPremiumAccess: hasPremiumAccess
            ),
            programs: programs,
            now: now,
            calendar: Calendar(identifier: .gregorian)
        )
    }

    private func context(
        profile: UserProfile?,
        projects: [SavedProject],
        onboardingComplete: Bool
    ) -> NotificationSyncContext {
        NotificationSyncContext(
            profile: profile,
            savedProjects: projects,
            latestPricerDraft: nil,
            completedClaimSteps: [],
            preferences: NotificationPreferences(deadlineRemindersEnabled: true),
            hasCompletedOnboarding: onboardingComplete,
            hasPremiumAccess: false
        )
    }

    private var profile: UserProfile {
        UserProfile(zipCode: "02108", state: "MA", isHomeowner: true, selectedProjects: [.heatPump])
    }

    private var project: SavedProject {
        SavedProject(id: projectID, name: "Home heat pump", projectType: .heatPump, stickerPriceUSD: 10_000)
    }

    private var programs: [Program] {
        [
            program(id: "federal-program", name: "Federal credit", level: .federal, amount: .fixedAmount(1_000)),
            program(id: "state-program", name: "State rebate", level: .state, amount: .fixedAmount(500))
        ]
    }

    private func program(id: String, name: String, level: ProgramLevel, amount: AmountType) -> Program {
        Program(
            id: id,
            name: name,
            level: level,
            benefitType: level == .federal ? .nonrefundableTaxCredit : .rebate,
            status: .active,
            projectTypes: [.heatPump],
            amountType: amount,
            eligibilityStates: level == .federal ? [] : ["MA"],
            eligibilityUtilities: [],
            eligibleHomeOccupancies: [],
            eligibleVehicleConditions: [],
            incomeCapsUSD: [:],
            vehiclePriceCapsUSD: [:],
            annualCaps: [],
            effectiveDate: now.addingTimeInterval(-86_400),
            deadline: now.addingTimeInterval(90 * 86_400),
            sourceURL: "https://example.com",
            lastVerifiedDate: now,
            eligibilitySummary: ["Eligible"],
            claimSteps: ["Submit paperwork"],
            description: "Test"
        )
    }
}

struct NotificationRouteTests {
    @Test func parsesProjectAndProgramDeepLinks() throws {
        let projectID = UUID(uuid: (0x11, 0x11, 0x11, 0x11, 0x22, 0x22, 0x33, 0x33, 0x44, 0x44, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55))
        let projectURL = try #require(URL(string: "offset://project/\(projectID.uuidString)"))
        let programURL = try #require(URL(string: "offset://program/federal-25c?project_id=\(projectID.uuidString)"))

        #expect(NotificationRoute.parse(url: projectURL) == .project(projectID))
        #expect(
            NotificationRoute.parse(url: programURL) == .program(id: "federal-25c", projectID: projectID)
        )
    }

    @Test func parsesOneSignalAdditionalData() {
        let projectID = UUID(uuid: (0x11, 0x11, 0x11, 0x11, 0x22, 0x22, 0x33, 0x33, 0x44, 0x44, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55))
        let route = NotificationRoute.parse(additionalData: [
            "program_id": "state-rebate",
            "project_id": projectID.uuidString
        ])

        #expect(route == .program(id: "state-rebate", projectID: projectID))
    }
}

@MainActor
struct NotificationIdentityTests {
    @Test func reusesTheAnonymousInstallationIdentifier() {
        let suiteName = "NotificationIdentityTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let configuration = AppConfiguration(values: [
            "RevenueCatMonthlyProductID": "monthly",
            "RevenueCatAnnualProductID": "annual",
            "RevenueCatEntitlementID": "offset_pro"
        ])

        let first = NotificationService(configuration: configuration, defaults: defaults)
        let second = NotificationService(configuration: configuration, defaults: defaults)

        #expect(first.externalUserID.hasPrefix("offset_"))
        #expect(second.externalUserID == first.externalUserID)
    }
}
