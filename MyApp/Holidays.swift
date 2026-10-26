import Foundation

/// Gesetzliche Feiertage in Deutschland.
/// Hinweis: Mariä Himmelfahrt in Bayern gilt nur in katholisch geprägten Gemeinden
/// und ist hier deshalb nicht enthalten.
enum Holidays {
    static func all(year: Int, state: Bundesland) -> [Date: String] {
        let cal = Calendar.current
        var result: [Date: String] = [:]

        func date(_ month: Int, _ day: Int) -> Date {
            cal.date(from: DateComponents(year: year, month: month, day: day))!
        }
        let easter = easterSunday(year: year)
        func easterPlus(_ days: Int) -> Date {
            cal.date(byAdding: .day, value: days, to: easter)!
        }
        func add(_ day: Date, _ name: String) {
            if let existing = result[day] {
                result[day] = existing + " / " + name
            } else {
                result[day] = name
            }
        }

        // Bundesweit
        add(date(1, 1), "Neujahr")
        add(easterPlus(-2), "Karfreitag")
        add(easterPlus(1), "Ostermontag")
        add(date(5, 1), "Tag der Arbeit")
        add(easterPlus(39), "Christi Himmelfahrt")
        add(easterPlus(50), "Pfingstmontag")
        add(date(10, 3), "Tag der Deutschen Einheit")
        add(date(12, 25), "1. Weihnachtstag")
        add(date(12, 26), "2. Weihnachtstag")

        // Je nach Bundesland
        if [.badenWuerttemberg, .bayern, .sachsenAnhalt].contains(state) {
            add(date(1, 6), "Heilige Drei Könige")
        }
        if [.berlin, .mecklenburgVorpommern].contains(state) {
            add(date(3, 8), "Internationaler Frauentag")
        }
        if [.badenWuerttemberg, .bayern, .hessen, .nordrheinWestfalen, .rheinlandPfalz, .saarland].contains(state) {
            add(easterPlus(60), "Fronleichnam")
        }
        if state == .saarland {
            add(date(8, 15), "Mariä Himmelfahrt")
        }
        if state == .thueringen {
            add(date(9, 20), "Weltkindertag")
        }
        if [.brandenburg, .bremen, .hamburg, .mecklenburgVorpommern, .niedersachsen,
            .sachsen, .sachsenAnhalt, .schleswigHolstein, .thueringen].contains(state) {
            add(date(10, 31), "Reformationstag")
        }
        if [.badenWuerttemberg, .bayern, .nordrheinWestfalen, .rheinlandPfalz, .saarland].contains(state) {
            add(date(11, 1), "Allerheiligen")
        }
        if state == .sachsen {
            // Mittwoch vor dem 23. November
            var day = date(11, 22)
            while cal.component(.weekday, from: day) != 4 {
                day = cal.date(byAdding: .day, value: -1, to: day)!
            }
            add(day, "Buß- und Bettag")
        }
        return result
    }

    /// Ostersonntag nach der Gauß'schen Osterformel (gregorianischer Kalender)
    static func easterSunday(year: Int) -> Date {
        let a = year % 19, b = year / 100, c = year % 100
        let d = b / 4, e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = (h + l - 7 * m + 114) % 31 + 1
        return Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
