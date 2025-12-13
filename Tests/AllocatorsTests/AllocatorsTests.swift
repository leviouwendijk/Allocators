import Testing
@testable import Allocators

@Test 
func example() async throws {
    var base = GenericAllocator.shared
    let opts = DebugAllocator.Options(
        captureStackTraces: true,
        reportLeaksOnDeinit: true
    )
    var alloc = DebugAllocator(base: base, options: opts)

    // No leaks after correct deallocate
    do {
        let p = alloc.allocate(Int.self, capacity: 4)
        p.initialize(repeating: 42, count: 4)

        #expect(alloc.hasLeaks())

        p.deinitialize(count: 4)
        alloc.deallocate(p, capacity: 4)

        #expect(!alloc.hasLeaks())
        #expect(alloc.leakReport() == nil)
    }

    // Leak report is produced when we forget to deallocate
    do {
        _ = alloc.allocate(UInt8.self, capacity: 16)
        #expect(alloc.hasLeaks())
        #expect(alloc.leakReport() != nil)
    }

    // Capacity mismatch triggers a precondition
    do {
        let p = alloc.allocate(Int.self, capacity: 2)
        p.initialize(repeating: 1, count: 2)

        p.deinitialize(count: 2)
        alloc.deallocate(p, capacity: 1) // should trap
    }
}
