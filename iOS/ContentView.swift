import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: PrayerViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingZonePicker = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ZoneHeader(zone: model.zone, placeName: model.placeName, autoLocate: model.autoLocate)

                    if let schedule = model.schedule {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            ScheduleSection(schedule: schedule, now: context.date)
                        }
                    } else if model.isLoading {
                        ProgressView("Getting times from JAKIM…")
                            .padding(.top, 40)
                    } else {
                        ContentUnavailableView(
                            "No prayer times yet",
                            systemImage: "moon.stars",
                            description: Text(model.errorMessage ?? "Tap the location button or choose a zone.")
                        )
                    }

                    if let error = model.errorMessage, model.schedule != nil {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Text("Source: JAKIM e-Solat (e-solat.gov.my)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding()
            }
            .navigationTitle("Waktu Solat")
            .refreshable { await model.refresh(force: true) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if model.isLoading {
                        ProgressView()
                    } else {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: model.notificationsEnabled ? "bell.fill" : "bell")
                        }
                        .accessibilityLabel("Notifications and settings")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        model.useGPS()
                    } label: {
                        Image(systemName: model.autoLocate ? "location.fill" : "location")
                    }
                    .accessibilityLabel("Use my location")

                    Button {
                        showingZonePicker = true
                    } label: {
                        Image(systemName: "map")
                    }
                    .accessibilityLabel("Choose zone")
                }
            }
            .sheet(isPresented: $showingZonePicker) {
                ZonePickerView()
                    .environmentObject(model)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(model)
            }
        }
        .task { await model.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refresh() } }
        }
    }
}

// MARK: - Header

private struct ZoneHeader: View {
    let zone: JakimZone?
    let placeName: String?
    let autoLocate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: autoLocate ? "location.fill" : "mappin.and.ellipse")
                Text(zone?.code ?? "No zone")
                    .font(.headline)
                if let zone {
                    Text(zone.state)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            if let placeName {
                Text(placeName)
                    .font(.subheadline)
            }
            if let zone {
                Text(zone.areas)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Schedule

private struct ScheduleSection: View {
    let schedule: PrayerSchedule
    let now: Date

    var body: some View {
        let today = schedule.day(for: now)
        let next = schedule.next(after: now)
        let current = schedule.current(at: now)

        VStack(spacing: 16) {
            if let next {
                NextPrayerCard(next: next, now: now)
            }

            if let today {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(today.date, format: .dateTime.weekday(.wide).day().month(.wide).year())
                        Spacer()
                        Text(today.hijriDisplay)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)

                    ForEach(Prayer.allCases) { prayer in
                        PrayerRow(prayer: prayer,
                                  time: today.time(prayer),
                                  isCurrent: current?.prayer == prayer,
                                  isNext: next?.prayer == prayer && Calendar.malaysia.isDate(next!.time, inSameDayAs: now))
                    }
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            } else {
                Text("Today's times aren't cached yet. Pull down to refresh.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct NextPrayerCard: View {
    let next: PrayerMoment
    let now: Date

    var body: some View {
        VStack(spacing: 6) {
            Text("Next prayer")
                .font(.subheadline)
                .opacity(0.85)
            Label(next.prayer.name, systemImage: next.prayer.symbol)
                .font(.largeTitle.bold())
            Text(next.time, format: .dateTime.hour().minute())
                .font(.title2.weight(.semibold))
            Text(timerInterval: now...max(now, next.time), countsDown: true)
                .font(.title3.monospacedDigit())
                .opacity(0.9)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            LinearGradient(colors: [.teal, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20)
        )
    }
}

private struct PrayerRow: View {
    let prayer: Prayer
    let time: Date
    let isCurrent: Bool
    let isNext: Bool

    var body: some View {
        HStack {
            Image(systemName: prayer.symbol)
                .frame(width: 28)
            Text(prayer.name)
                .fontWeight(isCurrent ? .bold : .regular)
            if isCurrent {
                Text("now").font(.caption2.bold())
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2), in: Capsule())
            } else if isNext {
                Text("next").font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(time, format: .dateTime.hour().minute())
                .monospacedDigit()
                .fontWeight(isCurrent ? .bold : .regular)
        }
        .foregroundStyle(prayer.isFard ? Color.primary : Color.secondary)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(isCurrent ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 10))
    }
}
