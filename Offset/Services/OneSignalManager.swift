import Foundation
import OneSignalFramework
import UIKit

/// The single boundary around OneSignal SDK APIs.
final class OneSignalManager: NSObject,
    OSNotificationClickListener,
    OSNotificationLifecycleListener,
    OSPushSubscriptionObserver
{
    static let shared = OneSignalManager()

    private(set) var isConfigured = false
    private var pendingRoute: NotificationRoute?

    private override init() {}

    func initialize(appID: String, launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        guard !isConfigured else { return }
        isConfigured = true
        OneSignal.initialize(appID, withLaunchOptions: launchOptions)
        OneSignal.Notifications.addClickListener(self)
        OneSignal.Notifications.addForegroundLifecycleListener(self)
        OneSignal.User.pushSubscription.addObserver(self)
        evaluateRegistration(OneSignal.User.pushSubscription.id)
    }

    func requestPermission() async -> Bool {
        guard isConfigured else { return false }
        return await withCheckedContinuation { continuation in
            OneSignal.Notifications.requestPermission({ accepted in
                continuation.resume(returning: accepted)
            }, fallbackToSettings: true)
        }
    }

    var pushSubscriptionID: String? {
        guard isConfigured else { return nil }
        return OneSignal.User.pushSubscription.id
    }

    func announceRegistrationIfAvailable() {
        guard isConfigured else { return }
        evaluateRegistration(OneSignal.User.pushSubscription.id)
    }

    func onPushSubscriptionDidChange(state: OSPushSubscriptionChangedState) {
        evaluateRegistration(state.current.id)
    }

    func synchronizeUser(externalID: String, desiredTags: [String: String], managedTagKeys: Set<String>) {
        guard isConfigured else { return }
        OneSignal.login(externalId: externalID, token: nil)
        let existing = OneSignal.User.getTags()
        let changes = desiredTags.filter { existing[$0.key] != $0.value }
        let stale = existing.keys.filter { managedTagKeys.contains($0) && desiredTags[$0] == nil }.sorted()
        if !stale.isEmpty { OneSignal.User.removeTags(stale) }
        if !changes.isEmpty { OneSignal.User.addTags(changes) }
    }

    func consumePendingRoute() -> NotificationRoute? {
        defer { pendingRoute = nil }
        return pendingRoute
    }

    func onClick(event: OSNotificationClickEvent) {
        let route = NotificationRoute.parse(additionalData: event.notification.additionalData)
            ?? event.result.url.flatMap(URL.init(string:)).flatMap { NotificationRoute.parse(url: $0) }
        guard let route else { return }
        DispatchQueue.main.async {
            self.pendingRoute = route
            NotificationCenter.default.post(name: .offsetNotificationRoute, object: route)
        }
    }

    func onWillDisplay(event _: OSNotificationWillDisplayEvent) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .offsetForegroundNotificationReceived, object: nil)
        }
    }

    private func evaluateRegistration(_ subscriptionID: String?) {
        guard let subscriptionID,
              !subscriptionID.isEmpty,
              !subscriptionID.hasPrefix("local-") else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .offsetOneSignalRegistrationCompleted,
                object: subscriptionID
            )
        }
    }
}

extension Notification.Name {
    static let offsetOneSignalRegistrationCompleted = Notification.Name(
        "offset.onesignal.registration-completed"
    )
}
