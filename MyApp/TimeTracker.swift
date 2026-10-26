import SwiftUI
import AppKit
import Combine
import ServiceManagement

enum MainTab: Hashable {
    case zeiten, abwesenheiten, einstellungen
}

struct DaySummary {
    let day: Date
    let gross: TimeInterval            // Summe aller Zeiträume
    let breakDeduction: TimeInterval   // automatischer Pausenabzug
    let target: TimeInterval           // Soll
    let holiday: String?
    let absences: [Absence]
    let isWeekend: Bool
    let counts: Bool                   // zählt dieser Tag schon zum Überstundenkonto?

    var worked: TimeInterval { gross - breakDeduction }
    var diff: TimeInterval { worked - target }
}

struct VacationStatus {
    let entitlement: Double
    let taken: Double
    let planned: Double
    var remaining: Double { entitlement - taken - planned }
}

final class TimeTracker: ObservableObject {
    @Published private(set) var sessions: [WorkSession]
    @Published private(set) var absences: [Absence]
    @Published var settings: AppSettings {
        didSet { if settings != oldValue { store.saveSettings(settings) } }
    }
    @Published var selectedTab: MainTab = .zeiten

    let store: DataStore
    private let cal = Calendar.current

    init() {
        let store = DataStore()
        self.store = store
        self.settings = store.loadSettings()
        self.sessions = store.loadSessions()
        self.absences = store.loadAbsences()
    }

    // MARK: - Ein- und Ausstempeln

    var runningSession: WorkSession? { sessions.first(where: { $0.end == nil }) }
    var isRunning: Bool { runningSession != nil }

    func startWork() {
        guard !isRunning else { return }
        sessions.append(WorkSession(start: Date()))
        store.saveSessions(sessions)
    }

    func stopWork() {
        guard let i = sessions.firstIndex(where: { $0.end == nil }) else { return }
        sessions[i].end = Date()
        store.saveSessions(sessions)
    }

    // MARK: - Zeiten bearbeiten

    func addSession(on day: Date) {
        let start = cal.date(bySettingHour: 8, minute: 0, second: 0, of: day) ?? day
        let pause: TimeInterval = settings.autoBreak ? 30 * 60 : 0
        sessions.append(WorkSession(start: start, end: start.addingTimeInterval(settings.dailyTarget + pause)))
        store.saveSessions(sessions)
    }

    func deleteSession(_ id: UUID) {
        sessions.removeAll(where: { $0.id == id })
        store.saveSessions(sessions)
    }

    func startBinding(_ id: UUID) -> Binding<Date> {
        Binding(
            get: { self.sessions.first(where: { $0.id == id })?.start ?? Date() },
            set: { newValue in self.modifySession(id) { $0.start = newValue } }
        )
    }

    func endBinding(_ id: UUID) -> Binding<Date> {
        Binding(
            get: { self.sessions.first(where: { $0.id == id })?.end ?? Date() },
            set: { newValue in self.modifySession(id) { $0.end = newValue } }
        )
    }

    private func modifySession(_ id: UUID, _ change: (inout WorkSession) -> Void) {
        guard let i = sessions.firstIndex(where: { $0.id == id }) else { return }
        var updated = sessions[i]
        change(&updated)
        guard updated != sessions[i] else { return }
        sessions[i] = updated
        store.saveSessions(sessions)
    }

    // MARK: - Urlaub & Krankheit

    /// Trägt alle Arbeitstage im Zeitraum ein und gibt deren Anzahl zurück.
    @discardableResult
    func addAbsence(from: Date, to: Date, type: AbsenceType, halfDay: Bool, note: String) -> Int {
        var day = cal.startOfDay(for: min(from, to))
        let last = cal.startOfDay(for: max(from, to))
        var count = 0
        while day <= last {
            if isWorkday(day) {
                absences.removeAll(where: { cal.isDate($0.date, inSameDayAs: day) })
                absences.append(Absence(date: day, type: type, fraction: halfDay ? 0.5 : 1, note: note))
                count += 1
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        absences.sort(by: { $0.date < $1.date })
        store.saveAbsences(absences)
        return count
    }

    func deleteAbsence(_ id: UUID) {
        absences.removeAll(where: { $0.id == id })
        store.saveAbsences(absences)
    }

    // MARK: - Berechnungen

    func holidayName(for day: Date) -> String? {
        Holidays.all(year: cal.component(.year, from: day), state: settings.bundesland)[cal.startOfDay(for: day)]
    }

    func isWorkday(_ day: Date) -> Bool {
        let weekday = cal.component(.weekday, from: day)
        return weekday != 1 && weekday != 7 && holidayName(for: day) == nil
    }

    func daySessions(on day: Date) -> [WorkSession] {
        sessions
            .filter { cal.isDate($0.start, inSameDayAs: day) }
            .sorted(by: { $0.start < $1.start })
    }

    func summary(for date: Date, now: Date = Date()) -> DaySummary {
        let day = cal.startOfDay(for: date)
        let dayAbsences = absences.filter { cal.isDate($0.date, inSameDayAs: day) }
        return evaluate(day: day, sessions: daySessions(on: day), absences: dayAbsences,
                        holiday: holidayName(for: day), now: now)
    }

    /// Überstundenkonto vom Startdatum bis heute.
    /// Der heutige Tag zählt erst, wenn du Feierabend gemacht hast.
    func overtimeBalance(now: Date = Date()) -> TimeInterval {
        let today = cal.startOfDay(for: now)
        let sessionsByDay = Dictionary(grouping: sessions, by: { cal.startOfDay(for: $0.start) })
        let absencesByDay = Dictionary(grouping: absences, by: { cal.startOfDay(for: $0.date) })
        var holidayCache: [Int: [Date: String]] = [:]
        var balance = settings.overtimeCarryoverHours * 3600
        var day = cal.startOfDay(for: settings.startDate)

        while day <= today {
            let year = cal.component(.year, from: day)
            if holidayCache[year] == nil {
                holidayCache[year] = Holidays.all(year: year, state: settings.bundesland)
            }
            let list = (sessionsByDay[day] ?? []).sorted(by: { $0.start < $1.start })
            let s = evaluate(day: day, sessions: list, absences: absencesByDay[day] ?? [],
                             holiday: holidayCache[year]?[day], now: now)
            if s.counts { balance += s.diff }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return balance
    }

    func vacationStatus(year: Int) -> VacationStatus {
        let today = cal.startOfDay(for: Date())
        let list = absences.filter { $0.type == .urlaub && cal.component(.year, from: $0.date) == year }
        let taken = list.filter { $0.date <= today }.reduce(0.0) { $0 + $1.fraction }
        let planned = list.filter { $0.date > today }.reduce(0.0) { $0 + $1.fraction }
        let carry = year == cal.component(.year, from: Date()) ? settings.vacationCarryover : 0
        return VacationStatus(entitlement: settings.vacationDaysPerYear + carry, taken: taken, planned: planned)
    }

    func sickDays(year: Int) -> Double {
        absences
            .filter { $0.type == .krank && cal.component(.year, from: $0.date) == year }
            .reduce(0.0) { $0 + $1.fraction }
    }

    private func evaluate(day: Date, sessions list: [WorkSession], absences dayAbsences: [Absence],
                          holiday: String?, now: Date) -> DaySummary {
        let gross = list.reduce(0.0) { $0 + $1.duration(now: now) }
        let deduction = breakDeduction(list, gross: gross)

        let weekday = cal.component(.weekday, from: day)
        let weekend = weekday == 1 || weekday == 7
        var target: TimeInterval = 0
        if !weekend && holiday == nil {
            let absent = dayAbsences.reduce(0.0) { $0 + $1.fraction }
            target = settings.dailyTarget * max(0, 1 - absent)
        }

        let today = cal.startOfDay(for: now)
        let counts: Bool
        if day < cal.startOfDay(for: settings.startDate) || day > today {
            counts = false
        } else if day == today {
            counts = !list.isEmpty && !list.contains(where: { $0.end == nil })
        } else {
            counts = true
        }

        return DaySummary(day: day, gross: gross, breakDeduction: deduction, target: target,
                          holiday: holiday, absences: dayAbsences, isWeekend: weekend, counts: counts)
    }

    /// Gesetzliche Mindestpause (30 min ab 6 h, 45 min ab 9 h).
    /// Lücken zwischen zwei Zeiträumen zählen bereits als Pause.
    private func breakDeduction(_ list: [WorkSession], gross: TimeInterval) -> TimeInterval {
        guard settings.autoBreak else { return 0 }
        let required: TimeInterval = gross > 9 * 3600 ? 45 * 60 : (gross > 6 * 3600 ? 30 * 60 : 0)
        var gaps: TimeInterval = 0
        for (a, b) in zip(list, list.dropFirst()) {
            if let end = a.end { gaps += max(0, b.start.timeIntervalSince(end)) }
        }
        return max(0, required - gaps)
    }

    // MARK: - System

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            objectWillChange.send()
            do {
                if newValue { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                print("Autostart konnte nicht geändert werden: \(error)")
            }
        }
    }

    func openDataFolder() {
        NSWorkspace.shared.open(store.folder)
    }
}
