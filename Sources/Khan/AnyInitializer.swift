/// A type-erased wrapper for `Initializer` types.
///
/// `AnyInitializer` allows for the creation of homogeneous collections of different
/// `Initializer` types. It conforms to `Hashable`, enabling its use in sets and as
/// dictionary keys.
///
/// This struct is crucial for the internal workings of the dependency management system,
/// allowing it to handle different initializer types uniformly.
///
/// # Usage
///
/// Typically, you won't need to create `AnyInitializer` instances directly.
/// The dependency management system uses this internally. However, understanding
/// its purpose can help in debugging and extending the system.
///
/// ```swift
/// let databaseInitializer = AnyInitializer(DatabaseInitializer.self)
/// let networkInitializer = AnyInitializer(NetworkInitializer.self)
///
/// let initializerSet: Set<AnyInitializer> = [databaseInitializer, networkInitializer]
/// ```
struct AnyInitializer: Hashable {
    /// The type-erased `Initializer` type.
    let type: Initializer.Type

    /// Creates a new `AnyInitializer` instance.
    ///
    /// - Parameter type: The concrete `Initializer` type to wrap.
    init(_ type: Initializer.Type) {
        self.type = type
    }
    
    /// Compares two `AnyInitializer` instances for equality.
    ///
    /// Two `AnyInitializer` instances are considered equal if they wrap the same `Initializer` type.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side `AnyInitializer` instance.
    ///   - rhs: The right-hand side `AnyInitializer` instance.
    /// - Returns: `true` if the wrapped types are the same, `false` otherwise.
    static func == (lhs: AnyInitializer, rhs: AnyInitializer) -> Bool {
        lhs.type == rhs.type
    }
    
    /// Hashes the essential components of this value by feeding them into the given hasher.
    ///
    /// This method uses `ObjectIdentifier` to create a unique identifier for the wrapped type,
    /// ensuring that different `Initializer` types produce different hash values.
    ///
    /// - Parameter hasher: The hasher to use when combining the components of this instance.
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(type))
    }
}
