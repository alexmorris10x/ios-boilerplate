# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-02-05

### Added

- **Core Infrastructure**
  - App entry point with environment injection
  - Environment configuration (development/staging/production)
  - Feature flags system
  - Unified logging with os.log

- **Networking**
  - Protocol-based API client with async/await
  - Type-safe endpoint definitions
  - Typed error handling
  - Middleware support (auth, logging)

- **Persistence**
  - SwiftData container setup with CloudKit support
  - Type-safe UserDefaults wrapper with @propertyWrapper
  - Keychain manager for secure storage

- **Navigation**
  - Type-safe routes enum
  - Centralized Router with NavigationStack
  - Sheet and full-screen cover support
  - Deep linking handler

- **Services**
  - AuthService for authentication flows
  - AnalyticsService for event tracking
  - HapticService with Core Haptics support

- **Shared Components**
  - Extensions for CGPoint, CGSize, Color, View, Date
  - App and UI constants
  - Theme system with color palette and typography
  - Button styles (primary, secondary, destructive, ghost, icon, pill)
  - Form components (text field, secure field, validation)
  - Feedback components (loading, empty state, error)
  - View modifiers (shimmer, card)
  - LoadingState and PaginationState types

- **Features**
  - Auth feature (login, sign up, user model)
  - Settings feature (preferences, theme, about)
  - Example feature (complete CRUD implementation)
    - SwiftData model
    - API service with protocol
    - ViewModel with loading states and pagination
    - List, detail, and form views

- **Testing**
  - Mock API client
  - Mock auth service
  - Unit tests for API client
  - Unit tests for ExampleListViewModel

- **Documentation**
  - README with setup instructions
  - CONTRIBUTING guidelines
  - Code quality configurations (.swiftlint.yml, .swiftformat)

### Technical Details

- Minimum iOS version: 17.0
- Swift version: 5.9+
- Architecture: MVVM with @Observable
- Data persistence: SwiftData
- Navigation: NavigationStack with Router pattern
- Dependency injection: SwiftUI Environment

---

## [Unreleased]

### Added

- XcodeGen `project.yml` as the committed source of truth for generating `Boilerplate.xcodeproj`.
- Production-readiness SOP checklist covering onboarding, monetization, reviews, analytics, crash monitoring, privacy, QA, release, and post-launch operations.
- Provider-neutral `PaywallService`, `PaywallView`, and `SubscriptionStatusView` scaffolding.
- `ReviewPromptService` for testable App Store review prompt eligibility.
- Dedicated onboarding feature with standard analytics events.
- Privacy manifest for the boilerplate's current required-reason API usage.
- Unit tests for production SOP analytics events, review prompt eligibility, and not-configured paywall behavior.

### Changed

- Xcode Cloud post-clone script now generates the Xcode project before stamping build numbers.
- Settings now acts as the production trust surface with subscription, restore, review, support, legal, version, and delete-account placeholders.

### Planned

- Push notifications setup
- Localization support
- Accessibility improvements
- More UI components (cards, avatars, badges)
- Widget extension example
- Watch app extension example
