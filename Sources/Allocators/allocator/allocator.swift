/// A lightweight allocation capability.
///
/// Allocators may be ordinary escapable values or lifetime-bound nonescapable
/// views. Resource ownership belongs to the type that vends the capability.
public protocol Allocator: ~Escapable {
    func allocate<T>(
        _ type: T.Type,
        capacity: Int
    ) -> UnsafeMutablePointer<T>

    func deconstruct<T>(
        _ pointer: UnsafeMutablePointer<T>,
        count: Int
    )

    func deallocate<T>(
        _ pointer: UnsafeMutablePointer<T>
    )

    func clear<T>(
        _ pointer: UnsafeMutablePointer<T>,
        count: Int
    )
}

/// An allocator capability that is explicitly safe to pass across concurrency
/// domains.
public protocol ConcurrentAllocator: Allocator, Sendable {}

public extension Allocator {
    func allocate<T>(
        _ type: T.Type,
        capacity: Int
    ) -> UnsafeMutablePointer<T> {
        precondition(capacity >= 0, "capacity must be non-negative")
        return UnsafeMutablePointer<T>.allocate(capacity: capacity)
    }

    func deconstruct<T>(
        _ pointer: UnsafeMutablePointer<T>,
        count: Int
    ) {
        precondition(count >= 0, "count must be non-negative")
        pointer.deinitialize(count: count)
    }

    func deallocate<T>(
        _ pointer: UnsafeMutablePointer<T>
    ) {
        pointer.deallocate()
    }

    func clear<T>(
        _ pointer: UnsafeMutablePointer<T>,
        count: Int
    ) {
        deconstruct(pointer, count: count)
        deallocate(pointer)
    }
}
