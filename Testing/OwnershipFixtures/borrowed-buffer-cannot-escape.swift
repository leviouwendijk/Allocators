import Allocators

private func requireEscapable<T: ~Copyable>(
    _ value: borrowing T
) {}

private func probe(
    _ owner: borrowing BumpAllocator
) {
    let allocator = owner.allocator
    let buffer = makeBuffer(
        count: 2,
        allocator: allocator,
        initial: { index in
            index
        }
    )

    requireEscapable(buffer)
}
