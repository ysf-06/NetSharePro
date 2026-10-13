import SwiftUI
import UIKit

@MainActor
final class AppContext: ObservableObject {
    let settings: SettingsStore
    let engine: ProxyEngine
    let browser: DiscoveryBrowser
    let dashboardViewModel: DashboardViewModel
    let clientsViewModel: ClientsViewModel
    let activityViewModel: ActivityViewModel
    let settingsViewModel: SettingsViewModel

    init() {
        let settings = SettingsStore()
        let engine = ProxyEngine(settings: settings)
        self.settings = settings
        self.engine = engine
        browser = DiscoveryBrowser()
        dashboardViewModel = DashboardViewModel(engine: engine)
        clientsViewModel = ClientsViewModel(engine: engine, browser: browser)
        activityViewModel = ActivityViewModel(engine: engine)
        settingsViewModel = SettingsViewModel(engine: engine, settings: settings)
    }

    func startDiscovery() {
        browser.start()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        let shouldStayAwake = phase == .active
            && engine.isRunning
            && settings.keepScreenAwake
        UIApplication.shared.isIdleTimerDisabled = shouldStayAwake
    }
}

@main
struct NetShareProApp: App {
    @StateObject private var context = AppContext()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(AppTheme.card)
        UITabBar.appearance().standardAppearance = tabAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        }

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(AppTheme.background)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(context)
                .environmentObject(context.settings)
                .preferredColorScheme(.dark)
                .tint(AppTheme.accentLight)
                .onAppear {
                    context.startDiscovery()
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("--autostart"),
                       !context.engine.isRunning {
                        context.dashboardViewModel.startSharing()
                    }
                    #endif
                }
        }
        .onChange(of: scenePhase) { newPhase in
            context.handleScenePhase(newPhase)
        }
    }
}
