import Allocators

private func requireConcurrent<A: ConcurrentAllocator>(
    _ allocator: borrowing A
) {}

private func probe(
    _ owner: borrowing BumpAllocator
) {
    requireConcurrent(owner.allocator)
}
