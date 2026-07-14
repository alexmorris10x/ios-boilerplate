# Architecture Guide

This document provides an in-depth explanation of the architectural decisions in this iOS boilerplate. Understanding the "why" behind each choice will help you make informed decisions when building on top of this foundation.

## Table of Contents

1. [Architectural Philosophy](#architectural-philosophy)
2. [MVVM Pattern](#mvvm-pattern)
3. [Production App SOP](#production-app-sop)
4. [Folder Structure](#folder-structure)
5. [Dependency Injection](#dependency-injection)
6. [Navigation Architecture](#navigation-architecture)
7. [Networking Layer](#networking-layer)
8. [Data Persistence](#data-persistence)
9. [State Management](#state-management)
10. [Error Handling](#error-handling)
11. [Testing Strategy](#testing-strategy)
12. [Code Organization](#code-organization)
13. [Decision Records](#decision-records)

---

## Architectural Philosophy

### Core Principles

1. **Simplicity over cleverness** - Choose boring, well-understood patterns over novel solutions
2. **Testability by design** - Every component should be testable in isolation
3. **Explicit over implicit** - Dependencies and data flow should be visible and traceable
4. **Progressive complexity** - Start simple, add complexity only when needed
5. **Apple-first** - Prefer Apple frameworks when they meet requirements

### Why These Principles Matter

**Simplicity**: Complex architectures (VIPER, Clean Architecture with 5+ layers) add cognitive overhead. Most iOS apps don't need them. MVVM provides sufficient separation for apps up to medium complexity.

**Testability**: If you can't test a component easily, it's often a sign of tight coupling. Protocol-based dependencies make testing straightforward.

**Explicit**: SwiftUI's Environment provides a clean way to inject dependencies without hiding them in singletons. You can always see what a view depends on.

**Progressive**: This boilerplate is a starting point, not a final architecture. Add what you need, when you need it.

**Apple-first**: Third-party libraries add maintenance burden and can break with OS updates. SwiftData, async/await, and NavigationStack are battle-tested.

**Provider-neutral growth plumbing**: Production apps need monetization, reviews, analytics, support, privacy, and release operations, but the boilerplate should not force every app to ship the same SDK stack. Shared services define the boundaries; derived apps choose RevenueCat, PostHog, Sentry, Superwall, or alternatives when the product needs them.

---

## MVVM Pattern

### What is MVVM?

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│    View     │────▶│  ViewModel  │────▶│    Model    │
│  (SwiftUI)  │◀────│ (@Observable)│◀────│  (Data)     │
└─────────────┘     └─────────────┘     └─────────────┘
     UI               Business Logic        Data
```

- **View**: Displays data, captures user input, declarative SwiftUI
- **ViewModel**: Transforms data for display, handles user actions, contains business logic
- **Model**: Data structures, persistence, networking responses

### Why MVVM for SwiftUI?

| Alternative | Pros | Cons | Verdict |
|-------------|------|------|---------|
| **MVC** | Simple, Apple's original pattern | Massive View Controllers, hard to test | Not suitable for SwiftUI |
| **MVVM** | Clean separation, testable, SwiftUI-native | Slightly more files | ✅ Best fit |
| **VIPER** | Very separated, enterprise-grade | Overkill for most apps, many files | Too complex |
| **TCA** | Predictable state, time-travel debugging | Steep learning curve, Combine dependency | Good for specific use cases |

MVVM hits the sweet spot: enough separation for testability without drowning in abstraction layers.

### @Observable vs ObservableObject

We use `@Observable` (iOS 17+) instead of `ObservableObject` for several important reasons:

```swift
// ❌ OLD: ObservableObject (iOS 13+)
class OldViewModel: ObservableObject {
    @Published var items: [Item] = []        // Must annotate every published property
    @Published var isLoading = false         // Easy to forget @Published
    @Published var errorMessage: String?     // Causes full view re-render on ANY change
    var internalState = 0                    // This won't trigger updates (is that intentional?)
}

// ✅ NEW: @Observable (iOS 17+)
@Observable
class NewViewModel {
    var items: [Item] = []                   // Automatically tracked
    var isLoading = false                    // No annotations needed
    var errorMessage: String?                // Only views using this property re-render
    private var internalState = 0            // Private = not observed (clear intent)
}
```

**Key differences:**

| Aspect | ObservableObject | @Observable |
|--------|------------------|-------------|
| Property annotation | Required (`@Published`) | Automatic |
| View updates | All `@Published` changes trigger updates | Only accessed properties trigger updates |
| Performance | Can cause unnecessary re-renders | More granular, better performance |
| Boilerplate | More verbose | Cleaner code |
| Debugging | Harder to track what triggers updates | Clearer update tracking |

### ViewModel Structure Convention

Every ViewModel in this boilerplate follows this structure:

```swift
@Observable
final class FeatureViewModel {
    // MARK: - Published State (what the View reads)
    private(set) var items: [Item] = []
    private(set) var loadingState: LoadingState<[Item]> = .idle

    // MARK: - Internal State (not for View consumption)
    private var currentPage = 1

    // MARK: - Dependencies (injected for testability)
    private let apiService: APIServiceProtocol
    private let analytics: AnalyticsServiceProtocol

    // MARK: - Initialization
    init(apiService: APIServiceProtocol = APIService(),
         analytics: AnalyticsServiceProtocol = AnalyticsService()) {
        self.apiService = apiService
        self.analytics = analytics
    }

    // MARK: - Public Methods (actions the View can trigger)
    func loadItems() async { ... }
    func deleteItem(_ item: Item) async throws { ... }

    // MARK: - Private Methods (internal logic)
    private func processItems(_ raw: [RawItem]) -> [Item] { ... }
}
```

**Why `private(set)`?**

```swift
// ❌ Without private(set): View can mutate state directly
viewModel.items = []  // Bypasses business logic!

// ✅ With private(set): State only changes through methods
viewModel.loadItems()  // Goes through proper flow
```

This ensures all state changes go through methods where you can add logging, validation, or side effects.

---

## Production App SOP

The full launch checklist lives in [docs/PRODUCTION-READINESS-CHECKLIST.md](docs/PRODUCTION-READINESS-CHECKLIST.md). Architecturally, the boilerplate provides stable seams for the surfaces every production app should decide on before App Store submission:

| Surface | Boilerplate Boundary | Default Behavior |
|---------|----------------------|------------------|
| Onboarding | `Features/Onboarding/Views/OnboardingView.swift` | Tracks start/completion and then marks onboarding complete |
| Monetization | `PaywallService` + paywall/subscription views | Shows not-configured states until a purchase provider is connected |
| Reviews | `ReviewPromptService` + root `requestReview` integration | Prompts only after local eligibility rules pass |
| Analytics | `AnalyticsService` + `AnalyticsEvent` names | Logs provider-neutral events for PostHog or another backend |
| Settings and trust | `SettingsView` | Centralizes support, legal, subscription, review, version, and account actions |
| Privacy | `PrivacyInfo.xcprivacy` | Declares current UserDefaults required-reason API usage |

### Monetization Boundary

`PaywallService` is intentionally provider-neutral. For a subscription app, keep the public interface and replace the internals with RevenueCat or StoreKit calls. If the app needs remote paywall placement and experimentation, add Superwall at the placement layer while keeping RevenueCat or StoreKit as the entitlement source of truth.

### Review Prompt Boundary

`ReviewPromptService` does not call StoreKit directly. It records success moments and exposes a pending prompt request. `RootView` owns Apple's SwiftUI `requestReview` environment action, which keeps eligibility logic testable and prevents custom review prompts.

### Project Generation

`project.yml` is the source of truth for Xcode project settings. Generated `.xcodeproj` files are local artifacts and should stay untracked. CI runs `xcodegen generate` before stamping build numbers or invoking Xcode.

---

## Folder Structure

### Feature-Based vs Layer-Based

We use **feature-based** organization:

```
// ✅ Feature-based (our choice)
Features/
├── Auth/
│   ├── Views/
│   │   ├── LoginView.swift
│   │   └── SignUpView.swift
│   ├── ViewModels/
│   │   └── AuthViewModel.swift
│   └── Models/
│       └── User.swift
├── Settings/
│   └── ...
└── Example/
    └── ...
```

```
// ❌ Layer-based (not our choice)
Views/
├── LoginView.swift
├── SignUpView.swift
├── SettingsView.swift
└── ExampleListView.swift
ViewModels/
├── AuthViewModel.swift
├── SettingsViewModel.swift
└── ExampleListViewModel.swift
Models/
├── User.swift
└── ExampleItem.swift
```

### Why Feature-Based?

| Scenario | Feature-Based | Layer-Based |
|----------|---------------|-------------|
| "I need to work on Auth" | Open `Features/Auth/` - everything's there | Open 3+ folders, hunt for related files |
| "Delete the Example feature" | Delete `Features/Example/` | Find and delete files across many folders |
| Adding a new feature | Create one folder, add files | Touch 3+ existing folders |
| Code review | Changes grouped by feature | Changes scattered across folders |
| Team scaling | Teams own features | Merge conflicts across shared folders |

Feature-based scales better as your app grows. When working on a feature, you rarely need to jump between distant folders.

### Core vs Shared

```
Core/       → Infrastructure that features DEPEND ON
Shared/     → Reusable code that features USE
```

**Core/** contains foundational services:
- Networking (APIClient)
- Persistence (SwiftData, Keychain)
- Navigation (Router)
- Services (Auth, Analytics)

**Shared/** contains reusable UI elements:
- Components (buttons, forms)
- Extensions (Color, View)
- Styles (themes)
- View Modifiers

**Why separate them?**

```swift
// Core depends on nothing in Features or Shared
// (can be extracted to a separate module)

// Shared might depend on Core (e.g., a component using AppTheme)
// but never on Features

// Features depend on Core and Shared
// but never on each other (prevents coupling)
```

This layering prevents circular dependencies and makes it easy to identify what depends on what.

---

## Dependency Injection

### SwiftUI Environment

We use SwiftUI's `@Environment` for dependency injection:

```swift
// App setup
@main
struct BoilerplateApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(APIClient())
                .environment(AuthService())
                .environment(Router.shared)
        }
    }
}

// In any view
struct MyView: View {
    @Environment(APIClient.self) private var apiClient
    @Environment(AuthService.self) private var authService

    var body: some View { ... }
}
```

### Why Environment Over Alternatives?

| Approach | Code | Testability | Visibility |
|----------|------|-------------|------------|
| Singletons | `APIClient.shared` | ❌ Hard to mock | ❌ Hidden dependency |
| Constructor injection | `init(api: APIClient)` | ✅ Easy to mock | ⚠️ Prop drilling |
| Environment | `@Environment(APIClient.self)` | ✅ Easy to mock | ✅ Visible in code |

**Singletons are problematic:**
```swift
// ❌ Singleton: hidden dependency, hard to test
class MyViewModel {
    func loadData() {
        APIClient.shared.fetch(...)  // Can't mock this in tests
    }
}

// ✅ Environment: explicit, testable
class MyViewModel {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }
}
```

**Testing with Environment is clean:**
```swift
// In tests
let mockAPI = MockAPIClient()
mockAPI.mockResponse = [Item(id: "1", title: "Test")]

let viewModel = MyViewModel(apiClient: mockAPI)
await viewModel.loadData()

#expect(viewModel.items.count == 1)
```

**In SwiftUI previews:**
```swift
#Preview {
    MyView()
        .environment(MockAPIClient())  // Easy preview with mock data
}
```

---

## Navigation Architecture

### The Router Pattern

We use a centralized `Router` with type-safe `Route` enum:

```swift
enum Route: Hashable {
    case home
    case exampleList
    case exampleDetail(id: String)
    case settings
    case settingsAbout
}

@Observable
final class Router {
    var path = NavigationPath()
    var presentedSheet: Sheet?
    var presentedFullScreenCover: FullScreenCover?

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

### Why Type-Safe Routes?

```swift
// ❌ String-based navigation (fragile)
NavigationLink("Details", value: "item_123")
// Later...
if destination == "item_123" { ... }  // Easy to typo, no compile-time safety

// ✅ Type-safe routes (robust)
router.navigate(to: .exampleDetail(id: "item_123"))
// Compiler ensures all routes are handled
```

**Benefits:**

| Benefit | Explanation |
|---------|-------------|
| Compile-time safety | Typos caught by compiler |
| Refactoring | Rename a route, Xcode updates all usages |
| Discoverability | Autocomplete shows all possible destinations |
| Deep linking | Routes map directly to URL paths |
| Centralized | All navigation logic in one place |

### NavigationStack Integration

```swift
struct RootView: View {
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .home:
                        HomeView()
                    case .exampleList:
                        ExampleListView()
                    case .exampleDetail(let id):
                        ExampleDetailView(itemId: id)
                    case .settings:
                        SettingsView()
                    case .settingsAbout:
                        AboutView()
                    }
                }
        }
        .sheet(item: $router.presentedSheet) { sheet in
            // Sheet content
        }
    }
}
```

**Why NavigationStack over NavigationView?**

`NavigationView` is deprecated in iOS 16+. `NavigationStack` provides:
- Programmatic navigation control
- Type-safe destinations
- Better performance
- Support for deep linking

---

## Networking Layer

### Protocol-Based Design

```swift
protocol APIClientProtocol: Sendable {
    func request<T: Decodable & Sendable>(_ endpoint: APIEndpoint) async throws -> T
}

final class APIClient: APIClientProtocol, @unchecked Sendable {
    func request<T: Decodable & Sendable>(_ endpoint: APIEndpoint) async throws -> T {
        // Implementation
    }
}
```

**Why protocols?**

```swift
// ✅ Protocol enables testing without network
final class MockAPIClient: APIClientProtocol {
    var mockResponse: Any?
    var mockError: Error?

    func request<T: Decodable & Sendable>(_ endpoint: APIEndpoint) async throws -> T {
        if let error = mockError { throw error }
        return mockResponse as! T
    }
}

// In tests:
let mock = MockAPIClient()
mock.mockResponse = [Item(id: "1", title: "Test")]
let viewModel = MyViewModel(apiClient: mock)
// Test without hitting real network
```

### Type-Safe Endpoints

```swift
enum APIEndpoint {
    case getItems
    case getItem(id: String)
    case createItem(title: String, description: String?)
    case updateItem(id: String, title: String?, description: String?)
    case deleteItem(id: String)

    var path: String {
        switch self {
        case .getItems: return "/items"
        case .getItem(let id): return "/items/\(id)"
        case .createItem: return "/items"
        case .updateItem(let id, _, _): return "/items/\(id)"
        case .deleteItem(let id): return "/items/\(id)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .getItems, .getItem: return .get
        case .createItem: return .post
        case .updateItem: return .put
        case .deleteItem: return .delete
        }
    }
}
```

**Benefits over string URLs:**

| Aspect | String URLs | Type-Safe Endpoints |
|--------|-------------|---------------------|
| Typos | Runtime crash | Compile error |
| Parameters | Manual string interpolation | Type-checked |
| Discoverability | Grep through codebase | Autocomplete |
| Refactoring | Find and replace (risky) | Rename symbol (safe) |
| Documentation | External docs needed | Self-documenting |

### Middleware Architecture

```swift
protocol APIMiddleware: Sendable {
    func prepare(_ request: URLRequest, endpoint: APIEndpoint) async throws -> URLRequest
    func process<T>(_ response: T, endpoint: APIEndpoint) async throws -> T
}
```

**Why middleware?**

Separates cross-cutting concerns:
- `AuthMiddleware`: Adds authentication tokens
- `LoggingMiddleware`: Logs requests/responses

Without middleware, every request would need:
```swift
// ❌ Repeated code in every request
var request = URLRequest(url: url)
request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")  // Auth
Logger.debug("Request: \(request)")  // Logging
```

With middleware:
```swift
// ✅ Configure once, applies everywhere
apiClient.addMiddleware(AuthMiddleware(authService: authService))
apiClient.addMiddleware(LoggingMiddleware())
```

---

## Data Persistence

### Three-Tier Strategy

| Data Type | Storage | Reasoning |
|-----------|---------|-----------|
| Structured data | SwiftData | Relationships, queries, CloudKit sync |
| Sensitive data | Keychain | Encrypted, survives reinstall |
| Preferences | UserDefaults | Fast, simple key-value |

**Why not put everything in one place?**

- **Tokens in UserDefaults** → Security vulnerability (unencrypted plist)
- **Preferences in SwiftData** → Overkill, slower for simple values
- **Large data in Keychain** → Not designed for it, size limits

### SwiftData vs Core Data

| Aspect | Core Data | SwiftData |
|--------|-----------|-----------|
| Setup | Verbose, .xcdatamodeld file | Swift macros, no schema file |
| Types | NSManagedObject | Pure Swift classes |
| SwiftUI | Manual integration | Native @Query support |
| CloudKit | Possible but complex | Built-in |
| Learning curve | Steep | Gentle |

```swift
// Core Data (verbose)
@objc(Item)
class Item: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var title: String
}

// SwiftData (clean)
@Model
final class Item {
    var id: String
    var title: String
}
```

### Keychain for Secrets

```swift
final class KeychainManager {
    func save(_ data: Data, for key: String) throws { ... }
    func retrieve(for key: String) throws -> Data? { ... }
    func delete(for key: String) throws { ... }
}
```

**Never store these in UserDefaults:**
- API tokens
- Auth credentials
- Encryption keys
- Session tokens

Keychain data:
- ✅ Encrypted at rest
- ✅ Survives app reinstall
- ✅ Can sync via iCloud Keychain
- ✅ Protected by device passcode/biometrics

### Type-Safe UserDefaults

```swift
// ❌ Unsafe: typos, wrong types
UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
let value = UserDefaults.standard.bool(forKey: "hasSeenOnboading")  // Typo!

// ✅ Type-safe with property wrapper
@propertyWrapper
struct UserDefault<Value> {
    let key: String
    let defaultValue: Value

    var wrappedValue: Value {
        get { UserDefaults.standard.object(forKey: key) as? Value ?? defaultValue }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

// Usage
enum UserPreferences {
    @UserDefault(key: "hasSeenOnboarding", defaultValue: false)
    static var hasSeenOnboarding: Bool
}

// Can't typo, type-checked
UserPreferences.hasSeenOnboarding = true
```

---

## State Management

### LoadingState Enum

```swift
enum LoadingState<T: Equatable>: Equatable {
    case idle
    case loading
    case loaded(T)
    case error(AppError)
}
```

**Why a generic enum over boolean flags?**

```swift
// ❌ Boolean flags (error-prone)
class ViewModel {
    var items: [Item] = []
    var isLoading = false
    var error: Error?

    // Problem: Can be in invalid states!
    // isLoading = true AND error != nil ???
}

// ✅ Enum (impossible invalid states)
class ViewModel {
    var state: LoadingState<[Item]> = .idle

    // Can only be ONE state at a time
}
```

**Exhaustive switch handling:**

```swift
switch viewModel.state {
case .idle:
    Text("Pull to refresh")
case .loading:
    ProgressView()
case .loaded(let items):
    ItemList(items: items)
case .error(let error):
    ErrorView(error: error)
}
// Compiler ensures all states handled!
```

### PaginationState

```swift
struct PaginationState {
    var currentPage: Int = 1
    var totalPages: Int = 1
    var isLoadingMore: Bool = false

    var hasMorePages: Bool { currentPage < totalPages }
    var canLoadMore: Bool { hasMorePages && !isLoadingMore }
}
```

Encapsulates pagination logic so Views don't need to compute it:

```swift
// In View
if viewModel.pagination.canLoadMore {
    Button("Load More") { await viewModel.loadMore() }
}
```

---

## Error Handling

### Typed Errors

```swift
enum APIError: Error, LocalizedError {
    case networkUnavailable
    case invalidURL
    case unauthorized
    case forbidden
    case notFound
    case serverError(statusCode: Int, message: String?)
    case decodingError(Error)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable: return "No internet connection"
        case .unauthorized: return "Please log in again"
        // ...
        }
    }

    var isRecoverable: Bool {
        switch self {
        case .networkUnavailable, .serverError: return true
        case .unauthorized, .forbidden: return false
        // ...
        }
    }
}
```

**Why typed errors over raw Error?**

```swift
// ❌ Raw Error: no context
catch {
    showError("Something went wrong")  // Unhelpful to user
}

// ✅ Typed Error: actionable
catch let error as APIError {
    switch error {
    case .networkUnavailable:
        showError("Check your internet connection", canRetry: true)
    case .unauthorized:
        router.navigate(to: .login)
    case .serverError(let code, _):
        analytics.track("server_error", ["code": code])
        showError("Server error, please try again later")
    }
}
```

### AppError Wrapper

```swift
struct AppError: Error, Equatable, Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let isRecoverable: Bool

    static func from(_ error: Error) -> AppError {
        if let apiError = error as? APIError {
            return AppError(
                title: "Network Error",
                message: apiError.localizedDescription,
                isRecoverable: apiError.isRecoverable
            )
        }
        return AppError(
            title: "Error",
            message: error.localizedDescription,
            isRecoverable: false
        )
    }
}
```

**Used in LoadingState:**
```swift
case .error(let appError):
    ErrorView(
        title: appError.title,
        message: appError.message,
        showRetry: appError.isRecoverable,
        onRetry: { await viewModel.refresh() }
    )
```

---

## Testing Strategy

### Swift Testing Framework

We use Swift Testing (introduced in Xcode 15) over XCTest:

```swift
// XCTest (old)
func testLoadItems() async throws {
    XCTAssertEqual(viewModel.items.count, 0)
    await viewModel.load()
    XCTAssertEqual(viewModel.items.count, 3)
}

// Swift Testing (new)
@Test("ViewModel loads items successfully")
func loadItems() async throws {
    #expect(viewModel.items.count == 0)
    await viewModel.load()
    #expect(viewModel.items.count == 3)
}
```

**Why Swift Testing?**

| Feature | XCTest | Swift Testing |
|---------|--------|---------------|
| Failure messages | "XCTAssertEqual failed: 0 is not equal to 3" | Shows actual expression and values |
| Parameterized tests | Manual loops | Built-in `@Test(arguments:)` |
| Test organization | Class-based | Struct-based with tags |
| Parallel execution | Limited | Better support |
| Syntax | Verbose | Modern, clean |

### Mock Strategy

Every protocol gets a mock:

```swift
// Protocol
protocol APIClientProtocol {
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T
}

// Mock
final class MockAPIClient: APIClientProtocol {
    var mockResponse: Any?
    var mockError: Error?
    var requestedEndpoints: [APIEndpoint] = []  // Track calls

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        requestedEndpoints.append(endpoint)  // Record what was called
        if let error = mockError { throw error }
        return mockResponse as! T
    }
}
```

**Testing with mocks:**

```swift
@Test("ViewModel calls correct endpoint")
func callsCorrectEndpoint() async {
    let mock = MockAPIClient()
    mock.mockResponse = [Item(id: "1", title: "Test")]

    let viewModel = MyViewModel(apiClient: mock)
    await viewModel.loadItems()

    #expect(mock.requestedEndpoints.contains(.getItems))
}

@Test("ViewModel handles error gracefully")
func handlesError() async {
    let mock = MockAPIClient()
    mock.mockError = APIError.networkUnavailable

    let viewModel = MyViewModel(apiClient: mock)
    await viewModel.loadItems()

    #expect(viewModel.state.isError)
}
```

### What to Test

| Layer | What to Test | How |
|-------|--------------|-----|
| ViewModels | State changes, method behavior | Unit tests with mocks |
| Services | Business logic | Unit tests |
| API Client | Request building, response parsing | Unit tests with mock URLSession |
| Views | Rarely test directly | Previews, manual testing, snapshot tests |

**Focus on ViewModels** - they contain the logic. Views are mostly declarative UI.

---

## Code Organization

### MARK Comments

Every file follows consistent structure:

```swift
final class MyViewModel {
    // MARK: - Properties

    // MARK: - Dependencies

    // MARK: - Initialization

    // MARK: - Public Methods

    // MARK: - Private Methods
}
```

Makes navigation in Xcode's minimap easy.

### Access Control

| Modifier | Usage |
|----------|-------|
| `private` | Implementation details |
| `private(set)` | Readable by View, writable only by ViewModel |
| `internal` (default) | Accessible within module |
| `public` | For framework/library code |

**Default to most restrictive**, then open up as needed.

### File Naming

- **Views**: `FeatureView.swift`, `FeatureListView.swift`
- **ViewModels**: `FeatureViewModel.swift`
- **Models**: `ModelName.swift` (matches type name)
- **Protocols**: `ProtocolName.swift` or in same file as primary implementation

---

## Decision Records

### Why iOS 17+ Minimum?

**Decided**: Target iOS 17 as minimum deployment target.

**Reasoning**:
- `@Observable` macro requires iOS 17
- SwiftData requires iOS 17
- NavigationStack improvements in iOS 17
- iOS 17 adoption was >75% within 6 months of release

**Trade-off**: ~5-10% of users on iOS 16 and earlier won't be supported.

**Mitigation**: For apps requiring iOS 16, `@Observable` can be replaced with `ObservableObject`, but we recommend iOS 17+ for new projects.

### Why Not Include Third-Party Libraries?

**Decided**: Ship with zero third-party dependencies.

**Reasoning**:
- Apple's frameworks cover most needs (async/await, SwiftData, SwiftUI)
- Dependencies add maintenance burden
- Version conflicts between dependencies
- Breaking changes on OS updates
- Licensing considerations

**What we considered:**
- **Alamofire**: URLSession with async/await is sufficient
- **Realm**: SwiftData covers our needs
- **SnapKit**: SwiftUI doesn't need it
- **SDWebImage**: AsyncImage + simple caching is enough for most apps

**Exception**: Add dependencies when they provide significant value. This boilerplate is a starting point.

### Why Feature-Based Organization?

**Decided**: Organize code by feature, not by layer.

**Reasoning**: See [Folder Structure](#folder-structure) section.

**Migration from layer-based**: If converting an existing project:
1. Create feature folders
2. Move related files together
3. Keep `Core/` and `Shared/` as-is
4. Update import statements

### Why Environment Over Singletons?

**Decided**: Use SwiftUI Environment for dependency injection.

**Reasoning**: See [Dependency Injection](#dependency-injection) section.

**When singletons are OK**: True global state like `Router.shared` (navigation is inherently app-wide). Even then, inject via Environment for testability.

---

## Further Reading

- [Apple's SwiftUI documentation](https://developer.apple.com/documentation/swiftui)
- [Swift Concurrency documentation](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency)
- [SwiftData documentation](https://developer.apple.com/documentation/swiftdata)
- [WWDC23: Discover Observation in SwiftUI](https://developer.apple.com/videos/play/wwdc2023/10149/)
- [WWDC23: Meet SwiftData](https://developer.apple.com/videos/play/wwdc2023/10187/)

---

*This document is part of the [iOS Boilerplate](https://github.com/alexmorris10x/ios-boilerplate) project.*
