//
//  OffsetApp.swift
//  Offset
//
//  Created by Sujal Bhakare on 9/10/26.
//

import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let configuration = AppConfiguration()
        if let appID = configuration.oneSignalAppID {
            OneSignalManager.shared.initialize(appID: appID, launchOptions: launchOptions)
        }
        return true
    }

    func consumePendingRoute() -> NotificationRoute? {
        OneSignalManager.shared.consumePendingRoute()
    }
}

@main
struct OffsetApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appState: AppState
    @StateObject private var subscriptions: SubscriptionService
    @StateObject private var notifications: NotificationService

    init() {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset-state") {
            UserDefaults.standard.removeObject(forKey: "offset.app-state.v1")
        }
#endif
        let configuration = AppConfiguration()
        _appState = StateObject(wrappedValue: AppState())
        _subscriptions = StateObject(wrappedValue: SubscriptionService(configuration: configuration))
        _notifications = StateObject(wrappedValue: NotificationService(configuration: configuration))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(subscriptions)
                .environmentObject(notifications)
                .tint(OffsetTheme.emerald)
                .task {
                    await subscriptions.refresh()
                    if let route = appDelegate.consumePendingRoute() {
                        appState.openNotificationRoute(route)
                    }
                }
                .task(id: "\(appState.notificationSyncRevision)-\(subscriptions.hasPremiumAccess)") {
                    await synchronizeNotifications()
                }
                .onReceive(NotificationCenter.default.publisher(for: .offsetForegroundNotificationReceived)) { _ in
                    notifications.recordForegroundReceipt()
                }
                .onChange(of: scenePhase) { phase in
                    guard phase == .active else { return }
                    Task {
                        await subscriptions.refreshEntitlement()
                        await synchronizeNotifications()
                    }
                }
        }
    }

    private func synchronizeNotifications() async {
        await notifications.synchronize(context: NotificationSyncContext(
            profile: appState.profile,
            savedProjects: appState.savedProjects,
            latestPricerDraft: appState.latestPricerDraft,
            completedClaimSteps: appState.completedClaimSteps,
            preferences: appState.notificationPreferences,
            hasCompletedOnboarding: appState.hasCompletedOnboarding,
            hasPremiumAccess: subscriptions.hasPremiumAccess
        ))
    }
}
