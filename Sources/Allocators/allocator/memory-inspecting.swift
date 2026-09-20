/// Orthogonal inspection capability for allocator owners and other resources.
///
/// `~Copyable` allows uniquely owned resources such as `DebugAllocator` to
/// conform without imposing copyability on the owner itself.
public protocol MemoryInspecting: ~Copyable {
    var inspector: MemoryInspector { get }
}
