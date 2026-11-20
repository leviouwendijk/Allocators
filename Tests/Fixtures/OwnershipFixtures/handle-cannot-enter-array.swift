import Allocators

private func probe(
    _ owner: borrowing BumpAllocator
) {
    let values = [owner.allocator]
    _ = values
}
