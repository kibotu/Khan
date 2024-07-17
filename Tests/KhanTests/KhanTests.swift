import XCTest
@testable import Khan

class KhanTests: XCTestCase {

    // MARK: - Circular Dependency Tests

    func testCircularDependencyDetection() {
        class A: Initializer {
            static var dependencies: [Initializer.Type] = [B.self]
            static func embark() async throws {}
        }
        
        class B: Initializer {
            static var dependencies: [Initializer.Type] = [A.self]
            static func embark() async throws {}
        }
        
        XCTAssertThrowsError(try Khan(initializers: [A.self, B.self])) { error in
            XCTAssertTrue(error.localizedDescription.contains("CyclicDependencyError"))
        }
    }

    func testComplexCircularDependencyDetection() {
        class A: Initializer {
            static var dependencies: [Initializer.Type] = [B.self]
            static func embark() async throws {}
        }
        
        class B: Initializer {
            static var dependencies: [Initializer.Type] = [C.self]
            static func embark() async throws {}
        }
        
        class C: Initializer {
            static var dependencies: [Initializer.Type] = [A.self]
            static func embark() async throws {}
        }
        
        XCTAssertThrowsError(try Khan(initializers: [A.self, B.self, C.self])) { error in
            XCTAssertTrue(error.localizedDescription.contains("CyclicDependencyError"))
        }
    }

    // MARK: - Thread Safety Tests

    func testConcurrentInitialization() async throws {
        class A: Initializer {
            static var dependencies: [Initializer.Type] = []
            static func embark() async throws {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
        }
        
        class B: Initializer {
            static var dependencies: [Initializer.Type] = []
            static func embark() async throws {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
        }
        
        let khan = try Khan(initializers: [A.self, B.self])
        
        let expectation = XCTestExpectation(description: "Concurrent initialization")
        
        Task {
            try await khan.conquer()
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    // MARK: - Deadlock Tests

    func testNoDeadlockWithComplexDependencies() async throws {
        class A: Initializer {
            static var dependencies: [Initializer.Type] = [B.self, C.self]
            static func embark() async throws {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
        }
        
        class B: Initializer {
            static var dependencies: [Initializer.Type] = [D.self]
            static func embark() async throws {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
        }
        
        class C: Initializer {
            static var dependencies: [Initializer.Type] = [D.self]
            static func embark() async throws {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
        }
        
        class D: Initializer {
            static var dependencies: [Initializer.Type] = []
            static func embark() async throws {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
        }
        
        let khan = try Khan(initializers: [A.self, B.self, C.self, D.self])
        
        let expectation = XCTestExpectation(description: "Complex initialization without deadlock")
        
        Task {
            try await khan.conquer()
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    // MARK: - Dependency Order Tests

    func testCorrectDependencyOrder() async throws {
        class TestTracker {
            static var initializationOrder: [String] = []
        }
        
        class A: Initializer {
            static var dependencies: [Initializer.Type] = [B.self]
            static func embark() async throws {
                TestTracker.initializationOrder.append("A")
            }
        }
        
        class B: Initializer {
            static var dependencies: [Initializer.Type] = [C.self]
            static func embark() async throws {
                TestTracker.initializationOrder.append("B")
            }
        }
        
        class C: Initializer {
            static var dependencies: [Initializer.Type] = []
            static func embark() async throws {
                TestTracker.initializationOrder.append("C")
            }
        }
        
        let khan = try Khan(initializers: [A.self, B.self, C.self])
        try await khan.conquer()
        
        XCTAssertEqual(TestTracker.initializationOrder, ["C", "B", "A"])
    }

    func testCorrectDependencyOrderWithMultipleDependencies() async throws {
        class TestTracker {
            static var initializationOrder: [String] = []
        }
        
        class A: Initializer {
            static var dependencies: [Initializer.Type] = [B.self, C.self]
            static func embark() async throws {
                TestTracker.initializationOrder.append("A")
            }
        }
        
        class B: Initializer {
            static var dependencies: [Initializer.Type] = [D.self]
            static func embark() async throws {
                TestTracker.initializationOrder.append("B")
            }
        }
        
        class C: Initializer {
            static var dependencies: [Initializer.Type] = [D.self]
            static func embark() async throws {
                TestTracker.initializationOrder.append("C")
            }
        }
        
        class D: Initializer {
            static var dependencies: [Initializer.Type] = []
            static func embark() async throws {
                TestTracker.initializationOrder.append("D")
            }
        }
        
        let khan = try Khan(initializers: [A.self, B.self, C.self, D.self])
        try await khan.conquer()
        
        XCTAssertEqual(TestTracker.initializationOrder.first, "D")
        XCTAssertEqual(TestTracker.initializationOrder.last, "A")
        XCTAssertTrue(TestTracker.initializationOrder.firstIndex(of: "B")! < TestTracker.initializationOrder.firstIndex(of: "A")!)
        XCTAssertTrue(TestTracker.initializationOrder.firstIndex(of: "C")! < TestTracker.initializationOrder.firstIndex(of: "A")!)
    }
}
