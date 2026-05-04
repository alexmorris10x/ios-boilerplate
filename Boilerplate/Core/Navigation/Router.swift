import SwiftUI

/// Centralized navigation coordinator using NavigationStack
/// Manages all push/pop navigation and presentations
@Observable
final class Router {
    // MARK: - Singleton

    static let shared = Router()

    // MARK: - Navigation State

    /// Navigation path for NavigationStack
    var path = NavigationPath()

    /// Currently presented sheet
    var presentedSheet: Sheet?

    /// Currently presented full screen cover
    var presentedFullScreenCover: FullScreenCover?

    /// Currently presented alert
    var presentedAlert: AlertItem?

    // MARK: - Initialization

    private init() {}

    // MARK: - Push Navigation

    /// Navigate to a route (push)
    func navigate(to route: Route) {
        path.append(route)
        Logger.shared.ui("Navigate to: \(route)", level: .debug)
    }

    /// Navigate to multiple routes
    func navigate(to routes: [Route]) {
        for route in routes {
            path.append(route)
        }
    }

    // MARK: - Pop Navigation

    /// Go back one screen
    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
        Logger.shared.ui("Pop navigation", level: .debug)
    }

    /// Go back multiple screens
    func pop(_ count: Int) {
        let removeCount = min(count, path.count)
        path.removeLast(removeCount)
    }

    /// Go back to root
    func popToRoot() {
        path.removeLast(path.count)
        Logger.shared.ui("Pop to root", level: .debug)
    }

    // MARK: - Sheet Presentation

    /// Present a sheet
    func present(sheet: Sheet) {
        presentedSheet = sheet
        Logger.shared.ui("Present sheet: \(sheet)", level: .debug)
    }

    /// Dismiss current sheet
    func dismissSheet() {
        presentedSheet = nil
    }

    // MARK: - Full Screen Cover Presentation

    /// Present a full screen cover
    func present(fullScreenCover: FullScreenCover) {
        presentedFullScreenCover = fullScreenCover
        Logger.shared.ui("Present full screen: \(fullScreenCover)", level: .debug)
    }

    /// Dismiss current full screen cover
    func dismissFullScreenCover() {
        presentedFullScreenCover = nil
    }

    // MARK: - Alert Presentation

    /// Show an alert
    func showAlert(_ alert: AlertItem) {
        presentedAlert = alert
    }

    /// Show a simple error alert
    func showError(_ message: String, title: String = "Error") {
        presentedAlert = AlertItem(
            title: title,
            message: message,
            primaryButton: .default("OK"),
            secondaryButton: nil
        )
    }

    /// Show a confirmation alert
    func showConfirmation(
        title: String,
        message: String?,
        confirmTitle: String = "Confirm",
        isDestructive: Bool = false,
        onConfirm: @escaping () -> Void
    ) {
        let primaryButton: AlertItem.AlertButton = isDestructive
            ? .destructive(confirmTitle, action: onConfirm)
            : .default(confirmTitle, action: onConfirm)

        presentedAlert = AlertItem(
            title: title,
            message: message,
            primaryButton: primaryButton,
            secondaryButton: .cancel()
        )
    }

    /// Dismiss current alert
    func dismissAlert() {
        presentedAlert = nil
    }

    // MARK: - Reset

    /// Reset all navigation state
    func reset() {
        popToRoot()
        presentedSheet = nil
        presentedFullScreenCover = nil
        presentedAlert = nil
    }
}

// MARK: - Deep Link Handling

extension Router {
    /// Handle a deep link URL
    func handleDeepLink(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let host = components.host else {
            return false
        }

        let pathComponents = components.path.split(separator: "/").map(String.init)

        Logger.shared.app("Handling deep link: \(url)", level: .info)

        switch host {
        case "example":
            if let id = pathComponents.first {
                navigate(to: .exampleDetail(id: id))
                return true
            }
            navigate(to: .exampleList)
            return true

        case "settings":
            navigate(to: .settings)
            return true

        case "profile":
            navigate(to: .profile)
            return true

        case "paywall":
            navigate(to: .paywall)
            return true

        default:
            Logger.shared.app("Unknown deep link host: \(host)", level: .warning)
            return false
        }
    }
}
