import Foundation

/// Type-safe route definitions for app navigation
/// All navigation destinations are defined here for compile-time safety
enum Route: Hashable {
    // MARK: - Main Routes

    case home
    case exampleList
    case exampleDetail(id: String)
    case exampleForm(item: ExampleItem?)
    case settings
    case profile
    case paywall

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        switch self {
        case .home:
            hasher.combine("home")
        case .exampleList:
            hasher.combine("exampleList")
        case .exampleDetail(let id):
            hasher.combine("exampleDetail")
            hasher.combine(id)
        case .exampleForm(let item):
            hasher.combine("exampleForm")
            hasher.combine(item?.id)
        case .settings:
            hasher.combine("settings")
        case .profile:
            hasher.combine("profile")
        case .paywall:
            hasher.combine("paywall")
        }
    }

    static func == (lhs: Route, rhs: Route) -> Bool {
        switch (lhs, rhs) {
        case (.home, .home),
             (.exampleList, .exampleList),
             (.settings, .settings),
             (.profile, .profile),
             (.paywall, .paywall):
            return true
        case (.exampleDetail(let lhsId), .exampleDetail(let rhsId)):
            return lhsId == rhsId
        case (.exampleForm(let lhsItem), .exampleForm(let rhsItem)):
            return lhsItem?.id == rhsItem?.id
        default:
            return false
        }
    }
}

/// Sheet presentations (modal views)
enum Sheet: Identifiable {
    case login
    case signUp

    var id: String {
        switch self {
        case .login:
            return "login"
        case .signUp:
            return "signUp"
        }
    }
}

/// Full screen cover presentations
enum FullScreenCover: Identifiable {
    case onboarding
    case imageViewer(url: URL)

    var id: String {
        switch self {
        case .onboarding:
            return "onboarding"
        case .imageViewer(let url):
            return "imageViewer_\(url.absoluteString)"
        }
    }
}

/// Alert presentations
struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String?
    let primaryButton: AlertButton
    let secondaryButton: AlertButton?

    struct AlertButton {
        let title: String
        let role: ButtonRole?
        let action: () -> Void

        init(title: String, role: ButtonRole? = nil, action: @escaping () -> Void = {}) {
            self.title = title
            self.role = role
            self.action = action
        }

        static func cancel(_ action: @escaping () -> Void = {}) -> AlertButton {
            AlertButton(title: "Cancel", role: .cancel, action: action)
        }

        static func destructive(_ title: String, action: @escaping () -> Void) -> AlertButton {
            AlertButton(title: title, role: .destructive, action: action)
        }

        static func `default`(_ title: String, action: @escaping () -> Void = {}) -> AlertButton {
            AlertButton(title: title, action: action)
        }
    }

    enum ButtonRole {
        case cancel
        case destructive
    }
}
