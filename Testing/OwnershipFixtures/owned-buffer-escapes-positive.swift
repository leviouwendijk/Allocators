import Allocators

private func makeOwned() -> OwnedBuffer<Int, GenericAllocator> {
    makeOwnedBuffer(
        count: 4,
        allocator: GenericAllocator(),
        initial: { index in
            index
        }
    )
}
