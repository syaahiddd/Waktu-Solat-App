import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var model: PrayerViewModel
    @Environment(\.dismiss) private var dismiss

    private let reminderOptions = [0, 5, 10, 15, 30]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Prayer time alerts", isOn: Binding(
                        get: { model.notificationsEnabled },
                        set: { model.setNotifications($0) }
                    ))

                    Picker("Remind me before", selection: Binding(
                        get: { model.reminderMinutes },
                        set: { model.setReminder($0) }
                    )) {
                        ForEach(reminderOptions, id: \.self) { minutes in
                            Text(minutes == 0 ? "Off" : "\(minutes) min").tag(minutes)
                        }
                    }
                    .disabled(!model.notificationsEnabled)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Alerts for Subuh, Zohor, Asar, Maghrib and Isyak, using the default sound. They also appear on your Apple Watch when your iPhone is locked. Open the app at least once a week to keep them scheduled.")
                }

                if model.notificationsDenied {
                    Section {
                        Text("Notifications are turned off for Waktu Solat.")
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            Link("Open Settings", destination: url)
                        }
                    }
                }

                Section("About") {
                    LabeledContent("Prayer times", value: "JAKIM e-Solat")
                    if let zone = model.zone {
                        LabeledContent("Zone", value: zone.code)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
