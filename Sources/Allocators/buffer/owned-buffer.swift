/// A uniquely owned, escapable allocation together with the allocator
/// capability required to release it.
///
/// `OwnedBuffer` is intended for storage that must survive beyond a local
/// borrowed allocation domain. Its allocator generic retains Swift's ordinary
/// `Escapable` requirement, so lifetime-bound capabilities such as
/// `BumpAllocator.Handle` cannot be stored here.
public struct OwnedBuffer<Element, A: Allocator>: ~Copyable {
    @usableFromInline
    let pointer: UnsafeMutablePointer<Element>

    @usableFromInline
    let allocator: A

    public let count: Int

    @usableFromInline
    init(
        pointer: UnsafeMutablePointer<Element>,
        count: Int,
        allocator: consuming A
    ) {
        self.pointer = pointer
        self.allocator = allocator
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
    /// Any handle that escapes the closure is manually lifetime-managed from
    /// that point onward.
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
