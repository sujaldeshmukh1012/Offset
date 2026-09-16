import Foundation
import UIKit
import UserNotifications

struct NotificationSyncContext: Sendable {
    let profile: UserProfile?
    let savedProjects: [SavedProject]
    let latestPricerDraft: PricerDraft?
    let completedClaimSteps: Set<ClaimStepID>
    let preferences: NotificationPreferences
    let hasCompletedOnboarding: Bool
    let hasPremiumAccess: Bool
}

struct OffsetReminder: Equatable, Sendable {
    let identifier: String
    let title: String
    let body: String
    let fireDate: Date
    let route: NotificationRoute?
}

struct NotificationRetentionPlan: Equatable, Sendable {
    static let managedTagKeys: Set<String> = [
        "onboarding_status", "journey_stage", "has_saved_project", "saved_project_count",
        "reminders_enabled", "premium_access", "match_count", "matched_program_ids",
        "matched_program_names", "matched_savings_usd", "matched_deadlines", "next_deadline_at",
        "next_program_id", "next_project_id", "claim_steps_complete", "claim_steps_total"
    ]
    // OneSignal's free plan permits only a small number of tags per user.
    // Keep remote segmentation focused while retaining the richer local plan
    // for notification scheduling and future paid-plan use.
    static let remoteTagKeys: Set<String> = ["journey_stage", "premium_access"]

    let tags: [String: String]
    let reminders: [OffsetReminder]

    static func make(
        context: NotificationSyncContext,
        programs: [Program],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Self {
        var tags: [String: String] = [
            "onboarding_status": context.hasCompletedOnboarding ? "complete" : "incomplete",
            "has_saved_project": context.savedProjects.isEmpty ? "false" : "true",
            "saved_project_count": String(context.savedProjects.count),
            "reminders_enabled": context.preferences.deadlineRemindersEnabled ? "true" : "false",
            "premium_access": context.hasPremiumAccess ? "active" : "free"
        ]
        tags["journey_stage"] = if !context.hasCompletedOnboarding {
            "incomplete_onboarding"
        } else if context.savedProjects.isEmpty {
            "no_saved_project"
        } else {
            "saved_project"
        }

        guard let profile = context.profile else {
            tags["match_count"] = "0"
            return Self(tags: tags, reminders: nudgeReminders(context: context, now: now, calendar: calendar))
        }

        let visiblePrograms = context.hasPremiumAccess ? programs : programs.filter { $0.level == .federal }
        var matches: [(projectID: UUID?, projectName: String, match: MatchResult)] = []
        for project in context.savedProjects {
            let projectMatches = MatchingEngine(programs: visiblePrograms, referenceDate: now).matches(
                for: profile,
                project: project.projectType,
                stickerPriceUSD: project.stickerPriceUSD,
                hasPremiumAccess: true
            )
            matches.append(contentsOf: projectMatches.map { (project.id, project.name, $0) })
        }
        if let draft = context.latestPricerDraft {
            let draftMatches = MatchingEngine(programs: visiblePrograms, referenceDate: now).matches(
                for: profile,
                project: draft.projectType,
                stickerPriceUSD: draft.stickerPriceUSD,
                hasPremiumAccess: true
            )
            matches.append(contentsOf: draftMatches.map { (nil, draft.projectType.displayName, $0) })
        }

        let orderedMatches = matches.sorted {
            let left = $0.match.program.deadline ?? .distantFuture
            let right = $1.match.program.deadline ?? .distantFuture
            if left != right { return left < right }
            if $0.match.program.id != $1.match.program.id { return $0.match.program.id < $1.match.program.id }
            return ($0.projectID?.uuidString ?? "draft") < ($1.projectID?.uuidString ?? "draft")
        }
        tags["match_count"] = String(orderedMatches.count)
        if !orderedMatches.isEmpty {
            tags["matched_program_ids"] = limited(orderedMatches.map { $0.match.program.id })
            tags["matched_program_names"] = limited(orderedMatches.map { $0.match.program.name })
            tags["matched_savings_usd"] = limited(orderedMatches.map { String(Int($0.match.estimatedSavingsUSD.rounded())) })
            tags["matched_deadlines"] = limited(orderedMatches.map {
                $0.match.program.deadline.map(Self.isoDate) ?? "none"
            })
        }

        let allStepIDs = orderedMatches.compactMap { item -> [ClaimStepID]? in
            guard let projectID = item.projectID else { return nil }
            return item.match.program.claimSteps.indices.map {
                ClaimStepID(projectID: projectID, programID: item.match.program.id, stepIndex: $0)
            }
        }.flatMap { $0 }
        tags["claim_steps_total"] = String(allStepIDs.count)
        tags["claim_steps_complete"] = String(allStepIDs.filter(context.completedClaimSteps.contains).count)

        if let next = orderedMatches.first(where: { $0.match.program.deadline != nil }),
           let deadline = next.match.program.deadline {
            tags["next_deadline_at"] = Self.isoDate(deadline)
            tags["next_program_id"] = next.match.program.id
            if let projectID = next.projectID { tags["next_project_id"] = projectID.uuidString }
        }

        var reminders = nudgeReminders(context: context, now: now, calendar: calendar)
        guard context.preferences.deadlineRemindersEnabled else { return Self(tags: tags, reminders: reminders) }
        for item in orderedMatches {
            let program = item.match.program
            guard let deadline = program.deadline else { continue }
            let hasIncompleteStep = item.projectID == nil || program.claimSteps.indices.contains { index in
                guard let projectID = item.projectID else { return true }
                return !context.completedClaimSteps.contains(
                    ClaimStepID(projectID: projectID, programID: program.id, stepIndex: index)
                )
            }
            guard hasIncompleteStep else { continue }
            for days in [30, 14, 7] {
                guard let reminderDay = calendar.date(byAdding: .day, value: -days, to: deadline),
                      let fireDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: reminderDay),
                      fireDate > now else { continue }
                reminders.append(OffsetReminder(
                    identifier: "offset.deadline.\(item.projectID?.uuidString ?? "draft").\(program.id).\(days)",
                    title: "\(days) days left: \(program.name)",
                    body: "\(item.projectName): review the claim checklist before the \(deadline.formatted(date: .abbreviated, time: .omitted)) deadline.",
                    fireDate: fireDate,
                    route: .program(id: program.id, projectID: item.projectID)
                ))
            }
        }
        reminders.sort { $0.fireDate < $1.fireDate }
        return Self(tags: tags, reminders: Array(reminders.prefix(60)))
    }

    private static func nudgeReminders(context: NotificationSyncContext, now: Date, calendar: Calendar) -> [OffsetReminder] {
        guard context.preferences.deadlineRemindersEnabled else { return [] }
        if !context.hasCompletedOnboarding {
            return [OffsetReminder(
                identifier: "offset.nudge.incomplete-onboarding",
                title: "Finish your Offset profile",
                body: "Add your ZIP, utility, and projects so Offset can find the programs that fit your home.",
                fireDate: calendar.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86_400),
                route: nil
            )]
        }
        if context.savedProjects.isEmpty && context.latestPricerDraft == nil {
            return [
                OffsetReminder(
                    identifier: "offset.nudge.welcome",
                    title: "Your savings profile is ready",
                    body: "Price your first project to see verified incentives in the order they apply.",
                    fireDate: calendar.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86_400),
                    route: nil
                ),
                OffsetReminder(
                    identifier: "offset.nudge.no-saved-project",
                    title: "Keep a project deadline-ready",
                    body: "Save a project to build its combined incentive checklist and deadline reminders.",
                    fireDate: calendar.date(byAdding: .day, value: 3, to: now) ?? now.addingTimeInterval(259_200),
                    route: nil
                )
            ]
        }
        return []
    }

    private static func limited(_ values: [String]) -> String {
        String(values.joined(separator: "|").prefix(240))
    }

    private static func isoDate(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

@MainActor
final class NotificationService: ObservableObject {
    @Published private(set) var permissionGranted = false
    @Published private(set) var pushSubscriptionID: String?
    @Published private(set) var statusMessage: String?
    @Published private(set) var lastSyncedTags: [String: String] = [:]
    @Published private(set) var externalUserID: String

    private let isOneSignalConfigured: Bool
    private let notificationCenter: UNUserNotificationCenter
    private static let externalUserIDKey = "offset.notifications.external-user-id"

    init(
        configuration: AppConfiguration,
        notificationCenter: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard
    ) {
        isOneSignalConfigured = configuration.oneSignalAppID != nil
        self.notificationCenter = notificationCenter
        if let existing = defaults.string(forKey: Self.externalUserIDKey), !existing.isEmpty {
            externalUserID = existing
        } else {
            let generated = "offset_\(UUID().uuidString.lowercased())"
            defaults.set(generated, forKey: Self.externalUserIDKey)
            externalUserID = generated
        }
    }

    func requestPermission() async -> Bool {
        let accepted: Bool
        if isOneSignalConfigured {
            accepted = await OneSignalManager.shared.requestPermission()
        } else {
            do {
                accepted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            } catch {
                statusMessage = error.localizedDescription
                return false
            }
        }
        await refreshStatus()
        statusMessage = accepted
            ? "Reminders enabled. Offset will keep upcoming deadlines current."
            : "Notifications are off. You can enable them later in iOS Settings."
        return accepted
    }

    func refreshStatus() async {
        let settings = await notificationCenter.notificationSettings()
        permissionGranted = switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
        pushSubscriptionID = isOneSignalConfigured ? OneSignalManager.shared.pushSubscriptionID : nil
    }

    func synchronize(context: NotificationSyncContext) async {
        await refreshStatus()
        let programs: [Program]
        do {
            programs = try ProgramStore.loadBundledPrograms(profile: context.profile)
        } catch {
            statusMessage = "Reminder data could not be loaded: \(error.localizedDescription)"
            return
        }
        let plan = NotificationRetentionPlan.make(context: context, programs: programs)
        lastSyncedTags = plan.tags
        if isOneSignalConfigured {
            let remoteTags = plan.tags.filter { NotificationRetentionPlan.remoteTagKeys.contains($0.key) }
            OneSignalManager.shared.synchronizeUser(
                externalID: externalUserID,
                desiredTags: remoteTags,
                managedTagKeys: NotificationRetentionPlan.managedTagKeys
            )
        }
        await replaceManagedReminders(with: permissionGranted ? plan.reminders : [])
        if permissionGranted && context.preferences.deadlineRemindersEnabled {
            statusMessage = plan.reminders.isEmpty
                ? "Reminders are on. No dated, incomplete matches need scheduling right now."
                : "\(plan.reminders.count) reminder\(plan.reminders.count == 1 ? "" : "s") scheduled."
        }
    }

    func recordForegroundReceipt() {
        statusMessage = "A OneSignal notification was received while Offset was open."
    }

    static func managedStaleTagKeys(existing: [String: String], desired: [String: String]) -> [String] {
        existing.keys.filter {
            NotificationRetentionPlan.managedTagKeys.contains($0) && desired[$0] == nil
        }.sorted()
    }

    func scheduleLocalTestNotification() async {
        await refreshStatus()
        guard permissionGranted else {
            statusMessage = "Notifications are off. Enable them from the OneSignal setup prompt or iOS Settings before sending a test."
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Offset notifications are working"
        content.body = "This local test arrived successfully. Remote OneSignal delivery will activate with APNs provisioning."
        content.sound = .default
        do {
            try await notificationCenter.add(UNNotificationRequest(
                identifier: "offset.local-notification-proof",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
            ))
            statusMessage = "Local test scheduled. Background the app now; it will arrive in about 3 seconds."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func replaceManagedReminders(with reminders: [OffsetReminder]) async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let desiredIDs = Set(reminders.map(\.identifier))
        let existingNudgeIDs = Set(pending.map(\.identifier).filter { $0.hasPrefix("offset.nudge.") })
        let managedIDs = pending.map(\.identifier).filter { identifier in
            identifier.hasPrefix("offset.deadline.")
                || (identifier.hasPrefix("offset.nudge.") && !desiredIDs.contains(identifier))
        }
        if !managedIDs.isEmpty { notificationCenter.removePendingNotificationRequests(withIdentifiers: managedIDs) }
        for reminder in reminders where reminder.fireDate > Date() {
            // Keep an existing nudge's original fire date instead of pushing it back on every sync.
            if reminder.identifier.hasPrefix("offset.nudge."), existingNudgeIDs.contains(reminder.identifier) {
                continue
            }
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            if let route = reminder.route { content.userInfo = route.userInfo }
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
            do {
                try await notificationCenter.add(UNNotificationRequest(
                    identifier: reminder.identifier,
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                ))
            } catch {
                statusMessage = "A reminder could not be scheduled: \(error.localizedDescription)"
            }
        }
    }
}
