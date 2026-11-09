/// Runs initializers as soon as their dependencies have finished, in parallel where the graph allows.
///
/// ```swift
/// let khan = try Khan(initializers: [DatabaseInitializer.self, NetworkInitializer.self])
/// try await khan.conquer()
/// ```
///
/// The graph is validated on creation, so missing dependencies and cycles throw from `init`.
/// If an initializer throws, its transitive dependents are skipped, unrelated initializers still
/// run, and ``conquer()`` throws ``KhanError/failed(_:skipped:)`` once everything else settled.
public struct Khan {
    private let types: [Initializer.Type]
    private let dependencies: [[Int]]
    private let dependents: [[Int]]
    private let logger: (@Sendable (String) -> Void)?

    /// - Parameters:
    ///   - initializers: Every initializer to run, including all transitive dependencies. Duplicates are ignored.
    ///   - logger: Receives one line per finished initializer and the total duration.
    /// - Throws: ``KhanError/missingDependency(_:dependency:)`` or ``KhanError/cycle(_:)``.
    public init(initializers: [Initializer.Type], logger: (@Sendable (String) -> Void)? = nil) throws {
        var index: [ObjectIdentifier: Int] = [:]
        var types: [Initializer.Type] = []
        for type in initializers where index[ObjectIdentifier(type)] == nil {
            index[ObjectIdentifier(type)] = types.count
            types.append(type)
        }

        let dependencies = try types.map { type in
            try Set(type.dependencies.map { dependency in
                guard let i = index[ObjectIdentifier(dependency)] else {
                    throw KhanError.missingDependency(type, dependency: dependency)
                }
                return i
            }).sorted()
        }
        try Self.rejectCycles(in: dependencies, types: types)

        var dependents = [[Int]](repeating: [], count: types.count)
        for (node, deps) in dependencies.enumerated() {
            for dep in deps { dependents[dep].append(node) }
        }

        self.types = types
        self.dependencies = dependencies
        self.dependents = dependents
        self.logger = logger
    }

    /// Runs all initializers, starting each as soon as its dependencies succeeded.
    ///
    /// - Throws: ``KhanError/failed(_:skipped:)``.
    public func conquer() async throws {
        let clock = ContinuousClock()
        let start = clock.now
        var pending = dependencies.map(\.count)
        var succeeded = Set<Int>()
        var failures: [KhanError.Failure] = []

        await withTaskGroup(of: (Int, Error?).self) { group in
            func launch(_ node: Int) {
                let type = types[node]
                let logger = logger
                group.addTask {
                    let begin = clock.now
                    do {
                        try await type.embark()
                        logger?("\(type) done in \(begin.duration(to: clock.now).milliseconds)ms")
                        return (node, nil)
                    } catch {
                        logger?("\(type) failed in \(begin.duration(to: clock.now).milliseconds)ms: \(error)")
                        return (node, error)
                    }
                }
            }

            for node in pending.indices where pending[node] == 0 { launch(node) }

            while let (node, error) = await group.next() {
                if let error {
                    failures.append(.init(initializer: types[node], error: error))
                    continue
                }
                succeeded.insert(node)
                for dependent in dependents[node] {
                    pending[dependent] -= 1
                    if pending[dependent] == 0 { launch(dependent) }
                }
            }
        }

        logger?("conquered in \(start.duration(to: clock.now).milliseconds)ms")
        guard failures.isEmpty else {
            let failed = Set(failures.map { ObjectIdentifier($0.initializer) })
            let skipped = types.indices.filter { !succeeded.contains($0) && !failed.contains(ObjectIdentifier(types[$0])) }
            throw KhanError.failed(failures, skipped: skipped.map { types[$0] })
        }
    }

    private static func rejectCycles(in dependencies: [[Int]], types: [Initializer.Type]) throws {
        enum State { case unvisited, visiting, done }
        var state = [State](repeating: .unvisited, count: dependencies.count)
        var path: [Int] = []

        func visit(_ node: Int) throws {
            state[node] = .visiting
            path.append(node)
            for dep in dependencies[node] {
                switch state[dep] {
                case .unvisited:
                    try visit(dep)
                case .visiting:
                    let cycle = path[path.firstIndex(of: dep)!...] + [dep]
                    throw KhanError.cycle(cycle.map { types[$0] })
                case .done:
                    break
                }
            }
            path.removeLast()
            state[node] = .done
        }

        for node in dependencies.indices where state[node] == .unvisited { try visit(node) }
    }
}

private extension Duration {
    var milliseconds: Int {
        Int(components.seconds * 1_000 + components.attoseconds / 1_000_000_000_000_000)
    }
}
