import PerformanceNervousSystem
import SwiftUI

/// Thin app vocabulary over the repo-local performance implementation.
///
/// Keep generic collection, privacy, retention, and persistence behavior in
/// `Packages/PerformanceNervousSystem`. Add product-specific journey names to
/// this adapter after copying the boilerplate into a real app.
enum AppPerformance {
    private static let system = PerformanceNervousSystem.shared

    static func start() {
        #if DEBUG
        let environment = "development"
        #else
        let environment = "production"
        #endif

        system.start(.init(environment: environment))
        system.setContext("startup", metadata: ["screen": "startup"])
    }

    static func sceneChanged(_ phase: ScenePhase) {
        let value: String
        switch phase {
        case .active:
            value = "active"
        case .inactive:
            value = "inactive"
        case .background:
            value = "background"
        @unknown default:
            value = "unknown"
        }

        system.mark("lifecycle_\(value)", metadata: ["phase": value])
        if phase == .background {
            system.writeSession(reason: "background", force: true)
        }
    }
}
