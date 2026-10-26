import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var tracker: TimeTracker

    var body: some View {
        Form {
            Section("Arbeitszeit") {
                TextField("Wochenstunden", value: number(\.weeklyHours), format: .number)
                Text("Das sind \(Format.hm(tracker.settings.dailyTarget)) h pro Tag (Montag bis Freitag).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Pausen automatisch abziehen", isOn: $tracker.settings.autoBreak)
                Text("30 Minuten ab 6 Stunden, 45 Minuten ab 9 Stunden. Wenn du zwischendurch ausstempelst, zählt diese Zeit schon als Pause.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Bundesland (für Feiertage)", selection: $tracker.settings.bundesland) {
                    ForEach(Bundesland.allCases) { land in
                        Text(land.rawValue).tag(land)
                    }
                }
            }

            Section("Urlaub") {
                TextField("Urlaubstage pro Jahr", value: number(\.vacationDaysPerYear), format: .number)
                TextField("Resturlaub aus dem Vorjahr", value: number(\.vacationCarryover), format: .number)
            }

            Section("Startwerte") {
                DatePicker("Zeiterfassung ab", selection: $tracker.settings.startDate, displayedComponents: .date)
                TextField("Überstunden bis dahin (in Stunden)", value: number(\.overtimeCarryoverHours), format: .number)
            }

            Section("System") {
                Toggle("Beim Anmelden automatisch starten", isOn: $tracker.launchAtLogin)
                LabeledContent("Datenordner") {
                    Text(tracker.store.folder.path)
                        .font(.caption)
                        .textSelection(.enabled)
                }
                Button("Datenordner im Finder öffnen") { tracker.openDataFolder() }
            }
        }
        .formStyle(.grouped)
    }

    /// Schreibt nur bei einer echten Änderung zurück. Zahlenfelder geben beim Aufbau
    /// sonst denselben Wert nochmal ab und lösen mitten im Rendern eine Änderung aus.
    private func number(_ keyPath: WritableKeyPath<AppSettings, Double>) -> Binding<Double> {
        Binding(
            get: { tracker.settings[keyPath: keyPath] },
            set: { newValue in
                if tracker.settings[keyPath: keyPath] != newValue {
                    tracker.settings[keyPath: keyPath] = newValue
                }
            }
        )
    }
}
