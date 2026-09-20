import Allocators

private func probe(
    _ owner: borrowing BumpAllocator
) {
    let allocator = owner.allocator

    _ = makeOwnedBuffer(
        count: 4,
        allocator: allocator,
        initial: { index in
            index
        }
    )
}
