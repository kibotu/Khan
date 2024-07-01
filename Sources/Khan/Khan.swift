import Foundation

/// A dependency management and initialization system for modular app components.
///
/// The `Khan` class provides a robust solution for managing and initializing app components
/// with complex dependency relationships. It uses a topological sorting algorithm to determine
/// the correct order of initialization, ensuring that all dependencies are properly satisfied.
///
/// - Important: This class detects and prevents circular dependencies, which could lead to
///   initialization deadlocks.
///
/// # Usage
///
/// ```swift
/// let initializers: [Initializer.Type] = [
///     DatabaseInitializer.self,
///     NetworkingInitializer.self,
///     AnalyticsInitializer.self
/// ]
///
/// do {
///     let khan = try Khan(initializers: initializers)
///     try await khan.conquer()
/// } catch {
///     print("Initialization failed: \(error)")
/// }
/// ```
///
/// # Features
///
/// - Dependency graph construction and validation
/// - Circular dependency detection
/// - Optional parallel initialization for improved performance
/// - Debug mode shuffling to detect order-dependent issues early
/// - Comprehensive logging for debugging and monitoring
///
/// # Note
///
/// The name "Khan" and related conquest terminology are used metaphorically,
/// representing the system's ability to "conquer" complex initialization challenges.
class Khan {
    
    /// Determines whether logging is enabled for this instance.
    ///
    /// This property uses the `@Storage` property wrapper, likely for persistent storage.
    /// The default value is `true`.
    var enableLogging: Bool = true
    
    private var initializers: [AnyInitializer]
    private var dependencyGraph: [AnyInitializer: [AnyInitializer]] = [:]
    private var inDegree: [AnyInitializer: Int] = [:]
    private var visited: Set<AnyInitializer> = []
    private var recursionStack: Set<AnyInitializer> = []

    /// Creates a new `Khan` instance with the specified initializers.
    ///
    /// - Parameters:
    ///   - initializers: An array of `Initializer.Type` objects representing the app components
    ///                   to be initialized. Default is an empty array.
    ///
    /// - Throws: An error if circular dependencies are detected during graph construction.
    init(initializers: [Initializer.Type] = []) throws {
        #if DEBUG
        // we shuffle in debug to detect order issues earlier
        self.initializers = initializers.shuffled().map { AnyInitializer($0) }
        #else
        self.initializers = initializers.map { AnyInitializer($0) }
        #endif
        try buildDependencyGraph()
        
//        printDependencyTree()
    }

    private func buildDependencyGraph() throws {
        for initializer in initializers {
            dependencyGraph[initializer] = initializer.type.dependencies.map { AnyInitializer($0) }
            inDegree[initializer] = 0
        }
        
        for (_, deps) in dependencyGraph {
            for dep in deps {
                inDegree[dep, default: 0] += 1
            }
        }
        
        for initializer in initializers {
            if !visited.contains(initializer) {
                try dfs(initializer)
            }
        }
    }

    private func dfs(_ node: AnyInitializer) throws {
        visited.insert(node)
        recursionStack.insert(node)
        
        if let dependencies = dependencyGraph[node] {
            for dependency in dependencies {
                if !visited.contains(dependency) {
                    try dfs(dependency)
                } else if recursionStack.contains(dependency) {
                    throw NSError(domain: "CyclicDependencyError", code: 1, userInfo: ["cycle": "\(node.type) -> \(dependency.type)"])
                }
            }
        }
        
        recursionStack.remove(node)
    }
    
    /// Executes the initialization process for all registered components.
    ///
    /// This method performs a topological sort on the dependency graph and then
    /// initializes each component in the correct order. If `runParallel` was set to `true`
    /// during initialization, it will attempt to run initializers concurrently where possible.
    ///
    /// - Throws: An error if any initializer fails or if circular dependencies are detected.
    func conquer() async throws {
        // Queue of nodes with no incoming edges (dependencies)
        var zeroInDegreeQueue: [AnyInitializer] = inDegree.filter { $0.value == 0 }.map { $0.key }
        // List to store the order of initialisation
        var sortedInitializers: [AnyInitializer] = []
        
        while !zeroInDegreeQueue.isEmpty {
            let current = zeroInDegreeQueue.removeFirst()
            sortedInitializers.append(current)
            
            if let dependencies = dependencyGraph[current] {
                for dep in dependencies {
                    inDegree[dep]! -= 1
                    if inDegree[dep]! == 0 {
                        zeroInDegreeQueue.append(dep)
                    }
                }
            }
        }
            
        // Check if topological sort includes all nodes
        if sortedInitializers.count != initializers.count {
            throw NSError(domain: "CircularDependencyError", code: 2, userInfo: nil)
        }
        
        let sortedListReversed = sortedInitializers.reversed().map { $0.type }
        
        let startTime = Date()
        // Execute initializers in topological order
        try await runInitializers(sortedInitializers: sortedListReversed)
        log("[conquered] in \(startTime.dt)", "👑")
    }

    private func runInitializers(sortedInitializers: [Initializer.Type]) async throws {
        var errors: [Error] = []

        for initializer in sortedInitializers {
            do {
                let startTime = Date()
                try await initializer.embark()
                log("[\(initializer.self)][vanquished] \(startTime.dt)", "⚔️")
            } catch {
                errors.append(error)
            }
        }

        if !errors.isEmpty {
            throw NSError(domain: "[Khan] InitialisationError", code: 3, userInfo: ["errors": errors])
        }
    }
    
    /// Prints a visual representation of the dependency tree.
    ///
    /// This method is useful for debugging and understanding the structure of your
    /// initialization graph. It will only output if logging is enabled.
    func printDependencyTree() {
        log("Dependency Tree:")
        for initializer in initializers where inDegree[initializer] == 0 {
            // Start with initializers that have no dependencies (roots of the trees)
            printDependencyTreeNode(initializer, indentLevel: 0)
        }
    }

    private func printDependencyTreeNode(_ initializer: AnyInitializer, indentLevel: Int) {
        let indent = String(repeating: "    ", count: indentLevel) // 4 spaces per indent level
        log("\(indent)- \(initializer.type)")

        if let dependencies = dependencyGraph[initializer] {
            for dependency in dependencies {
                printDependencyTreeNode(dependency, indentLevel: indentLevel + 1)
            }
        }
    }
    
    private func log(_ message: String, _ icon: Character? = nil) {
        if enableLogging {
            print("\(String(describing: icon)) [Kahn]\(message)")
        }
    }
}
