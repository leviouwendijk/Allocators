/// Stateless system allocator backed by `UnsafeMutablePointer.allocate` and
/// `deallocate`.
///
/// This value is deliberately cheap and copyable. It carries allocation
/// capability, not allocation ownership.
public struct GenericAllocator: ConcurrentAllocator {
    public static let shared = GenericAllocator()

    public init() {}
}
