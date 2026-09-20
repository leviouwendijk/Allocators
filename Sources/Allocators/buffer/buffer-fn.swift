/// Allocates and initializes a buffer using the explicitly supplied allocator.
///
/// The returned `BufferHandle` is non-owning. The same allocation domain must
/// remain valid until `destroyBuffer` is called.
@inlinable
public func makeBuffer<Element, A: Allocator>(
    count: Int,
    allocator: A,
    initial: (Int) -> Element
) -> BufferHandle<Element> {
    precondition(count >= 0, "count must be non-negative")

    let pointer = allocator.allocate(
        Element.self,
        capacity: count
    )

    for index in 0..<count {
        pointer.advanced(by: index).initialize(
            to: initial(index)
        )
    }

    return BufferHandle(
        ptr: pointer,
        count: count
    )
}

/// Deinitializes and releases storage previously created by `makeBuffer`.
@inlinable
public func destroyBuffer<Element, A: Allocator>(
    _ buffer: BufferHandle<Element>,
    allocator: A
) {
    allocator.clear(
        buffer.ptr,
        count: buffer.count
    )
}
