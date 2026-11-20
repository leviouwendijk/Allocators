import Allocators

private func requireCopyable<T: Copyable>(
    _ value: T
) {}

private func probe(
    _ owner: borrowing BumpAllocator
) {
    requireCopyable(owner)
}
