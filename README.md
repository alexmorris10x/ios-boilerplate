# iOS Boilerplate

A production-ready iOS boilerplate built with modern SwiftUI patterns, designed to help you ship iOS apps faster while following industry best practices.

## Why This Boilerplate?

Starting a new iOS project means making dozens of architectural decisions before writing any feature code. This boilerplate makes those decisions for you, based on:

- **Apple's guidance** for SwiftUI and Swift Concurrency
- **Community best practices** from top iOS developers and companies
- **Real-world experience** from production apps
- **2024-2025 iOS ecosystem** standards (iOS 17+, Swift 5.9+)

Every pattern in this boilerplate exists for a reason. This documentation explains not just *what* to do, but *why*.

## Features

| Feature | Implementation | Why This Approach |
|---------|---------------|-------------------|
| Architecture | MVVM + `@Observable` | Simplest reactive pattern that scales well |
| Networking | Protocol-based async/await | Testable, modern, no callback hell |
| Persistence | SwiftData + Keychain + UserDefaults | Right tool for each data type |
| Navigation | Type-safe Router | Compile-time safety, deep linking ready |
| UI Components | Composable SwiftUI views | Reusable, consistent, maintainable |
| Testing | Swift Testing + mocks | Apple's modern testing framework |
| Code Quality | SwiftLint + SwiftFormat | Consistent style, catch bugs early |
| Project Generation | XcodeGen | Buildable project without committing `.xcodeproj` churn |
| Production SOP | Checklist + provider-neutral services | Repeatable launch readiness across apps |

## Requirements

- **iOS 17.0+** - Required for `@Observable`, modern SwiftData, and NavigationStack improvements
- **Xcode 15.0+** - Required for Swift 5.9 and iOS 17 SDK
- **Swift 5.9+** - Required for `@Observable` macro
- **XcodeGen** - Required to generate `Boilerplate.xcodeproj` from `project.yml`

> **Why iOS 17?** The `@Observable` macro (iOS 17+) dramatically simplifies state management compared to `ObservableObject` + `@Published`. If you need iOS 16 support, you can convert ViewModels to use `ObservableObject`, but we recommend targeting iOS 17+ for new projects.

## Quick Start

```bash
# Clone the repository
git clone https://github.com/10x-oss/ios-boilerplate.git
cd ios-boilerplate

# Generate the Xcode project
xcodegen generate

# Open in Xcode
open Boilerplate.xcodeproj
```

Then:
1. Update bundle identifier in project settings
2. Configure API URLs in `AppEnvironment.swift`
3. Replace support/legal/App Store IDs in `AppConstants.swift`
4. Review [docs/PRODUCTION-READINESS-CHECKLIST.md](docs/PRODUCTION-READINESS-CHECKLIST.md)
5. Build and run (`⌘R`)

## Documentation

| Document | Description |
|----------|-------------|
| [README.md](README.md) | This file - overview and quick start |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Deep dive into architectural decisions |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Guidelines for contributing |
| [CHANGELOG.md](CHANGELOG.md) | Version history |
| [docs/PRODUCTION-READINESS-CHECKLIST.md](docs/PRODUCTION-READINESS-CHECKLIST.md) | SOP for app launch readiness |
| [docs/XCODE-CLOUD-WORKFLOW.md](docs/XCODE-CLOUD-WORKFLOW.md) | CI/versioning runbook for Xcode Cloud |

---

## Project Structure

```
ios-boilerplate/
├── Boilerplate/
│   ├── App/                    # App entry point and configuration
│   ├── Core/                   # Infrastructure (networking, persistence, etc.)
│   ├── Shared/                 # Reusable code (components, extensions, etc.)
│   ├── Features/               # Feature modules (auth, settings, etc.)
│   └── Resources/              # Assets, localization, Info.plist
├── BoilerplateTests/           # Unit tests
├── BoilerplateUITests/         # UI tests
├── docs/                       # SOPs and release runbooks
└── project.yml                 # XcodeGen project definition
```

---

## Production-Ready App Shell

This boilerplate includes the repeatable production surfaces most iOS apps need before launch:

- **Onboarding**: Dedicated first-run feature with `onboarding_started` and `onboarding_completed` events.
- **Monetization**: Provider-neutral `PaywallService`, `PaywallView`, restore purchases, subscription status, and manage-subscription link.
- **Reviews**: `ReviewPromptService` tracks eligibility and lets the SwiftUI host call Apple's system review prompt after success moments.
- **Settings and trust**: Support, legal links, app version/build, subscription tools, review link, debug console, and account deletion placeholder.
- **Privacy**: `PrivacyInfo.xcprivacy` starts with the boilerplate's UserDefaults required-reason API declaration.

Recommended provider defaults for derived apps:

| Need | Recommended Default | Notes |
|------|---------------------|-------|
| Subscriptions and entitlements | RevenueCat | Keep it as the subscription source of truth |
| Paywall placement experiments | Superwall | Optional; add when paywall iteration speed matters |
| Product analytics and feature flags | PostHog | Keep event names stable across apps |
| Crash reporting | Sentry or Firebase Crashlytics | Add before public launch and upload dSYMs from CI |

### Why This Structure?

**Feature-based organization** (vs. layer-based like `Models/`, `Views/`, `ViewModels/`):

| Approach | Pros | Cons |
|----------|------|------|
| **Feature-based** (our choice) | Related code together, easy to find, scales well | Slightly more folders |
| Layer-based | Familiar from MVC | Files scattered, hard to navigate at scale |

With feature-based organization, everything related to "Auth" is in `Features/Auth/`. When you're working on a feature, you rarely need to jump between distant folders.

**Shared vs. Core distinction**:
- `Core/` = Infrastructure that features depend on (networking, persistence, navigation)
- `Shared/` = Reusable UI code (components, extensions, styles)

This separation makes dependencies clear and prevents circular imports.

---

## Architecture Deep Dive

### MVVM with @Observable

**Why MVVM?**
- Clear separation: Views display, ViewModels process, Models store
- Testable: ViewModels can be tested without UI
- SwiftUI-native: Works naturally with SwiftUI's data flow

**Why @Observable over ObservableObject?**
```swift
// OLD: ObservableObject (iOS 13+)
class OldViewModel: ObservableObject {
    @Published var items: [Item] = []     // Must mark each property
    @Published var isLoading = false      // Easy to forget @Published
    @Published var error: Error?          // Boilerplate heavy
}

// NEW: @Observable (iOS 17+)
@Observable
class NewViewModel {
    var items: [Item] = []                // Just works
    var isLoading = false                 // No annotations needed
    var error: Error?                     // Cleaner code
}
```

Benefits of `@Observable`:
- **Less boilerplate** - No `@Published` on every property
- **Automatic tracking** - SwiftUI only updates when accessed properties change
- **Better performance** - More granular updates than `ObservableObject`

**ViewModel Pattern**:
```swift
@Observable
final class ExampleListViewModel {
    // MARK: - State (private(set) prevents external mutation)
    private(set) var items: [ExampleItem] = []
    private(set) var loadingState: LoadingState<[ExampleItem]> = .idle

    // MARK: - Dependencies (injected for testability)
    private let apiService: ExampleAPIServiceProtocol

    // MARK: - Public Methods (the only way to change state)
    func loadItems() async { ... }
    func deleteItem(_ item: ExampleItem) async throws { ... }
}
```

**Why this pattern?**
- `private(set)` ensures state can only change through methods (predictable)
- Protocol-typed dependencies enable mock injection for testing
- `async` methods work naturally with SwiftUI's `.task` modifier

### Dependency Injection via Environment

**Why Environment over singletons or manual injection?**

```swift
// SINGLETON (avoid)
class APIClient {
    static let shared = APIClient()  // Hard to test, hidden dependency
}

// MANUAL INJECTION (verbose)
struct MyView: View {
    let apiClient: APIClient  // Must pass through every view
}

// ENVIRONMENT (our choice)
struct MyView: View {
    @Environment(APIClient.self) private var apiClient  // Available everywhere
}
```

Benefits of Environment:
- **Testable**: Inject mocks in previews and tests
- **Clean**: No prop drilling through view hierarchy
- **SwiftUI-native**: Built into the framework

**Setup in App entry point**:
```swift
@main
struct BoilerplateApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(APIClient())        // Available to all views
                .environment(AuthService())
                .environment(Router.shared)
        }
        .modelContainer(SwiftDataContainer.shared)  // SwiftData
    }
}
```

### Type-Safe Navigation

**Why a Router pattern?**

```swift
// WITHOUT Router (fragile)
NavigationLink("Details", value: "item_123")  // String = runtime errors

// WITH Router (safe)
router.navigate(to: .exampleDetail(id: "item_123"))  // Compile-time checked
```

**Route enum provides**:
- **Compile-time safety**: Typos are caught by the compiler
- **Refactoring support**: Rename routes and Xcode updates all usages
- **Deep linking ready**: Routes map directly to URL paths
- **Centralized navigation**: All possible destinations in one place

```swift
enum Route: Hashable {
    case home
    case exampleList
    case exampleDetail(id: String)  // Associated values for parameters
    case settings
}
```

**Router implementation**:
```swift
@Observable
final class Router {
    var path = NavigationPath()
    var presentedSheet: Sheet?

    func navigate(to route: Route) {
        path.append(route)
    }

    func pop() {
        path.removeLast()
    }

    func popToRoot() {
        path.removeLast(path.count)
    }
}
```

---

## Networking

### Protocol-Based API Client

**Why protocols?**

```swift
// Protocol defines the contract
protocol APIClientProtocol: Sendable {
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T
}

// Real implementation
final class APIClient: APIClientProtocol { ... }

// Mock for testing
final class MockAPIClient: APIClientProtocol { ... }
```

Benefits:
- **Testable**: Inject `MockAPIClient` in tests
- **Flexible**: Swap implementations without changing calling code
- **Documented**: Protocol is the contract/documentation

### Type-Safe Endpoints

**Why an enum over strings?**

```swift
// STRINGS (error-prone)
let url = baseURL + "/items/\(id)"  // Typo = runtime crash

// ENUM (safe)
enum APIEndpoint {
    case getItem(id: String)

    var path: String {
        switch self {
        case .getItem(let id): return "/items/\(id)"
        }
    }
}
```

Benefits:
- **Discoverable**: Autocomplete shows all endpoints
- **Type-safe parameters**: Can't pass wrong types
- **Centralized**: All API surface in one file
- **Self-documenting**: Endpoint names describe what they do

### Typed Errors

**Why custom error types?**

```swift
enum APIError: Error, LocalizedError {
    case networkUnavailable
    case unauthorized
    case serverError(statusCode: Int, message: String?)

    var errorDescription: String? { ... }  // User-friendly messages
    var isRecoverable: Bool { ... }        // Can user retry?
    var suggestedAction: String? { ... }   // What should user do?
}
```

Benefits:
- **Actionable UI**: Show appropriate error states based on error type
- **Retry logic**: Only retry recoverable errors
- **Logging**: Log detailed info for debugging
- **Localization**: Centralized error messages

---

## Persistence

### Three-Tier Strategy

| Data Type | Storage | Why |
|-----------|---------|-----|
| Structured data (models) | SwiftData | Apple's modern ORM, CloudKit sync |
| Sensitive data (tokens) | Keychain | Encrypted, survives app reinstall |
| Preferences (settings) | UserDefaults | Simple key-value, fast |

**Why not put everything in one place?**
- Tokens in UserDefaults = security vulnerability
- Preferences in SwiftData = overkill, slower
- Large data in Keychain = not designed for it

### SwiftData Setup

```swift
@Model
final class ExampleItem {
    @Attribute(.unique) var id: String  // Unique constraint
    var title: String
    var createdAt: Date
}
```

**Why SwiftData over Core Data?**
- **Swift-native**: No NSManagedObject, uses Swift types
- **Less boilerplate**: No .xcdatamodeld file
- **Better SwiftUI integration**: Works with `@Query`
- **CloudKit built-in**: Just set `cloudKitDatabase: .automatic`

### Type-Safe UserDefaults

```swift
// UNSAFE
UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
let value = UserDefaults.standard.bool(forKey: "hasCompletedOnboaring")  // Typo!

// SAFE (our approach)
@UserDefault(key: "hasCompletedOnboarding", defaultValue: false)
static var hasCompletedOnboarding: Bool

UserDefaultsWrapper.hasCompletedOnboarding = true  // Type-checked, autocomplete
```

---

## UI Components

### Component Design Philosophy

**Why reusable components?**

| Without Components | With Components |
|-------------------|-----------------|
| Copy-paste button styles | `PrimaryButton(title: "Save")` |
| Inconsistent spacing | `UIConstants.Spacing.md` |
| Different loading states | `LoadingView(message: "...")` |

Benefits:
- **Consistency**: Same look everywhere
- **Maintainability**: Change once, update everywhere
- **Speed**: Don't reinvent the wheel

### Loading State Pattern

```swift
enum LoadingState<T: Equatable>: Equatable {
    case idle
    case loading
    case loaded(T)
    case error(AppError)
}
```

**Why a generic enum?**

```swift
// In ViewModel
@Observable
class MyViewModel {
    var loadingState: LoadingState<[Item]> = .idle

    func load() async {
        loadingState = .loading
        do {
            let items = try await api.getItems()
            loadingState = .loaded(items)
        } catch {
            loadingState = .error(.from(error))
        }
    }
}

// In View
switch viewModel.loadingState {
case .idle, .loading:
    LoadingView()
case .loaded(let items):
    ItemList(items: items)
case .error(let error):
    ErrorView(error: error, onRetry: viewModel.load)
}
```

Benefits:
- **Exhaustive handling**: Compiler ensures all states handled
- **Single source of truth**: Can't be loading AND have an error
- **Reusable**: Works for any data type

---

## Testing

### Why Swift Testing over XCTest?

```swift
// XCTEST (old)
func testLoadItems() async throws {
    XCTAssertEqual(viewModel.items.count, 0)
    await viewModel.load()
    XCTAssertEqual(viewModel.items.count, 3)
}

// SWIFT TESTING (new, our choice)
@Test("ViewModel loads items successfully")
func testLoadItems() async throws {
    #expect(viewModel.items.count == 0)
    await viewModel.load()
    #expect(viewModel.items.count == 3)
}
```

Benefits:
- **Better output**: `#expect` shows actual vs expected
- **Parameterized tests**: Test multiple inputs easily
- **Tags**: Organize tests by category
- **Modern syntax**: Cleaner, more readable

### Mock Strategy

```swift
// Protocol enables mocking
protocol APIClientProtocol {
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T
}

// Mock captures calls and returns controlled responses
final class MockAPIClient: APIClientProtocol {
    var mockResponse: Any?
    var mockError: Error?
    var requestedEndpoints: [APIEndpoint] = []

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        requestedEndpoints.append(endpoint)  // Track what was called
        if let error = mockError { throw error }
        return mockResponse as! T
    }
}
```

**Why this approach?**
- **Control responses**: Test success and error paths
- **Verify calls**: Assert correct endpoints were called
- **No network**: Tests are fast and reliable

---

## Code Quality

### SwiftLint Rules

Key rules we enable and why:

| Rule | Why |
|------|-----|
| `force_unwrapping` | Crashes are bugs; handle optionals properly |
| `implicit_return` | Cleaner single-expression functions |
| `sorted_imports` | Consistent, easy to find imports |
| `vertical_whitespace` | Consistent spacing |

### SwiftFormat Configuration

Key settings:
- `--indent 4` - Apple's standard
- `--wraparguments before-first` - Readable multi-line calls
- `--self remove` - Less noise (Swift doesn't require `self.`)

---

## Configuration

### Environment-Based Settings

```swift
enum AppEnvironment {
    case development, staging, production

    static var current: AppEnvironment {
        #if DEBUG
        return .development
        #else
        return .production  // Safe default
        #endif
    }

    var baseURL: URL {
        switch self {
        case .development: return URL(string: "https://api-dev.example.com")!
        case .staging: return URL(string: "https://api-staging.example.com")!
        case .production: return URL(string: "https://api.example.com")!
        }
    }
}
```

**Why this pattern?**
- **No runtime strings**: Can't misconfigure
- **Safe defaults**: Production if unsure
- **All config in one place**: Easy to audit

---

## Getting Help

- **Issues**: [GitHub Issues](https://github.com/10x-oss/ios-boilerplate/issues)
- **Discussions**: [GitHub Discussions](https://github.com/10x-oss/ios-boilerplate/discussions)

## License

MIT License - see [LICENSE](LICENSE) for details.

---

Built with care by [10x-oss](https://github.com/10x-oss)
