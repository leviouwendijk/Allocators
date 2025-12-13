import Foundation

/// Default allocator backed by `UnsafeMutablePointer.allocate` / `deallocate`.
public struct GenericAllocator: Allocator {
    public static let shared = GenericAllocator()

    public init() { }
}
