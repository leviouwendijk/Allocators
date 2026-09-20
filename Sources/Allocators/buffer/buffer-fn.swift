/// Allocates and initializes a lifetime-bound buffer.
///
/// This is the default safe allocating buffer API. The returned buffer inherits
/// a lifetime dependency from `allocator` and cannot escape that allocation
/// domain. It stores the allocator capability used to create its storage and
/// clears the allocation when the buffer leaves scope.
@_lifetime(borrow allocator)
@inlinable
public func makeBuffer<Element, A: Allocator & ~Escapable>(
    count: Int,
    allocator: borrowing A,
    initial: (Int) -> Element
) -> BorrowedBuffer<Element, A> {
    precondition(
        count > 0,
        "buffer count must be greater than zero"
    )

    let pointer = allocator.allocate(
        Element.self,
        capacity: count
    )

    for index in 0..<count {
        pointer.advanced(by: index).initialize(
            to: initial(index)
        )
    }

    return BorrowedBuffer(
        pointer: pointer,
        count: count,
        allocator: allocator
    )
}

/// Allocates and initializes an escapable, uniquely owned buffer.
///
/// The allocator capability is consumed into the buffer and is retained for
/// cleanup. Because the allocator generic keeps the ordinary `Escapable`
/// requirement, a lifetime-bound allocator such as `BumpAllocator.Handle`
/// cannot be used to manufacture an `OwnedBuffer` that outlives its domain.
@inlinable
public func makeOwnedBuffer<Element, A: Allocator>(
    count: Int,
    allocator: consuming A,
    initial: (Int) -> Element
) -> OwnedBuffer<Element, A> {
    precondition(
        count > 0,
        "buffer count must be greater than zero"
    )

    let pointer = allocator.allocate(
        Element.self,
        capacity: count
    )

    for index in 0..<count {
        pointer.advanced(by: index).initialize(
            to: initial(index)
        )
    }

    return OwnedBuffer(
        pointer: pointer,
        count: count,
        allocator: allocator
    )
}

/// Allocates and initializes an explicitly unsafe raw buffer handle.
///
/// Unlike `makeBuffer`, the returned value carries no lifetime relationship to
/// `allocator`. This is an intentional escape hatch for callers that accept
/// manual lifetime management.
@inlinable
public func makeUnsafeBufferHandle<Element, A: Allocator & ~Escapable>(
    count: Int,
    allocator: borrowing A,
    initial: (Int) -> Element
) -> BufferHandle<Element> {
    precondition(
        count > 0,
        "buffer count must be greater than zero"
    )

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

/// Clears storage previously returned by `makeUnsafeBufferHandle`.
///
/// The caller must supply the allocator associated with the allocation. The
/// type system intentionally does not track that relationship for unsafe
/// handles.
@inlinable
public func destroyUnsafeBufferHandle<Element, A: Allocator & ~Escapable>(
    _ buffer: BufferHandle<Element>,
    allocator: borrowing A
) {
    allocator.clear(
        buffer.ptr,
        count: buffer.count
    )
}
