/// A lightweight, copyable capability for obtaining and releasing storage.
///
/// Resource-owning allocator implementations should not place ownership in
/// conforming values. Instead, an owning type may be `~Copyable` and vend a
/// copyable allocator handle conforming to this protocol.
public protocol Allocator {
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
///
/// Concurrency safety is intentionally separate from `Allocator`: local arena
/// and bump allocator handles need not pay for synchronization merely to
/// satisfy the allocation contract.
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
