import Foundation

/// Default allocator backed by `UnsafeMutablePointer.allocate` / `deallocate`.
public struct GenericAllocator: Allocator {
    public static let shared = GenericAllocator()
    public var tracker: any AllocationTracking

    public init(
        options: AllocationTracker.Options = .init()
    ) {
        self.tracker = AllocationTracker(options: options)
    }
}
