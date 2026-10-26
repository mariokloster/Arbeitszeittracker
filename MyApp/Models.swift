import Foundation

/// Ein Arbeitsblock: von „Arbeit beginnen“ bis „Feierabend“.
struct WorkSession: Identifiable, Equatable {
    let id: UUID
    var start: Date
    var end: Date?          // nil = läuft gerade

    init(id: UUID = UUID(), start: Date, end: Date? = nil) {
        self.id = id
        self.start = start
        self.end = end
    }

    func duration(now: Date = Date()) -> TimeInterval {
        max(0, (end ?? now).timeIntervalSince(start))
    }
}

enum AbsenceType: String, CaseIterable, Identifiable, Codable {
    case urlaub = "Urlaub"
    case krank = "Krank"

    var id: String { rawValue }
    var symbol: String { self == .urlaub ? "sun.max" : "cross.case" }
}

/// Ein Urlaubs- oder Krankheitstag.
struct Absence: Identifiable, Equatable {
    let id: UUID
    var date: Date          // Tagesbeginn
    var type: AbsenceType
    var fraction: Double    // 1 = ganzer Tag, 0.5 = halber Tag
    var note: String

    init(id: UUID = UUID(), date: Date, type: AbsenceType, fraction: Double = 1, note: String = "") {
        self.id = id
        self.date = date
        self.type = type
        self.fraction = fraction
        self.note = note
    }

    var label: String { (fraction < 1 ? "½ " : "") + type.rawValue }
}

enum Bundesland: String, CaseIterable, Identifiable, Codable {
    case badenWuerttemberg = "Baden-Württemberg"
    case bayern = "Bayern"
    case berlin = "Berlin"
    case brandenburg = "Brandenburg"
    case bremen = "Bremen"
    case hamburg = "Hamburg"
    case hessen = "Hessen"
    case mecklenburgVorpommern = "Mecklenburg-Vorpommern"
    case niedersachsen = "Niedersachsen"
    case nordrheinWestfalen = "Nordrhein-Westfalen"
    case rheinlandPfalz = "Rheinland-Pfalz"
    case saarland = "Saarland"
    case sachsen = "Sachsen"
    case sachsenAnhalt = "Sachsen-Anhalt"
    case schleswigHolstein = "Schleswig-Holstein"
    case thueringen = "Thüringen"

    var id: String { rawValue }
}

struct AppSettings: Codable, Equatable {
    var weeklyHours: Double = 39
    var vacationDaysPerYear: Double = 30
    var vacationCarryover: Double = 0          // Resturlaub aus dem Vorjahr
    var overtimeCarryoverHours: Double = 0     // Überstunden vor Beginn der Erfassung
    var startDate: Date = Calendar.current.startOfDay(for: Date())
    var bundesland: Bundesland = .nordrheinWestfalen
    var autoBreak: Bool = true

    /// Soll-Arbeitszeit pro Tag (Mo–Fr) in Sekunden
    var dailyTarget: TimeInterval { weeklyHours / 5 * 3600 }

    init() {}

    // Fehlende Werte in der JSON-Datei werden mit Standardwerten aufgefüllt.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        weeklyHours = try c.decodeIfPresent(Double.self, forKey: .weeklyHours) ?? d.weeklyHours
        vacationDaysPerYear = try c.decodeIfPresent(Double.self, forKey: .vacationDaysPerYear) ?? d.vacationDaysPerYear
        vacationCarryover = try c.decodeIfPresent(Double.self, forKey: .vacationCarryover) ?? d.vacationCarryover
        overtimeCarryoverHours = try c.decodeIfPresent(Double.self, forKey: .overtimeCarryoverHours) ?? d.overtimeCarryoverHours
        startDate = try c.decodeIfPresent(Date.self, forKey: .startDate) ?? d.startDate
        bundesland = try c.decodeIfPresent(Bundesland.self, forKey: .bundesland) ?? d.bundesland
        autoBreak = try c.decodeIfPresent(Bool.self, forKey: .autoBreak) ?? d.autoBreak
    }
}
