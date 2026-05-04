import Foundation

/// App-wide constants
enum AppConstants {
    // MARK: - App Info

    /// Bundle identifier
    static let bundleId = Bundle.main.bundleIdentifier ?? "com.boilerplate.app"

    /// App version
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

    /// Build number
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    /// Full version string (e.g., "1.0.0 (123)")
    static var fullVersion: String {
        "\(appVersion) (\(buildNumber))"
    }

    // MARK: - API

    enum API {
        /// Default page size for paginated requests
        static let defaultPageSize = 20

        /// Maximum page size allowed
        static let maxPageSize = 100

        /// Request timeout in seconds
        static let requestTimeout: TimeInterval = 30

        /// Maximum retry attempts for failed requests
        static let maxRetryAttempts = 3

        /// Delay between retries in seconds
        static let retryDelay: TimeInterval = 1.0
    }

    // MARK: - Cache

    enum Cache {
        /// Maximum memory cache size in bytes (50 MB)
        static let maxMemoryCacheSize = 50 * 1024 * 1024

        /// Maximum disk cache size in bytes (200 MB)
        static let maxDiskCacheSize = 200 * 1024 * 1024

        /// Cache expiration time in seconds (1 day)
        static let defaultExpiration: TimeInterval = 24 * 60 * 60
    }

    // MARK: - Animation

    enum Animation {
        /// Standard animation duration
        static let standard: TimeInterval = 0.3

        /// Fast animation duration
        static let fast: TimeInterval = 0.15

        /// Slow animation duration
        static let slow: TimeInterval = 0.5

        /// Spring response for bouncy animations
        static let springResponse: Double = 0.3

        /// Spring damping for bouncy animations
        static let springDamping: Double = 0.7
    }

    // MARK: - Validation

    enum Validation {
        /// Minimum password length
        static let minPasswordLength = 8

        /// Maximum password length
        static let maxPasswordLength = 128

        /// Minimum username length
        static let minUsernameLength = 3

        /// Maximum username length
        static let maxUsernameLength = 30

        /// Maximum bio length
        static let maxBioLength = 500

        /// Email regex pattern
        static let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    }

    // MARK: - Limits

    enum Limits {
        /// Maximum file upload size in bytes (10 MB)
        static let maxFileUploadSize = 10 * 1024 * 1024

        /// Maximum image dimension
        static let maxImageDimension = 4096

        /// Maximum items in a list before pagination
        static let listPaginationThreshold = 50
    }

    // MARK: - Dates

    enum DateFormat {
        /// ISO 8601 format
        static let iso8601 = "yyyy-MM-dd'T'HH:mm:ssZ"

        /// Date only
        static let dateOnly = "yyyy-MM-dd"

        /// Time only
        static let timeOnly = "HH:mm:ss"

        /// Display format
        static let display = "MMM d, yyyy"

        /// Display with time
        static let displayWithTime = "MMM d, yyyy 'at' h:mm a"
    }

    // MARK: - Support

    enum Support {
        /// Support email
        static let email = "support@example.com"

        /// Replace this with the App Store app ID before enabling the public review link.
        static let appStoreID = "0000000000"

        /// Help URL
        static let helpURL = URL(string: "https://example.com/help")!

        /// Privacy policy URL
        static let privacyURL = URL(string: "https://example.com/privacy")!

        /// Terms of service URL
        static let termsURL = URL(string: "https://example.com/terms")!

        /// Support email URL
        static let contactURL = URL(string: "mailto:\(email)")!

        /// Opens the App Store write-review flow once `appStoreID` is replaced.
        static let reviewURL = URL(string: "itms-apps://itunes.apple.com/app/id\(appStoreID)?action=write-review")!

        /// Apple's subscription management screen.
        static let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!
    }
}
