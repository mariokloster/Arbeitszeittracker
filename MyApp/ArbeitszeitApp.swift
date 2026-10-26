import SwiftUI

@main
struct ArbeitszeitApp: App {
    @StateObject private var tracker = TimeTracker()

    var body: some Scene {
        // Das Icon oben in der Menüleiste
        MenuBarExtra {
            MenuView()
                .environmentObject(tracker)
        } label: {
            Image(systemName: tracker.isRunning ? "clock.fill" : "clock")
        }
        .menuBarExtraStyle(.window)

        // Das große Fenster für Übersicht, Urlaub und Einstellungen
        Window("Arbeitszeit", id: "main") {
            MainWindow()
                .environmentObject(tracker)
        }
        .defaultSize(width: 860, height: 580)
    }
}

struct MainWindow: View {
    @EnvironmentObject private var tracker: TimeTracker

    var body: some View {
        TabView(selection: $tracker.selectedTab) {
            TimesView()
                .tabItem { Label("Zeiten", systemImage: "clock") }
                .tag(MainTab.zeiten)
            AbsencesView()
                .tabItem { Label("Urlaub & Krankheit", systemImage: "airplane") }
                .tag(MainTab.abwesenheiten)
            SettingsView()
                .tabItem { Label("Einstellungen", systemImage: "gearshape") }
                .tag(MainTab.einstellungen)
        }
        .padding()
        .frame(minWidth: 760, minHeight: 500)
    }
}
