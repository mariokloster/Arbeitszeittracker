import Foundation

/// Liest und schreibt alle Daten als CSV bzw. JSON in ~/Dokumente/Arbeitszeit
struct DataStore {
    let folder: URL

    var sessionsURL: URL { folder.appendingPathComponent("arbeitszeiten.csv") }
    var absencesURL: URL { folder.appendingPathComponent("abwesenheiten.csv") }
    var settingsURL: URL { folder.appendingPathComponent("einstellungen.json") }

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        folder = documents.appendingPathComponent("Arbeitszeit", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    // MARK: Arbeitszeiten  (start;ende;dauer)

    func loadSessions() -> [WorkSession] {
        rows(of: sessionsURL).compactMap { cols in
            // Die Kopfzeile lässt sich nicht als Datum lesen und wird so übersprungen
            guard let start = Format.parseDateTime(cols[0]) else { return nil }
            let end = cols.count > 1 ? Format.parseDateTime(cols[1]) : nil
            return WorkSession(start: start, end: end)
        }
    }

    func saveSessions(_ sessions: [WorkSession]) {
        var lines = ["start;ende;dauer"]
        for s in sessions.sorted(by: { $0.start < $1.start }) {
            let start = Format.csvDateTime.string(from: s.start)
            let end = s.end.map { Format.csvDateTime.string(from: $0) } ?? ""
            let duration = s.end == nil ? "" : Format.hm(s.duration())
            lines.append("\(start);\(end);\(duration)")
        }
        write(lines, to: sessionsURL)
    }

    // MARK: Abwesenheiten  (datum;typ;anteil;notiz)

    func loadAbsences() -> [Absence] {
        rows(of: absencesURL).compactMap { cols in
            guard cols.count >= 2,
                  let date = Format.parseDate(cols[0]),
                  let type = AbsenceType(rawValue: cols[1]) else { return nil }
            let fraction = cols.count > 2 ? Double(cols[2].replacingOccurrences(of: ",", with: ".")) ?? 1 : 1
            let note = cols.count > 3 ? cols[3] : ""
            return Absence(date: date, type: type, fraction: fraction, note: note)
        }
    }

    func saveAbsences(_ absences: [Absence]) {
        var lines = ["datum;typ;anteil;notiz"]
        for a in absences.sorted(by: { $0.date < $1.date }) {
            let note = a.note
                .replacingOccurrences(of: ";", with: ",")
                .replacingOccurrences(of: "\n", with: " ")
            lines.append("\(Format.csvDate.string(from: a.date));\(a.type.rawValue);\(Format.days(a.fraction));\(note)")
        }
        write(lines, to: absencesURL)
    }

    // MARK: Einstellungen (JSON)

    func loadSettings() -> AppSettings {
        guard let data = try? Data(contentsOf: settingsURL) else { return AppSettings() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(AppSettings.self, from: data)) ?? AppSettings()
    }

    func saveSettings(_ settings: AppSettings) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(settings) {
            try? data.write(to: settingsURL, options: .atomic)
        }
    }

    // MARK: Hilfsfunktionen

    private func rows(of url: URL) -> [[String]] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(whereSeparator: \.isNewline).map { line in
            line.split(separator: ";", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
        }
    }

    private func write(_ lines: [String], to url: URL) {
        try? (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}

/// Datums- und Zeitformate
enum Format {
    private static func formatter(_ pattern: String, german: Bool = false) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: german ? "de_DE" : "en_US_POSIX")
        f.dateFormat = pattern
        return f
    }

    // Formate in den Dateien
    static let csvDateTime = Format.formatter("yyyy-MM-dd HH:mm:ss")
    static let csvDate = Format.formatter("yyyy-MM-dd")
    // Falls die CSV mal in Excel/Numbers gespeichert wurde
    static let dateTimeFallbacks = ["yyyy-MM-dd HH:mm", "dd.MM.yyyy HH:mm:ss", "dd.MM.yyyy HH:mm", "dd.MM.yy HH:mm"]
        .map { Format.formatter($0) }
    static let dateFallbacks = ["dd.MM.yyyy", "dd.MM.yy"].map { Format.formatter($0) }

    static func parseDateTime(_ text: String) -> Date? {
        for f in [csvDateTime] + dateTimeFallbacks {
            if let d = f.date(from: text) { return d }
        }
        return nil
    }

    static func parseDate(_ text: String) -> Date? {
        for f in [csvDate] + dateFallbacks {
            if let d = f.date(from: text) { return d }
        }
        return nil
    }

    // Formate für die Anzeige
    static let time = Format.formatter("HH:mm", german: true)
    static let date = Format.formatter("dd.MM.yyyy", german: true)
    static let dayShort = Format.formatter("EE dd.MM.", german: true)
    static let dayLong = Format.formatter("EEEE, d. MMMM yyyy", german: true)
    static let month = Format.formatter("MMMM yyyy", german: true)

    /// Sekunden → „7:48“, mit signed: true → „+1:12“ / „−0:30“
    static func hm(_ t: TimeInterval, signed: Bool = false) -> String {
        let minutes = Int((abs(t) / 60).rounded())
        let sign = minutes == 0 ? "" : (t < 0 ? "−" : (signed ? "+" : ""))
        return "\(sign)\(minutes / 60):" + String(format: "%02d", minutes % 60)
    }

    /// 30 → „30“, 0.5 → „0,5“
    static func days(_ d: Double) -> String {
        if d == d.rounded() { return String(Int(d)) }
        return String(format: "%.1f", d).replacingOccurrences(of: ".", with: ",")
    }
}
