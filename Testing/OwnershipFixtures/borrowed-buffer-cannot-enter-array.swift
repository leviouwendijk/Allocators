import Allocators

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

    let values = [consume buffer]
    _ = values
}
