import Foundation

/// An explicitly unsafe, non-owning handle to manually managed storage.
///
/// `BufferHandle` is deliberately escapable and carries no allocator lifetime
/// dependency. It is the low-level `{ pointer, count }` representation for
/// callers that intentionally want manual lifetime control or C/Zig-style
/// interoperability.
///
/// Prefer `BorrowedBuffer` when storage belongs to a scoped allocation domain,
/// or `OwnedBuffer` when the buffer itself should manage allocation cleanup.
/// A `BufferHandle` may outlive the storage it addresses; correctness is the
/// caller's responsibility.
public struct BufferHandle<Element> {
    public var ptr: UnsafeMutablePointer<Element>
    public var count: Int

    @inlinable
    public init(
        ptr: UnsafeMutablePointer<Element>,
        count: Int
    ) {
        self.ptr = ptr
        self.count = count
    }

    /// A mutable unsafe view of the same storage.
    @inlinable
    public var mutableSlice: UnsafeMutableBufferPointer<Element> {
        UnsafeMutableBufferPointer(
            start: ptr,
            count: count
        )
    }

    /// A read-only unsafe view of the same storage.
    @inlinable
    public var slice: UnsafeBufferPointer<Element> {
        UnsafeBufferPointer(
            start: ptr,
            count: count
        )
    }
}
