import SwiftUI

/// Screens the watch app can navigate to.
enum WatchRoute: Hashable {
    case states
    case zones(state: String)
}

struct WatchContentView: View {
    @EnvironmentObject private var model: WatchModel
    @State private var path: [WatchRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let schedule = model.schedule {
                    TimelineView(.everyMinute) { context in
                        ScheduleList(schedule: schedule, now: context.date)
                    }
                } else if model.isRefreshing {
                    ProgressView()
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            Image(systemName: "moon.stars")
                                .font(.title2)
                                .foregroundStyle(.tint)
                            Text("Choose your JAKIM zone, or open Waktu Solat on your iPhone.")
                                .multilineTextAlignment(.center)
                                .font(.footnote)
                            NavigationLink(value: WatchRoute.states) {
                                Label("Choose zone", systemImage: "mappin.and.ellipse")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Waktu Solat")
            .navigationDestination(for: WatchRoute.self) { route in
                switch route {
                case .states:
                    StateList()
                case .zones(let state):
                    ZoneList(state: state) { zone in
                        model.selectZone(zone)
                        path.removeAll()
                    }
                }
            }
        }
        .task { await model.refresh() }
    }
}

// MARK: - Zone picker

private struct StateList: View {
    var body: some View {
        List(Zones.states, id: \.self) { state in
            NavigationLink(state, value: WatchRoute.zones(state: state))
        }
        .navigationTitle("State")
    }
}

private struct ZoneList: View {
    let state: String
    let onPick: (JakimZone) -> Void

    var body: some View {
        List(Zones.all.filter { $0.state == state }) { zone in
            Button {
                onPick(zone)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(zone.code).font(.headline)
                    Text(zone.areas)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        }
        .navigationTitle(state)
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
                NavigationLink(value: WatchRoute.states) {
                    Label("Zone \(schedule.zoneCode)", systemImage: "mappin.and.ellipse")
                        .font(.footnote)
                }
            } footer: {
                Text("Prayer times from JAKIM e-Solat")
            }
        }
    }
}
