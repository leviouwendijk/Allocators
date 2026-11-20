import Allocators

private func useBuffer(
    _ owner: borrowing BumpAllocator
) {
    let allocator = owner.allocator
    let buffer = makeBuffer(
        count: 4,
        allocator: allocator,
        initial: { index in
            index
        }
    )

    _ = buffer[0]
    _ = buffer[3]
}

private func probe() {
    let owner = BumpAllocator(
        totalBytes: 256,
        alignment: 64
    )

    useBuffer(owner)
    owner.shutdown()
}
