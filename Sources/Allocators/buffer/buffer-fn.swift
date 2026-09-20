/// Allocates and initializes a buffer using the explicitly supplied allocator.
///
/// `allocator` is borrowed for the duration of this operation. `BufferHandle`
/// itself still contains an unsafe pointer and therefore does not carry the
/// allocator's lifetime dependency; callers remain responsible for keeping the
/// allocation domain alive while using it.
@inlinable
public func makeBuffer<Element, A: Allocator & ~Escapable>(
    count: Int,
    allocator: borrowing A,
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
public func destroyBuffer<Element, A: Allocator & ~Escapable>(
    _ buffer: BufferHandle<Element>,
    allocator: borrowing A
) {
    allocator.clear(
        buffer.ptr,
        count: buffer.count
    )
}
