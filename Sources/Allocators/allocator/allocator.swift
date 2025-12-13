import Foundation

public protocol Allocator: Sendable {
    func allocate<T>(
        _ type: T.Type,
        capacity: Int
    ) -> UnsafeMutablePointer<T>

    func deallocate<T>(
        _ pointer: UnsafeMutablePointer<T>,
        // capacity: Int
    )

    // deinitialize() first
    // + deallocate()
    func clear<T>(
        _ pointer: UnsafeMutablePointer<T>,
        count: Int
    )
}

extension Allocator {
    public func allocate<T>(
        _ type: T.Type,
        capacity: Int
    ) -> UnsafeMutablePointer<T> {
        UnsafeMutablePointer<T>.allocate(capacity: capacity)
    }

    // fully deinit and dealloc
    public func deallocate<T>(
        _ pointer: UnsafeMutablePointer<T>,
        // capacity: Int
    ) {
        // pointer.deinitialize(count: capacity)
        pointer.deallocate()
    }
}

extension Allocator {
    public func deconstruct<T>(
        _ pointer: UnsafeMutablePointer<T>,
        count: Int
    ) {
        pointer.deinitialize(count: count)
    }

    // public func fulldestruct<T>(
    // public func abandon<T>(
    // public func wipe<T>(
    // public func clean<T>(
    public func clear<T>(
        _ pointer: UnsafeMutablePointer<T>,
        count: Int
    ) {
        pointer.deinitialize(count: count)
        deallocate(pointer)
    }
}
