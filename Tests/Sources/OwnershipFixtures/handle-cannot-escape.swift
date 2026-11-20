import Allocators

private func requireEscapable<T>(
    _ value: T
) {}

private func probe(
    _ owner: borrowing BumpAllocator
) {
    requireEscapable(owner.allocator)
}
