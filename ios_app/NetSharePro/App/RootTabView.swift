import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var context: AppContext

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView(viewModel: context.dashboardViewModel)
            }
            .tabItem {
                Label("Panel", systemImage: "shield.lefthalf.filled")
            }

            NavigationStack {
                ClientsView(viewModel: context.clientsViewModel)
            }
            .tabItem {
                Label("Cihazlar", systemImage: "laptopcomputer.and.iphone")
            }

            NavigationStack {
                ActivityView(viewModel: context.activityViewModel)
            }
            .tabItem {
                Label("Etkinlik", systemImage: "clock.arrow.circlepath")
            }

            NavigationStack {
                SettingsView(viewModel: context.settingsViewModel)
            }
            .tabItem {
                Label("Ayarlar", systemImage: "gearshape.fill")
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
    }
}
