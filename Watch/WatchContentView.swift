import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject private var model: WatchModel

    var body: some View {
        NavigationStack {
            Group {
                if let schedule = model.schedule {
                    TimelineView(.everyMinute) { context in
                        ScheduleList(schedule: schedule, now: context.date)
                    }
                } else if model.isRefreshing {
                    ProgressView()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "iphone")
                            .font(.title2)
                        Text("Open Waktu Solat on your iPhone to set your zone.")
                            .multilineTextAlignment(.center)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Waktu Solat")
        }
        .task { await model.refresh() }
    }
}

private struct ScheduleList: View {
    let schedule: PrayerSchedule
    let now: Date

    var body: some View {
        let next = schedule.next(after: now)
        let current = schedule.current(at: now)

        List {
            if let next {
                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Label(next.prayer.name, systemImage: next.prayer.symbol)
                            .font(.title3.bold())
                            .foregroundStyle(.tint)
                        Text(next.time, format: .dateTime.hour().minute())
                            .font(.headline)
                        Text(timerInterval: now...max(now, next.time), countsDown: true)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let today = schedule.day(for: now) {
                Section {
                    ForEach(Prayer.allCases) { prayer in
                        HStack {
                            Image(systemName: prayer.symbol)
                                .frame(width: 20)
                            Text(prayer.name)
                            Spacer()
                            Text(today.time(prayer), format: .dateTime.hour().minute())
                                .monospacedDigit()
                        }
                        .font(.footnote)
                        .fontWeight(current?.prayer == prayer ? .bold : .regular)
                        .foregroundStyle(current?.prayer == prayer ? Color.accentColor
                                         : (prayer.isFard ? Color.primary : Color.secondary))
                    }
                } header: {
                    Text(today.hijriDisplay)
                }
            }

            Section {
                Text("Zone \(schedule.zoneCode) · JAKIM")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
