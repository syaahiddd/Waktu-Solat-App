import WidgetKit
import SwiftUI

/// One widget used by both the iPhone widget extension and the Apple Watch complication extension.
struct PrayerWidget: Widget {
    let kind = "WaktuSolatWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            PrayerWidgetView(entry: entry)
        }
        .configurationDisplayName("Waktu Solat")
        .description("Next prayer time for your JAKIM zone.")
        .supportedFamilies(Self.families)
    }

    static var families: [WidgetFamily] {
        #if os(watchOS)
        return [.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner]
        #else
        return [.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        #endif
    }
}

// MARK: - Router

struct PrayerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerEntry

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if isHomeScreen {
                    LinearGradient(colors: [.teal, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                } else {
                    Color.clear
                }
            }
    }

    private var isHomeScreen: Bool {
        #if os(iOS)
        return family == .systemSmall || family == .systemMedium
        #else
        return false
        #endif
    }

    /// Picks the layout for the current widget size / complication slot.
    private var content: AnyView {
        guard entry.next != nil else { return AnyView(EmptyStateView()) }
        #if os(iOS)
        if family == .systemSmall { return AnyView(SmallWidgetView(entry: entry)) }
        if family == .systemMedium { return AnyView(MediumWidgetView(entry: entry)) }
        #endif
        #if os(watchOS)
        if family == .accessoryCorner { return AnyView(CornerView(entry: entry)) }
        #endif
        switch family {
        case .accessoryCircular: return AnyView(CircularView(entry: entry))
        case .accessoryInline: return AnyView(InlineView(entry: entry))
        default: return AnyView(RectangularView(entry: entry))
        }
    }
}

// MARK: - Shared bits

private let shortTime = Date.FormatStyle.dateTime.hour(.defaultDigits(amPM: .omitted)).minute()
private let fullTime = Date.FormatStyle.dateTime.hour().minute()

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "moon.stars")
            Text("Open Waktu Solat")
                .font(.caption2)
                .multilineTextAlignment(.center)
        }
    }
}

private struct Countdown: View {
    let entry: PrayerEntry
    let next: PrayerMoment

    var body: some View {
        Text(timerInterval: entry.date...max(entry.date, next.time), countsDown: true)
            .monospacedDigit()
    }
}

// MARK: - iPhone Home Screen

#if os(iOS)
private struct SmallWidgetView: View {
    let entry: PrayerEntry

    var body: some View {
        if let next = entry.next {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "moon.stars.fill")
                    Text(entry.zoneCode ?? "")
                }
                .font(.caption2.bold())
                .opacity(0.8)

                Spacer(minLength: 0)

                Text("Next")
                    .font(.caption)
                    .opacity(0.8)
                Label(next.prayer.name, systemImage: next.prayer.symbol)
                    .font(.title3.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(next.time, format: fullTime)
                    .font(.title2.weight(.semibold))
                Countdown(entry: entry, next: next)
                    .font(.caption)
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

private struct MediumWidgetView: View {
    let entry: PrayerEntry

    var body: some View {
        HStack(spacing: 12) {
            SmallWidgetView(entry: entry)

            if let day = entry.day {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Prayer.fard) { prayer in
                        let isNext = entry.next?.prayer == prayer
                            && Calendar.malaysia.isDate(entry.next!.time, inSameDayAs: day.date)
                        HStack {
                            Text(prayer.name)
                            Spacer()
                            Text(day.time(prayer), format: fullTime)
                                .monospacedDigit()
                        }
                        .font(.caption.weight(isNext ? .bold : .regular))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isNext ? Color.white.opacity(0.25) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 6))
                    }
                    Text(day.hijriDisplay)
                        .font(.caption2)
                        .opacity(0.8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
            }
        }
    }
}
#endif

// MARK: - Lock Screen & Watch complications

private struct CircularView: View {
    let entry: PrayerEntry

    var body: some View {
        if let next = entry.next {
            // Ring empties from the previous prayer to the next one; the system animates it live.
            ProgressView(timerInterval: min(entry.countdownStart, next.time)...next.time, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                VStack(spacing: 0) {
                    Text(next.prayer.shortName)
                        .font(.system(size: 10, weight: .semibold))
                        .widgetAccentable()
                    Text(next.time, style: .timer)
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            }
            .progressViewStyle(.circular)
        }
    }
}

private struct RectangularView: View {
    let entry: PrayerEntry

    var body: some View {
        if let next = entry.next {
            VStack(alignment: .leading, spacing: 0) {
                // Next prayer and its time
                HStack(spacing: 4) {
                    Image(systemName: next.prayer.symbol)
                    Text(next.prayer.name)
                    Spacer(minLength: 2)
                    Text(next.time, format: fullTime)
                }
                .font(.headline)
                .widgetAccentable()

                // Countdown right below it
                Text(next.time, style: .timer)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .monospacedDigit()

                Text(entry.zoneCode ?? "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct InlineView: View {
    let entry: PrayerEntry

    var body: some View {
        if let next = entry.next {
            Label {
                Text("\(next.prayer.name) · \(next.time, style: .timer)")
            } icon: {
                Image(systemName: next.prayer.symbol)
            }
        }
    }
}

#if os(watchOS)
private struct CornerView: View {
    let entry: PrayerEntry

    var body: some View {
        if let next = entry.next {
            Image(systemName: next.prayer.symbol)
                .font(.title3)
                .widgetAccentable()
                .widgetLabel {
                    Text("\(next.prayer.name) \(next.time, style: .timer)")
                }
        }
    }
}
#endif
