/// A uniquely held buffer whose lifetime is borrowed from an allocation
/// capability.
///
/// `BorrowedBuffer` is both noncopyable and nonescapable. This lets it safely
/// contain storage allocated from lifetime-bound domains such as
/// `BumpAllocator` without retaining the domain through ARC.
///
/// The buffer stores a copy of the allocator capability so cleanup always goes
/// back through the allocator that created the storage. The capability itself
/// remains lifetime-dependent on its owner when appropriate.
public struct BorrowedBuffer<Element, A: Allocator & ~Escapable>: ~Copyable, ~Escapable {
    @usableFromInline
    let pointer: UnsafeMutablePointer<Element>

    @usableFromInline
    let allocator: A

    public let count: Int

    @_lifetime(borrow allocator)
    @usableFromInline
    init(
        pointer: UnsafeMutablePointer<Element>,
        count: Int,
        allocator: borrowing A
    ) {
        self.pointer = pointer
        self.allocator = copy allocator
        self.count = count
    }

    deinit {
        allocator.clear(
            pointer,
            count: count
        )
    }

    @inlinable
    public var isEmpty: Bool {
        count == 0
    }

    @inlinable
    public subscript(index: Int) -> Element {
        get {
            precondition(
                index >= 0 && index < count,
                "buffer index out of bounds"
            )
            return pointer[index]
        }
        nonmutating set {
            precondition(
                index >= 0 && index < count,
                "buffer index out of bounds"
            )
            pointer[index] = newValue
        }
    }

    /// Temporarily exposes the underlying storage as an unsafe handle.
    ///
    /// Returning or storing the supplied handle can deliberately bypass the
    /// lifetime protection provided by `BorrowedBuffer`. Callers choosing this
    /// API accept responsibility for keeping the buffer and its allocation
    /// domain alive for every subsequent use of the escaped handle.
    @inlinable
    public borrowing func withUnsafeHandle<Result>(
        _ body: (BufferHandle<Element>) throws -> Result
    ) rethrows -> Result {
        try body(
            BufferHandle(
                ptr: pointer,
                count: count
            )
        )
    }
}
