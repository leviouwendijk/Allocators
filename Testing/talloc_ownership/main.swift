import Allocators
import Foundation

private struct TestFailure: Error, CustomStringConvertible {
    let message: String

    var description: String {
        message
    }
}

private struct OwnershipTest {
    let name: String
    let body: () throws -> Void
}

private struct CompilerResult {
    let status: Int32
    let output: String
}

private let packageRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

private let modulesDirectory: URL = {
    guard let executable = Bundle.main.executableURL else {
        fatalError("unable to determine talloc_ownership executable location")
    }

    return executable
        .deletingLastPathComponent()
        .appendingPathComponent("Modules", isDirectory: true)
}()

private func useBumpAllocator(
    _ owner: borrowing BumpAllocator
) {
    let allocator = owner.allocator
    let pointer = allocator.allocate(
        UInt64.self,
        capacity: 1
    )

    pointer.initialize(to: 42)

    allocator.clear(
        pointer,
        count: 1
    )
}

private func requireConcurrent<A: ConcurrentAllocator>(
    _ allocator: borrowing A
) {}

private func testBumpBorrowThenConsume() throws {
    let owner = BumpAllocator(
        totalBytes: 128,
        alignment: 64
    )

    useBumpAllocator(owner)

    owner.shutdown()
}

private func testDebugHandleRetainsConcurrency() throws {
    let owner = DebugAllocator(
        alloc: GenericAllocator(),
        options: .init(
            reportLeaksOnDeinit: false
        )
    )

    requireConcurrent(owner.allocator)
}

private func testGenericAllocatorRemainsCopyable() throws {
    let allocator = GenericAllocator()
    let copy = allocator

    let pointer = copy.allocate(
        UInt64.self,
        capacity: 1
    )
    pointer.initialize(to: 7)
    copy.clear(
        pointer,
        count: 1
    )
}

private func runCompiler(
    fixture: String
) throws -> CompilerResult {
    let fixtureURL = packageRoot
        .appendingPathComponent("Testing", isDirectory: true)
        .appendingPathComponent("OwnershipFixtures", isDirectory: true)
        .appendingPathComponent(fixture)

    guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
        throw TestFailure(
            message: "ownership fixture not found: \(fixtureURL.path)"
        )
    }

    guard FileManager.default.fileExists(atPath: modulesDirectory.path) else {
        throw TestFailure(
            message: "SwiftPM Modules directory not found: \(modulesDirectory.path)"
        )
    }

    let process = Process()
    let output = Pipe()

    process.executableURL = URL(
        fileURLWithPath: "/usr/bin/env"
    )
    process.arguments = [
        "swiftc",
        "-typecheck",
        "-swift-version",
        "6",
        "-enable-experimental-feature",
        "LifetimeDependence",
        "-enable-experimental-feature",
        "Lifetimes",
        "-I",
        modulesDirectory.path,
        fixtureURL.path,
    ]
    process.currentDirectoryURL = packageRoot
    process.standardOutput = output
    process.standardError = output

    try process.run()
    process.waitUntilExit()

    let data = output.fileHandleForReading.readDataToEndOfFile()
    let outputText = String(
        data: data,
        encoding: .utf8
    ) ?? ""

    return CompilerResult(
        status: process.terminationStatus,
        output: outputText
    )
}

private func expectFixture(
    _ fixture: String,
    compiles: Bool
) throws {
    let result = try runCompiler(
        fixture: fixture
    )
    let didCompile = result.status == 0

    guard didCompile == compiles else {
        let expectation = compiles
            ? "compile successfully"
            : "fail compilation"

        throw TestFailure(
            message: "fixture '\(fixture)' was expected to \(expectation), exit \(result.status)\n\(result.output)"
        )
    }
}

private func runOwnershipTests(
    arguments: [String]
) throws {
    let unsupported = arguments.filter {
        $0 != "--verbose"
    }

    guard unsupported.isEmpty else {
        throw TestFailure(
            message: "unsupported arguments: \(unsupported.joined(separator: " "))"
        )
    }

    let verbose = arguments.contains("--verbose")

    let tests: [OwnershipTest] = [
        .init(
            name: "bump-borrow-then-consume",
            body: testBumpBorrowThenConsume
        ),
        .init(
            name: "debug-handle-retains-concurrency",
            body: testDebugHandleRetainsConcurrency
        ),
        .init(
            name: "generic-allocator-remains-copyable",
            body: testGenericAllocatorRemainsCopyable
        ),
        .init(
            name: "borrowed-handle-positive",
            body: {
                try expectFixture(
                    "borrowed-handle-positive.swift",
                    compiles: true
                )
            }
        ),
        .init(
            name: "handle-cannot-escape",
            body: {
                try expectFixture(
                    "handle-cannot-escape.swift",
                    compiles: false
                )
            }
        ),
        .init(
            name: "owner-cannot-copy",
            body: {
                try expectFixture(
                    "owner-cannot-copy.swift",
                    compiles: false
                )
            }
        ),
        .init(
            name: "handle-cannot-enter-escaping-array",
            body: {
                try expectFixture(
                    "handle-cannot-enter-array.swift",
                    compiles: false
                )
            }
        ),
        .init(
            name: "bump-handle-not-concurrent",
            body: {
                try expectFixture(
                    "bump-handle-not-concurrent.swift",
                    compiles: false
                )
            }
        ),
    ]

    var failures: [String] = []

    for test in tests {
        do {
            try test.body()

            if verbose {
                print(
                    "PASS talloc_ownership :: \(test.name)"
                )
            }
        } catch {
            failures.append(
                "\(test.name): \(error)"
            )
            print(
                "FAIL talloc_ownership :: \(test.name) :: \(error)"
            )
        }
    }

    guard failures.isEmpty else {
        throw TestFailure(
            message: "talloc_ownership failed \(failures.count)/\(tests.count) test(s)"
        )
    }

    print(
        "PASS talloc_ownership :: \(tests.count)/\(tests.count)"
    )
}

try runOwnershipTests(
    arguments: Array(
        CommandLine.arguments.dropFirst()
    )
)
