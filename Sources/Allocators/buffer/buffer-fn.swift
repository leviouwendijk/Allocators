// import Foundation

// /// Allocates and initializes a buffer, returning a `BufferHandle`.
// ///
// /// The caller is responsible for eventually calling `destroyBuffer` with
// /// the same allocator.
// ///
// /// - Parameters:
// ///   - count: Number of elements.
// ///   - allocator: Allocator to use (defaults to `GenericAllocator.shared`).
// ///   - initial: Closure that produces the initial value for index `i`.
// @inlinable
// public func makeBuffer<Element>(
//     count: Int,
//     allocator: Allocator = GenericAllocator.shared,
//     initial: (Int) -> Element
// ) -> BufferHandle<Element> {
//     let ptr = allocator.allocate(Element.self, capacity: count)
//     for i in 0..<count {
//         ptr.advanced(by: i).initialize(to: initial(i))
//     }
//     return BufferHandle(ptr: ptr, count: count)
// }

// /// Deinitializes and deallocates the storage referenced by a `BufferHandle`.
// ///
// /// - Parameters:
// ///   - buffer: The buffer to destroy.
// ///   - allocator: The allocator originally used to allocate the storage.
// @inlinable
// public func destroyBuffer<Element>(
//     _ buffer: BufferHandle<Element>,
//     allocator: Allocator = GenericAllocator.shared
// ) {
//     allocator.deallocate(buffer.ptr, capacity: buffer.count)
// }

// /// Convenience helper for scoped manual allocation.
// ///
// /// Allocates uninitialized storage for `count` elements, then passes the
// /// raw pointer into `body`. When `body` returns or throws, the memory is
// /// deinitialized (up to `count` elements) and deallocated.
// ///
// /// The `body` closure is responsible for initializing the memory. If you
// /// only partially initialize elements, you should track that yourself and
// /// call `deinitialize` on the correct count before returning.
// ///
// /// This helper is most useful for “scratch” buffers scoped to a single call.
// @inlinable
// public func withBuffer<Element, R>(
//     count: Int,
//     allocator: Allocator = GenericAllocator.shared,
//     _ body: (UnsafeMutablePointer<Element>) throws -> R
// ) rethrows -> R {
//     let ptr = allocator.allocate(Element.self, capacity: count)
//     defer {
//         allocator.deallocate(ptr, capacity: count)
//     }
//     return try body(ptr)
// }
