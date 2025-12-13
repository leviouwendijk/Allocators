import Foundation

#if ALLOC_DEBUG
public typealias DefaultAllocator = DebugAllocator<GenericAllocator>
#else
public typealias DefaultAllocator = GenericAllocator
#endif
