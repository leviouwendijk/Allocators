/// Default lightweight allocation capability.
///
/// Debug ownership is explicit rather than selected through conditional
/// compilation so that allocator ownership and lifetime remain visible.
public typealias DefaultAllocator = GenericAllocator

/// Convenience spelling for the standard debug-allocation owner.
public typealias DefaultDebugAllocator = DebugAllocator<GenericAllocator>
