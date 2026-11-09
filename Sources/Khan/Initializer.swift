/// A unit of app start-up work that may declare other initializers it must run after.
///
/// ```swift
/// enum DatabaseInitializer: Initializer {
///     static let dependencies: [Initializer.Type] = [ConfigInitializer.self]
///
///     static func embark() async throws {
///         // open the database
///     }
/// }
/// ```
///
/// Annotate `embark()` with `@MainActor` if the work must run on the main thread.
public protocol Initializer: Sendable {
    /// Initializers that must finish successfully before this one starts.
    ///
    /// Every dependency must also be passed to ``Khan``.
    static var dependencies: [Initializer.Type] { get }

    /// Performs the work. Runs concurrently with unrelated initializers.
    static func embark() async throws
}

public extension Initializer {
    static var dependencies: [Initializer.Type] { [] }
}
