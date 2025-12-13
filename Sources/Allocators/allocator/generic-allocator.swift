import Foundation

/// Default allocator backed by `UnsafeMutablePointer.allocate` / `deallocate`.
public struct GenericAllocator: Allocator {
    public static let shared = GenericAllocator()

    public init() { }

    public func allocate<T>(
        _ type: T.Type,
        capacity: Int
    ) -> UnsafeMutablePointer<T> {
        UnsafeMutablePointer<T>.allocate(capacity: capacity)
    }

    public func deallocate<T>(
        _ pointer: UnsafeMutablePointer<T>,
        capacity: Int
    ) {
        pointer.deinitialize(count: capacity)
        pointer.deallocate()
    }
}
