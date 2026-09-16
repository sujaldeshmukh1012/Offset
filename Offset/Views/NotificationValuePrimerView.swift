import SwiftUI
import UIKit

struct NotificationValuePrimerView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var notifications: NotificationService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var isRequesting = false
    @State private var permissionWasDenied = false
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(OffsetTheme.emerald)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 10) {
                        OffsetEyebrow(text: "Deadline reminders")
                        Text("Keep every savings deadline in view")
                            .font(.title.weight(.bold))
                            .foregroundStyle(OffsetTheme.text)
                        Text("Offset can remind you 30, 14, and 7 days before a matched program closes, with a tap taking you straight to its claim details.")
                            .foregroundStyle(OffsetTheme.secondaryText)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        benefit(icon: "calendar.badge.clock", title: "Timely, not noisy", detail: "Only dated programs with unfinished claim steps create reminders.")
                        benefit(icon: "arrow.trianglehead.2.clockwise", title: "Always current", detail: "Profile, project, and checklist changes automatically update or remove reminders.")
                        benefit(icon: "lock.shield", title: "You stay in control", detail: "Your full profile remains on this device. You can turn reminders off at any time.")
                    }
                    .padding(18)
                    .background(OffsetTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(OffsetTheme.outline, lineWidth: 1)
                    }

                    if permissionWasDenied {
                        Text("Notifications are currently off. Enable them in iOS Settings whenever you’re ready.")
                            .font(.footnote)
                            .foregroundStyle(OffsetTheme.secondaryText)
                            .accessibilityIdentifier("notifications.permission-denied")
                    }

                    VStack(spacing: 12) {
                        Button(permissionWasDenied ? "Open iOS Settings" : "Enable reminders") {
                            if permissionWasDenied {
                                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                    openURL(settingsURL)
                                }
                            } else {
                                enableReminders()
                            }
                        }
                        .buttonStyle(OffsetPrimaryButtonStyle())
                        .disabled(isRequesting)
                        .accessibilityIdentifier("notifications.enable")

                        Button("Not now") {
                            onDismiss()
                            dismiss()
                        }
                            .buttonStyle(OffsetSecondaryButtonStyle())
                            .disabled(isRequesting)
                            .accessibilityIdentifier("notifications.not-now")
                    }
                }
                .padding(24)
            }
            .offsetScreen()
            .navigationTitle("Stay on track")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
    }

    private func benefit(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(OffsetTheme.emerald)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(OffsetTheme.text)
                Text(detail).font(.subheadline).foregroundStyle(OffsetTheme.secondaryText)
            }
        }
    }

    private func enableReminders() {
        isRequesting = true
        Task {
            let accepted = await notifications.requestPermission()
            appState.setDeadlineRemindersEnabled(accepted)
            isRequesting = false
            permissionWasDenied = !accepted
            if accepted {
                onDismiss()
                dismiss()
            }
        }
    }
}
