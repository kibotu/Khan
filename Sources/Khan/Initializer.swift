/// A protocol defining the interface for initializable components in the application.
///
/// The `Initializer` protocol is a key part of the dependency management system.
/// It allows components to declare their dependencies and provide an initialization method.
///
/// # Usage
///
/// Conform your component's initializer to this protocol:
///
/// ```swift
/// class DatabaseInitializer: Initializer {
///     static var dependencies: [Initializer.Type] = [ConfigurationInitializer.self]
///
///     static func embark() async throws {
///         // Initialize database connection
///     }
/// }
/// ```
///
/// # Note
///
/// The term "embark" is used metaphorically, representing the start of the initialization process.
protocol Initializer {
    /// An array of initializer types that this initializer depends on.
    ///
    /// Use this property to declare other components that must be initialized
    /// before this one. The dependency management system will use this information
    /// to determine the correct initialization order.
    ///
    /// - Important: Avoid circular dependencies, as they will cause initialization to fail.
    static var dependencies: [Initializer.Type] { get }

    /// Performs the actual initialization of the component.
    ///
    /// This method is called by the dependency management system when it's this
    /// component's turn to initialize. It's marked as `async` and `throws`, allowing
    /// for asynchronous operations and error handling during initialization.
    ///
    /// - Throws: Any error that occurs during the initialization process.
    ///           These errors will be caught and handled by the dependency management system.
    static func embark() async throws
}
