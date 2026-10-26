import SwiftUI

/// Urlaub und Krankheit eintragen und ansehen.
struct AbsencesView: View {
    @EnvironmentObject private var tracker: TimeTracker
    @State private var type: AbsenceType = .urlaub
    @State private var from = Date()
    @State private var to = Date()
    @State private var halfDay = false
    @State private var note = ""
    @State private var message: String?
    @State private var year = Calendar.current.component(.year, from: Date())

    private var entries: [Absence] {
        tracker.absences
            .filter { Calendar.current.component(.year, from: $0.date) == year }
            .sorted(by: { $0.date > $1.date })
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Form {
                Section("Neu eintragen") {
                    Picker("Art", selection: $type) {
                        ForEach(AbsenceType.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    DatePicker("Von", selection: $from, displayedComponents: .date)
                    DatePicker("Bis", selection: $to, in: from..., displayedComponents: .date)
                    Toggle("Nur halbe Tage", isOn: $halfDay)
                    TextField("Notiz (optional)", text: $note)
                    Button("Eintragen", action: submit)
                        .keyboardShortcut(.defaultAction)
                    if let message {
                        Text(message).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Text("Wochenenden und Feiertage werden automatisch übersprungen. Ein bestehender Eintrag am selben Tag wird ersetzt.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .frame(width: 350)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button { year -= 1 } label: { Image(systemName: "chevron.left") }
                    Text(String(year)).font(.title2.bold()).monospacedDigit()
                    Button { year += 1 } label: { Image(systemName: "chevron.right") }
                }

                let vacation = tracker.vacationStatus(year: year)
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 4) {
                    GridRow { Text("Urlaubsanspruch"); Text(Format.days(vacation.entitlement) + " Tage") }
                    GridRow { Text("Genommen"); Text(Format.days(vacation.taken) + " Tage") }
                    GridRow { Text("Geplant"); Text(Format.days(vacation.planned) + " Tage") }
                    GridRow { Text("Verfügbar").bold(); Text(Format.days(vacation.remaining) + " Tage").bold() }
                    GridRow { Text("Krankheitstage"); Text(Format.days(tracker.sickDays(year: year)) + " Tage") }
                }
                .monospacedDigit()

                List {
                    if entries.isEmpty {
                        Text("Keine Einträge in diesem Jahr.").foregroundStyle(.secondary)
                    }
                    ForEach(entries) { absence in
                        HStack {
                            Image(systemName: absence.type.symbol)
                                .foregroundStyle(absence.type == .krank ? Color.orange : Color.blue)
                            Text(Format.date.string(from: absence.date)).monospacedDigit()
                            Text(absence.label)
                            if !absence.note.isEmpty {
                                Text(absence.note).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Button { tracker.deleteAbsence(absence.id) } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Eintrag löschen")
                        }
                    }
                }
            }
        }
    }

    private func submit() {
        let count = tracker.addAbsence(from: from, to: max(from, to), type: type, halfDay: halfDay, note: note)
        let days = Format.days(halfDay ? Double(count) / 2 : Double(count))
        let kind = type == .urlaub ? "Urlaubstag(e)" : "Krankheitstag(e)"
        message = count == 0
            ? "Im Zeitraum liegen keine Arbeitstage."
            : "\(days) \(kind) eingetragen."
        note = ""
        year = Calendar.current.component(.year, from: from)
    }
}
