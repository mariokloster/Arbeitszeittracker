import SwiftUI
import AppKit

/// Das kleine Fenster, das sich beim Klick auf das Menüleisten-Icon öffnet.
struct MenuView: View {
    @EnvironmentObject private var tracker: TimeTracker
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // Alle 30 Sekunden aktualisieren, damit die laufende Zeit stimmt
        TimelineView(.periodic(from: .now, by: 30)) { context in
            content(now: context.date)
        }
        .padding(14)
        .frame(width: 300)
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let today = tracker.summary(for: now, now: now)
        let balance = tracker.overtimeBalance(now: now)
        let year = Calendar.current.component(.year, from: now)
        let vacation = tracker.vacationStatus(year: year)

        VStack(alignment: .leading, spacing: 12) {
            if let running = tracker.runningSession {
                Label("Du arbeitest seit \(Format.time.string(from: running.start)) Uhr", systemImage: "record.circle")
                    .foregroundStyle(.green)
            } else {
                Label("Gerade nicht eingestempelt", systemImage: "moon.zzz")
                    .foregroundStyle(.secondary)
            }

            Button {
                if tracker.isRunning { tracker.stopWork() } else { tracker.startWork() }
            } label: {
                Label(tracker.isRunning ? "Feierabend" : "Arbeit beginnen",
                      systemImage: tracker.isRunning ? "house" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(tracker.isRunning ? .red : .green)

            Divider()

            InfoRow(title: "Heute",
                    value: "\(Format.hm(today.worked)) von \(Format.hm(today.target)) h")
            InfoRow(title: today.counts ? "Überstunden" : "Überstunden (ohne heute)",
                    value: Format.hm(balance, signed: true) + " h",
                    color: balance < 0 ? .red : .primary)
            InfoRow(title: "Urlaub \(year) verfügbar",
                    value: "\(Format.days(vacation.remaining)) von \(Format.days(vacation.entitlement)) Tagen")
            if vacation.planned > 0 {
                Text("\(Format.days(vacation.planned)) Tage davon sind schon verplant")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            MenuLink(title: "Urlaub oder Krankheit eintragen …", symbol: "airplane") { open(.abwesenheiten) }
            MenuLink(title: "Übersicht & Zeiten bearbeiten …", symbol: "calendar") { open(.zeiten) }
            MenuLink(title: "Einstellungen …", symbol: "gearshape") { open(.einstellungen) }

            Divider()

            MenuLink(title: "Beenden", symbol: "power") { NSApp.terminate(nil) }
        }
    }

    private func open(_ tab: MainTab) {
        tracker.selectedTab = tab
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct InfoRow: View {
    let title: String
    let value: String
    var color: Color = .primary

    var body: some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit().foregroundStyle(color)
        }
    }
}

private struct MenuLink: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
