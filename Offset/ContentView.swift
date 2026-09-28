import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var notifications: NotificationService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showOneSignalIntegrationAlert = false
    @State private var hasShownOneSignalIntegrationAlert = false

    var body: some View {
        Group {
            switch appState.rootRoute {
            case .main:
                MainTabView()
            case .onboarding:
                OnboardingFlowView(profile: appState.profile)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: appState.rootRoute)
        .tint(OffsetTheme.emerald)
        .preferredColorScheme(.light)
        .onAppear {
            notifications.announceOneSignalRegistrationIfAvailable()
        }
        .onOpenURL { url in
            if let route = NotificationRoute.parse(url: url) {
                appState.openNotificationRoute(route)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .offsetNotificationRoute)) { notification in
            if let route = notification.object as? NotificationRoute {
                appState.openNotificationRoute(route)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .offsetOneSignalRegistrationCompleted)) { _ in
            guard _isDebugAssertConfiguration() else { return }
            guard !hasShownOneSignalIntegrationAlert else { return }
            hasShownOneSignalIntegrationAlert = true
            showOneSignalIntegrationAlert = true
        }
        .alert(
            "Your OneSignal SDK integration is complete!",
            isPresented: $showOneSignalIntegrationAlert
        ) {
            Button("Got it") {
                Task { _ = await notifications.requestPermission() }
            }
        } message: {
            Text("You can now send Push Notifications & In-App Messages through OneSignal. Tap below to enable push notifications.")
        }
        .sheet(item: $appState.notificationRoute) { route in
            NotificationDestinationView(route: route)
                .environmentObject(appState)
        }
        .alert(
            "Local storage issue",
            isPresented: Binding(
                get: { appState.persistenceErrorMessage != nil },
                set: { isPresented in
                    if !isPresented { appState.clearPersistenceError() }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                appState.clearPersistenceError()
            }
        } message: {
            Text(appState.persistenceErrorMessage ?? "Your changes could not be saved.")
        }
    }
}

private struct NotificationDestinationView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptions: SubscriptionService
    @EnvironmentObject private var supabaseCatalog: SupabaseCatalogService
    let route: NotificationRoute

    var body: some View {
        NavigationStack {
            switch route {
            case .project(let id):
                if appState.savedProjects.contains(where: { $0.id == id }) {
                    SavedProjectDetailView(projectID: id)
                } else {
                    missingDestination("That saved project is no longer on this device.")
                }
            case .program(let id, let projectID):
                if let program = programs.first(where: { $0.id == id }) {
                    if program.level == .federal || subscriptions.hasPremiumAccess {
                        ProgramDetailView(
                            program: program,
                            estimatedSavingsUSD: estimatedSavings(programID: id, projectID: projectID)
                        )
                    } else {
                        missingDestination("Premium is required to open this state or utility program.")
                    }
                } else {
                    missingDestination("That program is no longer in the verified catalog.")
                }
            }
        }
    }

    private var programs: [Program] {
        _ = supabaseCatalog.revision
        return (try? ProgramStore.loadCurrentPrograms(profile: appState.profile)) ?? []
    }

    private func estimatedSavings(programID: String, projectID: UUID?) -> Double {
        guard let profile = appState.profile,
              let projectID,
              let project = appState.savedProjects.first(where: { $0.id == projectID }),
              let experience = try? ProjectExperienceService.current(profile: profile) else { return 0 }
        return experience.matches(for: project, profile: profile)
            .first(where: { $0.program.id == programID })?
            .estimatedSavingsUSD ?? 0
    }

    private func missingDestination(_ message: String) -> some View {
        EmptyStateView(icon: "bell.slash", title: "Reminder unavailable", message: message)
    }
}

private struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptions: SubscriptionService

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(AppState.Tab.home)

            NavigationStack {
                ChecklistRootView()
            }
            .tabItem {
                Label("Checklist", systemImage: "checklist")
            }
            .tag(AppState.Tab.checklist)

            if !subscriptions.hasPremiumAccess {
                PremiumUnlockView(showsCloseButton: false)
                    .tabItem {
                        Label("Premium", systemImage: "crown.fill")
                    }
                    .tag(AppState.Tab.premium)
            }

            NavigationStack {
                SettingsRootView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(AppState.Tab.settings)
        }
        .tint(OffsetTheme.emerald)
        .toolbarBackground(OffsetTheme.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onChange(of: subscriptions.hasPremiumAccess) { hasPremiumAccess in
            if hasPremiumAccess, appState.selectedTab == .premium {
                appState.selectedTab = .home
            }
        }
    }
}

private struct SettingsRootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var notifications: NotificationService
    @EnvironmentObject private var supabaseCatalog: SupabaseCatalogService
    private let configuration = AppConfiguration()

    var body: some View {
        List {
            if let profile = appState.profile {
                Section {
                    LabeledContent("Home", value: profile.isHomeowner ? "Homeowner" : "Renter")
                    LabeledContent("ZIP code", value: profile.zipCode)
                        .accessibilityIdentifier("settings.zip")
                    LabeledContent("State", value: profile.state)
                    if let utility = profile.utilityProvider {
                        LabeledContent("Utility", value: utilityDisplayName(utility))
                            .accessibilityIdentifier("settings.utility")
                    } else {
                        LabeledContent("Utility", value: "Not listed")
                            .accessibilityIdentifier("settings.utility")
                    }
                    LabeledContent(
                        "Projects",
                        value: profile.selectedProjects.map(\.displayName).joined(separator: ", ")
                    )
                    .accessibilityIdentifier("settings.projects")
                    .accessibilityElement(children: .combine)
                    Button("Edit profile") {
                        appState.restartOnboarding()
                    }
                } header: {
                    Text("Profile")
                } footer: {
                    Text("Stored only on this iPhone. No account required.")
                }
            }

            Section("Notifications") {
                Toggle("Deadline reminders", isOn: Binding(
                    get: { appState.notificationPreferences.deadlineRemindersEnabled },
                    set: { updateDeadlineReminders($0) }
                ))
                .accessibilityIdentifier("settings.deadline-reminders")

                Text("Get reminders before matched program deadlines. Your preference is stored locally, and notification permission can be changed in iOS Settings.")
                    .font(.footnote)
                    .foregroundStyle(OffsetTheme.secondaryText)

                LabeledContent("System permission", value: notifications.permissionGranted ? "Allowed" : "Not allowed")
            }

            Section("Offset Premium") {
                LabeledContent("Access", value: premiumAccessText)
                    .accessibilityIdentifier("settings.premium-status")

                if !subscriptions.hasPremiumAccess {
                    Button("Buy Premium") {
                        appState.selectedTab = .premium
                    }
                    .accessibilityIdentifier("settings.buy-premium")
                }

                if let managementURL = subscriptions.managementURL {
                    Link("Manage subscription", destination: managementURL)
                }

                Button("Restore purchases") {
                    Task { await subscriptions.restore() }
                }
                .disabled(isSubscriptionBusy)
            }

            Section("About") {
                if let privacyPolicyURL = configuration.privacyPolicyURL {
                    Link("Privacy Policy", destination: privacyPolicyURL)
                }
                if let supportURL = configuration.supportURL {
                    Link("Support", destination: supportURL)
                }
                Link(
                    "Terms of Use",
                    destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
                )
            }

            Section("Rebate data") {
                Text(supabaseCatalog.statusDescription)
                    .font(.footnote)
                    .foregroundStyle(OffsetTheme.secondaryText)

                Button("Check for updates") {
                    Task {
                        await supabaseCatalog.refreshIfNeeded(
                            hasPremiumAccess: subscriptions.hasPremiumAccess,
                            force: true
                        )
                    }
                }
                .disabled(!subscriptions.hasPremiumAccess)
            }

        }
        .scrollContentBackground(.hidden)
        .background(OffsetTheme.canvas)
        .listRowBackground(OffsetTheme.surface)
        .tint(OffsetTheme.emerald)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .task { await notifications.refreshStatus() }
    }

    @EnvironmentObject private var subscriptions: SubscriptionService

    private var isSubscriptionBusy: Bool {
        switch subscriptions.state {
        case .loadingProducts, .purchasing, .restoring: true
        default: false
        }
    }

    private var premiumAccessText: String {
        switch subscriptions.accessStatus {
        case .checking: "Checking…"
        case .free: "Free"
        case .active(_, let willRenew, let isTrial):
            isTrial ? "Trial active" : (willRenew ? "Active" : "Active until expiration")
        case .billingIssue: "Active — payment issue"
        case .expired: "Expired"
        case .unavailable: "Unavailable"
        }
    }

    private func updateDeadlineReminders(_ shouldEnable: Bool) {
        if !shouldEnable {
            appState.setDeadlineRemindersEnabled(false)
            return
        }

        Task {
            let accepted = await notifications.requestPermission()
            appState.setDeadlineRemindersEnabled(accepted)
        }
    }

    private func utilityDisplayName(_ identifier: String) -> String {
        let locations = try? LocationService.current()
        return locations?.utilityName(for: identifier) ?? identifier
    }
}

#if DEBUG
struct IntegrationProofView: View {
    @EnvironmentObject private var subscriptions: SubscriptionService
    @EnvironmentObject private var notifications: NotificationService
    private let configuration = AppConfiguration()

    var body: some View {
        List {
            Section("RevenueCat") {
                LabeledContent("Entitlement", value: configuration.revenueCatEntitlementID)
                LabeledContent("Access", value: subscriptions.hasPremiumAccess ? "Active" : "Inactive")

                productRow(id: configuration.revenueCatMonthlyProductID, label: "Monthly")
                productRow(id: configuration.revenueCatAnnualProductID, label: "Annual")

                Button("Restore purchases") {
                    Task { await subscriptions.restore() }
                }
                .disabled(isRevenueCatBusy)

                Text(revenueCatStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("OneSignal") {
                Text("Enable deadline reminders so Offset can warn you 30, 14, and 7 days before matched programs close.")

                Button("Send local test in 3 seconds") {
                    Task { await notifications.scheduleLocalTestNotification() }
                }

                Button("Refresh registration") {
                    Task { await notifications.refreshStatus() }
                }

                LabeledContent("Permission", value: notifications.permissionGranted ? "Granted" : "Not granted")
                LabeledContent("Subscription ID", value: notifications.pushSubscriptionID ?? "Not registered")
                    .textSelection(.enabled)
                LabeledContent("External user ID", value: notifications.externalUserID)
                    .textSelection(.enabled)
                LabeledContent("Synced tags", value: String(notifications.lastSyncedTags.count))

                if let statusMessage = notifications.statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(OffsetTheme.canvas)
        .listRowBackground(OffsetTheme.surface)
        .tint(OffsetTheme.emerald)
        .navigationTitle("Integration proof")
        .task {
            await subscriptions.refresh()
            await notifications.refreshStatus()
        }
    }

    @ViewBuilder
    private func productRow(id: String, label: String) -> some View {
        if let product = subscriptions.product(id: id) {
            Button {
                Task { await subscriptions.purchase(productID: id) }
            } label: {
                LabeledContent(label, value: product.localizedPriceString)
            }
            .disabled(isRevenueCatBusy)
        } else {
            LabeledContent(label, value: "Unavailable")
        }
    }

    private var isRevenueCatBusy: Bool {
        switch subscriptions.state {
        case .loadingProducts, .purchasing, .restoring:
            true
        default:
            false
        }
    }

    private var revenueCatStatus: String {
        switch subscriptions.state {
        case .idle:
            "Ready"
        case .loadingProducts:
            "Loading products…"
        case .purchasing:
            "Completing purchase…"
        case .restoring:
            "Restoring purchases…"
        case .pending:
            "Purchase pending approval"
        case .succeeded:
            "Premium unlocked"
        case .restored:
            "Premium restored"
        case .restoredNoPurchase:
            "No active purchase found"
        case .cancelled:
            "Purchase cancelled"
        case .failed(let message):
            message
        }
    }
}
#endif

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack {
            VStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(OffsetTheme.emerald)
                    .frame(width: 62, height: 62)
                    .background(OffsetTheme.surfaceHigh, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(OffsetTheme.text)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(OffsetTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 420)
            .offsetCard(padding: 28, elevated: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offsetScreen()
    }
}

#Preview("Onboarding") {
    ContentView()
        .environmentObject(AppState(store: PreviewAppStateStore()))
}

private struct PreviewAppStateStore: AppStateStoring {
    func load() throws -> AppStateSnapshot? { nil }
    func save(_ snapshot: AppStateSnapshot) throws {}
}
