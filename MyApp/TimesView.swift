import SwiftUI

/// Monatsübersicht links, Details zum gewählten Tag rechts.
struct TimesView: View {
    @EnvironmentObject private var tracker: TimeTracker
    @State private var month = TimesView.startOfMonth(Date())
    @State private var selectedDay: Date? = Calendar.current.startOfDay(for: Date())

    private static func startOfMonth(_ date: Date) -> Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
    }

    private var days: [Date] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        return range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: month) }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack {
                    Button { changeMonth(by: -1) } label: { Image(systemName: "chevron.left") }
                    Spacer()
                    Text(Format.month.string(from: month)).font(.headline)
                    Spacer()
                    Button { changeMonth(by: 1) } label: { Image(systemName: "chevron.right") }
                }
                List(days, id: \.self, selection: $selectedDay) { day in
                    DayRow(summary: tracker.summary(for: day))
                }
                monthFooter
            }
            .frame(width: 340)
            .padding(.trailing, 12)

            Divider()

            Group {
                if let day = selectedDay {
                    DayDetailView(day: day)
                } else {
                    Text("Wähle links einen Tag aus.").foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, 16)
        }
    }

    private var monthFooter: some View {
        let summaries = days.map { tracker.summary(for: $0) }.filter(\.counts)
        let worked = summaries.reduce(0.0) { $0 + $1.worked }
        let diff = summaries.reduce(0.0) { $0 + $1.diff }
        return HStack {
            Text("Monat: \(Format.hm(worked)) h gearbeitet")
            Spacer()
            Text(Format.hm(diff, signed: true) + " h")
                .foregroundStyle(diff < 0 ? Color.red : Color.green)
        }
        .font(.callout)
        .monospacedDigit()
    }

    private func changeMonth(by value: Int) {
        month = Calendar.current.date(byAdding: .month, value: value, to: month) ?? month
    }
}

struct DayRow: View {
    let summary: DaySummary

    var body: some View {
        HStack(spacing: 8) {
            Text(Format.dayShort.string(from: summary.day))
                .monospacedDigit()
                .foregroundStyle(summary.isWeekend ? Color.secondary : Color.primary)
                .frame(width: 85, alignment: .leading)
            if let holiday = summary.holiday {
                Text(holiday).font(.caption).foregroundStyle(.purple).lineLimit(1)
            } else if let absence = summary.absences.first {
                Text(absence.label)
                    .font(.caption)
                    .foregroundStyle(absence.type == .krank ? Color.orange : Color.blue)
            }
            Spacer()
            if summary.gross > 0 {
                Text(Format.hm(summary.worked)).monospacedDigit()
            }
            if summary.counts && (summary.target > 0 || summary.worked > 0) {
                Text(Format.hm(summary.diff, signed: true))
                    .monospacedDigit()
                    .foregroundStyle(summary.diff < 0 ? Color.red : Color.green)
                    .frame(width: 55, alignment: .trailing)
            }
        }
    }
}

struct DayDetailView: View {
    @EnvironmentObject private var tracker: TimeTracker
    let day: Date

    var body: some View {
        let summary = tracker.summary(for: day)
        let list = tracker.daySessions(on: day)

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(Format.dayLong.string(from: day)).font(.title2.bold())

                if let holiday = summary.holiday {
                    Label("Feiertag: \(holiday)", systemImage: "star.fill").foregroundStyle(.purple)
                }
                ForEach(summary.absences) { absence in
                    HStack {
                        Label(absenceText(absence), systemImage: absence.type.symbol)
                        Spacer()
                        Button("Entfernen") { tracker.deleteAbsence(absence.id) }
                    }
                }

                Text("Arbeitszeiten").font(.headline)
                if list.isEmpty {
                    Text("Keine Einträge für diesen Tag.").foregroundStyle(.secondary)
                }
                ForEach(list) { session in
                    HStack(spacing: 12) {
                        DatePicker("Von", selection: tracker.startBinding(session.id),
                                   displayedComponents: .hourAndMinute)
                            .fixedSize()
                        if session.end != nil {
                            DatePicker("Bis", selection: tracker.endBinding(session.id),
                                       displayedComponents: .hourAndMinute)
                                .fixedSize()
                        } else {
                            Text("läuft …").foregroundStyle(.green)
                        }
                        Spacer()
                        Text(Format.hm(session.duration()) + " h").monospacedDigit()
                        Button { tracker.deleteSession(session.id) } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Eintrag löschen")
                    }
                }
                Button { tracker.addSession(on: day) } label: {
                    Label("Zeitraum hinzufügen", systemImage: "plus")
                }

                Divider()

                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                    GridRow {
                        Text("Anwesend")
                        Text(Format.hm(summary.gross) + " h")
                    }
                    if summary.breakDeduction > 0 {
                        GridRow {
                            Text("Automatischer Pausenabzug")
                            Text("−" + Format.hm(summary.breakDeduction) + " h")
                        }
                    }
                    GridRow {
                        Text("Gearbeitet").bold()
                        Text(Format.hm(summary.worked) + " h").bold()
                    }
                    GridRow {
                        Text("Soll")
                        Text(Format.hm(summary.target) + " h")
                    }
                    if summary.counts {
                        GridRow {
                            Text("Differenz")
                            Text(Format.hm(summary.diff, signed: true) + " h")
                                .foregroundStyle(summary.diff < 0 ? Color.red : Color.green)
                        }
                    }
                }
                .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func absenceText(_ absence: Absence) -> String {
        absence.note.isEmpty ? absence.label : absence.label + " – " + absence.note
    }
}
