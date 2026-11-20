import Allocators

private func useAllocator(
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

private func probe() {
    let owner = BumpAllocator(
        totalBytes: 128,
        alignment: 64
    )

    useAllocator(owner)
    owner.shutdown()
}
