import Allocators

private func makeEscapingHandle() -> BufferHandle<Int> {
    let allocator = GenericAllocator()

    return makeUnsafeBufferHandle(
        count: 2,
        allocator: allocator,
        initial: { index in
            index
        }
    )
}
