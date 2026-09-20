import Allocators

// Known Swift 6.2.1 lifetime-checker gap.
//
// Semantically, `allocator` depends on `owner`, so consuming the owner before
// the handle's final use should be rejected. The current experimental lifetime
// checker still accepts this cross-module pattern, so this file documents the
// missing diagnostic but is intentionally not part of the passing ownership
// contract suite.
private func knownCompilerGap() {
    let owner = BumpAllocator(
        totalBytes: 128,
        alignment: 64
    )
    let allocator = owner.allocator

    owner.shutdown()

    let pointer = allocator.allocate(
        UInt64.self,
        capacity: 1
    )
    pointer.initialize(to: 1)
    allocator.clear(
        pointer,
        count: 1
    )
}
