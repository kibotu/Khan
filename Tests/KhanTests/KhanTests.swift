import Dispatch
import XCTest
@testable import Khan

private actor Recorder {
    private(set) var events: [String] = []

    func record(_ event: String) { events.append(event) }
    func reset() { events = [] }

    func waitFor(_ event: String, timeout: UInt64 = 2_000_000_000) async throws {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeout
        while !events.contains(event) {
            guard DispatchTime.now().uptimeNanoseconds < deadline else { throw TestError.timeout(event) }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}

private let recorder = Recorder()

private enum TestError: Error, Equatable {
    case boom
    case timeout(String)
}

/// Records `start:`/`end:` events around an optional delay.
private protocol Probe: Initializer {
    static var delay: UInt64 { get }
}

private extension Probe {
    static var delay: UInt64 { 0 }
    static var name: String { String(describing: self).split(separator: ".").last.map(String.init)! }

    static func embark() async throws {
        await recorder.record("start:\(name)")
        try await Task.sleep(nanoseconds: delay)
        await recorder.record("end:\(name)")
    }
}

final class KhanTests: XCTestCase {
    override func setUp() async throws { await recorder.reset() }

    private func index(of event: String, in events: [String], file: StaticString = #filePath, line: UInt = #line) -> Int {
        guard let i = events.firstIndex(of: event) else {
            XCTFail("missing \(event) in \(events)", file: file, line: line)
            return -1
        }
        return i
    }

    // MARK: - Ordering

    func testChainRunsInDependencyOrder() async throws {
        enum A: Probe { static let dependencies: [Initializer.Type] = [B.self] }
        enum B: Probe { static let dependencies: [Initializer.Type] = [C.self] }
        enum C: Probe {}

        try await Khan(initializers: [A.self, B.self, C.self]).conquer()

        let events = await recorder.events
        XCTAssertEqual(events, ["start:C", "end:C", "start:B", "end:B", "start:A", "end:A"])
    }

    func testDependentStartsOnlyAfterSlowDependencyEnds() async throws {
        enum Slow: Probe { static let delay: UInt64 = 150_000_000 }
        enum Fast: Probe {}
        enum Child: Probe { static let dependencies: [Initializer.Type] = [Slow.self, Fast.self] }

        try await Khan(initializers: [Child.self, Fast.self, Slow.self]).conquer()

        let events = await recorder.events
        XCTAssertLessThan(index(of: "end:Slow", in: events), index(of: "start:Child", in: events))
        XCTAssertLessThan(index(of: "end:Fast", in: events), index(of: "start:Child", in: events))
    }

    func testDiamondRunsSharedDependencyOnceAndRootLast() async throws {
        enum A: Probe { static let dependencies: [Initializer.Type] = [B.self, C.self] }
        enum B: Probe { static let dependencies: [Initializer.Type] = [D.self] }
        enum C: Probe { static let dependencies: [Initializer.Type] = [D.self] }
        enum D: Probe {}

        try await Khan(initializers: [A.self, B.self, C.self, D.self]).conquer()

        let events = await recorder.events
        XCTAssertEqual(events.filter { $0 == "start:D" }.count, 1)
        XCTAssertEqual(events.first, "start:D")
        XCTAssertEqual(events.last, "end:A")
    }

    // MARK: - Parallelism

    func testIndependentInitializersOverlap() async throws {
        enum P: Initializer {
            static func embark() async throws {
                await recorder.record("start:P")
                try await recorder.waitFor("start:Q")
            }
        }
        enum Q: Initializer {
            static func embark() async throws {
                await recorder.record("start:Q")
                try await recorder.waitFor("start:P")
            }
        }

        try await Khan(initializers: [P.self, Q.self]).conquer()
    }

    func testSiblingsOfSlowInitializerAreNotBlocked() async throws {
        enum Blocked: Initializer {
            static func embark() async throws { try await recorder.waitFor("end:AfterOther") }
        }
        enum Other: Probe {}
        enum AfterOther: Probe { static let dependencies: [Initializer.Type] = [Other.self] }

        try await Khan(initializers: [Blocked.self, Other.self, AfterOther.self]).conquer()
    }

    // MARK: - Failure

    func testFailureSkipsDependentsButNotUnrelated() async throws {
        enum Boom: Initializer { static func embark() async throws { throw TestError.boom } }
        enum Child: Probe { static let dependencies: [Initializer.Type] = [Boom.self] }
        enum Grandchild: Probe { static let dependencies: [Initializer.Type] = [Child.self] }
        enum Unrelated: Probe {}

        let khan = try Khan(initializers: [Boom.self, Child.self, Grandchild.self, Unrelated.self])

        do {
            try await khan.conquer()
            XCTFail("expected failure")
        } catch let KhanError.failed(failures, skipped) {
            XCTAssertEqual(failures.map { "\($0.initializer)" }, ["Boom"])
            XCTAssertEqual(failures.first?.error as? TestError, .boom)
            XCTAssertEqual(Set(skipped.map { "\($0)" }), ["Child", "Grandchild"])
        }

        let events = await recorder.events
        XCTAssertEqual(events, ["start:Unrelated", "end:Unrelated"])
    }

    func testFailureStillLetsRunningSiblingsFinish() async throws {
        enum Boom: Initializer { static func embark() async throws { throw TestError.boom } }
        enum Slow: Probe { static let delay: UInt64 = 100_000_000 }

        do {
            try await Khan(initializers: [Boom.self, Slow.self]).conquer()
            XCTFail("expected failure")
        } catch KhanError.failed {}

        let events = await recorder.events
        XCTAssertTrue(events.contains("end:Slow"))
    }

    func testCancellationStopsLaunchingDependents() async throws {
        enum Long: Probe { static let delay: UInt64 = 10_000_000_000 }
        enum Child: Probe { static let dependencies: [Initializer.Type] = [Long.self] }
        let khan = try Khan(initializers: [Long.self, Child.self])

        let task = Task { try await khan.conquer() }
        try await recorder.waitFor("start:Long")
        task.cancel()

        do {
            try await task.value
            XCTFail("expected cancellation")
        } catch is CancellationError {}

        let events = await recorder.events
        XCTAssertEqual(events, ["start:Long"])
    }

    // MARK: - Validation

    func testCycleIsReportedWithPath() {
        enum A: Probe { static let dependencies: [Initializer.Type] = [B.self] }
        enum B: Probe { static let dependencies: [Initializer.Type] = [C.self] }
        enum C: Probe { static let dependencies: [Initializer.Type] = [A.self] }

        XCTAssertThrowsError(try Khan(initializers: [A.self, B.self, C.self])) { error in
            guard case let KhanError.cycle(path) = error else { return XCTFail("\(error)") }
            XCTAssertEqual(path.map { "\($0)" }, ["A", "B", "C", "A"])
        }
    }

    func testSelfDependencyIsACycle() {
        enum A: Probe { static let dependencies: [Initializer.Type] = [A.self] }

        XCTAssertThrowsError(try Khan(initializers: [A.self])) { error in
            guard case KhanError.cycle = error else { return XCTFail("\(error)") }
        }
    }

    func testMissingDependencyThrows() {
        enum A: Probe { static let dependencies: [Initializer.Type] = [B.self] }
        enum B: Probe {}

        XCTAssertThrowsError(try Khan(initializers: [A.self])) { error in
            guard case let KhanError.missingDependency(initializer, dependency) = error else { return XCTFail("\(error)") }
            XCTAssertTrue(initializer == A.self)
            XCTAssertTrue(dependency == B.self)
        }
    }

    // MARK: - Misc

    func testDuplicateRegistrationsRunOnce() async throws {
        enum A: Probe {}

        try await Khan(initializers: [A.self, A.self]).conquer()

        let events = await recorder.events
        XCTAssertEqual(events, ["start:A", "end:A"])
    }

    func testConquerIsRepeatable() async throws {
        enum A: Probe {}
        enum B: Probe { static let dependencies: [Initializer.Type] = [A.self] }
        let khan = try Khan(initializers: [A.self, B.self])

        try await khan.conquer()
        try await khan.conquer()

        let events = await recorder.events
        XCTAssertEqual(events.count, 8)
    }

    func testEmptyGraphSucceeds() async throws {
        try await Khan(initializers: []).conquer()
    }

    func testLoggerReceivesLinePerInitializerAndTotal() async throws {
        enum A: Probe {}
        let lines = LockedBox<[String]>([])

        try await Khan(initializers: [A.self], logger: { line in lines.mutate { $0.append(line) } }).conquer()

        let captured = lines.value
        XCTAssertEqual(captured.count, 2)
        XCTAssertTrue(captured[0].hasPrefix("A done in"))
        XCTAssertTrue(captured[1].hasPrefix("conquered in"))
    }
}

private final class LockedBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: T
    init(_ value: T) { storage = value }
    var value: T {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func mutate(_ body: (inout T) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        body(&storage)
    }
}
