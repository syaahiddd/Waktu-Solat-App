import SwiftUI

struct ZonePickerView: View {
    @EnvironmentObject private var model: PrayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private struct StateGroup: Identifiable {
        let state: String
        let zones: [JakimZone]
        var id: String { state }
    }

    private var filteredStates: [StateGroup] {
        let query = TextMatch.normalize(search)
        return Zones.states.compactMap { state in
            let zones = Zones.all.filter { zone in
                zone.state == state && (query.isEmpty
                    || TextMatch.normalize(zone.code + " " + zone.state + " " + zone.areas).contains(query))
            }
            return zones.isEmpty ? nil : StateGroup(state: state, zones: zones)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        model.useGPS()
                        dismiss()
                    } label: {
                        Label("Detect automatically (GPS)", systemImage: "location.fill")
                    }
                } footer: {
                    Text("The zone updates from your location each time you open the app.")
                }

                ForEach(filteredStates) { group in
                    Section(group.state) {
                        ForEach(group.zones) { zone in
                            Button {
                                model.selectZone(zone)
                                dismiss()
                            } label: {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(zone.code).font(.headline)
                                        Text(zone.areas).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if !model.autoLocate && model.zone == zone {
                                        Image(systemName: "checkmark").foregroundStyle(.tint)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Search town or zone code")
            .navigationTitle("JAKIM Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
