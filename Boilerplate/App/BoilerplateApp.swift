import SwiftData
import SwiftUI
import StoreKit

@main
struct BoilerplateApp: App {
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Dependencies

    private let router = Router.shared
    private let apiClient = APIClient()
    private let authService: AuthService
    private let analyticsService = AnalyticsService()
    private let paywallService: PaywallService
    private let reviewPromptService: ReviewPromptService

    // MARK: - Initialization

    init() {
        AppPerformance.start()
        authService = AuthService(apiClient: apiClient)
        paywallService = PaywallService(analyticsService: analyticsService)
        reviewPromptService = ReviewPromptService(analyticsService: analyticsService)
        configureUITestState()
        configureAppearance()
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(apiClient)
                .environment(authService)
                .environment(analyticsService)
                .environment(paywallService)
                .environment(reviewPromptService)
        }
        .modelContainer(SwiftDataContainer.shared)
        .onChange(of: scenePhase) { _, phase in
            AppPerformance.sceneChanged(phase)
        }
    }

    // MARK: - Private Methods

    private func configureAppearance() {
        // Configure global appearance settings
        #if DEBUG
        Logger.shared.app("App launched in \(AppEnvironment.current.rawValue) mode")
        #endif
    }

    private func configureUITestState() {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-resetOnboarding") else { return }
        UserDefaultsWrapper.hasCompletedOnboarding = false
        #endif
    }
}

// MARK: - Root View

struct RootView: View {
    @Environment(Router.self) private var router
    @Environment(AuthService.self) private var authService
    @Environment(ReviewPromptService.self) private var reviewPromptService
    @Environment(\.requestReview) private var requestReview
    @State private var hasCompletedOnboarding = UserDefaultsWrapper.hasCompletedOnboarding

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            Group {
                if authService.isAuthenticated {
                    HomeView()
                } else if hasCompletedOnboarding {
                    LoginView()
                } else {
                    OnboardingView {
                        hasCompletedOnboarding = true
                    }
                }
            }
            .navigationDestination(for: Route.self) { route in
                destinationView(for: route)
            }
        }
        .sheet(item: $router.presentedSheet) { sheet in
            sheetView(for: sheet)
        }
        .alert(item: $router.presentedAlert) { alert in
            if let secondaryButton = alert.secondaryButton {
                Alert(
                    title: Text(alert.title),
                    message: alert.message.map(Text.init),
                    primaryButton: alertButton(alert.primaryButton),
                    secondaryButton: alertButton(secondaryButton)
                )
            } else {
                Alert(
                    title: Text(alert.title),
                    message: alert.message.map(Text.init),
                    dismissButton: alertButton(alert.primaryButton)
                )
            }
        }
        .onChange(of: reviewPromptService.pendingRequestID) { _, requestID in
            guard requestID != nil else { return }
            requestReview()
            reviewPromptService.markPromptAttempted()
        }
    }

    @ViewBuilder
    private func destinationView(for route: Route) -> some View {
        switch route {
        case .home:
            HomeView()
        case .exampleList:
            ExampleListView()
        case .exampleDetail(let id):
            ExampleDetailView(itemId: id)
        case .exampleForm(let item):
            ExampleFormView(existingItem: item)
        case .settings:
            SettingsView()
        case .profile:
            ProfileView()
        case .paywall:
            PaywallView(placement: "manual")
        }
    }

    @ViewBuilder
    private func sheetView(for sheet: Sheet) -> some View {
        switch sheet {
        case .login:
            LoginView()
        case .signUp:
            SignUpView()
        }
    }

    private func alertButton(_ button: AlertItem.AlertButton) -> Alert.Button {
        switch button.role {
        case .cancel:
            return .cancel(Text(button.title), action: button.action)
        case .destructive:
            return .destructive(Text(button.title), action: button.action)
        case nil:
            return .default(Text(button.title), action: button.action)
        }
    }
}

// MARK: - Home View (Placeholder)

struct HomeView: View {
    @Environment(Router.self) private var router
    @Environment(AnalyticsService.self) private var analyticsService
    @Environment(ReviewPromptService.self) private var reviewPromptService

    var body: some View {
        List {
            Section("Features") {
                Button("Example Feature") {
                    analyticsService.track(.featureUsed("example_feature"))
                    reviewPromptService.recordSuccessfulAction(reason: "opened_example_feature")
                    router.navigate(to: .exampleList)
                }
            }

            Section("Monetization") {
                Button("Paywall Example") {
                    router.navigate(to: .paywall)
                }
            }

            Section("Account") {
                Button("Settings") {
                    router.navigate(to: .settings)
                }
            }
        }
        .navigationTitle("Home")
    }
}

// MARK: - Profile View (Placeholder)

struct ProfileView: View {
    @Environment(AuthService.self) private var authService

    var body: some View {
        List {
            if let user = authService.currentUser {
                Section {
                    LabeledContent("Name", value: user.name)
                    LabeledContent("Email", value: user.email)
                }
            }

            Section {
                Button("Sign Out", role: .destructive) {
                    Task {
                        await authService.signOut()
                    }
                }
            }
        }
        .navigationTitle("Profile")
    }
}
