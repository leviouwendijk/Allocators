import Foundation

/// A non-owning handle to manually managed storage.
///
/// `BufferHandle` does not allocate or free memory by itself.
/// It simply carries a base pointer and a count. 
///
/// The idea is to match the spirit of a Zig slice `{ ptr, len }` or a
/// C-style `{ T *ptr; size_t count; }` pair.
public struct BufferHandle<Element> {
    public var ptr: UnsafeMutablePointer<Element>
    public var count: Int

    @inlinable
    public init(ptr: UnsafeMutablePointer<Element>, count: Int) {
        self.ptr = ptr
        self.count = count
    }

    /// A mutable, non-owning view of the buffer as an `UnsafeMutableBufferPointer`.
    @inlinable
    public var mutableSlice: UnsafeMutableBufferPointer<Element> {
        UnsafeMutableBufferPointer(start: ptr, count: count)
    }

    /// A read-only, non-owning view of the buffer as an `UnsafeBufferPointer`.
    @inlinable
    public var slice: UnsafeBufferPointer<Element> {
        UnsafeBufferPointer(start: ptr, count: count)
    }
}
