import Allocators

private struct TestFailure: Error, CustomStringConvertible {
    let message: String

    var description: String {
        message
    }
}

private struct TestCase {
    let name: String
    let body: () throws -> Void
}

package enum TestAllocators {
    package static func runAll(arguments: [String]) throws {
        try runTests(
            allocatorTests + bufferTests,
            suite: "talloc",
            arguments: arguments
        )
    }

    package static func runAllocator(arguments: [String]) throws {
        try runTests(
            allocatorTests,
            suite: "talloc_allocator",
            arguments: arguments
        )
    }

    package static func runBuffer(arguments: [String]) throws {
        try runTests(
            bufferTests,
            suite: "talloc_buffer",
            arguments: arguments
        )
    }

    private static var allocatorTests: [TestCase] {
        [
            .init(
                name: "generic-allocator-copyable-capability",
                body: testGenericAllocatorCopyableCapability
            ),
            .init(
                name: "debug-owner-copyable-handle",
                body: testDebugOwnerCopyableHandle
            ),
            .init(
                name: "debug-deconstruct-deallocate",
                body: testDebugDeconstructDeallocate
            ),
            .init(
                name: "debug-report",
                body: testDebugReport
            ),
            .init(
                name: "bump-owner-copyable-handle",
                body: testBumpOwnerCopyableHandle
            ),
        ]
    }

    private static var bufferTests: [TestCase] {
        [
            .init(
                name: "buffer-handle-views",
                body: testBufferHandleViews
            ),
            .init(
                name: "explicit-buffer-allocator",
                body: testExplicitBufferAllocator
            ),
            .init(
                name: "slice-helpers",
                body: testSliceHelpers
            ),
        ]
    }

    private static func runTests(
        _ tests: [TestCase],
        suite: String,
        arguments: [String]
    ) throws {
        let unsupported = arguments.filter { $0 != "--verbose" }
        guard unsupported.isEmpty else {
            throw TestFailure(
                message: "unsupported arguments: \(unsupported.joined(separator: " "))"
            )
        }

        let verbose = arguments.contains("--verbose")
        var failures: [String] = []

        for test in tests {
            do {
                try test.body()
                if verbose {
                    print("PASS \(suite) :: \(test.name)")
                }
            } catch {
                failures.append("\(test.name): \(error)")
                print("FAIL \(suite) :: \(test.name) :: \(error)")
            }
        }

        guard failures.isEmpty else {
            throw TestFailure(
                message: "\(suite) failed \(failures.count)/\(tests.count) tests"
            )
        }

        print("PASS \(suite) :: \(tests.count)/\(tests.count)")
    }

    private static func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) throws {
        guard condition() else {
            throw TestFailure(message: message)
        }
    }

    private static func testGenericAllocatorCopyableCapability() throws {
        let allocator = GenericAllocator()
        let copied = allocator

        let pointer = allocator.allocate(
            Int.self,
            capacity: 4
        )
        pointer.initialize(
            repeating: 7,
            count: 4
        )

        try expect(pointer[0] == 7, "first element should be initialized")
        try expect(pointer[3] == 7, "last element should be initialized")

        copied.clear(
            pointer,
            count: 4
        )
    }

    private static func testDebugOwnerCopyableHandle() throws {
        let owner = DebugAllocator(
            alloc: GenericAllocator(),
            options: .init(
                reportLeaksOnDeinit: false
            )
        )
        let allocator = owner.allocator
        let copied = allocator

        let pointer = copied.allocate(
            Int.self,
            capacity: 2
        )
        pointer.initialize(
            repeating: 11,
            count: 2
        )

        try expect(
            owner.inspector.leaks(),
            "allocation through copied handle should be visible to owner"
        )

        allocator.clear(
            pointer,
            count: 2
        )

        try expect(
            !owner.inspector.leaks(),
            "clearing through another handle copy should clear the same domain"
        )
    }

    private static func testDebugDeconstructDeallocate() throws {
        let owner = DebugAllocator(
            alloc: GenericAllocator(),
            options: .init(
                reportLeaksOnDeinit: false
            )
        )
        let allocator = owner.allocator

        let pointer = allocator.allocate(
            Int.self,
            capacity: 3
        )
        pointer.initialize(
            repeating: 5,
            count: 3
        )

        allocator.deconstruct(
            pointer,
            count: 3
        )

        try expect(
            owner.inspector.leaks(),
            "deconstructed storage should remain tracked until deallocation"
        )

        allocator.deallocate(pointer)

        try expect(
            !owner.inspector.leaks(),
            "deallocation should finish the tracked allocation lifecycle"
        )
    }

    private static func testDebugReport() throws {
        let owner = DebugAllocator(
            alloc: GenericAllocator(),
            options: .init(
                reportLeaksOnDeinit: false
            )
        )
        let allocator = owner.allocator

        let pointer = allocator.allocate(
            UInt8.self,
            capacity: 3
        )
        pointer.initialize(
            repeating: 0x2A,
            count: 3
        )

        let report = owner.inspector.report()

        try expect(
            report?.contains("capacity: 3") == true,
            "leak report should include allocation capacity"
        )
        try expect(
            report?.contains("bytes: 3") == true,
            "leak report should include byte count"
        )

        allocator.clear(
            pointer,
            count: 3
        )

        try expect(
            owner.inspector.report() == nil,
            "report should disappear after clear"
        )
    }

    private static func testBumpOwnerCopyableHandle() throws {
        let owner = BumpAllocator(
            totalBytes: 512,
            alignment: 64
        )
        let allocator = owner.allocator
        let copied = allocator

        let first = allocator.allocate(
            Int.self,
            capacity: 4
        )
        first.initialize(
            repeating: 13,
            count: 4
        )

        let usedAfterFirst = owner.usedBytes

        let second = copied.allocate(
            UInt64.self,
            capacity: 2
        )
        second.initialize(
            repeating: 21,
            count: 2
        )

        try expect(
            owner.usedBytes > usedAfterFirst,
            "copied bump handle should advance the same allocation domain"
        )
        try expect(
            first[0] == 13,
            "first bump allocation should remain valid"
        )
        try expect(
            second[1] == 21,
            "second bump allocation should remain valid"
        )

        allocator.clear(
            first,
            count: 4
        )
        copied.clear(
            second,
            count: 2
        )
    }

    private static func testBufferHandleViews() throws {
        let allocator = GenericAllocator()
        let pointer = allocator.allocate(
            Int.self,
            capacity: 3
        )
        pointer.initialize(
            repeating: 0,
            count: 3
        )
        defer {
            allocator.clear(
                pointer,
                count: 3
            )
        }

        let handle = BufferHandle(
            ptr: pointer,
            count: 3
        )
        let mutable = handle.mutableSlice
        mutable[0] = 4
        mutable[1] = 8
        mutable[2] = 15

        try expect(handle.count == 3, "buffer handle should retain count")
        try expect(handle.slice[0] == 4, "read-only view should see first write")
        try expect(handle.slice[1] == 8, "read-only view should see second write")
        try expect(handle.slice[2] == 15, "read-only view should see third write")
    }

    private static func testExplicitBufferAllocator() throws {
        let owner = DebugAllocator(
            alloc: GenericAllocator(),
            options: .init(
                reportLeaksOnDeinit: false
            )
        )
        let allocator = owner.allocator

        let buffer = makeBuffer(
            count: 4,
            allocator: allocator,
            initial: { index in
                index * 3
            }
        )

        try expect(buffer.slice[0] == 0, "explicit buffer allocator should initialize first value")
        try expect(buffer.slice[3] == 9, "explicit buffer allocator should initialize final value")
        try expect(owner.inspector.leaks(), "buffer allocation should be tracked")

        destroyBuffer(
            buffer,
            allocator: allocator
        )

        try expect(
            !owner.inspector.leaks(),
            "destroyBuffer should release through the supplied allocator"
        )
    }

    private static func testSliceHelpers() throws {
        let allocator = GenericAllocator()
        let pointer = allocator.allocate(
            Int.self,
            capacity: 4
        )

        pointer.advanced(by: 0).initialize(to: 1)
        pointer.advanced(by: 1).initialize(to: 2)
        pointer.advanced(by: 2).initialize(to: 3)
        pointer.advanced(by: 3).initialize(to: 4)

        defer {
            allocator.clear(
                pointer,
                count: 4
            )
        }

        let mutable = UnsafeMutableBufferPointer(
            start: pointer,
            count: 4
        )

        try expect(
            _exampleSumSlice(
                UnsafeBufferPointer(
                    start: mutable.baseAddress,
                    count: mutable.count
                )
            ) == 10,
            "sum helper should total the slice"
        )

        _exampleDoubleInPlace(mutable)

        try expect(mutable[0] == 2, "first value should double")
        try expect(mutable[1] == 4, "second value should double")
        try expect(mutable[2] == 6, "third value should double")
        try expect(mutable[3] == 8, "fourth value should double")
    }
}
