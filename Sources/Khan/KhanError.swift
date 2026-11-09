/// Why a ``Khan`` could not be created or did not finish.
public enum KhanError: Error {
    /// An initializer depends on one that was not registered.
    case missingDependency(Initializer.Type, dependency: Initializer.Type)

    /// The dependencies form a cycle. The first and last element are the same type.
    case cycle([Initializer.Type])

    /// One or more initializers threw. `skipped` never ran because a dependency failed.
    case failed([Failure], skipped: [Initializer.Type])

    public struct Failure: Sendable {
        public let initializer: Initializer.Type
        public let error: Error
    }
}

extension KhanError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .missingDependency(initializer, dependency):
            "\(initializer) depends on \(dependency), which is not registered"
        case let .cycle(path):
            "dependency cycle: \(path.map { "\($0)" }.joined(separator: " -> "))"
        case let .failed(failures, skipped):
            "failed: " + failures.map { "\($0.initializer) (\($0.error))" }.joined(separator: ", ")
                + (skipped.isEmpty ? "" : "; skipped: " + skipped.map { "\($0)" }.joined(separator: ", "))
        }
    }
}
