import Foundation

/// Generic loading state for async operations
enum LoadingState<T: Equatable>: Equatable {
    case idle
    case loading
    case loaded(T)
    case error(AppError)

    // MARK: - Computed Properties

    /// Whether the state is currently loading
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }

    /// Whether data has been loaded successfully
    var isLoaded: Bool {
        if case .loaded = self {
            return true
        }
        return false
    }

    /// Whether an error occurred
    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }

    /// The loaded value, if any
    var value: T? {
        if case .loaded(let value) = self {
            return value
        }
        return nil
    }

    /// The error, if any
    var error: AppError? {
        if case .error(let error) = self {
            return error
        }
        return nil
    }

    // MARK: - Equatable

    static func == (lhs: LoadingState<T>, rhs: LoadingState<T>) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.loading, .loading):
            return true
        case (.loaded(let lhsValue), .loaded(let rhsValue)):
            return lhsValue == rhsValue
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

extension LoadingState {
    /// Map the loaded value to a new type
    func map<U: Equatable>(_ transform: (T) -> U) -> LoadingState<U> {
        switch self {
        case .idle:
            return .idle
        case .loading:
            return .loading
        case .loaded(let value):
            return .loaded(transform(value))
        case .error(let error):
            return .error(error)
        }
    }

    /// Flat map the loaded value
    func flatMap<U: Equatable>(_ transform: (T) -> LoadingState<U>) -> LoadingState<U> {
        switch self {
        case .idle:
            return .idle
        case .loading:
            return .loading
        case .loaded(let value):
            return transform(value)
        case .error(let error):
            return .error(error)
        }
    }
}

// MARK: - App Error

/// Unified app error type
enum AppError: Error, LocalizedError, Equatable {
    // MARK: - Cases

    case api(APIError)
    case validation(String)
    case persistence(String)
    case unknown(String)

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .api(let apiError):
            return apiError.localizedDescription
        case .validation(let message):
            return message
        case .persistence(let message):
            return message
        case .unknown(let message):
            return message
        }
    }

    // MARK: - Factory Methods

    static func from(_ error: Error) -> AppError {
        if let apiError = error as? APIError {
            return .api(apiError)
        }
        if let appError = error as? AppError {
            return appError
        }
        return .unknown(error.localizedDescription)
    }

    // MARK: - Equatable

    static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
        case (.api(let lhsError), .api(let rhsError)):
            return lhsError == rhsError
        case (.validation(let lhsMsg), .validation(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.persistence(let lhsMsg), .persistence(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.unknown(let lhsMsg), .unknown(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

// MARK: - Pagination State

/// State for paginated data loading
struct PaginationState<T: Equatable>: Equatable {
    var items: [T] = []
    var currentPage: Int = 1
    var hasMorePages: Bool = true
    var isLoadingMore: Bool = false
    var error: AppError?

    var isEmpty: Bool {
        items.isEmpty
    }

    var canLoadMore: Bool {
        hasMorePages && !isLoadingMore && error == nil
    }

    mutating func reset() {
        items = []
        currentPage = 1
        hasMorePages = true
        isLoadingMore = false
        error = nil
    }

    mutating func appendPage(_ newItems: [T], hasMore: Bool) {
        items.append(contentsOf: newItems)
        currentPage += 1
        hasMorePages = hasMore
        isLoadingMore = false
    }
}
